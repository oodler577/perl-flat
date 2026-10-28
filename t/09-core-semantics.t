use strict;
use warnings;
use Test::More;
use FLAT;

sub dfa { FLAT::Regex->new($_[0])->as_dfa }

# Fixed examples exercise consuming cycles, dead cycles, and empty languages.
for my $case (
    ['#', 1], ['[]', 1], ['a', 1], ['ab*c', 0],
    ['a*', 0], ['(ab)*c', 0], ['a*b*', 0], ['a#b*', 1],
    ['[]*', 1], ['a+bc', 1], ['[foo]*', 0],
) {
    my ($re, $finite) = @$case;
    for my $representation ('as_nfa', 'as_dfa', 'as_min_dfa') {
        is(!!FLAT::Regex->new($re)->$representation()->is_finite,
           !!$finite, "$representation finiteness of $re");
    }
}

my $epsilon_cycle = FLAT::NFA->new;
$epsilon_cycle->add_states(3);
$epsilon_cycle->set_starting(0);
$epsilon_cycle->set_accepting(2);
$epsilon_cycle->set_transition(0, 1, '');
$epsilon_cycle->set_transition(1, 0, '');
$epsilon_cycle->set_transition(1, 2, 'a');
ok($epsilon_cycle->is_finite, 'epsilon-only cycle accepts a finite language');
$epsilon_cycle->add_transition(0, 1, 'b');
ok(!$epsilon_cycle->is_finite, 'consuming edge in the same SCC makes it infinite');

my $dead_cycle = FLAT::NFA->new;
$dead_cycle->add_states(3);
$dead_cycle->set_starting(0);
$dead_cycle->set_accepting(1);
$dead_cycle->set_transition(0, 1, 'a');
$dead_cycle->set_transition(2, 2, 'b');
ok($dead_cycle->is_finite, 'unreachable consuming cycle is harmless');
$dead_cycle->set_transition(0, 2, 'b');
ok($dead_cycle->is_finite, 'reachable cycle with no accepting continuation is harmless');

# Compare set operations against their definitions on a bounded fixed corpus.
my @words = ('');
my @level = ('');
for (1 .. 4) {
    @level = map { my $prefix = $_; map { $prefix . $_ } qw(a b) } @level;
    push @words, @level;
}
my $a = dfa('a*');
my $b = dfa('b*');
my $union = $a->union($b);
my $intersection = $a->intersect($b);
my $difference = $a->difference($b);
my $symdiff = $a->symdiff($b);
for my $word (@words) {
    my ($in_a, $in_b) = map { !!$_->contains($word) } ($a, $b);
    is(!!$union->contains($word), !!($in_a || $in_b), "union <$word>");
    is(!!$intersection->contains($word), !!($in_a && $in_b), "intersection <$word>");
    is(!!$difference->contains($word), !!($in_a && !$in_b), "difference <$word>");
    is(!!$symdiff->contains($word), !!($in_a != $in_b), "symmetric difference <$word>");
}
ok($a->contains('aa') && !$a->contains('b'), 'operations leave the left input unchanged');
ok($b->contains('bb') && !$b->contains('a'), 'operations leave the right input unchanged');

my $partial = dfa('ab*')->trim_sinks;
my $complement = $partial->complement;
for my $word (@words) {
    is(!!$complement->contains($word), !$partial->contains($word),
       "complement completes a partial DFA <$word>");
}
ok($partial->intersect(dfa('ab'))->contains('ab'), 'intersection accepts a partial DFA');

for my $case (
    [$union, ['a', 'b'], ['ab']],
    [dfa('a')->concat(dfa('b')), ['ab'], ['', 'a', 'b', 'ba']],
    [dfa('ab')->kleene, ['', 'ab', 'abab'], ['a', 'ba']],
    [dfa('ab')->reverse, ['ba'], ['', 'ab']],
) {
    my ($result, $accepted, $rejected) = @$case;
    isa_ok($result, 'FLAT::DFA');
    is(scalar(() = $result->get_starting), 1, 'DFA result has one start');
    for my $state ($result->get_states) {
        for my $symbol ($result->alphabet) {
            my @next = $result->successors($state, $symbol);
            is(scalar @next, 1, 'DFA result has exactly one transition per symbol');
        }
    }
    ok($result->is_valid_string($_), "DFA accepts <$_>") for @$accepted;
    ok(!$result->is_valid_string($_), "DFA rejects <$_>") for @$rejected;
}
isa_ok($union->as_nfa, 'FLAT::NFA');
ok(!$union->as_nfa->isa('FLAT::DFA'), 'as_nfa changes the representation class');

my $replace_start = dfa('a');
my ($start) = $replace_start->get_starting;
my ($after_a) = $replace_start->successors($start, 'a');
is_deeply([$replace_start->predecessors($after_a, 'a')], [$start],
          'DFA graph predecessors preserve original state IDs');
$replace_start->unset_starting($replace_start->get_starting);
$replace_start->set_starting(1);
is_deeply([$replace_start->get_starting], [1], 'starting state can be replaced');

my $empty = dfa('#')->trim_sinks;
is(scalar(() = $empty->get_starting), 1, 'empty trimmed DFA retains a start');
ok($empty->is_empty, 'empty trimmed DFA remains empty');

sub collect {
    my ($next) = @_;
    my @words;
    for (1 .. 100) {
        my $word = $next->();
        return [sort @words] unless defined $word;
        push @words, $word;
    }
    die 'finite iterator did not terminate';
}

for my $method ('new_acyclic_string_generator', 'new_deepdft_string_generator') {
    is_deeply(collect(dfa('[]+0+a')->$method()), ['', '0', 'a'],
              "$method emits epsilon and zero once, then terminates");
    is_deeply(collect(dfa('ab+ba')->as_min_dfa->trim_sinks->$method()), ['ab', 'ba'],
              "$method preserves both paths through a diamond");
    is_deeply(collect(dfa('a+bc')->as_min_dfa->trim_sinks->$method()), ['a', 'bc'],
              "$method does not share visited-state marks across sibling paths");
}
is_deeply(collect(dfa('a*')->as_min_dfa->new_acyclic_string_generator()), [''],
          'acyclic traversal does not revisit the starting state');
is_deeply(collect(dfa('a*')->as_min_dfa->new_deepdft_string_generator(3)), ['', 'a', 'aa'],
          'depth-first traversal obeys its per-state visit bound');

done_testing;
