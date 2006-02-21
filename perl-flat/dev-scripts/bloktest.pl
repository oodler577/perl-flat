#!/usr/bin/perl

use lib '../lib';
use FLAT::FA;
use Data::Dumper;

# my $regex = FLAT::Regex->new("abc*+[]c(d+e)");
# printf "$regex becomes %s\n", $regex->as_perl_regex;


my $fa = FLAT::FA->new;

$fa->add_states(3);
$fa->set_starting(0);

$fa->set_transition(0, 1, "a");
$fa->set_transition(1, 1, "z");
$fa->set_transition(1, 0, "a");
$fa->set_transition(2, 0, "b");
$fa->set_transition(2, 2, "c");

print Dumper $fa;
$fa->prune;
print Dumper $fa;

