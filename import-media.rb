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

def import(from_dir, to_dir, operation=:move)
  #binding.pry
  analyze(from_dir, to_dir) do |from, to, event|
    case event
    when :okay_to_import
      if (operation == :move)
        yield from, to, :moving if block_given?
        FileUtils.mv from, to
      elsif (operation == :copy)
        yield from, to, :copying if block_given?
        FileUtils.cp from, to
      end
    when :Skipping
      yield from, to, :skipping if block_given?
    when :name_collision_found
      yield from, to, :name_collision_found if block_given?
    when :noexifdate
      if (operation == :move)
        yield from, to, :moving_noexifdate if block_given?
        FileUtils.mv from, to
      elsif (operation == :copy)
        yield from, to, :copying_noexifdate if block_given?
        FileUtils.cp from, to
      end

      open("#{to}.log", 'w') do |f|
        f.puts "original path: #{from}"
        f.puts "siblings at the time of import:"
        f.puts `ls "#{File.dirname(from)}"`
      end
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

      target_dir = nil
      if date.nil?
        target_dir = "#{to_dir}/undated"
      else
        target_dir = date_dir(to_dir, date)
      end

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
        if date.nil?
          yield media_file, target, :noexifdate
        else
          yield media_file, target, :okay_to_import
        end
      end
    rescue
      yield media_file, nil, :error
    end
  end
end

def date(media_file)
  begin
    exif = MiniExiftool.new media_file

    # exif tags from images and avi
    date = exif.DateTimeOriginal
    date = exif.DateTimeDigitized if date.nil?
    date = exif.DateTime if date.nil?

    # tags from videos
    date = exif.MediaCreateDate if date.nil?
    date = exif.TrackCreateDate if date.nil?
    date = exif.CreateDate if date.nil?

    if date.instance_of? String
      date = Time.parse date
    end

    date
  rescue
    nil
  end
end

def compute_target_file_name(src, target_dir)
  duplicate = find_duplicate(src, target_dir)

  unless duplicate.nil?
    yield duplicate, :duplicate_found
    return nil # no need to get unique name if duplicate already exists at target
  end

  seed = File.basename(src)
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

  ext = File.extname(seed_file_name)
  seed_fullpath = "#{dir}/#{seed_file_name}"
  basename_noext = File.basename(seed_file_name, ext)

  while File.exists?(seed_fullpath)
    yield seed_fullpath, :name_collision_found

    seed_fullpath = "#{dir}/#{basename_noext}_#{suffix}#{ext}" # ext includes dot
    suffix += 1
  end

  seed_fullpath
end

def date_dir(root_dir, date)
  "#{root_dir.chomp('/')}/#{date.year}/#{'%02d' % date.month}/#{'%02d' % date.day}"
end

def timestamp(datetime)
  "#{datetime.year}-#{'%02d' % datetime.month}-#{'%02d' % datetime.day}-#{'%02d' % datetime.hour}-#{'%02d' % datetime.min}-#{'%02d' % datetime.sec}"
end

#
# Commandline Processing
#
require 'docopt'

USAGE = <<DOCOPT
Imports media (photos, videos) according to exif date information.

Usage:
  #{__FILE__} <source_path> <target_path>
  #{__FILE__} [(--move | -mv) | (--copy | -cp)] <source_path> <target_path>

Options:
  -h --help      Shows this screen
  <source_path>  Source root directory with media to import
  <target_path>  Target root directory
  -mv --move     Moves media at the source_path to target_path (according to the exif date) recursively.
  -cv --copy     Copies media at the source_path to target_path (according to the exif date) recursively.
DOCOPT

begin
  cmdline = Docopt::docopt(USAGE)

  from_dir = cmdline['<source_path>'].chomp('/').chomp('\\')
  to_dir =cmdline['<target_path>'].chomp('/').chomp('\\')
  operation = cmdline['--copy'] ? :copy : :move

  unless from_dir.nil? || to_dir.nil?
    start_time = Time.now

    puts
    puts "#{start_time}: Import Started..."

    FileUtils.mkpath to_dir
    log = File.open("#{to_dir}/import-photos_#{timestamp(start_time)}.log", 'w')

    import(from_dir, to_dir, operation) do |src, tgt, event|
      msg = nil

      case event
      when :moving
        msg = "Moving.. from: #{src} --> #{tgt}"
      when :copying
        msg = "Copying.. from: #{src} --> #{tgt}"
      when :moving_noexifdate
        msg = "Moving.. (No exif date) from: #{src} --> #{tgt}"

        open("#{tgt}.log", 'w') do |undated_log|
          undated_log.puts "original path: #{src}"
          undated_log.puts "siblings at the time of import (source dir):"
          undated_log.puts `ls "#{File.dirname(src)}"`
        end
      when :copying_noexifdate
        msg = "Copying.. (No exif date) from: #{src} --> #{tgt}"

        open("#{tgt}.log", 'w') do |undated_log|
          undated_log.puts "original path: #{src}"
          undated_log.puts "siblings at the time of import (source dir):"
          undated_log.puts `ls "#{File.dirname(src)}"`
        end
      when :skipping
        # no need to log. skipping most likely due to duplicate.
        #msg = "Skipping.. : #{src}"
      when :duplicate_found
        msg = "Skipping.. duplicate found: #{src} <==> #{tgt}"
      when :name_collision_found
        msg = "Renaming.. Name already exists: #{src} <==> #{tgt}"
      when :error
        msg = "ERROR.. src: #{src} tgt: #{tgt} event: #{$!.inspect}"
      else
        msg = "UNKNOWN_EVENT.. src: #{src} tgt: #{tgt} event: #{event}"
      end

      unless msg.nil?
        puts msg
        log.puts msg
        log.flush
      end
    end

    end_time = Time.now

    conclusion = <<END

---------------------------------------------------
Import started on : #{start_time}
Import ended on   : #{end_time}
---------------------------------------------------

END

    log.puts conclusion
    log.close

    puts conclusion
  end
rescue Docopt::Exit => e
  puts e.message
end


