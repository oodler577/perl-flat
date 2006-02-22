#!/usr/bin/perl

use lib '../lib';
use FLAT::NFA;
use FLAT::Regex;
use Data::Dumper;

# my $regex = FLAT::Regex->new("abc*+[]c(d+e)");
# printf "$regex becomes %s\n", $regex->as_perl_regex;

sub foo {
    FLAT::Regex->new(shift)->as_nfa;
}


for (qw{ ab|cd|[] ab*  []* (a|b)* ([]|[])*  }) {
    my $nfa = foo($_);

    print "$_ is: ";
    print $nfa->is_finite ? "finite\n" : "infinite\n";
}

my $x = FLAT::NFA->singleton("a");
my $y = FLAT::NFA->singleton("d");

my $z = $x->clone;
$z->_swallow($y);

print Dumper $x, $y, $z;


