#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "config"

class ConfigTest < Minitest::Test
  def setup
    @options = {config_dir: File.join(TEST_ROOT, "config")}
  end

  def test_new
    config = Config.new(@options)
    refute_nil config, "Config successfully created"
  end

  def test_to_s
    config = Config.new(@options)
    assert config.to_s.is_a?(String), "to_s returns String"
  end

  def test_hash_methods
    config = Config.new(@options)
    assert config.key?(:feed_validate_script), "key? returns true"
    assert config[:feed_validate_script], "[] returns a value"
    assert_instance_of Method, config.method(:count),
      "#count is a Method"
  end

  def test_options
    config = Config.new(@options)
    assert config.key?(:config_dir), ":config_dir key from options"
  end

  def test_profile
    config = Config.new(@options.merge({config_profile: "dlxs"}))
    refute_nil config, "Config successfully created"
    assert config[:stages].any? { |s| s[:class] == "DLXSCompressor" },
      "config has DLXSCompressor stage"
    assert config[:blah] == "blah", "test value from config.dlxs.local.yml"
  end

  def test_raises_if_no_entry
    assert_raises Errno::ENOENT do
      Config.new({config_dir: File.join(TEST_ROOT, "shipments")})
    end
  end
end
