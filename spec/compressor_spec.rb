class FakeCompressionTool
  def self.compress(sparse_path, new_path, tiffinfo)
    FileUtils.cp(File.join("spec/fixtures/10_10_8_400.jp2"), new_path)
    LogEntry.info(command: nil, time: nil)
  end
end

describe Compressor do
  include_context "uses temp dir"
  let(:log) { Log.new }
  let(:compression_tool) { FakeCompressionTool }
  # image file has path, objid, objid_file, file
  # objid="omzhx8s5.0074.149"
  # path="/usr/src/app/test/shipments/DLXSCompressorTest_test_run_DLXS/omzhx8s5/0074/149/00000001.tif"
  # objid_file="omzhx8s5/0074/149/00000001.tif"
  # file="00000001.tif"
  let(:path) { File.join("spec/fixtures", @image_file) }
  let(:objid) { "some_barcode" }
  let(:objid_file) { File.join(objid, @image_file) }
  let(:image_file) { double("image_file", path: path, objid: objid, objid_file: objid_file, file: @image_file) }
  let(:compressor) do
    Compressor.for(image_file: image_file, tmpdir: Pathname(temp_dir), log: log)
  end
  before(:each) do
    @image_file = "10_10_8_400.tif"
  end
  it "generates final document name" do
    expect(compressor.document_name).to eq("some_barcode/10_10_8_400.jp2")
  end

  it "is a Color compressor when initialized with an 8bps image" do
    expect(compressor.class.to_s).to eq("Compressor::Color")
  end

  context "#run" do
    it "removes alpha when it exists" do
      @image_file = "10_10_8_400_alpha.tif"
      compressor.run(compression_tool)
      expect(log.entries).to include(match("-alpha off"))
    end

    it "ignores alpha when it doesn't exist" do
      compressor.run(compression_tool)
      expect(log.entries).not_to include(match("-alpha off"))
    end

    it "strips tiff profile data when it exists" do
      @image_file = "10_10_8_400_icc.tif"
      compressor.run(compression_tool)
      expect(log.entries).to include(match("-strip"))
    end

    it "ignores tiff profile when it doesn't exist" do
      compressor.run(compression_tool)
      expect(log.entries).not_to include(match("-strip"))
    end

    it "runs the compression tool" do
      compressor.run
      expect(log.entries).to include(match("kdu_compress"))
    end

    it "copies original metadata to the jpeg2000" do
      compressor.run
      expect(log.entries).to include(match("tiff:Compression=JPEG 2000"))
    end

    xit "copies original image datetime when present" do
    end

    it "copies alphaless metadata to the jp2 when tiff has alpha" do
      @image_file = "10_10_8_400_alpha.tif"
      compressor.run(compression_tool)
      expect(log.entries).to include(match("PhotometricInterpretation>XMP-tiff")).twice
    end
  end
end

describe ImageMagick do
  include_context "uses temp dir"
  context "#remove_tiff_alpha" do
    it "removes the alpha channel if it exists" do
      tiff_path = "#{temp_dir}/input.tif"
      FileUtils.copy("spec/fixtures/10_10_8_400_alpha.tif", tiff_path)
      expect(TIFF.new(tiff_path).info[:alpha]).to eq(true)
      ImageMagick.remove_tiff_alpha(tiff_path)
      expect(TIFF.new(tiff_path).info[:alpha]).to eq(false)
    end
  end

  context "#strip_tiff_profiles" do
    it "strips tiff profile data" do
      tiff_path = "#{temp_dir}/input.tif"
      FileUtils.copy("spec/fixtures/10_10_8_400_icc.tif", tiff_path)
      expect(TIFF.new(tiff_path).info[:icc]).to eq(true)
      ImageMagick.strip_tiff_profiles(tiff_path)
      expect(TIFF.new(tiff_path).info[:icc]).to eq(false)
    end

    it "handles warnings" do
      tiff_path = "spec/fixtures/10_10_8_400_fake.tif"
      log_entry = ImageMagick.strip_tiff_profiles(tiff_path)
      expect(log_entry.level).to eq(:warning)
    end
  end
end
