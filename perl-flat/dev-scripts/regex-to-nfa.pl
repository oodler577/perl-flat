#!/usr/bin/perl
use lib '../lib';
use FLAT::Regex;
use FLAT::NFA;

@ARGV == 1
    or die "Usage: $0 regex\n -- output goes to output.png\n";

my $regex = shift;

my $dot = FLAT::Regex->new($regex)->as_nfa->as_graphviz;

open my $fh, "|-", "dot -Tpng -o output.png"
   or die "Couldn't run dot: $!\n";

print $fh $dot;
close $fh;
