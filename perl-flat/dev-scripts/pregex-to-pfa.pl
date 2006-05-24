#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use Data::Dumper;
use FLAT::PFA;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PRE = FLAT::Regex::WithExtraOps->new($ARGV[0]);

my $PFA = $PRE->as_pfa();

my $dot = $PFA->as_graphviz;
my $summary = $PFA->as_summary;

print "$summary\n";

open my $fh, "|-", "dot -Tpng -o output.png"
   or die "Couldn't run dot: $!\n";

print $fh $dot;
close $fh;
