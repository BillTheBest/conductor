require 'util/repository_manager'
require 'util/image_descriptor_xml'

class ImageDescriptor < ActiveRecord::Base
  has_many :image_descriptor_targets,  :dependent => :destroy

  #TODO: validations

  def update_xml_attributes!(opts = {})
    doc = ImageDescriptorXML.new(self[:xml])
    doc.name = opts[:name] if opts[:name]
    doc.platform = opts[:platform] if opts[:platform]
    doc.description = opts[:description] if opts[:description]
    doc.services = opts[:services] if opts[:services]
    doc.packages = opts[:packages] if opts[:packages]
    self[:xml] = doc.to_xml
    @xml = doc
    save!
  end

  def xml
    unless @xml
      @xml = ImageDescriptorXML.new(self[:xml].to_s)
    end
    return @xml
  end
end