#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

class CommandError < StandardError
  attr_reader :command, :code, :stderr_str, :stdout_str
  def initialize(command:, code:, stderr_str:, stdout_str:)
    @command = command
    @code = code
    @stderr_str = stderr_str
    @stdout_str = stdout_str
    msg = "'#{@command}' returned #{code.exitstatus}: #{stderr_str}"
    super(msg)
  end

  def stdout_arr
    stdout_str.split("\n")
  end

  def stderr_arr
    stderr_str.split("\n")
  end
end

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
      raise CommandError.new(command: @cmd, code: code,
        stdout_str: stdout_str, stderr_str: stderr_str)
    end

    @end = Time.now
    @status = {stdout: stdout_str,
               stderr: stderr_str,
               code: code,
               time: Time.now - @start}
  end
end
