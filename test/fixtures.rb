#!/usr/bin/env ruby
# frozen_string_literal: true

module Fixtures
  TIFF_FIXTURES = {
    bitonal: {
      file: "10_10_1_600.tif",
      description: "well-formed 10 x 10 600ppi bitonal image"
    },
    contone: {
      file: "10_10_8_400.tif",
      description: "well-formed 10 x 10 400ppi contone image"
    },
    bad_16bps: {
      file: "10_10_1_16bps_400.tif",
      description: "16bps image that will fail Image Validator and Compression"
    }
  }.freeze
  JP2_FIXTURES = {
    contone: {
      file: "10_10_8_400.jp2",
      description: "well-formed 10 x 10 400ppi contone image"
    }
  }.freeze
  TEST_FIXTURES_PATH = File.join(__dir__, "fixtures").freeze

  def self.tiff_fixture(name)
    return unless TIFF_FIXTURES[name.to_sym]

    File.join(TEST_FIXTURES_PATH, TIFF_FIXTURES[name.to_sym][:file])
  end

  def self.jp2_fixture(name)
    return unless JP2_FIXTURES[name.to_sym]

    File.join(TEST_FIXTURES_PATH, JP2_FIXTURES[name.to_sym][:file])
  end
end
