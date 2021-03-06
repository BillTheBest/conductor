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

class TransformFieldsOfProviderAccountToCredentials < ActiveRecord::Migration
  def self.up
    transform
    remove_column :provider_accounts, :username
    remove_column :provider_accounts, :password
    remove_column :provider_accounts, :account_number
    remove_column :provider_accounts, :x509_cert_priv
    remove_column :provider_accounts, :x509_cert_pub

  end

  def self.down
    add_column :provider_accounts, :username, :string
    add_column :provider_accounts, :password, :string
    add_column :provider_accounts, :account_number, :string
    add_column :provider_accounts, :x509_cert_priv, :text
    add_column :provider_accounts, :x509_cert_pub, :text
    transform_back
  end

  def self.transform
    unless ProviderAccount.all.empty?
      ProviderAccount.all.each do |account|
        Credential.create!(:provider_account_id => account.id, :credential_definition_id => CredentialDefinition.find_by_name('username',:conditions => {:provider_type_id => account.provider.provider_type.id}).id, :value => account.username)
        Credential.create!(:provider_account_id => account.id, :credential_definition_id => CredentialDefinition.find_by_name('password',:conditions => {:provider_type_id => account.provider.provider_type.id}).id, :value => account.password)

        # transform more attributes for ec2
        if account.provider.provider_type.codename == 'ec2'
          Credential.create!(:provider_account_id => account.id, :credential_definition_id => CredentialDefinition.find_by_name('account_id',:conditions => {:provider_type_id => account.provider.provider_type.id}).id, :value => account.account_number)
          Credential.create!(:provider_account_id => account.id, :credential_definition_id => CredentialDefinition.find_by_name('x509private',:conditions => {:provider_type_id => account.provider.provider_type.id}).id, :value => account.x509_cert_priv)
          Credential.create!(:provider_account_id => account.id, :credential_definition_id => CredentialDefinition.find_by_name('x509public',:conditions => {:provider_type_id => account.provider.provider_type.id}).id, :value => account.x509_cert_pub)
        end
      end
    end
  end

  def self.transform_back
    unless Credential.all.empty?
      Credential.all.each do |credential|
        if credential.credential_definition.name == 'username'
          credential.provider_account.update_attribute(:username, credential.value)
        elsif credential.credential_definition.name == 'password'
          credential.provider_account.update_attribute(:password, credential.value)
        end
        if credential.credential_definition.provider_type.codename == 'ec2'
          if credential.credential_definition.name == 'account_id'
            credential.provider_account.update_attribute(:account_number, credential.value)
          elsif credential.credential_definition.name == 'x509private'
            credential.provider_account.update_attribute(:x509_cert_priv, credential.value)
          elsif credential.credential_definition.name == 'x509public'
            credential.provider_account.update_attribute(:x509_cert_pub, credential.value)
          end
        end
      end
    end
  end

end
