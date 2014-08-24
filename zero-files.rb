require 'find'

def files(dir)
  files = []
  Find.find(dir) do |f|
    files << f if File.file?(f) && File.zero?(f)
  end

  files
end

puts files(ARGV[0])
