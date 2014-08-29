require "test/unit"
require "./zero-files.rb"
require "./import-media.rb"

class ImageImportTest < Test::Unit::TestCase
  TEST_DATA = "./test/data"

  SOURCE = "/tmp/root"
  @source_files = []
  @source_files_valid_media = []

  TARGET = "/tmp/imported"
  TARGET_FILES = ["#{TARGET}/2008/08/29/IMG_002.JPG",
                  "#{TARGET}/2001/02/19/sample_.mov",
                  "#{TARGET}/2005/10/17/sample.mov",
                  "#{TARGET}/2005/10/28/sample.3g2",
                  "#{TARGET}/2005/10/28/sample.3gp",
                  "#{TARGET}/2005/10/28/sample.mp4",
                  "#{TARGET}/2005/12/20/sample.m4v",
                  "#{TARGET}/2008/08/29/IMG_002.JPG"]

  def setup
    FileUtils.cp_r "#{TEST_DATA}/.", SOURCE
    @source_files = Dir["#{SOURCE}/*"].reject { |f| File.directory? f }.sort
    @source_files_valid_media = @source_files.reject { |f| /noexifdate/ =~ f } 

    FileUtils.mkpath "#{SOURCE}/2015"
    FileUtils.mkpath "/tmp/.cache/"

    FileUtils.mkpath "#{SOURCE}/.cache/"
    FileUtils.mkpath "#{SOURCE}/2015/01/"
    FileUtils.mkpath "#{SOURCE}/2017/05/"

    FileUtils.touch "#{SOURCE}/zero.JPG"
    File.open("#{SOURCE}/text.txt", 'w') { |txt_f| txt_f.write 'dummy content' }
    FileUtils.touch "#{SOURCE}/zero.txt"

    FileUtils.touch "#{SOURCE}/.cache/IMG_001.JPG"
    FileUtils.cp_r "#{TEST_DATA}/.", "#{SOURCE}/.cache/"
    FileUtils.touch "#{SOURCE}/.cache/IMG_003.JPG"

    FileUtils.mkpath TARGET
  end

  def teardown
    FileUtils.rm_r SOURCE
    FileUtils.rm_r TARGET if File.exists?(TARGET)
  end

  def test_files
    valid_files = files(SOURCE)
    assert_equal((@source_files + ["#{SOURCE}/text.txt"]).sort, valid_files.sort)
  end

  def test_files_commandline
    valid_files = `ruby zero-files.rb`
    assert(valid_files.empty?)

    valid_files = `ruby zero-files.rb #{SOURCE}`
    list = valid_files.split("\n").reject { |l| /--/ =~ l || l.empty?}
    assert_equal((@source_files + ["#{SOURCE}/text.txt"]).sort, list)
  end

  def test_media
    # check return
    assert_equal(@source_files, media(SOURCE))

    # check yield
    media(SOURCE) do |m, exif|
      assert(@source_files.include?(m))
    end
  end

  def test_date_dir
    d = '2009-09-30 11:10:55 UTC'
    dir = date_dir(TARGET, Time.parse(d))
    assert_equal("#{TARGET}/2009/09/30", dir)
  end

  def test_import
    TARGET_FILES.each { |f| File.delete(f) if File.exists? f }

    import SOURCE, TARGET
    assert(@source_files_valid_media.all? { |f| !File.exists?(f) })
    assert(TARGET_FILES.all? { |f| File.exists?(f) })
  end

  def test_import_yield
    source_t = "#{SOURCE}/#{__method__}"

    begin
      FileUtils.mkpath source_t
      FileUtils.cp @source_files_valid_media.first, source_t
      target_file = TARGET_FILES.first

      moving = false
      import source_t, TARGET do |s,t,e|
        case e
          when :moving
            moving = true
        end
      end
      assert(moving)

      skipping_collision = false
      FileUtils.cp target_file, source_t
      import source_t, TARGET do |s,t,e|
        case e
          when :skipping_collision
            skipping_collision = true
        end
      end
      assert(skipping_collision)

      skipping_noexifdate = false
      FileUtils.rm_r Dir["#{source_t}/*"]
      FileUtils.cp "#{SOURCE}/noexifdate.png", source_t
      import source_t, TARGET do |s,t,e|
        case e
          when :skipping_noexifdate
            skipping_noexifdate = true
        end
      end
      assert(skipping_noexifdate)
    ensure
      FileUtils.rm_r source_t if File.exists?(source_t)
    end
  end

  def test_import_errorhandling
    source_t = "#{SOURCE}/#{__method__}"
    FileUtils.mkpath source_t
    FileUtils.cp @source_files_valid_media.first, source_t

    # faking a failure
    FileUtils.instance_eval do
      alias :original_mkpath :mkpath

      @@hit = false
      def self.mkpath path
        if @@hit
          original_mkpath path # so that we don't screw up other tests
        else
          @@hit = true
          raise IOError, 'faking a failure'
        end
      end
    end

    error = false
    import source_t, TARGET do |s,t,e|
      case e
        when :error
          assert_equal($!.class, IOError)
          error = true
      end
    end
    assert(error)
  end

  def test_import_commandline
    media = `ruby import-media.rb`
    assert(media.empty?)

    TARGET_FILES.each { |f| File.delete(f) if File.exists? f }

    media = `ruby import-media.rb #{SOURCE} #{TARGET}`
    assert(@source_files_valid_media.all? { |f| !File.exists?(f) })
    assert(TARGET_FILES.all? { |f| File.exists?(f) })
  end
end
