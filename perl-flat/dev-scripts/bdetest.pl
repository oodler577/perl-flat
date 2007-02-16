#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;

print FLAT::Regex->new('a')->as_nfa->as_dfa->as_min_dfa->as_undirected; 
