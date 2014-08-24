require 'fileutils'

list = ARGV[0]

File.readlines(list).each do |l|
  l = l.chomp

  if File.exists?(l)
    puts "Deleting.. #{l}: size=#{File.size(l)}"
    File.delete(l)
  end
end
