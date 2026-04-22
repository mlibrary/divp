class ImageFile
  attr_reader :objid, :path, :objid_file, :file

  def self.file_type(file_path)
    File.extname(file_path).split(".").last
  end

  def self.source_for(objid_file:, source_path:, objid_config:)
    objid, file = objid_config.split_objid_file(objid_file)
    path = File.join(source_path, objid_file)
    new(objid, path, objid_file, file)
  end

  def initialize(objid, path, objid_file, file, objid_config = nil)
    @objid = objid # barcode ex: barcode or adz05h3e.5454.380
    @path = path # full path to the file /maindir/shipment/source/barcode
    @objid_file = objid_file # path within shipment to file. example barcode/01.tif or adz05h3e/5454/380/00000001.tif
    @file = file # filename ex 01.tif
    @objid_config = objid_config
  end

  def file_type
    self.class.file_type(@file)
  end

  def checksum
    Digest::SHA256.file(path).hexdigest
  end
end

class DLXSImageFile < ImageFile
end
