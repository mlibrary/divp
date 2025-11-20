#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "command"

class CommandTest < Minitest::Test
  def test_new
    config = Command.new("ls")
    refute_nil config, "Command successfully created"
  end

  def test_run
    status = Command.new("ls").run
    refute_nil status, "Command #run returns non-nil status"
    assert_instance_of String, status[:stdout], "Command stdout is a String"
    assert_instance_of String, status[:stderr], "Command stderr is a String"
    refute_nil status[:code], "Command status has non-nil code"
    assert_instance_of Float, status[:time], "Command time is a Float"
  end

  def test_raise
    assert_raises(StandardError, "#run raises errors by default") do
      Command.new("ls -0").run
    end
  end

  def test_noraise
    status = Command.new("ls -0").run(false)
    refute_nil status, "Command #run returns non-nil status instead of raising"
  end
end
