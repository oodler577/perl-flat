# Recovered hand-written FLaT parsers

Recovered from Brett Estrade's `FLAT-FA-0.5.tgz` on BackPAN. These files are
preserved byte-for-byte as historical source, not loaded by the current library.
Their packages and parse-tree representation predate the current FLaT AST.

Archive: https://backpan.perl.org/authors/id/E/ES/ESTRABD/FLAT-FA-0.5.tgz

Archive SHA-256:
`a08e850e40f81a9c6b575459d7ff08aca0115608a7d2aa5bb4a89f8062a2b28d`

| File | Original archive path | SHA-256 |
| --- | --- | --- |
| RE.pm | FLAT-FA-0.5/lib/FLAT/FA/RE.pm | 883301cd16c54c3157da04e5b9501a0c550430c108e125dd1276da93792caa4e |
| PRE.pm | FLAT-FA-0.5/lib/FLAT/FA/PRE.pm | b9ee9ed5cbf492da307448b657e31926688ee99cb17a7e43593bac220db1343e |

`RE.pm` implements `parse` at line 394 and `nexttoken` at line 431, with grammar
routines `R`, `O`, `O_prime`, `C`, and others. `PRE.pm` implements `parse` at
line 162 and `nexttoken` at line 199, including parallel composition routines.
These are hand-written recursive-descent implementations, not Parse::RecDescent
clients. They construct hash-based trees with symbol/left/right/position fields.
The archive's Changes file identifies an original version dated February 21,
2006; that is not independently verified as the upload date of version 0.5.

The hand-written routines also survive in FLAT-FA 0.1 through 0.4 and in the
FLAT-Legacy-FA archive family. The FLAT 0.9.0 release already uses
Parse::RecDescent. BackPAN also retains the FLAT.FA and flat-fa name variants.
The current upstream main history terminates at the later squash, so the release
archives are the successful recovery source.

Do not add this directory to PERL5LIB or treat these files as a current parser
backend without porting and testing their older syntax and representations.
