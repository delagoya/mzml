require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe MzML do
  before(:all) do 
    # set the input file name
    @file = "small.mzML"
    @compressed = "small.compressed.mzML"
  end
  
  
  context "Given an valid mzML file" do 
    it "I should be able to open the mzML file"
    it "should read the index"
    it "should get scan=506"
    it "should unmarshall the first 64 byte mz array"  
    it "should unmarshall the first 32 byte intensity array"
    it "should unmarshall and uncompress the 64 byte mz array"  
    it "should unmarshall and uncompress the 32 byte intensity array"
  end
end
