package FLAT::NFA;
use strict;
use base 'FLAT::FA';

use FLAT::Transition;

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new(@_);
    $self->{TRANS_CLASS} = "FLAT::Transition";
    return $self;
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

sub as_nfa { $_[0]->clone }

sub union {
    my @nfas = map { $_->as_nfa } @_;
    
    my $result = $nfas[0]->clone;
    
    $result->_swallow($_) for @nfas[1 .. $#nfas];

#    my @newstate = ([ $result->get_states ]);
#    for (1 .. $#nfas) {
#        push @newstate, [ $result->_swallow( $nfas[$_] ) ];
#    }

#    my $newstart = $result->add_states(1);
#    $result->unset_starting($result->get_states);
#    $result->set_starting($newstart);
    
#    for my $nfa_id (0 .. $#nfas) {
#        $result->set_transition( $newstart, $newstate[$nfa_id][$_], "" )
#            for $nfas[$nfa_id]->get_starting;
#    }

    $result;
}

sub concat {
    my @nfas = map { $_->as_nfa } @_;
    
    my $result = $nfas[0]->clone;
    my @newstate = ([ $result->get_states ]);
    my @start = $result->get_starting;

    for (1 .. $#nfas) {
        push @newstate, [ $result->_swallow( $nfas[$_] ) ];
    }

    $result->unset_accepting($result->get_states);
    $result->unset_starting($result->get_states);
    $result->set_starting(@start);
    
    for my $nfa_id (1 .. $#nfas) {
        for my $s1 ($nfas[$nfa_id-1]->get_accepting) {
        for my $s2 ($nfas[$nfa_id]->get_starting) {
            $result->set_transition(
                $newstate[$nfa_id-1][$s1],
                $newstate[$nfa_id][$s2], "" );
        }}
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

###########

sub is_empty {
    my $self = shift;
    
    my @queue = $self->get_starting;
    my %seen = map { $_ => 1 } @queue;
    
    while (@queue) {
        return 0 if grep { $self->is_accepting($_) } @queue;
        @queue = grep { !$seen{$_}++ } $self->successors(\@queue);
    }
    return 1;
}

sub is_finite {
    my $self = shift;
    
    my @alphabet = $self->alphabet;
    return 1 if @alphabet == 0;
    
    my @queue = $self->get_starting;
    my %seen = map { $_ => 1 } @queue;
    
    while (@queue) {
        @queue = grep { !$seen{$_}++ } $self->successors(\@queue);
    }
    
    for my $s ( grep { $self->is_accepting($_) } keys %seen ) {
        @queue = $self->epsilon_closure($s);
        %seen  = map { $_ => 1 } @queue;
        
        while (@queue) {
            my @next = $self->epsilon_closure(
                            $self->successors(\@queue, \@alphabet) );

            return 0 if grep { $s eq $_ } @next;
            @queue = grep { !$seen{$_}++ } @next;
        }
    }
    return 1;
}

sub epsilon_closure {
    my ($self, @states) = @_;
    my %seen  = map { $_ => 1 } @states;
    my @queue = @states;
    
    while (@queue) {
        @queue = grep { ! $seen{$_}++ } $self->successors( \@queue, "" );
    }
    
    keys %seen;
}


sub contains {
    my ($self, $string) = @_;

    my @active = $self->epsilon_closure( $self->get_starting );    
    for my $char (split //, $string) {
        return 0 if ! @active;
        @active = $self->epsilon_closure( $self->successors(\@active, $char) );
    }
    return !! grep { $self->is_accepting($_) } @active;
}

sub trace {
    my ($self, $string) = @_;

    my @trace = ([ $self->epsilon_closure( $self->get_starting ) ]);
    
    for my $char (split //, $string) {
        push @trace,
            [ $self->epsilon_closure( $self->successors($trace[-1], $char) ) ];
    }
    return @trace;
}

############

sub as_graphviz {
    my $self = shift;
    
    my @states = map {
        sprintf qq{%s [label="%s",shape=%s]\n},
            $_,
            ($self->is_starting($_) ? "start" : ""),
            ($self->is_accepting($_) ? "doublecircle" : "circle")
    } $self->get_states;
    
    my @trans;
    for my $s1 ($self->get_states) {
    for my $s2 ($self->get_states) {
        my $t = $self->get_transition($s1, $s2);
        
        if (defined $t) {
            push @trans, sprintf qq[%s -> %s [label="%s"]\n],
                $s1, $s2, $t->as_string;
        }
    }}
    
    return sprintf "digraph G {\ngraph [rankdir=LR]\n\n%s\n%s}\n",
        join("", @states),
        join("", @trans);
}

sub _SET_ID { join "\0", sort { $a <=> $b } @_; }
sub as_dfa {
    my $self = shift;
    
    my $result = FLAT::DFA->new;
    my %subset;
    
    my %final = map { $_ => 1 } $self->get_accepting;
    my @start = sort { $a <=> $b }
                $self->epsilon_closure( $self->get_starting );

    my $start = $subset{ _SET_ID(@start) } = $result->add_states(1);
    $result->set_starting($start);
    $result->set_accepting( $subset{$start} )
        if grep $_, @final{@start};

    my @queue = (\@start);
    while (@queue) {
        my @states = @{ shift @queue };
        my $S      = $subset{ _SET_ID(@states) };
        
        for my $symb ($self->alphabet) {
            my @to = $self->epsilon_closure(
                            $self->successors(\@states, $symb) );

            if ( not exists $subset{_SET_ID(@to)} ) {
                push @queue, \@to;
                my $T = $subset{_SET_ID(@to)} = $result->add_states(1);
                $result->set_accepting($T)
                    if grep $_, @final{@to};
            }
            
            $result->add_transition($S, $subset{ _SET_ID(@to) }, $symb);
        }
    }

    $result;
}

##########

1;
