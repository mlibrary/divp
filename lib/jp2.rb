#!/usr/bin/env ruby
# frozen_string_literal: true

require "command"

# JP2 info utility
class JP2
  def initialize(path)
    @path = path
  end

  # Run tiffinfo command and return output text block
  def info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    cmd = "exiftool #{@path}"
    status = Command.new(cmd).run
    jp2info = extract_fields(status[:stdout])
    jp2info[:cmd] = cmd
    jp2info[:time] = status[:time]
    jp2info[:warnings] = []
    jp2info[:errors] = []
    status[:stderr].chomp.split("\n").each do |err|
      if /warning/i.match? err
        jp2info[:warnings] << err
      else
        jp2info[:errors] << err
      end
    end
    jp2info
  end

  private

  def extract_fields(info)
    fields = {}
    match = info.match(/^X Resolution\s+:\s+(\d+)/)
    fields[:x_res] = match[1].to_i unless match.nil?
    match = info.match(/^Y Resolution\s+:\s+(\d+)/)
    fields[:y_res] = match[1].to_i unless match.nil?
    match = info.match(/^Resolution Unit\s+:\s+(.+)/)
    fields[:res_unit] = match[1] unless match.nil?
    fields
  end
end
