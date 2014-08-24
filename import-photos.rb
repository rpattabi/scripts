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

      #exif.user_comment = "original:#{img}"
      #exif.save

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

  now = Time.now
  timestamp = "#{now.year}-#{now.month}-#{now.day}-#{now.hour}-#{now.min}-#{now.sec}"
  log = File.open("#{ARGV[1].chomp('/')}/import-photos_#{timestamp}.log", 'w')

  import(images(ARGV[0]), ARGV[1]) do |src, tgt, event|
    msg = nil

    case event
      when :moving
        msg = "Moving.. from: #{src} --> #{tgt}"
      when :skipping_collision
        msg = "Skipping.. name collision: #{tgt}"
      when :skipping_noexifdate
        msg = "Skipping.. No exif date: #{src}"
      else
        msg = "UNEXPECTED.. src: #{src} tgt: #{tgt} event: #{event}"
    end

    puts msg
    log.puts msg
    log.flush
  end

  log.close

  puts "-------- import:end --------"
  puts
end

