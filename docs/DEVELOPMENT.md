# Development

The source version remains FLAT 1.0.4. No release/upload is part of preparation.

## Dependencies

- Perl, make and a C toolchain as needed by dependencies.
- XML::LibXML (runtime); Parse::RecDescent only for optional parser oracle tests.
- Test::More (tests).
- Dist::Zilla with the plugins named in dist.ini, including
  Dist::Zilla::Plugin::MakeMaker::Awesome (maintainer distribution builds only).

On the current Ubuntu VM:

    apt-get install libdist-zilla-perl libdist-zilla-plugin-makemaker-awesome-perl libparse-recdescent-perl libxml-libxml-perl

Other systems may install the equivalent dependencies through their normal
Perl toolchain. The apt command is a VM setup example, not a portable installer.

## Commands

Run from the checkout root:

    prove -lr t
    prove -lv t/07-release-104.t t/08-known-gaps.t t/09-core-semantics.t
    dzil build
    dzil test

The historical known-gap file now contains ordinary passing regressions for
seven repaired baseline defects. The semantic tests cover epsilon-only and
consuming cycles, set operations, DFA invariants, partial transitions, sink
removal, and bounded word enumeration.

Existing generator tests are randomized and the total check count varies.
New regressions should be deterministic. Long historical PFA tests are opt-in
via FLAT_RUN_LONG_TESTS; they are not part of the default preparation check.

Dist::Zilla creates local build products. Do not commit those artifacts or
upload a distribution unless performing an explicit release task.

## Validation baseline

The preparation commit recorded the baseline; the subsequent cleanup repairs
its seven reproduced defects. Release-specific tests protect the recovered
parser-character and generator-delimiter changes. See KNOWN_GAPS.md for the
remaining limitations and iterator compatibility notes.

## Manuals and Bash completion

Built distributions install lib/perlflat.pod and lib/perlfash.pod through normal
MakeMaker POD/module handling. Check them with `perldoc perlflat` and
`perldoc perlfash` outside the checkout, using the same Perl installation.

`fash completion bash` generates a script from the command/option registry.
The MakeMaker::Awesome footer adds an installation hook for Perl, site and
vendor installs. It installs completion under the executable prefix, respects
DESTDIR and records it in the packlist. Generated Makefile.PL does not require
Dist::Zilla or the plugin. `make install FASH_COMPLETION_DIR=none` opts out; an
absolute FASH_COMPLETION_DIR overrides the default inside the staging root.
Older bash-completion loaders may require an explicit directory override or
`source <(fash completion bash)`. See `perldoc perlfash`. No shell RC is edited.

## Continuous integration

GitHub Actions runs on pushes, pull requests, and manual dispatch. Source tests
run on Perl 5.32, 5.38 and 5.40. A distribution job uses Dist::Zilla and runs
`bash ci/check-installed.sh` to check staged installation, both perldoc manuals,
CLI witnesses, JFLAP layout, Bash completion, packlist paths and installation
overrides. The script writes only to temporary directories.

The downstream job tests Sub::Genius 0.314006 at commit
`a63042dcad686b1739e51e36fa2624ad4b7c66b9` against this checkout's FLaT library.
Pinning the consumer keeps failures reproducible; update the ref deliberately
when adding coverage for a newer Sub::Genius release. These jobs do not publish
to CPAN or certify JFLAP GUI compatibility.

## Hand-written parser verification

Normal runtime no longer requires Parse::RecDescent. The source CI matrix also
runs `prove -l xt/parser-parity.t` against the frozen previous grammar. Install
Parse::RecDescent only for this optional oracle. It compares grammar acceptance
and ASTs for fixed errors and seeded RE/PRE expressions.

`perl author/bench-parser.pl --baseline /path/to/old-checkout --iterations 500 --startups 10`
compares startup and repeated parsing separately on the same Perl interpreter.
Performance is workload-dependent and is not a CI threshold. Default parser
limits are 1,000,000 input characters, 65,536 characters per bracketed key, and
128 nested groups. They do not bound FA compilation.

ASTs remain blessed arrays. Parsed nodes expose optional `source_span` metadata;
programmatic `atom`, `epsilon`, `empty`, and `from_op` factories support literal
keys and explicit symbol tokens. Source spans are diagnostic metadata, not
serialized occurrence IDs. No new bracket-escape syntax is introduced.
Recovered historical source under `historical/parser` is not a runtime backend.

The modern parser is a port of the recovered original grammar routines, whose
source is preserved under `historical/parser`. Precedence follows the later API
(union below shuffle), with no legacy mode. Modern literals and strict operand
validation are retained rather than all old quirks.

A sample run is recorded in `author/parser-benchmark-sample.csv`: 2,100
constructor parses of the seven-expression corpus took 17.84 seconds in the
previous checkout and 0.27 seconds in the port on the same VM/Perl 5.38.2.
Ten library startups took 0.95 and 0.39 seconds respectively. These are sample
measurements, not universal speed guarantees or automaton-compilation timings.
