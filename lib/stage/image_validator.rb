#!/usr/bin/env ruby
# frozen_string_literal: true

require "command"
require "jp2"
require "stage"
require "tiff"

# TIFF Validation Stage
class ImageValidator < Stage

  def run(agenda)
    return unless agenda.any?

    tiff_files = image_files.select { |file| agenda.include? file.objid }
    jp2_files = image_files("jp2").select { |file| agenda.include? file.objid }
    @bar.steps = tiff_files.count + jp2_files.count
    tiff_files.each do |image_file|
      @bar.next! image_file.objid_file
      tiffinfo = run_tiffinfo image_file
      next if tiffinfo.nil?

      evaluate_tiff image_file, tiffinfo
    end
    jp2_files.each do |image_file|
      @bar.next! image_file.objid_file
      jp2info = run_jp2info image_file
      next if jp2info.nil?

      evaluate_jp2 image_file, jp2info
    end
  end

  private

  def bitonal_res
    config[:bitonal_resolution]
  end

  def contone_res
    config[:contone_resolution]
  end

  # Run tiffinfo command and return output text block
  def run_tiffinfo(image_file)
    begin
      info = TIFF.new(image_file.path).info
    rescue => e
      add_error Error.new(e.message, image_file.objid, image_file.file)
      return nil
    end
    log info[:cmd], info[:time]
    info[:warnings].each do |err|
      add_warning Error.new(err, image_file.objid, image_file.file)
    end
    info[:errors].each do |err|
      add_error Error.new(err, image_file.objid, image_file.file)
    end
    info
  end

  # Resolution line must have 'pixels/inch' unit
  # 'Bits/Sample' line -> bps
  # 'Samples/Pixel' line -> spp
  # bps of 1 requires spp=1 and xres=BITONAL_RES and yres=BITONAL_RES
  # bps of 8 requires spp in [1,3,4] and xres=CONTONE_RES and yres=CONTONE_RES
  def evaluate_tiff(image_file, info)
    if info[:res_unit] != "pixels/inch"
      image_error image_file, "must have pixels/inch, not #{info[:res_unit]}"
    end
    case info[:bps]
    when 1
      evaluate_tiff_1_bps(image_file, info)
    when 8
      evaluate_tiff_8_bps(image_file, info)
    else
      image_error image_file, "can't have BPS #{info[:bps]}"
    end
  end

  def evaluate_tiff_1_bps(image_file, info)
    if info[:spp] != 1
      image_error image_file, "invalid SPP #{info[:spp]} with 1 BPS"
    end
    return unless info[:x_res] != bitonal_res || info[:y_res] != bitonal_res

    image_error image_file, "#{info[:x_res]}x#{info[:y_res]} bitonal"
  end

  def evaluate_tiff_8_bps(image_file, info)
    if [1, 3, 4].include? info[:spp]
      if info[:x_res] != contone_res || info[:y_res] != contone_res
        image_error image_file, "#{info[:x_res]}x#{info[:y_res]} contone"
      end
    else
      image_error image_file, "can't have SPP #{info[:spp]} with 8 BPS"
    end
  end

  def run_jp2info(image_file)
    begin
      info = JP2.new(image_file.path).info
    rescue => e
      add_error Error.new(e.message, image_file.objid, image_file.file)
      return nil
    end
    log info[:cmd], info[:time]
    info[:warnings].each do |err|
      add_warning Error.new(err, image_file.objid, image_file.file)
    end
    info[:errors].each do |err|
      add_error Error.new(err, image_file.objid, image_file.file)
    end
    info
  end

  def evaluate_jp2(image_file, info)
    unless info[:res_unit] == "inches"
      image_error(image_file, "resolution unit '#{info[:res_unit]}'")
    end
    return if info[:x_res] == contone_res && info[:y_res] == contone_res

    image_error image_file, "#{info[:x_res]}x#{info[:y_res]} contone"
  end

  def image_error(image_file, err)
    add_error Error.new(err, image_file.objid, image_file.path)
  end
end

# Original name for this class. This is for backwards compatibility
class TIFFValidator < ImageValidator
end
