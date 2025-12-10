describe Compressor do
  include_context "uses temp dir"

  context "#run" do
    it "removes alpha when it exists" do
      image_file = double("image_file", path: "spec/fixtures/10_10_8_400.tif")
      compressor = Compressor.new(image_file: image_file, tmpdir: Pathname(temp_dir))
      expect(compressor).not_to be_nil
    end
  end
end
