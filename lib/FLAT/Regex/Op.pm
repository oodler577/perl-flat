package FLAT::Regex::Op;
use strict;
use Carp ();
use Scalar::Util qw(blessed);
use Hash::Util::FieldHash qw(fieldhash);
fieldhash my %SOURCE_SPAN;

sub source_span {
    my ($self)=@_;
    return exists($SOURCE_SPAN{$self}) ? {%{$SOURCE_SPAN{$self}}} : undef;
}
sub _set_source_span {
    my ($self,$span)=@_;
    $SOURCE_SPAN{$self}={%$span};
    return $self;
}


sub new {
    my $pkg = shift;
    if ($pkg eq 'FLAT::Regex::Op::atomic') {
        Carp::croak('an atom requires exactly one key or symbol') unless @_==1;
        Carp::croak('reference atoms must be FLAT::Symbol::Token objects')
            if ref($_[0]) && !(blessed($_[0]) && $_[0]->isa('FLAT::Symbol::Token'));
    }
    elsif ($pkg =~ /::(?:star|negate)\z/) {
        Carp::croak('unary operator requires exactly one AST node') unless @_==1
            && blessed($_[0]) && $_[0]->isa('FLAT::Regex::Op');
    }
    elsif ($pkg =~ /::(?:alt|concat|shuffle)\z/) {
        Carp::croak('operator requires AST node operands') unless @_ && !grep {
            !blessed($_) || !$_->isa('FLAT::Regex::Op') } @_;
    }
    ## flatten alike operations, i.e, "a+(b+c)" into "a+b+c"
    my @flat = map {UNIVERSAL::isa($_, $pkg) ? $_->members : $_} @_;

    bless \@flat, $pkg;
}

sub members {
    my $self = shift;
    wantarray ? @$self[0 .. $#$self] : $self->[0];
}

#################################
#### regex operators / components

package FLAT::Regex::Op::atomic;
use parent 'FLAT::Regex::Op';

sub key {
    my $value=$_[0]->members;
    return ref($value) ? $value->key : $value;
}
sub symbol {
    my $value=$_[0]->members;
    return ref($value) ? $value : undef;
}

sub as_string {
    my $t = $_[0]->key;
    return "#" if not defined $t;
    Carp::croak("cannot represent a key containing ']' in formal-expression text") if index($t,']')>=0;
    return $t =~ /\A[A-Za-z0-9_]\z/ ? $t : "[$t]";
}

sub as_perl_regex {
    my $r = $_[0]->key;

    return "(?!)" if not defined $r;

    $r = quotemeta $r;
    return $r =~ /^\w$/ ? $r : "(?:$r)";
}

sub as_nfa {
    FLAT::NFA->singleton($_[0]->members);
}

sub as_pfa {
    FLAT::PFA->singleton($_[0]->members);
}

sub from_parse {
    my ($pkg, @item) = @_;
    my $i = $item[1];

    return $pkg->new("")    if $i eq "[]";
    return $pkg->new(undef) if $i eq "#";

    $i =~ s/^\[|\]$//g;

    return $pkg->new($i);
}

sub reverse {
    $_[0];
}

sub is_empty {
    not defined $_[0]->members;
}

sub has_nonempty_string {
    my $self = shift;
    defined $self->key and length $self->key;
}

sub is_finite {
    1
}

##############################
package FLAT::Regex::Op::star;
use parent 'FLAT::Regex::Op';

sub parse_spec {"%s '*'"}
sub precedence {30}

sub as_string {
    my ($self, $prec) = @_;
    my $result = $self->members->as_string($self->precedence) . "*";
    return $prec > $self->precedence ? "($result)" : $result;
}

sub as_perl_regex {
    my ($self, $prec) = @_;
    my $result = $self->members->as_perl_regex($self->precedence) . "*";
    return $prec > $self->precedence ? "(?:$result)" : $result;
}

sub as_nfa {
    my $self = shift;
    $self->members->as_nfa->kleene;
}

sub as_pfa {
    my $self = shift;
    $self->members->as_pfa->kleene;
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new($item[1]);
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
    !$_[0]->members->has_nonempty_string;
}

################################
package FLAT::Regex::Op::concat;
use parent 'FLAT::Regex::Op';

sub parse_spec {"%s(2..)";}
sub precedence {20}

sub as_string {
    my ($self, $prec) = @_;
    my $result = join "", map {$_->as_string($self->precedence)} $self->members;
    return $prec > $self->precedence ? "($result)" : $result;
}

sub as_perl_regex {
    my ($self, $prec) = @_;
    my $result = join "", map {$_->as_perl_regex($self->precedence)} $self->members;
    return $prec > $self->precedence ? "(?:$result)" : $result;
}

sub as_nfa {
    my $self = shift;
    my @parts = map {$_->as_nfa} $self->members;
    $parts[0]->concat(@parts[1 .. $#parts]);
}

sub as_pfa {
    my $self = shift;
    my @parts = map {$_->as_pfa} $self->members;
    $parts[0]->concat(@parts[1 .. $#parts]);
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new(@{$item[1]});
}

## note: "reverse" conflicts with perl builtin
sub reverse {
    my $self = shift;
    my @ops = CORE::reverse map {$_->reverse} $self->members;
    __PACKAGE__->new(@ops);
}

sub is_empty {
    my $self    = shift;
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
use parent 'FLAT::Regex::Op';

sub parse_spec {"%s(2.. /[+|]/)"}
sub precedence {10}

sub as_string {
    my ($self, $prec) = @_;
    my $result = join "+", map {$_->as_string($self->precedence)} $self->members;
    return $prec > $self->precedence ? "($result)" : $result;
}

sub as_perl_regex {
    my ($self, $prec) = @_;
    my $result = join "|", map {$_->as_perl_regex($self->precedence)} $self->members;
    return $prec > $self->precedence ? "(?:$result)" : $result;
}

sub as_nfa {
    my $self = shift;
    my @parts = map {$_->as_nfa} $self->members;
    $parts[0]->union(@parts[1 .. $#parts]);
}

sub as_pfa {
    my $self = shift;
    my @parts = map {$_->as_pfa} $self->members;
    $parts[0]->union(@parts[1 .. $#parts]);
}

sub from_parse {
    my ($pkg, @item) = @_;
    $pkg->new(@{$item[1]});
}

sub reverse {
    my $self = shift;
    my @ops = map {$_->reverse} $self->members;
    __PACKAGE__->new(@ops);
}

sub is_empty {
    my $self    = shift;
    my @members = $self->members;
    for (@members) {
        return 0 if not $_->is_empty;
    }
    return 1;
}

sub has_nonempty_string {
    my $self    = shift;
    my @members = $self->members;
    for (@members) {
        return 1 if $_->has_nonempty_string;
    }
    return 0;
}

sub is_finite {
    my $self    = shift;
    my @members = $self->members;
    for (@members) {
        return 0 if not $_->is_finite;
    }
    return 1;
}
1;

__END__

=head1 NAME

FLAT::Regex::Op - formal-expression AST nodes

=head1 CONTRACT

Existing blessed-array nodes and C<members> remain the representation.
Atoms carry exactly one literal key, undef (empty language), an empty string
(epsilon), or a L<FLAT::Symbol::Token>. Unary operators require one AST node;
union, concatenation and shuffle require nonempty node lists. Associative
operators flatten nested operands as before. Constructors reject raw data
references in atoms; wrap payloads explicitly in a symbol token.

Atoms expose C<key> and C<symbol> (the latter returns undef for string atoms).
Formal-expression text and Perl pattern conversion use matching keys, never
display labels. Automaton conversion retains explicit token bindings and payload
identity. Keys containing a closing bracket cannot be represented by the current
formal text syntax; C<as_string> rejects them explicitly. Programmatic automaton
and AST operations can still use such keys.

C<source_span> returns a copy of optional parser location metadata. It counts
characters, not bytes, with an exclusive end offset and one-based line/column.
The metadata is weakly associated with nodes, contains no input text, and does
not survive serialization. Programmatic nodes normally have no source span;
transformed nodes do not acquire invented source locations. Source spans are
not execution-occurrence IDs or a lossless concrete syntax tree.

=cut
