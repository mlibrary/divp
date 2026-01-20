describe ChecksumFileGenerator do
  context ".write" do
    it "returns true" do
      expect(described_class.write).to eq(true)
    end
  end
end

describe GenerateChecksums do
  it "does something" do
    shipment = instance_double(Shipment, is_a?: true, objids: [])
    described_class.new(shipment)
  end
end
