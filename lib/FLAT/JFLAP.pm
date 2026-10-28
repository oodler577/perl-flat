package FLAT::JFLAP;
use strict;
use warnings;
use Carp qw(croak);
use Encode qw(decode);
use XML::LibXML;
use FLAT::NFA;

sub _error { croak 'JFLAP: ' . $_[0] }
sub _check_text {
    _error('text contains a character XML 1.0 cannot represent')
        if $_[0] =~ /[^\x09\x0a\x0d\x20-\x{d7ff}\x{e000}-\x{fffd}\x{10000}-\x{10ffff}]/;
}
sub _children {
    my ($node, @allowed) = @_;
    my %allowed = map { $_ => 1 } @allowed;
    for my $child ($node->nonBlankChildNodes) {
        next if $child->nodeType == XML_COMMENT_NODE;
        _error('unsupported element in ' . $node->nodeName)
            unless $child->nodeType == XML_ELEMENT_NODE && $allowed{$child->nodeName};
    }
}
sub _text {
    my ($node, $name, $required) = @_;
    my @elements = $node->findnodes('./' . $name);
    _error("expected one $name element") if @elements > 1 || ($required && !@elements);
    return undef unless @elements;
    _error("nested markup is not allowed inside $name") if $elements[0]->findnodes('./*');
    return $elements[0]->textContent;
}
sub from_file {
    my ($class, $file) = @_;
    my $xml;
    if ($file eq '-') { local $/; $xml = <STDIN> }
    else {
        open my $fh, '<:raw', $file or croak "cannot read '$file': $!";
        local $/; $xml = <$fh>; close $fh or croak "cannot close '$file': $!";
    }
    return $class->from_string($xml);
}
sub from_string {
    my ($class, $xml) = @_;
    _error('empty XML input') unless defined $xml && length $xml;
    _error('DTD and entity declarations are not supported') if $xml =~ /<!\s*(?:DOCTYPE|ENTITY)\b/i;
    my $parser = XML::LibXML->new(no_network=>1, load_ext_dtd=>0, expand_entities=>0, recover=>0);
    my $doc = eval { $parser->load_xml(string=>$xml) };
    _error('malformed XML') unless $doc;
    _error('DTD declarations are not supported') if $doc->internalSubset || $doc->externalSubset;
    my $root = $doc->documentElement;
    _error('expected a structure document') unless $root->nodeName eq 'structure';
    _children($root, qw(type automaton state transition));
    my $type = _text($root, 'type', 1);
    $type =~ s/\A\s+|\s+\z//g;
    _error('only finite automata (type fa) are supported') unless $type eq 'fa';
    my @automata = $root->findnodes('./automaton');
    _error('expected at most one automaton') if @automata > 1;
    _error('cannot mix nested and legacy top-level states/transitions')
        if @automata && $root->findnodes('./state | ./transition');
    # JFLAP 4 stores states/transitions directly under structure; later
    # versions wrap them in automaton. Export the current nested form.
    my $automaton = @automata ? $automata[0] : $root;
    _children($automaton, @automata ? qw(state transition) : qw(type state transition));
    my @states = $automaton->findnodes('./state');
    _error('at least one state is required') unless @states;
    my $nfa = FLAT::NFA->new;
    my %id;
    for my $state (@states) {
        _children($state, qw(x y initial final label));
        my $id = $state->getAttribute('id');
        _error('state IDs must be nonnegative integers') unless defined $id && $id =~ /\A(?:0|[1-9][0-9]*)\z/;
        _error("duplicate state ID $id") if exists $id{$id};
        my $s = $id{$id} = $nfa->add_states(1);
        my $meta = $nfa->{STATES}[$s];
        $meta->{jflap_name} = $state->getAttribute('name') if $state->hasAttribute('name');
        for my $coordinate (qw(x y)) {
            my $value = _text($state, $coordinate, 0);
            next unless defined $value;
            _error("invalid $coordinate coordinate") unless $value =~ /\A\s*[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\s*\z/;
            $meta->{'jflap_' . $coordinate} = $value;
        }
        my $label = _text($state, 'label', 0);
        $meta->{jflap_label} = $label if defined $label;
        for my $flag (qw(initial final)) {
            my $value = _text($state, $flag, 0);
            _error("$flag must be empty") if defined $value && $value =~ /\S/;
            if (defined $value) {
                $flag eq 'initial' ? $nfa->set_starting($s) : $nfa->set_accepting($s);
            }
        }
    }
    my @start = $nfa->get_starting;
    _error('expected exactly one initial state') unless @start == 1;
    for my $transition ($automaton->findnodes('./transition')) {
        _children($transition, qw(from to read));
        my $from = _text($transition, 'from', 1);
        my $to = _text($transition, 'to', 1);
        s/\A\s+|\s+\z//g for ($from, $to);
        _error('transition references an unknown state') unless exists $id{$from} && exists $id{$to};
        my $read = _text($transition, 'read', 0) // '';
        # JFLAP multi-character reads consume a character string. Expand them
        # rather than confusing them with FLAT's single multi-character token.
        my @symbols = length($read) ? split(//, $read) : ('');
        my $current = $id{$from};
        for my $i (0 .. $#symbols) {
            my $next = $i == $#symbols ? $id{$to} : $nfa->add_states(1);
            $nfa->add_transition($current, $next, $symbols[$i]);
            $current = $next;
        }
    }
    return $nfa;
}
sub to_string {
    my ($class, $fa, %options) = @_;
    _error('convert a PFA to an NFA before export') if $fa->isa('FLAT::PFA');
    my @start = $fa->get_starting;
    _error('an initial state is required') unless @start;
    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $root = $doc->createElement('structure');
    $doc->setDocumentElement($root);
    $root->appendTextChild('type', 'fa');
    my $automaton = $doc->createElement('automaton');
    $root->appendChild($automaton);
    my $next_id = $fa->num_states;
    my $add_state = sub {
        my ($s, $meta, $initial, $final) = @_;
        _check_text($_) for values %$meta;
        my $state = $doc->createElement('state');
        $state->setAttribute(id=>$s);
        $state->setAttribute(name=>$meta->{jflap_name} // "q$s");
        $state->appendTextChild('x', $meta->{jflap_x} // (100 + 120 * ($s % 6)));
        $state->appendTextChild('y', $meta->{jflap_y} // (100 + 120 * int($s / 6)));
        $state->appendTextChild('label', $meta->{jflap_label}) if exists $meta->{jflap_label};
        $state->appendChild($doc->createElement('initial')) if $initial;
        $state->appendChild($doc->createElement('final')) if $final;
        $automaton->appendChild($state);
    };
    for my $s ($fa->get_states) {
        $add_state->($s, $fa->{STATES}[$s], @start == 1 && $fa->is_starting($s), $fa->is_accepting($s));
    }
    my @edges;
    if (@start > 1) {
        my $synthetic = $next_id++;
        $add_state->($synthetic, {}, 1, 0);
        push @edges, [$synthetic, $_, ''] for @start;
    }
    for my $from ($fa->get_states) {
        for my $to ($fa->get_states) {
            my $edge = $fa->get_transition($from, $to) or next;
            for my $symbol ($edge->alphabet) {
                _check_text($symbol);
                _error('multi-character tokens require explicit expand_labels => 1 (CLI --expand-labels)')
                    if length($symbol) > 1 && !$options{expand_labels};
                my @symbols = length($symbol) ? split(//, $symbol) : ('');
                my $current = $from;
                for my $i (0 .. $#symbols) {
                    my $next = $i == $#symbols ? $to : $next_id++;
                    $add_state->($next, {}, 0, 0) if $i != $#symbols;
                    push @edges, [$current, $next, $symbols[$i]];
                    $current = $next;
                }
            }
        }
    }
    for my $edge (@edges) {
        my $transition = $doc->createElement('transition');
        $transition->appendTextChild('from', $edge->[0]);
        $transition->appendTextChild('to', $edge->[1]);
        $transition->appendTextChild('read', $edge->[2]);
        $automaton->appendChild($transition);
    }
    return decode('UTF-8', $doc->toString(1));
}
1;

__END__

=head1 NAME

FLAT::JFLAP - finite-automaton JFLAP XML interchange

=head1 SYNOPSIS

  my $nfa = FLAT::JFLAP->from_file('example.jff');
  my $nfa = FLAT::JFLAP->from_string($xml);
  my $xml = $nfa->as_jflap;

=head1 CONTRACT

Imports legacy top-level and nested finite-automaton XML as an NFA.
State IDs are remapped; names, labels and coordinates are retained on direct
round trips. Empty or omitted read elements denote epsilon. Multi-character
reads are expanded into character paths.

Export returns Unicode text. Encode it as UTF-8 when writing a file.
Multi-character FLAT tokens require C<expand_labels =E<gt> 1>, which maps the
token alphabet to character strings explicitly. Convert PFAs to NFAs before
exporting. Other machine types, DTDs, and unsupported semantic elements fail
with an exception. See docs/CLI.md for scope and examples.

=cut
