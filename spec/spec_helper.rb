$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'mzml'
require 'spec'
require 'spec/autorun'

class Mgf < Struct.new(:title, :mz, :intensity); end

def parse_mgf(fname)
  mgf = Mgf.new(nil,[],[])
  File.open(fname).each do |l|
    l.chomp!
    case l
    when /^TITLE=(.+)/
      mgf.title = $1
    when /^\d/
      m,i = l.split().map{|e| (e.to_f * 1000).to_i() / 1000.0 }
      mgf.mz << m
      mgf.intensity << i
    end
  end
  return mgf
end

Spec::Runner.configure do |config|
end
