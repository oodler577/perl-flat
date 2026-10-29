package FLAT::DFA::Hyper;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed);

# Snapshot the existing dense FLAT graph as a deterministic token table.
# A virtual rejecting sink completes partial DFAs without changing their IDs.
sub _model {
    my ($dfa) = @_;
    croak 'expected a FLAT::DFA' unless blessed($dfa) && $dfa->isa('FLAT::DFA');
    my @start = $dfa->get_starting;
    croak 'DFA must have exactly one initial state' unless @start == 1;
    my @alphabet = sort $dfa->alphabet;
    my $n = $dfa->num_states;
    for my $p ($dfa->get_states) {
        for my $q ($dfa->get_states) {
            my $edge = $dfa->get_transition($p, $q) or next;
            croak 'epsilon transitions are not allowed in a DFA'
                if grep { !length($_) } $edge->alphabet;
        }
    }
    my (@delta, @final);
    my $missing = 0;
    for my $p ($dfa->get_states) {
        $final[$p] = $dfa->is_accepting($p) ? 1 : 0;
        for my $c (0 .. $#alphabet) {
            my @to = $dfa->successors($p, $alphabet[$c]);
            croak 'nondeterministic transition in DFA' if @to > 1;
            $delta[$p][$c] = @to ? $to[0] : $n;
            $missing = 1 unless @to;
        }
        $delta[$p] ||= [];
    }
    if ($missing) {
        $delta[$n] = [map { $n } @alphabet];
        $final[$n] = 0;
    }
    return {delta=>\@delta, final=>\@final, alphabet=>\@alphabet,
            start=>$start[0], original_count=>$n};
}

sub _reachable {
    my ($m) = @_;
    my @queue = ($m->{start});
    my %seen = ($m->{start}=>1);
    for (my $i = 0; $i < @queue; ++$i) {
        for my $q (@{$m->{delta}[$queue[$i]]}) {
            push @queue, $q unless $seen{$q}++;
        }
    }
    return \%seen;
}

# Kahn elimination leaves precisely cycles and everything downstream of them.
# Restricted to reachable states, those have infinite left languages.
sub _partition {
    my ($m) = @_;
    my $reachable = _reachable($m);
    my @in = (0) x @{$m->{delta}};
    for my $p (keys %$reachable) { ++$in[$_] for @{$m->{delta}[$p]} }
    my @queue = grep { !$in[$_] } sort {$a <=> $b} keys %$reachable;
    my %preamble;
    for (my $i = 0; $i < @queue; ++$i) {
        my $p = $queue[$i];
        $preamble{$p} = 1;
        for my $q (@{$m->{delta}[$p]}) { push @queue, $q if --$in[$q] == 0 }
    }
    return {
        preamble=>[grep { $preamble{$_} } 0 .. $m->{original_count}-1],
        kernel=>[grep { $reachable->{$_} && !$preamble{$_} } 0 .. $m->{original_count}-1],
        unreachable=>[grep { !$reachable->{$_} } 0 .. $m->{original_count}-1],
    };
}
sub preamble_kernel { return _partition(_model($_[1])) }

# Badr Algorithms 5-6: find right-finite states of the full XOR self-product.
# Seed with all empty right languages, not just the diagonal, so this also
# handles nonminimal inputs while retaining their original state identifiers.
sub _finite_pairs {
    my ($m) = @_;
    my $n = @{$m->{delta}};
    my $k = @{$m->{alphabet}};
    my (@incoming, @bad);
    for my $p (0 .. $n-1) {
        for my $q (0 .. $n-1) {
            my $id = $p*$n+$q;
            push @bad, $id if $m->{final}[$p] != $m->{final}[$q];
            for my $c (0 .. $k-1) {
                my $to = $m->{delta}[$p][$c]*$n + $m->{delta}[$q][$c];
                push @{$incoming[$to]}, $id;
            }
        }
    }
    my %productive = map { $_=>1 } @bad;
    for (my $i = 0; $i < @bad; ++$i) {
        for my $p (@{$incoming[$bad[$i]] || []}) {
            push @bad, $p unless $productive{$p}++;
        }
    }
    my @remaining = ($k) x ($n*$n);
    my @queue = grep { !$productive{$_} || !$k } 0 .. $n*$n-1;
    my @finite = (0) x ($n*$n);
    $finite[$_] = 1 for @queue;
    for (my $i = 0; $i < @queue; ++$i) {
        for my $p (@{$incoming[$queue[$i]] || []}) {
            next if $finite[$p];
            if (--$remaining[$p] == 0) { $finite[$p] = 1; push @queue, $p }
        }
    }
    return \@finite;
}
sub _classes {
    my ($m) = @_;
    my $finite = _finite_pairs($m);
    my $n = @{$m->{delta}};
    my @classes;
    for my $p (0 .. $m->{original_count}-1) {
        my ($class) = grep { $finite->[$p*$n + $_->[0]] } @classes;
        if ($class) { push @$class, $p } else { push @classes, [$p] }
    }
    return \@classes;
}
sub f_equivalence_classes { return _classes(_model($_[1])) }
sub analyze {
    my ($class, $dfa) = @_;
    my $m = _model($dfa);
    return {%{_partition($m)}, f_equivalence_classes=>_classes($m)};
}

# Build an ordinary FLAT::DFA, preserving tokens and removing unreachable nodes.
sub _materialize {
    my ($m) = @_;
    require FLAT::DFA;
    my $reachable = _reachable($m);
    my @states = sort {$a <=> $b} keys %$reachable;
    my $dfa = FLAT::DFA->new;
    my %id;
    $id{$_} = $dfa->add_states(1) for @states;
    $dfa->set_starting($id{$m->{start}});
    for my $p (@states) {
        $dfa->set_accepting($id{$p}) if $m->{final}[$p];
        for my $c (0 .. $#{$m->{alphabet}}) {
            $dfa->add_transition($id{$p}, $id{$m->{delta}[$p][$c]}, $m->{alphabet}[$c]);
        }
    }
    return ($dfa, \%id);
}

# Badr Algorithm 4 and Algorithm 8: classical minimization first; then merge
# only preamble states, preferring a kernel representative of each f-class.
sub minimize_with_report {
    my ($class, $input) = @_;
    my ($complete) = _materialize(_model($input));
    my $minimal = $complete->as_min_dfa;
    my $m = _model($minimal);
    my $analysis = {%{_partition($m)}, f_equivalence_classes=>_classes($m)};
    my %kernel = map { $_=>1 } @{$analysis->{kernel}};
    my @representative = 0 .. $minimal->num_states-1;
    for my $block (@{$analysis->{f_equivalence_classes}}) {
        my @kernel = grep { $kernel{$_} } @$block;
        my $rep = @kernel ? $kernel[0] : $block->[0];
        $representative[$_] = $rep for grep { !$kernel{$_} } @$block;
    }
    my @delta;
    for my $p (0 .. $#representative) {
        $delta[$p] = [map { $representative[$_] } @{$m->{delta}[$p]}];
    }
    my ($result, $ids) = _materialize({%$m, delta=>\@delta, start=>$representative[$m->{start}]});
    my @map = map { $ids->{$representative[$_]} } 0 .. $#representative;
    return {dfa=>$result, minimal_dfa=>$minimal, analysis=>$analysis,
            minimal_to_result=>\@map};
}
sub minimize { return $_[0]->minimize_with_report($_[1])->{dfa} }

1;
__END__

=head1 NAME

FLAT::DFA::Hyper - Badr preamble/kernel analysis and DFA hyper-minimization

=head1 SYNOPSIS

  my $parts = $dfa->preamble_kernel;
  my $classes = $dfa->f_equivalence_classes;
  my $hyper = $dfa->as_hyper_min_dfa;
  my $finite_difference = $dfa->symdiff($hyper);  # ordinary exact FLAT DFA/NFA
  die unless $finite_difference->is_finite;

  my $report = FLAT::DFA::Hyper->minimize_with_report($dfa);
  my $analysis = FLAT::DFA::Hyper->analyze($dfa);

=head1 SEMANTICS

Preamble states have finite left languages; kernel states have infinite left
languages. Every state reachable from a reachable cycle is in the kernel,
including states outside the cycle. Unreachable states are reported separately.
This is independent of accepting status and is not the finite/infinite partition
of states' right languages. Analysis does not modify or renumber input states.

Two states are f-equivalent (almost equivalent) when the symmetric difference
of their right languages is finite. C<f_equivalence_classes> returns an array
reference of classes, each an array reference of original state IDs, including
unreachable states. Nonminimal DFAs are supported. A virtual rejecting sink
completes missing transitions internally and is omitted from analysis results.

C<as_hyper_min_dfa> is explicitly LOSSY: it returns a smallest complete DFA
whose language differs on finitely many token words. It need not preserve the
empty word or any individual word. It must not replace exact minimization in
workflow validation or execution. Ordinary C<as_min_dfa>, equality, and inclusion
retain their existing semantics. Hyper-minimal outputs need not be unique;
representatives here are deterministic (lowest kernel ID, else lowest ID).

All results use existing FLAT automaton, transition and literal-token classes,
so ordinary operations, witnesses, traces and JFLAP export apply. The result is
an ordinary C<FLAT::DFA>, not a new storage format. Source state metadata is not
propagated across minimization; IDs are local to each returned graph.

C<minimize_with_report> returns C<dfa>, the complete exact C<minimal_dfa>, its
C<analysis>, and C<minimal_to_result> (an array mapping minimal DFA state IDs
to output IDs, or undef if no longer reachable). The report's partition and
classes refer to C<minimal_dfa>, not input IDs. C<analyze> instead reports the
input's partition and classes. These reports are ordinary Perl data structures.

=head1 ALGORITHM AND COST

Implements Algorithms 4-8 of Andrew Badr, I<Hyper-Minimization in O(n squared)>,
CIAA 2008, DOI 10.1007/978-3-540-70844-5_23:
L<https://www.andrewbadr.com/files/hyper/ciaa32.pdf>.
The full XOR self-product and right-finite elimination are used to find
f-equivalence. Empty right languages are found explicitly, generalizing the
paper's diagonal seed to nonminimal inputs. Reachable indegree elimination
computes the preamble/kernel partition. Only preamble states are merged;
distinct kernel states are retained even when f-equivalent.

Pair analysis uses O((alphabet-size + 1) * states-squared) time and space after
snapshotting the graph. The existing classical minimizer and dense FLAT graph
construction have their own costs; this module does NOT claim the entire
pipeline achieves the paper's quadratic bound. The paper's separate DFCA
minimization and finite-factoring construction are not implemented here.

The background is also developed in Badr, Geffert and Shipman,
I<Hyper-minimizing minimized deterministic finite state automata>,
RAIRO 43 (2009), 69-94, DOI 10.1051/ita:2007061.

=cut
