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


sub delete_state {
    my ($self, @states) = @_;

    $self->_assert_states(@states);

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
    
    $self->_assert_non_states(@states);
    
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
    $self->_assert_states($state);
    $self->{STATES}{$state}{num};
}

##############

sub is_starting {
    my ($self, $state) = @_;
    $self->_assert_states($state);
    return $self->{STATES}->{$state}{starting};
}
sub set_starting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}->{$_}{starting} = 1 for @states;
}
sub unset_starting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}->{$_}{starting} = 0 for @states;
}
sub get_starting {
    my $self = shift;
    return grep { $self->is_starting($_) } $self->get_states;
}

##############

sub is_accepting {
    my ($self, $state) = @_;
    $self->_assert_states($state);
    return $self->{STATES}->{$state}{accepting};
}
sub set_accepting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
    $self->{STATES}->{$_}{accepting} = 1 for @states;
}
sub unset_accepting {
    my ($self, @states) = @_;
    $self->_assert_states(@states);
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
    
    my @states = ref $state eq 'ARRAY'
        ? @$state
        : ($state);
        
    $self->_assert_states(@states);
    
    if (@_ == 3 and !ref $symb) {
        my $cmp = $symb;
        
        if (defined $cmp) {
            $symb = sub { defined $_[0] and $cmp eq $_[0] };
        } else {
            $symb = sub { not defined $_[0] };
        }
    } elsif (@_ == 2) {
        $symb = sub { defined $_[0] };
    }
    
    my %succ;
    
    for my $s (@states) {
        $succ{$_}++
            for grep { $symb->( $self->get_transition($s, $_) ) }
                $self->get_states;
    }
    return keys %succ;
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

sub _fresh_state_names {
    my ($self, $num) = @_;
    
    my @names;
    while (@names < $num) {
        my $name = join "", map { (0 .. 9, 'a' .. 'z')[rand 36] } 1 .. 8;
        push @names, $name if not $self->is_state($name);
    }
    return wantarray ? @names : $names[0];
}

1;
