package FLAT::Symbol::Token;
use strict;
use warnings;
use parent 'FLAT::Symbol';
use Carp qw(croak);
use Hash::Util qw(lock_hash);

sub new {
    my ($class, @args) = @_;
    croak 'expected key/label/payload named arguments' if @args % 2;
    my %args = @args;
    croak "unknown symbol attribute '$_'" for grep { !/\A(?:key|label|payload)\z/ } keys %args;
    my $key = $args{key};
    croak 'symbol key must be a nonempty string other than #lambda'
        if !defined($key) || ref($key) || !length($key) || $key eq '#lambda';
    my $label = exists $args{label} ? $args{label} : $key;
    croak 'symbol label must be a defined string' if !defined($label) || ref($label);
    croak 'symbol payload must be a reference or undef'
        if defined($args{payload}) && !ref($args{payload});
    my $self = bless {KEY=>$key, LABEL=>$label, PAYLOAD=>$args{payload}}, $class;
    lock_hash(%$self);
    return $self;
}

1;
__END__

=head1 NAME

FLAT::Symbol::Token - immutable symbol identity and display label with a shared payload

=head1 SYNOPSIS

  my $job = {name => 'compile'};
  my $symbol = FLAT::Symbol::Token->new(
      key => 'step.compile', label => 'Compile', payload => $job);
  print "$symbol\n";                 # Compile
  my $text = sprintf '%s', $symbol;    # Compile
  my $copy = $symbol;                 # same symbol object
  my $fa = FLAT::PFA->singleton($symbol)->as_nfa->as_dfa;
  $fa->symbol('step.compile')->payload->{name} = 'compile again';

=head1 CONTRACT

C<key> is the immutable, nonempty string used for matching. C<label> is the
immutable display string (defaults to the key); it may be empty or C<0>.
C<payload> is an optional shared Perl reference. The binding is immutable but
the referenced data can change. Epsilon's empty key and PFA's C<#lambda> key
are reserved. Unicode strings are compared exactly without normalization.

Stringification, interpolation, C<print>, and C<sprintf '%s'> use the label.
Assignment retains the symbol reference; it does not convert it to text.
Boolean context is always true. String comparisons compare display text;
compare C<key> values when testing symbol identity. Hash keys also stringify:
use C<$map{$symbol-E<gt>key}>, not C<$map{$symbol}>.

Automata accept these objects in transition builders and C<singleton>.
They keep string keys on edges; C<alphabet> remains a list of keys.
C<symbols> returns active symbol objects; C<symbol($key)> resolves an object.
Legacy string alphabets and epsilon remain supported. Reusing a key binds the
same matching symbol, including when that key is supplied as a plain string.
Different keys can have identical display labels and payload references.

Combining explicit bindings with the same key requires identical labels and
identical payload references (or undef on both). Conflicts throw instead of
silently losing data. No global registry or address-derived identity is used.
Use C<register_symbols> to bind objects to keys in a compiled formal expression.

FLaT's C<clone>, closure operations, determinization, exact minimization and
hyper-minimization preserve the symbol objects and payload reference identity.
Graph structures are copied independently; payload mutations are intentionally
shared. Registries may retain bindings no longer present on active edges until
the automaton is released; C<symbols> lists only the active alphabet.

External C<Storable::dclone>, file serialization, JSON, JFLAP and formal-expression
text do not preserve live reference identity. Existing text exports represent
matching keys, not payloads or display labels. No reference persistence or
reconnection protocol is provided here. Arbitrary Perl references must be
wrapped explicitly; passing a bare hash/array/code reference as a label fails.

=cut
