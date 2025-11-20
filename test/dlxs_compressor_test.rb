#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "dlxs_compressor"
require "fixtures"

class DLXSCompressorTest < Minitest::Test
  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      stage = DLXSCompressor.new(shipment, config: opts.merge(@config))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Compressor.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(0, stage.errors.count, "compressor runs without errors")
      stage = DLXSCompressor.new(shipment, config: opts.merge(@config))
      stage.run!
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      assert File.exist?(tiff), "00000001.tif exists"
      jp2 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.jp2")
      refute File.exist?(jp2), "00000001.jp2 does not exist"
      jp2 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "p0000001.jp2")
      assert File.exist?(jp2), "p0000001.jp2 exists"
    }
    generate_tests "run", test_proc
  end

  def setup
    @config = Config.new({no_progress: true})
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  invoke_gen
end
