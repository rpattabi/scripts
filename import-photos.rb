require 'find'
require 'fileutils'
require 'mini_exiftool'

require './zero-files.rb'

# /image/ =~ p.mimetype

def images(dir)
  files(dir).select { |f| 
    /image/ =~ `file #{f}`
  }
end
