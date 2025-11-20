#!/usr/bin/env ruby
# frozen_string_literal: true

# Single-line CLI ASCII art progress bar.
# Can be used in the following ways:
# [1, 2].each do |n|
#   bar.next! "doing #{n}" # prints "(0/2) doing 1", "(1/2) doing 2"
# end
# bar.done! # prints "(2/2)"
#
# OR
#
# [1, 2].each_with_index do |n, i|
#   bar.step! i, "doing #{n}" # prints "(0/2) doing 1", "(1/2) doing 2"
# end
# bar.done! # prints "(2/2)"
class ProgressBar
  attr_accessor :error, :warning, :steps, :done

  def initialize(owner = "")
    @done = nil
    @steps = 0
    @owner = owner
    @error = false
    @warning = false
    @newline = false
  end

  def step!(done, action = "")
    return if done?

    @done = done
    @done = @steps if @done > @steps
    draw action
  end

  def next!(action = "")
    step! (@done.nil? ? 0 : @done + 1), action
  end

  def done?
    (@done || 0) >= @steps && @newline
  end

  def done!(action = "")
    step! @steps, action
  end

  # The \033[K is to erase the entire line in case a previous action string
  # might not be completely overwritten by a subsequent shorter one.
  def draw(action = "")
    return if @newline

    progress = @steps.zero? ? 10 : 10 * (@done || 0) / @steps
    printf("\r\033[K%-16s |%s| (#{done}/#{steps}) #{action}",
      @owner, bar(progress))
    return unless progress >= 10

    puts "\n"
    @newline = true
  end

  private

  def bar(progress)
    segment ||= "█".encode("utf-8")
    bar = format "%<segments>-10s", segments: segment * progress
    bar = bar.brown if @warning && !@error
    bar = bar.red if @error
    bar
  end
end

# ProgressBar that doesn't draw anything
class SilentProgressBar < ProgressBar
  def draw(action = "")
    # No-op
  end
end
