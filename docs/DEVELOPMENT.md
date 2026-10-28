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
    prove -lv t/07-release-104.t t/08-known-gaps.t
    dzil build
    dzil test

The known-gap file contains seven expected-failing TODO checks. A successful
suite run does not mean those defects have been repaired. Remove the relevant
TODO when a repair and its regression are ready.

Existing generator tests are randomized and the total check count varies.
New regressions should be deterministic. Long historical PFA tests are opt-in
via FLAT_RUN_LONG_TESTS; they are not part of the default preparation check.

Dist::Zilla creates local build products. Do not commit those artifacts or
upload a distribution unless performing an explicit release task.

## Validation baseline

The preparation commit adds documentation and tests without changing runtime
algorithms. Release-specific tests protect the recovered parser-character and
generator-delimiter changes. See KNOWN_GAPS.md for behavior still needing repair.
