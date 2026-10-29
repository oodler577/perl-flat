package FLAT::Symbol::Token::Scalar;
use strict;
use warnings;
use parent 'FLAT::Symbol::Token';
use Carp qw(croak);

sub new {
    my ($class, $key, @extra) = @_;
    croak 'expected one nonempty scalar key other than #lambda'
        if @extra || !defined($key) || ref($key) || !length($key) || $key eq '#lambda';
    my $self = bless \$key, $class;
    Internals::SvREADONLY($$self, 1);
    return $self;
}
sub key { ${$_[0]} }
sub label { ${$_[0]} }
sub as_string { ${$_[0]} }
sub payload { undef }

1;
__END__

=head1 NAME

FLAT::Symbol::Token::Scalar - lightweight immutable scalar token

=head1 SYNOPSIS

  my $symbol = FLAT::Symbol::Token::Scalar->new('a');
  print $symbol;                         # a
  my $fa = FLAT::NFA->singleton($symbol);

=head1 CONTRACT

A L<FLAT::Symbol::Token> subclass backed by a blessed scalar reference instead
of a hash. The key and display label are the same immutable string, and
C<payload> is always undef. It supports the same builders, lookup, matching,
stringification and reference-preserving transformation APIs as the full token.
Empty keys and C<#lambda> are reserved. The C<0> key remains a true object.
Legacy alphabet-count mutators are not part of the explicit token interface.

This avoids the full token's attribute hash, but still has object and registry
overhead. Bare string labels remain supported and require no explicit binding;
use them when an object identity or richer symbol interface is unnecessary.
Full tokens and scalar tokens may be mixed. Compatible same-key bindings merge
by the standard token conflict rules; the first registered object is retained.

=cut
