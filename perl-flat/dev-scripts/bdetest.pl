#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::DFA;
use FLAT::NFA;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;

my $dfa = FLAT::Regex::WithExtraOps->new($ARGV[0])->as_pfa->as_nfa->as_dfa;

use Data::Dumper;
$Data::Dumper::Deepcopy = 1;

#print Dumper($dfa->as_node_list);

my $tree = $dfa->as_depth_first_tree();
#print Dumper($tree);
