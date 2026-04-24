#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"
require "tiff"
require "compressor"

# TIFF to JP2/TIFF compression stage
class Compression < Stage
  def run(agenda)
    return unless agenda.any?
    files = image_files.select { |file| agenda.include? file.objid }
    @bar.steps = files.count
    files.each_with_index do |image_file, i|
      compressor_klass = Compressor.klass_for(image_file: image_file, config: config)

      @bar.step! i, "#{image_file.objid_file} #{compressor_klass.compression_type}"
      next if compressor_klass.compression_type == "None"

      compressor = compressor_klass.new(image_file: image_file, tmpdir: create_tempdir, logger: logger)

      compressor.run

      on_disk_temp_image_path = compressor.final_image_path.sub(shipment.directory, shipment.tmp_directory)
      system("mkdir -p #{File.dirname(on_disk_temp_image_path)}")
      system("cp #{compressor.output_path} #{on_disk_temp_image_path}")

      copy_on_success on_disk_temp_image_path, compressor.final_image_path, compressor.image_file.objid
      delete_on_success compressor.image_file.path, compressor.image_file.objid if compressor.compression_type == "JP2"

      system("rm -r #{compressor.tmpdir}/*")
    rescue => e
      add_error Error.new(e.message, image_file.objid, image_file.file)
      next
    end
  end
end
