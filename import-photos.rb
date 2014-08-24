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

    if date.nil?
      yield img, nil, :skipping_noexifdate if block_given?
      next
    end

    date_dir = date_dir(to_dir, date)
    FileUtils.mkpath date_dir

    target = "#{date_dir}/#{File.basename(img)}"

    if File.exists?(target)
      yield img, target, :skipping_collision if block_given?
    else
      yield img, target, :moving if block_given?
      FileUtils.mv img, target
    end
  }
end

def date_dir(root_dir, date)
    "#{root_dir.chomp('/')}/#{date.year}/#{'%02d' % date.month}/#{'%02d' % date.day}"
end

unless ARGV[0].nil? || ARGV[1].nil?
  puts
  puts "-------- import:start --------"

  import(images(ARGV[0]), ARGV[1]) do |src, tgt, event|
    case event
      when :moving
        puts "Moving.. from: #{src} --> #{tgt}"
      when :skipping_collision
        puts "Skipping.. name collision: #{tgt}"
      when :skipping_noexifdate
        puts "Skipping.. No exif date: #{src}"
    end
  end

  puts "-------- import:end --------"
  puts
end

