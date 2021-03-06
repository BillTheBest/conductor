#
# Copyright (C) 2011 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
  layout 'login'

  def new
  end

  def create
    authenticate!
    session[:javascript_enabled] = request.xhr?
    respond_to do |format|
      format.html do
        flash[:notice] = t"user_sessions.flash.notice.login"
        redirect_back_or_default root_url
      end
      format.js { render :status => 201, :text => root_url }
    end
  end

  def unauthenticated
    Rails.logger.warn "Request is unauthenticated for #{request.remote_ip}"

    respond_to do |format|
      format.xml { head :unauthorized }
      format.html do
        flash[:warning] = t"user_sessions.flash.warning.login_failed"
        render :action => :new
      end
      format.js { render :status=> 401, :text => "#{t('user_sessions.flash.warning.login_failed')}" }
    end

    return false
  end

  def destroy
    clear_breadcrumbs
    logout
    flash[:notice] = t"user_sessions.flash.notice.logout"
    redirect_back_or_default login_url
  end
end
