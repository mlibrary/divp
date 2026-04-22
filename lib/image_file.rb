class ImageFile
  attr_reader :objid, :path, :objid_file, :file

  PATH_COMPONENTS = 1
  OBJID_SEPARATOR = "/"

  def self.file_type(file_path)
    File.extname(file_path).split(".").last
  end

  def self.source_for(objid_file:, source_path:, objid_config:)
    # components = objid_file.split(File::SEPARATOR)
    objid, file = path_to_parts(objid_file, objid_config) # beginning to second from end
    path = File.join(source_path, objid_file)
    new(objid, path, objid_file, file)
  end

  def self.path_to_parts(objid_file, objid_config)
    components = objid_file.split(File::SEPARATOR)
    objid = path_to_objid(components[0..-2], objid_config)
    file = components[-1] # beginning to second from end
    [objid, file]
  end

  def self.path_to_objid(path_components, objid_config = nil)
    if path_components.count != objid_config.path_components
      raise "WARNING: #{self} is not designed for path components" \
        " other than #{objid_config.path_components} (#{path_components})"
    end

    path_components.join objid_config.separator
  end

  def initialize(objid, path, objid_file, file, config = nil)
    @objid = objid # barcode ex: barcode or adz05h3e.5454.380
    @path = path # full path to the file /maindir/shipment/source/barcode
    @objid_file = objid_file # path within shipment to file. example barcode/01.tif or adz05h3e/5454/380/00000001.tif
    @file = file # filename ex 01.tif
    @config = config
  end

  def document_name
    components = path.split(File::Separator)
    starting_index = (-1 * self.class::PATH_COMPONENTS) - 1
    components[starting_index..].join(File::Separator)
  end

  def file_type
    self.class.file_type(@file)
  end

  def checksum
    Digest::SHA256.file(path).hexdigest
  end
end

class DLXSImageFile < ImageFile
  PATH_COMPONENTS = 3
  OBJID_SEPARATOR = "."
end
