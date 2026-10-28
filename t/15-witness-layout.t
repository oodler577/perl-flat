use strict;
use warnings;
use utf8;
use Test::More;
use Storable qw(freeze);
use FLAT;
use FLAT::Regex;
use FLAT::NFA;
use FLAT::CLI;
use FLAT::JFLAP;
use XML::LibXML;
sub dfa { FLAT::Regex->new($_[0])->as_nfa->as_dfa }
for my $l ('#','[]','0','a','a*','a+b','ab','a*b*') {
    for my $r ('#','[]','0','a','a*','a+b','ab','a*b*') {
        my ($a,$b) = (dfa($l), dfa($r));
        for my $subset (0,1) {
            my $method = $subset ? 'subset_counterexample' : 'equivalence_counterexample';
            my $w = $a->$method($b);
            my $holds = $subset ? $a->is_subset_of($b) : $a->equals($b);
            is(!defined($w), !!$holds, "$method $l / $r agrees with relation");
            next unless defined $w;
            my $word = join '', @{$w->{tokens}};
            my @shorter=('');
            my $minimal=1;
            for (my $n=0; $n < @{$w->{tokens}}; ++$n) {
                for my $short (@shorter) {
                    my ($la,$ra)=($a->contains($short),$b->contains($short));
                    $minimal=0 if $subset ? ($la && !$ra) : (!!$la != !!$ra);
                }
                @shorter=map { my $prefix=$_; map { $prefix.$_ } qw(0 a b) } @shorter;
            }
            ok($minimal,'no shorter word disproves relation');
            is(!!$a->contains($word), !!$w->{left_accepts}, 'left acceptance verified');
            is(!!$b->contains($word), !!$w->{right_accepts}, 'right acceptance verified');
            ok($subset ? $w->{left_accepts} && !$w->{right_accepts} : $w->{left_accepts} != $w->{right_accepts}, 'word disproves relation');
        }
    }
}
is_deeply(dfa('[]')->equivalence_counterexample(dfa('#'))->{tokens}, [], 'empty word witness');
is_deeply(dfa('b+a')->equivalence_counterexample(dfa('#'))->{tokens}, ['a'], 'stable shortest tie');
my $token = FLAT::NFA->singleton('open')->as_dfa;
is_deeply($token->subset_counterexample(dfa('#'))->{tokens}, ['open'], 'multi-character token stays intact');
my $unicode = FLAT::NFA->singleton('猫')->as_dfa;
is_deeply($unicode->equivalence_counterexample(dfa('#'))->{tokens}, ['猫'], 'Unicode token stays intact');
my $a=dfa('a'); my $b=dfa('b');
my ($before_a,$before_b) = (freeze($a),freeze($b));
$a->equivalence_counterexample($b);
is(freeze($a),$before_a,'left input unchanged'); is(freeze($b),$before_b,'right input unchanged');
# Check the layerer on cycles, unreachable states and synthetic token states.
my $nfa=FLAT::NFA->singleton('ab');
my $dead=$nfa->add_states(1);
$nfa->{STATES}[0]{jflap_x}=999;
my $before=freeze($nfa);
my $xml=$nfa->as_jflap(expand_labels=>1,layout=>'layered');
is(freeze($nfa),$before,'layout does not mutate input');
my $doc=XML::LibXML->load_xml(string=>$xml);
is($doc->findvalue('//state[@id="0"]/x'),100,'initial state in first column');
my %positions;
for my $state ($doc->findnodes('//state')) {
    my $xy=join ',', map { $state->findvalue($_) } qw(x y);
    ok(!$positions{$xy}++, 'all exported states have distinct positions');
}
ok(FLAT::JFLAP->from_string($xml)->contains('ab'),'expanded path survives layout');
is($nfa->as_jflap(expand_labels=>1,layout=>'layered'),$xml,'layout is deterministic');
like($nfa->as_jflap(expand_labels=>1),qr/<x>999<\/x>/,'default preserves positions');
for my $expr ('a*','[]','#','ab+ba') {
    my $fa=dfa($expr);
    ok($fa->equals(FLAT::JFLAP->from_string($fa->as_jflap(layout=>'layered'))->as_dfa), "layout preserves $expr");
}
my $error=eval { $nfa->as_jflap(layout=>'unknown'); 1 }; ok(!$error,'unknown layout rejected');
my $meta=FLAT::CLI->completion_metadata;
ok(grep($_ eq '--witness', @{$meta->{options}{compare}}),'comparison completion includes witness');
ok(grep($_ eq '--layout', @{$meta->{options}{dfa2jflap}}),'JFLAP alias completion includes layout');
ok(!grep($_ eq '--layout', @{$meta->{options}{dfa2gv}}),'DOT alias excludes JFLAP layout');
is_deeply($meta->{values}{'--layout'},[qw(preserve layered)],'layout values complete');
for my $kind (qw(legacy nested)) {
    my $fa=FLAT::JFLAP->from_file("t/data/jflap-synthetic-$kind.jff");
    ok($fa->contains('ab猫猫'), "$kind fixture accepts character path and Unicode loop");
    ok(!$fa->contains('a'), "$kind fixture rejects incomplete path");
    for my $layout (qw(preserve layered)) {
        my $back=FLAT::JFLAP->from_string($fa->as_jflap(layout=>$layout));
        ok($fa->as_dfa->equals($back->as_dfa), "$kind $layout roundtrip equivalent");
    }
}
done_testing;
