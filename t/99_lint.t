#!perl

## Minor code cleanup checks

use 5.006;
use strict;
use warnings;
use Test::More;

my (@testfiles,%fileslurp,$t);

if (! $ENV{AUTHOR_TESTING}) {
	plan (skip_all =>  'Test skipped unless environment variable AUTHOR_TESTING is set');
}

my @cfiles = (qw/ dbdimp.c quote.c types.c /);


$ENV{LANG} = 'C';
opendir my $dir, 't' or die qq{Could not open directory 't': $!\n};
@testfiles = map { "t/$_" } grep { /^.+\.(t|pl)$/ } readdir $dir;
closedir $dir or die qq{Could not closedir "$dir": $!\n};

##
## Load all Test::More calls into memory
##
my $testmore = 0;
for my $file (@testfiles) {
    open my $fh, '<', $file or die qq{Could not open "$file": $!\n};
    my $line;
    while (defined($line = <$fh>)) {
        last if $line =~ /__DATA__/; ## perlcritic.t
        for my $func (qw/ok isnt pass fail cmp cmp_ok is_deeply unlike like/) { ## no skip
            next if $line !~ /\b$func\b/;
            next if $line =~ /$func \w/; ## e.g. 'skip these tests'
            next if $line =~ /[\$\%]$func/; ## e.g. $ok %ok
            $fileslurp{$file}{$.}{$func} = $line;
            $testmore++;
        }
    }
    close $fh or die qq{Could not close "$file": $!\n};
}

ok (@testfiles, 'Found files in test directory');

##
## Make sure the README.dev mentions all files used, and jives with the MANIFEST
##
my $file = 'README.dev';
open my $fh, '<', $file or die qq{Could not open "$file": $!\n};
my $point = 1;
my %devfile;
while (<$fh>) {
	chomp;
	if (1 == $point) {
		next unless /File List/;
		$point = 2;
		next;
	}
	last if /= Compiling/;
	if (m{^([\w\./-]+) \- }) {
		$devfile{$1} = $.;
		next;
	}
	if (m{^(t/.+)}) {
		$devfile{$1} = $.;
	}
}
close $fh or die qq{Could not close "$file": $!\n};

$file = 'MANIFEST';
my %manfile;
open $fh, '<', $file or die qq{Could not open "$file": $!\n};
while (<$fh>) {
	next unless /^(\S.+)/;
	$manfile{$1} = $.;
}
close $fh or die qq{Could not close "$file": $!\n};

$file = 'MANIFEST.SKIP';
open $fh, '<', $file or die qq{Could not open "$file": $!\n};
while (<$fh>) {
	next unless m{^(t/.*)};
	$manfile{$1} = $.;
}
close $fh or die qq{Could not close "$file": $!\n};

##
## Everything in MANIFEST[.SKIP] should also be in README.dev
##
for my $file (sort keys %manfile) {
	if (!exists $devfile{$file}) {
		fail qq{File "$file" is in MANIFEST but not in README.dev\n};
	}
}

##
## Everything in README.dev should also be in MANIFEST, except derived files
##
my %derived = map { $_, 1 } qw/Makefile Pg.c README.testdatabase dbdpg_test_database/;
for my $file (sort keys %devfile) {
	if (!exists $manfile{$file} and !exists $derived{$file}) {
		fail qq{File "$file" is in README.dev but not in MANIFEST\n};
	}
	if (exists $manfile{$file} and exists $derived{$file}) {
		fail qq{File "$file" is derived and should not be in MANIFEST\n};
	}
}

##
## Make sure all Test::More function calls are standardized
##
for my $file (sort keys %fileslurp) {
	for my $linenum (sort {$a <=> $b} keys %{$fileslurp{$file}}) {
		for my $func (sort keys %{$fileslurp{$file}{$linenum}}) {
			$t=qq{Test::More method "$func" is in standard format inside $file at line $linenum};
            my $line = $fileslurp{$file}{$linenum}{$func};
			## Must be at start of line (optional whitespace and comment), a space, a paren, and something interesting
            next if $line =~ /\w+ fail/;
            next if $line =~ /defined \$expected \? like/;
			like ($line, qr{^\s*#?$func \(['\S]}, $t);
		}
	}
}

##
## Check C files for consistent whitespace
##
for my $file (@cfiles) {
    my $tabfail = 0;
    open my $fh, '<', $file or die "Could not open $file: $!\n";
    my $inquote = 0;
    while (<$fh>) {
        if ($inquote) {
            if (m{^\Q*/}) {
                $inquote = 0;
            }
            next;
        }
        if (m{^\Q/*}) {
            $inquote = 1;
            next;
        }

        ## Special exception for types.c:
        next if $file eq 'types.c' and /^ \{/;

        $tabfail++ if /^ /;
        warn $_ if /^ /;
    }
    close $fh;
    if ($tabfail) {
        fail (qq{File "$file" contains leading tabs, not spaces: $tabfail});
    }
    else {
        pass (qq{File "$file" has no leading spaces});
    }
}


done_testing();
