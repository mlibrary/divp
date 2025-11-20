#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

# Wrapper for Open3 invocation of external binaries
class Command
  attr_reader :status

  def initialize(cmd)
    @cmd = cmd
    @status = {}
  end

  def run(raise_error = true)
    @start = Time.now
    stdout_str, stderr_str, code = Open3.capture3(@cmd)
    if !code.success? && raise_error
      raise "'#{@cmd}' returned #{code.exitstatus}: #{stderr_str}"
    end

    @end = Time.now
    @status = {stdout: stdout_str,
               stderr: stderr_str,
               code: code,
               time: Time.now - @start}
  end
end
