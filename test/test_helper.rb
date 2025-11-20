#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv"

Dotenv.load

require "simplecov"

SimpleCov.start do
  add_filter do |file|
    (/_test\.rb$/.match? File.basename(file.filename))
  end
end

require_relative "../rsvp"
TEST_ROOT = File.expand_path(__dir__)
$LOAD_PATH << TEST_ROOT

require "minitest"
require "test_shipment"
require "string_color"

# Clean up any leftover test shipments
if File.directory? TestShipment::PATH
  FileUtils.rm_r(TestShipment::PATH, force: true)
end

module Minitest
  class Test
    @generated_tests = {}
    def test_name
      [self.class.to_s, caller_locations(1..1)[0].label].join "_"
    end

    def self.add_test(name)
      @generated_tests ||= {}
      if @generated_tests[name]
        puts "Warning: #{self} test #{name} may be a duplicate".brown
      end
      @generated_tests[name] = 1
    end
    # Crazy test generator:
    # Problem: we want Minitest #test_ methods for each Shipment subclass
    # Solution: Create a gen_* class method for each test Proc which
    # creates a test_* method for each shipment class.

    # Generates Shipment/DLXSShipment test_* methods
    # for the Minitest::Test class invoking it.
    # Each test case in the Minitest::Test creates test pairs using this
    # routine and then invokes them with this at the end of the file:
    def self.generate_tests(name, block) # rubocop:disable Metrics/MethodLength
      add_test name
      ["", "DLXS"].each do |type|
        method_name = "test_#{name}"
        method_name += "_#{type}" unless type == ""
        shipment_class_name = "Shipment"
        test_shipment_class_name = "TestShipment"
        opts = {}
        if type == "DLXS"
          require "dlxs_shipment"
          shipment_class_name = "DLXSShipment"
          test_shipment_class_name = "DLXSTestShipment"
          opts = {config_profile: "dlxs"}
        end
        test_shipment_class = Object.const_get(test_shipment_class_name)
        shipment_class = Object.const_get(shipment_class_name)
        test_shipment_dir = "#{self}_#{method_name}"
        define_method(method_name.to_sym) do
          instance_exec(shipment_class, test_shipment_class,
            test_shipment_dir, opts, &block)
        end
      end
    end

    # Must be called after the various gen_ class methods have been defined.
    # Finds all of them and invokes them.
    # This is a shortcut for copy/pasting a list of class methods to call.
    def self.invoke_gen
      methods.select { |m| /^gen_/.match? m.to_s }.each do |m|
        send m
      end
    end
  end
end
