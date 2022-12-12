#!/bin/sh

# A pcrepattern(3) specifying generally how a variable assignment should look.
readonly VAR_PATTERN=[a-zA-Z_][a-zA-Z0-9_]\*
readonly DECL_PATTERN="$VAR_PATTERN=(\\$\\(.*\\)|\".*\"|'.*'|\\S*)"

# These variables are provided for convenience in writing templates.
export readonly ARTICLES=$(find articles/ -type f)

# Template the first path argument (or standard input if empty or "-") by
# running setvars (defined below) on the tail end of it, and then using
# envsubst(1) to replace all shell-like expansions in the rest of it. Second
# and third arguments may be provided as paths to header and footer files
# respectively, which are templated using the first argument's variables as
# well.
#
# The -e flag can be provided to incorporate variables in the current
# environment into the substitution as well. Any variables
template() {
	local readonly UNIX_TIME=$(date +%s)
	local envs=

	while [ -n "$1" ]; do
		case "$1" in
		-e)
			if [ -z "$2" ]; then
				printf >&2 "A variable name must be provided\n"
				exit 1
			fi

			# Any xtemplate calls within this template can't tell
			# between -e variables and ones previously read from
			# the template, so we should treat these as ..._val
			# variables as well.
			eval export -- $2\_val=$2 || exit 1
			local envs=$envs\ $2
			shift; shift
			;;
		*) break ;;
		esac
	done

	# If tac(1) is unavailable, use a sed(1) alternative (likely less
	# efficient).
	if ! command -v tac >/dev/null; then
		alias tac="sed -n '1!G;h;\$p'"
	fi

	if [ ! \( -z "$1" -o "$1" = - \) ]; then
		exec <"$1"
	fi

	{ printf %s\\n "_unix_time=${_unix_time:-$UNIX_TIME}"; tac; } | {
		setvars -x -v <&3 >/dev/null || return 1
		export vars=$(for v in $VARS $envs; do printf \$%s: $v; done)

		tac <&3 | cat ${2:+"$2"} - ${3:+"$3"} | envsubst "$vars"
	} 3<&0
	# Redirect standard input to an extra file descriptor so it can be read
	# in tandem with standard input by subshells.

	unalias tac 2>/dev/null
	return 0
}

# Cross-template: use the second file's variables to fill a template in the
# first file. This is intended to be used as a helper function in templates.
#
# The -e flag can be used, like in the normal template function, to include
# additional variables from the current environment.
xtemplate() {
	local envs=

	while [ -n "$1" ]; do
		case "$1" in
		-e)
			if [ -z "$2" ]; then
				printf >&2 "A variable name must be provided\n"
				exit 1
			fi

			# Since this can only be used within a template, it's
			# probably referring to another variable in the
			# template, which at this point has been stored in a
			# local ..._val variable. 
			eval export -- $2=\$$2\_val || exit 1
			local envs=$envs\ $2
			shift; shift
			;;
		*) break ;;
		esac
	done

	if [ $# -ne 2 ]; then
		printf >&2 "Exactly two files must be given to xtemplate\n"
		return 1
	fi

	tac "$2" | {
		setvars -x -v >/dev/null
		template $(for v in $VARS; do printf -- -e\ %s\  "$v"; done) \
		         $(for v in $envs; do printf -- -e\ %s\  "$v"; done) \
		         "$1"
	 }
}

# Read and execute variable declarations from standard input. If any shell
# operations fail, none of the variables are set and an all errors are
# reported.
#
# Any arguments provided (other than the -x and -v flags) are regarded as an
# exclusive list of variables which should be recognized. As such, extraneous
# declarations will not be executed and any potential errors that would result
# from them are not reported.
#
# Once standard input is closed or a non-matching line is read, processing ends
# and all variables names that were set are printed to standard output.
#
# If the -x flag is set, then variables are also exported.
#
# If the -v flag is set, then the list of variables that were set as a result
# of the function are also stored into a VARS variable as well as being
# printed.
setvars() {
	while [ -n "$1" ]; do
		case "$1" in
		-x) local export_vars=1;     shift ;;
		-v) local store_varnames=1;  shift ;;
		*) break ;;
		esac
	done

	local joined_vars=$(printf \|%s $*)
	local joined_vars=${joined_vars#|}
	local err=0 vars= val

	while read -r x; do
		if [ -z "$x" ]; then continue; fi

		local var=${x%=*}
		local rhs=${x#*=}

		# This is pretty ugly, but is necessary to keep dependent
		# variables working correctly. Since variable expansions are
		# temporarily stored in ..._val local variables, these need to
		# be searched and replaced in advance. Only use existing
		# variables to not interfere with things like for-loops.
		local join=$(printf %s\  $vars | tr \  \|)
		rhs=$(printf %s "$rhs" \
		    | sed -r "s/(^|[^\\\\\\])(\\\$(${join%|}))/\\1\\2_val/g")

		eval val=$rhs </dev/null
		if [ $? -ne 0 ]; then
			printf >&2 "Evaluated \$%s to a non-zero status\n" $var
			local err=$(( $err + 1 ))
			continue
		fi

		eval local $var\_val=\$val
		local vars="$vars $var"
	done <<-END
	$(stdbuf -i0 sed -rn -e "/^$DECL_PATTERN$/!{x;q};" \
	                     -e "/^(${joined_vars:-.+})=/p")
	END
	# The stdbuf(1) invocation above is necessary to prevent consuming the
	# rest of the input.

	if [ $err -lt 1 -a -n "$vars" ]; then
		for v in $vars; do
			eval ${export_vars+export --} $v=\$$v\_val
		done

		if [ -n "${store_varnames+1}" ]; then
			VARS=${vars# }
		fi

		printf %s\\n $vars
	fi

	return $err
}

template $*
