package FLAT::Regex::WithExtraOps;
use base 'FLAT::Regex';

use strict;
use Carp;

my $PARSER = FLAT::Regex::Parser->new(qw[ alt concat star negate shuffle ]);
sub _parser { $PARSER }

#### Precedence
# 30 ::star
# 20 ::concat
# 15 ::negate   <---<<
# 12 ::shuffle  <---<<
# 10 ::alt
# 0  ::atomic

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

###############################
package FLAT::Regex::Op::shuffle;
use base 'FLAT::Regex::Op';

sub parse_spec { "%s(2.. /[&]/)" }
sub precedence { 12 }

sub as_string {
    my ($self, $prec) = @_;
    my $result = join "&",
                 map { $_->as_string($self->precedence) }
                 $self->members;
    return $prec > $self->precedence ? "($result)" : $result;
}

sub shuffle {
    my $self = shift;
    # will handle shuffle operatation
}

sub as_pfa {
    my $self = shift;
    # ... will turn shuffle instance into PFA - similar to Op->alt->as_nfa,
    # but a tiny different...if I may offer you a riddle :) 
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
        return 1 if $_->is_empty;
    }
    return 0;
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
