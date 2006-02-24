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


for (qw{ ab|cd|[] ab*  []* (a|b)* ([]|[])* }, "#*", "###") {
    my $nfa = foo($_);

    print "$_ is: ";
    print $nfa->is_finite ? "finite, " : "infinite, ";
    print $nfa->is_empty ? "empty, " : "nonempty, ";
    print "alphabet = ", $nfa->alphabet, "\n";
}

#######

my $nfa = foo("ab(c|d)*e");

for (qw[ abe abce abcdcdcdcde bcde be abcd ab ]) {
    printf "$_ in the language? %s\n",
       $nfa->contains($_) ? "yes!" : "no";
    my @t = $nfa->trace($_);

    print "[@$_] " for @t;
    print $/;
}
