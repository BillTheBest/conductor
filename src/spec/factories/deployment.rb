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

FactoryGirl.define do
  factory :deployment do
    sequence(:name) { |n| "deployment#{n}" }
    association :pool, :factory => :pool
    association :owner, :factory => :user
    after_build do |deployment|
      deployment.deployable_xml = DeployableXML.import_xml_from_url("http://localhost/deployables/deployable1.xml")
    end
  end
  factory :deployment_with_launch_parameters, :parent => :deployment do
    after_build do |deployment|
      deployment.deployable_xml = DeployableXML.import_xml_from_url("http://localhost/deployables/deployable_with_launch_parameters.xml")
    end
  end
end
