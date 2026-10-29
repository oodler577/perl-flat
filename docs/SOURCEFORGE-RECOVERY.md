# SourceForge recovery, comparison and salvage inventory

Recovered 2026-10-29. Active-code baseline for this review: `e1b1af9`.
The historical sources are archived separately; no old implementation was merged
into the active library during this recovery. Two paper examples and three legacy example languages
were reintroduced as modern semantic regressions.

## Where to browse

| Material | Location |
| --- | --- |
| SVN trunk through r120 | [archive/sourceforge/trunk](https://github.com/oodler577/perl-flat/tree/archive/sourceforge/trunk) |
| Original estrabd branch | [archive/sourceforge/branches/estrabd](https://github.com/oodler577/perl-flat/tree/archive/sourceforge/branches/estrabd) |
| Original perl-flat branch | [archive/sourceforge/branches/perl-flat](https://github.com/oodler577/perl-flat/tree/archive/sourceforge/branches/perl-flat) |
| Original DEV tag | [archive/sourceforge/DEV](https://github.com/oodler577/perl-flat/tree/archive/sourceforge/DEV) |
| Dump, standalone Git bundle, release archives, validation and hashes | [archive/sourceforge/evidence](https://github.com/oodler577/perl-flat/tree/archive/sourceforge/evidence) |
| Browsable November 2005 initial release | [initial-release](https://github.com/oodler577/perl-flat/tree/archive/sourceforge/evidence/initial-release) |
| All 119 legacy test expressions, with source paths | [legacy-test-corpus.json](https://github.com/oodler577/perl-flat/blob/archive/sourceforge/evidence/legacy-test-corpus.json) |

The evidence branch has its own root commit and restore instructions. It is not
a release branch. The converted history remains independent of master, preserving
its original ancestry rather than attaching old commits to the current squash.

## Preservation and validation

Source: `https://svn.code.sf.net/p/perl-flat/code/`.
Repository UUID: `29d5d42d-ca11-0410-8b08-e15d86285476`.

- SVN log and dump cover r1-r120, from 2005-11-09 to 2007-05-16.
- `git svn clone --stdlayout --prefix=sf/` recovered 114 reachable Git commits,
  two branches, trunk, and the DEV tag. Original username/date metadata matches
  the SVN log for every converted commit; Git dates have second precision.
- Revisions 6, 9, 19, 22, 59 and 60 have no changed paths and no separate
  git-svn commit. Their messages and revision properties remain in the dump/log.
- The raw dump was loaded into a fresh SVN repository. UUID and youngest revision
  match the source. The standalone Git bundle was cloned into a fresh bare
  repository and passed `git fsck --full --strict`.
- Complete file sets and every file's bytes match between each recovered Git
  head and its corresponding restored SVN path/revision: trunk 82 files,
  estrabd 39, perl-flat 18, and DEV 57.
- SHA256SUMS covers the evidence files and all extracted initial-release files.
  Release tarballs are retained byte-for-byte, with URLs and sizes in manifest.json.

The recorded Git endpoints are:

| SVN path | Revision | Git commit |
| --- | --- | --- |
| trunk | 120 | d792a1426b051670aeb9f797db0ee4fc22113027 |
| branches/estrabd | 58 | 9276b12de4e6db0dfe075d91e6b198c02116e732 |
| branches/perl-flat | 21 | 9b4ca3df601eefab0cb5078162a946ebcdfb9e29 |
| tags/DEV | 61 | c180183d6c64738d5f4e3814c2019c2b6d9ebbaa |

Author names are `estrabd`, `blokhead`, `root`, and `(no author)`. git-svn's
`username@UUID` addresses are identifiers, not asserted personal addresses.
The dump retains fractional dates, revision properties, empty directories and
SVN copy metadata that Git cannot fully represent. This recovers the available
CVS-to-SVN history, not an independently recovered original CVS RCS database.
Some scripts have embedded RCS keyword dates from September 2005, earlier than
the SVN import; those comments do not reconstruct missing earlier revisions.

## Release provenance

SourceForge's OldFiles folder supplied:

| File | SHA-256 | Observation |
| --- | --- | --- |
| perl-flat.initial.tgz | cd3115ad4304c5083aa2d3295c8d71a8d22ccda0ce1155b48650704b3a9a098b | Listed as November 10, 2005; pre-namespace RE/PRE/FA modules, drivers and fixtures |
| FLAT-FA-0.2.tgz | 72a8a9e24a15659b4a93214ba553ef05139ebf6852cc9393cdc75dfe564b09b5 | Its top directory says FLAT-FA-0.1; identical to the previously inspected BackPAN 0.1 archive |
| FLAT-FA-0.3.tgz | f119085ab57c92c1a8cbe4cb422dee2002aa238edf16b6428b2d3f5c3dedac68 | Matches the previously inspected BackPAN 0.3 archive |

Download base: `https://downloads.sourceforge.net/project/perl-flat/OldFiles/`.
Names alone are not sufficient evidence that two distributions differ.

## Timeline recovered from commits

| Revision(s) | Evidence |
| --- | --- |
| 1-3, November 2005 | CVS-to-SVN initialization and initial code import |
| 7, November 11, 2005 | blokhead adds the new FLAT/Regex implementation |
| 10-12, November 12, 2005 | Operators are factored out; extensible generated parser introduced |
| 25, November 15, 2005 | estrabd adds shuffle work and WithExtraOps |
| 33-35, February 2006 | Dense numeric state model, multivalued transitions, new NFA conversion and minimization |
| 57-61, March 2006 | FLAT::Legacy::FA packaging and manufactured DEV branch/tag copies |
| 78, October 2006 | PFA-to-NFA work and sink trimming in the newer implementation |
| 99-119, February/March 2007 | Node-list, depth-first traversal, acyclic-word and cycle-exploration experiments |
| 120, May 16, 2007 | Last available SVN revision; TODO file removed and Makefile.PL renamed |

This explains why the earliest CPAN release under the plain FLAT distribution
already uses RecDescent: the hand-written and rewritten implementations existed
alongside each other earlier under other names and repository paths.

## Initial release versus thesis, paper and current code

The user-supplied thesis, *An Investigation of Equivalent Serialized Forms of
Parallel Finite Automata* (Brett Dominique Estrade, 2005), printed page 8 / PDF
page 19, gives the R/P/O/C/S/L recursive-descent grammar. Appendix A lists the
module responsibilities; Appendix B gives the ab&cd and a&b* conversion examples.
The user-supplied 2006 paper, *Explicitly Parallel Regular Expressions*
(Estrade, Perkins and Harris), describes parse-tree traversal and modified
Thompson construction, then PFA serialization through an equivalent NFA.
The PDFs were consulted as references, not added to the software distribution.

| Area | Recovered initial/legacy design | Current implementation |
| --- | --- | --- |
| Parser | Hand-written R/P/O/C/S/L and continuation routines, mutable lookahead/concatenation flags | Original routines modernized with indexed lexer tokens, strict operands, located errors and AST spans |
| Precedence | Original PRE puts shuffle below union | Current semantics retained: star, concat, shuffle, union from tightest to loosest; no old-precedence mode |
| Epsilon | Several missing operands/empty groups become epsilon implicitly | Explicit [] required; malformed expressions remain errors |
| AST | Hash nodes with symbol/left/right/pos, plus an artificial end-marker for position construction | Existing operator nodes, literal/token atoms, optional source spans; no artificial language symbol appended |
| PRE-to-PFA | Modified Thompson traversal of the expression tree | Corresponding construction remains the supported representation route |
| PFA-to-NFA | Explicit active-node configurations, tied-node/lambda handling | Current PFA conversion preserves the same distinction between nodes and states |
| Direct RE-to-DFA | Position/followpos implementation explicitly named to_dfa_BROKEN | Supported route is via NFA; no broken position implementation promoted to public API |
| Symbols | Character strings and parser-position bookkeeping | Literal string keys plus optional immutable scalar/full tokens and shared payload bindings |
| Serialization | Text graph formats and object caches in drivers | Those are distinct from partial workflow execution or live-reference persistence; neither is recovered by replaying old drivers |

Source spans are not occurrence IDs. Repeated equal atoms still require distinct
positions if a future position automaton or action-occurrence analysis is built.
The original position/end-marker machinery is useful evidence for that design,
not something to append blindly to today's formal language.

## Salvage inventory and disposition

Paths below are relative to the recovered trunk unless stated otherwise.
"Candidate" means inspected and worth considering, not certified correct.

| Item | Recovered location | Status / disposition |
| --- | --- | --- |
| Original hand-written RE/PRE parsing | Initial RE.pm/PRE.pm; perl-flat-legacy/lib/FLAT/Legacy/FA/RE.pm and PRE.pm | Already recovered and modernized in the parser work; history now establishes the earlier lineage |
| Concrete language examples from the papers | Thesis Appendix B; initial conversion drivers | Two paper examples and three legacy cases now have exact modern regression expectations in t/data/recovered-language-cases.json |
| Larger generated expression corpus | perl-flat-legacy/t/FLAT-FA-RE.t and FLAT-FA-PRE.t | 43 RE and 76 PRE strings indexed in evidence. Old tests assert removed-state counts; do not import those counts as semantic truth |
| Direct position automaton | Legacy RE.pm: firstpos, lastpos, followpos, to_dfa_BROKEN | Valuable alternative-construction/teaching candidate. Explicitly broken; concatenation followpos uses right.lastpos where the standard construction requires right.firstpos. Reimplement against current AST with distinct occurrence IDs and equivalence tests before use |
| NFA/PFA/DFA text loaders and fixtures | Initial load_file/load_string routines and t/nfa.*, t/pfa.*, t/dfa.1; legacy t/input | Candidate for a small legacy-format import adapter or teaching fixtures. Not a reason to revive the old storage classes wholesale |
| Acyclic word enumeration | perl-flat/dev-scripts/all-strings-no-cycles.pl and bdetest.pl; r101-r110 predecessor methods | Confirms origin of today's bounded iterators. Current iterators already repair epsilon/zero and sibling-visit issues; compare behavior before copying code |
| Goal-directed cycle exploration | perl-flat/dev-scripts/explode.pl, r115-r119 | Prototype, not complete infinite-language enumeration. Useful for a future bounded cycle/path explorer with explicit guarantees |
| Equivalence demonstration | perl-flat/dev-scripts/pre_compare.pl | Covered by current compare/subset/witness commands; preserve as historical example, no duplicate feature needed |
| Stress/profiling tools | regex-stress.pl, pregex-stress.pl, legacy samples/make.tests.pl, profile.sh | Candidate workload sources. Replace process-ID seeding and output-only checks with seeded generation, independent acceptance/equivalence oracles, and meaningful timing |
| DFA-to-RE driver | Initial t/dfa2re.pl; legacy samples/dfa2re.pl | Calls to_re, but no implementation was found in the archive or searched module history. This is a driver-shaped placeholder, not a recovered state-elimination algorithm |
| XFA state-elimination outline | CPAN FLAT 0.9.0 lib/FLAT/XFA.pm, outside this SVN snapshot | Separate previously inspected archive: eliminate_states and as_re have empty bodies. Preserves intent, not an implementation to port |
| Finite-word construction | Legacy NFA.pm generate_from_strings | Returns Coming soon; not an implemented finite-language builder |
| Early pumping/random DFA methods | Initial DFA.pm generate_random, pump_strings, init_string_pump, pump_next | Empty or Coming soon bodies. Retain as roadmap evidence only |
| PRE symbolic transformation | perl-flat/lib/FLAT/Regex/Transform.pm and t/04-transform.t | Thin subclass/comment and placeholder test. No completed simplifier or CAS recovered |
| TODO and removed experiments | Trunk TODO before r120; DFA traversal code before r108 | Preserved in history even though absent at HEAD; useful research notes, not validated APIs |
| Shell and cache wrappers | Initial shell/f@sh.pl and later drivers | Superseded by the validated CLI. Do not restore old evaluation/cache-path conventions as current interfaces |

The to_re history search used `git log --all -S 'sub to_re' -- '*.pm'` and
found no definition-introducing commit. This does not prove that no unpublished
implementation ever existed. The recovered available history is the boundary
of this claim.

## Modern regression salvage

`t/19-recovered-examples.t` checks exact language equivalence against independent
ordinary-RE descriptions and verifies concrete accepted/rejected words:

- ab&cd against the six order-preserving interleavings.
- a&b* against b*ab*.
- Historical 0&1* against 1*01* (zero remains real data).
- Historical 00&100&1 against an independently enumerated finite shuffle set.
- Historical 01001|11(1|) translated to explicit epsilon and checked against
  the finite language {01001, 111, 11}.

A separate guard verifies modern precedence for 0|1&0. No old-precedence
compatibility mode or permissive malformed-expression handling was introduced.
Historical state-removal counts and unimplemented driver calls are not oracles.

## Recommended port order after this inventory

1. Expand the small recovered semantic corpus carefully, keeping current syntax.
2. If desired, add a legacy text-format adapter without reviving old graph classes.
3. Treat the firstpos/followpos route as a separate correctness-tested construction.
4. Use cycle prototypes as research input for an explicitly bounded explorer.
5. DFA-to-formal-RE still requires a real implementation; the recovered placeholder
   files do not close that gap.
