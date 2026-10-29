package FLAT::Regex;
use parent 'FLAT';
use strict;
use Carp;
use Scalar::Util ();

use FLAT::Regex::Parser;
use FLAT::Regex::Op;

my $PARSER = FLAT::Regex::Parser->new(qw[ alt concat star ]);

sub _parser { $PARSER }

sub new {
    my ( $pkg, $string ) = @_;
    my $result = $pkg->_parser->parse_or_die($string);

    $pkg->_from_op($result);
}

sub _from_op {
    my ( $proto, $op ) = @_;
    $proto = ref $proto || $proto;    ## I really do want this

    bless [$op], $proto;
}

sub from_op {
    my ($class,$op)=@_;
    croak 'expected a FLAT::Regex::Op node'
        unless Scalar::Util::blessed($op) && $op->isa('FLAT::Regex::Op');
    return $class->_from_op($op);
}
sub atom {
    my ($class,$key)=@_;
    return $class->from_op(FLAT::Regex::Op::atomic->new($key));
}
sub epsilon { return $_[0]->atom('') }
sub empty { return $_[0]->atom(undef) }
sub contains_tokens { return $_[0]->as_pfa->as_nfa->contains_tokens($_[1]) }

sub op {
    $_[0][0];
}

use overload '""' => 'as_string';

sub as_string {
    $_[0]->op->as_string(0);
}

sub as_perl_regex {
    my ( $self, %opts ) = @_;

    my $fmt = $opts{anchored} ? '(?:\A%s\z)' : '(?:%s)';
    return sprintf $fmt, $self->op->as_perl_regex(0);
}

sub contains {
    my ( $self, $string ) = @_;
    $string =~ $self->as_perl_regex( anchored => 1 );
}

sub as_nfa {
    $_[0]->op->as_nfa;
}

sub as_pfa {
    require FLAT::PFA;
    $_[0]->op->as_pfa;
}

#### regular language standard interface implementation:
#### TODO: parameter checking?

sub as_regex {
    $_[0];
}

sub union {
    my $self = $_[0];
    my $op   = FLAT::Regex::Op::alt->new( map { $_->as_regex->op } @_ );
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
    my $op   = FLAT::Regex::Op::concat->new( map { $_->as_regex->op } @_ );
    $self->_from_op($op);
}

sub kleene {
    my $self = shift;
    my $op   = FLAT::Regex::Op::star->new( $self->op );
    $self->_from_op($op);
}

sub reverse {
    my $self = shift;
    my $op   = $self->op->reverse;
    $self->_from_op($op);
}

sub is_empty {
    $_[0]->op->is_empty;
}

sub is_finite {
    $_[0]->op->is_finite;
}

1;

__END__

=head1 NAME

FLAT::Regex - Regular expressions

=head1 SYNOPSIS

A FLAT::Regex object is a regular expression.

=head1 USAGE

In addition to implementing the interface specified in L<FLAT>, FLAT::Regex
objects provide the following regex-specific methods:

=over

=item FLAT::Regex-E<gt>new($string)

Returns a regex object representing the expression given in $string. C<|>
and C<+> can both be used to denote alternation. C<*> denotes Kleene star, and
parentheses can be used for grouping. No other features or shortcut notation
is currently supported (character classes, {n,m} repetition, etc).

Whitespaces is ignored. To specify a literal space, use C<[ ]>. This syntax
can also be used to specify atomic "characters" longer than a single
character. For example, the expression:

  [foo]abc[bar]*

is treated as a regular expression over the symbols "a", "b", "c", "foo",
and "bar". In particular, this means that when the regular expression is
reversed, "foo" and "bar" remain the same (i.e, they do not become "oof" and
"rab").

The empty regular expression (epsilon) is written as C<[]>, and the null
regular expression (sometimes called phi) is specified with the C<#>
character. To specify a literal hash-character, use C<[#]>. Including
literal square bracket characters is currently not supported.

The expression "" (or any string containing only whitespace) is not a valid
FLAT regex expression. Either C<[]> or C<#> are probably what was intended.

=item $regex-E<gt>as_string

Returns the string representation of the regex, in the same format as above.
It is NOT necessarily true that

  FLAT::Regex->new($string)->as_string

is identical to $string, especially if $string contains whitespace or
redundant parentheses.

=item $regex-E<gt>as_perl_regex

=item $regex-E<gt>as_perl_regex(anchored => $bool);

Returns an equivalent Perl regular expression. If the "anchored" option
is set to a true value, the regular expression will be anchored with
C<\A> and C<\z>. The default behavior is to omit the anchors.

The Perl regex will not contain capturing parentheses. "Extended" characters
that are written as "[char]" in FLAT regexes will be written without the
square brackets in the corresponding Perl regex. So the following:

  FLAT::Regex->new("[foo][bar]*")->as_perl_regex

will be equal to "(?:foo(?:bar)*)".

=back

=head1 AUTHORS & ACKNOWLEDGEMENTS

FLAT is written by Mike Rosulek E<lt>mike at mikero dot comE<gt> and 
B. Estarde E<lt>estradb at gmail dot comE<gt>.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 PARSING AND PROGRAMMATIC ASTS

C<new($text)> uses the hand-written L<FLAT::Regex::Parser>. Syntax failures throw
L<FLAT::Regex::ParseError> with character offset, line and column. Syntax and
precedence follow the existing formal-language grammar; these are not Perl
regular-expression literals. The parser's limits do not bound FA compilation.

C<atom($key_or_symbol)> constructs a literal atom without parsing display text.
C<epsilon> and C<empty> construct the empty word and empty language respectively.
C<from_op($node)> wraps a validated L<FLAT::Regex::Op>. Existing composition
methods operate on these nodes. A literal C<atom('#')> differs from textual
C<new('#')>, which denotes empty language.

  my $atom = FLAT::Regex->atom($token);
  my $plan = $atom->concat(FLAT::Regex->atom('finish'));
  $plan->contains_tokens([$token, 'finish']);

Token-backed atoms retain matching keys and payload references through AST
composition and FA conversion. Display labels are never parsed as syntax.
C<op-E<gt>source_span> exposes optional source locations for parsed nodes;
programmatic/transformed nodes need not have locations.

=cut
