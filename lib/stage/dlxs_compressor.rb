#!/usr/bin/env ruby
# frozen_string_literal: true

require "command"
require "stage"

# JP2-to-TIFF conversion stage for DLXS
class DLXSCompressor < Stage # rubocop:disable Metrics/ClassLength
  def run(agenda) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return unless agenda.any?

    files = image_files("jp2").select { |file| agenda.include? file.objid }
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      @bar.step! i, image_file.objid_file
      begin
        handle_conversion image_file
      rescue => e
        add_error Error.new(e.message, image_file.objid, image_file.path)
      end
    end
  end

  private

  def handle_conversion(image_file) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    basename = File.basename(image_file.path, ".*")
    tmpdir = create_tempdir basename
    source = File.join(tmpdir, "source.tif")
    bitonal = File.join(tmpdir, "bitonal.tif")
    final_image_name = basename + ".tif"
    final_image = File.join(File.dirname(image_file.path), final_image_name)
    expand_jp2 image_file.path, source
    tiff_to_pgm tmpdir
    pgm_to_bitonal tmpdir
    source_image = File.join(shipment.objid_to_path(image_file.objid),
      final_image_name)
    copy_metadata image_file.path, bitonal, source_image
    copy_on_success bitonal, final_image, image_file.objid
    copy_on_success image_file.path, jp2_name(image_file.path),
      image_file.objid
    delete_on_success image_file.path
  end

  def copy_metadata(source, destination, source_image) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cmd = <<~CMD.tr("\n", " ")
      exiftool -tagsFromFile #{source}
      '-IFD0:DocumentName=#{source_image}'
      '-IFD0:Orientation<XMP-tiff:Orientation'
      '-IFD0:ResolutionUnit<XMP-tiff:ResolutionUnit'
      '-IFD0:Artist<XMP-tiff:Artist'
      '-IFD0:Make<XMP-tiff:Make'
      '-IFD0:Model<XMP-tiff:Model'
      '-IFD0:Software<XMP-tiff:Software'
      '-IFD0:ModifyDate<XMP-tiff:DateTime'
      '-IFD0:ImageDescription=extracted from JP2'
       -overwrite_original #{destination}
    CMD
    status = Command.new(cmd).run
    log cmd, status[:time]
    xres = get_x_resolution source
    yres = get_y_resolution source
    return unless /^\d+$/.match?(xres) && /^\d+$/.match?(yres)

    cmd = <<~CMD.tr("\n", " ")
      exiftool -q
      '-IFD0:XResolution=#{xres.to_i * 3 / 2}'
      '-IFD0:YResolution=#{yres.to_i * 3 / 2}'
      -overwrite_original #{destination}
    CMD
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  def get_x_resolution(path)
    cmd = "exiftool -XMP-tiff:XResolution #{path} | sed -e 's/^.*: *//'"
    status = Command.new(cmd).run
    log cmd, status[:time]
    status[:stdout].chomp
  end

  def get_y_resolution(path)
    cmd = "exiftool -XMP-tiff:YResolution #{path} | sed -e 's/^.*: *//'"
    status = Command.new(cmd).run
    log cmd, status[:time]
    status[:stdout].chomp
  end

  # Converts 'source.tif' to 'source.pgm' in temporary directory
  def tiff_to_pgm(dir) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    source = File.join(dir, "source.tif")
    pnm = File.join(dir, "source.pnm")
    pgm = File.join(dir, "source.pgm")
    cmd = "tifftopnm #{source} > #{pnm}"
    status = Command.new(cmd).run
    log cmd, status[:time]
    FileUtils.rm source
    header = nil
    File.open(pnm, "rb") do |file|
      header = file.read(2).unpack("A2")
    end
    case header[0]
    when "P5"
      FileUtils.mv pnm, pgm
      log "mv #{pnm} #{pgm}"
    when "P6"
      cmd = "ppmtopgm #{pnm} > #{pgm}"
      status = Command.new(cmd).run
      log cmd, status[:time]
      FileUtils.rm pnm
    else
      raise "PNM header '#{header}' not in {P5,P6}"
    end
  end

  # Converts 'source.pgm' to 'bitonal.tif' in temporary directory
  def pgm_to_bitonal(dir)
    pgm = File.join(dir, "source.pgm")
    bitonal = File.join(dir, "bitonal.tif")
    cmd = "pnmscale 1.5 #{pgm} | pgmnorm | pgmtopbm -threshold \
      | pnmtotiff -g4 -rowsperstrip 196136698 > #{bitonal}"
    status = Command.new(cmd).run
    log cmd, status[:time]
    FileUtils.rm pgm
  end

  # Expand existing jp2 into tif in temp directory
  def expand_jp2(src, dest)
    cmd = "kdu_expand -quiet -i '#{src}' -o '#{dest}'"
    status = Command.new(cmd).run
    log cmd, status[:time]
  end

  # Replace first leading zero with 'p'
  def jp2_name(path)
    File.join(File.dirname(path), File.basename(path).sub(/^\d/, "p"))
  end
end
