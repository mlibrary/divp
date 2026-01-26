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
      remove_existing_checksum_file(dir)
      ChecksumFileGenerator.write(dir)
    end
  end

  private

  def remove_existing_checksum_file(dir)
    checksum_file_path = File.join(dir, "checksum.md5")
    FileUtils.rm_f(checksum_file_path) if File.exist?(checksum_file_path)
  end
end
