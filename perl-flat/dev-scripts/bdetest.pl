#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::DFA;
use FLAT::NFA;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;

my $dfa = FLAT::Regex->new($ARGV[0])->as_nfa->as_dfa;
if ($dfa->is_valid($ARGV[1])) {
  print "valid" 
} else {
  print "not valid" 
}
