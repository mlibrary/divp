#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "string_color"

class StringColorTest < Minitest::Test
  METHODS = %i[black red green brown blue magenta cyan gray
    bg_black bg_red bg_green bg_brown bg_blue bg_magenta
    bg_cyan bg_gray
    bold italic underline blink reverse_color].freeze
  REGEX = /\e\[\d\d?m/.freeze

  def test_colors
    StringColorTest::METHODS.each do |m|
      assert "test".respond_to?(m), "String responds to ##{m}"
      assert_match StringColorTest::REGEX, "test".send(m), "String is colorized"
    end
  end

  def test_decolorize
    assert_equal "test", "test".red.decolorize, "#decolorize removes escapes"
  end
end
