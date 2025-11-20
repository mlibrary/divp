#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"

require "minitest/autorun"
require "processor"
require "fixtures"

class ProcessorTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    @options = {config_dir: File.join(TEST_ROOT, "config")}
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      refute_nil processor, "processor successfully created"
      refute File.exist?(File.join(test_shipment.directory, "status.json")),
        "status.json not created yet"
      processor.write_status_file
      assert File.exist?(File.join(test_shipment.directory, "status.json")),
        "status.json created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_config
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      refute_nil processor, "processor successfully created"
      assert_match(/fake_feed_validate/,
        processor.config[:feed_validate_script],
        "has custom feed_validate_script path")
    }
    generate_tests "config", test_proc
  end

  def self.gen_stages
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      assert_kind_of Array, processor.stages, "processor#stages is Array"
      assert_kind_of Stage, processor.stages[0],
        "processor#stages is Array of Stage"
    }
    generate_tests "stages", test_proc
  end

  def self.gen_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC F .DS_Store")
      options = {no_progress: true}
      processor = Processor.new(test_shipment.directory, opts.merge(options))
      capture_io do
        processor.run
      end
      errs = processor.errors["Preflight"][processor.shipment.objids[0]]
      warnings = processor.warnings["Preflight"][processor.shipment.objids[0]]
      assert errs.any? { |e| /no.image.files/.match? e.to_s },
        "Preflight fails with no images error"
      assert warnings.any? { |e| /\.DS_Store/.match? e.to_s },
        "Preflight warns about .DS_Store"
    }
    generate_tests "run", test_proc
  end

  def self.gen_invalid_status_file
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC F .DS_Store")
      status_json = File.join(test_shipment.directory, "status.json")
      FileUtils.touch(status_json)
      assert_raises(JSON::ParserError) do
        Processor.new(test_shipment.directory, opts.merge(@options))
      end
      assert_equal(File.size(status_json), 0, "status.json is unmodified")
    }
    generate_tests "invalid_status_file", test_proc
  end

  # Don't pass TestShipment to anything we want to serialize --
  # the initializer isn't JSON-aware
  def self.gen_reload_status_file # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bad_16bps 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
      end
      processor.write_status_file
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      errs = processor.errors["Image Validator"][processor.shipment.objids[0]]
      assert_kind_of Error, errs[0],
        "Error class reconstituted from status.json"
    }
    generate_tests "reload_status_file", test_proc
  end

  # Don't pass TestShipment to anything we want to serialize --
  # the initializer isn't JSON-aware
  def self.gen_move_status_file # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      processor.write_status_file
      shipment_copy_dir = File.join(TEST_ROOT, "shipments", dir + "_COPY")
      FileUtils.copy_entry(test_shipment.directory, shipment_copy_dir)
      FileUtils.rm_r(test_shipment.directory, force: true)
      processor = Processor.new(shipment_copy_dir, opts.merge(@options))
      assert_equal 1, processor.shipment.objids.count,
        "relocated shipment can access its objids"
      FileUtils.rm_r(shipment_copy_dir, force: true)
    }
    generate_tests "move_status_file", test_proc
  end

  def self.gen_restore_from_source_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      shipment = processor.shipment
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      old_hash = Digest::SHA256.file(tiff).hexdigest
      shipment.setup_source_directory
      `/bin/echo -n 'test' > #{tiff}`
      capture_io do
        processor.restore_from_source_directory
      end
      assert File.exist?(tiff), "00000001.tif restored from source"
      new_hash = Digest::SHA256.file(tiff).hexdigest
      assert_equal old_hash, new_hash, "00000001.tif matches hash from source"
    }
    generate_tests "restore_from_source_directory", test_proc
  end

  def self.gen_finalize # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
      end
      processor.write_status_file
      capture_io do
        processor.finalize
      end
      assert File.exist?(processor.status_file), "status.json intact"
      refute File.exist?(processor.shipment.source_directory),
        "shipment source deleted"
    }
    generate_tests "finalize", test_proc
  end

  def self.gen_finalize_does_nothing # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bad_16bps 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
      end
      processor.write_status_file
      capture_io do
        processor.finalize
      end
      assert File.exist?(processor.status_file), "status.json left intact"
      assert File.exist?(processor.shipment.source_directory),
        "shipment source left intact"
    }
    generate_tests "finalize_does_nothing", test_proc
  end

  def self.gen_restart_finalized # rubocop:disable Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
        processor.finalize
      end
      processor.write_status_file
      assert_raises(FinalizedShipmentError) do
        processor = Processor.new(test_shipment.directory,
          opts.merge({restart_all: 1}))
      end
    }
    generate_tests "restart_finalized", test_proc
  end

  invoke_gen
end

class ProcessorErrorCorrectionTest < Minitest::Test
  def setup
    @options = {config_dir: File.join(TEST_ROOT, "config")}
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  # Initial run detects bogus file, replacement allows second run to pass,
  # and fixity is updated with the new file.
  def self.gen_error_correction # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      spec = "BC T contone 1 BC T bad_16bps 1"
      test_shipment = test_shipment_class.new(dir, spec)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
      end
      refute processor.errors.none?, "error detected"
      bad_objid = test_shipment.ordered_objids[1]
      tiff = File.join(processor.shipment.objid_to_path(bad_objid),
        "00000001.tif")
      old_checksum = processor.shipment.checksums[tiff]
      fixture = Fixtures.tiff_fixture("contone")
      dest = File.join(processor.shipment.source_objid_directory(bad_objid),
        "00000001.tif")
      FileUtils.cp fixture, dest
      capture_io do
        processor.run
      end
      new_checksum = processor.shipment.checksums[tiff]
      refute_nil new_checksum, "bad file has a checksum"
      refute_equal new_checksum, old_checksum,
        "old and new checksums should not match"
    }
    generate_tests "error_correction", test_proc
  end

  invoke_gen
end
