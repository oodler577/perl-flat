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
    wantarray ? @$self[0 .. $#$self] : $self->[0];
}


#################################
#### regex operators / components

package FLAT::Regex::Op::atomic;
use base 'FLAT::Regex::Op';

my $EPSILON = "[]";
my $NULL    = "#";

sub as_string {
    $_[0]->members;
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new( $item[1] );
}

sub reverse {
    $_[0];
}

sub is_empty {
    $_[0]->members eq $NULL;
}

sub has_nonempty_string {
    my $self = shift;
    $self->members ne $EPSILON and $self->members ne $NULL;
}

sub is_finite {
    1
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

sub is_empty {
    0
}

sub has_nonempty_string {
    $_[0]->members->has_nonempty_string;
}

sub is_finite {
    ! $_[0]->members->has_nonempty_string;
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

sub is_empty {
    my $self = shift;
    my @members = $self->members;
    for (@members) {
        return 1 if $_->is_empty;
    }
    return 0;
}

sub has_nonempty_string {
    my $self = shift;
    return 0 if $self->is_empty;
    
    my @members = $self->members;
    for (@members) {
        return 1 if $_->has_nonempty_string;
    }
    return 0;
}

sub is_finite {
    my $self = shift;
    return 1 if $self->is_empty;
    
    my @members = $self->members;
    for (@members) {
        return 0 if not $_->is_finite;
    }
    return 1;
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

sub is_empty {
    my $self = shift;
    my @members = $self->members;
    for (@members) {
        return 0 if not $_->is_empty;
    }
    return 1;
}

sub has_nonempty_string {
    my $self = shift;
    my @members = $self->members;
    for (@members) {
        return 1 if $_->has_nonempty_string;
    }
    return 0;
}

sub is_finite {
    my $self = shift;
    my @members = $self->members;
    for (@members) {
        return 0 if not $_->is_finite;
    }
    return 1;
}
1;
