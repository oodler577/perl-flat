#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use FLAT::PFA;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PFA1 = FLAT::Regex::WithExtraOps->new($ARGV[0])->as_pfa();
my $PFA2 = FLAT::Regex::WithExtraOps->new($ARGV[1])->as_pfa();

my $DFA1 = $PFA1->as_nfa->as_min_dfa;
my $DFA2 = $PFA2->as_nfa->as_min_dfa;

print "Match!" if ($DFA1->equals($DFA2));

__END__
open(GDL,">pfa.gdl");
  print GDL $PFA->as_gdl,"\n";
close(GDL);

my $NFA = $PFA->as_nfa();

open(GDL,">nfa.gdl");
  print GDL $NFA->as_gdl,"\n";
close(GDL);

my $DFA = $NFA->as_dfa();

open(GDL,">dfa.gdl");
  print GDL $DFA->as_gdl,"\n";
close(GDL);

open(GDL,">mindfa.gdl");
  print GDL $DFA->as_min_dfa->trim_sinks->as_gdl,"\n";
close(GDL);

my $dot = $DFA->as_min_dfa->as_graphviz;
open my $fh, "|-", "circo -Tpng -o output.png"
   or die "Couldn't run dot: $!\n";

print $fh $dot;
close $fh;
