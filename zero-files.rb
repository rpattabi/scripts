require 'find'

def files(dir)
  files = []
  Find.find(dir) do |f|
    files << f unless FileTest.directory?(f) || File.size(f) > 0
  end

  files
end

puts files(ARGV[0])
