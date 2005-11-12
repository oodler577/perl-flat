package FLAT::Regex;
use strict;
use Carp;

use FLAT::Regex::Parser;
use FLAT::Regex::Op;

my $PARSER = FLAT::Regex::Parser->new(qw[ alt concat star ]);
#### TODO: error checking in the parse

sub new {
    my ($pkg, $string) = @_;
    my $result = $PARSER->parse($string)
        or croak qq[``$string'' is not a valid regular expression];

    $pkg->_from_op( $result );
}

sub _from_op {
    my ($proto, $op) = @_;
    $proto = ref $proto || $proto; ## I really do want this
    
    bless [ $op ], $proto;
}

sub op {
    $_[0][0];
}

use overload '""' => 'as_string';
sub as_string {
    $_[0]->op->as_string(0);
}


#### regular language standard interface implementation:
#### TODO: parameter checking?

sub as_dfa {
    croak "FLAT::Regex::as_dfa? Not Yet";
}

sub as_nfa {
    croak "FLAT::Regex::as_nfa? Not Yet";
}


sub as_regex {
    $_[0];
}

sub union {
    my $self = $_[0];
    my $op   = FLAT::Regex::op::alt->new( map { $_->as_regex->op } @_ );
    $self->_from_op($op);
}

sub intersect {
    my @dfas = map { $_->as_dfa } @_;
    my $self = shift @dfas;
    $self->intersect(@dfas)->as_regex;
}

sub complement {
    my $self = shift;
    $self->as_dfa->complement->as_regex;
}

sub concat {
    my $self = $_[0];
    my $op = FLAT::Regex::op::concat->new( map { $_->as_regex->op } @_ );
    $self->_from_op($op);
}

sub kleene {
    my $self = shift;
    my $op   = FLAT::Regex::op::star->new( $self->op );
    $self->_from_op($op);
}

sub reverse {
    my $self = shift;
    my $op   = $self->op->reverse;
    $self->_from_op($op);
}

1;

__END__

TODO: documentation
