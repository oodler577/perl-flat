#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::WithExtraOps;
use Data::Dumper;
use FLAT::PFA;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PRE = FLAT::Regex::WithExtraOps->new('(a&b&c)*([cat]&[dog])');

my $PFA = $PRE->as_pfa();

print Dumper($PFA);
