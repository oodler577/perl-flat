#!/usr/bin/env bash
set -euo pipefail
# Run from the repository root. No writes to system installation directories.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

dzil build --in "$work/dist"
cd "$work/dist"
perl Makefile.PL INSTALL_BASE=/opt/flat-ci
make
make install DESTDIR="$work/stage"

export PERL5LIB="$work/stage/opt/flat-ci/lib/perl5"
export PATH="$work/stage/opt/flat-ci/bin:$PATH"
cd "$work"
perldoc -U -T perlflat > perlflat.txt
perldoc -U -T perlfash > perlfash.txt
test -s perlflat.txt
test -s perlfash.txt
fash compare 'a+b' 'b+a' --witness
# Rejection is a valid result, with a token-preserving witness.
status=0
fash subset '[]+a' a --witness > witness.txt || status=$?
test "$status" -eq 1
grep -F '"tokens":[]' witness.txt
fash show ab --type nfa --format jflap --layout layered > example.jff
fash test example.jff --input-format jflap ab

completion="$work/stage/opt/flat-ci/share/bash-completion/completions/fash"
bash -n "$completion"
bash --noprofile --norc -c 'source "$1"; COMP_WORDS=(fash compare --w); COMP_CWORD=2; _fash; [[ " ${COMPREPLY[*]} " == *" --witness "* ]]' bash "$completion"
# The completion hook records its logical path, matching its uninstall contract.
perl -MExtUtils::Packlist -e '
    my @files = glob "$ARGV[0]/lib/perl5/*/auto/FLAT/.packlist";
    die "expected one packlist" unless @files == 1;
    my $pack = ExtUtils::Packlist->new($files[0]);
    die "completion missing from packlist" unless exists $pack->{"/opt/flat-ci/share/bash-completion/completions/fash"};
    die "staged completion path recorded" if exists $pack->{"$ARGV[1]/opt/flat-ci/share/bash-completion/completions/fash"};
' "$work/stage/opt/flat-ci" "$work/stage"

cd "$work/dist"
make install DESTDIR="$work/disabled" FASH_COMPLETION_DIR=none
test ! -e "$work/disabled/opt/flat-ci/share/bash-completion/completions/fash"
make install DESTDIR="$work/custom" FASH_COMPLETION_DIR=/etc/bash_completion.d
test -f "$work/custom/etc/bash_completion.d/fash"
printf '%s\n' "Installed manuals, CLI, JFLAP, completion, packlist and install overrides passed."
