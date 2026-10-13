# Task 7 report (K6 catalog language and builder)

Commit: 0395b061 feat(kit): the catalog language and the library builder (K6)
Files: packages/jet_cad_2d_kit/lib/authoring.dart (two exports), lib/src/authoring/catalog.dart, lib/src/authoring/builder.dart, test/authoring/builder_test.dart. Brief code used verbatim, then `dart format .`.

RED: `flutter test test/authoring/builder_test.dart` before the export: "Error: Method not found: 'encodeLibrary'." / "Some tests failed."
GREEN: `flutter test test/authoring test/invariants` -> "All tests passed!" (12).
Gate: `flutter test` -> "+188: All tests passed!"; `flutter analyze` -> "No issues found!"; `dart format --output=none --set-exit-if-changed .` exit 0.

Mutations (committed files, each reverted with git checkout, `git diff --quiet` exit 0):
- M-B1 (per-call handle start offset): `00:00 +0 -1: B1 deterministic: two builds give the same bytes [E]` (only B1 red)
- M-B2 (all definitions allocated first): `00:00 +1 -1: B2 handles ascend: a definition, its leaves, the next definition [E]`
- M-B3a (drop attachTo): `00:00 +2 -1: B3 every shape kind and every field round-trips through decode [E]`
- M-B3b (drop labelling): `00:00 +2 -1: B3 every shape kind and every field round-trips through decode [E]`
- M-B3c (arc start/sweep swapped): `00:00 +2 -1: B3 every shape kind and every field round-trips through decode [E]`
- M-B5 (delete SymbolLibrary.decode(bytes)): `00:00 +4 -1: B5 the format's refusals reach the generator [E]`
- M-P1 (import flutter/foundation.dart in builder.dart): `00:00 +0 -1: P1 lib/authoring.dart and every file under lib/src/model reach no Flutter, dart:ui or dart:io, and reach every authoring file [E]`
(A first M-B1 attempt looped on a counter in the loop condition and exhausted handles; discarded and redone as above.)

Concerns: none. Worktree clean after.
