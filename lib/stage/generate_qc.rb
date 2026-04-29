#!/usr/bin/env ruby
# frozen_string_literal: true

require "stage"

class GenerateQC < Stage
  def run(agenda)
    qc_shipment_path = File.join(ENV["QC_DIR"], shipment.name)
    if Dir.exist?(qc_shipment_path)
      FileUtils.remove_dir(qc_shipment_path)
    end
    FileUtils.mkdir(qc_shipment_path)
    @bar.steps = shipment.items.count
    shipment.items.each_with_index do |item, i|
      qc_item_path = File.join(qc_shipment_path, item.objid_components)
      FileUtils.mkdir_p(qc_item_path)
      @bar.step! i, item
      qc_image_files(item.image_files).each do |image_file|
        FileUtils.copy(image_file.path, File.join(qc_item_path, image_file.file))
      end
    end
  end

  private

  def qc_image_files(image_files)
    if image_files.count <= 10
      image_files
    else
      select_10_or_10_percent(image_files)
    end
  end

  def select_10_or_10_percent(image_files)
    number_to_select = if image_files.count <= 100
      10
    else
      image_files.count / 10
    end

    image_files.sort_by! { |x| x.basename }
    greatest_starting_index = image_files.count - number_to_select
    starting_index = Random.rand(greatest_starting_index)
    (starting_index...starting_index + number_to_select).map { |i| image_files[i] }
  end
end
