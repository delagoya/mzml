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
  unless  s.precursor_list.nil? || s.precursor_list.empty?
  
 
    #now we print!

    puts "BEGIN IONS"
    puts "TITLE=#{s.id}"
    puts "RTINSECONDS=#{s.retention_time}"
    puts "PEPMASS=#{s.precursor_mass} #{s.precursor_intensity}"

    0.upto(s.mz.length-1) do |i|

      puts "#{sprintf('%5.7f', s.mz[i])} #{sprintf('%4.9f', s.intensity[i])}"

    end


    puts "END IONS"

    
  end
  

  
end



