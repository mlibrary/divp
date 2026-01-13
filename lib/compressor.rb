require "tiff"

module Kakadu
  JP2_LEVEL_MIN = 5
  JP2_LAYERS = 8
  JP2_ORDER = "RLCP"
  JP2_USE_SOP = "yes"
  JP2_USE_EPH = "yes"
  JP2_MODES = '"RESET|RESTART|CAUSAL|ERTERM|SEGMARK"'
  JP2_SLOPE = 42_988
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

  def self.copy_jp2_alphaless_metadata(source, destination)
    cmd = "exiftool -tagsFromFile #{source}" \
            " '-IFD0:BitsPerSample>XMP-tiff:BitsPerSample'" \
            " '-IFD0:SamplesPerPixel>XMP-tiff:SamplesPerPixel'" \
            " '-IFD0:PhotometricInterpretation>XMP-tiff:" \
            "PhotometricInterpretation'" \
            " -overwrite_original '#{destination}'"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.copy_tiff_metadata(source, destination)
    cmd = "exiftool -tagsFromFile #{source}" \
          " '-IFD0:DocumentName'" \
          " '-IFD0:ImageDescription='" \
          " '-IFD0:Orientation'" \
          " '-IFD0:XResolution'" \
          " '-IFD0:YResolution'" \
          " '-IFD0:ResolutionUnit'" \
          " '-IFD0:ModifyDate'" \
          " '-IFD0:Artist'" \
          " '-IFD0:Make'" \
          " '-IFD0:Model'" \
          " '-IFD0:Software'" \
          " -overwrite_original '#{destination}'"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.clear_software_tag(path)
    cmd = "exiftool -IFD0:Software= -overwrite_original #{path}"
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

module TiffTools
  TIFFTAGS = {
    document_name: 269,
    date_time: 306,
    software: 305
  }

  def self.date_time_format(datetime)
    datetime.strftime("%Y:%m:%d %H:%M:%S")
  end

  def self.compress(source, destination)
    cmd = "tifftopnm #{source} | pnmtotiff -g4 -rowsperstrip" \
          " 196136698 > #{destination}"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.copy_page_1(source, destination)
    cmd = "tiffcp #{source},0 #{destination}"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end

  def self.set_tag(path:, tag:, value:)
    cmd = "tiffset -s #{TIFFTAGS[tag]}, '#{value}' #{path}"
    status = Command.new(cmd).run
    LogEntry.info(command: cmd, time: status[:time])
  end
end

class Compressor
  attr_reader :tiffinfo, :image_file, :tmpdir

  def self.for(image_file:, tmpdir:, log: "whatever", now: Time.now)
    tiffinfo = TIFF.new(image_file.path).info
    klass = case tiffinfo[:bps]
    when 8
      Compressor::Color
    when 1
      Compressor::Bitonal
    else
      Compressor
    end
    klass.new(image_file:, tmpdir:, log: log, now: now)
  end

  def initialize(image_file:, tmpdir:, log:, now:)
    @image_file = image_file
    @tiffinfo = TIFF.new(image_file.path).info
    @tmpdir = tmpdir
    @log = log
    @now = now
  end

  def run
    raise NotImplementedError
  end

  def bps
    @tiffinfo[:bps]
  end

  private

  def log_it(log_entry)
    @log.log_it log_entry
  end
end

class Compressor::Color < Compressor
  def run(compression_tool = Kakadu)
    # We don't want any XMP metadata to be copied over on its own. If
    # it's been a while since we last ran exiftool, this might take a sec.
    log_it ExifTool.remove_tiff_metadata(source: image_file.path, destination: sparse_path)
    log_it ImageMagick.remove_tiff_alpha(sparse_path) if tiffinfo[:alpha]
    log_it ImageMagick.strip_tiff_profiles(sparse_path) if tiffinfo[:icc]

    # mrio: copying this note over from Compression.rb. Not sure what it means
    # or implies yet.
    #
    # FIXME: process-tiffs.sh defines this variable but does not
    # use it. Check the original on tang.
    # if /Samples\/Pixel:\s3/.match? metadata
    #  jp2_space = 'sRGB'
    # else
    #  jp2_space = 'sLUM'
    # end

    # We have a TIFF with no XMP now. We try to convert it to JP2.
    # This will always take a second. Other than the initial loading
    # of exiftool libraries, this is the only JP2 step that takes
    # noticeable time.
    log_it compression_tool.compress(sparse_path, new_path, tiffinfo)

    # We have our JP2; we can remove the middle TIFF. Then we try
    # to grab metadata from the original TIFF. This should be very
    # quick since we just used exiftool a few lines back.
    log_it ExifTool.copy_jp2_metadata(image_file.path, new_path, document_name, tiffinfo)

    # If our image had an alpha channel, it'll be gone now, and
    # the XMP data needs to reflect that (previously, we were
    # taking that info from the original image).
    log_it ExifTool.copy_jp2_alphaless_metadata(sparse_path, new_path) if tiffinfo[:alpha]
  end

  def final_image_path
    File.join(File.dirname(image_file.path), final_image_name)
  end

  def document_name
    objid_file_parts = image_file.objid_file.split("/")
    objid_file_parts[-1] = final_image_name
    File.join(objid_file_parts)
  end

  def final_image_name
    File.basename(image_file.file, ".*") + ".jp2"
  end

  def sparse_path
    @sparse_path ||= File.join(tmpdir, "sparse.tif")
  end

  def new_path
    @new_path ||= File.join(tmpdir, "new.jp2")
  end
end

class Compressor::Bitonal < Compressor
  def run
    # Try to compress the image. This is the only part of this step
    # that should take any time. It should take a second or so.
    log_it TiffTools.compress(image_file.path, compressed_path)

    log_it ExifTool.copy_tiff_metadata(image_file.path, compressed_path)

    log_it TiffTools.copy_page_1(compressed_path, page1_path)
    log_it TiffTools.set_tag(path: page1_path, tag: :date_time, value: TiffTools.date_time_format(@now)) unless tiffinfo[:date_time]

    # Set the document name with objid/image.tif
    log_it TiffTools.set_tag(path: page1_path, tag: :document_name, value: image_file.objid_file)
    if tiffinfo[:software]
      log_it ExifTool.clear_software_tag(page1_path)
      log_it TiffTools.set_tag(path: page1_path, tag: :software, value: tiffinfo[:software])
    else
      log_it LogEntry.warning(error: Error.new("could not extract software", image_file.objid, image_file.path))
    end
  end

  def compressed_path
    @compressed_path ||= File.join(tmpdir, "#{File.basename(image_file.path)}-compressed")
  end

  def page1_path
    @page1_path ||= File.join(tmpdir, "#{File.basename(image_file.path)}-page1")
  end
end
