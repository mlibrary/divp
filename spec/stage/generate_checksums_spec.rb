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
  let(:barcode) { "39015002231713" }
  let(:shipment_path) { "#{temp_dir_path}/test_shipment" }
  let(:item_path) { "#{shipment_path}/#{barcode}" }
  let(:shipment) { Shipment.new(shipment_path) }
  subject do
    described_class.new(shipment, config: Config.new({no_progress: true}))
  end

  def set_up_shipment
    FileUtils.mkdir_p(item_path)
    FileUtils.cp("spec/fixtures/10_10_8_400.jp2", item_path)
  end

  it "creates a checksum file" do
    set_up_shipment

    subject.run!
    checksum_contents = File.read(File.join(item_path, "checksum.md5"))
    expect(checksum_contents).to include("  10_10_8_400.jp2")
  end

  it "original checksum file is removed before calculating checksum" do
    set_up_shipment
    FileUtils.touch("#{item_path}/checksum.md5")
    subject.run!
    checksum_contents = File.read(File.join(item_path, "checksum.md5"))
    expect(checksum_contents).to include("  10_10_8_400.jp2")
    expect(checksum_contents).not_to include("  checksum.md5")
  end
end
