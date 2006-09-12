#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use Data::Dumper;
use FLAT::PFA;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PRE = FLAT::Regex::WithExtraOps->new($ARGV[0]);

my $PFA = $PRE->as_pfa();

my $graphviz = $PFA->as_graphviz;
my $summary = $PFA->as_summary;

print "$summary\n";

open my $fh, "|-", "circo -Tpng -o output.png"
   or die "Couldn't run graphviz: $!\n";

print $fh $graphviz;
close $fh;

my $NFA = $PFA->as_nfa();
print Dumper($NFA);
