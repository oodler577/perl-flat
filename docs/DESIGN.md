# Design decisions and open questions

This is primarily a proposal. The optional symbol layer is now implemented:
`FLAT::Symbol::Token` stores an explicit stable key, display label and optional
shared payload; `FLAT::Symbol::Token::Scalar` is the scalar-backed variant.
`alphabet` remains string keys, and `contains_tokens` matches key/object arrays.
Explicit keys define identity; payload reference identity is used to detect
conflicting bindings, not to generate implicit address-based keys. Distinct
keys can carry identical payloads or equal-content distinct references.
See `perldoc FLAT::Symbol::Token` for the implemented contract; the remaining
expression, occurrence and execution design below is future work.

## Symbols and input

An alphabet contains atomic symbols. Internally use opaque IDs, with distinct
display labels and payload bindings. Keep epsilon and PFA lambda outside the
user-symbol namespace. Reconcile registries when combining languages.

Default reference equality is identity. Two equal-content hashrefs are distinct
symbols; mutating a hash does not change identity. Retain strong payload
references while needed. Structural graph copies preserve payload identity,
without accidentally sharing mutable graph bookkeeping.

Distinguish an alphabet symbol from a named variable denoting a whole language.
Track occurrence identities separately when execution or provenance requires it.
Language equivalence may discard distinctions that execution must retain.

Begin with explicit token arrays. Unicode labels use exact equality, no implicit
normalization/case folding. Keep operators fixed, quote labels, escape invisible
and control characters in diagnostics, and bound parser/label input sizes.
Do not introduce grapheme segmentation or Unicode property-class semantics in
the initial interface.

Within-process reference identity is a library contract. Worker processes need
an explicit input/result transfer contract; live references are not persistent
identifiers and arbitrary payloads are not automatically portable. Persist
symbolic structure separately from runtime bindings.

## Expression representation

Preserve structured expressions, named sublanguages, and source locations.
Prefer immutable nodes and shared subexpressions. Initial operators are empty
language, epsilon, atom, union, concatenation, star and shuffle.
Intersection/complement need explicit alphabet semantics.

Keep symbolic expressions, PFA configurations, NFAs and DFAs available as
alternative representations. Compilation should be a requested operation.
Retain optional source-to-result mappings through conversions.

## Four different operations

For (a & b) & c:

| Operation | Example | Contract |
| --- | --- | --- |
| Equivalent expansion | (ab + ba) & c | Same word language |
| Select an inner ordering | ab & c | Restricted word language |
| Atomic nested execution | execute ab or ba as a block alongside c | Additional execution boundary |
| Consume prefix a | residual b & c | Left quotient by the consumed prefix |

An atomic nested block disallows interleaving c between its internal actions.
Plain parentheses do not create that boundary. Atomicity must be represented
explicitly, not inferred from grouping.

Finite nonrecursive named composition stays within the intended setting.
Unrestricted recursive or runtime-generated subplans require a separate
semantics and are outside the initial regular-language guarantees.

## Cursors

Proposed operations: enabled_symbols, advance, accepting, residual.
An enabled symbol is permitted by the specification; this does not establish
application readiness, resource availability, or successful execution.
A language cursor must retain alternatives when an input symbol can arise from
multiple branches. Scheduling an action occurrence requires richer occurrence
and dependency information than a set of enabled labels alone.

Prototype both lazy PFA configuration exploration and shuffle-expression
derivatives. Measure their costs against eager subset construction.
Neither approach guarantees avoidance of worst-case exponential growth.

## Adaptive execution contract

Separate:
1. symbolic transformations preserving the full language;
2. scheduling refinements that restrict permitted executions;
3. backend execution and its effects.

For completed traces, adapted-language inclusion in the original language is a
safety condition. Inclusion alone is insufficient: empty behavior also satisfies
it. Define progress, deadlock handling, required work and fairness as applicable.

Use explicit task occurrences and dependency/join structure. Word-language
equivalence alone loses the distinction between parallel a & b and alternative
sequential orders ab + ba. Preserve that structure for scheduling.

Initial adaptation happens at safe boundaries, retaining completed prefixes and
tracking running tasks. Do not silently restart, discard or duplicate actions.
Worker loss/retry and exactly-once effects require separate contracts.

"Sequential consistency" needs an explicit observable-action and visibility
model. Trace acceptance does not prove correctness of arbitrary shared-memory
callbacks. Begin with explicit task inputs/results and declared dependencies.

## Runtime separation

- Language layer: symbolic operations, automata, residuals, analysis.
- Workflow layer: occurrences, dependencies, nested boundaries, bindings.
- Scheduler: readiness, resources, dispatch, completion and failure.
- Backend: sequential reference execution, then MCE.

Sub::Genius is an integration case. Resource-adaptive workflows and teaching
tools should use the same mathematical foundation without requiring it.

## Decisions still open

- Registry ownership and collision-free composition.
- Detailed token APIs and backward compatibility.
- Representation of atomic nested regions and their observable traces.
- Alphabet universe for complement and cross-alphabet operations.
- Ordering and fairness guarantees of iterators.
- Simplification rules preserving execution annotations.
- Persistent cache keys, versions and payload rebinding.
