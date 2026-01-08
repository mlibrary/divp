require "tiff"
require "ostruct"

module Kakadu
  def self.compress(source, destination, tiffinfo)
    clevels = jp2_clevels(tiffinfo)
    cmd = "kdu_compress -quiet -i #{source} -o #{destination}" \
          " 'Clevels=#{clevels}'" \
          " 'Clayers=#{JP2_LAYERS}'" \
          " 'Corder=#{JP2_ORDER}'" \
          " 'Cuse_sop=#{JP2_USE_SOP}'" \
          " 'Cuse_eph=#{JP2_USE_EPH}'" \
          " Cmodes=#{JP2_MODES}" \
          " -no_weights -slope '#{JP2_SLOPE}'"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.jp2_clevels(tiffinfo)
    # Get the width and height, figure out which is larger.
    size = [tiffinfo[:width], tiffinfo[:height]].max
    # Calculate appropriate Clevels.
    clevels = (Math.log(size.to_i / 100.0) / Math.log(2)).to_i
    (clevels < JP2_LEVEL_MIN) ? JP2_LEVEL_MIN : clevels
  end
end

module ExifTool
  def self.remove_tiff_metadata(source:, destination:)
    cmd = "exiftool -XMP:All= -MakerNotes:All= #{source} -o #{destination}"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.copy_jp2_metadata(source, destination, document_name, tiffinfo)
    # If the original image has a date, we want it. If not, we
    # want to add the current date.
    # date "%Y-%m-%dT%H:%M:%S"
    datetime = if tiffinfo[:date_time]
      "-IFD0:ModifyDate>XMP-tiff:DateTime"
    else
      "-XMP-tiff:DateTime=#{Time.now.strftime("%FT%T")}"
    end
    cmd = "exiftool -tagsFromFile #{source}" \
          " '-XMP-dc:source=#{document_name}'" \
          " '-XMP-tiff:Compression=JPEG 2000'" \
          " '-IFD0:ImageWidth>XMP-tiff:ImageWidth'" \
          " '-IFD0:ImageHeight>XMP-tiff:ImageHeight'" \
          " '-IFD0:BitsPerSample>XMP-tiff:BitsPerSample'" \
          " '-IFD0:PhotometricInterpretation>XMP-tiff:" \
          "PhotometricInterpretation'" \
          " '-IFD0:Orientation>XMP-tiff:Orientation'" \
          " '-IFD0:SamplesPerPixel>XMP-tiff:SamplesPerPixel'" \
          " '-IFD0:XResolution>XMP-tiff:XResolution'" \
          " '-IFD0:YResolution>XMP-tiff:YResolution'" \
          " '-IFD0:ResolutionUnit>XMP-tiff:ResolutionUnit'" \
          " '-IFD0:Artist>XMP-tiff:Artist'" \
          " '-IFD0:Make>XMP-tiff:Make'" \
          " '-IFD0:Model>XMP-tiff:Model'" \
          " '-IFD0:Software>XMP-tiff:Software'" \
          " '#{datetime}'" \
          " -overwrite_original #{destination}"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end
end

module ImageMagick
  def self.remove_tiff_alpha(path)
    tmp = path + ".alphaoff"
    cmd = "convert #{path} -alpha off #{tmp}"
    status = Command.new(cmd).run
    FileUtils.mv(tmp, path)
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.strip_tiff_profiles(path)
    tmp = path + ".stripped"
    cmd = "convert #{path} -strip #{tmp}"
    begin
      status = Command.new(cmd).run
    rescue => e
      warning = "couldn't remove ICC profile (#{cmd}) (#{e.message})"
      LogEntry.warning(error: Error.new(warning, nil, path))
    else
      FileUtils.mv(tmp, path)
      LogEntry.info(command: cmd, time: status[:time])
    end
  end
end

class Compressor
  attr_reader :tiffinfo, :image_file, :tmpdir
  def initialize(image_file:, tmpdir:, log: "whatever")
    @image_file = image_file
    @tiffinfo = TIFF.new(image_file.path).info
    @tmpdir = tmpdir
    @log = log
  end

  def run(compression_tool = Kakadu)
    # We don't want any XMP metadata to be copied over on its own. If
    # it's been a while since we last ran exiftool, this might take a sec.
    @log.log_it ExifTool.remove_tiff_metadata(source: image_file.path, destination: sparse_path)
    @log.log_it ImageMagick.remove_tiff_alpha(sparse_path) if tiffinfo[:alpha]
    @log.log_it ImageMagick.strip_tiff_profiles(sparse_path) if tiffinfo[:icc]
    @log.log_it compression_tool.compress(sparse_path, new_path, tiffinfo)
    @log.log_it ExifTool.copy_jp2_metadata(image_file.path, new_path, document_name, tiffinfo)

    # copy_jp2_alphaless_metadata(sparse, new_image) if tiffinfo[:alpha]
  end

  def document_name
    objid_file_parts = image_file.objid_file.split("/")
    final_image_name = File.basename(objid_file_parts.last, ".*") + ".jp2"
    objid_file_parts[-1] = final_image_name
    File.join(objid_file_parts)
  end

  def sparse_path
    @sparse_path ||= File.join(tmpdir, "sparse.tif")
  end

  def new_path
    @new_path ||= File.join(tmpdir, "new.jp2")
  end
end
