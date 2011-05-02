require 'nokogiri'
require 'base64'
require 'zlib'

#--
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Library or "Lesser" General Public
# License (LGPL) as published by the Free Software Foundation;
# either version 2 of the License, or (at your option) any later
# version.
# Author: Angel Pizarro
# Date: 12/05/2009
# Copyright: Angel Pizarro, Copyright (c) University of Pennsylvania.  All rights reserved.
#

# == MzML
#
# A non-validating mzML v 1.1.0 parser. Most annotation is left as XML DOM
# objects. See the Nokogiri::XML::Node and Nokogiri::XML::NodeSet
# documentation on how to work with these.
#
# ===USAGE:
#
#     require 'mzml'
#     mzml =  MzML::Doc.new("test.mzXML")

module MzML

  # An internal module containing useful regular expressions
  module RGX
    # The file byte offset of the start of the file index
    INDEX_OFFSET = /<indexListOffset>(\d+)<\/indexListOffset>/
    # The start of a either a spectrumList or chromatographList
    DATA_LIST_START =  /<(spectrum|chromatogram)List\s.*count\=["'](\d+)/m
    # The start spectrum or chromatogram element
    DATA_START = /<(spectrum|chromatogram)\s.*id=["']([^'"]+)["']/m
    # The end spectrum or chromatogram element
    DATA_END = /(<\/(spectrum|chromatogram)>)/
  end

  def parse(xml)
    Nokogiri::XML.parse(xml).root
  end

  class UnsupportedFileFormat < Exception
  end
  class BadIdentifier < Exception
  end

  class Doc < File
    attr_reader :index, :fname, :spectrum_count, :chromatogram_count, :node

    def initialize(mz_fname)
      unless mz_fname =~ /\.mzML$/
        raise MzML::UnsupportedFileFormat.new  "File extension must be .\"mzML\""
      end
      super(mz_fname, "r")
      @index = parse_index_list
    end

    def chromatogram(chromatogram_id)
      if @index[:chromatogram].has_key? chromatogram_id
        self.seek @index[:chromatogram][chromatogram_id]
        parse_next
      else
        raise MzML::BadIdentifier.new("Invalid ID '#{chromatogram_id}'")
      end
    end

    def spectrum(spectrum_id)
      if @index[:spectrum].has_key? spectrum_id
        self.seek @index[:spectrum][spectrum_id]
        return Spectrum.new(parse_next())

      else
        raise MzML::BadIdentifier.new("Invalid ID '#{spectrum_id}'")
      end
    end

    # private
    # Parses the IndexList
    def parse_index_list
      self.seek(self.stat.size - 200)
      # parse the index offset
      tmp = self.read
      tmp  =~  MzML::RGX::INDEX_OFFSET
      offset = $1
      # if I didn't match anything, compute the index and return
      unless (offset)
        return compute_index_list
      end
      @index = {}
      self.seek(offset.to_i)
      tmp = Nokogiri::XML.parse(self.read).root
      tmp.css("index").each do |idx|
        index_type = idx[:name].to_sym
        @index[index_type] = {}
        idx.css("offset").each do |o|
          @index[index_type][o[:idRef]] = o.text().to_i
        end
      end
      return @index
    end

    def compute_index_list
      @index = Hash.new {|h,k| h[k] = {} }
      # start at the beginning.
      self.rewind
      # fast forward to the first spectrum or chromatograph
      buffer = ''
      while !self.eof
        buffer += self.read(1024)
        if start_pos = buffer =~ MzML::RGX::DATA_START
          self.seek start_pos
          break
        end
      end
      # for each particular entity start to fill in the index
      buffer = ''
      rgx_start = /<(spectrum|chromatogram)\s.*id=["']([^"']+)["']/
      while !self.eof
        buffer += self.read(1024)
        if start_pos = buffer =~ rgx_start
          start_pos = self.pos - buffer.length + start_pos
          @index[$1.to_sym][$2] = start_pos
          buffer = ''
        end
      end
      return @index
    end

    def parse_next
      buffer = self.read(1024)
      end_pos = nil
      while(!self.eof)
        if end_pos = buffer =~ MzML::RGX::DATA_END
          buffer = buffer.slice(0..(end_pos + $1.length))
          break
        end
        buffer += self.read(1024)
      end
      return Nokogiri::XML.parse(buffer)
    end
  end

  class Spectrum
    attr_accessor :id, :default_array_length, :spot_id, :type,\
    :charge, :precursor, :base_peak_mz, :base_peak_intensity, :ms_level, \
    :high_mz, :low_mz, :title, :tic, :polarity, :representation, :mz_node, :intensity_node, \
    :mz, :intensity, :precursor_list, :scan_list, :retention_time, :precursor_mass, :precursor_intensity
    
    attr_reader :node, :params

    # mz & intensity arrays will be don by proper methods maybe.
    def initialize(spectrum_node)
      @node = spectrum_node
      @params = {}
      @precursor_list = []
      parse_element()
    end

    protected
    # This method pulls out all of the annotation from the XML node
    def parse_element
      # id
      @id = @node.xpath("spectrum")[0][:id]
      @default_array_length = @node.xpath("spectrum")[0][:defaultArrayLength]
      @spot_id = @node.xpath("spectrum")[0][:spotID]
      # now reaching into params
      @params = @node.xpath("spectrum/cvParam").inject({}) do  |memo,prm|
        memo[prm[:name]] = prm[:value]
        memo
      end
      @ms_level = @params["ms level"].to_i
      @low_mz = @params["lowest observed m/z"].to_f if @params.has_key?("lowest observed m/z")
      @high_mz = @params["highest observed m/z"].to_f if @params.has_key?("highest observed m/z")
      @tic = @params["total ion current"].to_i if @params.has_key?("total ion current")
      @base_peak_mz = @params["base peak m/z"].to_i if @params.has_key?("base peak m/z")
      @base_peak_intensity = @params["base peak intensity"].to_i if @params.has_key?("base peak intensity")
      # polarity
      # representation
      # precursor list
      if (! @node.xpath("spectrum/precursorList")[0].nil?)
        parse_precursor_list()
        get_parent_info()
      else
        @precursor_list = []
      end
      # scan list
      if (@node.xpath("spectrum/scanList")[0])
        @scan_list = parse_scan_list()
      else
        @scan_list = nil
      end
      # binary data
      parse_binary_data()
    end

    def parse_precursor_list
      @node.css("precursorList > precursor").each do |p|
        [p[:spectrumRef], p]
        @precursor_list << p
      end
    end

    def get_parent_info
      
      unless @precursor_list.empty?
        
        @precursor_mass = @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam[@accession='MS:1000744']")[0][:value] unless @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam[@accession='MS:1000744']")[0].nil?
        @precursor_intensity = @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam[@accession='MS:1000042']")[0][:value] unless @precursor_list[0].xpath("selectedIonList/selectedIon/cvParam[@accession='MS:1000042']")[0].nil?
        
      end
        
      
    end

    def parse_scan_list
      @scan_list = @node.xpath("spectrum/scanList/scan")
      @retention_time = @node.xpath("spectrum/scanList/scan/cvParam[@accession='MS:1000016']")[0][:value] unless @node.xpath("spectrum/scanList/scan/cvParam[@accession='MS:1000016']")[0].nil?
    end

    def parse_binary_data
       cv_node = @node.xpath("spectrum/binaryDataArrayList/binaryDataArray/cvParam[@accession='MS:1000514']").first
       if cv_node
         @mz_node = cv_node.parent
         data = Base64.decode64(@mz_node.xpath("binary").text)
         if @mz_node.xpath("cvParam[@accession='MS:1000574']")[0]
           # need to uncompress the data
           data = Zlib::Inflate.inflate(data)
         end
         # 64-bit floats? default is 32-bit
         dtype = @mz_node.xpath("cvParam[@accession='MS:1000523']")[0] ? "E*" : "e*"
         @mz = data.unpack(dtype)
       end

       cv_node = @node.xpath("spectrum/binaryDataArrayList/binaryDataArray/cvParam[@accession='MS:1000515']").first
       if cv_node
         @intensity_node = cv_node.parent
         data = Base64.decode64(@intensity_node.xpath("binary").text)
         if @intensity_node.xpath("cvParam[@accession='MS:1000574']")[0]
           # need to uncompress the data
           data = Zlib::Inflate.inflate(data)
         end
         # 64-bit floats? default is 32-bit
         dtype = @intensity_node.xpath("cvParam[@accession='MS:1000523']")[0] ? "E*" : "e*"
         @intensity = data.unpack(dtype)
       end
    end
  end
end
