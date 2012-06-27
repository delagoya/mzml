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


  class UnsupportedFileFormat < Exception
  end
  class BadIdentifier < Exception
  end

  # def parse(xml)
  #   Nokogiri::XML.parse(xml).root
  # end

  # The main mzML parser class, it is a subclass of the File class from the
  # Ruby standard library in that it places a read cursor on the mzML file,
  # and will skip around using byte-offsets. We utilize the index at the
  # end of mzML files to facilitate random access of spectra.
  #
  # The {#each} method will cycle through all of the spectrum in a file, starting
  # from the first one each time. If you would rather access the spectra randomly,
  # the {#spectrum_list} attribute contains the ordered list of specturm identifiers.
  # You can access the MzML::Spectrum objects by feeding these identifiers to the {#spectrum}
  # method.
  class Doc < ::File

    # Open a file handle to a mzML document
    def initialize(mz_fname)
      unless mz_fname =~ /\.mzML$/
        raise MzML::UnsupportedFileFormat.new  "File extension must be .\"mzML\""
      end
      super(mz_fname, "r")
      @fname = mz_fname
      @index = parse_index_list
      @spectrum_count = @spectrum_list.length
      @chromatogram_count = @chromatogram_list.length
      @current_spectrum_index = 0
    end
    attr_reader :index, :fname, :spectrum_list, :spectrum_count, :chromatogram_list, :chromatogram_count

    # Fetch a {MzML::Chromatogram} from the file, given the identifier
    # @param chromatogram_id String
    # @return {MzML::Chromatogram}
    def chromatogram(chromatogram_id)
      if @index[:chromatogram].has_key? chromatogram_id
        self.seek @index[:chromatogram][chromatogram_id]
        return MzML::Chromatogram.new(parse_next)
      else
        raise MzML::BadIdentifier.new("Invalid ID '#{chromatogram_id}'")
      end
    end

    def spectrum(spectrum_id)
      if @index[:spectrum].has_key? spectrum_id
        self.seek @index[:spectrum][spectrum_id]
        return MzML::Spectrum.new(parse_next())
      else
        raise MzML::BadIdentifier.new("Invalid ID '#{spectrum_id}'")
      end
    end

    def each &block
      @spectrum_list.each do |spectrum_id|
        block.call(self.spectrum(spectrum_id))
        @current_spectrum_index += 1
      end
    end
    alias_method :each_spectrum, :each

    def next &block
      if @current_spectrum_index < @spectrum_list.length
        @current_spectrum_index += 1
        self.spectrum(@spectrum_list[@current_spectrum_index - 1])
      else
        nil
      end
    end
    alias_method :next_spectrum, :next

    def rewind
      super
      @current_spectrum_index = 0
    end

    private
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
      @spectrum_list = []
      @chromatogram_list = []
      self.seek(offset.to_i)
      tmp = Nokogiri::XML.parse(self.read).root
      tmp.css("index").each do |idx|
        index_type = idx[:name].to_sym
        @index[index_type] = {}
        idx.css("offset").each do |o|
          @index[index_type][o[:idRef]] = o.text().to_i
          if index_type == :spectrum
            @spectrum_list << o[:idRef]
          else
            @chromatogram_list << o[:idRef]
          end
        end
      end
      self.rewind
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
      buffer = ''
      while(!self.eof)
        if end_pos = buffer =~ MzML::RGX::DATA_END
          extra_content = buffer.slice!((end_pos + $1.length)..-1)
          self.pos -= (extra_content.length)
          break
        end
        buffer += self.read(1024)
      end
      return Nokogiri::XML.parse(buffer).root
    end
  end
end
