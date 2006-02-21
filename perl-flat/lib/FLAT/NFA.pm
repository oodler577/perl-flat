package FLAT::NFA;
use strict;
use base 'FLAT::FA';

sub as_nfa { $_[0]->clone }

sub epsilon_closure {
    my ($self, @states) = @_;
    my %seen  = map { $_ => 1 } @states;
    my @queue = @states;
    
    while (@queue) {
        @queue = grep { ! $seen{$_}++ } $self->successors( \@queue, "" );
    }
    
    keys %seen;
}

sub union {
    my @nfas = map { $_->as_nfa } @_;
    
    my $result = $nfas[0]->clone;
    my @newstate = ([ $result->get_states ]);
    
    for (1 .. $#nfas) {
        push @newstate, [ $result->add_states( $nfas[$_]->num_states ) ];
    }

    my ($newstart) = $result->add_states(1);
    $result->unset_starting($result->get_states);
    $result->set_starting($newstart);
    
    for my $nfa_id (0 .. $#nfas) {
        for my $s1 ($nfas[$nfa_id]->get_states) {
        for my $s2 ($nfas[$nfa_id]->get_states) {
            $result->set_transition(
                    $newstate[$nfa_id][$s1],
                    $newstate[$nfa_id][$s2],
                    $nfas[$nfa_id]->get_transition($s1, $s2) );
        }}
    
        $result->set_transition( $newstart, $newstate[$nfa_id][$_], "" )
            for $nfas[$nfa_id]->get_starting;

        $result->set_accepting(
            @{$newstate[$nfa_id]}[ $nfas[$nfa_id]->get_accepting ] );
    }

    $result;
}

sub concat {
    my @nfas = map { $_->as_nfa } @_;
    
    my $result = $nfas[0]->clone;
    my @newstate = ([ $result->get_states ]);

    for (1 .. $#nfas) {
        push @newstate, [ $result->add_states( $nfas[$_]->num_states ) ];
    }

    $result->unset_accepting($result->get_states);
    
    for my $nfa_id (0 .. $#nfas) {
        for my $s1 ($nfas[$nfa_id]->get_states) {
        for my $s2 ($nfas[$nfa_id]->get_states) {
            $result->set_transition(
                    $newstate[$nfa_id][$s1],
                    $newstate[$nfa_id][$s2],
                    $nfas[$nfa_id]->get_transition($s1, $s2) );
        }}

        if ($nfa_id > 0) {
            for my $s1 ($nfas[$nfa_id-1]->get_accepting) {
            for my $s2 ($nfas[$nfa_id]->get_starting) {
                $result->set_transition(
                    $newstate[$nfa_id-1][$s1],
                    $newstate[$nfa_id][$s2], "" );
            }}
        }
    }

    $result->set_accepting(
        @{$newstate[-1]}[ $nfas[-1]->get_accepting ] );

    $result;
}

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

sub singleton {
    my ($class, $char) = @_;
    my $nfa = $class->new;

    if (not defined $char) {
        $nfa->add_states(1);
        $nfa->set_starting(0);
    } elsif ($char eq "") {
        $nfa->add_states(1);
        $nfa->set_starting(0);
        $nfa->set_accepting(0);
    } else {
        $nfa->add_states(2);
        $nfa->set_starting(0);
        $nfa->set_accepting(1);
        $nfa->set_transition(0, 1, $char);
    }
    return $nfa;
}

sub as_graphviz {
    my $self = shift;
    
    my @states = map {
        sprintf "%s [shape=%s]\n",
            $_, $self->is_accepting($_) ? "doublecircle" : "circle"
    } $self->get_states;
    
    my @trans;
    for my $s1 ($self->get_states) {
    for my $s2 ($self->get_states) {
        my $t = $self->get_transition($s1, $s2);
        
        if (defined $t) {
            push @trans, sprintf qq[%s -> %s [label="%s"]\n],
                $s1, $s2, length $t ? $t : "epsilon";
        }
    }}
    
    return sprintf "digraph G {\ngraph [rankdir=LR]\n\n%s\n%s}\n",
        join("", @states),
        join("", @trans);
}

1;
