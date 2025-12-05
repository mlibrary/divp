#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "jhove"

# Test basic functions of lib/jhove.rb
class JHOVETest < Minitest::Test
  def setup
    @config = Config.new({config_dir: File.join(TEST_ROOT, "config"),
                          no_progress: true})
  end

  def teardown
    TestShipment.remove_test_shipments
    %w[FAKE_FEED_VALIDATE_FAIL FAKE_NEW_FEED_VALIDATE_FAIL
      FAKE_FEED_VALIDATE_LONG].each do |var|
      ENV.delete var
    end
  end

  def setup_test(shipment_class, test_shipment_class, dir, opts)
    @test_shipment = test_shipment_class.new(dir, "BC T bitonal 1 T contone 2")
    @shipment = shipment_class.new(@test_shipment.directory)
    @jhove = JHOVE.new(@shipment.directory, @config.merge(opts))
  end

  def self.gen_new
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      setup_test(shipment_class, test_shipment_class, dir, opts)
      refute_nil @jhove, "JHOVE runner successfully created"
    }
    generate_tests "new", test_proc
  end

  def self.gen_run
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      setup_test(shipment_class, test_shipment_class, dir, opts)
      @jhove.run
      assert @jhove.errors.none?, "JHOVE runner runs without errors"
    }
    generate_tests "run", test_proc
  end

  def self.gen_error # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      setup_test(shipment_class, test_shipment_class, dir, opts)
      tiff = File.join(@shipment.objid_to_path(@shipment.objids[0]),
        "00000001.tif")
      %w[FAKE_FEED_VALIDATE_FAIL FAKE_NEW_FEED_VALIDATE_FAIL].each do |var|
        ENV[var] = tiff
        @jhove = JHOVE.new(@shipment.directory, @config.merge(opts))
        @jhove.run
        assert @jhove.errors.is_a?(Array), "JHOVE #errors returns an Array"
        tiff_regex = /#{Regexp.escape("00000001.tif")}/
        assert @jhove.errors.any? { |err| tiff_regex.match? err.to_s },
          "TIFF file in feed validate error with #{var}"
        assert @jhove.errors.none? { |err| /failure!/i.match? err.to_s },
          "no 'failure!' error from feed validate with #{var}"
        ENV.delete var
      end
    }
    generate_tests "error", test_proc
  end

  def self.gen_error_fields # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      setup_test(shipment_class, test_shipment_class, dir, opts)
      ENV["FAKE_FEED_VALIDATE_LONG"] = "1"
      @jhove.run
      fields = @jhove.error_fields
      assert fields.is_a?(Array), "JHOVE #error_fields returns an Array"
      assert fields.any? { |field| /tiff:Orientation/.match? field },
        "tiff:Orientation error field"
      assert fields.any? { |field| /tiff:Artist/.match? field },
        "tiff:Artist error field"
      fields.each do |field|
        assert_equal 1, @jhove.errors_for_field(field).count,
          "1 error for field '#{field}'"
      end
    }
    generate_tests "error_fields", test_proc
  end

  def self.gen_raw_output
    test_proc = proc { |shipment_class, test_shipment_class, dir, opts|
      setup_test(shipment_class, test_shipment_class, dir, opts)
      ENV["FAKE_FEED_VALIDATE_LONG"] = "1"
      @jhove.run
      assert @jhove.raw_output.is_a?(String),
        "JHOVE #raw_output returns a String"
    }
    generate_tests "raw_output", test_proc
  end

  invoke_gen
end
