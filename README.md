# gensched

A small tool for generating schedule files suitable for use with `pg_regress`
based on the options passed to autoconf in the `./configure` step.

## Usage

The input schedule files are `.in` files which can be conveniently processed at
`make all` into schedules with the supported testsuites kept as `test:` rows
and the ones with unresolved dependencies moved to `ignore:` rows. Dependencies
are set per test by suffixing the testname with a list in parenthesis:

	test: aaa bbb(foo bar) ccc(foo)

Here, test aaa has no dependencies, bbb depends on `--with-foo` and `--with-bar`
and ccc depends on `--with-foo`.  The exact names of the dependencies aren’t
limited to the featurename as they are set in autoconf but it’s probably a good
idea to maintain the name.  In the example above the following sequence would
not cause bbb to be marked as FAILED as it would simply not be executed at all:

	./configure --with-foo
	make install
	make -C gpAux/gpdemo cluster
	make installcheck-good

`gensched.pl` takes the dependencies set in autoconf as parameters, reads the
`.in` file on STDIN and outputs the resulting schedule on STDOUT.


Resolves configured dependencies on test definitions in schedule files
based on the dependencies passed as command line parameters and outputs
a schedule file for use with `pg_regress`. Reads STDIN and outputs onto
STDOUT for file generation.

	./gensched.pl --dependency foo,bar < input > output

## Autoconf integration

The easiest way to set up the dependencies for `gensched.pl` in autoconf is
to continually build up the commandline as the features are handled:

	if test "$with_foo" = yes; then
		...
		ICG_DEPENDENCIES="--dependency libxml "$ICG_DEPENDENCIES
	fi

At the end of the configure script, pass the depedencies to a variable with
`AC_SUBST(ICG_DEPENDENCIES)`. The Makefile rule for generating the schedule
file is:

	%_schedule: %_schedule.in
		./gensched.pl $(ICG_DEPENDENCIES) < $< > $@
