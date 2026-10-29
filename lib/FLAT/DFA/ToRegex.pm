package FLAT::DFA::ToRegex;
use strict;
use warnings;
use Carp qw(croak);
use FLAT::Regex;

# undef denotes a missing GNFA edge (empty language), not an epsilon edge.
sub _epsilon { FLAT::Regex::Op::atomic->new('') }
sub _is_epsilon {
    ref($_[0]) eq 'FLAT::Regex::Op::atomic'
        && defined($_[0]->key) && $_[0]->key eq '';
}
# Structural keys avoid parsing/stringifying labels, including keys containing ].
sub _signature {
    my ($node) = @_;
    if (ref($node) eq 'FLAT::Regex::Op::atomic') {
        my $key = $node->key;
        return defined($key) ? 'a'.length($key).':'.$key : 'e';
    }
    return ref($node).'('.join('', map {
        my $s = _signature($_); length($s).':'.$s
    } $node->members).')';
}
sub _alt {
    my @nodes;
    my %seen;
    for my $node (grep { defined } @_) {
        my @parts = ref($node) eq 'FLAT::Regex::Op::alt' ? $node->members : ($node);
        push @nodes, grep { !$seen{_signature($_)}++ } @parts;
    }
    return undef unless @nodes;
    return $nodes[0] if @nodes == 1;
    return FLAT::Regex::Op::alt->new(@nodes);
}
sub _concat {
    return undef if grep { !defined } @_;
    my @nodes = grep { !_is_epsilon($_) } @_;
    return _epsilon() unless @nodes;
    return $nodes[0] if @nodes == 1;
    return FLAT::Regex::Op::concat->new(@nodes);
}
sub _star {
    my ($node) = @_;
    return _epsilon() unless defined($node) && !_is_epsilon($node);
    return $node if ref($node) eq 'FLAT::Regex::Op::star';
    return FLAT::Regex::Op::star->new($node);
}

sub convert {
    my ($class, $dfa, @options) = @_;
    croak 'as_regex takes no options' if @options;
    my @starts = $dfa->get_starting;
    croak 'DFA-to-RE requires exactly one starting state' unless @starts == 1;

    # Work only on states on accepting paths; no mutation or minimization.
    my @queue = @starts;
    my %reachable = map { $_ => 1 } @queue;
    for (my $i=0; $i<@queue; ++$i) {
        push @queue, grep { !$reachable{$_}++ } sort {$a<=>$b} $dfa->successors($queue[$i]);
    }
    my %pred;
    for my $s ($dfa->get_states) {
        push @{$pred{$_}}, $s for $dfa->successors($s);
    }
    @queue = $dfa->get_accepting;
    my %live = map { $_ => 1 } @queue;
    for (my $i=0; $i<@queue; ++$i) {
        push @queue, grep { !$live{$_}++ } @{$pred{$queue[$i]} || []};
    }
    return FLAT::Regex->empty unless $live{$starts[0]};
    my @states = grep { $reachable{$_} && $live{$_} } $dfa->get_states;
    # Synthetic endpoints cannot collide with numeric FA state IDs.
    my ($start, $final) = ('start', 'final');
    my %edge;
    $edge{$start}{$starts[0]} = _epsilon();
    for my $i (@states) {
        $edge{$i}{$final} = _epsilon() if $dfa->is_accepting($i);
        for my $j (@states) {
            my $transition = $dfa->get_transition($i, $j);
            next unless defined $transition;
            for my $key ($transition->alphabet) {
                my $symbol = $dfa->symbol($key);
                my $atom = FLAT::Regex::Op::atomic->new(defined($symbol) && $symbol->isa('FLAT::Symbol::Token') ? $symbol : $key);
                $edge{$i}{$j} = _alt($edge{$i}{$j}, $atom);
            }
        }
    }
    # GNFA invariant: edge(i,j) describes paths whose internal states have
    # already been eliminated. Fixed state-ID order gives reproducible output.
    my @remaining = ($start, @states, $final);
    for my $k (@states) {
        my @others = grep { $_ ne "$k" } @remaining;
        my $loop = _star($edge{$k}{$k});
        for my $i (@others) {
            next unless defined $edge{$i}{$k};
            for my $j (@others) {
                next unless defined $edge{$k}{$j};
                $edge{$i}{$j} = _alt($edge{$i}{$j},
                    _concat($edge{$i}{$k}, $loop, $edge{$k}{$j}));
            }
        }
        delete $edge{$k};
        delete $edge{$_}{$k} for @others;
        @remaining = @others;
    }
    return defined($edge{$start}{$final})
        ? FLAT::Regex->from_op($edge{$start}{$final}) : FLAT::Regex->empty;
}
1;

__END__

=head1 NAME

FLAT::DFA::ToRegex - exact GNFA state elimination to formal regular expressions

=head1 SYNOPSIS

  my $re = $dfa->as_regex;
  print $re->as_string, "\n";

=head1 ALGORITHM AND CONTRACT

C<FLAT::DFA::as_regex> returns an ordinary L<FLAT::Regex> AST using union,
concatenation and Kleene star. These are formal-language expressions.
The source graph is not changed. Partial DFAs, accepting initial states,
multiple accepting states, loops and the empty language are supported.
Exactly one starting state is required; no options are currently accepted.

The construction adds fresh epsilon-linked start/final endpoints, discards
unreachable states and states unable to reach acceptance, then eliminates
original states in ascending numeric ID order, applying

  R(i,j) := R(i,j) + R(i,k) R(k,k)* R(k,j)

Missing edges denote empty language. Local identities remove empty-language
paths, epsilon concatenations, duplicate union alternatives and repeated stars.
This is exact conversion, not hyper-minimization. No minimal-expression or
compact-output guarantee is made: time, memory and output can grow exponentially.
There are no conversion budgets or progress events in this initial implementation.

Atoms retain matching keys and existing token objects, including shared payload
references. Display labels are never reparsed. Text output cannot preserve
payloads, and keys containing C<]> remain programmatic-only under the existing
formal-expression syntax. Use C<contains_tokens> for atomic multi-character keys.

NFA C<as_regex> first determinizes; PFA C<as_regex> first serializes through its
existing DFA conversion. No historical unfinished converter is used.

=cut
