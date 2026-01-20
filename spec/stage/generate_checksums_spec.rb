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
  it "does something" do
    shipment = instance_double(Shipment, is_a?: true, objids: [])
    described_class.new(shipment)
  end
end
