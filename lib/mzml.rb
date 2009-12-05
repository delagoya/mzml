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
# A non-validating mzML parser.
#
# ===USAGE:
#
#     require 'mzxml'
#     mzml =  MzML::Doc.new("test.mzXML")
#     index = mzxml.index # Returns a hash of scan numbers and the file byte position
#     # get the first scan number
#     firstScanNumber = index.keys.sort.first
#     # could also just ask for next_scan like "mzxml.next_scan"
#     # now got get it!
#     scan = mzxml.scan(firstScanNumber)
#
#     # "scan" is now MzXml::Scan object with mz, intensity arrays retrieved lazily from either Scan#mz and Scan#i
#     # get the whole mz array
#     mz = scan.mz
#     # get just the 23rd mz value
#     mz_23 = scan.mz(23)

module MzML

  module RGX
    # parses out the file offset of the indexList element
    INDEX_OFFSET = /<indexListOffset>(\d+)<\/indexListOffset>/
    #
    SPCT_LIST_START =  /<spectrumList.+count\=["'](\d+)/
    CHRM_LIST_START =  /<chromatogramList.+count\=["'](\d+)/
    SPCT_START = /<spectrum/
    SPCT_END = /<\/spectrum>/
    CHRM_START = /<chromatogram\s/
    CHRM_END = /<\/chromatogram>/
  end

  def parse(xml)
    Nokogiri::XML.parse(xml).root
  end

  class UnsupportedFile < Error
  end
  class Doc < File
    attr_reader :index, :fname, :spectrum_count, :chromatogram_count

    def initialize(mz_fname)
      unless mz_fname =~ /\.mzML$/
        raise UnsupportedFile "File extension must be .\"mzML\""
      end
      super(mz_fname, "r")
      @index = parse_index_list
    end

    def chromatrogram(chromatogram_id)
      @index[:chromatogram][chromatogram_id]
    end

    def spectrum(spectrum_id)
      @index[:spectrum][spectrum_id]
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
      tmp.css("index").each do |i|
        n = i[:name].to_sym
        i.css("offset").each do |o|
          prev = nil
          @index[n][o[:idRef]] = [o.text().to_i,
            (@index[n][prev] || offset) ]
          prev = o[:idRef]
        end
      end
      return @index
    end

    def compute_index_list
      @index = {}
      # start at the beginning.
      self.rewind
      # fast forward to the first spectrum or chromatograph
      rgx_start = /<spectrumList|<chromatogramList/
      buffer = ''
      while !self.eof
        buffer += self.read(1024)
        if start_pos = buffer =~ rgx_start
          self.seek start_pos + 10
          buffer = self.read(200)
          start_pos = buffer =~ /<spectrum|<chromatogram/
          self.seek(self.pos - 200 + start_pos)
          break
        end
      end
      # for each particular entity start to fill in the index
      buffer = ''
      rgx_start = /<(spectrum|chromatogram)\s.*id=["']([^"']+)["']/m
      while !self.eof
        buffer = self.read(1024)
        if start_pos = buffer =~ rgx_start
          curr_pos = self.pos - buffer.length + start_pos
          @index[$1.to_sym][$2] = [curr_pos, prev_pos]
          prev_pos = curr_pos
        end
        # need to be careful here. debug it.
        self.seek(self.pos - 100) unless self.eof
      end
      return @index
    end
  end

  class Spectrum
    include MzXml
    attr_accessor :id, :default_array_length, :spot_id, :type,\
    :charge, :precursor, :base_peak_mz, :base_peak_intensity, :ms_level, \
    :high_mz, :low_mz, :title, :tic, :polarity, :representation, :mz_node, :intensity_node \
    :mz, :intensity, :precursor_list, :scan_list, :retention_time
    attr_reader :node, :params

    # mz & intensity arrays will be don by proper methods maybe.
    def initialize(spectrum_xml_str)
      @node = parse(spectrum_xml_str)
      @params = {}
      parse_element()
      parse_peaks()
    end


    protected
    # This method pulls out all of the annotation from the XML node
    def parse_element
      # id
      @id = @node[:id]
      @default_array_length = @node[:defaultArrayLength]
      @spot_id = @node[:spotID]
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
      # polarity
      # representation
      # precursor list
      if (@node.xpath("precursorList")[0])
        parse_precursor_list()
      else
        @precursor_list = nil
      end
      # scan list
      if (@node.xpath("scanList")[0])
        @scan_list = parse_scan_list()
      else
        @scan_list = nil
      end
      # binary data
      parse_binary_data()
    end

    def parse_precursor_list
      @precursor_list = @node.css("precursorList > precursor").each do |p|
        [p[:spectrumRef], p]
      end
    end

    def parse_scan_list
      @scan_list = @node.xpath("scanList/scan")
      @retention_time = @node.xpath("scanList/scan/cvParam[@accesion='MS:1000016']")[0]
    end

    def parse_binary_data
      @mz_node = @node.xpath("binaryDataArrayList/binaryDataArray/cvParam[@accession='MS:1000514']").first.parent
      data = Base64.decode64(@mz_node.xpath("binary").text)
      if @mz_node.xpath("cvParam[@accession='MS:1000574']")[0]
        # need to uncompress the data
        data = Zlib::Inflate.inflate(data)
      end
      # 64-bit floats? default is 32-bit
      dtype = @mz_node.xpath("cvParam[@accession='MS:1000523']")[0] ? "E*" : "e*"
      @mz = data.unpack(dtype)
      @intensity_node = @node.xpath("binaryDataArrayList/binaryDataArray/cvParam[@accession='MS:1000515']").first.parent
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


    def get_scan_from_curr_pos #:nodoc:
      return nil if (@file.eof)
      xml = ""
      while (!@file.eof )
        l = @file.readline
        if (l =~ /\<\/scan\>|\<\/spectrum\>/) then
          xml.concat(l)
          break
        end
        xml.concat(l)
      end
      xml.empty? ? nil :  parse(xml)
    end

    # Return a Scan for a given scan number
    #
    # @param [Fixnum] the scan number to grab
    def scan scanNum
      @file.pos = @index[scanNum]
      Scan.new(get_scan_from_curr_pos)
    end
    # Return a Scan node for the next scan sequentially encountered with respect to the file.
    # This may not correspond to any notion of scan ordering by ms_level, retention time, etc., it is
    # simply related to file read position.
    #
    # This method pays no attention to the last scan called in your routines. If you made any other API
    # calls that change the file read position (most methods do), the result will be unexpected. Use at your own risk  :-P

    def next_scan
      lastPos = @file.pos
      while (!@file.eof )
        l = @file.readline
        break if l =~ /\<scan|\<spectrum\s/
        lastPos = @file.pos
      end
      @file.pos = lastPos
      Scan.new(get_scan_from_curr_pos)
    end
  end
end