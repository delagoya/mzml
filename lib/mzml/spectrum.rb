require 'base64'
require 'zlib'

module MzML
  class Spectrum
    attr_reader :id, :default_array_length, :type,
    :charge, :precursor, :base_peak_mz, :base_peak_intensity, :ms_level,
    :high_mz, :low_mz, :title, :tic, :polarity, :representation, :mz_node, :intensity_node,
    :mz, :intensity, :precursor_list, :scan_list, :retention_time, :precursor_mass,
    :precursor_intensity, :node, :params

    # mz & intensity arrays will be don by proper methods maybe.
    def initialize(node)
      @node = node
      @params = {}
      @precursor_list = []
      parse_element()
    end

    protected
    # This method pulls out all of the annotation from the XML node
    def parse_element

      # id
      @id = @node.attributes["id"].value
      @index = @node.attributes["index"].value.to_i
      @default_array_length = @node.attributes["defaultArrayLength"].value.to_i

      # now reaching into params
      @params = @node.xpath("cvParam").inject({}) do  |memo,prm|
        memo[prm[:name]] = prm[:value]
        memo
      end

      @ms_level = @params["ms level"].to_i
      @low_mz = @params["lowest observed m/z"].to_f if @params.has_key?("lowest observed m/z")
      @high_mz = @params["highest observed m/z"].to_f if @params.has_key?("highest observed m/z")
      @tic = @params["total ion current"].to_i if @params.has_key?("total ion current")
      @base_peak_mz = @params["base peak m/z"].to_i if @params.has_key?("base peak m/z")
      @base_peak_intensity = @params["base peak intensity"].to_i if @params.has_key?("base peak intensity")

      # precursor list
      if @node.xpath("precursorList/precursor").length > 0
        parse_precursor_list()
        get_parent_info()
      else
        @precursor_list = []
      end

      # scan list
      if (@node.xpath("scanList/scan").length > 0)
        @scan_list = parse_scan_list()
      else
        @scan_list = nil
      end
      # binary data
      parse_binary_data()
    end

    def parse_precursor_list
      @precursor_list = []
      @node.xpath("precursorList/precursor").each do |p|
        @precursor_list << [p[:spectrumRef], p.xpath("precursorList")
      end
    end

    def get_parent_info
      unless @precursor_list.empty?
        if @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam/@accession='MS:1000744'")
          @precursor_mass = @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam[@accession='MS:1000744']")[0][:value].to_f
        end
        if @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam/@accession='MS:1000042'")
          @precursor_intensity = @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam[@accession='MS:1000042']")[0][:value].to_f
      end
    end

    def parse_scan_list
      @scan_list = @node.xpath("scanList/scan")
      if @node.xpath("scanList/scan/cvParam/@accession='MS:1000016'")
        @retention_time = @node.xpath("scanList/scan/cvParam[@accession='MS:1000016']")[0][:value]
      end
    end

    def parse_binary_data
      @node.xpath("binaryDataArrayList/binaryDataArray").each do |bd|
        if bd.xpath("cvParam/@accession='MS:1000523'")
          # "64-bit float"
          decode_type = "E*"
        else
          # 32-bit float
          decode_type = "e*"
        end
        data = Base64.decode64(bd.xpath("binary").text)
        # compressed?
        if bd.xpath("cvParam/@accession='MS:1000574'")
           data = Zlib::Inflate.inflate(data)
        end
        # m/z or intensity data?
        if bd.xpath("cvParam/@accession='MS:1000040'")
          # m/z data
          @mz = data.unpack(decode_type)
        else
          @intensity = data.unpack(decode_type)
        end
    end
  end
end