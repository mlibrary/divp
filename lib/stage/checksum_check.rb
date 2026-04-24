#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"

module ChecksumChecker
  def self.check(path)
    cmd = "md5sum -c checksum.md5"
    FileUtils.cd(path) do
      status = Command.new(cmd).run
      LogEntry.info(command: cmd, time: status[:time])
    rescue => e
      e.stdout_arr.map do |entry|
        LogEntry.error(error: entry)
      end
    end
  end
end

class ChecksumCheck < Stage
  def run(agenda)
    @bar.steps = shipment.items.count
    shipment.items.each_with_index do |item, i|
      @bar.step! i, item
      log_it(ChecksumChecker.check(item.path))
    end
  end
end
