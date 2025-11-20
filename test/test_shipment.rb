#!/usr/bin/env ruby
# frozen_string_literal: true

require "luhn"
require "fixtures"
require_relative "../lib/shipment"

class TestShipment < Shipment # rubocop:disable Metrics/ClassLength
  attr_reader :ordered_objids

  PATH = File.join(__dir__, "shipments").freeze

  # Yes, we want this shared with subclasses
  def self.test_shipments
    @@test_shipments ||= [] # rubocop:disable Style/ClassVars
  end

  def self.remove_test_shipments
    while test_shipments.any?
      dir = File.join(PATH, test_shipments.pop)
      FileUtils.rm_r(dir, force: true)
    end
  end

  def self.add_test_shipment(name)
    Dir.mkdir PATH unless File.exist? PATH
    test_shipments << name
  end

  # Randomly-generated objid that passes Luhn check
  def self.generate_objid(valid = true)
    objid = "39015" + (8.times.map { rand 10 }).join
    if valid
      objid + Luhn.checksum(objid).to_s
    else
      objid + ((Luhn.checksum(objid) + 1) % 10).to_s
    end
  end

  # Generate a test directory under test/shipments based on specification
  # spec is a string of opcodes and optional parameters
  # OPCODES
  # [BC] create objid directory (and make it current)
  # [BBC] create bogus objid directory (and make it current)
  # [TIF name, dest] copy TIF fixture to dest (which can be a range)
  # [F dest] create zero-length file at dest
  # [DIR] cwd to shipment directory
  def initialize(name, spec = "")
    self.class.add_test_shipment(name)
    @name = name
    dir = File.join(PATH, @name)
    FileUtils.rm_r(dir, force: true) if File.directory? dir
    Dir.mkdir(dir)
    super dir
    @ordered_objids = []
    process_spec spec
  end

  def process_spec(spec) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    @current_dir = @dir
    elements = spec.split(/\s+/)
    while elements.any?
      case op = elements.shift
      when "BC"
        handle_objid_op
      when "BBC"
        handle_bogus_objid_op
      when "T"
        handle_tiff_op(elements.shift, elements.shift)
      when "J"
        handle_jp2_op(elements.shift, elements.shift)
      when "F"
        FileUtils.touch(File.join(@current_dir, elements.shift))
      when "DIR"
        @current_dir = @dir
      else
        raise StandardError, "Unrecognized opcode #{op}"
      end
    end
  end

  private

  def handle_objid_op
    objid = self.class.generate_objid(true)
    @current_dir = File.join(@dir, objid)
    Dir.mkdir(@current_dir)
    @ordered_objids << objid
  end

  def handle_bogus_objid_op
    objid = self.class.generate_objid(false)
    @current_dir = File.join(@dir, objid)
    Dir.mkdir(@current_dir)
    @ordered_objids << objid
  end

  def handle_tiff_op(name, dest) # rubocop:disable Metrics/MethodLength
    fixture = Fixtures.tiff_fixture(name)
    case dest
    when /^\d+$/
      dest = format "%<filename>08d.tif", {filename: dest}
      FileUtils.cp fixture, File.join(@current_dir, dest)
    when /^\d+-\d+$/
      first, last = dest.split("-").map(&:to_i)
      first, last = last, first if first > last
      (first..last).each do |n|
        dest = format "%<filename>08d.tif", {filename: n}
        FileUtils.cp fixture, File.join(@current_dir, dest)
      end
    else
      raise StandardError, "Unknown TIFF destination format '#{dest}'"
    end
  end

  def handle_jp2_op(name, dest) # rubocop:disable Metrics/MethodLength
    fixture = Fixtures.jp2_fixture(name)
    case dest
    when /^\d+$/
      dest = format "%<filename>08d.jp2", {filename: dest}
      FileUtils.cp fixture, File.join(@current_dir, dest)
    when /^\d+-\d+$/
      first, last = dest.split("-").map(&:to_i)
      first, last = last, first if first > last
      (first..last).each do |n|
        dest = format "%<filename>08d.jp2", {filename: n}
        FileUtils.cp fixture, File.join(@current_dir, dest)
      end
    else
      raise StandardError, "Unknown JP2 destination format '#{dest}'"
    end
  end
end

class DLXSTestShipment < TestShipment
  # Randomly-generated DLXS id/volume/number objid abcde/XXXX/YYY
  def self.generate_objid(valid = true)
    objid = [[*("a".."z"), *("0".."9")].sample(8).join,
      4.times.map { rand 10 }.join,
      3.times.map { rand 10 }.join].join(".")
    valid ? objid : objid.reverse
  end

  def handle_objid_op
    objid = self.class.generate_objid(true)
    components = objid.split "."
    path = @dir
    components.each do |component|
      path = File.join(path, component)
      Dir.mkdir(path)
    end
    @current_dir = path
    @ordered_objids << objid
  end

  def handle_bogus_objid_op
    objid = self.class.generate_objid(false)
    components = objid.split "."
    path = @dir
    components.each do |component|
      path = File.join(path, component)
      Dir.mkdir(path)
    end
    @current_dir = path
    @ordered_objids << objid
  end
end
