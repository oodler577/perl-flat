use strict;
use warnings;
use utf8;
use Test::More;
use Scalar::Util qw(refaddr weaken);
use FLAT::Symbol::Token;
use FLAT::Symbol::Token::Scalar;
use FLAT::PFA;
use FLAT::DFA::Hyper;
use FLAT::Regex::WithExtraOps;
use FLAT::Transition::Simple;

my $payload={count=>0};
my $a=FLAT::Symbol::Token->new(key=>'open', label=>'Open file', payload=>$payload);
my $b=FLAT::Symbol::Token->new(key=>'close',label=>'Close file',payload=>$payload);
is("$a",'Open file','interpolation uses display label');
is(sprintf('%s',$a),'Open file','sprintf uses display label');
my $printed=''; open my $fh,'>',\$printed or die $!; print $fh $a; close $fh;
is($printed,'Open file','print uses display label');
my $assigned=$a;
is(refaddr($assigned),refaddr($a),'assignment preserves symbol reference');
is($a->key,'open','matching key distinct from display');
is(refaddr($a->payload),refaddr($payload),'original payload reference');
ok(!eval { $a->{KEY}='changed'; 1 },'key immutable');
ok(!eval { $a->{LABEL}='changed'; 1 },'label immutable');
ok(!eval { $a->{PAYLOAD}={}; 1 },'payload binding immutable');
$a->payload->{count}++;
is($payload->{count},1,'payload referent remains mutable');
for my $label ('','0','猫') {
    my $s=FLAT::Symbol::Token->new(key=>'event',label=>$label);
    ok($s,'symbol true regardless of label');
    is("$s",$label,'empty, zero and Unicode display preserved');
    my $fa=FLAT::PFA->singleton($s);
    ok($fa->contains_tokens([$s]),'singleton consumes key despite display');
    ok(!$fa->contains_tokens([]),'empty display is not epsilon');
    ok(!$fa->kleene->is_finite,'empty display still denotes consuming cycle');
}
my $nfa=FLAT::NFA->singleton($a);
is_deeply([$nfa->alphabet],['open'],'alphabet remains string keys');
is(refaddr($nfa->symbol('open')),refaddr($a),'lookup returns original object');
is(refaddr($nfa->symbol($a)),refaddr($a),'lookup accepts symbol');
is_deeply([map { $_->key } $nfa->symbols],['open'],'active symbols accessor');
my ($start)=$nfa->get_starting;
is_deeply([$nfa->successors($start,$a)],[1],'successors accepts object key');
ok($nfa->get_transition(0,1)->does($a),'transition membership uses key');
is_deeply([$nfa->get_valid_symbols([$a,$b])],['open'],'valid-symbol query uses keys');
ok($nfa->contains_tokens(['open']),'bare key matches symbol');
ok(!$nfa->contains_tokens(['Open file']),'display text is not matching identity');
ok(!$nfa->contains_tokens(['o','p','e','n']),'multi-character key is atomic');
my $legacy=FLAT::Regex->new('ab')->as_nfa;
ok($legacy->contains('ab'),'legacy character input unchanged');
ok($legacy->contains_tokens(['a','b']),'legacy token input');
is_deeply([map { "$_" } $legacy->symbols],[qw(a b)],'legacy symbols display their keys');
is($legacy->symbol('missing'),undef,'missing lookup returns undef');
my $clone=$nfa->clone;
isnt(refaddr($clone->{STATES}),refaddr($nfa->{STATES}),'clone copies graph structure');
is(refaddr($clone->symbol('open')),refaddr($a),'clone shares immutable symbol');
is(refaddr($clone->symbol('open')->payload),refaddr($payload),'clone shares payload');
$clone->remove_transition(0,1);
ok($nfa->contains_tokens([$a]),'clone graph edits isolated');
is_deeply([$clone->symbols],[],'symbols lists only active keys');
is(refaddr($clone->symbol('open')),refaddr($a),'inactive binding can be reused');

my $pfa=FLAT::PFA->singleton($a)->shuffle(FLAT::PFA->singleton($b));
my @graphs=(['PFA shuffle',$pfa],['PFA to NFA',$pfa->as_nfa],
 ['determinize',$pfa->as_dfa],['minimize',$pfa->as_min_dfa],
 ['hypermin',$pfa->as_dfa->as_hyper_min_dfa],
 ['union',$nfa->union(FLAT::NFA->singleton($b))],
 ['concat',$nfa->concat(FLAT::NFA->singleton($b))],
 ['star',$nfa->kleene],['reverse',$nfa->reverse],
 ['DFA union',$nfa->as_dfa->union(FLAT::NFA->singleton($b))],
 ['DFA concat',$nfa->as_dfa->concat(FLAT::NFA->singleton($b))],
 ['DFA reverse',$nfa->as_dfa->reverse],
 ['DFA star',$nfa->as_dfa->kleene],
 ['complement',$nfa->as_dfa->complement],
 ['intersection',$pfa->as_dfa->intersect($pfa->as_dfa)],
 ['difference',$pfa->as_dfa->difference($nfa->as_dfa)],
 ['symdiff',$pfa->as_dfa->symdiff($nfa->as_dfa)],
 ['trim',$pfa->as_dfa->trim_sinks]);
for my $entry (@graphs) {
    my ($name,$graph)=@$entry;
    is(refaddr($graph->symbol('open')),refaddr($a),"$name retains symbol identity");
    is(refaddr($graph->symbol('open')->payload),refaddr($payload),"$name retains payload identity");
}
ok($pfa->as_dfa->contains_tokens([$a,$b]),'shuffle accepts first order');
ok($pfa->as_min_dfa->contains_tokens([$b,$a]),'shuffle accepts other order after minimization');
$payload->{count}=42;
is($_->[1]->symbol('open')->payload->{count},42,"$_->[0] sees payload changes") for @graphs;
# Payloads with cycles, aliases and code refs must never be passed to dclone.
my $cycle={}; $cycle->{self}=$cycle;
my $callback=sub { 17 };
for my $data ($cycle,$callback,[$payload,$payload],\(my $scalar=7)) {
    my $symbol=FLAT::Symbol::Token->new(key=>'x',payload=>$data);
    my $out=FLAT::PFA->singleton($symbol)->as_nfa->as_dfa->as_min_dfa->clone;
    is(refaddr($out->symbol('x')->payload),refaddr($data),'arbitrary payload reference survives pipeline');
}
delete $cycle->{self};
# Equal display labels must not cause distinct matching keys to collapse.
my $same_label=FLAT::Symbol::Token->new(key=>'other',label=>'Open file',payload=>$payload);
my $u=$nfa->union(FLAT::NFA->singleton($same_label))->as_dfa;
is_deeply([sort $u->alphabet],[qw(open other)],'equal display labels retain distinct keys');
ok($u->contains_tokens([$a]) && $u->contains_tokens([$same_label]),'both identities match');
ok($nfa->as_dfa->intersect(FLAT::NFA->singleton($same_label))->is_empty,'different keys do not intersect');
my $compatible=FLAT::Symbol::Token->new(key=>'open',label=>'Open file',payload=>$payload);
my $joined=$nfa->union(FLAT::NFA->singleton($compatible));
is(refaddr($joined->symbol('open')),refaddr($a),'compatible repeated key retains first binding');
for my $conflict (
 FLAT::Symbol::Token->new(key=>'open',label=>'Different',payload=>$payload),
 FLAT::Symbol::Token->new(key=>'open',label=>'Open file',payload=>{count=>42}),
 FLAT::Symbol::Token->new(key=>'open',label=>'Open file')) {
    ok(!eval { $nfa->union(FLAT::NFA->singleton($conflict)); 1 },'conflicting key rejected on merge');
    like($@,qr/conflicting symbol binding/,'collision explained');
    ok(!eval { $nfa->set_transition(0,1,$b,$conflict); 1 },'conflicting transition rejected');
    is_deeply([$nfa->alphabet],['open'],'failed transition leaves alphabet unchanged');
    ok($nfa->contains_tokens([$a]),'failed transition leaves old edge intact');
    is($nfa->symbol('close'),undef,'failed registration is atomic');
}
# Bind symbols after compiling an ordinary formal expression by matching keys.
my $bound=FLAT::Regex::WithExtraOps->new('[open]&[close]')->as_pfa->register_symbols($a,$b)->as_nfa->as_dfa;
ok($bound->contains_tokens([$a,$b]),'expression-bound keys use symbol API');
is(refaddr($bound->symbol('close')->payload),refaddr($payload),'expression conversion retains shared binding');
my $zero=FLAT::Symbol::Token->new(key=>'0',label=>'Zero');
ok(FLAT::NFA->singleton($zero)->contains_tokens([$zero]),'zero key preserved');
for my $args ([key=>''],[key=>'#lambda'],[key=>{}],[key=>'a',label=>undef],[key=>'a',payload=>'text'],[key=>'a',unknown=>1]) {
    ok(!eval { FLAT::Symbol::Token->new(@$args); 1 },'invalid symbol rejected');
}
for my $bad ({}, [], sub {}) {
    ok(!eval { FLAT::NFA->singleton($bad); 1 },'bare reference not silently stringified');
}
for my $bad (undef,'a',[''],[undef],[{}]) {
    ok(!eval { $nfa->contains_tokens($bad); 1 },'invalid token sequence rejected');
}
my $edge=FLAT::Transition::Simple->new($a);
is_deeply([$edge->alphabet],['open'],'direct transition uses key');
$edge->add($b); ok($edge->does($b),'direct transition add uses key');
$edge->delete($a); ok(!$edge->does($a),'direct transition delete uses key');
my $light=FLAT::Symbol::Token::Scalar->new('light');
isa_ok($light,'FLAT::Symbol::Token');
is(Scalar::Util::reftype($light),'SCALAR','light token backed by scalar');
is("$light",'light','scalar token stringification');
is($light->key,'light','scalar token key');
is($light->payload,undef,'scalar token has no payload');
ok(!eval { $$light='changed'; 1 },'scalar key is immutable');
my $mixed=FLAT::PFA->singleton($light)->concat(FLAT::PFA->singleton($a))->as_dfa->as_min_dfa;
ok($mixed->contains_tokens([$light,$a]),'scalar/full token mixture matches');
is(refaddr($mixed->symbol('light')),refaddr($light),'light object identity preserved');
is(refaddr($mixed->symbol('open')->payload),refaddr($payload),'mixed full payload retained');
my $lightzero=FLAT::Symbol::Token::Scalar->new('0');
ok($lightzero,'scalar zero token is true');
ok(FLAT::NFA->singleton($lightzero)->contains_tokens([$lightzero]),'scalar zero token consumes');
my $full_light=FLAT::Symbol::Token->new(key=>'light');
my $light_union=FLAT::NFA->singleton($light)->union(FLAT::NFA->singleton($full_light));
is(refaddr($light_union->symbol('light')),refaddr($light),'scalar/full compatible key keeps first binding');
ok(!exists $legacy->{SYMBOLS},'legacy graph does not allocate explicit registry');
for my $bad ('','#lambda',undef,{},[]) {
    ok(!eval { FLAT::Symbol::Token::Scalar->new($bad); 1 },'invalid scalar token rejected');
}
my $weak;
{
    my $data={}; $weak=$data; weaken($weak);
    my $temporary=FLAT::Symbol::Token->new(key=>'temporary',payload=>$data);
    my $graph=FLAT::NFA->singleton($temporary)->as_dfa;
    ok(defined $weak,'live graph retains payload');
}
is($weak,undef,'no global registry retains released payloads');
my $plain=FLAT::PFA->singleton('a')->shuffle(FLAT::PFA->singleton('b'));
ok($plain->as_dfa->contains('ab') && $plain->as_min_dfa->contains('ba'),'plain PFA shortcut serializes parallel structure');
ok(!$plain->as_dfa->contains('a'),'plain PFA shortcut requires both branches');
# Text interchange retains matching strings, not bindings or payload data.
require FLAT::JFLAP;
my $display=FLAT::Symbol::Token->new(key=>'a',label=>'SECRET DISPLAY',payload=>{secret=>'SECRET PAYLOAD'});
my $xml=FLAT::NFA->singleton($display)->as_jflap;
like($xml,qr/<read>a<\/read>/,'JFLAP emits matching key');
unlike($xml,qr/SECRET/,'JFLAP does not emit display or payload');
my $round=FLAT::JFLAP->from_string($xml);
ok($round->contains_tokens(['a']),'interchange preserves key language');
is($round->symbol('a')->payload,undef,'interchange does not imply live binding persistence');
done_testing;
