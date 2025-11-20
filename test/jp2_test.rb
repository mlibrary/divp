#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "jp2"

class TIFFTest < Minitest::Test
  def test_new
    shipment = TestShipment.new(test_name, "BC J contone 1")
    jp2 = JP2.new(shipment.image_files.first.path)
    refute_nil jp2, "JP2 is not nil"
  end

  def test_info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    shipment = TestShipment.new(test_name, "BC J contone 1")
    jp2 = JP2.new(shipment.image_files.first.path)
    info = jp2.info
    assert_instance_of Hash, info
    assert_instance_of Array, info[:warnings]
    assert_empty info[:warnings]
    assert_instance_of Array, info[:errors]
    assert_empty info[:errors]
    assert_instance_of Integer, info[:x_res]
    assert_instance_of Integer, info[:y_res]
    assert_instance_of String, info[:res_unit]
  end
end
