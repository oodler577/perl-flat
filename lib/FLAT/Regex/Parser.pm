package FLAT::Regex::Parser;
use strict;
use warnings;
no warnings 'recursion'; # bounded by max_depth, including recursive grammar levels
use Carp qw(croak);
use Scalar::Util qw(blessed);
use FLAT::Regex::Lexer;
use FLAT::Regex::Op;

# Retained for code inspecting the historical lexical vocabulary.
our $CHAR=qr{[A-Za-z0-9_\$\#\%\@;:\-\^]|\[[^\]]*\]};
sub new {
    my ($class,@args)=@_;
    my %config;
    my @operators;
    if (@args && $args[0] =~ /\A(?:operators|max_length|max_token_length|max_depth)\z/) {
        croak 'expected named parser options' if @args % 2;
        %config=@args;
        croak "unknown parser option '$_'" for grep { !/\A(?:operators|max_length|max_token_length|max_depth)\z/ } keys %config;
        croak 'operators must be an array reference' if exists($config{operators}) && ref($config{operators}) ne 'ARRAY';
        @operators=@{delete($config{operators}) || [qw(alt concat star)]};
    }
    else { @operators=@args ? @args : qw(alt concat star) }
    my %ops=map { $_=>1 } @operators;
    croak "unsupported parser operator '$_'" for grep { !/\A(?:alt|concat|star|negate|shuffle)\z/ } @operators;
    my $depth=delete($config{max_depth}) // 128;
    croak 'max_depth must be a positive integer' unless !ref($depth) && $depth =~ /\A[1-9][0-9]*\z/;
    return bless {ops=>\%ops,lexer=>FLAT::Regex::Lexer->new(%config),max_depth=>$depth},$class;
}
sub error { $_[0]{error} }
sub _fail {
    my ($self,$s,$message)=@_;
    my $t=$s->{tokens}[$s->{i}];
    die FLAT::Regex::ParseError->new(message=>$message,offset=>$t->{start},line=>$t->{line},column=>$t->{column});
}
sub parse {
    my ($self,$text)=@_;
    delete $self->{error};
    my $result=eval {
        my $s={tokens=>$self->{lexer}->tokenize($text),i=>0,depth=>0};
        my $op=$self->R($s);
        $self->_fail($s,'unexpected trailing token or missing operator') unless $s->{tokens}[$s->{i}]{type} eq 'eof';
        $op;
    };
    if (my $error=$@) {
        die $error unless blessed($error) && $error->isa('FLAT::Regex::ParseError');
        $self->{error}=$error;
        return undef;
    }
    return $result;
}
sub parse_or_die {
    my ($self,$text)=@_;
    my $result=$self->parse($text);
    die $self->error unless defined $result;
    return $result;
}
sub _span {
    my ($self,$op,$start,$end)=@_;
    return $op->_set_source_span({start=>$start->{start},end=>$end->{end},
        line=>$start->{line},column=>$start->{column},end_line=>$end->{end_line},end_column=>$end->{end_column}});
}
# Ported from B. D. Estrade's FLAT-FA-0.5 RE.pm/PRE.pm R/O/C/S/L and
# *_prime routines. The originals are preserved verbatim in historical/parser.
# nexttoken now advances a token cursor; *_prime tail recursion becomes loops.
# Current Op nodes replace hash trees; the old conversion end-marker is omitted.
sub lookahead { $_[1]{tokens}[$_[1]{i}]{type} }
sub nexttoken { $_[1]{tokens}[$_[1]{i}++] }
sub match {
    my ($self,$s,$type)=@_;
    $self->_fail($s,"expected '$type'") unless $self->lookahead($s) eq $type;
    return $self->nexttoken($s);
}
sub R {
    my ($self,$s)=@_;
    return $self->O($s);
}
sub O {
    my ($self,$s)=@_;
    my $start=$s->{tokens}[$s->{i}];
    my $next='P';
    return $self->O_prime($s,$self->$next($s),$start,$next);
}
sub O_prime {
    my ($self,$s,$tree,$start,$next)=@_;
    my @parts=($tree);
    while ($self->{ops}{alt} && $self->lookahead($s) =~ /\A[+|]\z/) {
        $self->nexttoken($s);
        push @parts,$self->$next($s);
    }
    return $tree if @parts==1;
    return $self->_span(FLAT::Regex::Op::alt->new(@parts),$start,$s->{tokens}[$s->{i}-1]);
}
sub P {
    my ($self,$s)=@_;
    my $start=$s->{tokens}[$s->{i}];
    my $next='N';
    return $self->P_prime($s,$self->$next($s),$start,$next);
}
sub P_prime {
    my ($self,$s,$tree,$start,$next)=@_;
    my @parts=($tree);
    while ($self->{ops}{shuffle} && $self->lookahead($s) eq '&') {
        $self->match($s,'&');
        push @parts,$self->$next($s);
    }
    return $tree if @parts==1;
    return $self->_span(FLAT::Regex::Op::shuffle->new(@parts),$start,$s->{tokens}[$s->{i}-1]);
}
# Extension to the recovered grammar, retaining the later ~ precedence.
sub N {
    my ($self,$s)=@_;
    my $start=$s->{tokens}[$s->{i}];
    if ($self->{ops}{negate} && $self->lookahead($s) eq '~') {
        $self->match($s,'~');
        return $self->_span(FLAT::Regex::Op::negate->new($self->C($s)),$start,$s->{tokens}[$s->{i}-1]);
    }
    return $self->C($s);
}
sub C {
    my ($self,$s)=@_;
    my $start=$s->{tokens}[$s->{i}];
    return $self->C_prime($s,$self->S($s),$start);
}
sub C_prime {
    my ($self,$s,$tree,$start)=@_;
    my @parts=($tree);
    while ($self->{ops}{concat} && $self->lookahead($s) =~ /\A(?:atom|\()\z/) {
        push @parts,$self->S($s);
    }
    return $tree if @parts==1;
    return $self->_span(FLAT::Regex::Op::concat->new(@parts),$start,$s->{tokens}[$s->{i}-1]);
}
sub S {
    my ($self,$s)=@_;
    my $start=$s->{tokens}[$s->{i}];
    return $self->S_prime($s,$self->L($s),$start);
}
sub S_prime {
    my ($self,$s,$tree,$start)=@_;
    if ($self->{ops}{star} && $self->lookahead($s) eq '*') {
        $self->match($s,'*');
        return $self->_span(FLAT::Regex::Op::star->new($tree),$start,$s->{tokens}[$s->{i}-1]);
    }
    return $tree;
}
sub L {
    my ($self,$s)=@_;
    my $token=$s->{tokens}[$s->{i}];
    if ($self->lookahead($s) eq '(') {
        $self->_fail($s,'parenthesis nesting exceeds max_depth') if ++$s->{depth}>$self->{max_depth};
        $self->match($s,'(');
        my $tree=$self->R($s);
        $self->_fail($s,"expected ')' to close group") unless $self->lookahead($s) eq ')';
        my $end=$self->match($s,')');
        --$s->{depth};
        return $self->_span($tree,$token,$end);
    }
    if ($self->lookahead($s) eq 'atom') {
        $self->nexttoken($s);
        return $self->_span(FLAT::Regex::Op::atomic->new($token->{value}),$token,$token);
    }
    $self->_fail($s,'expected an atom or parenthesized expression');
}

1;
__END__

=head1 NAME

FLAT::Regex::Parser - modernized Estrade recursive-descent RE/PRE parser

=head1 CONTRACT

Ports the recovered FLAT-FA-0.5 RE/PRE C<R>, C<O>, C<C>, C<S>, C<L>
and continuation routines to current ASTs. The unchanged originals and source
checksums are in F<historical/parser>. Indexed token lookahead, iterative
continuations, strict operand checks and located errors replace the older
character queue, concatenation toggle, and permissive epsilon recovery.
The old artificial conversion end-marker is not part of the current AST.

C<new(qw(alt concat star))> selects ordinary RE syntax. Adding C<shuffle>
and C<negate> enables the existing PRE grammar. C<parse> returns the existing
L<FLAT::Regex::Op> AST, or undef on syntax failure; C<error> supplies a structured
L<FLAT::Regex::ParseError>. C<parse_or_die> throws that object on failure.
Parser objects are reusable; errors are reset for each call.

Precedence, lowest first: union C<+> or C<|>, shuffle C<&>, prefix C<~>,
implicit concatenation, postfix C<*>. Negation binds the following concatenation;
C<a~b>, C<~~a>, and repeated postfix stars are rejected as in the previous grammar.
Parenthesize those subexpressions explicitly where meaningful. Parsing C<~>
does not implement its currently unfinished language operations.

The port deliberately retains the modern precedence used by the later API:
union binds less tightly than shuffle. The recovered original PRE parser used
the opposite ordering. The C<O>/C<P> call order is adjusted accordingly; there
is no legacy precedence mode. Modern bracket literals and strict operands are
retained rather than the older permissive epsilon recovery.

Named configuration is also accepted:

  FLAT::Regex::Parser->new(operators => [qw(alt concat star)],
      max_depth => 128, max_length => 1_000_000, max_token_length => 65_536);

Limits are positive integers. They constrain parsing, not automaton compilation.
Only the built-in operators are supported; dynamic RecDescent C<parse_spec>
grammar generation is no longer used. Non-ASCII symbols must be bracketed.
See L<FLAT::Regex::Lexer> for literal, whitespace, and location rules.

Parsed nodes expose C<source_span> with half-open character offsets and one-based
line/column positions. Grouping does not add a semantic AST node, so an enclosing
group can widen the contained root's span. Flattened associative nodes describe
the combined expression. Spans describe parsed source, not later transformed
expressions; they are optional, weakly associated diagnostic metadata and are
not serialized. No input text or payload reference is kept in that metadata.

=cut
