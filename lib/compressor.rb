require "tiff"
require "ostruct"
module ExifTool
  def self.remove_tiff_metadata(source:, destination:)
    cmd = "exiftool -XMP:All= -MakerNotes:All= #{source} -o #{destination}"
    status = Command.new(cmd).run
    OpenStruct.new(command: cmd, time: status[:time])
  end

  def self.remove_tiff_alpha(path)
    tmp = path + ".alphaoff"
    cmd = "convert #{path} -alpha off #{tmp}"
    status = Command.new(cmd).run
    FileUtils.mv(tmp, path)
    OpenStruct.new(command: cmd, time: status[:time])
  end
end

class Compressor
  attr_reader :tiffinfo, :image_file, :tmpdir
  def initialize(image_file:, tmpdir:, shipment: "whatever", log: "whatever")
    @image_file = image_file
    @tiffinfo = TIFF.new(image_file.path).info
    @tmpdir = tmpdir
    @shipment = shipment
    @log = log
  end

  def run
    # We don't want any XMP metadata to be copied over on its own. If
    # it's been a while since we last ran exiftool, this might take a sec.
    @log.log_it ExifTool.remove_tiff_metadata(source: @image_file.path, destination: sparse_path)
    # @log.log_it ExifTool.remove_tiff_alpha(sparse_path) if tiffinfo[:alpha]
  end

  def sparse_path
    @sparse_path ||= File.join(tmpdir, "sparse.tif")
  end
end
