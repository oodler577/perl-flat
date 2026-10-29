use strict;
use warnings;
use utf8;
use Test::More;
use Storable qw(dclone);
use FLAT;
use FLAT::DFA;
use FLAT::Regex;
use FLAT::DFA::Hyper;
sub re { FLAT::Regex->new($_[0])->as_nfa->as_dfa }
sub machine {
    my ($rows,$accept,$alphabet)=@_;
    $alphabet ||= ['a','b'];
    my $d=FLAT::DFA->new;
    $d->add_states(scalar @$rows); $d->set_starting(0);
    for my $p (0..$#$rows) {
        $d->set_accepting($p) if $accept & (1 << $p);
        for my $c (0..$#$alphabet) {
            $d->add_transition($p,$rows->[$p][$c],$alphabet->[$c]) if defined $rows->[$p][$c];
        }
    }
    return $d;
}
# Acceptance is irrelevant to left-language partition. Include an unreachable
# cycle and a reachable state downstream of, but not on, a cycle.
my $d=machine([[1,2],[1,3],[3,3],[undef,undef],[4,4]],8);
my $before=dclone($d);
is_deeply($d->preamble_kernel,{preamble=>[0,2],kernel=>[1,3],unreachable=>[4]},'kernel includes descendants, excludes unreachable cycle');
is_deeply($d,$before,'partition leaves graph unchanged');
$d->set_accepting(0,1,2,4);
is_deeply($d->preamble_kernel,{preamble=>[0,2],kernel=>[1,3],unreachable=>[4]},'partition independent of final states');
my $loop=machine([[0]],0,['a']);
is_deeply($loop->preamble_kernel->{kernel},[0],'initial self-loop is kernel');
my $empty=machine([[]],1,[]);
is_deeply($empty->preamble_kernel,{preamble=>[0],kernel=>[],unreachable=>[]},'empty alphabet and epsilon');
is_deeply($empty->f_equivalence_classes,[[0]],'empty alphabet f-class');
is($empty->as_hyper_min_dfa->num_states,1,'empty alphabet hyper-minimum is one state');
# Nonminimal inputs need all empty right languages as seeds, not diagonal only.
my $redundant=machine([[1,2],[1,2],[2,1]],0);
is_deeply($redundant->f_equivalence_classes,[[0,1,2]],'nonminimal equivalent cyclic states all coalesce in f-class');
my $r=machine([[1,2],[1,2],[2,1]],6);
is_deeply($r->f_equivalence_classes,[[0,1,2]],'nonminimal states differing only by epsilon are f-equivalent');
my $distinct=machine([[0,1],[1,0]],1);
is_deeply($distinct->f_equivalence_classes,[[0],[1]],'infinitely distinguishing cyclic states remain separate');
# Two distinct kernel states can be f-equivalent and must both survive.
my $kernel=machine([[1,0],[2,2],[2,2]],2);
my $report=FLAT::DFA::Hyper->minimize_with_report($kernel);
is($report->{dfa}->num_states,3,'distinct f-equivalent kernel states are not merged');
ok($kernel->equals($report->{dfa}),'kernel-only example remains exactly equal');
for my $expr ('#','[]','0','ab','a+b','a*','a*b','ab+a*','a*+b','(a+b)*') {
    my $a=re($expr); my $snapshot=dclone($a);
    my $h=$a->as_hyper_min_dfa;
    isa_ok($h,'FLAT::DFA');
    ok($a->symdiff($h)->is_finite,"$expr has finite error language");
    ok($h->num_states <= $a->as_min_dfa->num_states,"$expr does not grow after hyper-minimization");
    is($h->as_hyper_min_dfa->num_states,$h->num_states,"$expr size is idempotent");
    is_deeply($a,$snapshot,"$expr input unmodified");
    for my $p ($h->get_states) {
        for my $symbol ($h->alphabet) {
            is(scalar($h->successors($p,$symbol)),1,'output complete and deterministic');
        }
    }
}
my $finite=re('ab')->as_hyper_min_dfa;
is($finite->num_states,1,'nonempty finite language hyper-minimizes to one rejecting state');
ok(!re('ab')->equals($finite),'hyper-minimization explicitly changes exact acceptance');
ok(re('ab')->is_f_equivalent($finite),'finite difference predicate true');
ok(!re('a*')->is_f_equivalent(re('b*')),'infinite difference predicate false');
# Independent oracle for every complete binary two-state DFA: the only
# complete one-state languages over this alphabet are empty and universal.
for my $bits (0..15) {
    my @rows=map { my $p=$_; [map { ($bits >> (2*$p+$_)) & 1 } 0..1] } 0..1;
    for my $accept (0..3) {
        my $a=machine(\@rows,$accept);
        my $h=$a->as_hyper_min_dfa;
        my $one_state_possible=$a->is_finite || $a->complement->is_finite;
        is($h->num_states,$one_state_possible ? 1 : 2,"optimal size for table $bits finals $accept");
        ok($a->symdiff($h)->is_finite,'exhaustive finite difference oracle');
        my $classes=$a->f_equivalence_classes;
        my $x=$a->clone; $x->unset_starting($x->get_starting); $x->set_starting(0);
        my $y=$a->clone; $y->unset_starting($y->get_starting); $y->set_starting(1);
        is(@$classes==1 ? 1 : 0,$x->symdiff($y)->is_finite ? 1 : 0,'pair class matches independent symmetric-difference oracle');
    }
}
# Compare all pair classes with independently rooted-language finite checks.
for my $rows ([[1,2],[1,2],[2,2]], [[1,2],[2,0],[0,1]], [[1,1],[2,2],[2,2]]) {
    for my $accept (0..7) {
        my $a=machine($rows,$accept);
        my $classes=$a->f_equivalence_classes;
        my %class;
        for my $i (0..$#$classes) { $class{$_}=$i for @{$classes->[$i]} }
        for my $p (0..2) {
            for my $q ($p..2) {
                my $x=$a->clone; $x->unset_starting($x->get_starting); $x->set_starting($p);
                my $y=$a->clone; $y->unset_starting($y->get_starting); $y->set_starting($q);
                is($class{$p}==$class{$q} ? 1 : 0,$x->symdiff($y)->is_finite ? 1 : 0,'three-state pair oracle');
            }
        }
        my $h=$a->as_hyper_min_dfa;
        ok($a->symdiff($h)->is_finite,'three-state hyper-result finite difference');
    }
}
my $token=machine([[1,2],[1,2],[2,2]],2,['open','猫']);
my $h=$token->as_hyper_min_dfa;
is_deeply([sort $h->alphabet],['open','猫'],'atomic multi-character and Unicode alphabet preserved');
ok($token->symdiff($h)->is_finite,'token-language finite difference');
my $analysis=FLAT::DFA::Hyper->analyze($token);
is_deeply($analysis->{f_equivalence_classes},$token->f_equivalence_classes,'analysis uses input IDs');
my $partial=machine([[1,undef],[undef,undef]],2);
my $p_snapshot=dclone($partial);
ok($partial->symdiff($partial->as_hyper_min_dfa)->is_finite,'partial DFA completed for hyper-minimization');
is_deeply($partial,$p_snapshot,'partial input not completed in place');
my $bad=FLAT::DFA->new; $bad->add_states(1);
ok(!eval { $bad->preamble_kernel; 1 },'missing initial state rejected');
$bad->set_starting(0); $bad->add_transition(0,0,'');
ok(!eval { $bad->as_hyper_min_dfa; 1 },'epsilon transition rejected');
my $nd=machine([[0]],1,['a']); $nd->add_states(1); $nd->add_transition(0,1,'a');
ok(!eval { $nd->f_equivalence_classes; 1 },'nondeterministic DFA rejected');
done_testing;
