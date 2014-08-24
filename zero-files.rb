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
      files << f unless File.zero?(f)
    end
  end

  files
end

#puts files(ARGV[0]) unless ARGV[0].nil?
