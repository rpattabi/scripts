require "./zero-files.rb"
require "./import-photos.rb"

require "rubygems"
gem "mocha"

require "test/unit"
require "mocha/test_unit"

class ImageImportTest < Test::Unit::TestCase
  ROOT = "/tmp/root"

  def setup
    FileUtils.mkpath "#{ROOT}/2015"
    FileUtils.mkpath "/tmp/.cache/"

    FileUtils.mkpath "#{ROOT}/.cache/"
    FileUtils.mkpath "#{ROOT}/2015/01/"
    FileUtils.mkpath "#{ROOT}/2017/05/"

    FileUtils.touch "#{ROOT}/IMG_001.JPG"
    FileUtils.touch "#{ROOT}/text.txt"
    FileUtils.touch "#{ROOT}/text-.txt"
    FileUtils.cp "./test/data/IMG_002.JPG", "#{ROOT}/IMG_002.JPG"
    FileUtils.touch "#{ROOT}/.cache/IMG_001.JPG"
    FileUtils.cp "./test/data/IMG_002.JPG", "#{ROOT}/.cache/IMG_002.JPG"
    FileUtils.touch "#{ROOT}/.cache/IMG_003.JPG"

    File.expects(:zero?).with("#{ROOT}/IMG_001.JPG").returns(true)
    File.expects(:zero?).with("#{ROOT}/IMG_002.JPG").returns(false)
    File.expects(:zero?).with("#{ROOT}/text.txt").returns(false)
    File.expects(:zero?).with("#{ROOT}/text-.txt").returns(true)
  end

  def teardown
    FileUtils.rm_r ROOT
  end

  def test_files
    valid_files = files(ROOT)
    assert_equal(["#{ROOT}/IMG_002.JPG", "#{ROOT}/text.txt"].sort, valid_files.sort)
  end

  def test_images
    images = images(ROOT)
    assert_equal(["#{ROOT}/IMG_002.JPG"], images)
  end
end
