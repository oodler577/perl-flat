package FLAT::PFA; # should this be FLAT::NFA::PFA ? .. might be too confusing
use strict;
use base 'FLAT::NFA';

use FLAT::Transition;

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new(@_); # Inherits constructor from NFA
                                     # contains states (actually nodes), alphabet, and 
                                     # transitions like NFA
    $self->{TIED} = [];              # tracks tied nodes
    $self->{ACTIVE_NODES} = [];      # tracks active nodes - could be label like start and final
    return $self;
}

# Uses FLAT::NFA methods for fall back, including: union, concat, kleene, and singleton

sub as_pfa { $_[0]->clone() }


# PFA->NFA conversion algorithm
sub as_nfa {

}

# Shuffle constructor
sub shuffle {

}

1;

__END__

=head1 NAME

FLAT::PFA - Parallel finite automata

=head1 SYNOPSIS

A FLAT::PFA object is a finite automata whose transitions are labeled
either with characters, the empty string (epsilon), or a concurrent line of
execution (lambda).  It essentially models two FSA in a non-deterministic way 
such that a string is valid it puts the FSA of the shuffled languages both into a
final, or accepting, state.  A PFA is an NFA, and as such exactly describes a regular
language.

A PFA contains nodes and states.  A state is made up of whatever nodes happen to be active.
There are two transition functions, nodal transitions and state transitions.  When a PFA
is converted into a NFA, there is no longer a need for nodes or nodal transitions, so they
go are eliminated.  PFA model state spaces much more compactly than NFA, and an N state PFA may 
represent 2**N non-deterministic states. This also means that a PFA may represent up to
2^(2^N) deterministic states.

=head1 USAGE

(not implemented yet)

In addition to implementing the interface specified in L<FLAT>, FLAT::PFA
objects provide the following PFA-specific methods:

=over

item $pfa-E<gt>shuffle

Cloning method; returns a copy of itself.

=item $pfa-E<gt>shuffle

Shuffle construct for building a PFA out of a PRE (i.e., a regular expression with
the shuffle operator)

=item $pfa-E<gt>as_nfa

Converts a PFA to an NFA by enumerating all states; similar to the Subset Construction
Algorithm, it does not implement e-closure.  Instead it treats epsilon transitions
normally, and joins any states resulting from a lambda (concurrent) transition
using an epsilon transition.

=back
