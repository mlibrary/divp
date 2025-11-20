#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "agenda"

class AgendaTest < Minitest::Test
  def teardown
    TestShipment.remove_test_shipments
  end

  def self.gen_new
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      test_shipment = test_shipment_class.new(dir)
      processor = Processor.new(test_shipment.directory, opts)
      agenda = Agenda.new processor.shipment, processor.stages
      refute_nil agenda, "agenda successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_for_stage
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      spec = "BC T contone 1 BC T contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      processor = Processor.new(test_shipment.directory, opts)
      agenda = Agenda.new processor.shipment, processor.stages
      assert_equal processor.shipment.objids,
        agenda.for_stage(processor.stages[0]),
        "first stage has all shipment objids"
    }
    generate_tests "for_stage", test_proc
  end

  def self.gen_update # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      spec = "BC T contone 1 BC T contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      processor = Processor.new(test_shipment.directory, opts)
      agenda = Agenda.new processor.shipment, processor.stages
      err = Error.new "test error", processor.shipment.objids[0],
        "00000001.tif"
      processor.stages[0].add_error err
      agenda.update processor.stages[0]
      assert_equal processor.shipment.objids[1..],
        agenda.for_stage(processor.stages[1]),
        "subsequent stage has one less objid"
    }
    generate_tests "update", test_proc
  end

  def self.gen_update_fatal_error # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |_shipment_class, test_shipment_class, dir, opts|
      spec = "BC T contone 1 BC T contone 1"
      test_shipment = test_shipment_class.new(dir, spec)
      processor = Processor.new(test_shipment.directory, opts)
      agenda = Agenda.new processor.shipment, processor.stages
      err = Error.new "fatal error"
      processor.stages[0].add_error err
      agenda.update processor.stages[0]
      assert_equal 0, agenda.for_stage(processor.stages[1]).count,
        "subsequent stage has no objids"
    }
    generate_tests "update_fatal_error", test_proc
  end

  invoke_gen
end
