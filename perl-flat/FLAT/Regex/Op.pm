package FLAT::Regex::Op;
use strict;

sub new {
    my $pkg = shift;
    ## flatten alike operations, i.e, "a+(b+c)" into "a+b+c"
    my @flat = map { UNIVERSAL::isa($_, $pkg) ? $_->members : $_ } @_;

    bless \@flat, $pkg;
}
sub members {
    my $self = shift;
    @$self[0 .. $#$self];
}


#################################
#### regex operators / components

package FLAT::Regex::Op::atomic;
use base 'FLAT::Regex::Op';

sub as_string {
    $_[0][0]
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new( $item[1] );
}

sub reverse {
    $_[0];
}


##############################
package FLAT::Regex::Op::star;
use base 'FLAT::Regex::Op';

sub parse_spec { "%s '*'" }
sub precedence { 30 }

sub as_string {
    my ($self, $prec) = @_;
    my $result = $self->members->as_string($self->precedence) . "*";
    return $prec > $self->precedence ? "($result)" : $result;
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new( $item[1] );
}

sub reverse {
    my $self = shift;
    my $op   = $self->members->reverse;
    __PACKAGE__->new($op);
}


################################
package FLAT::Regex::Op::concat;
use base 'FLAT::Regex::Op';

sub parse_spec { "%s(2..)"; }
sub precedence { 20 }

sub as_string {
    my ($self, $prec) = @_;
    my $result = join "",
                 map { $_->as_string($self->precedence) }
                 $self->members;
    return $prec > $self->precedence ? "($result)" : $result;
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new( @{ $item[1] } );
}

## note: "reverse" conflicts with perl builtin
sub reverse {
    my $self = shift;
    my @ops  = CORE::reverse map { $_->reverse } $self->members;
    __PACKAGE__->new(@ops);
}

#############################
package FLAT::Regex::Op::alt;
use base 'FLAT::Regex::Op';

sub parse_spec { "%s(2.. /[+|]/)" }
sub precedence { 10 }

sub as_string {
    my ($self, $prec) = @_;
    my $result = join "+",
                 map { $_->as_string($self->precedence) }
                 $self->members;
    return $prec > $self->precedence ? "($result)" : $result;
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new( @{ $item[1] } );
}

sub reverse {
    my $self = shift;
    my @ops  = map { $_->reverse } $self->members;
    __PACKAGE__->new(@ops);
}

1;
