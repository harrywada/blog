#!/bin/sh

# Usage: publish.sh file directory
#
# Use this script to "publish" a post. Really all this means is moving the
# target file to the given directory, renaming it to the current date, and
# appending a _unix_time definition to it. Since this effectively means only
# one post can be published a day, the script will refuse to delete any
# existing files that match the generated path, to mitigate any unintentional
# data loss.

readonly UNIX_TIME=$(date +%s)
readonly TARGET=$1 DIR=$2

if [ $# -lt 2 ]; then
	printf >&2 "Missing target and directory\n"
	exit 1
elif [ ! \( -r "$TARGET" -a -r "$TARGET" \) ]; then
	printf >&2 "Cannot read %s\n" "$TARGET"
	exit 1
elif [ ! \( -d "$DIR" -a -w "$DIR" \) ]; then
	printf >&2 "Cannot write to directory %s\n" "$DIR"
	exit 1
fi

ext=$(printf "%s\n" "$TARGET" | sed -r '/\./!d; s/.+(\.[^\.]+)$/\1/')
dest=articles/$(date -d@$UNIX_TIME +%Y%m%d)$ext
if [ -e "$dest" ]; then
	printf >&2 "The destination %s exists; delete it first\n" "$dest"
	exit 1
fi

cp "$TARGET" $dest
printf _unix_time=$UNIX_TIME\\n >>$dest

rm "$TARGET"
