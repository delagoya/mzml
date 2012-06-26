require 'base64'
require 'zlib'

module MzML
  class Chromatogram
    # Canonical ID of the chromatogram
    attr_reader :id

    attr_reader :default_array_length

    # The positional index of the chromatogram in the mzML document
    attr_reader :index_position
    alias_method :index

    attr_reader :default_processing_ref

    # Timepoints intensity values
    attr_reader :time
    # The unit of time that the timepoints are measured in (e.g. seconds, minutes, ...)
    attr_reader :time_unit

    # Intensity array of values
    attr_reader :intensities

    # Nokogiri::XML::Node of the document
    attr_reader :node

    # CV param attributes
    attr_reader :params

    # mz & intensity arrays will be don by proper methods maybe.
    def initialize(node)
      @node = node
      @params = {}
      parse_element()
    end

    protected
    # This method pulls out all of the annotation from the XML node
    def parse_element
      @id = @node[:id]
      @default_array_length = @node[:defaultArrayLength]
      @index = @node[:index]
      # CV parameters
      @params = @node.xpath("./cvParam").inject([]) do  |memo,prm|
        memo << {name: prm[:name],
          value:  prm[:value],
          accession: prm[:accession],
          cv: prm[:cvRef]}
        memo
      end
      # binary data
      parse_binary_data()
    end

    def parse_binary_data
      @node.xpath("./binaryDataArrayList/binaryDataArray").each do |bd|
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
        # time or intensity data?
        if bd.xpath("cvParam/@accession='MS:1000595'")
          # parse the time units
          @time_unit = bd.xpath("cvParam[@accession='MS:1000595']")[0].attributes["unitName"].value
          @timepoints = data.unpack(decode_type)
        else
          @intensities = data.unpack(dtype)
        end
      end
    end
  end
end