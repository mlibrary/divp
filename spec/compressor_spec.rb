class FakeCompressionTool
  def self.compress(sparse_path, new_path, tiffinfo)
    FileUtils.cp(File.join("spec/fixtures/10_10_8_400.jp2"), new_path)
    LogEntry.info(command: nil, time: nil)
  end
end

describe Compressor do
  include_context "uses temp dir"
  def tiffinfo(path)
    `tiffinfo #{path}`
  end
  let(:log) { Log.new(objids: [objid]) }
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
  let(:now) { Time.now }
  let(:compressor) do
    Compressor.for(image_file: image_file, tmpdir: Pathname(temp_dir), log: log, now: now)
  end
  context "color tif" do
    before(:each) do
      @image_file = "10_10_8_400.tif"
      @log = Log.new
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
  context "bitonal tif" do
    before(:each) do
      @image_file = "10_10_1_600.tif"
    end
    it "is a Bitonal compressor when initialized with a 1bps image" do
      expect(compressor.class.to_s).to eq("Compressor::Bitonal")
    end
    context "#run" do
      it "runs the compression tool" do
        compressor.run
        expect(log.entries).to include(match("tifftopnm"))
      end
      it "runs copies the metadata from the original tiff to the compressed one" do
        compressor.run
        expect(log.entries).to include(match("exiftool -tagsFromFile #{compressor.image_file.path}"))
      end
      it "copies the first page of the tiff" do
        @image_file = "10_10_1_600_2pg.tif"
        starting_image_info = `tiffinfo #{path}`
        expect(starting_image_info).to include("directory 1")
        compressor.run
        result_info = tiffinfo(compressor.output_path)
        expect(result_info).not_to include("directory 1")
        expect(log.entries).to include(match("tiffcp"))
      end

      it "keeps the original datetime when the original image has one" do
        tmpdir_image_path = File.join(Pathname(temp_dir), @image_file)
        FileUtils.cp(path, tmpdir_image_path)
        one_hour_ago = Time.now - 3600
        allow(image_file).to receive(:path).and_return(tmpdir_image_path)
        TiffTools.set_tag(path: tmpdir_image_path, tag: :date_time, value: TiffTools.date_time_format(one_hour_ago))

        compressor.run
        result_info = tiffinfo(compressor.output_path)
        expect(result_info).to include("DateTime: #{TiffTools.date_time_format(one_hour_ago)}")
      end

      it "has now as the datetime when original tiff does not have a datetime" do
        compressor.run
        result_info = tiffinfo(compressor.output_path)
        expect(result_info).to include("DateTime: #{now.strftime("%Y:%m:%d %H:%M:%S")}")
      end

      it "has a document name of the original file" do
        compressor.run
        result_info = tiffinfo(compressor.output_path)
        expect(result_info).to include("DocumentName: #{objid_file}")
      end

      it "copies software from the original tiff to the output file" do
        tmpdir_image_path = File.join(Pathname(temp_dir), @image_file)
        FileUtils.cp(path, tmpdir_image_path)
        one_hour_ago = Time.now - 3600
        allow(image_file).to receive(:path).and_return(tmpdir_image_path)
        TiffTools.set_tag(path: tmpdir_image_path, tag: :software, value: "My Software")
        compressor.run
        result_software = TIFF.new(compressor.output_path).info[:software]
        expect(result_software).to eq("My Software")
        expect(log.entries).to include(match("exiftool -IFD0:Software="))
      end
      it "logs a warning if there is no software in the original" do
        compressor.run
        result_software = TIFF.new(compressor.output_path).info[:software]
        expect(result_software).to be_nil
        expect(log.warnings).to_json include(match("could not extract software"))
      end
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
