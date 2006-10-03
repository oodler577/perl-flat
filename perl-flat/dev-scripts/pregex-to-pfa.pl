#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use FLAT::PFA;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PFA = FLAT::Regex::WithExtraOps->new($ARGV[0])->as_pfa();

open(GDL,">pfa.gdl");
  print GDL $PFA->as_gdl,"\n";
close(GDL);

my $NFA = $PFA->as_nfa();

open(GDL,">nfa.gdl");
  print GDL $NFA->as_gdl,"\n";
close(GDL);
