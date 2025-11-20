#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tiff"

class TIFFTest < Minitest::Test
  def test_new
    shipment = TestShipment.new(test_name, "BC T contone 1")
    tiff = TIFF.new(shipment.image_files.first.path)
    refute_nil tiff, "TIFF is not nil"
  end

  def test_info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, "BC T contone 1")
    tiff = TIFF.new(shipment.image_files.first.path)
    info = tiff.info
    assert_instance_of Hash, info
    assert_instance_of Array, info[:warnings]
    assert_empty info[:warnings]
    assert_instance_of Array, info[:errors]
    assert_empty info[:errors]
    assert_instance_of Integer, info[:x_res]
    assert_instance_of Integer, info[:y_res]
    assert_instance_of String, info[:res_unit]
    assert_instance_of Integer, info[:bps]
    assert_instance_of Integer, info[:spp]
    assert info[:alpha].is_a?(TrueClass) || info[:alpha].is_a?(FalseClass)
    assert info[:icc].is_a?(TrueClass) || info[:icc].is_a?(FalseClass)
    assert_instance_of Integer, info[:width]
    assert_instance_of Integer, info[:height]
    assert_instance_of Integer, info[:length]
    assert_equal info[:height], info[:length]
    assert_nil info[:date_time]
    assert_nil info[:software]
  end

  def test_info_fail
    shipment = TestShipment.new(test_name, "BC F bogus_file")
    tiff = TIFF.new(File.join(shipment.directory,
      shipment.objid_to_path(shipment.objids.first),
      "bogus_file"))
    assert_raises(StandardError, "raises StandardError on bogus file") do
      tiff.info
    end
  end

  def test_set
    shipment = TestShipment.new(test_name, "BC T contone 1")
    tiff = TIFF.new(shipment.image_files.first.path)
    info = tiff.set(TIFF::TIFFTAG_ARTIST, "blah")
    assert_instance_of Hash, info, "#set returns Hash"
    assert_instance_of Array, info[:warnings], "#set warnings is Array"
    assert_empty info[:warnings], "#set warnings is empty"
    assert_instance_of Array, info[:errors], "#set errors is Array"
    assert_empty info[:errors], "#set errors is empty"
  end
end
