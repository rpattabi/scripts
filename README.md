# SCRIPTS

## import-media.rb

Imports photos and videos.

* **WARNING** *Moves* the photos and videos. *TODO: option to copy instead.*
* Imports media (photos & Videos) to Year/Month/Date directory structure in the target location, according to the media's meta-data (EXIF tags)
* Only imports media with proper meta-data tags. Skips otherwise.
* Works fine for JPEG Photos, AVI and QuickTime Videos (MOV, M4V, M2V, MP4, 3GP, 3G2)
* No Overwriting: Skips media if there's a file with the same name at the target. *TODO: Better Duplicates detection*
* Writes a neat log at target location everytime this script is invoked.
* Requires `ruby`
* Runs under `linux` *TODO: Platform Independance*

### Dependencies

* mini_exiftool gem (depends on exiftool library)
* mocha gem

### Usage

  `ruby import-media.rb source-directory target-directory`

## zero-files.rb

Provides a list of files in the given directory that are of zero length.

```
ruby zero-files.rb /path/to/folder

# outputs

/path/to/folder/zerofile1.IMG
/path/to/folder/another_folder/ze~.IMG
```

## delete-files.rb

Deletes given a list of files.

```
ruby zero-files.rb /path/to/folder > zero.log
ruby delete-files.rb zero.log

## outputs

Deleting.../path/to/folder/zerofile1.IMG
Deleting.../path/to/folder/another_folder/ze~.IMG
```
