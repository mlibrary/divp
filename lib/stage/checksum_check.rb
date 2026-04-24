#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"

module ChecksumChecker
  def self.check(item)
    cmd = "md5sum --quiet -c checksum.md5"
    FileUtils.cd(item.path) do
      status = Command.new(cmd).run
      LogEntry.info(command: cmd, time: status[:time])
    rescue => e
      error_arr = e.stdout_arr.empty? ? e.stderr_arr : e.stdout_arr
      error_arr.map do |entry|
        LogEntry.error(error: entry, objid: item.objid)
      end
    end
  end
end

class ChecksumCheck < Stage
  def run(agenda)
    @bar.steps = shipment.items.count
    shipment.items.each_with_index do |item, i|
      @bar.step! i, item
      logger.add(ChecksumChecker.check(item))
    end
  end
end
