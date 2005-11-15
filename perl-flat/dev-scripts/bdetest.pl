#!/usr/bin/env perl
use strict;

use lib qw(../lib);
use FLAT;
use Data::Dumper;

my $RE = FLAT::Regex->new('ab|c*');

print Dumper($RE);
