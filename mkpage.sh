#!/bin/sh

# Takes as its only argument a file containing an RSS `<item>` and produces on
# standard output an HTML file depicting its contents.
#
# For easier parsing, the `<item>` must be formatted very specifically (see
# existing posts for examples). For that reason, there is essentially zero
# error handling.

# Lookup table for month numbers and names from a prefix (e.g. Jun, Aug).
MONTHS="01 January
        02 February
        03 March
        04 April
        05 May
        06 June
        07 July
        08 August
        09 September
        10 October
        11 November
        12 December"

while read -r line; do
	case "$line" in
	\<title\>*)
		title=${line#<title>}
		title=${title%</title>}
		;;
	\<description\>\<!\[CDATA\[)
		description=$(sed -n /^"]]><\/description>"$/q\;p)
		;;
	\<pubDate\>*)
		pub_date=${line#<pubDate>}
		pub_date=${pub_date%</pubDate>}
		IFS=,:\  read -r day no mo yr hr min sec tz <<-EOF
		$pub_date
		EOF
		# Month number and expansion, respectively.
		read -r mon mox <<-EOF
		$(printf %s "$MONTHS" | grep $mo)
		EOF

		dt="$yr-$mon-$no"T"$hr:$min:$sec$tz"
		date="$mox $no, 20${yr#20}"
		;;
	esac
done <"$1"

cat <<-EOF
<!DOCTYPE html>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>$title</title>
<link rel="stylesheet" href="/index.css" />
<link rel="alternate" type="application/rss+xml" name="RSS" href="/feed.rss" />
<h1>$title</h1>
$description
<p id="timestamp">
<time datetime="$dt">$date</time>
<footer>
<hr />
<p>
<a href="/">Index</a>
</footer>
EOF
