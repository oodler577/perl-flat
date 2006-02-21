#!/usr/bin/perl

use lib '../lib';
use FLAT::FA;
use Data::Dumper;

# my $regex = FLAT::Regex->new("abc*+[]c(d+e)");
# printf "$regex becomes %s\n", $regex->as_perl_regex;


my $fa = FLAT::FA->new;

$fa->add_state(qw[ foo bar baz ]);
$fa->set_starting("foo");

$fa->set_transition("foo", "bar", "a");
$fa->set_transition("bar", "bar", "z");
$fa->set_transition("bar", "foo", "a");
$fa->set_transition("baz", "foo", "b");
$fa->set_transition("baz", "baz", "c");

print Dumper $fa;
$fa->prune;
print Dumper $fa;

