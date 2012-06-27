require 'test/unit'
require 'mzml'

class TestMzMLHelper < Test::Unit::TestCase
  def setup
    # set the input file name
    @file = File.join(File.dirname(__FILE__),  "sample.mzML")
    @compressed = File.join(File.dirname(__FILE__),  "sample.compressed.mzML")
    @mgf = File.join(File.dirname(__FILE__),  "sample.mgf")
  end

  def test_canary
    pass
  end
end