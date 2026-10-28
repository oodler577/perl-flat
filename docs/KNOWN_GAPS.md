# Baseline defects and remaining gaps

The seven defects below were reproduced against CPAN 1.0.4 and are now repaired
in the development checkout. t/08-known-gaps.t retains their regressions without
TODO markers; t/09-core-semantics.t exercises related semantic edge cases.
This does not imply that every advertised operation has been completed.

| Repaired baseline defect | Reproducer / expected behavior | Entry point |
| --- | --- | --- |
| Finiteness | ab*c is infinite, including after conversion | NFA::is_finite |
| Alphabet handling | {a} minus {b} accepts a | FLAT::difference, DFA::complement, NFA::_extend_alphabet |
| DFA invariants | Union must not return a DFA with two starts | NFA::union, FA::_swallow |
| Start mutation | unset_starting must return rather than recurse | DFA::unset_starting |
| Renumbering | Removing multiple sinks must preserve accepting states | DFA::trim_sinks |
| Zero word | A generator must emit the accepted word 0 | DFA iterator truth tests |
| Epsilon | A generator must emit an accepted empty word | DFA iterator initialization/return |

Remaining review findings, not all represented as automated regressions yet:

- String acceptance splits characters even when labels are multi-character
  tokens; define token acceptance explicitly before extending this API.
- Transitions stringify references; dclone copies payloads; new output
  automata reconstruct labels. Object symbols need an end-to-end contract.
- FA-to-RE conversion is missing; several RE operations depend on it.
- Shuffle and negation AST operations have explicit unimplemented paths.
- Transition/successor/pruning tests after __END__ in t/02-fa.t do not run.
- Some randomized generation tests assert only that emitted words are valid,
  without checking that required words were emitted.
- Regex::Util::get_random does not propagate symbol_len through its recursive
  calls; strengthen the purported multicharacter test cases.
- Basic state validation, partial/complete DFA behavior, exports and docs
  need systematic consistency checks.

Historical TODOs include parser/parameter diagnostics, parser performance,
symbol-count cleanup, PRE transformation iterators, hyper-minimization,
P/K graph exploration, and cycle-to-word exploration in scripts.
Abstract FLAT::Transition methods are intentional interfaces, not six separate
missing features. PFA documentation saying "not implemented yet" is stale.

## Compatibility notes

Generators now return an accepted empty word and the word "0" correctly. Only
undef denotes exhaustion: use while (defined(my $word = $next->())). Acyclic
iteration no longer revisits the starting state, and sibling paths no longer
share visited-state marks. Bounded traversal is graph-dependent; output order
is unspecified.

DFA union, concatenation, star and reversal now explicitly construct an NFA
intermediate and determinize the result. as_nfa returns an actual FLAT::NFA.
trim_sinks removes all states that cannot reach acceptance, while retaining
the initial state even for an empty language. It can produce a partial DFA.
Complement completes missing transitions over the current alphabet; difference
uses the operands' combined alphabets. An independently declared alphabet
universe remains future work.

CLI cleanup replaces shell interpolation, fixes DFA/DOT dispatch, and routes
legacy generator adapters through the bounded iterators. See CLI.md for JFLAP
character/token mapping and remaining import/export restrictions.
