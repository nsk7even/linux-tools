# linux-tools
Single file linux scripts.

## system-tools
Tools for the system level for both, non-interactive and interactive usage.
Root access required. Caution!

## file-handling-tools
Tools that work on files.

### fix-mp4-createdate.sh
Fixes the EXIF fields `CreateDate`, `TrackCreateDate`, `MediaCreateDate` with
writing the value from `DateTimeOriginal` to them, cause the latter contains the
correct value.

