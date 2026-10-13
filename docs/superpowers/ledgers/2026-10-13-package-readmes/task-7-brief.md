### Task 7: 0.7.2 — versions, constraints, CHANGELOGs, the guide (D10)

**Files:**
- Modify: `packages/{jet_cad_2d,jet_cad_2d_flutter,jet_cad_floor_plan}/pubspec.yaml` (`version`, constraints)
- Modify: every other live-line pubspec naming a published package (the list in `dependency_lines_test.dart`)
- Modify: `packages/*/CHANGELOG.md` (three), `CHANGELOG.md` (root index)
- Modify: `docs/host-guide.md` (§1: the version, `^0.7.2`), `tool/ci/host_probe/pubspec.yaml.in` (`^0.7.2`)
- Modify: `tool/ci/test/dependency_lines_test.dart` (DL2's `'^0.7.2'`, DL3's example), `tool/ci/test/guide_test.dart` (GD3's strings)

- [ ] **Step 1: The tests first.** DL2 expects `'^0.7.2'`; GD3 replaces `'jet_cad_floor_plan: ^0.7.2'` with `'jet_cad_floor_plan: ^0.7.3'`. `cd tool/ci && dart test`: DL2 and GD3 red (quote them).

- [ ] **Step 2: Versions and constraints.** `version: 0.7.2` in the three; every `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan` constraint in the live line's pubspecs (including `tool/screenshots` and `tool/readme_probe`) `^0.7.2`; `pubspec.yaml.in`'s line `^0.7.2`; the guide's §1 block and text (line 7 "**0.7.2**", line 24, line 33 "0.7.2 is built and tested with Flutter 3.47.6"); leave every "Since 0.7.0" marker and the schema 10 paragraph's version list (add 0.7.2 to "saved by 0.6.0, 0.7.0 or 0.7.1" at line 2271 and to line 2275's list). `flutter pub get`; `git status --short`.

- [ ] **Step 3: CHANGELOGs.** Each package's file gains, above `## 0.7.1`:
  - engine: `## 0.7.2` — the README links the renderer, the planner and the host guide, and says a host adds only the planner; funding links (GitHub Sponsors, Buy Me a Coffee). No code change; plans are stored as in 0.7.1.
  - renderer: `## 0.7.2` — screenshots (pub.dev gallery and README) of the canvas light and dark, the selection's grips, the crossing band and the symbol gallery; the README's package table and host guide link; funding links; `jet_cad_2d: ^0.7.2`. No code change.
  - planner: `## 0.7.2` — exports `SymbolLibraryState` (`SymbolLibraryLoading`, `SymbolLibraryReady`, `SymbolLibraryFailed`) and `TableNumberProblem` (R-10: a host implementing `FloorPlanStrings` no longer imports `editor.dart`); screenshots of the editor light and dark and of the service view (statuses and a group, a POS theme with a zone in focus, a rubber band, table colours); the README's package table; funding links; `jet_cad_2d: ^0.7.2`, `jet_cad_2d_flutter: ^0.7.2`. Plans are stored as in 0.7.1 (schema 10).
  The root `CHANGELOG.md`'s index names each package's 0.7.2.

- [ ] **Step 4: Green.** `cd tool/ci && dart test` (DL2, GD3 green); `dart run tool/ci/check_guide.dart`; each package's CLAUDE.md gate (the engine's and the renderer's change only pubspecs and CHANGELOGs: their suites must still match the standing lists). Commit, then from each package directory `dart pub publish --dry-run`: "Package has 0 warnings." each (the version bump has its CHANGELOG entry; the tree is committed). Commit: `git commit -m "chore: jet_cad_2d, jet_cad_2d_flutter and jet_cad_floor_plan 0.7.2"`.

---


## Controller amendment (Ruling R6, Task 3b, commit 5600f4f)

The renderer is no longer "No code change" in 0.7.2: `RulerFrame` now passes
the ambient `DefaultTextStyle`'s font family to the rulers' labels (and the
corner's unit symbol), so the rulers follow the host's text font; with no
ambient family the labels are drawn exactly as in 0.7.1. Its CHANGELOG entry
says so in one or two sentences, and drops "No code change." The planner's
entry may mention that its editor's rulers now use the app's font through
that change.
