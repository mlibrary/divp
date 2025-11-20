#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "shipment"

class ShipmentTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      refute_nil shipment, "#{test_shipment_class} successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_directory
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      refute_nil shipment.directory, "#{shipment_class} #directory is not nil"
      assert File.exist?(shipment.directory),
        "#{shipment_class} #directory exists"
      assert File.directory?(shipment.directory),
        "#{shipment_class} #directory is a directory"
    }
    generate_tests "directory", test_proc
  end

  def self.gen_path_components_from_objid # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      shipment = shipment_class.new(test_shipment.directory)
      components = shipment.objid_to_path(shipment.objids[0])
      assert_equal components.count, shipment_class::PATH_COMPONENTS,
        "objid path component count = PATH_COMPONENTS"
      path = [shipment.directory]
      while (component = components.shift)
        path << component
        assert File.directory?(File.join(path)),
          "#{File.join(path)} is a directory"
      end
    }
    generate_tests "objid_to_path", test_proc
  end

  def self.gen_source_directory # rubocop:disable Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      src = shipment.source_directory
      assert_equal "source", src.split(File::SEPARATOR)[-1],
        'source directory is named "source"'
      assert_equal shipment.directory,
        src.split(File::SEPARATOR)[0..-2].join(File::SEPARATOR),
        "source directory is at top level of shipment directory"
    }
    generate_tests "source_directory", test_proc
  end

  def self.gen_tmp_directory # rubocop:disable Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      tmp = shipment.tmp_directory
      assert_equal "tmp", tmp.split(File::SEPARATOR)[-1],
        'temp directory is named "tmp"'
      assert_equal shipment.directory,
        tmp.split(File::SEPARATOR)[0..-2].join(File::SEPARATOR),
        "temp directory is at top level of shipment directory"
    }
    generate_tests "tmp_directory", test_proc
  end

  def self.gen_source_objids
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      shipment.setup_source_directory
      assert_equal shipment.objids[0],
        shipment.source_objids[0],
        "objid and source objid are the same"
    }
    generate_tests "source_objids", test_proc
  end

  def self.gen_image_files # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      spec = "BC T contone 1 T contone 2 BC T contone 1 BC"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      files = shipment.image_files
      assert_equal 3, files.count, "3 image files"
      assert_kind_of ImageFile, files[0], "produces ImageFile"
      refute_nil files[0].objid, "ImageFile objid is not nil"
      refute_nil files[0].path, "ImageFile path is not nil"
    }
    generate_tests "image_files", test_proc
  end

  def self.gen_setup_source_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      shipment.setup_source_directory
      path = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]))
      assert File.directory?(path), "source/objid directory created"
      path = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      assert File.exist?(path), "source/objid/00000001.tif created"
    }
    generate_tests "setup_source_directory", test_proc
  end

  def self.gen_restore_from_source_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      shipment.setup_source_directory
      tiff = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      tiff_size = File.size tiff
      `/bin/echo -n 'test' > #{tiff}`
      assert_equal 4, File.size(tiff), "new file is 4 bytes"
      shipment.restore_from_source_directory
      assert_equal tiff_size, File.size(tiff),
        "TIFF file is restored to original size"
    }
    generate_tests "restore_from_source_directory", test_proc
  end

  def self.gen_partial_restore_from_source_directory # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      spec = "BC T contone 1 BC T contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      shipment.setup_source_directory
      tiff0 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      tiff0_size = File.size tiff0
      `/bin/echo -n 'test' > #{tiff0}`
      tiff1 = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[1]),
        "00000001.tif")
      `/bin/echo -n 'test' > #{tiff1}`
      shipment.restore_from_source_directory [shipment.objids[0]]
      assert_equal tiff0_size, File.size(tiff0),
        "TIFF file in restored directory at original size"
      assert_equal 4, File.size(tiff1),
        "TIFF file in nonrestored directory at modified size"
    }
    generate_tests "partial_restore_from_source_directory", test_proc
  end

  def self.gen_restore_from_nonexistent_source_directory
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      assert_raises(Errno::ENOENT, "raises Errno::ENOENT") do
        shipment.restore_from_source_directory
      end
    }
    generate_tests "restore_from_nonexistent_source_directory", test_proc
  end

  def self.gen_fixity_check # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, _opts| # rubocop:disable Metrics/BlockLength
      test_shipment = test_shipment_class.new(dir, "BC T contone 2-3")
      shipment = shipment_class.new(test_shipment.directory)
      shipment.setup_source_directory
      shipment.checksum_source_directory
      # Add 00000001.tif, change 00000002.tif, and remove 00000003.tif
      tiff1 = File.join(shipment.source_directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      refute File.exist?(tiff1), "(make sure 00000001.tif does not exist)"
      `/bin/echo -n 'test' > #{tiff1}`
      tiff2 = File.join(shipment.source_directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000002.tif")
      `/bin/echo -n 'test' > #{tiff2}`
      tiff3 = File.join(shipment.source_directory,
        shipment.objid_to_path(shipment.objids[0]),
        "00000003.tif")
      FileUtils.rm tiff3
      fixity = shipment.fixity_check
      assert_equal 1, fixity[:added].count, "one file added"
      objid_file = File.join(shipment.objid_to_path(shipment.objids[0]),
        "00000001.tif")
      assert_equal objid_file, fixity[:added][0].objid_file,
        "00000001.tif added"
      assert_equal 1, fixity[:changed].count, "one file changed"
      objid_file = File.join(shipment.objid_to_path(shipment.objids[0]),
        "00000002.tif")
      assert_equal objid_file, fixity[:changed][0].objid_file,
        "00000002.tif changed"
      assert_equal 1, fixity[:removed].count, "one file changed"
      objid_file = File.join(shipment.objid_to_path(shipment.objids[0]),
        "00000003.tif")
      assert_equal objid_file, fixity[:removed][0].objid_file,
        "00000003.tif removed"
    }
    generate_tests "fixity_check", test_proc
  end

  def self.gen_finalize # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      shipment = shipment_class.new(test_shipment.directory)
      shipment.setup_source_directory
      shipment.finalize
      refute File.exist?(shipment.source_directory), "source directory deleted"
      assert shipment.metadata[:finalized], "finalized status recorded"
      assert shipment.finalized?, "finalized? returns true"
      assert_raises(FinalizedShipmentError) do
        shipment.setup_source_directory
      end
    }
    generate_tests "finalize", test_proc
  end

  # Invoke all the generators
  invoke_gen
end
