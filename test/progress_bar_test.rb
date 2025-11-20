#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "progress_bar"

class ProgressBarTest < Minitest::Test
  def test_new
    bar = ProgressBar.new
    refute_nil bar, "progress bar successfully created"
  end

  def test_output
    bar = ProgressBar.new
    bar.steps = 10
    out, _err = capture_io do
      bar.step! 1
    end
    assert_match(/\u2588/, out, "draws one block")
    out, _err = capture_io do
      bar.next!
    end
    assert_match(/\u2588\u2588/, out, "draws two blocks")
  end

  def test_done!
    bar = ProgressBar.new
    bar.steps = 10
    capture_io do
      bar.done!
    end
    assert_equal 10, bar.done, "bar.done! sets done=steps"
  end

  def test_step!
    bar = ProgressBar.new
    bar.steps = 10
    capture_io do
      bar.step! 2
    end
    assert_equal 2, bar.done, "bar.step!(2) increments by 2"
    capture_io do
      bar.step! 20
    end
    assert_equal bar.steps, bar.done, "bar.step!(20) stops at bar.steps"
  end

  def test_next!
    bar = ProgressBar.new
    bar.steps = 10
    capture_io do
      bar.next!
    end
    assert_equal 0, bar.done, "bar.next! sets progress to 0 initially"
    capture_io do
      bar.next!
    end
    assert_equal 1, bar.done, "bar.next! sets progress to 1 subsequently"
  end

  def test_done?
    bar = ProgressBar.new
    capture_io do
      bar.done!
    end
    assert bar.done?, "bar.done? true at progress 1/1"
  end

  def test_error
    bar = ProgressBar.new
    bar.error = true
    out, _err = capture_io do
      bar.done!
    end
    assert_match(/\e\[31m/, out, "error turns output red")
  end
end
