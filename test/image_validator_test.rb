#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "image_validator"

class ImageValidatorTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    @config = Config.new({no_progress: true})
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      stage.run!
      assert_equal(0, stage.errors.count, "stage runs without errors")
    }
    generate_tests "run", test_proc
  end

  def self.gen_16bps_fails
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bad_16bps 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      stage.run!
      assert_equal(1, stage.errors.count, "16bps TIFF rejected")
    }
    generate_tests "16bps_fails", test_proc
  end

  def self.gen_pixelspercentimeter_fails # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `convert #{tiff} -units PixelsPerCentimeter #{tiff}`
      stage.run!
      assert(stage.errors.any? { |e| %r{pixels/cm}.match? e.to_s },
        "PixelsPerCentimeter TIFF rejected")
    }
    generate_tests "pixelspercentimeter_fails", test_proc
  end

  def self.gen_bitonal_3spp_fails # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `tiffset -s 277 '3' #{tiff}`
      stage.run!
      assert(stage.errors.any? { |e| /SPP\s3\swith\s1\sBPS/i.match? e.to_s },
        "1 BPS 3 SPP TIFF rejected")
    }
    generate_tests "bitonal_3spp_fails", test_proc
  end

  def self.gen_bitonal_resolution_fails # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `convert #{tiff} -density 100x100 -units pixelsperinch #{tiff}`
      stage.run!
      assert(stage.errors.any? { |e| /100x100 bitonal/i.match? e.to_s },
        "100x100 bitonal TIFF rejected")
    }
    generate_tests "bitonal_resolution_fails", test_proc
  end

  def self.gen_contone_2spp_fails # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `tiffset -s 277 '2' #{tiff}`
      stage.run!
      assert(stage.errors.any? { |e| /SPP 2 with 8 BPS/i.match? e.to_s },
        "8 BPS 2 SPP TIFF rejected")
    }
    generate_tests "contone_2spp_fails", test_proc
  end

  def self.gen_contone_resolution_fails # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `convert #{tiff} -density 100x100 -units pixelsperinch #{tiff}`
      stage.run!
      assert(stage.errors.any? { |e| /100x100 contone/i.match? e.to_s },
        "100x100 contone TIFF rejected")
    }
    generate_tests "contone_resolution_fails", test_proc
  end

  def self.gen_garbage_tiff_fails # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = ImageValidator.new(shipment, config: @config.merge(opts))
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `/bin/echo -n 'test' > #{tiff}`
      stage.run!
      assert(stage.errors.count == 1, "garbage TIFF generates one error")
      assert(stage.errors.any? { |e| /cannot read tiff header/i.match? e.to_s },
        "garbage TIFF rejected with message about TIFF header")
    }
    generate_tests "garbage_tiff_fails", test_proc
  end

  invoke_gen
end
