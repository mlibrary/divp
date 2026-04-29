describe GenerateQC do
  include_context "uses temp dir"

  let(:barcode) { "39015002231713" }
  let(:shipment_path) { "#{temp_dir_path}/test_shipment" }
  let(:item_path) { "#{shipment_path}/#{barcode}" }
  let(:shipment) { Shipment.new(shipment_path) }
  let(:qc_path) { "#{temp_dir_path}/qc" }

  around do |example|
    ClimateControl.modify QC_DIR: qc_path do
      example.run
    end
  end

  before(:each) do
    FileUtils.mkdir_p(qc_path)
    FileUtils.mkdir_p(item_path)
  end

  subject do
    described_class.new(shipment, config: Config.new({no_progress: true}))
  end

  def make_image_files(count)
    FileUtils.mkdir_p(item_path)
    (1..count).each do |page_num|
      FileUtils.touch("#{item_path}/#{page_num.to_s.rjust(7, "0")}.tif")
    end
  end

  it "copies all of the files to the qc dir when there are less than 10" do
    make_image_files(2)
    subject.run!
    expect(Dir.new(File.join(qc_path, "test_shipment", barcode)).children.count).to eq(2)
  end

  it "deletes existing qc shipment folder if it's already there" do
    FileUtils.mkdir_p(File.join(qc_path, "test_shipment", "some_other_barcode"))
    make_image_files(2)
    subject.run!
    expect(Dir.new(File.join(qc_path, "test_shipment", barcode)).children.count).to eq(2)
    expect(Dir.new(qc_path)).not_to include("some_other_barcode")
  end

  it "copies a set of 10 images in a row when there are more than 10 images but less than 100" do
    make_image_files(20)
    subject.run!
    qc_files = Dir.new(File.join(qc_path, "test_shipment", barcode)).children
    expect(qc_files.count).to eq(10)
    file_numbers = qc_files.map do |x|
      File.basename(x, ".tif").to_i
    end.sort

    file_numbers.each_with_index do |num, index|
      if index + 1 < file_numbers.count
        expect(num + 1).to eq(file_numbers[index + 1])
      end
    end
  end
  it "copies a 10% of images when there are more than 100" do
    make_image_files(111)
    subject.run!
    qc_files = Dir.new(File.join(qc_path, "test_shipment", barcode)).children
    expect(qc_files.count).to eq(11)
  end
end
