package FLAT::Regex::WithNegations;
use base 'FLAT::Regex';

use strict;
use Carp;

my $PARSER = FLAT::Regex::Parser->new(qw[ alt concat star negate ]);
sub _parser { $PARSER }

###############################
package FLAT::Regex::Op::negate;
use base "FLAT::Regex::Op";
use Carp;

sub parse_spec { "'~' %s"; }
sub precedence { 15 } # between concat and alternation

sub as_string {
    my ($self, $prec) = @_;
    my $result = "~" . $self->members->as_string($self->precedence);
    return $prec > $self->precedence ? "($result)" : $result;
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new( $item[2] );
}

## note: "reverse" conflicts with perl builtin
sub reverse {
    my $self = shift;
    my $op   = $self->members->reverse;
    __PACKAGE__->new($op);
}

sub is_empty {
    croak "Not implemented for negated regexes";
}

sub has_nonempty_string {
    croak "Not implemented for negated regexes";
}

sub is_finite {
    croak "Not implemented for negated regexes";
}
