#!/usr/bin/env ruby
# frozen_string_literal: true

require "command"

# TIFF info and tagging utility
class TIFF
  TIFFTAG_DOCUMENTNAME = 269
  TIFFTAG_MAKE = 271
  TIFFTAG_MODEL = 272
  TIFFTAG_ORIENTATION = 274
  TIFFTAG_SOFTWARE = 305
  TIFFTAG_ARTIST = 315

  def initialize(path)
    @path = path
  end

  # Run tiffinfo command and return output text block
  def info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cmd = "tiffinfo #{@path}"
    status = Command.new(cmd).run
    tiffinfo = extract_fields(status[:stdout])
    tiffinfo[:cmd] = cmd
    tiffinfo[:time] = status[:time]
    tiffinfo[:warnings] = []
    tiffinfo[:errors] = []
    status[:stderr].chomp.split("\n").each do |err|
      if /warning/i.match? err
        tiffinfo[:warnings] << err
      else
        tiffinfo[:errors] << err
      end
    end
    tiffinfo
  end

  def set(tag, value) # rubocop:disable Metrics/MethodLength
    cmd = "tiffset -s #{tag} '#{value}' #{@path}"
    status = Command.new(cmd).run
    tiffset = {cmd: cmd,
               time: status[:time],
               warnings: [],
               errors: []}
    status[:stderr].chomp.split("\n").each do |err|
      if /warning/i.match? err
        tiffset[:warnings] << err
      else
        tiffset[:errors] << err
      end
    end
    tiffset
  end

  private

  def extract_fields(info) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    h = {}
    m = info.match(/Resolution:\s(\d+(?:\.\d+)?),\s*(\d+(?:\.\d+)?)\s+(.*)/)
    unless m.nil?
      h[:x_res] = m[1].to_i
      h[:y_res] = m[2].to_i
      h[:res_unit] = m[3]
    end
    m = info.match(%r{Bits/Sample:\s(\d+)})
    h[:bps] = m[1].to_i unless m.nil?
    m = info.match(%r{Samples/Pixel:\s(\d+)})
    h[:spp] = m[1].to_i unless m.nil?
    h[:alpha] = /Extra\sSamples:\s1<unassoc-alpha>/.match? info
    h[:icc] = /ICC\sProfile:\s<present>/.match? info
    m = info.match(/Image\sWidth:\s(\d+)\sImage\sLength:\s(\d+)/)
    h[:width] = m[1].to_i
    h[:height] = h[:length] = m[2].to_i
    m = info.match(/DateTime:\s(.+)/)
    h[:date_time] = m[1] unless m.nil?
    m = info.match(/Software:\s(.+)/)
    h[:software] = m[1] unless m.nil?
    h
  end
end
