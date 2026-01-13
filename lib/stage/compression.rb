#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"
require "tiff"
require "compressor"

# TIFF to JP2/TIFF compression stage
class Compression < Stage
  def run(agenda)
    return unless agenda.any?
    files = image_files.select { |file| agenda.include? file.objid }
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      begin
        compressor = Compressor.for(image_file: image_file, tmpdir: create_tempdir, log: log_collection)
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

    compressed = compressor.compressed_path
    page1 = compressor.page1_path

    compressor.run

    FileUtils.rm(compressed)

    if tiffinfo[:software]
      write_tiff_software(page1, tiffinfo[:software])
    else
      add_warning Error.new("could not extract software", image_file.objid,
        image_file.path)
    end
    copy_on_success page1, image_file.path, image_file.objid
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
end
