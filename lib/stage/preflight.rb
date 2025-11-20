#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "luhn"
require "stage"

# Shipment directory well-formedness and content check.
# The only changes this stage makes to the filesystem is deletion
# of Thumbs.db and .DS_Store
class Preflight < Stage
  TIFF_REGEX = /^\d{8}\.tif$/i.freeze
  JP2_REGEX = /^\d{8}\.jp2$/i.freeze
  REMOVABLE_FILES = %w[.DS_Store Thumbs.db].freeze
  IGNORABLE_FILES = %w[aiim.tif aiim.jp2 notes.txt rit.tif rit.jp2
    checksum.md5 prodnote.tif].freeze

  # NOTE: currently there is no config to tell the processor to only look
  # for TIFF files and emit an error on JP2 files. The simplest approach
  # would probably be to put a list of permitted image file extensions
  # in the YML config.
  def self.image_file?(file)
    TIFF_REGEX.match?(file) || JP2_REGEX.match?(file)
  end

  def self.removable_files
    REMOVABLE_FILES
  end

  def self.ignorable_files
    IGNORABLE_FILES
  end

  def run(agenda) # rubocop:disable Metrics/AbcSize
    shipment.metadata[:initial_barcodes] = shipment.objids
    if shipment.metadata[:initial_barcodes].none?
      add_error Error.new("no objids in #{shipment_directory}")
    end
    @bar.steps = steps agenda
    @bar.next! "validate #{File.split(shipment_directory)[-1]}"
    validate_shipment_directory
    validate_objects agenda
    return if fatal_error?

    setup_source_directory
  end

  private

  def steps(agenda)
    1 + shipment.objids.count + agenda.count +
      (File.directory?(source_directory) ? 0 : shipment.objids.count)
  end

  def validate_objects(agenda)
    agenda.each do |objid|
      err = shipment.validate_objid objid
      add_warning Error.new(err, objid) unless err.nil?
      @bar.next! "validate #{objid}"
      validate_objid_directory objid
    end
  end

  # A shipment directory is valid if it contains only objid directories,
  # a source directory, and status.json
  def validate_shipment_directory # rubocop:disable Metrics/MethodLength
    Dir.entries(shipment_directory).sort.each do |entry|
      next if %w[. .. source tmp status.json].include? entry

      path = File.join(shipment_directory, entry)
      next if File.directory? path

      if self.class.removable_files.include? entry
        add_warning Error.new("unnecessary file deleted", nil, path)
        delete_on_success path
      else
        add_error Error.new("unknown file", nil, path)
      end
    end
  end

  # objid directory must include one or more TIFF files,
  # and a few other exceptions grandfathered by just_do_everything.sh
  # No directories are allowed
  def validate_objid_directory(objid) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    have_image = false
    objid_directory = shipment.objid_directory(objid)
    Dir.entries(objid_directory).sort.each do |entry|
      next if %w[. ..].include? entry

      path = File.join(objid_directory, entry)
      if File.directory? path
        add_error Error.new("illegal objid subdirectory '#{entry}'", objid)
      elsif self.class.image_file? entry
        have_image = true
      elsif self.class.ignorable_files.include? entry
        add_warning Error.new("file ignored", objid, entry)
      elsif self.class.removable_files.include? entry
        add_warning Error.new("file deleted", objid, entry)
        delete_on_success path
      else
        add_error Error.new("unknown file", objid, entry)
      end
    end
    add_error Error.new("no image files found", objid) unless have_image
  end

  def setup_source_directory
    shipment.setup_source_directory do |objid|
      @bar.next! "setup source/#{objid}"
    end
    shipment.checksum_source_directory do |objid|
      @bar.next! "checksum source/#{objid}"
    end
  end
end
