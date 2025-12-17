describe Compressor do
  include_context "uses temp dir"

  context "#run" do
    let(:log) { Stage::Log.new }

    before(:each) do
      @path = "spec/fixtures/10_10_8_400.tif"
    end

    subject do
      image_file = double("image_file", path: @path)
      compressor = Compressor.new(image_file: image_file, tmpdir: Pathname(temp_dir), log: log)
      compressor.run
    end

    it "removes alpha when it exists" do
      @path = "spec/fixtures/10_10_8_400_alpha.tif"
      subject
      expect(log.entries).to include(match("-alpha off"))
    end

    it "ignores alpha when it doesn't exist" do
      subject
      expect(log.entries).not_to include(match("-alpha off"))
    end

    it "strips tiff profile data when it exists" do
      @path = "spec/fixtures/10_10_8_400_icc.tif"
      subject
      expect(log.entries).to include(match("-strip"))
    end

    it "ignores tiff profile when it doesn't exist" do
      image_file = double("image_file", path: @path)
      compressor = Compressor.new(image_file: image_file, tmpdir: Pathname(temp_dir), log: log)
      compressor.run
      expect(log.entries).not_to include(match("-strip"))
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

    xit "gives a warning if tiff profile strip fails" do
    end
  end
end
