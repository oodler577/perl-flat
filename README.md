# SourceForge FLaT recovery evidence

Recovered 2026-10-29 from the public SourceForge repository and release downloads.
This is an archive branch, not the active library. The original initial release
is browsable in `initial-release/`; release tarballs are preserved byte-for-byte.

## Recovered history

- `archive/sourceforge/trunk`: r120, ending 2007-05-16.
- `archive/sourceforge/branches/estrabd`: recovered branch head r58.
- `archive/sourceforge/branches/perl-flat`: recovered branch head r21.
- tag `archive/sourceforge/DEV`: recovered tag r61.

The SVN log spans r1-r120, 2005-11-09 through 2007-05-16. Conversion produced
114 reachable Git commits, retaining original usernames and author dates to
one-second precision. Synthetic `<username>@<SVN-UUID>` Git email addresses
are git-svn identifiers, not verified personal email addresses. No guessed
identity map was applied. CVS-to-SVN manufactured branch/tag commits are kept.

`validation.json` lists the six revisions without separate Git commits and
records comparisons of every file at all four Git heads with restored SVN.
The full SVN dump preserves revision properties, fractional timestamps, empty
directories, copy paths and other data Git does not represent. It was loaded
into a fresh SVN repository; youngest revision and UUID matched. The bundle was
cloned into a fresh bare Git repository and passed `git fsck --full --strict`.
The mirror's unborn default HEAD can be set to `archive/sourceforge/trunk`.

## Restore

```
sha256sum -c SHA256SUMS
svnadmin create restored-svn
gzip -dc sourceforge.svndump.gz | svnadmin load --force-uuid restored-svn
git clone --mirror sourceforge-git.bundle restored-git.git
git --git-dir=restored-git.git symbolic-ref HEAD refs/heads/archive/sourceforge/trunk
```

The full conversion command was:

```
git svn clone --stdlayout --prefix=sf/ https://svn.code.sf.net/p/perl-flat/code/ history
```

Tool versions, provenance and hashes are included. SVN r120 was frozen for this
recovery; no live library sources were replaced. These archives and scripts
have not been certified for modern execution. Source license notices and
original attribution remain intact.

`FLAT-FA-0.2.tgz` has a `FLAT-FA-0.1` top directory and is byte-identical to the
BackPAN `FLAT-FA-0.1.tgz` examined earlier. Names alone are not version evidence.
The initial release includes a `dfa2re.pl` driver but no `to_re` definition.
An empty `to-re-history-search.txt` records no definition-introducing history
match for `sub to_re`; it is not evidence of a successful conversion algorithm.

See `docs/SOURCEFORGE-RECOVERY.md` on master for the comparison and inventory.
