require 'find'

def files(dir)
  files = []

  Find.find(dir) do |f|
    if File.directory?(f)
      # let us skip dot directories (hidden)
      if File.basename(f).start_with? '.'
        # prune optimizes find 
        #   by not looking at any files or subfolders of the current directory 
        #   (in our case, hidden directory)
        Find.prune
      else
        next
      end
    else
      unless File.zero?(f) || !File.readable?(f) || File.socket?(f)
        yield f if block_given?
        files << f
      end
    end
  end
  files
end

unless ARGV[0].nil?
  puts
  puts "----- valid files:start -----"

  puts files(ARGV[0])

  puts "----- valid files:end -----"
  puts
end

def timestamp
  now = Time.now
  "#{now.year}-#{'%02d' % now.month}-#{'%02d' % now.day}-#{'%02d' % now.hour}-#{'%02d' % now.min}-#{'%02d' % now.sec}"
end
