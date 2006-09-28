#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use FLAT::PFA;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PRE = FLAT::Regex::WithExtraOps->new($ARGV[0]);

my $PFA = $PRE->as_pfa();

my $graphviz = $PFA->as_graphviz;
my $summary = $PFA->as_summary;

my %TIED_BY_SRC = ();
my %TIED_BY_SNK = ();

print STDOUT $PFA->as_gdl,"\n";
print STDERR Dumper($PFA->get_tied());

#open my $fh, "|-", "dot -Tpng -o output.png"
#   or die "Couldn't run graphviz: $!\n";
#
#print $fh $graphviz;
#close $fh;

my $NFA = $PFA->as_nfa();

