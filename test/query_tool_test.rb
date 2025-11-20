#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "query_tool"

class QueryToolTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def setup
    @options = {config_dir: File.join(TEST_ROOT, "config"),
                no_progress: true}
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      tool = QueryTool.new(processor)
      refute_nil tool, "query tool successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_agenda_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.agenda_cmd
      end
      out = out.decolorize
      processor.stages.each do |stage|
        assert_match "#{stage.name}\n  (all objids)", out,
          "#{stage.name} all objids"
      end
    }
    generate_tests "agenda_cmd", test_proc
  end

  def self.gen_agenda_cmd_no_agenda # rubocop:disable Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
      end
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.agenda_cmd
      end
      assert_match(/no agenda/i, out, "no agenda after completion")
    }
    generate_tests "agenda_cmd_no_agenda", test_proc
  end

  def self.gen_objids_cmd
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.objids_cmd
      end
      assert_match(test_shipment.objids[0], out, "objid is listed")
    }
    generate_tests "objids_cmd", test_proc
  end

  def self.gen_objids_cmd_with_errors # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bad_16bps 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      stage = processor.stages[0]
      stage.add_error Error.new("err", processor.shipment.objids[0],
        "00000001.tif")
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.objids_cmd
      end
      assert_match("#{processor.shipment.objids[0]} ERROR", out.decolorize,
        "objid is listed with error")
    }
    generate_tests "objids_cmd_with_errors", test_proc
  end

  def self.gen_errors_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      spec = "BC T contone 1 BC T contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      shipment = processor.shipment
      stage = processor.stages[0]
      stage.add_error Error.new("err 1", shipment.objids[0], "00000001.tif")
      stage.add_error Error.new("err 2", shipment.objids[1], "00000002.tif")
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.errors_cmd
      end
      assert_match "00000001.tif", out, "reports errors for both files"
      assert_match shipment.objids[0], out, "reports errors for both objids"
      assert_match "00000002.tif", out, "reports errors for both files"
      assert_match shipment.objids[1], out, "reports errors for both objids"
      out, _err = capture_io do
        tool.errors_cmd shipment.objids[0]
      end
      assert_match "00000001.tif", out, "reports error for first file"
      assert_match shipment.objids[0], out, "reports error for first objid"
      refute_match "00000002.tif", out, "no error for second file"
      refute_match shipment.objids[1], out, "no error for second objid"
    }
    generate_tests "errors_cmd", test_proc
  end

  def self.gen_warnings_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      spec = "BC T contone 1 BC T contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      shipment = processor.shipment
      stage = processor.stages[0]
      stage.add_warning Error.new("err 1", shipment.objids[0], "00000001.tif")
      stage.add_warning Error.new("err 2", shipment.objids[1], "00000002.tif")
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.warnings_cmd
      end
      assert_match "00000001.tif", out, "warnings for both files"
      assert_match shipment.objids[0], out, "warnings for both objids"
      assert_match "00000002.tif", out, "warnings for both files"
      assert_match shipment.objids[1], out, "warnings for both objids"
      out, _err = capture_io do
        tool.warnings_cmd shipment.objids[0]
      end
      assert_match "00000001.tif", out, "warning for first file"
      assert_match shipment.objids[0], out, "warning for first objid"
      refute_match "00000002.tif", out, "no warning for second file"
      refute_match shipment.objids[1], out, "no warning for second objid"
    }
    generate_tests "warnings_cmd", test_proc
  end

  def self.gen_status_cmd
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      tool = QueryTool.new(processor)
      assert_output(/not.yet.run/i) { tool.status_cmd }
    }
    generate_tests "status_cmd", test_proc
  end

  def self.gen_status_cmd_err
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bad_16bps 1")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      capture_io do
        processor.run
      end
      tool = QueryTool.new(processor)
      assert_output(/1.error/i) { tool.status_cmd }
    }
    generate_tests "status_cmd_err", test_proc
  end

  def self.gen_fixity_cmd # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T contone 2-3")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      shipment = processor.shipment
      shipment.setup_source_directory
      shipment.checksum_source_directory
      objid = shipment.objids[0]
      objid_path = shipment.objid_to_path(objid)
      # Add 00000001.tif, change 00000002.tif, and remove 00000003.tif
      tiff1 = File.join(shipment.source_directory, objid_path, "00000001.tif")
      refute File.exist?(tiff1), "(make sure 00000001.tif does not exist)"
      `/bin/echo -n 'test' > #{tiff1}`
      tiff2 = File.join(shipment.source_directory, objid_path, "00000002.tif")
      `/bin/echo -n 'test' > #{tiff2}`
      tiff3 = File.join(shipment.source_directory, objid_path, "00000003.tif")
      FileUtils.rm tiff3
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.fixity_cmd
      end
      out = out.decolorize
      assert_match "Added\n  #{File.join(objid_path, "00000001.tif")}",
        out, "00000001.tif added"
      assert_match "Changed\n  #{File.join(objid_path, "00000002.tif")}",
        out, "00000002.tif changed"
      assert_match "Removed\n  #{File.join(objid_path, "00000003.tif")}",
        out, "00000003.tif removed"
    }
    generate_tests "fixity_cmd", test_proc
  end

  def self.gen_fixity_cmd_not_yet_populated # rubocop:disable Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      processor = Processor.new(test_shipment.directory, opts.merge(@options))
      tool = QueryTool.new(processor)
      out, _err = capture_io do
        tool.fixity_cmd
      end
      out = out.decolorize
      assert_match "not yet populated", out,
        "warns that source directory is unpopulated"
    }
    generate_tests "fixity_cmd_not_yet_populated", test_proc
  end

  invoke_gen
end
