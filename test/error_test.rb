#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "error"

class ErrorTest < Minitest::Test
  def teardown
    # TestShipment.remove_test_shipments
  end

  def test_new
    err = Error.new("some error", "12345678", "00000001.tif")
    refute_nil err, "err is not nil"
  end

  def test_compare
    err1 = Error.new("some error", "12345678", "00000001.tif")
    err2 = Error.new("another error", "12345678", "00000001.tif")
    err3 = Error.new("some error", "12345679", "00000001.tif")
    err4 = Error.new("some error")
    assert_equal(1, err1 <=> err2, '"some error" > "another error"')
    assert_equal(-1, err1 <=> err3, '"12345678" < "12345679"')
    assert_equal(-1, err4 <=> err1, 'nil < "12345678"')
  end

  def test_to_s
    err = Error.new("some error", "12345678", "00000001.tif")
    assert err.to_s.is_a?(String), "stringified version is String"
  end

  def test_json
    err = Error.new("some error", "12345678", "00000001.tif")
    # rubocop:disable Security/JSONLoad
    err2 = JSON.unsafe_load(err.to_json)
    # rubocop:enable Security/JSONLoad
    assert err.description == err2.description &&
      err.objid == err2.objid &&
      err.path == err2.path,
      "JSON round trip"
  end
end
