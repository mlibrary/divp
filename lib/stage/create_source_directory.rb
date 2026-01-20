require "stage"

class CreateSourceDirectory < Stage
  def run(agenda)
    setup_source_directory
  end

  private

  def setup_source_directory
    shipment.setup_source_directory do |objid|
      @bar.next! "setup source/#{objid}"
    end
    shipment.checksum_source_directory do |objid|
      @bar.next! "checksum source/#{objid}"
    end
  end
end
