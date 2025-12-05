#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "compressor"
require "fixtures"

class CompressionTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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
      stage = Compression.new(shipment, config: opts.merge(@config))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(0, stage.errors.count, "stage runs without errors")
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      assert File.exist?(tiff), "00000001.tif exists"
      jp2 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000002.jp2")
      assert File.exist?(jp2), "00000002.jp2 exists"
    }
    generate_tests "run", test_proc
  end

  def self.gen_set_tiff_date_time # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.send(:write_tiff_date_time, tiff)
      tiffinfo = `tiffinfo #{tiff}`
      assert_match(/DateTime:\s\d{4}:\d{2}:\d{2}\s\d{2}:\d{2}:\d{2}/, tiffinfo,
        "TIFF DateTime in %Y:%m:%d %H:%M:%S format")
    }
    generate_tests "set_tiff_date_time", test_proc
  end

  def self.gen_set_jp2_date_time # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `tiffset -s 306 '2000:11:11 11:11:11' #{tiff}`
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      jp2 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.jp2")
      exif_data = `exiftool #{jp2}`
      assert_match(%r{Date/Time\sModified\s*:\s*2000:11:11\s11:11:11},
        exif_data, "JP2 DateTime in %Y:%m:%d %H:%M:%S format")
    }
    generate_tests "set_jp2_date_time", test_proc
  end

  def self.gen_set_jp2_document_name # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      jp2 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.jp2")
      doc_name = File.join(shipment.objid_to_path(shipment.objids[0]),
        "00000001.jp2")
      exif_data = `exiftool #{jp2}`
      assert_match(/Source\s*:\s*#{Regexp.escape doc_name}/,
        exif_data, "JP2 File Name includes objid")
    }
    generate_tests "set_jp2_document_name", test_proc
  end

  def self.gen_16bps_fails
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bad_16bps 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(1, stage.errors.count, "stage fails with 16bps TIFF")
      assert_match(/invalid source tiff/i, stage.errors[0].description,
        'stage fails with "invalid source TIFF"')
    }
    generate_tests "16bps_fails", test_proc
  end

  def self.gen_zero_length_fails
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC F 00000001.tif")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      # Error description may be tiffinfo exit code or something more detailed.
      assert_equal(1, stage.errors.count, "stage fails with zero-length TIFF")
    }
    generate_tests "zero_length_fails", test_proc
  end

  def self.gen_alpha_channel # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `convert #{tiff} -alpha on #{tiff}`
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(0, stage.errors.count, "stage runs without errors")
    }
    generate_tests "alpha_channel", test_proc
  end

  def self.gen_icc_profile # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      profile_path = File.join(Fixtures::TEST_FIXTURES_PATH, "sRGB2014.icc")
      `convert #{tiff} -profile #{profile_path} #{tiff}`
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(0, stage.errors.count, "stage runs without errors")
    }
    generate_tests "icc_profile", test_proc
  end

  def self.gen_software # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `tiffset -s 305 'BOGUS SOFTWARE v1.0' #{tiff}`
      stage = Compression.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(0, stage.errors.count, "stage runs without errors")
      assert_match(/BOGUS\sSOFTWARE/, `tiffinfo #{tiff}`,
        "305 software tag is preserved")
    }
    generate_tests "software", test_proc
  end

  invoke_gen
end
