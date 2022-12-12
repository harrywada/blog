# A pcrepattern(3) specifying generally how a variable assignment should look.
readonly VAR_PATTERN=[a-zA-Z_][a-zA-Z0-9_]\*
readonly DECL_PATTERN="$VAR_PATTERN=(\\$\\(.*\\)|\".*\"|'.*'|\\S*)"

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
	local err=0 val

	while read -r x; do
		if [ -z "$x" ]; then continue; fi

		local var=${x%=*}
		local rhs=${x#*=}

		# This is pretty ugly, but is necessary to keep dependent
		# variables working correctly. Since variable expansions are
		# temporarily stored in ..._val local variables, these need to
		# be searched and replaced in advance.
		rhs=$(printf %s "$rhs" \
		    | sed -r "s/(^|[^\\\\\\])(\\\$$VAR_PATTERN)/\\1\\2_val/g")

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
