require './zero-files.rb'
require './import-photos.rb'

require 'rubygems'
gem 'mocha'

require 'test/unit'
require 'mocha/test_unit'
require 'fakefs'

class ImageImportTest < Test::Unit::TestCase
  ROOT = '/tmp/root/'

  def setup
    FakeFS do
      FileUtils.mkpath '/tmp/root/2015'
      FileUtils.mkpath '/tmp/.cache/'

      FileUtils.mkpath '/tmp/root/.cache/'
      FileUtils.mkpath '/tmp/root/2015/01/'
      FileUtils.mkpath '/tmp/root/2017/05/'

      FileUtils.touch '/tmp/root/IMG_001.JPG'
      FileUtils.touch '/tmp/root/IMG_002.JPG'
      FileUtils.touch '/tmp/root/.cache/IMG_001.JPG'
      FileUtils.touch '/tmp/root/.cache/IMG_002.JPG'
      FileUtils.touch '/tmp/root/.cache/IMG_003.JPG'

      File.expects(:zero?).with('/tmp/root/IMG_001.JPG').returns(true)
      File.expects(:zero?).with('/tmp/root/IMG_002.JPG').returns(false)
    end 
  end

  def test_files
    valid_files = files(ROOT)
    assert_equal(['/tmp/root/IMG_002.JPG'], valid_files)
  end
end
