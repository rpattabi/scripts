require 'find'
require 'fileutils'
require 'mini_exiftool'

require './zero-files.rb'

def images(dir)
  files(dir).select { |f| 
    /^image/ =~ `file -b --mime-type "#{f}"`
  }
end

def import(images, to_dir)
  images.each { |img|
    exif = MiniExiftool.new img

    date = exif.DateTimeOriginal
    date = exif.DateTimeDigitized if date.nil?
    date = exif.DateTime if date.nil?

    unless date.nil?
      date_dir = date_dir(to_dir, date)
      FileUtils.mkpath date_dir
      puts "#{img} will be moved to #{date_dir}/#{File.basename(img)}"
      FileUtils.mv img, "#{date_dir}/#{File.basename(img)}"
    else
      puts "No exif date for #{img}"
    end
  }
end

def date_dir(root_dir, date)
    "#{root_dir.chomp('/')}/#{date.year}/#{'%02d' % date.month}/#{'%02d' % date.day}"
end

unless ARGV[0].nil? || ARGV[1].nil?
  import images(ARGV[0]), ARGV[1]
end

