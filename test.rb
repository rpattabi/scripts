require "./zero-files.rb"
require "./import-media.rb"

require "rubygems"
gem "mocha"

require "test/unit"
require "mocha/test_unit"

class ImageImportTest < Test::Unit::TestCase
  SOURCE = "/tmp/root"
  SOURCE_FILE = "#{SOURCE}/IMG_002.JPG"
  TARGET = "#{SOURCE}/imported"
  TARGET_PATH = "#{TARGET}/2008/08/29"
  TARGET_FILE = "#{TARGET_PATH}/IMG_002.JPG"

  def setup
    FileUtils.mkpath "#{SOURCE}/2015"
    FileUtils.mkpath "/tmp/.cache/"

    FileUtils.mkpath "#{SOURCE}/.cache/"
    FileUtils.mkpath "#{SOURCE}/2015/01/"
    FileUtils.mkpath "#{SOURCE}/2017/05/"

    FileUtils.touch "#{SOURCE}/IMG_001.JPG"
    FileUtils.touch "#{SOURCE}/text.txt"
    FileUtils.touch "#{SOURCE}/text-.txt"
    FileUtils.cp "./test/data/IMG_002.JPG", "#{SOURCE}/IMG_002.JPG"
    FileUtils.cp "./test/data/noexifdate.png", "#{SOURCE}/noexifdate.png"
    FileUtils.touch "#{SOURCE}/.cache/IMG_001.JPG"
    FileUtils.cp "./test/data/IMG_002.JPG", "#{SOURCE}/.cache/IMG_002.JPG"
    FileUtils.touch "#{SOURCE}/.cache/IMG_003.JPG"

    File.expects(:zero?).with("#{SOURCE}/IMG_001.JPG").returns(true)
    File.expects(:zero?).with("#{SOURCE}/IMG_002.JPG").returns(false)
    File.expects(:zero?).with("#{SOURCE}/text.txt").returns(false)
    File.expects(:zero?).with("#{SOURCE}/text-.txt").returns(true)
    File.expects(:zero?).with("#{SOURCE}/noexifdate.png").returns(false)

    FileUtils.mkpath TARGET
  end

  def teardown
    FileUtils.rm_r SOURCE
  end

  def test_files
    valid_files = files(SOURCE)
    assert_equal(["#{SOURCE}/IMG_002.JPG", "#{SOURCE}/text.txt", "#{SOURCE}/noexifdate.png"].sort, valid_files.sort)
  end

  def test_files_commandline
    valid_files = `ruby zero-files.rb`
    assert(valid_files.empty?)

    valid_files = `ruby zero-files.rb #{SOURCE}`
    list = valid_files.split("\n").reject { |l| /--/ =~ l || l.empty?}
    assert_equal(["#{SOURCE}/IMG_002.JPG", "#{SOURCE}/noexifdate.png"].sort, list);
  end

  def test_media
    media = media(SOURCE)
    assert_equal(["#{SOURCE}/IMG_002.JPG", "#{SOURCE}/noexifdate.png"], media)
  end

  def test_date_dir
    d = '2009-09-30 11:10:55 UTC'
    dir = date_dir(TARGET, Time.parse(d))
    assert_equal("#{TARGET}/2009/09/30", dir)
  end

  def test_import
    File.delete(TARGET_FILE) if File.exists? TARGET_FILE

    import [SOURCE_FILE], TARGET
    assert(!File.exists?(SOURCE_FILE))
    assert(File.exists?(TARGET_PATH))
    assert(File.exists?(TARGET_FILE))
  end

  def test_import_yield
    moving = nil
    import [SOURCE_FILE], TARGET do |s,t,e|
      case e
        when :moving
          moving = true
      end
    end
    assert(moving);

    skipping_collision = nil
    FileUtils.cp TARGET_FILE, SOURCE_FILE
    import [SOURCE_FILE], TARGET do |s,t,e|
      case e
        when :skipping_collision
          skipping_collision = true
      end
    end
    assert(skipping_collision);

    skipping_noexifdate = nil
    import ["#{SOURCE}/noexifdate.png"], TARGET do |s,t,e|
      case e
        when :skipping_noexifdate
          skipping_noexifdate = true
      end
    end
    assert(skipping_noexifdate);
  end

  def test_import_commandline
    media = `ruby import-media.rb`
    assert(media.empty?)

    File.delete(TARGET_FILE) if File.exists? TARGET_FILE
    File.delete(TARGET_PATH) if File.exists? TARGET_PATH

    media = `ruby import-media.rb #{SOURCE} #{TARGET}`
    assert(!File.exists?(SOURCE_FILE))
    assert(File.exists?(TARGET_PATH))
    assert(File.exists?(TARGET_FILE))
  end

  def test_duplicate
  end
end
