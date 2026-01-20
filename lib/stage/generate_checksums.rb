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
    # shipment.objid_directories
  end
end
