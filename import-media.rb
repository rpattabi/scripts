require 'find'
require 'fileutils'
require 'mini_exiftool'

require './zero-files.rb'

def media(dir)
  # TODO: Implement if more efficiently
  # May be better approach is to yield
  files(dir).select { |f| 
    /^(image|video)/ =~ `file -b --mime-type "#{f}"`
  }
end

def import(media, to_dir)
  media.each { |m|
    begin
      exif = MiniExiftool.new m
 
      # exif tags from images
      date = exif.DateTimeOriginal
      date = exif.DateTimeDigitized if date.nil?
      date = exif.DateTime if date.nil?

      # tags from videos
      date = exif.MediaCreateDate if date.nil?
      date = exif.TrackCreateDate if date.nil?
      date = exif.CreateDate if date.nil?
 
      if date.nil?
        yield m, nil, :skipping_noexifdate if block_given?
        next
      end
 
      date_dir = date_dir(to_dir, date)
      FileUtils.mkpath date_dir
 
      target = "#{date_dir}/#{File.basename(m)}"
 
      if File.exists?(target)
        yield m, target, :skipping_collision if block_given?
      else
        yield m, target, :moving if block_given?
 
        #exif.user_comment = "original:#{m}"
        #exif.save
 
        FileUtils.mv m, target
      end
    rescue Exception => e
      yield m, nil, "exception: #{e.message}\n#{e.backtrace.inspect}"
    end
  }
end

def date_dir(root_dir, date)
    "#{root_dir.chomp('/')}/#{date.year}/#{'%02d' % date.month}/#{'%02d' % date.day}"
end

unless ARGV[0].nil? || ARGV[1].nil?
  puts
  puts "-------- import:start #{Time.now}--------"

  now = Time.now
  timestamp = "#{now.year}-#{now.month}-#{now.day}-#{now.hour}-#{now.min}-#{now.sec}"
  FileUtils.mkpath ARGV[1]
  log = File.open("#{ARGV[1].chomp('/')}/import-photos_#{timestamp}.log", 'w')

  import(media(ARGV[0]), ARGV[1]) do |src, tgt, event|
    msg = nil

    case event
      when :moving
        msg = "Moving.. from: #{src} --> #{tgt}"
      when :skipping_collision
        msg = "Skipping.. name collision: #{src} <==> #{tgt}"
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

  puts "-------- import:end #{Time.now}--------"
  puts
end

