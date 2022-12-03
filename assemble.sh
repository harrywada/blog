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

. ./funcs.sh

# If tac(1) is unavailable, use a sed(1) alternative (likely less efficient).
if ! command -v tac >/dev/null; then
	alias tac="sed -n '1!G;h;\$p'"
fi

if [ ! \( -z "$1" -o "$1" = - \) ]; then
	exec <"$1"
fi

# Redirect standard input to an extra file descriptor so it can be read in
# tandem with standard input by subshells.
{ printf %s\\n "_unix_time=$UNIX_TIME"; tac; } | {
	# While I would _love_ to be able to do
	#
	# setvars -x <&3 | {
	# 	vars=$(printf \$%s\  $(cat) | tr \  :)
	# 	tac <&3 | cat ${2:+"$2"} - ${3:+"$3"} | envsubst "$vars"
	# }
	#
	# the subshell is created immediately and therefore the values exported
	# by setvars are not propogated to where they can be used by
	# envsubst(1). Therefore a temporary file needs to be created on disk
	# instead.

	tmp=$(mktemp --tmpdir blog_XXXXXX)
	trap "rm -f \"$tmp\"" EXIT

	setvars -x >"$tmp" <&3 || exit 1
	vars=$(printf \$%s\  $(cat "$tmp") | tr \  :)

	tac <&3 | cat ${2:+"$2"} - ${3:+"$3"} | envsubst "$vars"
} 3<&0
