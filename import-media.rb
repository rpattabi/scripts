require 'find'
require 'fileutils'

require 'mimemagic'
require 'mini_exiftool'

require './zero-files.rb'

def media(dir)
  media = []
  files(dir) do |f|
    File.open(f, 'r') do |file|
      filetype = MimeMagic.by_magic(file)
      next if filetype.nil?

      if filetype.image? || filetype.video? #|| filetype.audio?
        yield f, MiniExiftool.new(f) if block_given?
        media << f
      end
    end
  end
  media
end

def import(from_dir, to_dir)
  analyze(from_dir, to_dir) do |from, to, event|
    case event
    when :okay
      yield from, to, :moving if block_given?
      FileUtils.mv from, to
    when :name_collision
      yield from, to, :skipping_collision if block_given?
    when :noexifdate
      yield from, to, :skipping_noexifdate if block_given?
    when :error
      yield from, to, :error if block_given?
    else
      #yield from, to, event if block_given?
    end
  end
end

def analyze(from_dir, to_dir)
  media(from_dir) do |m, exif|
    begin
      # exif tags from images and avi
      date = exif.DateTimeOriginal
      date = exif.DateTimeDigitized if date.nil?
      date = exif.DateTime if date.nil?

      # tags from videos
      date = exif.MediaCreateDate if date.nil?
      date = exif.TrackCreateDate if date.nil?
      date = exif.CreateDate if date.nil?

      if date.nil?
        yield m, nil, :noexifdate if block_given?
        next
      end

      date_dir = date_dir(to_dir, date)
      FileUtils.mkpath date_dir

      target = "#{date_dir}/#{File.basename(m)}"

      if File.exists?(target)
        yield m, target, :name_collision if block_given?
      else
        yield m, target, :okay if block_given?
      end
    rescue
      yield m, nil, :error if block_given?
    end
  end
end

def date_dir(root_dir, date)
  "#{root_dir.chomp('/')}/#{date.year}/#{'%02d' % date.month}/#{'%02d' % date.day}"
end

#
# Commandline Processing
#
from_dir = ARGV[0]
to_dir = ARGV[1]

unless from_dir.nil? || to_dir.nil?
  puts
  puts "-------- import:start #{Time.now} --------"

  now = Time.now
  timestamp = "#{now.year}-#{now.month}-#{now.day}-#{now.hour}-#{now.min}-#{now.sec}"
  FileUtils.mkpath to_dir
  log = File.open("#{to_dir.chomp('/')}/import-photos_#{timestamp}.log", 'w')

  import(from_dir, to_dir) do |src, tgt, event|
    msg = nil

    case event
    when :moving
      msg = "Moving.. from: #{src} --> #{tgt}"
    when :skipping_collision
      msg = "Skipping.. name collision: #{src} <==> #{tgt}"
    when :skipping_noexifdate
      msg = "Skipping.. No exif date: #{src}"
    when :error
      msg = "ERROR.. src: #{src} tgt: #{tgt} event: #{?!.inspect}"
    else
      msg = "UNKNOWN_EVENT.. src: #{src} tgt: #{tgt} event: #{event}"
    end

    puts msg
    log.puts msg
    log.flush
  end

  log.close

  puts "-------- import:end #{Time.now} --------"
  puts
end

