package FLAT::FA;

use strict;
use base 'FLAT';
use Carp;

use FLAT::Transition;

sub new {
    my $pkg = shift;
    bless {
        STATES => [],
        TRANS  => [],
        ALPHA  => {}
    }, $pkg;
}

sub get_states {
    my $self = shift;
    return 0 .. ($self->num_states - 1);
}

sub num_states {
    my $self = shift;
    return scalar @{ $self->{STATES} };
}

sub is_state {
    my ($self, $state) = @_;
    exists $self->{STATES}->[$state];
}

sub _assert_states {
    my ($self, @states) = @_;
    for (@states) {
        croak "'$_' is not a state" if not $self->is_state($_);
    }
}
sub _assert_non_states {
    my ($self, @states) = @_;
    for (@states) {
        croak "There is already a state called '$_'" if $self->is_state($_);    
    }
}


sub delete_states {
    my ($self, @states) = @_;

    $self->_assert_states(@states);

    for my $s ( sort { $b <=> $a } @states ) {
        $self->_decr_alphabet($_)
            for @{ splice @{ $self->{TRANS} }, $s, 1  };

        $self->_decr_alphabet( splice @$_, $s, 1 )
            for @{ $self->{TRANS} };
            
        splice @{ $self->{STATES} }, $s, 1;
    }
}

sub add_states {
    my ($self, $num) = @_;
    my $id = $self->num_states;
    
    for my $s ( $id .. ($id+$num-1) ) {
        push @$_, undef for @{ $self->{TRANS} };
        push @{ $self->{TRANS} }, [ (undef) x ($s+1) ];
        push @{ $self->{STATES} }, {
            starting => 0,
            accepting => 0
        };
    }
    
    return wantarray ? ($id .. ($id+$num-1))
                     : $id+$num-1;
}

##############

sub is_starting {
    my ($self, $state) = @_;
    $self->_assert_states($state);
    return $self->{STATES}[$state]{starting};
}
sub set_starting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}[$_]{starting} = 1 for @states;
}
sub unset_starting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}[$_]{starting} = 0 for @states;
}
sub get_starting {
    my $self = shift;
    return grep { $self->is_starting($_) } $self->get_states;
}

##############

sub is_accepting {
    my ($self, $state) = @_;
    $self->_assert_states($state);
    return $self->{STATES}[$state]{accepting};
}
sub set_accepting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}[$_]{accepting} = 1 for @states;
}
sub unset_accepting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}[$_]{accepting} = 0 for @states;
}
sub get_accepting {
    my $self = shift;
    return grep { $self->is_accepting($_) } $self->get_states;
}

###############

sub _decr_alphabet {
    my ($self, $t) = @_;
    return if not defined $t;
    for ($t->alphabet) {
        delete $self->{ALPHA}{$_} if not --$self->{ALPHA}{$_};
    }
}
sub _incr_alphabet {
    my ($self, $t) = @_;
    return if not defined $t;
    $self->{ALPHA}{$_}++ for $t->alphabet;
}

sub set_transition {
    my ($self, $state1, $state2, @label) = @_;
    $self->remove_transition($state1, $state2);

    @label = grep defined, @label;
    return if not @label;
    
    my $t = $self->{TRANS_CLASS}->new(@label);
    $self->_incr_alphabet($t);

    $self->{TRANS}[$state1][$state2] = $t;
}

sub add_transition {
    my ($self, $state1, $state2, @label) = @_;

    @label = grep defined, @label;
    return if not @label;

    my $t = $self->get_transition($state1, $state2);
    $self->_decr_alphabet($t);
    
    if (!$t) {
        $t = $self->{TRANS}[$state1][$state2] = $self->{TRANS_CLASS}->new;
    }
    
    $t->add(@label);
    $self->_incr_alphabet($t);
}

sub get_transition {
    my ($self, $state1, $state2) = @_;
    $self->_assert_states($state1, $state2);
    
    $self->{TRANS}[$state1][$state2];
}

sub remove_transition {
    my ($self, $state1, $state2) = @_;

    $self->_decr_alphabet( $self->{TRANS}[$state1][$state2] );
    $self->{TRANS}[$state1][$state2] = undef;
}

sub successors {
    my ($self, $state, $symb) = @_;
    
    my @states = ref $state eq 'ARRAY' ? @$state : ($state);
    my @symbs  = defined $symb
                  ? (ref $symb  eq 'ARRAY' ? @$symb  : ($symb))
                  : ();
        
    $self->_assert_states(@states);
    
    my %succ;
    for my $s (@states) {
        $succ{$_}++
            for grep { my $t = $self->{TRANS}[$s][$_];
                       defined $t && (@symbs ? $t->does(@symbs) : 1) } $self->get_states;
    }
    
    return keys %succ;
}

sub alphabet {
    my $self = shift;
    grep length, keys %{ $self->{ALPHA} };
}

############
sub prune {
    my $self = shift;
    
    my @queue = $self->get_starting;
    my %seen  = map { $_ => 1 } @queue;
    
    while (@queue) {
        @queue = grep { ! $seen{$_}++ } $self->successors(\@queue);
    }
    
    my @useless = grep { !$seen{$_} } $self->get_states;
    $self->delete_state(@useless);
    
    return @useless;
}


############

use Storable 'dclone';
sub clone {
    dclone( $_[0] );
}

sub _transpose {
    my $self = shift;
    my $N = $self->num_states - 1;
    
    $self->{TRANS} = [
        map {
            my $row = $_; 
            [ map { $_->[$row] } @{$self->{TRANS}} ]
        } 0 .. $N
    ];
}

## add an FA's states & transitions to this FA (as disjoint union)
sub _swallow {
    my ($self, $other) = @_;
    my $N1 = $self->num_states;
    my $N2 = $other->num_states;
    
    push @$_, (undef) x $N2
        for @{ $self->{TRANS} };

    push @{ $self->{TRANS} }, [ (undef) x $N1, @{ clone $_ } ]
        for @{ $other->{TRANS} };

    push @{ $self->{STATES} }, @{ clone $other->{STATES} };
    
    $self->{ALPHA}{$_} += $other->{ALPHA}{$_}
        for keys %{ $other->{ALPHA} };
    
    return map { $_ + $N1 } $other->get_states;
}

1;
