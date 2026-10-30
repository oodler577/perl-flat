use strict;
use warnings;
use Test::More;
use Scalar::Util qw(refaddr);
use FLAT::PFA;
use FLAT::Symbol::Token;

# Build every representation before editing the data, so copying a payload
# during any conversion would be detected by subsequent updates.
my $data={completed=>0, results=>[], value=>undef};
my $token=FLAT::Symbol::Token->new(key=>'job',label=>'Job',payload=>$data);
my $pfa=FLAT::PFA->singleton($token);
my $nfa=$pfa->as_nfa;
my $dfa=$nfa->as_dfa;
my $minimal=$dfa->as_min_dfa;
my $re=$minimal->as_regex;
my $rebuilt=$re->as_dfa;
my @graphs=(
    ['PFA',$pfa], ['NFA',$nfa], ['DFA',$dfa],
    ['minimal DFA',$minimal], ['RE rebuilt DFA',$rebuilt],
);
$token->payload->{completed}++;
$dfa->symbol('job')->payload->{completed}++;
push @{$rebuilt->symbol('job')->payload->{results}}, 'finished';
my $new_value={answer=>42};
$minimal->symbol('job')->payload->{value}=$new_value;
for my $entry (@graphs) {
    my ($name,$graph)=@$entry;
    is(refaddr($graph->symbol('job')),refaddr($token),"$name shares token");
    is($graph->symbol('job')->payload->{completed},2,"$name sees updates");
    is_deeply($graph->symbol('job')->payload->{results},['finished'],"$name sees nested updates");
    is(refaddr($graph->symbol('job')->payload->{value}),refaddr($new_value),"$name sees replacement container value");
    ok($graph->contains_tokens(['job']),"$name language still accepts job");
    ok(!$graph->contains_tokens([]),"$name language still rejects epsilon");
}
ok($re->contains_tokens([$token]),'RE membership unaffected by mutation');
is(refaddr($re->as_nfa->symbol('job')->payload),refaddr($data),'RE AST retains shared payload');

my @results;
my $array_token=FLAT::Symbol::Token->new(key=>'array',payload=>\@results);
my $array_graph=FLAT::PFA->singleton($array_token)->as_dfa;
push @{$array_graph->symbol('array')->payload}, 'item';
is_deeply(\@results,['item'],'array payload accepts normal push');
my $status='pending';
my $scalar_token=FLAT::Symbol::Token->new(key=>'scalar',payload=>\$status);
my $scalar_graph=FLAT::PFA->singleton($scalar_token)->as_dfa;
${$scalar_graph->symbol('scalar')->payload}='finished';
is($status,'finished','scalar payload accepts dereferenced assignment');

for my $method (qw(key label payload)) {
    my $code='$token->'.$method.' = undef';
    ok(!eval "$code; 1", "$method accessor is not assignable");
}
is($token->key,'job','key unchanged after rejected assignments');
is($token->label,'Job','label unchanged after rejected assignments');
is(refaddr($token->payload),refaddr($data),'payload binding unchanged');
is(FLAT::Symbol::Token->new(key=>'absent')->payload,undef,'missing payload stays undef');
done_testing;
