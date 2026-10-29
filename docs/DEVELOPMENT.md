# Development

The source version remains FLAT 1.0.4. No release/upload is part of preparation.

## Dependencies

- Perl, make and a C toolchain as needed by dependencies.
- Parse::RecDescent and XML::LibXML (runtime).
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
