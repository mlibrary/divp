describe ChecksumFileGenerator do
  include_context "uses temp dir"
  context ".write" do
    it "writes an checksum.md5 file for files in a given directory" do
      FileUtils.cp("spec/fixtures/10_10_8_400.jp2", temp_dir_path)
      described_class.write(temp_dir_path)
      checksum_contents = File.read(File.join(temp_dir_path, "checksum.md5"))
      expect(checksum_contents).to include("  10_10_8_400.jp2")
    end
  end
end

describe GenerateChecksums do
  include_context "uses temp dir"
  it "does something" do
    barcode = "39015002231713"
    shipment_path = "#{temp_dir_path}/test_shipment"
    item_path = "#{shipment_path}/#{barcode}"
    FileUtils.mkdir_p(item_path)
    FileUtils.cp("spec/fixtures/10_10_8_400.jp2", item_path)

    shipment = Shipment.new(shipment_path)
    stage = described_class.new(shipment)
    stage.run!
    checksum_contents = File.read(File.join(item_path, "checksum.md5"))
    expect(checksum_contents).to include("  10_10_8_400.jp2")
  end
end
