# Research notebook and experiment plan

## Working question

Can a regular concurrent specification be partially serialized as resource
budgets change, while preserving its ordering contract and progress, with
useful benefits over a scheduler that merely limits active workers?

A candidate follow-up study is:
"Adaptive Partial Serialization of Parallel Regular Expressions under
Changing Resource Budgets." This is a working title, not a novelty claim.

The practical library and student toolkit are primary deliverables.
Definitions, algorithms, experiments and counterexamples should also be
reproducible artifacts suitable for research follow-up.

## Starting literature

- Estrade, Perkins, Harris (2006), Explicitly Parallel Regular Expressions.
  https://doi.org/10.1109/IMSCCS.2006.60
  Indexed text confirms scheduling and computational-resource reduction
  applications. The old LSU PDF is unavailable; recover a complete copy before
  making a comprehensive account of its claims.

- Concurrent Kleene Algebra: Free Model and Completeness (2018).
  https://doi.org/10.1007/978-3-319-89884-1_30
  Close mathematical comparison: refinement, partial orders, exchange law.
  Distinguish pomset semantics from ordinary shuffle word languages.

- Brzozowski Goes Concurrent: A Kleene Theorem for Pomset Languages (2017).
  https://doi.org/10.4230/LIPIcs.CONCUR.2017.25
  Concurrent expressions, derivatives and automata.

- Derivatives and partial derivatives for regular shuffle expressions.
  https://www.sciencedirect.com/science/article/pii/S0022000016301325
  Candidate foundation for incremental language cursors.

- GPI-Space.
  https://www.gpi-space.de/features
  Close operational comparison: Petri-net workflow readiness and dynamic
  resource scheduling. Study existing capabilities before claiming a gap.

- Apache Flink adaptive scheduling.
  https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/elastic_scaling/
  Related operational adaptation; current master documentation is moving.

- OpenCilk serial projection.
  https://www.opencilk.org/doc/reference/glossary/serial-projection/
  Useful comparison for parallel versus sequential execution semantics.

- Unfolding-based Partial Order Reduction (2015).
  https://doi.org/10.4230/LIPIcs.CONCUR.2015.456
  Independence and representative executions for verification; do not confuse
  exploration reduction with physical resource adaptation.

- Badr, Hyper-Minimization in O(n^2) (CIAA 2008).
  https://www.andrewbadr.com/files/hyper/ciaa32.pdf
  Preamble/kernel and approximate language equivalence.
- Badr, Geffert, Shipman (2009), Hyper-minimizing minimized deterministic
  finite state automata. https://doi.org/10.1051/ita:2007061

## First study boundaries

Use finite, structured plans, explicit action occurrences, declared
dependencies, and task input/result values. Adapt between dispatch decisions
without interrupting running actions. Begin with deterministic synthetic
workloads; add loops, failure and shared-memory models only when specified.

State clearly whether each transform preserves all traces or restricts them.
Prove the relevant safety and progress properties under stated assumptions.
Do not infer safe parallel effects from language equivalence alone.

## Baselines

1. Eager PRE -> PFA -> NFA -> DFA planning.
2. A ready-task scheduler with a simple worker cap and the same resource policy.
3. An incremental representation with no symbolic plan rewriting.
4. Incremental planning with selected symbolic refinements.

GPI-Space is a literature/architecture comparison initially; an empirical
comparison requires matched workloads and a reproducible installation.

## Measurements

Planning time, peak memory, materialized states/configurations, adaptation
latency, execution makespan, scheduler overhead and trace correctness.
Use fixed workloads and seeds; record hardware, Perl/module versions,
resource-change schedules, raw results and failures.
Separate planning savings from execution scheduling improvements.

Include duplicate labels, empty branches, nested boundaries and uneven task
costs. Test worker budgets shrinking and growing while work is in flight.
Check non-vacuity/progress in addition to inclusion.

## Immediate artifacts

- Deterministic baseline regressions.
- Explicit semantics and small worked examples.
- Source-linked related-work matrix with claim-by-claim comparisons.
- Reference interpreter and trace validator.
- Benchmark harness and raw results.
- A manuscript only after the supported claim is clear.

Open questions include whether symbolic adaptation adds benefit beyond worker
throttling and whether lazy PFA exploration or derivatives is the better
practical representation. Negative results are recorded, not hidden.

## Historical motivation: PRE schedule templates

Brett reports that in 2006 he proposed to his PI using PREs as schedule
templates for an OpenMP-oriented task scheduling approach. That proposal did
not progress. This is author-provided historical context, not a claim about
a particular OpenMP specification version or a publicly documented result.

A template denotes permitted orderings and concurrent structure; a concrete
execution strategy realizes it on available resources. Preserve this distinction
in the architecture and in the comparison with simple worker throttling.
MCE is an initial Perl execution-backend candidate. An OpenMP-oriented backend
or template exporter is a possible later application, not an initial commitment.
