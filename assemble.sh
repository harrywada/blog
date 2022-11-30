#!/bin/sh

# Usage: assemble.sh [file] [header] [footer]
#
# Given an input file, generate to standard output the concatenation of an
# optional header, the file, and an optional footer, substituting into any
# templates according to definitions at the end of the input file. If the input
# file is omitted (or "-"), use standard input instead.
#
# Definition lines at the end of the input file should conform to the
# VAR_PATTERN, which is typically (though not exhaustively) what a normal shell
# variable assignment looks like. These definitions should be separated from
# the rest of the document by a non-definition line (an empty line is probably
# a good choice).
#
# Variables that are defined (and _only_ variables that are defined in the
# file, i.e. not PATH, SHELL, etc., with one exception) are substituted
# according to envsubst(1). They should generally not depend on each other,
# although this is technically possible if dependencies are placed below
# dependents. The one variable that will be substituted, even if not defined,
# is _unix_time. This contains the current UNIX time, but can be overridden if
# assigned explicitly.
#
# In order to provide a footer but no header, /dev/null can be given as the
# second argument.

readonly UNIX_TIME=$(date +%s)
# A pcrepattern(3) specifying generally how a variable assignment should look.
readonly VAR_PATTERN="[a-zA-Z_][a-zA-Z0-9_]*=(\\$\\(.*\\)|\".*\"|'.*'|\\S*)"

# If tac(1) is unavailable, use a sed(1) alternative (likely less efficient).
if ! command -v tac >/dev/null; then
	alias tac="sed -n '1!G;h;\$p'"
fi

if [ ! \( -z "$1" -o "$1" = - \) ]; then
	exec <"$1"
fi

{ printf %s\\n "_unix_time=$UNIX_TIME"; tac; } | {
	# The stdbuf(1) invocation is necessary here; otherwise sed(1) will
	# consume all of the input.
	while read -r x; do
		vars="${vars:+$vars:}\$${x%%=*}"
		eval export $x </dev/null
	done <<-END
	$(stdbuf -i0 sed -rn "/^$VAR_PATTERN$/!{x;q}; p")
	END

	# Here, tac(1) is used again to return input to the correct order.
	tac | cat ${2:+"$2"} - ${3:+"$3"} | envsubst "$vars"
}
