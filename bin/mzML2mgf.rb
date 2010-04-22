#!/opt/local/bin/ruby

################################
####
##
#     David Austin - UPENN
#     converts mzML to MGF format
#     set up to replicate msconvert but muuchh slower
#

require 'rubygems'
require 'mzml'


#first load nokogiri document

mzml =  MzML::Doc.new(ARGV[0])

#now loop through each spectrum.. sort first to be the same as msconvert

sorted_keys = mzml.parse_index_list[:spectrum].keys.sort{ |x,y| x.split('=')[3].to_i <=> y.split('=')[3].to_i }

sorted_keys.each do |k|
  
  s = mzml.spectrum(k)

  unless s.node.xpath("spectrum/precursorList/precursor")[0].nil?
    
    #need to get info that gem is not producing..

    id = s.node.xpath("spectrum")[0][:id]

    rtime = s.node.xpath("spectrum/scanList/scan/cvParam[@accession='MS:1000016']")[0][:value]
    
    p_intensity = s.node.xpath("spectrum/precursorList/precursor/selectedIonList/selectedIon/cvParam[@accession='MS:1000042']")[0][:value]
    
    p_mass = s.node.xpath("spectrum/precursorList/precursor/selectedIonList/selectedIon/cvParam[@accession='MS:1000744']")[0][:value]
  
    #now we print!

    puts "BEGIN IONS"
    puts "TITLE=#{id}"
    puts "RTINSECONDS=#{rtime.to_s[0..10]}"
    puts "PEPMASS=#{p_mass.to_s[0..10]} #{p_intensity.to_s[0..10]}"

    0.upto(s.mz.length-1) do |i|

      puts "#{s.mz[i].to_s[0..10]} #{s.intensity[i].to_s[0..10]}"

    end


    puts "END IONS"

    
  end
  

  
end



