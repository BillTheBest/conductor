class InstancesController < ApplicationController
  before_filter :require_user, :except => [:can_start, :can_create]
  before_filter :load_instance, :only => [:show, :key, :edit, :update]
  before_filter :set_view_vars, :only => [:show, :index]

  def index
    @params = params
    @search_term = params[:q]
    save_breadcrumb(instances_path(:viewstate => @viewstate ? @viewstate.id : nil))
    if @search_term.blank?
      load_instances
    else
      @instances = Instance.search { keywords(params[:q]) }.results
    end

    respond_to do |format|
      format.js { render :partial => 'list' }
      format.html
      format.json { render :json => @instances }
    end
  end

  def new
    @instance = Instance.new(params[:instance])
    require_privilege(Privilege::CREATE, Instance, @instance.pool) if @instance.pool

    unless @instance.template
      redirect_to select_template_instances_path
      return
    end

    init_new_instance_attrs
    respond_to do |format|
      format.js { render :partial => 'new' }
      format.html
      format.json { render :json => @instance }
    end
  end

  def select_template
    # FIXME: we need to list only templates for particular user,
    # => TODO: add TEMPLATE_* permissions
    @templates = Template.paginate(
      :page => params[:page] || 1,
      :include => {:images => :legacy_provider_images},
      :conditions => "legacy_provider_images.status = '#{LegacyProviderImage::STATE_COMPLETED}'"
    )
    respond_to do |format|
      format.html
      format.json { render :json => @templates }
    end
  end

  def create
    if params[:cancel]
      redirect_to select_template_instances_path
      return
    end

    @instance = Instance.new(params[:instance])
    @instance.state = Instance::STATE_NEW
    @instance.owner = current_user

    respond_to do |format|
      begin
        require_privilege(Privilege::CREATE, Instance,
                          Pool.find(@instance.pool_id))
        free_quota = Quota.can_start_instance?(@instance, nil)
        raise "Pool is not enabled" unless @instance.pool and @instance.pool.enabled
        @instance.transaction do
          @instance.save!
          # set owner permissions:
          @task = InstanceTask.create!({:user        => current_user,
                                        :task_target => @instance,
                                        :action      => InstanceTask::ACTION_CREATE})
          condormatic_instance_create(@task)
        end
      rescue
        init_new_instance_attrs
        flash[:warning] = "Failed to launch instance: #{$!}"
        format.js { render :partial => 'new' }
        format.html { render :new }
        format.json { render :json => @instance, :status => :unprocessable_entity}
      else
        if free_quota
          flash[:notice] = "Instance added."
        else
          flash[:warning] = "Quota Exceeded: Instance will not start until you have free quota"
        end
        format.js { render :partial => 'properties', :id => @instance.id }
        format.html { redirect_to instances_path }
        format.json { render :json => @instance, :status => :created }
      end
    end
  end

  def show
    load_instances
    @url_params = params.clone
    @tab_captions = ['Properties', 'History', 'Permissions']
    @details_tab = params[:details_tab].blank? ? 'properties' : params[:details_tab]
    save_breadcrumb(instance_path(@instance), @instance.name)
    respond_to do |format|
      format.js do
        if @url_params.delete :details_pane
          render :partial => 'layouts/details_pane' and return
        end
        render :partial => @details_tab and return
      end
      format.html { render :action => 'show'}
      format.json { render :json => @instance }
    end
  end

  def edit
    require_privilege(Privilege::MODIFY, @instance)
    respond_to do |format|
      format.js { render :partial => 'edit', :id => @instance.id }
      format.html
      format.json { render :json => @instance }
    end
  end

  def update
    # TODO - This USER_MUTABLE_ATTRS business is because what a user and app components can do
    # will be greatly different. (e.g., a user shouldn't be able to change an instance's pool,
    # since it won't do what they expect). As we build this out, this logic will become more complex.
    attrs = {}
    params[:instance].each_pair{|k,v| attrs[k] = v if Instance::USER_MUTABLE_ATTRS.include?(k)}
    respond_to do |format|
      if check_privilege(Privilege::MODIFY, @instance) and @instance.update_attributes(attrs)
        flash[:success] = t('instances.updated', :count => 1, :list => @instance.name)
        format.js { render :partial => 'properties' }
        format.html { redirect_to @instance }
        format.json { render :json => @instance }
      else
        flash[:error] = t('instances.not_updated', :count =>1, :list => @instance.name)
        format.js { render :partial => 'edit' }
        format.html { render :action => :edit }
        format.json { render :json => @instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    destroyed = []
    failed = []
    Instance.find(ids_list).each do |instance|
      if check_privilege(Privilege::MODIFY, instance) && instance.destroyable?
        instance.destroy
        destroyed << instance.name
      else
        failed << instance.name
      end
    end
    flash[:success] = t('instances.deleted', :list => destroyed.to_sentence, :count => destroyed.size) if destroyed.present?
    flash[:error] = t('instances.not_deleted', :list => failed.to_sentence, :count => failed.size) if failed.present?
    respond_to do |format|
      # FIXME: _list does not show flash messages, but I'm not sure that showing _list is proper anyway
      format.js do
        set_view_vars
        load_instances
        render :partial => 'list'
      end
      format.html { render :action => :show }
      format.json { render :json => {:success => destroyed, :errors => failed} }
    end
  end

  def key
    respond_to do |format|
      if @instance.instance_key.nil?
        flash[:warning] = "SSH Key not found for this Instance."
        format.js { render :partial => 'properties' }
        format.html { redirect_to instance_path(@instance) }
        format.json { render :json => flash[:warning], :status => :not_found }
      else
        format.js do
          send_data @instance.instance_key.pem,
                                :filename => "#{@instance.instance_key.name}.pem",
                                :type => "text/plain"
        end
        format.html { send_data @instance.instance_key.pem,
                                :filename => "#{@instance.instance_key.name}.pem",
                                :type => "text/plain" }
        format.json { render :json => {:key => @instance.instance_key.pem,
                                      :filename => "#{@instance.instance_key.name}.pem",
                                      :type => "text/plain" } }
      end
    end
  end

  def multi_stop
    notices = ""
    errors = ""
    Instance.find(params[:instance_selected]).each do |instance|
      begin
        require_privilege(Privilege::USE,instance)
        unless instance.valid_action?('stop')
          raise ActionError.new("stop is an invalid action.")
        end

        # not sure if task is used as everything goes through condor
        #permissons check here
        @task = instance.queue_action(@current_user, 'stop')
        unless @task
          raise ActionError.new("stop cannot be performed on this instance.")
        end
        condormatic_instance_stop(@task)
        notices << "#{instance.name}: stop action was successfully queued.<br/>"
      rescue Exception => err
        errors << "#{instance.name}: " + err + "<br/>"
      end
    end
    flash[:notice] = notices unless notices.blank?
    flash[:error] = errors unless errors.blank?
    respond_to do |format|
      format.html { redirect_to instances_path }
      format.json { render :json => {:success => notices, :errors => errors} }
    end
  end

  def remove_failed
    notices = ""
    errors = ""
    Instance.find(params[:instance_selected]).each do |instance|
      begin
        require_privilege(Privilege::USE,instance)
        raise ActionError.new("remove failed cannot be performed on this instance.") unless
          instance.state == Instance::STATE_ERROR
        condormatic_instance_reset_error(instance)
        notices << "#{instance.name}: remove failed action was successfully queued."
      rescue Exception => err
        errors << "#{instance.name}: " + err + "<br/>"
      end
    end
    flash[:notice] = notices unless notices.blank?
    flash[:error] = errors unless errors.blank?
    respond_to do |format|
      format.html { redirect_to instances_path }
      format.json { render :json => {:success => notices, :errors => errors}, :status => :unprocessable_entity }
    end
  end

  def can_create
    respond_to do |format|
      begin
        provider_account = ProviderAccount.find(params[:provider_account_id])
        @instance = Instance.find(params[:instance_id])
        @action_request = "can_create"
        @value = Quota.can_create_instance?(@instance, provider_account)
        format.html { render :partial => 'can_perform_state_change.xml' }
        format.json { render :json => {:action_request => @action_request, :instance_id => @instance.id, :value => @value} }
      rescue ActiveRecord::RecordNotFound
        format.html { head :not_found }
        format.json { render :json => {:error => 'Record not found'}, :status => :not_found }
      rescue Exception
        format.html { head :internal_server_error }
        format.json { render :json => {:error => $!}, :status => :internal_server_error }
      end
    end
  end

  def can_start
    respond_to do |format|
      begin
        provider_account = ProviderAccount.find(params[:provider_account_id])
        @instance = Instance.find(params[:instance_id])
        @action_request = "can_start"
        @value = Quota.can_start_instance?(@instance, provider_account)
        format.html { render :partial => 'can_perform_state_change.xml' }
        format.json { render :json => {:action_request => @action_request, :instance_id => @instance.id, :value => @value} }
      rescue ActiveRecord::RecordNotFound => e
        format.html do
          puts e.inspect
          head :not_found
        end
        format.json { render :json => {:error => 'Record not found'}, :status => :not_found }
      rescue Exception => e
        format.html do
          puts e.inspect
          head :internal_server_error
        end
        format.json { render :json => {:error => $!}, :status => :internal_server_error }
      end
    end
  end

  private

  def load_instance
    @instance = Instance.find(params[:id].to_a.first)
    require_privilege(Privilege::USE,@instance)
  end

  def init_new_instance_attrs
    @pools = Pool.list_for_user(@current_user, Privilege::CREATE, {:target_type => Instance,:conditions=>{ :enabled => true}})
    @realms = FrontendRealm.all
    @hardware_profiles = HardwareProfile.all(
      :include => :architecture,
      :conditions => {
        :provider_id => nil,
        'hardware_profile_properties.value' => @instance.template.architecture
      }
    )
  end

  def set_view_vars
    @header = [
      {:name => 'VM NAME', :sort_attr => 'name'},
      {:name => 'STATUS', :sortable => false},
      {:name => 'TEMPLATE', :sort_attr => 'templates.name'},
      {:name => 'PUBLIC ADDRESS', :sort_attr => 'public_addresses'},
      {:name => 'PROVIDER', :sortable => false},
      {:name => 'CREATED BY', :sort_attr => 'users.last_name'},
    ]

    @pools = Pool.list_for_user(@current_user, Privilege::CREATE, :target_type => Instance)
  end

  def load_instances
    @instances = Instance.all(:include => [:template, :owner],
                              :conditions => {:pool_id => @pools},
                              :order => (params[:order_field] || 'name') +' '+ (params[:order_dir] || 'asc')
    )
  end
end