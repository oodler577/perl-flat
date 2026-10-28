# JFLAP fixtures

`jflap-4-ex1.3a.jff` is the existing published JFLAP 4 example; see the original provenance notes in `docs/CLI.md`.

`jflap-synthetic-legacy.jff` and `jflap-synthetic-nested.jff` are project-authored format-contract examples, not files saved by a JFLAP GUI. Both describe the same automaton: sparse IDs, epsilon loop, multi-character character-path read, literal Unicode loop, label, coordinates and an unreachable state. Tests check acceptance and language equivalence after preserve/layered export and reimport.

These fixtures exercise both XML layouts without claiming certification against a particular GUI release. Direct open/save checks with additional JFLAP versions remain outstanding. Add genuinely GUI-saved fixtures with version, source and expected behavior when available; do not relabel synthetic files as version evidence.
