package FLAT::Regex;
use strict;
use Parse::RecDescent;
use Carp;

use vars '$CHAR';
$CHAR = qr{ [A-Za-z0-9_\!\@\#\$\%\&] | \[[^\]]*\] }x;

my $PARSER = Parse::RecDescent->new(<<'__EOG__') or die;

  regex:
      alt /^\Z/            { $item[1] }
  alt:
      concat(2.. /[+|]/)   { FLAT::Regex::op::alt->_init( @{$item[1]} ) }
    | concat               { $item[1] }
  concat:
      star(2..)            { FLAT::Regex::op::concat->_init( @{$item[1]} ) }
    | star                 { $item[1] }
  star :
      atomic '*'           { FLAT::Regex::op::star->_init( $item[1] ) }
    | atomic               { $item[1] }
  atomic:
      "(" alt ")"          { $item[2] }
    | /$FLAT::Regex::CHAR/ { FLAT::Regex::op::atomic->_init( $item[1] ) }

__EOG__

#### TODO: error checking in the parse

sub new {
    my ($pkg, $string) = @_;
    my $result = $PARSER->regex($string)
        or croak qq[``$string'' is not a valid regular expression];
    return $result;
}

sub _init {
    my $pkg = shift;
    ## flatten alike operations, i.e, "a+(b+c)" into "a+b+c"
    my @flat = map { UNIVERSAL::isa($_, $pkg) ? $_->_members : $_ } @_;

    bless \@flat, $pkg;
}
sub _members {
    my $self = shift;
    @$self[0 .. $#$self];
}

use overload '""' => 'as_string';
sub as_string {
    $_[0]->_as_string(0);
}

sub as_regex {
    $_[0];
}

#### regular language standard interface implementation:
#### TODO: parameter checking.

sub union {
    FLAT::Regex::op::alt->_init( map { $_->as_regex } @_ );
}

sub intersect {
    croak "Not Yet";
}

sub complement {
    croak "Not Yet";
}

sub concat {
    FLAT::Regex::op::concat->_init( map { $_->as_regex } @_ );
}

sub kleene {
    FLAT::Regex::op::star->_init( $_[0] );
}

## note: "reverse" conflicts with perl builtin
sub reverse {
    my $self = shift;
    
    $self->isa("FLAT::Regex::op::atomic")
        and return $self;

    $self->isa("FLAT::Regex::op::concat") 
        and return FLAT::Regex::op::concat->_init(
            CORE::reverse map { $_->reverse } $self->_members
        );
        
    $self->isa("FLAT::Regex::op::alt")
        and return FLAT::Regex::op::alt->_init(
            map { $_->reverse } $self->_members
        );

    $self->isa("FLAT::Regex::op::star")
        and return FLAT::Regex::op::star->_init( $self->_members->reverse );
}

#### regex operators / components

@FLAT::Regex::op::atomic::ISA =
@FLAT::Regex::op::concat::ISA =
@FLAT::Regex::op::alt::ISA    =
@FLAT::Regex::op::star::ISA   = qw[FLAT::Regex];

sub FLAT::Regex::op::atomic::_as_string {
    $_[0][0]
}

sub FLAT::Regex::op::concat::_as_string {
    my ($self, $prec) = @_;
    my $result = join "", map { $_->_as_string(2) } $self->_members;
    return $prec > 2 ? "($result)" : $result;
}

sub FLAT::Regex::op::alt::_as_string {
    my ($self, $prec) = @_;
    my $result = join "+", map { $_->_as_string(1) } $self->_members;
    return $prec > 1 ? "($result)" : $result;
}

sub FLAT::Regex::op::star::_as_string {
    my $self   = shift;
    my $result = $self->[0]->_as_string(3) . "*";
    return $result;
}

__END__

TODO: documentation
