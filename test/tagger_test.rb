#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tagger"

class TaggerTest < Minitest::Test
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
      stage = Tagger.new(shipment, config: @config.merge(opts))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_default_tags # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 BC T bitonal 1"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = Tagger.new(shipment, config: @config.merge(opts))
      stage.run!
      shipment.image_files.each do |image_file|
        info = `tiffinfo #{image_file.path}`
        assert_match "Orientation: row 0 top, col 0 lhs",
          info, "tiffinfo has correct default orientation"
        assert_match "Artist: University of Michigan: Digital Conversion Unit",
          info, "tiffinfo has correct default DCU artist"
        refute_match(/make:/i, info, "tiffinfo has no software tag")
        refute_match(/model:/i, info, "tiffinfo has no scanner tag")
      end
    }
    generate_tests "default_tags", test_proc
  end

  def self.gen_artist_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      config = Config.new({no_progress: true, tagger_artist: "bentley"})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      info = `tiffinfo #{tiff}`
      assert_match(/bentley/i, info, "tiffinfo has Bentley artist tag")
    }
    generate_tests "artist_tag", test_proc
  end

  def self.gen_scanner_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      config = Config.new({no_progress: true, tagger_scanner: "copibookv"})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      info = `tiffinfo #{tiff}`
      assert_match("Make: i2S DigiBook", info,
        "tiffinfo has DigiBook scanner tag")
      assert_match("Model: CopiBook V", info,
        "tiffinfo has CopiBook scanner tag")
    }
    generate_tests "scanner_tag", test_proc
  end

  def self.gen_software_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      config = Config.new({no_progress: true, tagger_software: "limb"})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      info = `tiffinfo #{tiff}`
      assert_match("LIMB", info, "tiffinfo has LIMB software tag")
    }
    generate_tests "software_tag", test_proc
  end

  invoke_gen
end

class TaggerCustomTagTest < Minitest::Test
  def setup
    @config = Config.new({no_progress: true})
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_custom_artist_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      artist = "University of Michigan: Secret Vaults"
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      config = Config.new({no_progress: true, tagger_artist: artist})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      assert(stage.errors.count.zero?, "no errors generated")
      assert stage.warnings.any? { |e| /custom\sartist/i.match? e.to_s },
        "warns about custom artist string"
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      info = `tiffinfo #{tiff}`
      assert_match("Artist: #{artist}", info, "tiffinfo has custom artist tag")
    }
    generate_tests "custom_artist_tag", test_proc
  end

  def self.gen_custom_scanner_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      config = Config.new({no_progress: true,
                           tagger_scanner: "Scans-R-Us|F-150 Flatbed"})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      assert(stage.errors.count.zero?, "no errors generated")
      assert stage.warnings.any? { |e| /custom\sscanner/i.match? e.to_s },
        "warns about custom scanner string"
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      info = `tiffinfo #{tiff}`
      assert_match("Make: Scans-R-Us", info,
        "tiffinfo has custom scanner make tag")
      assert_match("Model: F-150 Flatbed", info,
        "tiffinfo has custom scanner model tag")
    }
    generate_tests "custom_scanner_tag", test_proc
  end

  def self.gen_bogus_custom_scanner_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      config = Config.new({no_progress: true,
                           tagger_scanner: "some random string"})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      assert(stage.errors.any? { |e| /make\|model/i.match? e.to_s },
        "generates pipe-delimited error")
    }
    generate_tests "bogus_custom_scanner_tag", test_proc
  end

  def self.gen_custom_software_tag # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      software = "WhizzySoft ScanR v33"
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      config = Config.new({no_progress: true, tagger_software: software})
      stage = Tagger.new(shipment, config: config.merge(opts))
      stage.run!
      assert(stage.errors.count.zero?, "no errors generated")
      assert stage.warnings.any? { |e| /custom\ssoftware/i.match? e.to_s },
        "warns about custom software string"
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      info = `tiffinfo #{tiff}`
      assert_match("Software: #{software}", info,
        "tiffinfo has custom software tag")
    }
    generate_tests "custom_software_tag", test_proc
  end

  invoke_gen
end
