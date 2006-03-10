#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PRE = FLAT::Regex::WithExtraOps->new('(ab+c*)&(a+b)*');

my $PFA = $PRE->as_pfa();

my $NFA = $PFA->as_nfa();

my $DFA = $NFA->as_dfa();

my $DFA_min = $DFA->as_min_dfa();

print $PRE->as_string;
