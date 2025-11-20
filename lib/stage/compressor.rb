#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"
require "tiff"

JP2_LEVEL_MIN = 5
JP2_LAYERS = 8
JP2_ORDER = "RLCP"
JP2_USE_SOP = "yes"
JP2_USE_EPH = "yes"
JP2_MODES = '"RESET|RESTART|CAUSAL|ERTERM|SEGMARK"'
JP2_SLOPE = 42_988

TIFF_DATE_FORMAT = "%Y:%m:%d %H:%M:%S"

# TIFF to JP2/TIFF compression stage
class Compressor < Stage # rubocop:disable Metrics/ClassLength
  def run(agenda) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    return unless agenda.any?

    files = image_files.select { |file| agenda.include? file.objid }
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      begin
        tiffinfo = TIFF.new(image_file.path).info
      rescue => e
        add_error Error.new(e.message, image_file.objid, image_file.file)
        next
      end
      case tiffinfo[:bps]
      when 8
        # It's a contone, so we convert to JP2.
        @bar.step! i, "#{image_file.objid_file} JP2"
        begin
          handle_8_bps_conversion(image_file, tiffinfo)
        rescue => e
          add_error Error.new(e.message, image_file.objid, image_file.file)
        end
      when 1
        # It's bitonal, so we G4 compress it.
        @bar.step! i, "#{image_file.objid_file} G4"
        begin
          handle_1_bps_conversion(image_file, tiffinfo)
        rescue => e
          add_error Error.new(e.message, image_file.objid, image_file.file)
        end
      else
        add_error Error.new("invalid source TIFF BPS #{tiffinfo[:bps]}",
          image_file.objid, image_file.file)
      end
    end
  end

  private

  def handle_8_bps_conversion(image_file, tiffinfo) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tmpdir = create_tempdir
    sparse = File.join(tmpdir, "sparse.tif")
    new_image = File.join(tmpdir, "new.jp2")
    final_image_name = File.basename(image_file.path, ".*") + ".jp2"
    final_image = File.join(File.dirname(image_file.path), final_image_name)
    document_name = File.join(shipment.objid_to_path(image_file.objid),
      final_image_name)
    on_disk_temp_image = final_image.sub(shipment.directory, shipment.tmp_directory)
    system("mkdir -p #{File.dirname(on_disk_temp_image)}")

    # We don't want any XMP metadata to be copied over on its own. If
    # it's been a while since we last ran exiftool, this might take a sec.
    remove_tiff_metadata(image_file.path, sparse)

    remove_tiff_alpha(sparse) if tiffinfo[:alpha]

    strip_tiff_profiles(sparse) if tiffinfo[:icc]

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
    compress_jp2(sparse, new_image, tiffinfo)
    # We have our JP2; we can remove the middle TIFF. Then we try
    # to grab metadata from the original TIFF. This should be very
    # quick since we just used exiftool a few lines back.
    copy_jp2_metadata(image_file.path, new_image, document_name, tiffinfo)
    # If our image had an alpha channel, it'll be gone now, and
    # the XMP data needs to reflect that (previously, we were
    # taking that info from the original image).
    copy_jp2_alphaless_metadata(sparse, new_image) if tiffinfo[:alpha]
    system("cp #{new_image} #{on_disk_temp_image}")
    system("rm -r #{tmpdir}/*")
    copy_on_success on_disk_temp_image, final_image, image_file.objid
    delete_on_success image_file.path, image_file.objid
  end

  def jp2_clevels(tiffinfo)
    # Get the width and height, figure out which is larger.
    size = [tiffinfo[:width], tiffinfo[:height]].max
    # Calculate appropriate Clevels.
    clevels = (Math.log(size.to_i / 100.0) / Math.log(2)).to_i
    clevels < JP2_LEVEL_MIN ? JP2_LEVEL_MIN : clevels
  end

  def remove_tiff_metadata(path, destination)
    cmd = "exiftool -XMP:All= -MakerNotes:All= #{path} -o #{destination}"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def remove_tiff_alpha(path)
    tmp = path + ".alphaoff"
    cmd = "convert #{path} -alpha off #{tmp}"
    status = Command.new(cmd).run
    log cmd, status[:time]
    FileUtils.mv(tmp, path)
  end

  def strip_tiff_profiles(path) # rubocop:disable Metrics/MethodLength
    tmp = path + ".stripped"
    cmd = "convert #{path} -strip #{tmp}"
    begin
      status = Command.new(cmd).run
    rescue => e
      warning = "couldn't remove ICC profile (#{cmd}) (#{e.message})"
      add_warning Error.new(warning, objid_from_path(path), path)
    else
      log cmd, status[:time]
      FileUtils.mv(tmp, path)
    end
  end

  def compress_jp2(source, destination, tiffinfo) # rubocop:disable Metrics/MethodLength
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
    log cmd, status[:time]
  end

  def copy_jp2_metadata(source, destination, document_name, tiffinfo) # rubocop:disable Metrics/MethodLength
    # If the original image has a date, we want it. If not, we
    # want to add the current date.
    # date "%Y-%m-%dT%H:%M:%S"
    datetime = if tiffinfo[:date_time]
      "-IFD0:ModifyDate>XMP-tiff:DateTime"
    else
      "-XMP-tiff:DateTime=#{Time.now.strftime("%FT%T")}"
    end
    cmd = "exiftool -tagsFromFile #{source}"                  \
          " '-XMP-dc:source=#{document_name}'"                \
          " '-XMP-tiff:Compression=JPEG 2000'"                \
          " '-IFD0:ImageWidth>XMP-tiff:ImageWidth'"           \
          " '-IFD0:ImageHeight>XMP-tiff:ImageHeight'"         \
          " '-IFD0:BitsPerSample>XMP-tiff:BitsPerSample'"     \
          " '-IFD0:PhotometricInterpretation>XMP-tiff:"       \
          "PhotometricInterpretation'"                        \
          " '-IFD0:Orientation>XMP-tiff:Orientation'"         \
          " '-IFD0:SamplesPerPixel>XMP-tiff:SamplesPerPixel'" \
          " '-IFD0:XResolution>XMP-tiff:XResolution'"         \
          " '-IFD0:YResolution>XMP-tiff:YResolution'"         \
          " '-IFD0:ResolutionUnit>XMP-tiff:ResolutionUnit'"   \
          " '-IFD0:Artist>XMP-tiff:Artist'"                   \
          " '-IFD0:Make>XMP-tiff:Make'"                       \
          " '-IFD0:Model>XMP-tiff:Model'"                     \
          " '-IFD0:Software>XMP-tiff:Software'"               \
          " '#{datetime}'"                                    \
          " -overwrite_original #{destination}"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def copy_jp2_alphaless_metadata(source, destination)
    cmd = "exiftool -tagsFromFile #{source}" \
            " '-IFD0:BitsPerSample>XMP-tiff:BitsPerSample'"     \
            " '-IFD0:SamplesPerPixel>XMP-tiff:SamplesPerPixel'" \
            " '-IFD0:PhotometricInterpretation>XMP-tiff:"       \
            "PhotometricInterpretation'"                        \
            " -overwrite_original '#{destination}'"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def handle_1_bps_conversion(image_file, tiffinfo) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    tmpdir = create_tempdir
    compressed = File.join(tmpdir,
      "#{File.basename(image_file.path)}-compressed")
    page1 = File.join(tmpdir, "#{File.basename(image_file.path)}-page1")
    compress_tiff(image_file.path, compressed)
    copy_tiff_metadata(image_file.path, compressed)
    copy_tiff_page1(compressed, page1)
    FileUtils.rm(compressed)
    write_tiff_date_time page1 unless tiffinfo[:date_time]
    write_tiff_document_name(image_file, page1)
    if tiffinfo[:software]
      write_tiff_software(page1, tiffinfo[:software])
    else
      add_warning Error.new("could not extract software", image_file.objid,
        image_file.path)
    end
    copy_on_success page1, image_file.path, image_file.objid
  end

  # Try to compress the image. This is the only part of this step
  # that should take any time. It should take a second or so.
  def compress_tiff(path, destination)
    cmd = "tifftopnm #{path} | pnmtotiff -g4 -rowsperstrip" \
          " 196136698 > #{destination}"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def copy_tiff_metadata(path, destination) # rubocop:disable Metrics/MethodLength
    cmd = "exiftool -tagsFromFile #{path}"     \
          " '-IFD0:DocumentName'"              \
          " '-IFD0:ImageDescription='"         \
          " '-IFD0:Orientation'"               \
          " '-IFD0:XResolution'"               \
          " '-IFD0:YResolution'"               \
          " '-IFD0:ResolutionUnit'"            \
          " '-IFD0:ModifyDate'"                \
          " '-IFD0:Artist'"                    \
          " '-IFD0:Make'"                      \
          " '-IFD0:Model'"                     \
          " '-IFD0:Software'"                  \
          " -overwrite_original '#{destination}'"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def copy_tiff_page1(path, destination)
    cmd = "tiffcp #{path},0 #{destination}"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  # Set the document name with objid/image.tif
  def write_tiff_document_name(image_file, destination)
    tiff = TIFF.new(destination)
    tiffset = tiff.set(TIFF::TIFFTAG_DOCUMENTNAME, image_file.objid_file)
    log tiffset[:cmd], tiffset[:time]
  end

  # Remove ImageMagick software tag (if it exists) and replace with original
  def write_tiff_software(path, software)
    cmd = "exiftool -IFD0:Software= -overwrite_original #{path}"
    status = Command.new(cmd).run
    log cmd, status[:time]
    cmd = "tiffset -s 305 '#{software}' #{path}"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def write_tiff_date_time(path)
    date = Time.now.strftime(TIFF_DATE_FORMAT)
    cmd = "tiffset -s 306 '#{date}' #{path}"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end
end
