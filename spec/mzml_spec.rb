require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe MzML do
  before(:all) do
    # set the input file name
    @file = File.join(File.dirname(__FILE__),  "small.mzML")
    @compressed = File.join(File.dirname(__FILE__),  "small.compressed.mzML")
    @mgf = File.join(File.dirname(__FILE__),  "small.mgf")
  end

  context "Given a valid mzML file" do
    it "I should be able to open the mzML file" do
      file = MzML::Doc.new(@file)
      file.should(be_a_kind_of(MzML::Doc))
    end
    it "should read the index" do
      file = MzML::Doc.new(@file)
      file.index.should_not be_nil
    end
    it "should get the first spectrum" do
      file = MzML::Doc.new(@file)
      file.index.should_not be_nil
    end
    it "should unmarshall the a 64 byte mz array" do
      mz = MzML::Doc.new(@file)
      s = mz.spectrum(mz.index[:spectrum].keys.first)
      s.mz.should_not be_nil
    end
    it "should unmarshall the a 32 byte intensity array" do
      mz = MzML::Doc.new(@file)
      s = mz.spectrum(mz.index[:spectrum].keys.first)
      s.intensity.should_not be_nil
    end

    it "should be the same mz array as the MGF file" do
      mgf  = parse_mgf(@mgf)
      mz = MzML::Doc.new(@file)
      # grab this same spectrum from the mzML file
      s = mz.spectrum(mgf.title)
      i = s.intensity.map {|e| (e * 1000).to_i() / 1000.0}
      m = s.mz.map {|e| (e * 1000).to_i() / 1000.0}
      i.join(", ").should be == mgf.intensity.join(", ")
      m.join(", ").should be == mgf.mz.join(", ")
    end
  end

  context "Given a valid mzML file that uses compression" do
    it "should unmarshall and uncompress the 64 byte mz array" do
      mz = MzML::Doc.new(@compressed)
      s = mz.spectrum(mz.index[:spectrum].keys.first)
      s.mz.should_not be_nil
    end

    it "should unmarshall and uncompress the 32 byte intensity array" do
      mz = MzML::Doc.new(@compressed)
      s = mz.spectrum(mz.index[:spectrum].keys.first)
      s.intensity.should_not be_nil
    end
  end
end
