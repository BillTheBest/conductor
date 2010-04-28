#
# Copyright (C) 2009 Red Hat, Inc.
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

class Pool < ActiveRecord::Base
  include PermissionedObject
  has_many :instances,  :dependent => :destroy
  belongs_to :owner, :class_name => "User", :foreign_key => "owner_id"
  belongs_to :quota

  has_many :images,  :dependent => :destroy
  has_many :hardware_profiles,  :dependent => :destroy



  validates_presence_of :owner_id
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :owner_id
  validates_uniqueness_of :exported_as, :if => :exported_as

  has_many :permissions, :as => :permission_object, :dependent => :destroy,
           :include => [:role],
           :order => "permissions.id ASC"

  def cloud_accounts
    accounts = []
    instances.each do |instance|
      if instance.cloud_account and !accounts.include?(instance.cloud_account)
        accounts << instance.cloud_account
      end
    end
  end

  #FIXME: do we still allow explicit cloud/account choice via realm selection?
  #FIXME: How is account list for realm defined without explicit pool-account relationship?
  def realms
    realm_list = []
    CloudAccount.all.each do |cloud_account|
      prefix = cloud_account.account_prefix_for_realm
      realm_list << prefix
      cloud_account.provider.realms.each do |realm|
        realm_list << prefix + Realm::AGGREGATOR_REALM_ACCOUNT_DELIMITER +
                      realm.name
      end
    end
    realm_list
  end

  # FIXME: for already-mapped accounts, update rather than add new
  # FIXME: this needs to be revised to handle the removal of the account-pool association
  def populate_realms_and_images(accounts=CloudAccount.all)
    accounts.each do |cloud_account|
      client = cloud_account.connect
      realms = client.realms
      if client.driver_name == "ec2"
        images = client.images(:owner_id=>:self)
      else
        images = client.images
      end
      # FIXME: this should probably be in the same transaction as pool.save
      self.transaction do
        realms.each do |realm|
          #ignore if it exists
          #FIXME: we need to handle keeping in sync forupdates as well as
          # account permissions
          unless Realm.find_by_external_key_and_provider_id(realm.id,
                                                            cloud_account.provider.id)
            ar_realm = Realm.new(:external_key => realm.id,
                                 :name => realm.name ? realm.name : realm.id,
                                 :provider_id => cloud_account.provider.id)
            ar_realm.save!
          end
        end
        images.each do |image|
          #ignore if it exists
          #FIXME: we need to handle keeping in sync for updates as well as
          # account permissions
          ar_image = Image.find_by_external_key_and_provider_id(image.id,
                                                     cloud_account.provider.id)
          unless ar_image
            ar_image = Image.new(:external_key => image.id,
                                 :name => image.name ? image.name :
                                          (image.description ? image.description :
                                                               image.id),
                                 :architecture => image.architecture,
                                 :provider_id => cloud_account.provider.id)
            ar_image.save!
          end
          front_end_image = Image.new(:external_key =>
                                         cloud_account.account_prefix_for_realm +
                                         Realm::AGGREGATOR_REALM_ACCOUNT_DELIMITER +
                                         ar_image.external_key,
                                  :name => ar_image.name,
                                  :architecture => ar_image.architecture,
                                  :pool_id => id)
          front_end_image.save!
        end
        cloud_account.provider.hardware_profiles.each do |hardware_profile|
          front_hardware_profile = HardwareProfile.new(:external_key =>
                                         cloud_account.account_prefix_for_realm +
                                                       hardware_profile.external_key,
                               :name => hardware_profile.name,
                               :memory => hardware_profile.memory,
                               :storage => hardware_profile.storage,
                               :architecture => hardware_profile.architecture,
                               :pool_id => id)
          front_hardware_profile.save!
        end
      end
    end
  end


end
