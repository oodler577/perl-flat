#!/usr/bin/perl

use lib '../lib';
use FLAT;

my $regex = FLAT::Regex->new("abc*+[]c(d+e)");

printf "$regex becomes %s\n", $regex->as_perl_regex;
