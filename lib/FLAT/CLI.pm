package FLAT::CLI;
use strict;
use warnings;
use Getopt::Long ();
use JSON::PP ();
use Data::Dumper ();
use Storable ();
use FLAT;
use FLAT::PFA;
use FLAT::Regex::WithExtraOps;

my @OPTION_SPEC = (
    'help|h', 'version', 'batch|b', 'type=s', 'format=s', 'trim',
    'mode=s', 'depth=s', 'limit=s', 'delimiter=s', 'tokens', 'quiet|q',
    'output=s', 'force', 'length=s', 'seed=s', 'input-format=s', 'expand-labels', 'witness', 'layout=s',
);
my %COMMAND = (
    partition  => ['EXPR', 'Report preamble/kernel/unreachable DFA state IDs as JSON'],
    'f-classes'=> ['EXPR', 'Report finite-difference equivalence classes as JSON'],
    'f-equivalent'=> ['EXPR EXPR', 'Test whether the languages differ on finitely many words'],
    hypermin   => ['EXPR', 'Hyper-minimize (LOSSY: permits finite acceptance differences)'],
    completion => ['bash', 'Print a Bash completion script'],
    show       => ['EXPR', 'Inspect an automaton (--type, --format, --trim)'],
    summary    => ['EXPR', 'Print a minimized DFA summary'],
    dump       => ['EXPR', 'Dump the parsed expression tree'],
    'to-re'    => ['EXPR', 'Convert through a DFA to an ordinary formal RE'],
    normalize  => ['EXPR', 'Print the normalized formal expression'],
    'perl-regex' => ['EXPR', 'Print an anchored Perl regex (ordinary RE only)'],
    strings    => ['EXPR', 'Enumerate bounded accepted words'],
    somestrings=> ['EXPR', 'Alias for acyclic strings'],
    morestrings=> ['EXPR [DEPTH]', 'Alias for depth-bounded strings'],
    test       => ['EXPR WORD...', 'Test words; exit 1 if any is rejected'],
    trace      => ['EXPR WORD', 'Print the NFA active-state trace as JSON'],
    compare    => ['EXPR EXPR', 'Test language equivalence'],
    subset     => ['EXPR EXPR', 'Test whether the first language is a subset'],
    empty      => ['EXPR', 'Test whether the language is empty'],
    finite     => ['EXPR', 'Test whether the language is finite'],
    alphabet   => ['EXPR', 'Print the alphabet as a JSON array'],
    union      => ['EXPR EXPR...', 'Print the union as a formal expression'],
    concat     => ['EXPR EXPR...', 'Print concatenation as a formal expression'],
    shuffle    => ['EXPR EXPR...', 'Print shuffle as a parallel expression'],
    star       => ['EXPR', 'Print Kleene closure as a formal expression'],
    reverse    => ['EXPR', 'Reverse the language; output an automaton'],
    intersect  => ['EXPR EXPR...', 'Intersect languages; output an automaton'],
    difference => ['EXPR EXPR', 'Subtract the second language; output an automaton'],
    symdiff    => ['EXPR EXPR', 'Symmetric difference; output an automaton'],
    complement => ['EXPR', 'Complement over the expression alphabet'],
    savedfa    => ['EXPR', 'Save a DFA with --output FILE (Storable)'],
    random_re  => ['', 'Generate an RE (--length, --seed)'],
    random_pre => ['', 'Generate a PRE (--length, --seed)'],
);
my %FORMAT = (gdl => 'as_gdl', dot => 'as_graphviz', undot => 'as_undirected_graphviz',
              jflap => 'as_jflap', digraph => 'as_digraph',
              undirected => 'as_undirected', summary => 'as_summary');
my %ALIAS;
for my $type (qw(pfa nfa dfa)) {
    for my $suffix (qw(gv undgv digraph undirected undirectedgraph)) {
        my %format = (gv=>'dot', undgv=>'undot', digraph=>'digraph',
                      undirected=>'undirected', undirectedgraph=>'undirected');
        $ALIAS{"${type}2$suffix"} = [$type, $format{$suffix}];
    }
}
$ALIAS{dfa2jflap} = ['dfa', 'jflap'];
$ALIAS{nfa2jflap} = ['nfa', 'jflap'];

sub commands { return sort(keys %COMMAND, keys %ALIAS, 'help') }
sub _option_names {
    my ($command) = @_;
    $command = 'show' if $command eq 'summary' || exists $ALIAS{$command};
    my %allowed;
    $allowed{$_} = 1 for $command eq 'show' ? qw(type format trim)
        : $command =~ /^(reverse|intersect|difference|symdiff|complement)$/ ? qw(format trim)
        : $command =~ /^(strings|somestrings|morestrings)$/ ? qw(mode depth limit delimiter)
        : $command eq 'hypermin' ? qw(format)
        : $command eq 'f-equivalent' ? qw(quiet)
        : $command eq 'test' ? qw(tokens batch quiet)
        : $command eq 'trace' ? qw(tokens)
        : $command =~ /^(compare|subset)$/ ? qw(quiet witness)
        : $command =~ /^(empty|finite)$/ ? qw(quiet)
        : $command eq 'savedfa' ? qw(output force)
        : $command =~ /^random_/ ? qw(length seed) : ();
    $allowed{'input-format'} = 1 unless $command =~ /\A(?:normalize|perl-regex|dump|union|concat|shuffle|star|random_re|random_pre)\z/;
    $allowed{layout} = 1 if $command eq 'show' || $command =~ /\A(?:reverse|intersect|difference|symdiff|complement|hypermin)\z/;
    $allowed{'expand-labels'} = 1 if $command eq 'show' || $command =~ /\A(?:reverse|intersect|difference|symdiff|complement|hypermin)\z/;
    delete $allowed{'input-format'} if $command eq 'completion';
    return sort keys %allowed;
}

sub completion_metadata {
    my %options;
    my %files;
    for my $command (commands()) {
        my @names = $command eq 'help' ? () : _option_names($command);
        @names = grep { $_ ne 'type' && $_ ne 'format' } @names if exists $ALIAS{$command};
        @names = grep { $_ ne 'expand-labels' && $_ ne 'layout' } @names
            if exists $ALIAS{$command} && $ALIAS{$command}[1] ne 'jflap';
        my %allowed = map { $_ => 1 } (@names, 'help', 'version');
        my @flags;
        for my $spec (@OPTION_SPEC) {
            (my $names = $spec) =~ s/=.*//;
            my ($name, @aliases) = split /\|/, $names;
            next unless $allowed{$name};
            push @flags, '--' . $name, map { '-' . $_ } @aliases;
        }
        $options{$command} = [sort @flags];
        my $usage = exists $COMMAND{$command} ? $COMMAND{$command}[0] : 'EXPR';
        my @expressions = $usage =~ /EXPR/g;
        $files{$command} = $usage =~ /EXPR\.\.\./ ? -1 : scalar @expressions;
    }
    return {
        commands => [commands()], options => \%options, file_arguments => \%files,
        values => {'--type'=>[qw(pfa nfa dfa min-dfa)],
                   '--format'=>[sort(keys %FORMAT, 'json')],
                   '--layout'=>[qw(preserve layered)], '--mode'=>[qw(acyclic depth)], '--input-format'=>[qw(pre jflap)]},
        value_options => [map { '--' . ($_ =~ /\A([^=]+)/)[0] }
                          grep { /=/ } @OPTION_SPEC],
    };
}

sub _usage { die bless {message => $_[0], status => 2}, 'FLAT::CLI::Error' }
sub _arity {
    my ($args, $min, $max) = @_;
    _usage('wrong number of arguments; use fash help COMMAND')
        if @$args < $min || (defined $max && @$args > $max);
}
sub _line {
    my $line = <STDIN>;
    return undef unless defined $line;
    $line =~ s/\r?\n\z//;
    return $line;
}
sub _json { JSON::PP->new->canonical->encode($_[0]) }

sub help {
    my ($command) = @_;
    if (defined $command) {
        _usage("unknown command '$command'")
            unless exists $COMMAND{$command} || exists $ALIAS{$command};
        my $usage = exists $COMMAND{$command} ? $COMMAND{$command}[0] : 'EXPR';
        print "Usage: fash $command $usage [OPTIONS]\n\n";
    }
    else {
        print "Usage: fash COMMAND [OPTIONS] [--] ARGS...\n\n";
    }
    print "Formal REs: + or | union, concatenation, *, [] epsilon, # empty.\n";
    print "PREs additionally support & shuffle. Quote expressions in your shell.\n\n";
    for my $name (sort keys %COMMAND) {
        next if defined $command && $name ne $command;
        printf "  %-14s %-18s %s\n", $name, @{$COMMAND{$name}};
    }
    print "\nExport aliases: ", join(', ', sort keys %ALIAS), "\n";
    print <<'HELP';

Options (only where applicable):
  -h, --help                 Help (also: fash help COMMAND)
  --version                  Print FLAT version
  -b, --batch                test: first stdin line is EXPR, remaining lines WORDs
  --input-format pre|jflap    Interpret EXPR arguments as PREs or .jff file paths
  --witness                  Compare/subset: show a shortest counterexample
  --layout preserve|layered  JFLAP export: retain positions or arrange by distance
  --expand-labels            JFLAP export: map multi-character tokens to strings
  --type pfa|nfa|dfa|min-dfa  show: representation (default min-dfa)
  --format summary|dot|undot|gdl|jflap|digraph|undirected|json
                             show/FA operations: output (default summary)
  --trim                     Remove dead states from DFA output
  --mode acyclic|depth       strings: path traversal (default acyclic)
  --depth N                  Maximum visits per state in depth mode (default 1)
  --limit N                  Word limit (default 100; 0 means no output limit)
  --delimiter TEXT           Join emitted symbols (default empty string)
  --tokens                   test/trace: each WORD is a JSON array of tokens
  -q, --quiet                Predicates: suppress result text; retain exit status
  --output FILE [--force]    savedfa: explicit destination; force permits overwrite
  --length N [--seed N]      Random expressions: symbol count (default 8)

EXPR '-' reads an expression from stdin. 'test EXPR' reads words line-by-line
from stdin. Empty lines are empty words; spaces and backslashes are preserved.
Use -- before positional arguments that start with a dash.
Exit codes: 0 success/true; 1 false/rejected; 2 usage/input; 3 operation/I/O error.
Only undef ends a word iterator: epsilon prints as an empty line, 0 as '0'.
Traversal bounds are per graph state, not a complete enumeration of infinite
languages. --limit bounds output, not compilation time or memory use.
FA-to-RE and general negation (~) are not implemented. Hypermin permits finite errors.
Manuals: perldoc perlflat (library), perldoc perlfash (CLI).
Bash completion: source <(fash completion bash)
See docs/CLI.md for examples, compatibility changes, and remaining limitations.
HELP
    return 0;
}

sub _has_op {
    my ($op, $class) = @_;
    return 0 unless ref $op;
    return 1 if $op->isa($class);
    return scalar grep { _has_op($_, $class) } $op->members;
}
sub _parse {
    my ($text, $input_format) = @_;
    if (($input_format // 'pre') eq 'jflap') {
        require FLAT::JFLAP;
        my $fa = eval { FLAT::JFLAP->from_file($text) };
        _usage($@) unless defined $fa;
        return $fa;
    }
    if ($text eq '-') {
        local $/;
        $text = <STDIN>;
        _usage('no expression on stdin') unless defined $text && length $text;
    }
    my $expression = eval { FLAT::Regex::WithExtraOps->new($text) };
    if (!defined $expression) {
        my $error=$@;
        _usage(ref($error) && eval { $error->isa('FLAT::Regex::ParseError') }
            ? "$error" : 'invalid formal expression');
    }
    _usage('negation (~) is not implemented; use complement EXPR instead')
        if _has_op($expression->op, 'FLAT::Regex::Op::negate');
    return $expression;
}
sub _automaton {
    my ($expression, $type) = @_;
    if ($expression->isa('FLAT::FA')) {
        _usage('imported NFAs cannot be converted back to PFAs') if $type eq 'pfa';
        return $expression->as_nfa if $type eq 'nfa';
        return $type eq 'min-dfa' ? $expression->as_dfa->as_min_dfa : $expression->as_dfa;
    }
    return $expression->as_pfa if $type eq 'pfa';
    # Ordinary REs can bypass PFA expansion, including the empty language.
    my $nfa = _has_op($expression->op, 'FLAT::Regex::Op::shuffle')
        ? $expression->as_pfa->as_nfa
        : FLAT::Regex->_from_op($expression->op)->as_nfa;
    return $nfa if $type eq 'nfa';
    my $dfa = $nfa->as_dfa;
    return $type eq 'min-dfa' ? $dfa->as_min_dfa : $dfa;
}
sub _show {
    my ($fa, $format, $expand, $layout) = @_;
    if ($format eq 'json') {
        my @transitions;
        for my $from ($fa->get_states) {
            for my $to ($fa->get_states) {
                my $edge = $fa->get_transition($from, $to) or next;
                push @transitions, {from=>$from, to=>$to, symbols=>[$edge->alphabet]};
            }
        }
        print _json({type=>ref($fa), states=>[$fa->get_states],
            start=>[$fa->get_starting], accepting=>[$fa->get_accepting],
            alphabet=>[sort $fa->alphabet], transitions=>\@transitions}), "\n";
    }
    else {
        my $method = $FORMAT{$format};
        print $format eq 'jflap' ? $fa->as_jflap(expand_labels=>$expand, layout=>$layout // 'preserve') : $fa->$method();
    }
}
sub _symbols {
    my ($word, $tokens, $fa) = @_;
    if ($tokens) {
        my $symbols = eval { JSON::PP->new->decode($word) };
        _usage('each --tokens word must be a JSON array of nonempty strings')
            unless ref($symbols) eq 'ARRAY'
                && !grep { !defined($_) || ref($_) || !length($_) } @$symbols;
        return @$symbols;
    }
    _usage('multi-character alphabet: supply words as JSON arrays with --tokens')
        if grep { length($_) > 1 } $fa->alphabet;
    return split //, $word;
}
sub _trace {
    my ($fa, @symbols) = @_;
    my @trace = ([sort {$a <=> $b} $fa->epsilon_closure($fa->get_starting)]);
    for my $symbol (@symbols) {
        push @trace, [sort {$a <=> $b}
            $fa->epsilon_closure($fa->successors($trace[-1], $symbol))];
    }
    return \@trace;
}

sub run {
    my ($class, @args) = @_;
    my $status = eval { _main(\@args) };
    return $status unless $@;
    my $error = $@;
    my ($message, $code) = ref($error) eq 'FLAT::CLI::Error'
        ? ($error->{message}, $error->{status}) : ("$error", 3);
    $message =~ s/\s+at \S+ line \d+.*\z//s;
    $message =~ s/\s+\z//;
    $message =~ s/[\x00-\x08\x0b-\x1f\x7f]/?/g;
    print STDERR "fash: $message\n";
    return $code;
}
sub _main {
    my ($args) = @_;
    my %opt;
    my $parser = Getopt::Long::Parser->new(config => [qw(no_auto_abbrev no_ignore_case permute)]);
    my $option_error = '';
    my $ok;
    {
        local $SIG{__WARN__} = sub { $option_error .= $_[0] };
        $ok = $parser->getoptionsfromarray($args, \%opt,
            @OPTION_SPEC);
    }
    _usage($option_error || 'invalid option') unless $ok;
    if ($opt{version}) { _arity($args, 0, 0); print "fash (FLAT $FLAT::VERSION)\n"; return 0 }
    return help(@$args ? $args->[0] : undef) if $opt{help};
    _usage('a command is required; use fash --help') unless @$args;
    my $command = shift @$args;
    if ($command eq 'help') { _arity($args, 0, 1); return help(@$args) }
    _usage("unknown command '$command'; use fash --help")
        unless exists $COMMAND{$command} || exists $ALIAS{$command};

    my $export = $ALIAS{$command};
    if ($export) {
        _usage('export aliases do not take --type or --format; use show')
            if exists $opt{type} || exists $opt{format};
        ($opt{type}, $opt{format}) = @$export;
        $opt{type} = 'min-dfa' if $opt{type} eq 'dfa';
        $command = 'show';
    }
    $command = 'show' if $command eq 'summary';
    my %allowed = map { $_ => 1 } _option_names($command);
    _usage('--input-format must be pre or jflap') if exists $opt{'input-format'} && $opt{'input-format'} !~ /\A(?:pre|jflap)\z/;
    _usage('--expand-labels requires --format jflap') if $opt{'expand-labels'} && ($opt{format} // '') ne 'jflap';
    _usage('--layout requires --format jflap') if exists $opt{layout} && ($opt{format} // '') ne 'jflap';
    _usage('--layout must be preserve or layered') if exists $opt{layout} && $opt{layout} !~ /\A(?:preserve|layered)\z/;
    for my $name (keys %opt) { _usage("--$name does not apply to $command") unless $allowed{$name} }
    for my $name (qw(depth length limit)) {
        next unless exists $opt{$name};
        _usage("--$name must be " . ($name eq 'limit' ? 'a nonnegative' : 'a positive') . ' integer')
            unless $opt{$name} =~ /\A[0-9]+\z/ && ($name eq 'limit' || $opt{$name} > 0);
    }
    _usage('--seed must be an integer') if exists $opt{seed} && $opt{seed} !~ /\A-?[0-9]+\z/;
    _usage('unknown output format') if exists $opt{format} && !exists $FORMAT{$opt{format}} && $opt{format} ne 'json';
    _usage('unknown automaton type') if exists $opt{type} && $opt{type} !~ /\A(?:pfa|nfa|dfa|min-dfa)\z/;

    if ($command eq 'completion') {
        _arity($args, 1, 1);
        _usage('supported completion shell: bash') unless $args->[0] eq 'bash';
        require FLAT::CLI::Completion;
        print FLAT::CLI::Completion->bash;
        return 0;
    }
    if ($command =~ /^random_/) {
        _arity($args, 0, 0);
        srand($opt{seed}) if exists $opt{seed};
        my @alphabet = ('a'..'z', '0'..'9');
        my @operators = ('', '', '+', $command eq 'random_pre' ? '&' : '');
        my $text = '';
        for my $i (1 .. ($opt{length} // 8)) {
            $text .= $operators[rand @operators] if $i > 1;
            $text .= $alphabet[rand @alphabet];
            $text .= '*' if rand() < 0.15;
        }
        print _parse($text)->as_string, "\n";
        return 0;
    }
    if ($opt{batch}) {
        _arity($args, 0, 0);
        my $expression = _line();
        _usage('batch input needs an expression on the first line') unless defined $expression;
        push @$args, $expression;
    }
    _usage('use -b test for an expression and words in the same stdin stream')
        if $command eq 'test' && @$args == 1 && $args->[0] eq '-';
    if ($command eq 'test' && @$args == 1) {
        push @$args, $_ while defined($_ = _line());
    }
    my $many = $command =~ /\A(?:union|concat|shuffle|intersect)\z/;
    my $two = $command =~ /\A(?:compare|subset|difference|symdiff|trace|f-equivalent)\z/;
    _arity($args, $command eq 'test' || $many || $two ? 2 : 1,
           $command eq 'test' || $many ? undef : $two || $command eq 'morestrings' ? 2 : 1);
    my $expression = _parse(shift @$args, $opt{'input-format'});
    if ($command eq 'to-re') {
        print _automaton($expression, 'dfa')->as_regex->as_string, "\n"; return 0;
    }
    if ($command eq 'normalize') { print $expression->as_string, "\n"; return 0 }
    if ($command eq 'perl-regex') {
        _usage('shuffle cannot be converted directly to a Perl regex')
            if _has_op($expression->op, 'FLAT::Regex::Op::shuffle');
        print $expression->as_perl_regex(anchored=>1), "\n"; return 0;
    }
    if ($command eq 'dump') {
        print Data::Dumper->new([$expression])->Sortkeys(1)->Dump; return 0;
    }
    if ($command =~ /\A(?:union|concat|shuffle|star)\z/) {
        my $method = $command eq 'star' ? 'kleene' : $command;
        my @others = map { _parse($_) } @$args;
        print $expression->$method(@others)->as_string, "\n"; return 0;
    }
    if ($command eq 'show') {
        my $type = $opt{type} // 'min-dfa';
        _usage('PFA nodes cannot be exported as JFLAP FA states; use --type nfa')
            if $type eq 'pfa' && ($opt{format} // '') eq 'jflap';
        _usage('--trim requires a DFA') if $opt{trim} && $type !~ /dfa/;
        my $fa = _automaton($expression, $type);
        $fa = $fa->trim_sinks if $opt{trim};
        _show($fa, $opt{format} // 'summary', $opt{'expand-labels'}, $opt{layout}); return 0;
    }
    if ($command =~ /strings\z/) {
        if (@$args) {
            _usage('specify depth once, as DEPTH or --depth') if exists $opt{depth};
            $opt{depth} = shift @$args;
            _usage('DEPTH must be a positive integer') unless $opt{depth} =~ /\A[1-9][0-9]*\z/;
        }
        my $mode = $opt{mode} // ($command eq 'morestrings' || exists $opt{depth} ? 'depth' : 'acyclic');
        _usage('--mode must be acyclic or depth') unless $mode eq 'acyclic' || $mode eq 'depth';
        _usage('--depth requires depth mode') if $mode eq 'acyclic' && exists $opt{depth};
        my $fa = _automaton($expression, 'min-dfa')->trim_sinks;
        my $next = $mode eq 'acyclic'
            ? $fa->new_acyclic_string_generator($opt{delimiter} // '')
            : $fa->new_deepdft_string_generator($opt{depth} // 1, $opt{delimiter} // '');
        my $limit = $opt{limit} // 100;
        my $count = 0;
        while (!$limit || $count < $limit) {
            my $word = $next->(); last unless defined $word;
            print "$word\n"; $count++;
        }
        return 0;
    }
    if ($command eq 'test' || $command eq 'trace') {
        my $fa = _automaton($expression, 'nfa');
        my $rejected = 0;
        for my $word (@$args) {
            my $trace = _trace($fa, _symbols($word, $opt{tokens}, $fa));
            if ($command eq 'trace') { print _json($trace), "\n"; next }
            my $accepted = scalar grep { $fa->is_accepting($_) } @{$trace->[-1]};
            print(($accepted ? '(+): ' : '(-): '), $word, "\n") unless $opt{quiet};
            $rejected ||= !$accepted;
        }
        return $rejected ? 1 : 0;
    }
    my $dfa = _automaton($expression, 'dfa');
    if ($command eq 'partition' || $command eq 'f-classes') {
        my $analysis = $command eq 'partition' ? $dfa->preamble_kernel : $dfa->f_equivalence_classes;
        print _json($analysis), "\n"; return 0;
    }
    if ($command eq 'f-equivalent') {
        my $other = _automaton(_parse($args->[0], $opt{'input-format'}), 'dfa');
        my $answer = $dfa->is_f_equivalent($other);
        print($answer ? "Yes\n" : "No\n") unless $opt{quiet};
        return $answer ? 0 : 1;
    }
    if ($command eq 'hypermin') {
        _show($dfa->as_hyper_min_dfa, $opt{format} // 'summary', $opt{'expand-labels'}, $opt{layout});
        return 0;
    }
    if ($command eq 'alphabet') { print _json([sort $dfa->alphabet]), "\n"; return 0 }
    if ($command eq 'savedfa') {
        my $file = $opt{output} // ($expression->as_string . '.dat');
        die "destination exists; use --force to overwrite\n" if -e $file && !$opt{force};
        Storable::nstore($dfa, $file); return 0;
    }
    if ($command =~ /\A(?:compare|subset|empty|finite)\z/) {
        if ($opt{witness}) {
            my $other = _automaton(_parse($args->[0], $opt{'input-format'}), 'dfa');
            my $method = $command eq 'compare' ? 'equivalence_counterexample' : 'subset_counterexample';
            my $witness = $dfa->$method($other);
            unless ($opt{quiet}) {
                print defined($witness) ? "No\n" : "Yes\n";
                print "Counterexample: ", _json($witness), "\n" if defined $witness;
            }
            return defined($witness) ? 1 : 0;
        }
        my $answer = $command eq 'empty' ? $dfa->is_empty
            : $command eq 'finite' ? $dfa->is_finite
            : $command eq 'compare' ? $dfa->equals(_automaton(_parse($args->[0], $opt{'input-format'}), 'dfa'))
            : $dfa->is_subset_of(_automaton(_parse($args->[0], $opt{'input-format'}), 'dfa'));
        print($answer ? "Yes\n" : "No\n") unless $opt{quiet};
        return $answer ? 0 : 1;
    }
    my @others = map { _automaton(_parse($_, $opt{'input-format'}), 'dfa') } @$args;
    my $result = $dfa->$command(@others);
    $result = $result->trim_sinks if $opt{trim};
    _show($result, $opt{format} // 'summary', $opt{'expand-labels'}, $opt{layout});
    return 0;
}
1;
