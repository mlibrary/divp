#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "tempfile"
require "time"

require "config"
require "error"
require "progress_bar"
require "symbolize"

# Base class for conversion stages
class Stage # rubocop:disable Metrics/ClassLength
  attr_reader :errors, :warnings, :start, :end
  attr_accessor :name, :config, :shipment

  def self.json_create(hash)
    data = Symbolize.symbolize hash["data"]
    new nil, **data
  end

  def self.json_time(time)
    time.nil? ? "" : time.strftime("%Y-%m-%d %H:%M:%S.%N %z")
  end

  def to_json(*args)
    {
      "json_class" => self.class.name,
      "data" => {name: @name,
                 errors: @errors,
                 warnings: @warnings,
                 data: @data,
                 start: Stage.json_time(@start),
                 end: Stage.json_time(@end)}
    }.to_json(*args)
  end

  # Can be created without a shipment, but that field needs to be set
  # before the #run method can be called.
  def initialize(shipment, **args) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    unless shipment.nil? || shipment.is_a?(Shipment)
      raise StandardError, "unknown shipment class #{shipment.class}"
    end

    @shipment = shipment
    @name = args[:name] || self.class.to_s
    @config = args[:config] || {} # Top-level Config object
    @errors = args[:errors] || [] # Fatal conditions, Array of Error
    @warnings = args[:warnings] || [] # Nonfatal conditions, Array of Error
    @data = args[:data] || {} # Misc data structure including log
    # Time the stage was last run
    @start = if args[:start].to_s == ""
      nil
    else
      Time.parse args[:start]
    end
    # Time the stage last finished running
    # Currently used by #complete?
    @end = if args[:end].to_s == ""
      nil
    else
      Time.parse args[:end]
    end
    @bar = if config[:no_progress]
      SilentProgressBar.new(self.class)
    else
      ProgressBar.new(self.class)
    end
  end

  # Get rid of errors, warnings, and anything that may have been memoized
  def reinitialize!
    @errors = []
    @warnings = []
    @bar.done = nil
  end

  def run!(agenda = nil)
    @start = Time.now
    agenda = shipment.objids if agenda.nil?
    @bar.steps = agenda.count
    run agenda
    cleanup
    @end = Time.now
    @bar.done! format("%.3f sec", @end - @start)
  end

  # This is the method that needs to be implemented by a subclass
  def run(_agenda)
    raise "#{self.class.name}#run method unimplemented"
  end

  def add_error(err)
    raise "#{err.class} passed to add_error" unless err.is_a? Error
    unless err.objid.nil? || objids.member?(err.objid)
      raise "unknown error objid #{err.objid}"
    end

    @bar.error = true
    @errors << err
  end

  def add_warning(err)
    raise "#{err.class} passed to add_warning" unless err.is_a? Error
    unless err.objid.nil? || objids.member?(err.objid)
      raise "unknown warning objid #{err.objid}"
    end

    @bar.warning = true
    @warnings << err
  end

  # Map of objids + nil -> [Errors]
  # Does not include objids with no errors
  def errors_by_objid
    errors.each_with_object({}) do |err, memo|
      (memo[err.objid] ||= []) << err
    end
  end

  # Map of objids + nil -> [Errors]
  # Does not include objids with no warnings
  def warnings_by_objid
    warnings.each_with_object({}) do |err, memo|
      (memo[err.objid] ||= []) << err
    end
  end

  def error_objids
    errors_by_objid.keys.compact
  end

  # Any error with objid == nil is fatal.
  def fatal_error?
    errors_by_objid.key? nil
  end

  def delete_errors_for_objid(objid)
    @errors.delete_if { |err| err.objid == objid }
  end

  def delete_warnings_for_objid(objid)
    @warnings.delete_if { |err| err.objid == objid }
  end

  # OK to make destructive changes to the shipment for this objid?
  # With nil objid checks for presence of any error.
  def make_changes?(objid = nil)
    return @errors.none? if objid.nil?

    @errors.none? { |err| err.objid == objid || err.objid.nil? }
  end

  # True if the stage has been run and all possible errors have
  # had a chance to surface
  def complete?
    @errors.none? && !@end.nil?
  end

  # Expected to be run as part of #run,
  # may be called multiple times.
  def cleanup
    cleanup_copy_on_success
    cleanup_delete_on_success
    cleanup_tempdirs
  end

  def cleanup_copy_on_success
    return if @copy_on_success.nil?

    while @copy_on_success.any?
      copy = @copy_on_success.pop
      if make_changes? copy[:objid]
        FileUtils.cp copy[:source], copy[:destination]
      end
    end
  end

  def cleanup_delete_on_success
    return if @delete_on_success.nil? || !make_changes?

    @delete_on_success.each do |del|
      FileUtils.rm del[:path] if make_changes? del[:objid]
    end
    @delete_on_success = nil
  end

  def cleanup_tempdirs
    unless @tempdirs.nil? # ruboccop:disable Style/IfUnlessModifier
      FileUtils.rm_rf @tempdirs.pop while @tempdirs.any?
    end
    return unless File.directory? shipment.tmp_directory

    FileUtils.rm_rf shipment.tmp_directory
  end

  # Prefix is useful when debugging image processing pipelines.
  def create_tempdir(prefix = "")
    unless File.directory? shipment.tmp_directory
      Dir.mkdir shipment.tmp_directory
    end
    datadir = ENV.fetch("DATA_DIR", "/quod-prep/rsvp")
    Dir.mkdir datadir unless File.directory? datadir
    prefix = self.class.to_s + prefix
    (@tempdirs ||= []) << Dir.mktmpdir(prefix, datadir)
    @tempdirs[-1]
  end

  # source is copied to destination on success,
  # left alone on failure.
  def copy_on_success(source, destination, objid)
    (@copy_on_success ||= []) << {source: source, destination: destination,
                                  objid: objid}
  end

  def delete_on_success(path, objid = nil)
    (@delete_on_success ||= []) << {path: path, objid: objid}
  end

  def objids
    @objids ||= shipment.objids
  end

  def log_collection
    @data[:log] ||= Log.new
  end

  def log(entry, time = nil)
    log_collection.log(entry, time)
  end

  def shipment_directory
    shipment.directory
  end

  def source_directory
    shipment.source_directory
  end

  def objid_directories
    shipment.objid_directories
  end

  def image_files(type = "tif")
    shipment.image_files(type)
  end

  class Log
    include Enumerable

    def initialize
      @log = []
    end

    def each
      @log.each do |line|
        yield line
      end
    end

    def log(entry, time)
      entry += format(" (%.3f sec)", time) unless time.nil?
      @log << entry
    end

    def log_it(entry, time)
      log(entry, time)
    end

    def to_json(state = nil, *)
      JSON::State.from_state(state).generate(@log)
    end
  end
end
