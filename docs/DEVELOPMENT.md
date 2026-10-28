# Development

The source version remains FLAT 1.0.4. No release/upload is part of preparation.

## Dependencies

- Perl, make and a C toolchain as needed by dependencies.
- Parse::RecDescent (runtime).
- Test::More (tests).
- Dist::Zilla with the plugins named in dist.ini (distribution builds).

On the current Ubuntu VM:

    apt-get install libdist-zilla-perl libparse-recdescent-perl

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
