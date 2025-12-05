require "tiff"
class Compressor
  attr_reader :tiffinfo, :image_file, :tmpdir
  def initialize(image_file:, tmpdir:, shipment: "whatever", log: "whatever")
    @image_file = image_file
    @tiffinfo = TIFF.new(image_file.path).info
    @tmpdir = tmpdir
    @shipment = shipment
    @log = log
  end

  def sparse_path
    @sparse ||= File.join(tmpdir, "sparse.tif")
  end
end

module ExifTool
  def remove_tiff_metadata(source:, destination:)
    cmd = "exiftool -XMP:All= -MakerNotes:All= #{path} -o #{destination}"
    status = Command.new(cmd).run
    OpenStruct.new(command: cmd, time: status[:time])
  end
end
