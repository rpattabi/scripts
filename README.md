# SCRIPTS

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
