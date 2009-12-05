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
  BYTEORDER = {"little" =>"e*", "network"=>"g*", "big"=>"g*"}
  module RGX
    # parses out the file offset of the indexList element
    INDEX_OFFSET = /<indexListOffset>(\d+)<\/indexListOffset>/
    # 
    SPCT_LIST_START =  /<spetrumList.+count\=["'](\d+)/ 
    CHRM_LIST_START =  /<chromatogramList.+count\=["'](\d+)/ 
    SPCT_START = /<spectrum\s/
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
    attr_reader :index, :fname
    def initialize(mz_fname)
      unless mz_fname =~ /\.mzML$/
        raise UnsupportedFile "File extension must be .\"mzML\""
      end
      super(mz_fname, "r")
      @fname = mz_fname
      @index = self.parse_index_list
    end
    
    def scan(scan_id)
    end
    # searches the index for the given parameter
    # must be part of the native ID
    
    def search(str)

    end

    private
    # Parses the IndexList 
    def parse_index_list
      self.seek(self.stat.size - 200)
      # parse the index offset
      tmp = self.read
      tmp  =~  MzML::RGX::INDEX_OFFSET
      # if I didn't match anything, compute the index and return 
      unless ($1) 
        return compute_index_list
      end
      self.seek($1.to_i)
    end

    def compute_index_list
      @index_list = MzML::Index.new()
      # start at the beginning.
      self.rewind
      # sax parsing approach? or regex?
      past_pos = self.pos
      while self.eof
        
      end
    end
    
  end

  class Index
    attr_accessor :spectrum, :chromatogram
    def initialize()
      @spectrum = {}
      @chromatogram = {}
    end
  end
  
  class Scan
    include MzXml
    
    def initialize(elem)
      @e = elem
      @mz = nil
      @mzi = nil
      parse_peaks()
    end
    attr_reader :e

    protected
    def parse_peaks
      @mz = []
      @mzi = []
      return if @e[:peaksCount] == 0
      if (!@isMzData) then 
        pkelm = @e.at('peaks')
        sym = Rampy::BYTEORDER[pkelm[:byteOrder]]
        sym.upcase! if (pkelm[:precision].to_i > 32)
        data = Base64.decode64(pkelm.inner_text())
        if (pkelm[:compressionType] == 'zlib')
          data = Zlib::Inflate.inflate(data)
        end
        tmp = data.unpack("#{sym}")
        tmp.each_index do |idx|
          if (idx % 2 == 0 ) then 
            @mz.push(tmp[idx])
          else
            @mzi.push(tmp[idx])
          end
        end
      else
        # first, get mz array data
        tmp = scan.search('mzArrayBinary/data')
        sym = Rampy::BYTEORDER[tmp.attr('endian')]
        sym.upcase! if (tmp.attr('precision').to_i > 32)
        @mz = Base64.decode64(tmp.text()).unpack(sym)
        #now for the intensity array
        tmp = scan.search('intenArrayBinary/data')
        sym = Rampy::BYTEORDER[tmp.attr('endian')]
        sym.upcase! if (tmp.attr('precision').to_i > 32)
        @mzi = Base64.decode64(tmp.text()).unpack(sym)
      end
      return 1
    end

    def method_missing m
      @e[m.to_sym]
    end
    
    public 
    # return the retention time in seconds
    def retention_time_sec
      @e[:retentionTime] =~ /^PT(\d+\.\d+)S$/
      $1.to_f
    end
    
    # Return m/z array. If an index is given, it will return that particular m/z
    def mz(x=nil)
      x ? @mz[x] : @mz
    end

    # Return intensity array. If an index is given, it will return that particular intensity
    def mzi(x=nil)
      x ? @mzi[x] : @mzi
    end
    
    def attributes
      @e.attributes
    end
  end
  
  class MzFile
    include MzXml
    
    def initialize (mzXmlFile )
      @file = File.open(mzXmlFile, "r")
      @file.readline
      if (@file.readline =~  /mzData/) then
        @isMzData = true
      else 
        @isMzData = false
      end
      @offset = parse_index_offset
      @index = parse_index
      @header = parse_header
      @basepeak = nil
      @file.pos = 0
    end
    # Boolean determining whether the opened file is an mzData file, rather than mzXML
    attr :isMzData
    # The scan index read (or computed) from the mzXML/mzData file. A Hash of {scanNum => file_position}
    #-- 
    # should work on both file types
    attr :index
    # The mzXML/mzData header annotations (should have some useful information in it ;-) ) as REXML::Element
    attr :header
    # The base peak chromatograph (*WARNING* Calculated the first time it is accessed, which may take a bit of time)
    attr :basePeak

    private
    # Parses the indexOffset from mzXML files 
    def parse_index_offset
      return -1 if @isMzData
      r = %r{\<indexOffset\>(\d+)\<\/indexOffset\>}
      seekoffset = -120
      while true 
        self.seek(seekoffset, IO::SEEK_END)
        if (r.match(self.read)) then 
          return  $1.to_i
        end
        seekoffset -= 10
        return -1 if seekoffset <= -1000
      end
    end

    # Return a hash of scans, where {scan number} = file offset
    def parse_index
      if (@offset < 0) then 
        return compute_index
      end
      r= %r{\<offset\s+id=\"(\d+)\"\>(\d+)\<\/offset\>}
      @file.pos = @offset
      index = {}
      while (!@file.eof?) 
        next unless (r.match(@file.readline))
        index[$1.to_i] = $2.to_i
      end
      ## now check the index, otherwise recompute it!!!
      # beginning
      return compute_index if index.empty?
      r =/\<scan|\<spectrum\sid/
      tmpkeys = index.keys.sort
      @file.pos = index[tmpkeys.first]
      if (!(@file.readline =~ r ))
        index = compute_index
      else
        #middle 
        @file.pos = index[tmpkeys[tmpkeys.length/2]]
        if (!(@file.readline =~ r))
          index = compute_index
        else
          #end
          @file.pos = index[tmpkeys.last]
          if (!(@file.readline =~ r))
            index = compute_index
          end
        end
      end
      #reset the file to the first scan position
      @file.pos = index[tmpkeys.first]
      #return the index
      index
    end

    # Parses the file header information
    def parse_header
      @file.pos = 0
      r = %r{\<scan\s|\<spectrum\s}
      xml = "" 
      while true
        l = @file.readline
        break if l =~ r
        xml << l 
      end
      if (@isMzData) then 
        xml << "</spectrumList></mzData>"
      else 
        xml << "</msRun></mzXML>"
      end
      xml.empty? ? nil : parse(xml)
    end

    # Computes the index by scanning the entire file
    def compute_index 
      @file.rewind
      r = %r{\<scan\snum\=\"(\d+)\"|\<spectrum\sid\=\"(\d+)\"}
      index  = {}
      while (!@file.eof) 
        p = @file.pos
        if (r.match(@file.readline)) then 
          m = $1 ? $1 : $2
          index[m.to_i] = p
        end
      end
      index
    end
    # parses a bit of XML into a REXML::Element node
    protected

    def parse_base_peak #:nodoc: all
      @file.pos = 0
      @basepeak = [[],[]]
      if (@isMzData) 
        # MUCH more expensive to compute
        while (s = next_scan)
          p = get_peaks(s)
          max_int = -1.0
          bp_idx = 0
          p[1].each_index do |i|
            bp_idx = i if p[1][i] > max_int
          end
          @basepeak[0].push(p[0][bp_idx]) 
          @basepeak[0].push(p[1][bp_idx]) 
        end
      else
        numr= %r{\<scan num\=[\"|\'](\d+)[\"|\']}
        bpr= %r{basePeak(\w+)\=[\"|\'](\S+)[\"|\']}
        num = 0
        while(!@file.eof?)
          l = @file.readline
          if (m = numr.match(l))
            num = m[1].to_i
            next
          end
          if (m = bpr.match(l))
            if m[1] == "Mz"
              @basepeak[0].push(num) 
            else
              @basepeak[1].push(m[2].to_f)  
            end
          end
        end
      end
      @basepeak
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

    public 
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

    def basePeak #:nodoc: all
      return @basepeak if @basepeak
      parse_base_peak
    end
  end
end