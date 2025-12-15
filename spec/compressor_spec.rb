describe Compressor do
  include_context "uses temp dir"

  context "#run" do
    it "removes alpha when it exists" do
      image_file = double("image_file", path: "spec/fixtures/10_10_8_400_alpha.tif")
      # image_file = double("image_file", path: "input/output-alpha2.tiff")
      compressor = Compressor.new(image_file: image_file, tmpdir: Pathname(temp_dir))
      expect(compressor).not_to be_nil
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
end
