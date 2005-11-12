package FLAT::Regex;
use strict;
use Parse::RecDescent;
use Carp;

use FLAT::Regex::Op;

use vars '$CHAR';
$CHAR = qr{ [A-Za-z0-9_\!\@\#\$\%\&] | \[[^\]]*\] }x;

my $PARSER = Parse::RecDescent->new(<<'__EOG__') or die;
  regex:
      alt /^\Z/            { $item[1] }
  alt:
      concat(2.. /[+|]/)   { FLAT::Regex::Op::alt->from_parse(@item) }
    | concat               { $item[1] }
  concat:
      star(2.. //)         { FLAT::Regex::Op::concat->from_parse(@item) }
    | star                 { $item[1] }
  star:
      atomic '*'           { FLAT::Regex::Op::star->from_parse(@item) }
    | atomic               { $item[1] }
  atomic:
      "(" alt ")"          { $item[2] }
    | /$FLAT::Regex::CHAR/ { FLAT::Regex::Op::atomic->from_parse(@item) }
__EOG__

#### TODO: error checking in the parse

sub new {
    my ($pkg, $string) = @_;
    my $result = $PARSER->regex($string)
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
#### TODO: parameter checking.

sub as_dfa {
    croak "Not Yet";
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
    croak "Not Yet";
}

sub complement {
    croak "Not Yet";
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
