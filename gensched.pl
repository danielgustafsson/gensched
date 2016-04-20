#!/usr/bin/perl -w
#
# gensched.pl
#		Utility to generate pg_regress schedules based on dependencies
#
# Portions Copyright (c) 2016, Pivotal
# Portions Copyright (c) 2016, Daniel Gustafsson <daniel@yesql.se>
# 
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose, without fee, and without a written agreement
# is hereby granted, provided that the above copyright notice and this
# paragraph and the following two paragraphs appear in all copies.
#
# IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
# LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
# DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
# ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATIONS TO
# PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.

use Getopt::Long;
use strict;

my @dependencies = ();
my %dependencies;

GetOptions('dependency=s' => \@dependencies, 'usage|help' => \&usage);
@dependencies = split(/,/, join(',', @dependencies));
$dependencies{$_}++ for (@dependencies);

sub usage
{
	print "$0 [--dependency X,Y..,Z] < input_file > output_file\n";
	exit 1;
}

while (<>)
{
	# Preserve comments and blank lines in the output
	if (/^\s*(#.*)?$/)
	{
		print;
		next;
	}

	# Resolve dependencies in both test and ignore blocks as we want the output
	# schedule to be free from all dependency information
	if (/^\s*(test|ignore)\s*:\s*(.+){1}$/)
	{
		my @input = ();
		my @ignore = ();
		my @tests = ();
		my $header = $1;
		my $test_row = $2;

		# We can't just split the line of tests on whitespace since we need to
		# support all the following constructs: test test(foo) test(foo, bar)
		# test(foo,bar)
		push(@input, $&)
			while ($test_row =~ /([^(\s]+(\([^)\s,]+(\s*,\s*[^)\s,]+)*\))?)/g);

T_LOOP:	foreach my $t (@input)
		{
			# Only look at tests with dependencies, other tests can be output
			# immediately
			if ($t =~ /.+\)$/)
			{
				# For tests with dependencies, resolve against the passed set of
				# available dependencies and output test with satisfied
				# dependencies as test, else into an ignore block.
				$t =~ /([^(]+)\(([^)]+)\)/;
				$t = $1;
				my @deps = split(/,\s*/, $2);

				foreach my $d (@deps)
				{
					push(@ignore, $t) && next T_LOOP
						unless defined($dependencies{$d});
				}
			}
			push(@tests, $t);
		}
		# Output the tests that satisfy all the dependencies (if any)
		print $header . ": " . join(" ", @tests) . "\n" unless !scalar(@tests);
		if (scalar(@ignore) > 0)
		{
			print "# Tests ignored due to dependencies not fulfilled\n";
			print "ignore: " . join(" ", @ignore) . "\n";
		}
	}
}

exit 0;
__END__
