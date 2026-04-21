class ImageFile
  attr_reader :objid, :path, :objid_file, :file

  def initialize(objid, path, objid_file, file)
    @objid = objid # barcode ex: barcode
    @path = path # full path to the file /maindir/shipment/source/barcode
    @objid_file = objid_file # objid/filename ex: barcode/01.tif
    @file = file # filename ex 01.tif
  end

  def checksum
    Digest::SHA256.file(path).hexdigest
  end
end
