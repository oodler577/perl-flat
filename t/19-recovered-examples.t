use strict;
use warnings;
use Test::More;
use JSON::PP;
use FLAT;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;

open my $fh,'<','t/data/recovered-language-cases.json' or die $!;
local $/; my $data=decode_json(<$fh>);
for my $case (@{$data->{cases}}) {
    my $dfa=FLAT::Regex::WithExtraOps->new($case->{expression})->as_pfa->as_nfa->as_dfa;
    my $reference=FLAT::Regex->new($case->{reference})->as_nfa->as_dfa;
    ok($dfa->equals($reference),"$case->{id}: exact independent language equivalence");
    ok($dfa->contains($_),"$case->{id}: accepts <$_>") for @{$case->{accept}};
    ok(!$dfa->contains($_),"$case->{id}: rejects <$_>") for @{$case->{reject}};
}
# Current semantics apply even when revisiting historical work.
my $modern=FLAT::Regex::WithExtraOps->new('0|1&0')->as_pfa->as_nfa->as_dfa;
my $expected=FLAT::Regex->new('0+10+01')->as_nfa->as_dfa;
ok($modern->equals($expected),'historical mixed operators use modern precedence');
done_testing;
