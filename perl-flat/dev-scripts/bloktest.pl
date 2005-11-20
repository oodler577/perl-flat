#!/usr/bin/perl

use lib '../lib';
use FLAT::FA;
use Data::Dumper;

# my $regex = FLAT::Regex->new("abc*+[]c(d+e)");
# printf "$regex becomes %s\n", $regex->as_perl_regex;


my $fa = FLAT::FA->new;

$fa->add_state("foo");
print Dumper $fa;

$fa->add_state("bar");
print Dumper $fa;

$fa->set_transition("foo", "bar", "q");
$fa->set_transition("bar", "bar", "z");
$fa->set_transition("bar", "foo", "a");
print Dumper $fa;

print Dumper [ $fa->successors("bar") ];


$fa->delete_state("foo");
print Dumper $fa;

