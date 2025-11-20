#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "pagination_check"

class PaginationCheckTest < Minitest::Test
  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      shipment = shipment_class.new(test_shipment.directory)
      stage = PaginationCheck.new(shipment, config: opts.merge(@config))
      refute_nil stage, "stage successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir, "BC T bitonal 1-5")
      shipment = shipment_class.new(test_shipment.directory)
      stage = PaginationCheck.new(shipment, config: opts.merge(@config))
      stage.run!
      assert(stage.errors.none?, "no errors")
      assert(stage.warnings.none?, "no warnings")
    }
    generate_tests "run", test_proc
  end

  def self.gen_missing # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1-2 T bitonal 4-5"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = PaginationCheck.new(shipment, config: opts.merge(@config))
      stage.run!
      assert(stage.errors.count == 1, "one missing page error")
      assert_equal(stage.errors[0].objid, shipment.objids[0],
        "error objid is shipment objid")
      assert_match(/missing/, stage.errors[0].description,
        'error contains "missing"')
    }
    generate_tests "missing", test_proc
  end

  def self.gen_missing_range # rubocop:disable Metrics/AbcSize
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 T bitonal 5"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = PaginationCheck.new(shipment, config: opts.merge(@config))
      stage.run!
      assert(stage.errors.count == 1, "one missing page range error")
      assert_match(/2-4/, stage.errors[0].description, "error contains range")
    }
    generate_tests "missing_range", test_proc
  end

  def self.gen_duplicate # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      spec = "BC T bitonal 1 J contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      shipment = shipment_class.new(test_shipment.directory)
      stage = PaginationCheck.new(shipment, config: opts.merge(@config))
      stage.run!
      assert(stage.errors.count == 1, "one error from duplicate page")
      assert_match(/duplicate/, stage.errors[0].description,
        'error contains "duplicate"')
    }
    generate_tests "duplicate", test_proc
  end

  def setup
    @config = Config.new({no_progress: true})
  end

  def teardown
    TestShipment.remove_test_shipments
  end

  invoke_gen
end
