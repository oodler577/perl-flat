# FLaT development roadmap

Status: agreed direction, 2026-10-28. Production source baseline: CPAN FLAT
1.0.4, restored in commit 0ebfc29.

## Purpose

Build a useful Perl library and an approachable CS/student/hobbyist toolkit
for formal regular languages, while producing reproducible research artifacts.
Research questions guide experiments; unproved claims do not become API promises.

The longer-term workflow goal is adaptive partial serialization that respects
the ordering constraints of the original concurrent specification. Actual
parallel execution, potentially using MCE, is a separate runtime responsibility.

## Milestones and completion criteria

1. Reliable existing core.
   Repair finiteness, alphabet handling, DFA result invariants, starting-state
   mutation, sink removal, and zero/epsilon enumeration. Add deterministic
   regressions before repairs. Distinguish complete from partial DFAs.
   Done when the known-gap tests pass without TODO and existing tests pass.

2. Symbols and structured expressions.
   Separate symbol identity, display labels, payload bindings, and occurrences.
   Preserve original references within a process through graph transformations.
   Add explicit token-sequence APIs, named sublanguages, and AST construction.
   Done when distinct equal-content hashrefs remain distinct and the same
   reference survives composition, determinization, minimization, and cloning.

3. Incremental exploration and partial linearization.
   Add cursors with enabled symbols, acceptance, and residual-language views.
   First support selected PRE subtrees; investigate lazy PFA configurations and
   derivatives before choosing an implementation.
   Distinguish equivalent expansion, schedule restriction, and atomic nesting.
   Done when a nested reference-bound plan can advance without eager full-DFA
   construction, with reproducible trace checks.

4. Formal FA-to-RE conversion and algebra.
   Implement state elimination over an expression AST, distinguishing empty
   language from epsilon. Add simplification, elimination-order options,
   equivalence/inclusion and counterexamples. Compare direct NFA conversion
   with minimized-DFA conversion rather than assuming either is always better.
   Done when fixed and generated round trips establish language equivalence.

5. Analysis and teaching tools.
   Add reachable-state preamble/kernel decomposition, SCC/cycle witnesses,
   traces of algorithms, graph exports, examples, and an integrated CLI/REPL.
   Hyper-minimization is explicit approximate analysis, never an implicit
   exact-plan optimization.

6. Workflow runtime.
   Build a sequential reference interpreter, then an MCE backend. Preserve
   task occurrences and joins; define inputs/results, retries and failures.
   Add resource-budget changes at safe boundaries before considering
   interruption or migration of in-flight work.
   Done when changing worker counts preserves the specified execution contract.

## Packaging

Keep FLaT usable during repairs. Prototype the richer public API in a separate
distribution when the interfaces are concrete. Language::Regular is only a
working name: CPAN availability and namespace suitability remain unchecked.
Sub::Genius compatibility is an adapter goal, not the sole application.

## Source map

- lib/FLAT/FA.pm: state/transition storage, alphabet bookkeeping, cloning.
- lib/FLAT/Transition/Simple.pm: string-keyed transition labels.
- lib/FLAT/Symbol*.pm and Symbol/: existing symbol scaffolding.
- lib/FLAT/Regex/: parsing, operator AST, shuffle, transformation placeholder.
- lib/FLAT/PFA.pm: shuffle and PFA-to-NFA expansion.
- lib/FLAT/NFA.pm: epsilon closure and subset construction.
- lib/FLAT/DFA.pm: products, minimization, generators, hyper-minimization stub.
- scripts/dfa2re.pl: conversion placeholder.
- scripts/P-K-partition.pl: unfinished historical P/K prototype.
- t/02-fa.t: historical transition tests after __END__ are not executed.
- bin/fash and lib/FLAT/CMD/: existing CLI, requiring review and consolidation.

See DESIGN.md, RESEARCH.md, KNOWN_GAPS.md and DEVELOPMENT.md.
