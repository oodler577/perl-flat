package FLAT::FA;

use strict;
use base 'FLAT';
use Carp;

sub new {
    my $pkg = shift;
    bless {
#        STATE_NAMES => [],
        STATES      => {},
        TRANS       => []
    }, $pkg;
}

sub get_states {
    my $self = shift;
    return keys %{ $self->{STATES} };
}

sub num_states {
    my $self = shift;
    return scalar keys %{ $self->{STATES} };
}

sub is_state {
    my ($self, $state) = @_;
    exists $self->{STATES}->{$state};
}

sub delete_state {
    my ($self, @states) = @_;

    for (@states) {
        carp "'$_' is not a state" if not $self->is_state($_);
    }

    for (@states) {
        my $id = $self->_state_id($_);
        splice @{ $self->{TRANS} }, $id, 1;
        splice @$_, $id, 1 for @{ $self->{TRANS} };
        
        delete $self->{STATES}{$_};

        for ( values %{ $self->{STATES} } ) {
            $_->{num}-- if $_->{num} > $id;
        }
#        splice @{ $self->{STATE_NAMES} }, $id, 1;
    }
}

sub add_state {
    my ($self, @states) = @_;
    
    for (@states) {
        carp "There is already a state called '$_'" if $self->is_state($_);    
    }    
    
    my $id = $self->num_states;
    for (@states) {
        push @$_, undef for @{ $self->{TRANS} };
        push @{ $self->{TRANS} }, [ (undef) x ($id + 1) ];
        $self->{STATES}{$_} = {
            num => $id,
            starting => 0,
            accepting => 0
        };
#        push @{ $self->{STATE_NAMES} }, $_;
        $id++;
    }
}

sub _state_id {
    my ($self, $state) = @_;
    carp "'$state' is not a state" if not $self->is_state($state);
    $self->{STATES}{$state}{num};
}

##############

sub is_starting {
    my ($self, $state) = @_;
    carp "$state is not a state" if not $self->is_state($state);
    return $self->{STATES}->{$state}{starting};
}
sub set_starting {
    my ($self, @states) = @_;

    for (@states) {
        carp "'$_' is not a state" if not $self->is_state($_);
    }
    
    $self->{STATES}->{$_}{starting} = 1 for @states;
}
sub unset_starting {
    my ($self, @states) = @_;

    for (@states) {
        carp "'$_' is not a state" if not $self->is_state($_);
    }
    
    $self->{STATES}->{$_}{starting} = 0 for @states;
}
sub get_starting {
    my $self = shift;
    return grep { $self->is_starting($_) } $self->get_states;
}

##############

sub is_accepting {
    my ($self, $state) = @_;
    carp "$state is not a state" if not $self->is_state($state);
    return $self->{STATES}->{$state}{accepting};
}
sub set_accepting {
    my ($self, @states) = @_;

    for (@states) {
        carp "'$_' is not a state" if not $self->is_state($_);
    }
    
    $self->{STATES}->{$_}{accepting} = 1 for @states;
}
sub unset_accepting {
    my ($self, @states) = @_;

    for (@states) {
        carp "'$_' is not a state" if not $self->is_state($_);
    }
    
    $self->{STATES}->{$_}{accepting} = 0 for @states;
}
sub get_accepting {
    my $self = shift;
    return grep { $self->is_accepting($_) } $self->get_states;
}

###############

sub set_transition {
    my ($self, $state1, $state2, $label) = @_;
    
    $self->{TRANS}[ $self->_state_id($state1) ]
                  [ $self->_state_id($state2) ] = $label;
}

sub get_transition {
    my ($self, $state1, $state2) = @_;
    
    return $self->{TRANS}[ $self->_state_id($state1) ]
                         [ $self->_state_id($state2) ];
}

sub remove_transition {
    my ($self, $state1, $state2) = @_;
    $self->set_transition($state1, $state2, undef);
}

sub successors {
    my ($self, $state, $symb) = @_;
    carp "'$state' is not a state" if not $self->is_state($state);
    
    if (@_ == 3) {
        if (! ref $symb) {
            $symb = do {
                my $temp = $symb;
                sub { $_[0] eq $temp };
            }    
        }
    }
    
    my @states = grep { defined $self->get_transition($state, $_) }
                 $self->get_states;
    return @_ == 2
        ? @states
        : grep { $symb->( $self->get_transition($state, $_) ) } @states;
}

1;
