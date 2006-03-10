#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT;
use FLAT::NFA;
use FLAT::Regex;
use FLAT::Regex::WithExtraOps;
use Data::Dumper;

# This is mainly my test script for FLAT::FA::PFA.pm

my $PRE = FLAT::Regex::WithExtraOps->new('ab+c*&(a+b)*');

print $PRE->as_string;
