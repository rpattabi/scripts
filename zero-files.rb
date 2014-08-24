require 'find'

def files(dir)
  files = []
  Find.find(dir) do |f|
    files << f unless File.directory?(f) || File.zero?(f)
  end

  files
end

puts files(ARGV[0]) unless ARGV[0].nil?
