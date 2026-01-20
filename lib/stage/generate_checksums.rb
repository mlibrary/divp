#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"

module ChecksumFileGenerator
  def self.write(path)
    FileUtils.cd(path) do
      `md5sum * > checksum.md5`
    end
  end
end

class GenerateChecksums < Stage
  def run(agenda)
    @bar.steps = shipment.objid_directories.count
    shipment.objid_directories.each_with_index do |dir, i|
      @bar.step! i, dir
      ChecksumFileGenerator.write(dir)
    end
  end
end
