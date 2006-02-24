package FLAT::DFA;
use strict;
use base 'FLAT::NFA';
use Carp;


sub set_starting {
    my $self = shift;
    $self->SUPER::set_starting(@_);
    
    my $num = () = $self->get_starting;
    confess "DFA must have exactly one starting state"
        if $num != 1;
}

sub unset_starting {
    my $self = shift;
    $self->SUPER::unset_starting(@_);
    
    my $num = () = $self->unset_starting;
    croak "DFA must have exactly one starting state"
        if $num != 1;
}

sub as_min_dfa {
    my $self     = shift()->clone;
    my $N        = $self->num_states;
    my @alphabet = $self->alphabet;

    my ($start)  = $self->get_starting;
    my %final    = map { $_ => 1 } $self->get_accepting;

    my @equiv = map [ (0) x ($_+1), (1) x ($N-$_-1) ], 0 .. $N-1;

    while (1) {
        my $changed = 0;
        for my $s1 (0 .. $N-1) {
        for my $s2 (grep { $equiv[$s1][$_] } 0 .. $N-1) {
            
            if ( 1 == grep defined, @final{$s1, $s2} ) {
                $changed = 1;
                $equiv[$s1][$s2] = 0;
                next;
            }
            
            for my $char (@alphabet) {
                my @t = sort { $a <=> $b } $self->successors([$s1,$s2], $char);
                next if @t == 1;
                
                if (not $equiv[ $t[0] ][ $t[1] ]) {
                    $changed = 1;
                    $equiv[$s1][$s2] = 0;
                }
            }
        }}
        
        last if !$changed;
    }
    
    my $result = (ref $self)->new;
    my %newstate;
    my @classes;
    for my $s (0 .. $N-1) {
        next if exists $newstate{$s};
        
        my @c = ( $s, grep { $equiv[$s][$_] } 0 .. $N-1 );
        push @classes, \@c;

        @newstate{@c} = ( $result->add_states(1) ) x @c;
    }

    for my $c (@classes) {
        my $s = $c->[0];
        for my $char (@alphabet) {
            my ($next) = $self->successors($s, $char);
            $result->add_transition( $newstate{$s}, $newstate{$next}, $char );
        }
    }
    
    $result->set_starting( $newstate{$start} );
    $result->set_accepting( $newstate{$_} )
        for $self->get_accepting;
    
    $result;

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

FLAT::DFA is a subclass of FLAT::NFA and its objects provide the same
methods.
