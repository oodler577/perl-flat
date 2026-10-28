package FLAT::DFA;

use strict;
use warnings;
use parent qw(FLAT::NFA);
use Storable qw(dclone);
use FLAT::DFA::Minimal;
use Carp;

sub set_starting {
    my $self = shift;
    $self->SUPER::set_starting(@_);

    my $num = () = $self->get_starting;
    confess "DFA must have exactly one starting state"
      if $num != 1;
}

sub complement {
    my $self = $_[0]->clone;
    $self->_extend_alphabet($self->alphabet);

    for my $s ( $self->get_states ) {
        $self->is_accepting($s)
          ? $self->unset_accepting($s)
          : $self->set_accepting($s);
    }

    return $self;
}

# Perform epsilon/multiple-start constructions as NFAs, then determinize.
sub union {
    my $self = shift;
    return $self->as_nfa->union(@_)->as_dfa;
}

sub concat {
    my $self = shift;
    return $self->as_nfa->concat(@_)->as_dfa;
}

sub kleene {
    return $_[0]->as_nfa->kleene->as_dfa;
}

sub reverse {
    return $_[0]->as_nfa->reverse->as_dfa;
}

sub _TUPLE_ID { join "\0", @_ }

sub _uniq {
    my %seen;
    grep { !$seen{$_}++ } @_;
}

## this method still needs more work..
sub intersect {
    my @dfas = map { $_->as_dfa } @_;

    my $return = FLAT::DFA->new;
    my %newstates;
    my @alpha = _uniq( map { $_->alphabet } @dfas );

    $_->_extend_alphabet(@alpha) for @dfas;

    my @start = map { $_->get_starting } @dfas;
    my $start = $newstates{ _TUPLE_ID(@start) } = $return->add_states(1);
    $return->set_starting($start);
    $return->set_accepting($start)
      if !grep { !$dfas[$_]->is_accepting( $start[$_] ) } 0 .. $#dfas;

    my @queue = ( \@start );
    while (@queue) {
        my @tuple = @{ shift @queue };

        for my $char (@alpha) {
            my @next = map { $dfas[$_]->successors( $tuple[$_], $char ) } 0 .. $#dfas;

            #warn "[@tuple] --> [@next] via $char\n";

            if ( not exists $newstates{ _TUPLE_ID(@next) } ) {
                my $s = $newstates{ _TUPLE_ID(@next) } = $return->add_states(1);
                $return->set_accepting($s)
                  if !grep { !$dfas[$_]->is_accepting( $next[$_] ) } 0 .. $#dfas;
                push @queue, \@next;
            }

            $return->add_transition( $newstates{ _TUPLE_ID(@tuple) }, $newstates{ _TUPLE_ID(@next) }, $char );
        }
    }

    return $return;
}

# Permit a temporary zero-start state while replacing the starting state.
sub unset_starting {
    my $self = shift;
    return $self->SUPER::unset_starting(@_);
}

#### transformations

sub trim_sinks {
    my $self = shift;
    my $result = $self->clone;
    my @pred;
    for my $s ($self->get_states) {
        push @{$pred[$_]}, $s for $self->successors($s);
    }
    my @queue = $self->get_accepting;
    my %useful = map { $_ => 1 } @queue;
    while (@queue) {
        my $s = shift @queue;
        push @queue, grep { !$useful{$_}++ } @{$pred[$s] || []};
    }
    # Retain the start even for the empty language. delete_states sorts IDs
    # descending, so delete the whole batch before IDs can be reused.
    my @dead = grep { !$useful{$_} && !$self->is_starting($_) }
               $self->get_states;
    $result->delete_states(@dead);
    return $result;
}

# classical DFA minimization using equivalence classes
sub as_min_dfa {
    my $self     = shift()->clone;
    my $N        = $self->num_states;
    my @alphabet = $self->alphabet;
    my ($start)  = $self->get_starting;
    my %final    = map { $_ => 1 } $self->get_accepting;
    my @equiv    = map [ (0) x ( $_ + 1 ), (1) x ( $N - $_ - 1 ) ], 0 .. $N - 1;
    while (1) {
        my $changed = 0;
        for my $s1 ( 0 .. $N - 1 ) {
            for my $s2 ( grep { $equiv[$s1][$_] } 0 .. $N - 1 ) {
                if ( 1 == grep defined, @final{ $s1, $s2 } ) {
                    $changed = 1;
                    $equiv[$s1][$s2] = 0;
                    next;
                }
                for my $char (@alphabet) {
                    my @t = sort { $a <=> $b } $self->successors( [ $s1, $s2 ], $char );
                    next if @t == 1;

                    if ( not $equiv[ $t[0] ][ $t[1] ] ) {
                        $changed = 1;
                        $equiv[$s1][$s2] = 0;
                    }
                }
            }
        }
        last if !$changed;
    }
    my $result = FLAT::DFA::Minimal->new;
    my %newstate;
    my @classes;
    for my $s ( 0 .. $N - 1 ) {
        next if exists $newstate{$s};

        my @c = ( $s, grep { $equiv[$s][$_] } 0 .. $N - 1 );
        push @classes, \@c;

        @newstate{@c} = ( $result->add_states(1) ) x @c;
    }
    for my $c (@classes) {
        my $s = $c->[0];
        for my $char (@alphabet) {
            my ($next) = $self->successors( $s, $char );
            $result->add_transition( $newstate{$s}, $newstate{$next}, $char );
        }
    }
    $result->set_starting( $newstate{$start} );
    $result->set_accepting( $newstate{$_} ) for $self->get_accepting;
    $result->set_equivalence_classes( \@classes );
    return $result;
}

# the validity of a given string <-- executes symbols over DFA
# if there is not transition for given state and symbol, it fails immediately
# if the current state we're in is not final when symbols are exhausted, then it fails

sub is_valid_string {
    my $self   = shift;
    my $string = shift;
    chomp $string;
    my $OK    = undef;
    my @stack = split( '', $string );

    # this is confusing all funcs return arrays
    my @current = $self->get_starting();
    my $current = pop @current;
    foreach (@stack) {
        my @next = $self->successors( $current, $_ );
        if ( !@next ) {
            return $OK;    #<--returns undef bc no transition found
        }
        $current = $next[0];
    }
    $OK++ if ( $self->is_accepting($current) );
    return $OK;
}

# Need to implement! http://www.ianab.com/hyper/
# DFA hyper-minimization using equivalence classes
sub as_hyper_min_dfa {
    my $self = shift()->clone;
}

# DFT stuff in preparation for DFA pump stuff;
sub as_node_list {
    my $self = shift;
    my %node = ();
    for my $s1 ( $self->get_states ) {
        $node{$s1} = {};    # initialize
        for my $s2 ( $self->get_states ) {
            my $t = $self->get_transition( $s1, $s2 );
            if ( defined $t ) {

                # array of symbols that $s1 will go to $s2 on...
                push( @{ $node{$s1}{$s2} }, $t->alphabet );
            }
        }
    }
    return %node;
}

sub as_acyclic_strings {
    my $self        = shift;
    my %dflabel     = ();                      # lookup table for dflable
    my %backtracked = ();                      # lookup table for backtracked edges
    my $lastDFLabel = 0;
    my @string      = ();
    my %nodes       = $self->as_node_list();

    # output format is the actual PRE followed by all found strings
    $self->acyclic( $self->get_starting(), \%dflabel, $lastDFLabel, \%nodes, \@string );
}

sub acyclic {
    my $self        = shift;
    my $startNode   = shift;
    my $dflabel_ref = shift;
    my $lastDFLabel = shift;
    my $nodes       = shift;
    my $string      = shift;

    # tree edge detection
    if ( !exists( $dflabel_ref->{$startNode} ) ) {
        $dflabel_ref->{$startNode} = ++$lastDFLabel;    # the order inwhich this link was explored
        foreach my $adjacent ( keys( %{ $nodes->{$startNode} } ) ) {
            if ( !exists( $dflabel_ref->{$adjacent} ) ) {    # initial tree edge
                foreach my $symbol ( @{ $nodes->{$startNode}{$adjacent} } ) {
                    push( @{$string}, $symbol );
                    $self->acyclic( $adjacent, \%{$dflabel_ref}, $lastDFLabel, \%{$nodes}, \@{$string} );
                    if ( $self->array_is_subset( [$adjacent], [ $self->get_accepting() ] ) ) {    #< proof of concept
                        printf( "%s\n", join( '', @{$string} ) );
                    }
                    pop( @{$string} );
                }
            }
        }
    }

    # remove startNode entry to facilitate acyclic path determination
    delete( $dflabel_ref->{$startNode} );

    #$lastDFLabel--;
    return;
}

sub as_dft_strings {
    my $self  = shift;
    my $depth = 1;
    $depth = shift if ( 1 < $_[0] );
    my %dflabel = ();                      # scoped lookup table for dflable
    my %nodes   = $self->as_node_list();
    foreach ( keys(%nodes) ) {
        $dflabel{$_} = [];                 # initialize container (array) for multiple dflables for each node
    }
    my $lastDFLabel = 0;
    my @string      = ();
    $self->dft( $self->get_starting(), [ $self->get_accepting() ], \%dflabel, $lastDFLabel, \%nodes, \@string, $depth );
}

sub dft {
    my $self        = shift;
    my $startNode   = shift;
    my $goals_ref   = shift;
    my $dflabel_ref = shift;
    my $lastDFLabel = shift;
    my $nodes       = shift;
    my $string      = shift;
    my $DEPTH       = shift;

    # add start node to path
    my $c1 = @{ $dflabel_ref->{$startNode} };    # get number of elements
    if ( $DEPTH >= $c1 ) {
        push( @{ $dflabel_ref->{$startNode} }, ++$lastDFLabel );
        foreach my $adjacent ( keys( %{ $nodes->{$startNode} } ) ) {
            my $c2 = @{ $dflabel_ref->{$adjacent} };
            if ( $DEPTH > $c2 ) {    # "initial" tree edge
                foreach my $symbol ( @{ $nodes->{$startNode}{$adjacent} } ) {
                    push( @{$string}, $symbol );
                    $self->dft( $adjacent, [ @{$goals_ref} ], $dflabel_ref, $lastDFLabel, $nodes, [ @{$string} ], $DEPTH );

                    # assumes some base path found
                    if ( $self->array_is_subset( [$adjacent], [ @{$goals_ref} ] ) ) {
                        printf( "%s\n", join( '', @{$string} ) );
                    }
                    pop( @{$string} );
                }
            }
        }    # remove startNode entry to facilitate acyclic path determination
        pop( @{ $dflabel_ref->{$startNode} } );
        $lastDFLabel--;
    }
}

#
# String gen using iterators, supports delimter; default is q{}
#

sub get_acyclic_sub {
    my $self = shift;
    my ( $start, $nodelist_ref, $dflabel_ref, $string_ref, $accepting_ref, $lastDFLabel, $delimiter ) = @_;
    $delimiter //= q{};
    my @ret = ();
    foreach my $adjacent ( keys( %{ $nodelist_ref->{$start} } ) ) {
        $lastDFLabel++;
        if ( !exists( $dflabel_ref->{$adjacent} ) ) {
            foreach my $symbol ( @{ $nodelist_ref->{$start}{$adjacent} } ) {
                my $string_clone = [ @{$string_ref}, $symbol ];
                my $dflabel_clone = { %{$dflabel_ref}, $adjacent => $lastDFLabel };
                push( @ret, sub { return $self->get_acyclic_sub( $adjacent, $nodelist_ref, $dflabel_clone, $string_clone, $accepting_ref, $lastDFLabel, $delimiter ); });
            }
        }

    }

    # returns a complex data structure in the form of a hash reference
    return {
        substack    => [@ret],
        lastDFLabel => $lastDFLabel,
        string      => ( $self->array_is_subset( [$start], $accepting_ref ) ? join( $delimiter, @{$string_ref} ) : undef )
    };
}

sub init_acyclic_iterator {
    my ($self, $delimiter) = @_;
    my ($start)       = $self->get_starting;
    my %dflabel        = ($start => 1);
    my @string         = ();
    my $lastDFLabel    = 0;
    my %nodelist       = $self->as_node_list();
    my @accepting      = $self->get_accepting();

    # initialize
    my $r        = $self->get_acyclic_sub( $self->get_starting(), \%nodelist, \%dflabel, \@string, \@accepting, $lastDFLabel, $delimiter );
    my @substack = (sub { $r });
    return sub {
        while (1) {
            if ( !@substack ) {
                return undef;
            }
            my $s = pop @substack;
            my $r = $s->();
            push( @substack, @{ $r->{substack} } );
            if ( defined $r->{string} ) {
                return $r->{string};
            }
        }
    }
}

sub new_acyclic_string_generator {
    my ($self,$delim) = @_;
    my $iterator = $self->init_acyclic_iterator($delim);
    return $iterator;
}

sub get_deepdft_sub {
    my $self = shift;
    my ( $start, $nodelist_ref, $dflabel_ref, $string_ref, $accepting_ref, $lastDFLabel, $MAXLEVEL, $delimiter ) = @_;
    my @ret = ();
    my $c1  = ( ref $dflabel_ref eq 'HASH' ) ? @{ $dflabel_ref->{$start} } : 0;
    if ( $MAXLEVEL and $c1 < $MAXLEVEL ) {
        push( @{ $dflabel_ref->{$start} }, ++$lastDFLabel );
        foreach my $adjacent ( keys( %{ $nodelist_ref->{$start} } ) ) {
            my $c2 = @{ $dflabel_ref->{$adjacent} };
            if ( $c2 < $MAXLEVEL ) {
                foreach my $symbol ( @{ $nodelist_ref->{$start}{$adjacent} } ) {
                    push( @{$string_ref}, $symbol );
                    my $string_clone  = dclone($string_ref);
                    my $dflabel_clone = dclone($dflabel_ref);
                    push(
                        @ret,
                        sub {
                            return $self->get_deepdft_sub( $adjacent, $nodelist_ref, $dflabel_clone, $string_clone, $accepting_ref, $lastDFLabel, $MAXLEVEL, $delimiter );
                        }
                    );
                    pop @{$string_ref};
                }
            }
        }
    }
    return {
        substack    => [@ret],
        lastDFLabel => $lastDFLabel,
        string      => ( $self->array_is_subset( [$start], $accepting_ref ) ? join( $delimiter, @{$string_ref} ) : undef )
    };
}

sub init_deepdft_iterator {
    my ($self, $MAXLEVEL, $delimiter) = @_;
    $MAXLEVEL       //= 1;
    $delimiter      //= q{};
    my %dflabel     = ();
    my @string      = ();
    my $lastDFLabel = 0;
    my %nodelist    = $self->as_node_list();
    foreach my $node ( keys(%nodelist) ) {
        $dflabel{$node} = [];    # initializes anonymous arrays for all nodes
    }
    my @accepting = $self->get_accepting();

    # initialize
    my $r        = $self->get_deepdft_sub( $self->get_starting(), \%nodelist, \%dflabel, \@string, \@accepting, $lastDFLabel, $MAXLEVEL, $delimiter );
    my @substack = (sub { $r });
    return sub {
        while (1) {
            if ( !@substack ) {
                return undef;
            }
            my $s = pop @substack;
            my $r = $s->();
            push( @substack, @{ $r->{substack} } );
            if ( defined $r->{string} ) {
                return $r->{string};
            }
        }
    }
}

sub new_deepdft_string_generator {
    my ($self, $MAXLEVEL, $delimiter)  = @_;
    return $self->init_deepdft_iterator($MAXLEVEL, $delimiter);
}

1;

__END__

=head1 NAME

FLAT::DFA - Deterministic finite automata

=head1 SYNOPSIS

A FLAT::DFA object is a finite automata whose transitions are labeled
with single characters. Furthermore, each state has exactly one outgoing
transition for each available label/character. 

=head1 USAGE

In addition to implementing the interface specified in L<FLAT> and L<FLAT::NFA>, 
FLAT::DFA objects provide the following DFA-specific methods:

=over

=item $dfa-E<gt>unset_starting

Because a DFA, by definition, must have only ONE starting state, this allows one to unset
the current start state so that a new one may be set.

=item $dfa-E<gt>trim_sinks

Returns a copy with states that cannot reach acceptance removed, along with
transitions to those states. The initial state is retained even for the empty
language. The result may be a partial DFA (some transitions are absent).

This has no affect on testing if a string is valid using C<FLAT::DFA::is_valid_string>, 
discussed below.

=item $dfa-E<gt>as_min_dfa

This method returns a minimized copy of a complete DFA. The calling object
is not modified. Minimize before calling C<trim_sinks>.

=item $dfa-E<gt>is_valid_string($string)

This method tests if the given string is accepted by the DFA.

=item $dfa-E<gt>new_acyclic_string_generator($delimiter)

=item $dfa-E<gt>new_deepdft_string_generator($max_visits, $delimiter)

Return iterators over accepted words. The acyclic iterator does not repeat
a state within a path. The depth-first iterator permits at most C<$max_visits>
visits per state (default 1). These are bounded path traversals, not exhaustive
enumerators for arbitrary infinite languages. Output order is unspecified.

The delimiter defaults to the empty string. An accepted empty word is returned
as C<''>; the accepted word C<'0'> is also a valid result. Only C<undef> means
that the iterator is exhausted. Callers must test definedness:

  my $next = $dfa->new_acyclic_string_generator;
  while (defined(my $word = $next->())) {
      print "$word\n";
  }

Words from the two iterators may differ for equivalent automata with different
graph structure, because the bounds are on states rather than word length.

=back

=head1 AUTHORS & ACKNOWLEDGEMENTS

FLAT is written by Mike Rosulek E<lt>mike at mikero dot comE<gt> and 
B. Estarde E<lt>estradb at gmail dot comE<gt>.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
