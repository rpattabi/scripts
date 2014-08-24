require "./zero-files.rb"
require "./import-photos.rb"

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
    FileUtils.touch "#{SOURCE}/.cache/IMG_001.JPG"
    FileUtils.cp "./test/data/IMG_002.JPG", "#{SOURCE}/.cache/IMG_002.JPG"
    FileUtils.touch "#{SOURCE}/.cache/IMG_003.JPG"

    File.expects(:zero?).with("#{SOURCE}/IMG_001.JPG").returns(true)
    File.expects(:zero?).with("#{SOURCE}/IMG_002.JPG").returns(false)
    File.expects(:zero?).with("#{SOURCE}/text.txt").returns(false)
    File.expects(:zero?).with("#{SOURCE}/text-.txt").returns(true)

    FileUtils.mkpath TARGET
  end

  def teardown
    FileUtils.rm_r SOURCE
  end

  def test_files
    valid_files = files(SOURCE)
    assert_equal(["#{SOURCE}/IMG_002.JPG", "#{SOURCE}/text.txt"].sort, valid_files.sort)
  end

  def test_files_commandline
    valid_files = `ruby zero-files.rb`
    assert(valid_files.empty?)

    valid_files = `ruby zero-files.rb #{SOURCE}`
    assert_equal(["#{SOURCE}/IMG_002.JPG"].sort, valid_files.split("\n").sort)
  end

  def test_images
    images = images(SOURCE)
    assert_equal(["#{SOURCE}/IMG_002.JPG"], images)
  end

  def test_date_dir
    d = '2009-09-30 11:10:55 UTC'
    dir = date_dir(TARGET, Time.parse(d))
    assert_equal("#{TARGET}/2009/09/30", dir)
  end

  def test_import
    File.delete(TARGET_FILE) if File.exists? TARGET_FILE

    import [SOURCE_FILE], TARGET
    puts "debugging.."
    puts `tree #{SOURCE}`
    puts `tree #{TARGET}`
    assert(!File.exists?(SOURCE_FILE))
    assert(File.exists?(TARGET_PATH))
    assert(File.exists?(TARGET_FILE))
  end

  def test_import_commandline
    images = `ruby import-photos.rb`
    assert(images.empty?)

    File.delete(TARGET_FILE) if File.exists? TARGET_FILE
    File.delete(TARGET_PATH) if File.exists? TARGET_PATH

    images = `ruby import-photos.rb #{SOURCE} #{TARGET}`
    assert(!File.exists?(SOURCE_FILE))
    assert(File.exists?(TARGET_PATH))
    assert(File.exists?(TARGET_FILE))
  end
end