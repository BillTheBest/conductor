# == Schema Information
# Schema version: 20110513164105
#
# Table name: view_states
#
#  uuid       :string(36)      not null, primary key
#  user_id    :integer
#  name       :string(255)     not null
#  controller :string(255)     not null
#  action     :string(255)     not null
#  state      :text
#  created_at :datetime
#  updated_at :datetime
#

class ViewState < ActiveRecord::Base
  set_primary_key :uuid
  belongs_to :user

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :user_id
  validates_presence_of :controller
  validates_presence_of :action
  validates_presence_of :state

  before_create :ensure_uuid
  before_save :strip_session_only_keys

  attr_reader :pending_delete

  def mark_for_deletion
    @pending_delete = true
  end

  def ensure_uuid
    self.uuid = UUIDTools::UUID.timestamp_create.to_s
  end

  # Things that make sense to remember for the session ViewState but not for
  # the saved state -- such as position in the pagination.
  SESSION_ONLY_KEYS = ['page']

  def strip_session_only_keys
    self.state = state.reject { |k,v| SESSION_ONLY_KEYS.include? k }
  end

  def state
    unless read_attribute(:state).blank?
      JSON.load(read_attribute :state)
    end
  end

  def state=(attrs)
    write_attribute :state, JSON.dump(attrs || {})
  end
end