#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "stage"

class StageTest < Minitest::Test
  def setup
    @config = Config.new({no_progress: true})
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Stage.new(shipment, config: @config.merge(opts))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Stage.new(shipment, config: @config.merge(opts))
      assert_raises(StandardError, "raises for Stage#run") { stage.run }
    }
    generate_tests "run", test_proc
  end

  def self.gen_cleanup_tempdirs
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Stage.new(shipment, config: @config.merge(opts))
      tempdir = stage.create_tempdir
      assert File.exist?(tempdir), "tempdir created"
      stage.cleanup
      refute File.exist?(tempdir), "tempdir deleted by #cleanup"
    }
    generate_tests "cleanup_tempdirs", test_proc
  end

  def self.gen_cleanup_delete_on_success # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC")
      shipment = shipment_class.new(test_shipment.directory)
      stage = Stage.new(shipment, config: @config.merge(opts))
      temp = File.join(shipment.directory,
        shipment.objid_to_path(shipment.objids[0]),
        "temp.txt")
      FileUtils.touch(temp)
      stage.delete_on_success temp
      stage.cleanup
      refute File.exist?(temp), "file deleted by #delete_on_success"
    }
    generate_tests "cleanup_delete_on_success", test_proc
  end

  def self.gen_unknown_shipment_class
    test_proc = proc { |_shipment_class, _test_shipment_class, _dir, opts|
      assert_raises(StandardError, "raises unknown shipment class") do
        Stage.new("This is a String", config: @config.merge(opts))
      end
    }
    generate_tests "unknown_shipment_class", test_proc
  end

  invoke_gen
end
