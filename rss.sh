#!/bin/sh

# Usage: rss.sh file...
#
# This script takes a series of files, generates RSS data from them, and prints
# it to standard output. Channel data is determined by TITLE, URI, and
# DESCRIPTION variables that must be set when this script is run.
#
# The shell-like variable declarations presumably at the bottom of each file
# are read, although only necessary ones (title, description, and _unix_time)
# are interpreted. If _unix_time is undefined, the current time is used.
#
# Any errors in reading or handling any of the arguments will be reported and
# nothing will be printed to standard output.

readonly UNIX_TIME=$(date +%s)
readonly RFC822_DATEFORMAT="%a, %d %b %Y %H:%M:%S %Z"
# A pcrepattern(3) specifying generally how a variable assignment should look.
readonly VAR_PATTERN="[a-zA-Z_][a-zA-Z0-9_]*=(\\$\\(.*\\)|\".*\"|'.*'|\\S*)"

if [ -z "$TITLE" -o -z "$URI" -o -z "$DESCRIPTION" ]; then
	printf >&2 "TITLE, URI, and DESCRIPTION must all be set\n"
	exit 1
fi

# If tac(1) is unavailable, use a sed(1) alternative (likely less efficient).
if ! command -v tac >/dev/null; then
	alias tac="sed -n '1!G;h;\$p'"
fi

# RSS items are collected into a variable first so any errors caught while
# generating them can be reported first without printing to standard output.
items=$(for file; do
	if [ ! \( -f "$file" -a -r "$file" \) ]; then
		printf >&2 "Cannot read file %s\n" "$file"
		# This is a li'l trick to continue while returning a positive
		# (errored) exit code.
		continue -1 2>/dev/null
	fi

	tac "$file" | {
		# The stdbuf(1) invocation is necessary here; otherwise sed(1)
		# will consume all of the input.
		while read -r x; do
			if [ -z "$x" ]; then continue; fi
			eval export $x
		done <<-END
		$(stdbuf -i0 sed -rn -e "/^$VAR_PATTERN$/!{x;q}" \
		                     -e "/^(title|description|_unix_time)=/p")
		END

		_unix_time=${_unix_time:-$UNIX_TIME}

		title=${title:-$(date -d@$_unix_time +"%A, %B %-d %Y")}
		uri=${URI%/}/$(date -d@$_unix_time +%Y%m%d).html
		date=$(date -d@$_unix_time +"$RFC822_DATEFORMAT")

		envsubst \$title:\$uri:\$date:\$description <<-END
		<item>
			<title>$title</title>
			<link>$uri</link>
			<description>$description</description>
			<pubDate>$date</pubDate>
			<guid>$uri</guid>
		</item>
		END

		# Unset this so that any future empty titles will be properly
		# handled.
		unset title
	}
done)
if [ $? -ne 0 ]; then exit 1; fi

export date=$(date -d@$UNIX_TIME +"$RFC822_DATEFORMAT")
envsubst \$TITLE:\$URI:\$DESCRIPTION:\$items:\$date <<-END
<rss version="2.0">
	<channel>
		<title>\$TITLE</title>
		<link>\$URI</link>
		<description>\$DESCRIPTION</description>
		<lastBuildDate>\$date</lastBuildDate>
		$items
	</channel>
</rss>
END
