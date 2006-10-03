#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT;
use FLAT::NFA;
use FLAT::Regex;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

my $DFA = FLAT::Regex->new('ab+ba')->as_nfa->as_min_dfa;

print $DFA->as_gdl;
