#!/bin/sh

# Usage: index.sh file...
#
# Create an index file which will offer a convenient list of available posts
# according to the file arguments provided. The TITLE variable must also be set
# as well, as this will be used as the header.

. ./funcs.sh

if [ -z "$TITLE" ]; then
	printf >&2 "TITLE must be set\n"
	exit 1
fi

# If tac(1) is unavailable, use a sed(1) alternative (likely less efficient).
if ! command -v tac >/dev/null; then
	alias tac="sed -n '1!G;h;\$p'"
fi

# List items are collected into a variable first so any errors caught while
# generating them can be reported first without printing to standard output.
items=$(for file; do
	if [ ! \( -f "$file" -a -r "$file" \) ]; then
		printf >&2 "Cannot read file %s\n" "$file"
		# This is a li'l trick to continue while returning a positive
		# (errored) exit code.
		continue -1 2>/dev/null
	fi

	tac "$file" | {
		setvars title description keywords _unix_time >/dev/null \
		     || exit 1

		_unix_time=${_unix_time:-$UNIX_TIME}

		title=${title:-$(date -d@$_unix_time +"%A, %B %-d %Y")}
		uri=${URI%/}/$(date -d@$_unix_time +%Y/%m/%d)
		date=$(date -d@$_unix_time +%Y%m%d)
		date_pretty=$(date -d@$_unix_time +"%B %-d, %Y")

		envsubst \$title:\$uri:\$date:\$description <<-END
		<li>
			$date_pretty
			<br /><a href="/$date.html">$title</a>:
			$description
			<br /><small>$keywords</small>
		END
	}
done)
if [ $? -ne 0 ]; then exit 1; fi

envsubst \$TITLE:\$items <<-END
<!DOCTYPE html>

<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />

<title>Harry Wada's blog</title>

<link rel="stylesheet" href="/index.css" />
<link rel="alternate" type="application/rss+xml" name="RSS" href="/feed.xml" />

<html lang="en">

<h1>Harry Wada's blog</h1>

<p>
My own little corner of the Internet I've carved out for myself. Take off your
shoes; stay for awhile.

<ul id="index">
$items
</ul>

<footer>
	<hr />
	<p id="copyright">
	This website is
	<a href="https://github.com/harrywada/blog/">open source</a> and
	licensed under the <a rel="license" href="/COPYING">WTFPL</a>.
</footer>
END
