#require 'rubygems'
#require 'pry'
#require 'pry-debugger'

require 'find'
require 'fileutils'

require 'mimemagic'
require 'mini_exiftool'
require 'memoist'

require './zero-files.rb'

class Speed
  class << self
    extend Memoist

    def checksum(file)
      Digest::SHA2.file(file)
    end

    memoize :checksum
  end
end

def media_files(dir)
  media = []
  files(dir) do |f|
    File.open(f, 'r') do |file|
      filetype = MimeMagic.by_magic(file)
      next if filetype.nil?

      if filetype.image? || filetype.video? #|| filetype.audio?
        yield f if block_given?
        media << f
      end
    end
  end
  media
end

def import(from_dir, to_dir)
  #binding.pry
  analyze(from_dir, to_dir) do |from, to, event|
    case event
    when :okay_to_import
      yield from, to, :moving if block_given?
      FileUtils.mv from, to
    when :Skipping
      yield from, to, :skipping if block_given?
    when :name_collision_found
      yield from, to, :name_collision_found if block_given?
    when :noexifdate
      yield from, to, :skipping_noexifdate if block_given?
    when :error
      yield from, to, :error if block_given?
    else
      yield from, to, event if block_given?
    end
  end
end

def analyze(from_dir, to_dir)
  media_files(from_dir) do |media_file|
    begin
      date = date(media_file)
      if date.nil?
        yield media_file, nil, :noexifdate
        next
      end

      target_dir = date_dir(to_dir, date)
      FileUtils.mkpath target_dir

      target = compute_target_file_name(media_file, target_dir) do |existing_target_file, event|
        case event
        when :duplicate_found
          yield media_file, existing_target_file, :duplicate_found
          break # no need to continue importing, once a duplicate is found.
        when :name_collision_found
          yield media_file, existing_target_file, :name_collision_found
        end
      end

      if target.nil?
        # most likely duplicate was found.
        # we would have already raised :duplicate.
        yield media_file, nil, :skipping
      else
        yield media_file, target, :okay_to_import
      end
    rescue
      yield media_file, nil, :error
    end
  end
end

def date(media_file)
  exif = MiniExiftool.new media_file

  # exif tags from images and avi
  date = exif.DateTimeOriginal
  date = exif.DateTimeDigitized if date.nil?
  date = exif.DateTime if date.nil?

  # tags from videos
  date = exif.MediaCreateDate if date.nil?
  date = exif.TrackCreateDate if date.nil?
  date = exif.CreateDate if date.nil?

  date
end

def compute_target_file_name(src, target_dir)
  duplicate = find_duplicate(src, target_dir)

  unless duplicate.nil?
    yield duplicate, :duplicate_found
    return nil # no need to get unique name if duplicate already exists at target
  end

  seed = "#{target_dir}/#{File.basename(src)}"
  target_file_name = unique_file_name(target_dir, seed) do |colliding_name|
    yield colliding_name, :name_collision_found
  end

  target_file_name
end

def find_duplicate(src, target_dir)
  Dir["#{target_dir}/*"].each do |target|
    return target if Speed.checksum(src) == Speed.checksum(target)
  end
  nil
end

def unique_file_name(dir, seed_file_name)
  suffix = 1

  while File.exists?(seed_file_name)
    yield seed_file_name, :name_collision_found

    seed_file_name += "_#{suffix}"
    suffix += 1
  end

  seed_file_name
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
    when :skipping
      # no need to log. skipping most likely due to duplicate.
      #msg = "Skipping.. : #{src}"
    when :duplicate_found
      msg = "Skipping.. duplicate found: #{src} <==> #{tgt}"
    when :name_collision_found
      msg = "Renaming.. Name already exists: #{src} <==> #{tgt}"
    when :skipping_noexifdate
      msg = "Skipping.. No exif date: #{src}"
    when :error
      msg = "ERROR.. src: #{src} tgt: #{tgt} event: #{?!.inspect}"
    else
      msg = "UNKNOWN_EVENT.. src: #{src} tgt: #{tgt} event: #{event}"
    end

    unless msg.nil?
      puts msg 
      log.puts msg
      log.flush
    end
  end

  log.close

  puts "-------- import:end #{Time.now} --------"
  puts
end

