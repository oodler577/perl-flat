#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT;
use FLAT::NFA;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

#my $DFA = FLAT::Regex->new('ab+ba')->as_nfa->as_min_dfa;
#print $DFA->as_gdl;

my $PFA1 = FLAT::Regex::WithExtraOps->new('(abc)*dx&(efg)*hy')->as_pfa(); #<--!
my $PFA2 = FLAT::Regex::WithExtraOps->new('(abc+efg)*(
                                                      dx&(efg)*hy+
                                                      hy&(abc)*dx+
                                                      a(((bca)*bcdx)&((efg)*hy))+
                                                      a(((bca)*)&((efg)*hy))bcdx+
                                                      e(((fge)*fghy)&((abc)*dx))+
                                                      e(((fge)*)&((abc)*dx))fghy
                                                     )')->as_pfa();

my $DFA1 = $PFA1->as_nfa->as_min_dfa;
my $DFA2 = $PFA2->as_nfa->as_min_dfa;

print $DFA1->equals($DFA2);
