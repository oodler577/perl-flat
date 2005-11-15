#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT;
use FLAT::Regex::WithExtraOps;
use Data::Dumper;

my $RE = FLAT::Regex::WithExtraOps->new('ab|c* & (a|b)*');

print $RE->as_string;
# print Dumper($RE);
