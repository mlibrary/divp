#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "preflight"

class PreflightTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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
      stage = Preflight.new(shipment, config: opts.merge(@config))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 BC T bitonal 1"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal 0, stage.errors.count, "stage runs without errors"
      assert_equal 2, shipment.metadata[:initial_barcodes].count,
        "correct number of initial objids in metadata"
      assert_equal 2, shipment.checksums.count,
        "correct number of checksums in metadata"
    }
    generate_tests "run", test_proc
  end

  def self.gen_validate_objid
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BBC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert_equal(0, stage.errors.count, "stage produces no errors")
      # Different shipment classes will generate different warning messages
      assert_equal(1, stage.warnings.count, "stage produces one warning")
    }
    generate_tests "validate_objid", test_proc
  end

  def self.gen_remove_ds_store # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      ds_store = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        ".DS_Store")
      FileUtils.touch(ds_store)
      assert(File.exist?(ds_store), ".DS_Store file created")
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.warnings.any? { |e| /\.DS_Store/.match? e.to_s },
        "stage warns about removed .DS_Store"
      refute File.exist?(ds_store), ".DS_Store file removed"
    }
    generate_tests "remove_ds_store", test_proc
  end

  def self.gen_remove_thumbs_db # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      thumbs = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "Thumbs.db")
      FileUtils.touch(thumbs)
      assert File.exist?(thumbs), "Thumbs.db file created"
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.warnings.any? { |e| /Thumbs\.db/i.match? e.to_s },
        "stage warns about removed .DS_Store"
      refute(File.exist?(thumbs), "Thumbs.db file removed")
    }
    generate_tests "remove_thumbs_db", test_proc
  end

  def self.gen_remove_toplevel_ds_store # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      ds_store = File.join(shipment.directory, ".DS_Store")
      FileUtils.touch(ds_store)
      assert File.exist?(ds_store), ".DS_Store file created"
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.warnings.any? { |e| /\.DS_Store/.match? e.to_s },
        "stage warns about removed .DS_Store"
      refute(File.exist?(ds_store), ".DS_Store file removed")
    }
    generate_tests "remove_toplevel_ds_store", test_proc
  end

  def self.gen_remove_toplevel_thumbs_db # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1")
      shipment = shipment_class.new(test_shipment.directory)
      thumbs = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "Thumbs.db")
      FileUtils.touch(thumbs)
      assert File.exist?(thumbs), "Thumbs.db file created"
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.warnings.any? { |e| /Thumbs\.db/i.match? e.to_s },
        "stage warns about removed .DS_Store"
      refute File.exist?(thumbs), "Thumbs.db file removed"
    }
    generate_tests "remove_toplevel_thumbs_db", test_proc
  end

  def self.gen_objid_directory_errors_and_warnings # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC F spurious_file")
      shipment = shipment_class.new(test_shipment.directory)
      checksum_md5 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "checksum.md5")
      FileUtils.touch checksum_md5
      spurious_d = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "spurious_d")
      Dir.mkdir spurious_d
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /spurious_file/.match? e.to_s },
        "stage fails with unknown file"
      assert stage.errors.any? { |e| /spurious_d/.match? e.to_s },
        "stage fails with objid subdirectory"
      assert stage.warnings.any? { |e| /ignored/i.match? e.to_s },
        "stage warns about ignored checksum.md5 file"
    }
    generate_tests "objid_directory_errors_and_warnings", test_proc
  end

  def self.gen_shipment_directory_errors # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "F spurious_file")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Preflight.new(shipment, config: opts.merge(@config))
      stage.run!
      assert stage.errors.any? { |e| /no objids/.match? e.to_s },
        "stage fails with no objid directories"
      assert stage.errors.any? { |e| /spurious_file/.match? e.to_s },
        "stage fails with unknown file"
    }
    generate_tests "shipment_directory_errors", test_proc
  end

  invoke_gen
end
