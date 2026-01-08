#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"
require "tiff"
require "compressor"

JP2_LEVEL_MIN = 5
JP2_LAYERS = 8
JP2_ORDER = "RLCP"
JP2_USE_SOP = "yes"
JP2_USE_EPH = "yes"
JP2_MODES = '"RESET|RESTART|CAUSAL|ERTERM|SEGMARK"'
JP2_SLOPE = 42_988

TIFF_DATE_FORMAT = "%Y:%m:%d %H:%M:%S"

# TIFF to JP2/TIFF compression stage
class Compression < Stage
  def run(agenda)
    return unless agenda.any?
    files = image_files.select { |file| agenda.include? file.objid }
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      begin
        compressor = Compressor.new(image_file: image_file, tmpdir: create_tempdir, log: log_collection)
        tiffinfo = compressor.tiffinfo
      rescue => e
        add_error Error.new(e.message, image_file.objid, image_file.file)
        next
      end
      case tiffinfo[:bps]
      when 8
        # It's a contone, so we convert to JP2.
        @bar.step! i, "#{image_file.objid_file} JP2"
        begin
          handle_8_bps_conversion(compressor)
        rescue => e
          add_error Error.new(e.message, image_file.objid, image_file.file)
        end
      when 1
        # It's bitonal, so we G4 compress it.
        @bar.step! i, "#{image_file.objid_file} G4"
        begin
          handle_1_bps_conversion(compressor)
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

  def handle_8_bps_conversion(compressor)
    image_file = compressor.image_file
    tmpdir = compressor.tmpdir

    on_disk_temp_image = compressor.final_image_path.sub(shipment.directory, shipment.tmp_directory)
    system("mkdir -p #{File.dirname(on_disk_temp_image)}")

    compressor.run

    system("cp #{compressor.new_path} #{on_disk_temp_image}")
    system("rm -r #{tmpdir}/*")
    copy_on_success on_disk_temp_image, compressor.final_image_path, image_file.objid
    delete_on_success image_file.path, image_file.objid
  end

  def handle_1_bps_conversion(compressor)
    image_file = compressor.image_file
    tiffinfo = compressor.tiffinfo
    tmpdir = compressor.tmpdir

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

  def copy_tiff_metadata(path, destination)
    cmd = "exiftool -tagsFromFile #{path}" \
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
