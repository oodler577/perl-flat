package FLAT::Regex::ParseError;
use strict;
use warnings;
use overload '""' => 'as_string', 'bool' => sub {1}, fallback=>1;
sub new { my ($class,%args)=@_; return bless \%args,$class }
sub message { $_[0]{message} }
sub offset { $_[0]{offset} }
sub line { $_[0]{line} }
sub column { $_[0]{column} }
sub as_hash { return {%{$_[0]}} }
sub as_string {
    my ($self)=@_;
    return "invalid formal expression at line $self->{line}, column $self->{column} (offset $self->{offset}): $self->{message}\n";
}
1;
__END__

=head1 NAME

FLAT::Regex::ParseError - structured formal-expression syntax error

=head1 CONTRACT

Thrown by C<parse_or_die> and the expression constructor. Accessors C<message>,
C<offset>, C<line>, C<column>, and C<as_hash> expose details. Offsets count Perl
characters from zero; line and column count from one. Stringification yields a
concise diagnostic without evaluating or reproducing the entire expression.

=cut
