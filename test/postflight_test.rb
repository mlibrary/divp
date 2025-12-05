#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "postflight"

class PostflightTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    opts = {no_progress: true,
            feed_validate_script: "test/bin/fake_feed_validate.pl"}
    @config = Config.new opts
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      stage = Postflight.new(shipment, config: opts.merge(@config))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 T contone 2"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal 0, stage.errors.count, "stage runs without errors"
    }
    generate_tests "run", test_proc
  end

  def self.gen_metadata_mismatch_removed # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 BC T bitonal 1"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      FileUtils.rm_r(File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0])),
        force: true)
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /removed/.match? e.to_s },
        "stage gripes about removed objid"
    }
    generate_tests "metadata_mismatch_removed", test_proc
  end

  def self.gen_metadata_mismatch_added # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 BC T bitonal 1"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      new_objid = test_shipment_class.generate_objid
      FileUtils.mkdir_p File.join(shipment.directory,
        shipment.objid_to_path(new_objid))
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /added/i.match? e.to_s },
        "stage gripes about added objid"
    }
    generate_tests "metadata_mismatch_added", test_proc
  end

  def self.gen_feed_validate_error # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      tiff = File.join(shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      %w[FAKE_FEED_VALIDATE_FAIL FAKE_NEW_FEED_VALIDATE_FAIL].each do |var|
        ENV[var] = tiff
        stage = Postflight.new(shipment, config: opts.merge(@config))
        stage.run!
        assert stage.errors.any? { |e| /missing field value/i.match? e.to_s },
          "error(s) from feed validate with #{var}"
        tiff_regex = /#{Regexp.escape("00000001.tif")}/
        assert stage.errors.any? { |e| tiff_regex.match? e.to_s },
          "TIFF file in feed validate error with #{var}"
        assert stage.errors.none? { |e| /failure!/i.match? e.to_s },
          "no 'failure!' error from feed validate with #{var}"
        ENV.delete var
      end
    }
    generate_tests "feed_validate_error", test_proc
  end

  def self.gen_feed_validate_crash # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      ENV["FAKE_FEED_VALIDATE_CRASH"] = "1"
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert(stage.errors.any? { |e| /returned 1/i.match? e.to_s },
        "nonzero feed validate exit status")
      ENV.delete "FAKE_FEED_VALIDATE_CRASH"
    }
    generate_tests "feed_validate_crash", test_proc
  end

  def self.gen_checksum_mismatch # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      tiff = File.join(shipment.source_directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      `echo 'test' > #{tiff}`
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /SHA modified/i.match? e.to_s },
        "checksum error generated"
    }
    generate_tests "checksum_mismatch", test_proc
  end

  def self.gen_file_missing # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      tiff = File.join(shipment.source_directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      FileUtils.rm tiff
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /file missing/i.match? e.to_s },
        "file missing error generated"
    }
    generate_tests "file_missing", test_proc
  end

  def self.gen_file_added # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      tiff = File.join(shipment.source_directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000003.tif")
      `echo 'test' > #{tiff}`
      stage = Postflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /SHA missing/i.match? e.to_s },
        "SHA missing error generated"
    }
    generate_tests "file_added", test_proc
  end

  invoke_gen
end
