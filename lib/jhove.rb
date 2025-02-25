#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'

require 'command'
require 'error'
require 'symbolize'

# Wrapper for feed validate Perl script which invokes JHOVE
class JHOVE # rubocop:disable Metrics/ClassLength
  attr_reader :errors, :raw_output

  UNUSED_FIELDS = %i[description file namespace objid
                     remediable seq stage].freeze

  # Convert error Hash to Postflight Error object
  def self.error_object(err, objid = nil)
    fields = err.reject { |k, _v| JHOVE::UNUSED_FIELDS.include? k }
    desc = "#{err[:description]}: " +
           fields.map { |k, v| "#{k}: #{v}" }.join(', ')
    Error.new desc, objid, err[:file]
  end

  def initialize(directory, config)
    @dir = directory
    @config = config
    @errors = []
  end

  # Run the validation with output parsed into @errors.
  # This is for Postflight.
  def run
    cmd = feed_validate_script
    status = Command.new(cmd).run
    @raw_output = status[:stdout]
    process_feed_validate_output
  end

  def error_fields
    @error_fields ||= @errors.map { |err| error_field(err) }.compact.uniq.sort
  end

  def errors_for_field(field)
    errs = @errors.select do |err|
      error_field(err) == field
    end.uniq
    errs = deduplicate_errors errs
    errs.map do |err|
      if err[:file].is_a? Array
        err[:file] = "#{err[:file][0]} - #{err[:file][-1]}"
      end
      err
    end
  end

  private

  def feed_validate_script
    # If this is configured, simply call it without Docker.
    # Otherwise invoke the standard entry point.
    # Running under Docker is slow!
    # May be able to use something like https://github.com/upserve/docker-api
    # to reuse container.
    if @config[:feed_validate_script]
      ['perl', @config[:feed_validate_script], 'simple test', @dir]
    else
      feed_validate_script_docker
    end.join ' '
  end

  def feed_validate_script_docker
    local = Pathname.new(@dir)
    mount = Pathname.new('/images') + local.basename
    [
      "docker run --rm -v '#{local}:#{mount}'",
      'ghcr.io/hathitrust/feed',
      'perl',
      '/usr/local/feed/bin/validate_images.pl',
      'simple test',
      mount.to_s
    ]
  end

  def process_feed_validate_output
    return if @raw_output.chomp.length.zero?

    err_lines = @raw_output.chomp.split("\n")
    err_lines.each do |line|
      next if ['failure!', 'success!', ''].include? line

      process_feed_validate_line line
    end
    @errors.sort! { |a, b| a[:seq] <=> b[:seq] }
  end

  # Process error/warning lines into error hashes.
  # There's an impedance mismatch betweeen these hashes and
  # regular Error objects largely because these are meant to be
  # more on the human-readable side.
  # So some effort must be made to de-bloviate the JHOVE output
  # without losing information.
  def process_feed_validate_line(line)
    err = line_to_err(line)
    return if err.nil? || redundant_error?(err)

    @errors << err
  end

  def line_to_err(line)
    line = normalize_line(line)
    # Bail out if this is a WARN line, they are redundant
    return nil if /WARN - /.match? line

    fields = line.split("\t")
    # Extract the details if this is an actual error
    err = fields[1..].map do |field|
      field.scan(/(.+?)\s*:\s*(.+)/).first
    end.compact.to_h.symbolize
    err[:description] = fields[0].sub(/^(warn|error) - /i, '').downcase
    # This is the sort key (just in case we get errors out of order)
    # and the means by which we merge summaries into ranges
    # err[:seq] = filename_to_sequence err[:file]
    sequentialize! err
  end

  # Remove ANSI color and leading runtime info and pid
  def normalize_line(line)
    line.decolorize.sub(/.+?(?=(ERROR|WARN))/, '')
  end

  def redundant_error?(err)
    /validation failed/i.match?(err[:description]) &&
      @errors.any? { |e| e[:file] == err[:file] }
  end

  def deduplicate_errors(errs)
    new_errors = []
    errs.each do |e|
      if merge_errors? new_errors.last, e
        merge_errors! new_errors.last, e
        e = nil
      end
      new_errors << e.dup unless e.nil?
    end
    new_errors
  end

  def merge_errors?(err1, err2)
    if !err1.nil? && fields_for_merge(err1) == fields_for_merge(err2)
      last_seq = err1[:seq].is_a?(Array) ? err1[:seq].last : err1[:seq]
      return true if last_seq == err2[:seq] - 1
    end
    false
  end

  def merge_errors!(err1, err2)
    if err1[:seq].is_a? Array
      err1[:seq] = [err1[:seq].first, err2[:seq]]
      err1[:file] = [err1[:file].first, err2[:file]]
    else
      err1[:seq] = [err1[:seq], err2[:seq]]
      err1[:file] = [err1[:file], err2[:file]]
    end
  end

  def fields_for_merge(err)
    [err[:description], err[:expected], err[:actual], err[:detail]]
  end

  # Strip off any leading or trailing non-numeric characters
  # and convert to integer.
  def sequentialize!(err)
    return nil unless err[:file]

    file = err[:file].split(File::SEPARATOR).last
    match = file.match(/^.*?([0-9]+)\.(?:tif|jp2)$/)
    err[:seq] = match.nil? ? 0 : match[1].to_i
    err
  end

  def error_field(err)
    field = "#{err[:description]}: #{err[:field]}"
    field += " (#{err[:detail]})" unless err[:detail].nil?
    field
  end
end
