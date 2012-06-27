require 'test/unit'
require 'mzml'

class TestMzML < Test::Unit::TestCase

  def setup
    # set the input file name
    @file = File.join(File.dirname(__FILE__), "fixtures", "sample.mzML")
    @compressed = File.join(File.dirname(__FILE__), "fixtures", "sample.compressed.mzML")
    @mgf = File.join(File.dirname(__FILE__), "fixtures", "sample.mgf")
    @mzml = MzML::Doc.open(@file)
  end

  def test_canary
    pass
  end

  def test_mzml_file_open
    assert_instance_of(MzML::Doc, @mzml)
  end

  def test_index_created
    assert_not_nil(@mzml.index)
    assert(@mzml.index.keys.length > 0, "Index not parsed correctly, zero index keys")
  end

  def test_spectrum_fetch
    spectrum = @mzml.spectrum(@mzml.spectrum_list.first)
    assert_instance_of(MzML::Spectrum, spectrum)
    assert(spectrum.id == "controllerType=0 controllerNumber=1 scan=1")
  end

  def test_chromatogram_fetch
    # STDERR.puts @mzml.chromatogram_list.first
    chromatogram = @mzml.chromatogram(@mzml.chromatogram_list.first)
    assert_instance_of(MzML::Chromatogram, chromatogram)
    assert(chromatogram.id == "TIC")
  end

  # test the spectrum object.
  # attr_reader :id, :default_array_length, :type,
  #   :charge, :precursor, :base_peak_mz, :base_peak_intensity, :ms_level,
  #   :high_mz, :low_mz, :title, :tic, :polarity, :representation, :mz_node, :intensity_node,
  #   :mz, :intensity, :precursor_list, :scan_list, :retention_time, :precursor_mass,
  #   :precursor_intensity, :node, :params

  def test_spectrum_object
    spectrum = @mzml.spectrum(@mzml.spectrum_list[2])
    assert_instance_of(MzML::Spectrum, spectrum)
    assert_equal("controllerType=0 controllerNumber=1 scan=3",spectrum.id)
    assert_equal(2, spectrum.ms_level)
    assert_equal(231.38883972167969, spectrum.low_mz)
    assert_equal(1560.7198486328125, spectrum.high_mz)
    assert_equal(586279, spectrum.tic)
    assert_equal(161140.859375, spectrum.base_peak_intensity)
    assert_equal(736.6370849609375, spectrum.base_peak_mz)
  end

  def test_spectrum_decode
    spectrum = @mzml.spectrum(@mzml.spectrum_list[2])
    assert_instance_of(MzML::Spectrum, spectrum)
    assert_equal(spectrum.mz[3], 240.3084716796875)
  end

  def test_compressed_spectrum_decode
    mzml = MzML::Doc.open(@compressed)
    spectrum = mzml.spectrum(@mzml.spectrum_list[2])
    assert_instance_of(MzML::Spectrum, spectrum)
    assert_equal(spectrum.mz[3], 240.3084716796875)
  end

  # test the chromatogram object.
  def test_chromatogram_object

  end

  def test_chromatogram_decode

  end

  def test_compressed_chromatogram_decode

  end
end