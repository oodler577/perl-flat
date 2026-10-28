# fash command-line guide

fash is a Perl command-line entry point for FLaT. It passes arguments as data,
without a shell or generated Perl source. The old shell command names remain
available. From a checkout run `perl -Ilib bin/fash`; an installed distribution
provides `fash` on PATH. The distribution now includes the executable.

## Quick start

```sh
perldoc perlflat
perldoc perlfash
fash --help
fash help strings
fash normalize '(a+b)c'
fash test 'a*b' b aaab a
fash test '[]+0' '' 0
fash compare 'a&b' 'ab+ba'
fash finite 'ab*c'
fash show 'a&b' --type pfa --format dot > parallel.dot
fash dfa2gv 'a&b' > deterministic.dot
fash strings 'a&b' --limit 0
fash morestrings 'a*' --depth 3
```

Quote expressions: shells otherwise interpret `&`, `*`, parentheses and other
characters. Use `--` before dash-prefixed positional data.

The expression syntax is formal regular expressions: concatenation, `+` or `|`
for union, `*` for closure, `[]` for epsilon, `#` for empty language, and `&` for
shuffle. `[foo]` is ONE token named foo, not three characters. Bare operators
inside brackets are literal labels. Perl regex features are not implied.
The CLI reads/writes UTF-8 text, with exact label equality and no normalization.

## Commands and outputs

| Commands | Output |
| --- | --- |
| normalize, union, concat, shuffle, star | Formal expression text |
| perl-regex | Anchored Perl regex for an ordinary RE (no shuffle) |
| show, summary | Selected automaton; default minimized DFA summary |
| reverse, intersect, difference, symdiff, complement | DFA output in selected format |
| test | One `(+)` or `(-)` result per word |
| compare, subset, empty, finite | Yes/No, with predicate exit status |
| trace | JSON active NFA states before and after each input token |
| alphabet | JSON array of literal alphabet symbols |
| strings, somestrings, morestrings | One word per line; epsilon is a blank line |
| dump | Parsed expression tree (Data::Dumper) |
| random_re, random_pre | Random expression; optional --length and --seed |
| savedfa | Storable DFA file, no stdout |

`show --type` selects pfa, nfa, dfa, or min-dfa. Formats are summary, dot,
undot, gdl, jflap, digraph, undirected and json. JSON includes type, state IDs,
initial/accepting states, alphabet and transitions. PFA output describes nodes
and nodal edges; it is not a flattened FA state space. JFLAP export requires an
NFA/DFA. `--trim` is available on DFA output and can make its transition
function partial. Complement uses the input alphabet; difference and related
binary operations use the operands' combined alphabets.

The legacy export commands use the type prefix pfa/nfa/dfa and suffix gv,
undgv, digraph, or undirected. The documented undirectedgraph spelling is also
accepted. nfa2jflap and dfa2jflap export XML. Legacy dfa-prefixed exports now
consistently use a minimized DFA; use `show --type dfa` for an unminimized DFA.

FA-to-formal-RE, general negation (`~`) and hyper-minimization are not implemented
and are not presented as working CLI operations. The CLI exports currently
supported results rather than pretending to reconstruct missing expressions.

## Input and error contracts

```sh
printf 'a*b\nb\naaab\n' | fash -b test
printf '\n0\n' | fash test '[]+0'
printf 'a&b\n' | fash dfa2gv -
fash test '[foo][bar]' --tokens '["foo","bar"]'
fash trace '[foo][bar]' --tokens '["foo","bar"]'
fash compare 'a&b' 'ab+ba' --quiet
```

`-b test` uses the first stdin line as the expression and every later line as a
word. `test EXPR` without positional words reads words from stdin. Other uses
of EXPR `-` read an expression from stdin, including multiline expressions.
CRLF line endings are accepted; empty words, spaces and backslashes are retained.
For an expression and words in the same stream, use batch mode.

Ordinary word input consumes individual characters. Use `--tokens` for a JSON
array when the alphabet contains multi-character atomic labels. An empty JSON
array is the empty word. Token input is data, never Perl expressions.

| Exit | Meaning |
| --- | --- |
| 0 | Success, or a true predicate/all tested words accepted |
| 1 | False predicate, or at least one rejected test word |
| 2 | Usage, invalid expression, invalid option or invalid import input |
| 3 | Operation/export/file-write failure |

Results go to stdout; errors have a `fash:` prefix on stderr. False predicates
are ordinary results, not diagnostics. `--quiet` suppresses predicate result
text while keeping exit status. Unknown/abbreviated options and options that
do not apply to the selected command are rejected.

## Word generation

`strings` defaults to acyclic traversal and at most 100 output words. Use
`--limit 0` to remove the output cap. `--mode depth --depth N` allows at most N
visits per graph state. `morestrings EXPR N` retains the older positional-depth
syntax. `--delimiter TEXT` joins symbols, e.g. `[foo][bar] --delimiter ' '`.

These are bounded graph traversals, not complete enumeration of an arbitrary
infinite language. Bounds depend on automaton structure; output order is
unspecified. An output limit does not cap compilation time, graph size, or the
cost of searching before the next accepted word. Use small expressions when
exploring large shuffles. There is no implicit loading of expression-named
Storable cache files.

## JFLAP interoperability

```sh
fash dfa2jflap 'a&b' > example.jff
fash show --input-format jflap example.jff --type nfa --format dot
fash test --input-format jflap example.jff ab ba
fash show --input-format jflap example.jff --type nfa --format jflap > roundtrip.jff
fash compare --input-format jflap example.jff roundtrip.jff
fash dfa2jflap '[foo]' --expand-labels > foo.jff
```

The importer accepts finite-automaton `.jff` XML: the legacy JFLAP 4 top-level
layout and the later `automaton` layout. It handles sparse numeric IDs,
nondeterministic/parallel edges, epsilon reads (empty or omitted), and
multi-character reads. It returns an NFA; use `show --type dfa|min-dfa` to
convert it. In `--input-format jflap` mode all expression arguments name `.jff`
files, and `-` means XML from stdin. AST-only expression operations do not
accept this mode because FA-to-RE is still missing.

Export creates current nested FA XML, with one read symbol per transition,
escaped XML text, and default state coordinates. Multiple NFA starts get a
synthetic initial state with epsilon edges. Imported names, state labels and
coordinates survive direct import/export. IDs are renumbered, so XML is not
byte-identical. Transformations may replace states and their layout metadata.

JFLAP multi-character reads represent character sequences. Import expands them
into character-labeled paths. FLAT multi-character tokens require explicit
`--expand-labels` on export: this maps tokens to character strings, changing the
alphabet interpretation intentionally. No promise is made that token identities,
Perl references or occurrence provenance survive a `.jff` exchange.

Only type `fa` is supported. PDA/Turing/grammar files, hierarchical FA building
blocks, multiple initial states in an input file, and unsupported semantic XML
elements are rejected. Literal lambda is a character; only an empty read is
epsilon. DTD/entity declarations are not accepted. XML parsing uses XML::LibXML.

The tests include a published legacy JFLAP example, synthetic modern examples,
and language-equivalent round trips. They do not claim GUI testing against all
JFLAP releases. Format references:

- https://www.jflap.org/jflapbook/jflapbook2006.pdf (Appendix B, section 1.5)
- https://www.jflap.org/jflapbook/files/ex1.3a.jff
- t/data/jflap-4-ex1.3a.jff is that published example, unchanged.

## Saving and compatibility

`savedfa EXPR --output FILE` writes a Storable DFA. Without --output, the legacy
EXPR-derived `.dat` filename is retained. Existing files require `--force`.
There is deliberately no CLI command for loading arbitrary Storable data;
use JFLAP XML for exchange.

Compared with the shell wrapper: commands now have meaningful statuses; unknown
commands fail; dfa2gv emits DOT rather than XML; generators print only words,
without an expression heading; depth means maximum state visits; epsilon and 0
are real results; generators have a documented default output cap. The legacy
Perl string-generator adapters use the same iterator implementation, without
an output cap. Existing applications should test definedness, not truthiness,
when consuming iterator results.

## Installed manuals and Bash completion

`perldoc perlflat` is the library overview and `perldoc perlfash` is the CLI
manual. The latter also explains each workbench proposal in plain language,
with implemented and planned behavior clearly separated.

```bash
source <(fash completion bash)
```

This enables Tab completion immediately. The script completes commands,
applicable options, enum values and file paths, including names with spaces.
It neither compiles expressions nor invokes fash during completion. Its data
comes from the same command and option registry used by validation.

`make install` installs completion at
`PREFIX/share/bash-completion/completions/fash`, deriving PREFIX from the chosen
bin directory and respecting INSTALL_BASE, install type and DESTDIR. It is
recorded in the packlist. Automatic loading requires a loader that searches
that prefix (bash-completion 2.12+ supports executable prefixes). For older
loaders use the explicit source command or, for example:

```sh
make install FASH_COMPLETION_DIR=/usr/share/bash-completion/completions
make install FASH_COMPLETION_DIR=none
```

An absolute override is staged inside DESTDIR. The installer does not edit
shell startup files. Native Windows skips the Bash file. The generated script
itself needs Bash 3.2+, without helper-function dependencies.

Loader reference: https://github.com/scop/bash-completion

## Next UX improvements to consider

- JSON Lines for acceptance results, traces and words, including token arrays.
- Side-by-side conversion explanations and an interactive step/inspect REPL.
- Equivalence/subset counterexample words once the library provides them.
- Explicit compilation budgets and an optional conversion-progress display.
- A layout tool for generated JFLAP diagrams, and broader GUI/version fixtures.

See the PROPOSED WORKBENCH FEATURES section of `perldoc perlfash` for the six
plain-language explanations, current status and suggested implementation order.
