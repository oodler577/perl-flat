package FLAT::PFA;
use strict;
use base 'FLAT::NFA';
use Carp;

use FLAT::Transition;


# Note: in a PFA, states are made up of active nodes.  In this implementation, we have
# decided to retain the functionality of the state functions in FA.pm, although the entities
# being manipulated are technically nodes, not states.  States are only explicitly tracked
# once the PFA is serialized into an NFA.  Therefore, the TRANS member of the PFA object is
# the nodal transition function, gamma.  The state transition function, delta, is not used
# in anyway, but is derived out of the PFA->NFA conversion process.


# The new way of doing things eliminated from PFA.pm of FLAT::Legacy is the 
# need to explicitly track: start nodes, final nodes, symbols, and lambda & epsilon symbols,  

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new(@_); # <-- SUPER is FLAT::NFA
    $self->{LAMBDA} = '#lambda';     # special lambda symbol - used internally
    return $self;
}

# Singleton is no different than the NFA singleton
sub singleton {
    my ($class, $char) = @_;
    my $pfa = $class->new;
    if (not defined $char) {
        $pfa->add_states(1);
        $pfa->set_starting(0);
    } elsif ($char eq "") {
        $pfa->add_states(1);
        $pfa->set_starting(0);
        $pfa->set_accepting(0);
    } else {
        $pfa->add_states(2);
        $pfa->set_starting(0);
        $pfa->set_accepting(1);
        $pfa->set_transition(0, 1, $char);
    }
    return $pfa;
}

# attack of the clones
sub as_pfa { $_[0]->clone() }

# set lambda symbol - temp fix for larger problem of special symbols
# like epsilon and lambda
sub set_lambda {
  my $self = shift;
  $self->{LAMBDA} = $_[0];
}

# get lamnda symbol
sub get_lambda {
  my $self = shift;
  return $self->{LAMBDA};
}

# will implement the joining of two PFAs with lambda transitions
# need to fix <-- still broken?  need to check!!
sub shuffle {
    my @pfas = map { $_->as_pfa } @_;
    my $result = $pfas[0]->clone;
    # iteratively add lambda pinch to all PFAs
    for (1 .. $#pfas) {
        $result->_swallow( $pfas[$_] );
	my @starting = $result->get_starting();
	my @accepting = $result->get_accepting();
	$result->unset_starting(@starting);
	$result->unset_accepting(@accepting);
        my ($newstart, $newfinal) = $result->add_states(2);
	$result->set_starting($newstart);
	$result->set_accepting($newfinal);
	foreach (@starting) {
          $result->set_transition($newstart,$_,'#lambda');
	}
	foreach (@accepting) {
          $result->set_transition($_,$newfinal,'#lambda');
	}	
    }
    return $result;
}

# joins two PFAs in a union (or) - no change from NFA
sub union {
    my @pfas = map { $_->as_pfa } @_;
    my $result = $pfas[0]->clone;
    $result->_swallow($_) for @pfas[1 .. $#pfas];
    my ($newstart, $newfinal) = $result->add_states(2);
    
    }

# joins two PFAs via concatenation  - no change from NFA
sub concat {
    my @pfas = map { $_->as_pfa } @_;
    
    my $result = $pfas[0]->clone;
    my @newstate = ([ $result->get_states ]);
    my @start = $result->get_starting;

    for (1 .. $#pfas) {
        push @newstate, [ $result->_swallow( $pfas[$_] ) ];
    }

    $result->unset_accepting($result->get_states);
    $result->unset_starting($result->get_states);
    $result->set_starting(@start);
    
    for my $pfa_id (1 .. $#pfas) {
        for my $s1 ($pfas[$pfa_id-1]->get_accepting) {
        for my $s2 ($pfas[$pfa_id]->get_starting) {
            $result->set_transition(
                $newstate[$pfa_id-1][$s1],
                $newstate[$pfa_id][$s2], "" );
        }}
    }

    $result->set_accepting(
        @{$newstate[-1]}[ $pfas[-1]->get_accepting ] );

    $result;
}

# forms closure around a the given PFA  - no change from NFA
sub kleene {
    my $result = $_[0]->clone;
    
    my ($newstart, $newfinal) = $result->add_states(2);
    
    $result->set_transition($newstart, $_, "")
        for $result->get_starting;
    $result->unset_starting( $result->get_starting );
    $result->set_starting($newstart);

    $result->set_transition($_, $newfinal, "")
        for $result->get_accepting;
    $result->unset_accepting( $result->get_accepting );
    $result->set_accepting($newfinal);

    $result->set_transition($newstart, $newfinal, "");    
    $result->set_transition($newfinal, $newstart, "");
    
    $result;
}


# reverse  - no change from NFA
sub reverse {
    my $self = $_[0]->clone;
    $self->_transpose;
    
    my @start = $self->get_starting;
    my @final = $self->get_accepting;
    
    $self->unset_accepting( $self->get_states );
    $self->unset_starting( $self->get_states );
    
    $self->set_accepting( @start );
    $self->set_starting( @final );
    
    $self;
}

# stretching my legs after a few months being gone ... see if the legacy conversion
# can be modified to work

# See FLAT::Legacy::PFA for the initialization stuff - I am sure it can be refined a lot!
# PSUEDO CODE
#   my @Dstates = get_starting();
#   while (@Dstates) 
#   { my @T = @{pop (@Dstates)};                
#    #remember that states are made up of 1 or more nodes
#     my $current = $self->serialize_name(@T) 
#     add $current (or @T) to @DONE stack
#     foreach my $symbol ($self->alphabet)
#     {  if ($symbol eq $LAMBDA)
#        {  foreach my $L ($self->get_tied_from($current))
#           {  foreach my $U ($self->move($L,$LAMBDA) push(@N,unique($U)); }
#        }
#        else
#        {  foreach my $t (@T)  
#           {  foreach my $U ($self->move($U,$symbol))
#              {  push(@N,$self->complement(@T,$t)) };
#           }
#        }       
#        Ndtran [N,$symbol] := N !!add new transition
#        if N unmarked, add N to Dstates
#    }
#  }

#1. make sure psuedo code is correct
#2. implement it, including any require initializations
#3. refine, refactor

sub as_nfa { 
    my $self = shift;
    my @Dstates = $self->get_states();
    my %Dtran =(); # hash of serialized state names that have been searched
    # New NFA object reference
    my $result = FLAT::NFA->new();    

    return $result;
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
