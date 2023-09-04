#!/bin/sh

# Takes as its only argument an RSS file and creates an HTML index file from
# its contents.
#
# For easier parsing, the `<item>`s must be formatted very specifically (see
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

# A helper function for reading and populating into the `items` variable.
read_item() {
	while read -r line; do
		case "$line" in
		\<title\>*)
			title=${line#<title>}
			title=${title%</title>}
			;;
		\<link\>*)
			link=${line#<link>}
			link=${link%</link>}
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
		\</item\>)
			break
			;;
		esac
	done

	# Prefix each item with the time and stripped title for later sorting.
	items="$items$yr$mon$no$hr$min$sec$(printf %s "$title" | tr -d \ ) \
<li><time datetime=\"$dt\">$date</time><br /><a href=\"$link\">$title</a>
"
}

while read -r line; do
	case "$line" in
	\<title\>*)
		blogname=${line#<title>}
		blogname=${blogname%</title>}
		;;
	\<link\>*)
		root_url=${line#<link>}
		root_url=${root_url%</link>}
		root_url=${root_url%/}
		;;
	\<description\>)
		description=$(sed -n /^"<\/description>"$/q\;p)
		;;
	\<item\>)
		read_item
		;;
	esac
done <"$1"

cat <<-EOF
<!DOCTYPE html>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>$blogname</title>
<link rel="stylesheet" href="/index.css" />
<link rel="alternate" type="application/rss+xml" name="RSS" href="/feed.rss" />
<h1>$blogname</h1>
<p>
$description
<ul id="index">
$(printf %s "$items" | sort -r | cut -d \  -f 2-)
</ul>
<footer>
<hr />
<p id="source">
<a href="https://www.harrywada.com/git/harry/blog/">Source</a>
</footer>
EOF
