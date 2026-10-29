package FLAT::Transition::Simple;

use parent 'FLAT::Transition';

use strict;
use Carp;
use Scalar::Util qw(blessed);

sub _key {
    my ($value) = @_;
    return $value unless ref $value;
    croak 'reference labels must be wrapped in FLAT::Symbol::Token'
        unless blessed($value) && $value->isa('FLAT::Symbol::Token');
    return $value->key;
}


sub new {
    my ($pkg, @things) = @_;
    bless {map {_key($_) => 1} @things}, $pkg;
}

sub does {
    my ($self, @things) = @_;
    return 1 if @things == 0;
    return !!grep $self->{_key($_)}, @things;
}

sub add {
    my ($self, @things) = @_;
    @things = map { _key($_) } @things;
    @$self{@things} = (1) x @things;
}

sub delete {
    my ($self, @things) = @_;
    delete $self->{_key($_)} for @things;
}

sub alphabet {
    my $self = shift;
    sort {$a cmp $b} keys %$self;
}

sub as_string {
    my $self = shift;
    join ",", map {length $_ ? $_ : "epsilon"} $self->alphabet;
}

1;
