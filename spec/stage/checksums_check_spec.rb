describe ChecksumCheck do
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

  it "verifies a correct checksum file" do
    set_up_shipment
    FileUtils.cp("spec/fixtures/good_checksum.md5", "#{item_path}/checksum.md5")

    subject.run!
    expect(subject.log_entries).to include(match("md5sum -c checksum.md5"))
  end

  it "errors on on an incorrect checksum file" do
    set_up_shipment
    FileUtils.cp("spec/fixtures/bad_checksum.md5", "#{item_path}/checksum.md5")

    subject.run!
    expect(subject.log_entries).to include(match("md5sum -c checksum.md5"))
  end
end
