#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "luhn"
require "ostruct"

# Errors arising from trying to destructively manipulate a finalized shipment.
class FinalizedShipmentError < StandardError
end

# Shipment directory class
class Shipment
  PATH_COMPONENTS = 1
  OBJID_SEPARATOR = "/"
  OBJID_CONFIG = OpenStruct.new(path_components: 1, separator: "/")

  attr_reader :metadata

  def self.objid_config
    self::OBJID_CONFIG
  end

  def self.json_create(hash)
    new hash["data"]["dir"], hash["data"]["metadata"]
  end

  def self.top_level_directory_entries(dir)
    Dir.entries(dir).reject do |entry|
      %w[. .. source tmp].include?(entry) ||
        !File.directory?(File.join(dir, entry))
    end
  end

  def self.directory_entries(dir)
    Dir.entries(dir).reject do |entry|
      %w[. ..].include?(entry)
    end
  end

  def self.subdirectories(dir)
    Dir.entries(dir).reject do |entry|
      %w[. ..].include?(entry) ||
        !File.directory?(File.join(dir, entry))
    end
  end

  def initialize(dir, metadata = nil)
    raise "nil dir passed to Shipment#initialize" if dir.nil?
    raise "invalid dir passed to Shipment#initialize" if dir.is_a? Shipment

    @dir = dir
    @metadata = metadata || {}
    @metadata.transform_keys!(&:to_sym)
  end

  def objid_config
    self.class.objid_config
  end

  def image_file_class
    ImageFile
  end

  def item_class
    Item
  end

  def items
    @items = objid_directories.map do |path|
      item_class.new(path: path, objid_config: objid_config)
    end
  end

  def source_items
    return [] unless source_directory_exists?
    source_objid_directories.map do |path|
      item_class.new(path: path, objid_config: objid_config)
    end
  end

  def create_image_file(objid:, file_path:, objid_file:, file:)
    image_file_class.new(
      objid, file_path, objid_file, file, @objid_config
    )
  end

  def to_json(*args)
    {
      "json_class" => self.class.name,
      "data" => {dir: @dir, metadata: @metadata}
    }.to_json(*args)
  end

  def directory
    @dir
  end

  # Should only be necessary when loading from a status.json that has moved.
  # Assign new value and blow away any and all memoized paths.
  def directory=(dir)
    return if @dir == dir

    @dir = dir
    @source_directory = nil
    @tmp_directory = nil
  end

  def source_directory
    @source_directory ||= File.join @dir, "source"
  end

  def top_level_directory_entries
    self.class.top_level_directory_entries(@dir)
  end

  def tmp_directory
    @tmp_directory ||= File.join @dir, "tmp"
  end

  def objid_to_path(objid)
    objid.split(objid_config.separator)
  end

  def objid_directories
    objids.map { |objid| objid_directory objid }
  end

  def objids
    find_objids
  end

  def objid_directory(objid)
    File.join(@dir, objid_to_path(objid))
  end

  def source_objid_directories
    source_objids.map { |objid| source_objid_directory objid }
  end

  def source_objids
    find_objids source_directory
  end

  def source_objid_directory(objid)
    File.join(source_directory, objid_to_path(objid))
  end

  # Returns an error message or nil
  def validate_objid(objid)
    Luhn.valid?(objid) ? nil : "Luhn checksum failed"
  end

  def image_files(type = "tif")
    items.map do |item|
      item.image_files_by_type(type)
    end.flatten
  end

  def source_image_files(type = "tif")
    return [] unless File.directory? source_directory
    source_items.map do |item|
      item.image_files_by_type(type)
    end.flatten
  end

  # This is the very first step of the whole workflow.
  # If there is no @dir/source directory, create it and copy
  # every other directory in @dir into it.
  # We will potentially remove and re-copy directories from source/
  # but that depends on the options passed to the processor.
  def setup_source_directory
    raise FinalizedShipmentError if finalized?
    return if File.exist? source_directory

    Dir.mkdir source_directory
    objids.each do |objid|
      next unless File.directory? objid_directory(objid)

      yield objid if block_given?
      components = objid_to_path objid
      FileUtils.copy_entry(File.join(@dir, components[0]),
        File.join(source_directory, components[0]))
    end
  end

  # Copy clean or remediated objid directories from source.
  # Called with nil to replaces all objids, or an Array of objids.
  def restore_from_source_directory(objid_array = nil)
    raise FinalizedShipmentError if finalized?
    unless File.directory? source_directory
      raise Errno::ENOENT, "source directory #{source_directory} not found"
    end

    (objid_array || source_objids).each do |objid|
      yield objid if block_given?
      components = objid_to_path objid
      dest = File.join(@dir, components[0])
      FileUtils.rm_r(dest, force: true) if File.exist? dest
      FileUtils.copy_entry(File.join(source_directory, components[0]), dest)
    end
  end

  def finalize
    metadata[:finalized] = true
    return unless source_directory_exists?

    FileUtils.rm_r(source_directory, force: true)
  end

  def finalized?
    metadata[:finalized] ? true : false
  end

  ### === METADATA METHODS === ###
  def checksums
    metadata[:checksums] || {}
  end

  # Add SHA256 entries to metadata for each source/objid/file.
  # If a block is passed, calls it one for each objid in the source directory.
  # Must be called after #setup_source_directory.
  def checksum_source_directory
    metadata[:checksums] = {}
    last_objid = nil
    source_image_files.each do |image_file|
      yield image_file.objid if block_given? && last_objid != image_file.objid # this is for providing an objid to the status bar
      metadata[:checksums][image_file.objid_file] = image_file.checksum
      last_objid = image_file.objid
    end
  end

  # Returns Hash with keys {added, changed, removed} -> Array of ImageFile
  def fixity_check
    fixity = {added: [], removed: [], changed: []}
    return fixity if metadata[:checksums].nil?

    source_image_files.each do |image_file|
      yield image_file if block_given?
      if checksums[image_file.objid_file].nil?
        fixity[:added] << image_file
      elsif checksums[image_file.objid_file] != image_file.checksum
        fixity[:changed] << image_file
      end
    end

    checksums.keys.sort.each do |objid_file|
      image_file = image_file_class.source_for(objid_file: objid_file, source_path: source_directory, objid_config: objid_config)
      yield image_file if block_given?
      fixity[:removed] << image_file if !File.exist? image_file.path
    end
    fixity
  end

  private

  def source_directory_exists?
    File.directory? source_directory
  end

  # Traverse to a depth of PATH_COMPONENTS under shipment directory
  def find_objids(dir = @dir)
    dirs = Dir.children(dir).reject do |entry|
      ["source", "tmp"].include?(entry) ||
        !File.directory?(File.join(dir, entry))
    end
    dirs.map do |entry|
      find_objids_with_components(dir, [entry])
    end.flatten.uniq.sort
  end

  def find_objids_with_components(dir, components)
    bars = []
    if components.count < self.class::PATH_COMPONENTS
      subdir = File.join(dir, components)
      self.class.subdirectories(subdir).each do |entry|
        more_bars = find_objids_with_components(dir, components + [entry])
        bars = (bars + more_bars).uniq
      end
    elsif components.count == self.class::PATH_COMPONENTS
      bars << path_to_objid(components)
    end
    bars
  end

  def path_to_objid(path_components)
    if path_components.count != objid_config.path_components
      raise "WARNING: #{self} is not designed for path components" \
        " other than #{objid_config.path_components} (#{path_components})"
    end

    path_components.join objid_config.separator
  end
end
