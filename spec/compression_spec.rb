describe Compression do
  before(:each) do
    @config = Config.new({no_progress: true})
  end
  after(:each) do
    TestShipment.remove_test_shipments
  end
  context "#run" do
    it "removes alpha when it exists" do
    end
  end
end
