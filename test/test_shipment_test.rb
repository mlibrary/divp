#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "test_shipment"

class TestShipmentTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def test_valid_objids
    100.times do
      objid = TestShipment.generate_objid(true)
      assert Luhn.valid?(objid), "generate_objid #{objid} valid"
    end
  end

  def test_invalid_objids
    100.times do
      objid = TestShipment.generate_objid(false)
      refute Luhn.valid?(objid), "generate_objid #{objid} valid"
    end
  end

  def test_generate_test_shipment_objid # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, "BC")
    assert_equal 1, shipment.objids.count, "correct number of objids"
    assert File.directory?(shipment.directory), "#{test_name} is directory"
    objid_dir = File.join(shipment.directory,
      shipment.objid_to_path(shipment.objids[0]))
    assert File.directory?(objid_dir), "#{shipment.objids[0]} is directory"
    assert Luhn.valid?(shipment.objids[0]),
      "objid #{shipment.objids[0]} valid"
  end

  def test_generate_test_shipment_bogus_objid # rubocop:disable Metrics/AbcSize
    shipment = TestShipment.new(test_name, "BBC")
    assert_equal 1, shipment.objids.count, "correct number of objids"
    assert File.directory?(shipment.directory), "#{test_name} is directory"
    assert File.directory?(File.join(shipment.directory,
      shipment.objids[0])),
      "#{shipment.objids[0]} is directory"
    refute Luhn.valid?(shipment.objids[0]),
      "objid #{shipment.objids[0]} invalid"
  end

  def test_generate_test_shipment_tiff_files
    shipment = TestShipment.new(test_name, "BC T bitonal 1 F empty.txt")
    tiff = File.join(shipment.directory, shipment.objids[0],
      "00000001.tif")
    assert File.exist?(tiff), "000000001.tif is copied"
    txt = File.join(shipment.directory, shipment.objids[0], "empty.txt")
    assert File.exist?(txt), "empty.txt is created"
  end

  def test_generate_test_shipment_tiff_file_range
    shipment = TestShipment.new(test_name, "BC T contone 1-8")
    (1..8).each do |n|
      tiff = File.join(shipment.directory, shipment.objids[0],
        format("%<filename>08d.tif", {filename: n}))
      assert File.exist?(tiff), "#{tiff} in file range"
    end
  end

  def test_generate_test_shipment_jp2_files
    shipment = TestShipment.new(test_name, "BC J contone 1")
    jp2 = File.join(shipment.directory, shipment.objids[0], "00000001.jp2")
    assert File.exist?(jp2), "000000001.jp2 is copied"
  end

  def test_generate_test_shipment_jp2_file_range
    shipment = TestShipment.new(test_name, "BC J contone 1-8")
    (1..8).each do |n|
      jp2 = File.join(shipment.directory, shipment.objids[0],
        format("%<filename>08d.jp2", {filename: n}))
      assert File.exist?(jp2), "#{jp2} in file range"
    end
  end

  def test_dir_opcode
    shipment = TestShipment.new(test_name, "BC DIR F test")
    file = File.join(shipment.directory, "test")
    assert File.exist?(file), "test file creasted at top level"
  end

  def test_unknown_opcode
    assert_raises(StandardError, "raises unknown opcode") do
      TestShipment.new(test_name, "ZZZZZ")
    end
  end

  def test_unknown_tiff_format
    assert_raises(StandardError, "raises unknown tiff format") do
      TestShipment.new(test_name, "BC T contone ZZZZZ")
    end
  end

  def test_unknown_jp2_format
    assert_raises(StandardError, "raises unknown jp2 format") do
      TestShipment.new(test_name, "BC J contone ZZZZZ")
    end
  end
end

class DLXSTestShipmentTest < Minitest::Test
  def test_generate_test_shipment_dlxs_objid # rubocop:disable Metrics/AbcSize
    shipment = DLXSTestShipment.new(test_name, "BC")
    assert_equal 1, shipment.ordered_objids.count,
      "correct number of ordered objids"
    (id, vol, num) = shipment.ordered_objids[0].split "."
    assert File.directory?(File.join(shipment.directory, id)),
      "shipment/id is directory"
    assert File.directory?(File.join(shipment.directory, id, vol)),
      "shipment/id/volume is directory"
    assert File.directory?(File.join(shipment.directory, id, vol, num)),
      "shipment/id/volume/number is directory"
  end
end
