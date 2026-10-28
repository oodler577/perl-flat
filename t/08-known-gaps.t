use strict;
use warnings;
use Test::More;
use FLAT;

# Regressions for defects found in the CPAN 1.0.4 baseline.
# See docs/KNOWN_GAPS.md.

{
    ok(!FLAT::Regex->new('ab*c')->as_nfa->is_finite,
       'ab*c is infinite after NFA conversion');
}

{
    my $a = FLAT::Regex->new('a')->as_dfa;
    my $b = FLAT::Regex->new('b')->as_dfa;
    ok($a->difference($b)->contains('a'), '{a} minus {b} contains a');
}

{
    my $a = FLAT::Regex->new('a')->as_dfa;
    my $b = FLAT::Regex->new('b')->as_dfa;
    my $union = $a->union($b);
    my @starts = $union->get_starting;
    ok(!$union->isa('FLAT::DFA') || @starts == 1,
       'union result respects its advertised automaton type');
}

{
    my $dfa = FLAT::Regex->new('a')->as_dfa;
    # Convert Perl's deep-recursion warning into a bounded failure.
    # No timer or unbounded recursion is required.
    local $SIG{__WARN__} = sub {
        die "recursive unset_starting\n"
            if $_[0] =~ /Deep recursion.*unset_starting/;
        warn $_[0];
    };
    my $returned = eval { $dfa->unset_starting(0); 1 };
    ok($returned, 'unset_starting returns normally');
}

{
    my $dfa = FLAT::DFA->new;
    $dfa->add_states(4);
    $dfa->set_starting(0);
    $dfa->set_accepting(3);
    $dfa->set_transition(0, 1, 'a');
    $dfa->set_transition(0, 3, 'b');
    $dfa->set_transition($_, $_, 'a', 'b') for 1 .. 3;
    ok($dfa->trim_sinks->contains('b'),
       'removing two rejecting sinks preserves the accepting state');
}

{
    my $dfa = FLAT::Regex->new('0')->as_dfa;
    is($dfa->new_acyclic_string_generator()->(), '0',
       'accepted zero word is emitted');
}

{
    my $dfa = FLAT::Regex->new('[]')->as_dfa;
    is($dfa->new_acyclic_string_generator()->(), '',
       'accepted empty word is emitted (undef means exhausted)');
}

done_testing;
