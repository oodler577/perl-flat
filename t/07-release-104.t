use strict;
use warnings;
use Test::More;
use FLAT;

for my $char (split //, '%@;:-^') {
    my $dfa = FLAT::Regex->new($char)->as_dfa;
    ok($dfa->contains($char), "1.0.3 parser accepts $char");
}

my $dfa = FLAT::Regex->new('[foo][bar]')->as_dfa;
is($dfa->new_acyclic_string_generator('|')->(), 'foo|bar',
   '1.0.4 acyclic generator delimiter');
is($dfa->new_deepdft_string_generator(1, '|')->(), 'foo|bar',
   '1.0.4 depth-first generator delimiter');
is($dfa->new_deepdft_string_generator()->(), 'foobar',
   'default depth and delimiter remain supported');
done_testing;
