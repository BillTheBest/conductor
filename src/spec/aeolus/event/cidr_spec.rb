require 'event_spec_helper'

module Aeolus
  module Event
    describe Cidr do

      describe "#new" do
        it "should set default values on creation" do
          event = Cidr.new
          event.target.should == "syslog"
        end
        it "should set all attributes passed in" do
          event = Cidr.new({:owner=>'fred', :hardware_profile => 'm1.large'})
          event.owner.should == 'fred'
          event.hardware_profile.should == 'm1.large'
        end
        it "should set class default overrides" do
          event = Cidr.new
          event.event_id.should =='020001'
        end
      end

      describe "#changed_fields" do
        it "should return a list if changes present" do
          event = Cidr.new({:owner=>'sseago',:old_values=>{:owner=>'jayg'}})
          result = event.changed_fields
          result.should == [:owner]
        end
      end
    end
  end
end
