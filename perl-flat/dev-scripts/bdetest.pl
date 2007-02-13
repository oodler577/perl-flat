#!/usr/bin/env perl -l
use strict;

use lib qw(../lib);
use FLAT::Regex::Transform;
use Data::Dumper;

my $trans = FLAT::Regex::Transform->new('abc&efg+hi'); 
print Dumper($trans);
