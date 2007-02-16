#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;

print FLAT::Regex->new($ARGV[0])->as_nfa->as_dfa->as_min_dfa->trim_sinks->as_undirected; 
