require 'test/unit'
require './zero-files.rb'
require './import-media.rb'

#require 'pry'
#require 'pry-debugger'

class MediaImportTest < Test::Unit::TestCase
  TEST_DATA = "./test/data"

  SOURCE = "/tmp/root"
  @source_files = []
  @source_files_valid_media = []

  TARGET = "/tmp/imported"
  TARGET_UNDATED = "/tmp/imported/undated"
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

=begin
  def test_files_commandline
    valid_files = `ruby zero-files.rb`
    assert(valid_files.empty?)

    valid_files = `ruby zero-files.rb #{SOURCE}`
    list = valid_files.split("\n").reject { |l| /--/ =~ l || l.empty?}
    assert_equal((@source_files + ["#{SOURCE}/text.txt"]).sort, list)
  end
=end

  def test_media
    # check return
    assert_equal(@source_files, media_files(SOURCE))

    # check yield
    media_files(SOURCE) do |m, exif|
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

  def test_analyze_yield
    source_t = "#{SOURCE}/#{__method__}"

    begin
      FileUtils.mkpath source_t
      FileUtils.cp @source_files_valid_media.first, source_t
      target_file = TARGET_FILES.first
      source_file = "#{source_t}/#{File.basename(target_file)}"

      okay_to_import = false
      analyze source_t, TARGET do |s,t,e|
        case e
          when :okay_to_import
            assert_equal(s, source_file)
            assert_equal(t, target_file)
            okay_to_import = true
        end
      end
      assert(okay_to_import)

      duplicate_found = false
      FileUtils.cp source_file, "#{target_file}_1"
      analyze source_t, TARGET do |s,t,e|
        case e
          when :duplicate_found
            assert_equal(s, source_file)
            assert_equal(t, "#{target_file}_1")
            duplicate_found = true
        end
      end
      assert(duplicate_found)
      File.delete "#{target_file}_1"

      name_collision_found = false
      FileUtils.touch target_file
      analyze source_t, TARGET do |s,t,e|
        case e
          when :name_collision_found
            assert_equal(s, source_file)
            assert_equal(t, target_file)
            name_collision_found = true
        end
      end
      assert(name_collision_found)

      noexifdate = false
      FileUtils.rm_r Dir["#{source_t}/*"]
      FileUtils.cp "#{SOURCE}/noexifdate.png", source_t
      analyze source_t, TARGET do |s,t,e|
        case e
          when :noexifdate
            noexifdate = true
        end
      end
      assert(noexifdate)
    ensure
      FileUtils.rm_r source_t if File.exists?(source_t)
    end
  end

  def test_import_yield
    source_t = "#{SOURCE}/#{__method__}"

    begin
      FileUtils.mkpath source_t
      FileUtils.cp @source_files_valid_media.first, source_t
      target_file = TARGET_FILES.first
      source_file = "#{source_t}/#{File.basename(target_file)}"

      moving = false
      import source_t, TARGET do |s,t,e|
        case e
          when :moving
            assert_equal(s, source_file)
            assert_equal(t, target_file)
            moving = true
        end
      end
      assert(moving)

      duplicate_found = false
      FileUtils.mv target_file, source_file
      FileUtils.cp source_file, "#{target_file}_1"
      analyze source_t, TARGET do |s,t,e|
        case e
          when :duplicate_found
            assert_equal(s, source_file)
            assert_equal(t, "#{target_file}_1")
            duplicate_found = true
        end
      end
      assert(duplicate_found)
      File.delete "#{target_file}_1"

      name_collision_found = false
      FileUtils.touch target_file
      analyze source_t, TARGET do |s,t,e|
        case e
          when :name_collision_found
            assert_equal(s, source_file)
            assert_equal(t, target_file)
            name_collision_found = true
        end
      end
      assert(name_collision_found)

      moving_noexifdate = false
      FileUtils.rm_r Dir["#{source_t}/*"]
      FileUtils.cp "#{SOURCE}/noexifdate.png", source_t
      import source_t, TARGET do |s,t,e|
        case e
          when :moving_noexifdate
            moving_noexifdate = true
        end
      end
      assert(moving_noexifdate)
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
    assert_equal("Usage:\n  import-media.rb <source_path> <target_path>\n", media)

    TARGET_FILES.each { |f| File.delete(f) if File.exists? f }

    media = `ruby import-media.rb #{SOURCE} #{TARGET}`
    assert(@source_files_valid_media.all? { |f| !File.exists?(f) })
    assert(TARGET_FILES.all? { |f| File.exists?(f) })
  end

  def test_timestamp
    datetime = Time.parse('2014-09-02 06:44:48 +0530')
    assert_equal(timestamp(datetime), '2014-09-02-06-44-48')
  end

  def test_unique_file_name
    target_dir = "/tmp/#{__method__}"

    begin
      file_names = ["IMG_02.JPG", "IMG_02.JPG_1", "IMG_02_1.JPG", "IMG_02_2.JPG"]

      FileUtils.mkpath target_dir
      file_names.each do |fn|
        FileUtils.touch "#{target_dir}/#{fn}"
      end

      colliding_names = []
      unique = unique_file_name(target_dir, "IMG_02.JPG") do |colliding_name, event|
        case event
        when :name_collision_found
          colliding_names << File.basename(colliding_name)
        end
      end

      assert_equal("#{target_dir}/IMG_02_3.JPG", unique)
      assert_equal((file_names - ["IMG_02.JPG_1"]).sort, colliding_names.sort)
    ensure
      FileUtils.rm_r target_dir
    end
  end

  def test_import_noexifdate
    source_t = "#{SOURCE}/#{__method__}"

    begin
      moving_noexifdate = false
      FileUtils.mkpath source_t
      FileUtils.cp "#{SOURCE}/noexifdate.png", source_t
      import source_t, TARGET do |s,t,e|
        case e
          when :moving_noexifdate
            moving_noexifdate = true
            assert_equal("#{source_t}/noexifdate.png", s)
            assert_equal("#{TARGET_UNDATED}/noexifdate.png", t)
        end
      end
      assert(moving_noexifdate)
      assert(File.exists?("#{TARGET_UNDATED}/noexifdate.png"))
      assert(File.exists?("#{TARGET_UNDATED}/noexifdate.png.log"))
    ensure
      FileUtils.rm_r source_t if File.exists?(source_t)
    end
  end
end
