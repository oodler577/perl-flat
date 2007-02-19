#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::DFA;
use FLAT::NFA;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;

my $dfa = FLAT::Regex->new($ARGV[0])->as_nfa->as_dfa;

use Data::Dumper;
print Dumper($dfa->as_node_list);
