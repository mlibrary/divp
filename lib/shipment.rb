#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "luhn"

# Errors arising from trying to destructively manipulate a finalized shipment.
class FinalizedShipmentError < StandardError
end

ImageFile = Struct.new(:objid, :path, :objid_file, :file)

# Shipment directory class
class Shipment # rubocop:disable Metrics/ClassLength
  PATH_COMPONENTS = 1
  OBJID_SEPARATOR = "/"
  attr_reader :metadata

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

  def tmp_directory
    @tmp_directory ||= File.join @dir, "tmp"
  end

  def path_to_objid(path_components)
    if path_components.count != self.class::PATH_COMPONENTS
      raise "WARNING: #{self.class} is not designed for path components" \
            " other than #{self.class::PATH_COMPONENTS} (#{path_components})"
    end

    path_components.join self.class::OBJID_SEPARATOR
  end

  def objid_to_path(objid)
    objid.split self.class::OBJID_SEPARATOR
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

  def image_files(type = "tif", dir = @dir) # rubocop:disable Metrics/MethodLength
    files = []
    find_objids(dir).each do |objid|
      objid_path = objid_to_path objid
      objid_dir = File.join(dir, objid_path)
      self.class.directory_entries(objid_dir).sort.each do |entry|
        next unless entry.end_with? type

        files << ImageFile.new(objid, File.join(objid_dir, entry),
          File.join(objid_path, entry), entry)
      end
    end
    files
  end

  def source_image_files(type = "tif")
    return [] unless File.directory? source_directory

    image_files(type, source_directory)
  end

  # This is the very first step of the whole workflow.
  # If there is no @dir/source directory, create it and copy
  # every other directory in @dir into it.
  # We will potentially remove and re-copy directories from source/
  # but that depends on the options passed to the processor.
  def setup_source_directory # rubocop:disable Metrics/AbcSize
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
  def restore_from_source_directory(objid_array = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
    return unless File.exist? source_directory

    FileUtils.rm_r(source_directory, force: true)
  end

  def finalized?
    metadata[:finalized] ? true : false
  end

  ### === METADATA METHODS === ###
  def checksums
    metadata[:checksums] || {}
  end

  def checksum(image_file)
    Digest::SHA256.file(image_file.path).hexdigest
  end

  # Add SHA256 entries to metadata for each source/objid/file.
  # If a block is passed, calls it one for each objid in the source directory.
  # Must be called after #setup_source_directory.
  def checksum_source_directory
    metadata[:checksums] = {}
    last_objid = nil
    source_image_files.each do |image_file|
      yield image_file.objid if block_given? && last_objid != image_file.objid
      metadata[:checksums][image_file.objid_file] = checksum(image_file)
      last_objid = image_file.objid
    end
  end

  # Returns Hash with keys {added, changed, removed} -> Array of ImageFile
  def fixity_check # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    fixity = {added: [], removed: [], changed: []}
    return fixity if metadata[:checksums].nil?

    source_image_files.each do |image_file|
      yield image_file if block_given?
      if checksums[image_file.objid_file].nil?
        fixity[:added] << image_file
      elsif checksums[image_file.objid_file] != checksum(image_file)
        fixity[:changed] << image_file
      end
    end

    checksums.keys.sort.each do |objid_file|
      components = objid_file.split(File::SEPARATOR)
      objid = path_to_objid(components[0..-2])
      image_file = ImageFile.new(objid,
        File.join(source_directory, objid_file),
        objid_file, components[-1])
      yield image_file if block_given?
      fixity[:removed] << image_file unless File.exist? image_file.path
    end
    fixity
  end

  private

  # Traverse to a depth of PATH_COMPONENTS under shipment directory
  def find_objids(dir = @dir)
    bars = []
    dirs = self.class.top_level_directory_entries(dir)
    dirs.each do |entry|
      bars = (bars + find_objids_with_components(dir, [entry])).uniq
    end
    bars.sort
  end

  def find_objids_with_components(dir, components) # rubocop:disable Metrics/MethodLength
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
end
