use strict;
use warnings;
use utf8;
use Test::More;
use Scalar::Util qw(refaddr);
binmode Test::More->builder->output, ":encoding(UTF-8)";
binmode Test::More->builder->failure_output, ":encoding(UTF-8)";
use FLAT;
use FLAT::Regex::WithExtraOps;
use FLAT::Symbol::Token;
use FLAT::Symbol::Token::Scalar;

for my $text ('#','[]','0','a*','[]+ab','(a+b)*abb','a*b*','ab+ba',
              '[foo][bar]*','[#]+[+]+[ ]','[猫]*','(ab)*+b(a+b)*') {
    my $dfa=FLAT::Regex->new($text)->as_dfa;
    my $before=$dfa->clone;
    my $re=$dfa->as_regex;
    isa_ok($re,'FLAT::Regex');
    ok($dfa->equals($re->as_dfa),"exact round trip: $text");
    ok($dfa->equals(FLAT::Regex->new($re->as_string)->as_dfa),
        "formal text round trip: $text");
    is($re->as_string,$dfa->as_regex->as_string,'deterministic output');
    is_deeply($dfa,$before,'source graph unchanged');
}
is(FLAT::Regex->new('#')->as_dfa->as_regex->as_string,'#','empty language');
is(FLAT::Regex->new('[]')->as_dfa->as_regex->as_string,'[]','empty word');
is(FLAT::Regex->new('a*')->as_min_dfa->as_regex->as_string,'a*','simple loop simplified');

# Exhaust every partial two-state binary DFA, either initial state, and every
# accepting set. Each round trip uses an exact product-language comparison,
# not bounded word sampling or an expected state-elimination string.
subtest 'all 648 partial two-state binary DFAs' => sub {
    for my $code (0..80) {
        for my $start (0,1) {
            for my $mask (0..3) {
                my $dfa=FLAT::DFA->new;
                $dfa->add_states(2); $dfa->set_starting($start);
                $dfa->set_accepting(grep { $mask & (1<<$_) } 0,1);
                my $n=$code;
                for my $s (0,1) {
                    for my $key ('a','b') {
                        my $dest=$n%3; $n=int($n/3);
                        $dfa->add_transition($s,$dest,$key) if $dest<2;
                    }
                }
                ok($dfa->equals($dfa->as_regex->as_dfa),
                    "transitions=$code start=$start finals=$mask");
            }
        }
    }
};
# Three-state complete DFAs exercise several interacting elimination loops.
subtest 'three-state loop combinations' => sub {
    for my $seed (0..31) {
        my $dfa=FLAT::DFA->new; $dfa->add_states(3); $dfa->set_starting(0);
        $dfa->set_accepting(grep { ($seed+1) & (1<<$_) } 0..2);
        for my $s (0..2) {
            $dfa->add_transition($s,($s+$seed)%3,'a');
            $dfa->add_transition($s,($s*2+int($seed/3))%3,'b');
        }
        ok($dfa->equals($dfa->as_regex->as_dfa),"three-state case $seed");
    }
};

my $partial=FLAT::DFA->new; $partial->add_states(4);
$partial->set_starting(0); $partial->set_accepting(1,3);
$partial->add_transition(0,1,'a','b');
$partial->add_transition(0,2,'x'); $partial->add_transition(2,2,'x');
$partial->add_transition(3,3,'z');
is($partial->as_regex->as_string,'a+b','dead and unreachable states discarded');

my $payload={calls=>0};
my $token=FLAT::Symbol::Token->new(key=>'task]',label=>'Not expression syntax + *',payload=>$payload);
my $scalar=FLAT::Symbol::Token::Scalar->new('next');
my $dfa=FLAT::Regex->atom($token)->concat(FLAT::Regex->atom($scalar)->kleene)->as_dfa;
my $re=$dfa->as_regex;
ok($dfa->equals($re->as_dfa),'programmatic-only token key survives exact conversion');
my @atoms;
sub atoms {
    my ($node)=@_;
    if (ref($node) eq 'FLAT::Regex::Op::atomic') { push @atoms,$node }
    else { atoms($_) for $node->members }
}
atoms($re->op);
ok((grep { defined($_->symbol) && refaddr($_->symbol)==refaddr($token) } @atoms),
    'AST retains original full token object');
ok((grep { defined($_->symbol) && refaddr($_->symbol)==refaddr($scalar) } @atoms),
    'AST retains original scalar token object');
is(refaddr($re->as_nfa->symbol('task]')->payload),refaddr($payload),'payload identity survives');
ok($re->contains_tokens([$token,$scalar,$scalar]),'atomic token membership');
ok(!eval { $re->as_string; 1 },'unrepresentable key fails explicitly in text');

for my $kind ('nfa','pfa') {
    my $pre=FLAT::Regex::WithExtraOps->new('ab&cd');
    my $fa=$pre->as_pfa; $fa=$fa->as_nfa if $kind eq "nfa";
    ok($fa->as_dfa->equals($fa->as_regex->as_dfa),"$kind conversion integrates shuffle serialization");
}
my $a=FLAT::Regex->new('a+b'); my $b=FLAT::Regex->new('b+c');
ok($a->intersect($b)->equals(FLAT::Regex->new('b')),'RE intersection now returns an equivalent RE');
ok(FLAT::Regex->new('a')->complement->equals(FLAT::Regex->new('[]+aa a*')),
   'RE complement over its alphabet now returns an equivalent RE');
ok($a->difference($b)->equals(FLAT::Regex->new('a')),'RE difference works through conversion');
my $invalid=FLAT::DFA->new; $invalid->add_states(1);
ok(!eval { $invalid->as_regex; 1 },'missing starting state rejected');
like($@,qr/exactly one starting state/,'invalid graph diagnostic');
ok(!eval { $dfa->as_regex(order=>'random'); 1 },'unsupported options rejected');
like($@,qr/takes no options/,'option diagnostic');
done_testing;
