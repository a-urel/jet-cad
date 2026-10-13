# Final fix wave: report

Status: DONE. Nine commits on `feat/kit-architecture` on top of `fea46c30`. Nothing pushed, merged, tagged or published.

## Commits

| SHA | Subject | Brief item |
|---|---|---|
| f845bc71 | test(kit): pin rule 15's radius and line tolerance boundaries | 1 (FR2) |
| 6dbf4c0f | feat(kit): refuse a zero-length polyline and an outline with no area | 2 (FR8) |
| 6a270b51 | fix(kit): buildLibraryDocument disposes its document when building throws | 3 (FR9) |
| 47af5452 | test(kit): library FormatException is rule 2, a non-finite y, tool:sample | 4 |
| 096d1468 | ci(kit): check every Dart file of a kit, picked by its pubspec name | 5 (FR6) |
| d0a4349a | test(kit): every Dart block of docs/kits.md and the README is in example/ | 6 (FR7) |
| 4a2ce84f | docs(kit): say what the conformance test checks today; the retired mark is sub-project 2's | 7 (FR4, FR5) |
| 0dee1fb9 | docs(spec): the kit contract's final-review amendments and sub-project 2's inputs | 8 |
| 6464ad7f | docs: the kit contract's results note says only what the record holds | 9 (FR3) |

Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (`git log -9 ... | grep -c` printed 9). Files staged by explicit path only. No analysis_options.yaml touched; `git status --short` was empty after every gate.

## What changed

1. **FR2** (`test/model/symbol_library_test.dart`, rule 15 group): V15t/V15u circle and arc radius `linear/2` refused; V15v/V15w radius exactly `Tolerance.standard.linear` refused ("at or under"); V15x radius `2 * linear` loads (circle and arc, positive control); V15y a line `linear/2` long, off the origin (120, 340), refused; V15z a line `2 * linear` long loads (positive control).
2. **FR8** (`lib/src/model/symbol_library.dart`):
   - Rule 15: after the `pointCount < 2` check, `_allWithinTolerance(p)` refuses a polyline whose every two points are within `isDegenerateSegment` (distance <= `Tolerance.standard.linear`) of each other; message "is a zero-length polyline: its points all lie within the tolerance of each other". Pairwise, as the ruling says "of each other"; it stops at the first pair further apart (for a drawn polyline, its first two points).
   - Rule 11: a unit whose first leaf is a closed polyline is refused when `_enclosedArea` <= linear² (1e-18). The area is the unsigned shoelace area, taken relative to the first vertex so far-from-origin coordinates do not cancel (a collinear outline off the origin gives exactly 0.0). Circles are skipped: rule 15 already holds their radius above the tolerance.
   - Tests: V15aa (three points within linear/2, off origin), V15ab (closed polyline of one point: two equal points), V15ac positive control (points within 0.9·linear of the first but 1.8·linear apart load: pins "of each other"), V15ad positive control (a repeated first vertex loads); V11c (collinear closed outline on a diagonal, off the origin, "encloses no area (0.0)"), V11d (area linear²/2 = 5e-19, near the origin: the only place a double can hold so thin a triangle), V11e positive control (area 2·linear² loads), V11f positive control (clockwise outline loads).
   - Note: at coordinates of ~1000 mm the smallest non-zero area a double can express is far above 1e-18, so off the origin the rule in practice refuses exactly-degenerate outlines (collinear or back-and-forth). That is what the ruling's threshold gives; recorded here, not changed.
3. **FR9** (`lib/src/authoring/builder.dart`): everything after `DraftDocument.empty()` is in `try { ... return doc; } catch (_) { unawaited(doc.dispose()); rethrow; }`; the doc comment names the case. B8 in `test/authoring/builder_test.dart` builds a catalog with `CatalogPolyline([], closed: true)` and expects `throwsStateError` from both `buildLibraryDocument` and `encodeLibrary`. **Why only the code path changed:** the leak is not observable. The document never reaches the caller on a throw, and `DraftDocument.dispose()` only closes the command stack's stream controller; the engine keeps no registry of live documents, and the engine is out of scope (A12). B8 is therefore labelled a premise check (exempt from the mutation rule): it pins that this payload throws after the document exists and that the error reaches the caller unchanged. The obvious mutation (remove `rethrow`) does not compile (non-nullable return), so it cannot be run.
4. **Cheap minors**: V2f (`jetcad.library` with `format: "1"` → `FormatException` in `fromJson` → rule 2); V12b (base point `[1250.0, 1e999]`); PlanKit K4 list gains `'tool:sample'` with an M-K4c comment; `parseSnapshot`'s doc now says each entry is re-encoded compactly, only white space normalised, key order and number spelling kept, so `1` vs `1.0` reads as changed (fails closed).
5. **FR6** (`tool/ci/lib/kit_deps.dart`, `tool/ci/check_kit_deps.dart`): new `generatedDirectories = {'build', '.dart_tool'}`, `isPackageDartFile(path)` (any `.dart` file whose first path segment is not one of those) and `packageName(pubspec)` (null when not YAML/not a map/no string name). The script now picks a package by its pubspec name (an unreadable pubspec is still checked so `kitDepsProblems` reports it), lists the package's top-level entries, skips the two generated directories without descending into them, and reads every `.dart` file under the rest (including root-level files). Tests: D13 (`isPackageDartFile` cases incl. `example/`, `bin/`, root file, `lib/src/build/`), D14 (`packageName`), D15 (script: a kit's `example/main.dart` importing the plan and `bin/demo.dart` importing another kit are both named; `.dart_tool/gen.dart` is not), D16 (directory `cinema` with pubspec `jet_cad_2d_kit_cinema` is checked). Header comments updated.
6. **FR7** (`test/invariants/doc_snippets_test.dart`). The rule, exactly as the test's header states: a block is the lines between a line that is exactly "```dart" and the next line that is exactly "```". Each of its lines, followed by a newline, must appear as one contiguous run of whole lines (at the file's start or right after a newline) in one `example/*.dart` file. Nothing is ignored or normalised inside the run; the example files' leading comments that the documents omit simply lie before the run, so no comment-skipping exception is needed. DOC1 runs over `../../docs/kits.md` (4 blocks, count pinned) and `README.md` (1 block, pinned); DOC2 is a premise check of the run matcher.
7. **docs/kits.md**: §1 says "an import of any of its Dart files (`lib/`, `test/`, `tool/`, `example/` and every other directory but `build/` and `.dart_tool/`)"; §2 says the conformance test refuses a key under another id today and checks type and tool ids when the code side arrives, and that `PlanKit.validate` already reports foreign words incl. `tool:`/`type:`; §4 rules 11 and 15 name the two new refusals; §8 "a retired symbol stays in the library. Taking a retired symbol out of the gallery is the plan library's sub-project: the contract has no retired mark yet."; §9 item 6 adds "a test that `kit.validate()` is empty" and why. DOC1 stays green (no Dart block changed).
8. **Spec** (`docs/superpowers/specs/2026-10-13-kit-contract-design.md`): K3 rules 11 and 15 amended inline; K9 amended inline (every Dart file; I added this because K9's text otherwise contradicts the code after FR6); new section "Amendments from the final review (2026-10-13)" (rule 15, rule 11, K9, the docs' retired sentence) and "Inputs for sub-project 2" with R1-R6 as the brief words them (R2 states that a later field must be optional when read, absent = default `false`).
9. **Results note** (`docs/superpowers/notes/2026-10-13-kit-contract-results.md`): "(macOS)"/"(Linux)" removed; hash tests "fail identically on the clean main checkout", goldens "were reported pre-existing" (both in Gates §3 and in the Rulings list); Task 1's one flaky `query_allocation_test` run added; the mutations preamble now says "As the task reports record" and names Task 9's left mutation (`libraryKitMismatch` check deleted in `conformance.dart`) reverted by the controller; `[E]` markers attributed to Task 3 only; the plan-decision line on `check_kit_deps` notes the widening; a "Final fix wave" section lists the commits, the mutation table and the re-run gates.

## Mutations (each on a committed file, reverted with `git checkout --`, then `git diff --quiet -- <file>`; each printed `revert diff exit 0`)

- **M-V15t** `if (p.scalars[0] <= 0)` (committed f845bc71):
  `00:00 +91 -1: rule 15: leaf geometry (ported R20-R27e) V15t a circle of radius linear/2 [E]`, `... -2: ... V15u an arc of radius linear/2 [E]`, `... -3: ... V15v a circle of radius exactly linear [E]`, `... -4: ... V15w an arc of radius exactly linear [E]`, `00:00 +94 -4: Some tests failed.`; V15t alone: `the library was accepted; expected rule 15 naming [1075, radius 5e-10]`.
- **M-V15u** `if (p.scalars[0] < Tolerance.standard.linear)`:
  `00:00 +93 -1: ... V15v a circle of radius exactly linear [E]` / `the library was accepted; expected rule 15 naming [1075, radius 1e-9]`; `00:00 +93 -2: ... V15w an arc of radius exactly linear [E]` / `... naming [1074, radius 1e-9]`; `00:00 +96 -2: Some tests failed.`
- **M-V15y** `if (p.pointAt(0) == p.pointAt(1))`:
  `00:00 +96 -1: ... V15y a line linear/2 long [E]` / `the library was accepted; expected rule 15 naming [1072, zero-length]`; `00:00 +97 -1: Some tests failed.`
- **M-V15aa (drop)** `if (false && _allWithinTolerance(p))` (committed 6dbf4c0f):
  `00:00 +101 -1: ... V15aa a polyline of three points within linear of each other [E]` / `the library was accepted; expected rule 15 naming [1073, zero-length polyline]`; `00:00 +101 -2: ... V15ab a closed polyline of one point [E]` / `... naming [1073, zero-length]`; `00:00 +104 -2: Some tests failed.`
- **M-V15aa (exact)** `if (p.pointAt(i) != p.pointAt(j)) return false;`:
  `00:00 +101 -1: ... V15aa ... [E]` / `the library was accepted; expected rule 15 naming [1073, zero-length polyline]`; `00:00 +105 -1: Some tests failed.`
- **M-V15ac** `for (var i = 0; i < 1; i++)` (each point against the first only):
  `00:00 +103 -1: ... V15ac points within linear of the first, not of each other, load [E]` / `SymbolLibraryError (rule 15): leaf 1073 of 1068 is a zero-length polyline: its points all lie within the tolerance of each other`; `00:00 +105 -1: Some tests failed.`
- **M-V15ad** `return isDegenerateSegment(p.pointAt(0), p.pointAt(1));` first in `_allWithinTolerance`:
  `00:00 +103 -1: ... V15ac ... [E]` and `00:00 +103 -2: ... V15ad a polyline whose first two points coincide loads [E]`, each `SymbolLibraryError (rule 15): leaf 1073 of 1068 is a zero-length polyline: ...`.
- **M-V11c** `if (false && area <= linear * linear)`:
  `00:00 +46 -1: rule 11: a unit outline V11c a closed outline on one diagonal, off the origin [E]` / `the library was accepted; expected rule 11 naming [sample.table.high-top@2, 10D6, encloses no area (0.0)]`; `00:00 +46 -2: ... V11d an outline of area linear² / 2 [E]`; `00:00 +104 -2: Some tests failed.`
- **M-V11d** `if (area == 0)`:
  `00:00 +47 -1: rule 11: a unit outline V11d an outline of area linear² / 2 [E]` / `the library was accepted; expected rule 11 naming [sample.table.high-top@2, 10D6, encloses no area]`; `00:00 +105 -1: Some tests failed.`
- **M-V11e** `if (area <= linear)`:
  `00:00 +48 -1: rule 11: a unit outline V11e an outline of area 2 * linear² loads [E]` / `SymbolLibraryError (rule 11): definition 10CC (sample.table.high-top@2) is a unit whose outline, 10D6, encloses no area (1.9999193273667616e-18)`; `00:00 +105 -1: Some tests failed.`
- **M-V11f** `return twice / 2;` (no `.abs()`):
  `00:00 +49 -1: rule 11: a unit outline V11f a clockwise outline loads [E]` / `... encloses no area (-360000.0)`; `00:00 +105 -1: Some tests failed.`
- **M-V2f** `const rule = 1;` in `_guarded`'s FormatException arm (committed 47af5452):
  `00:00 +18 -1: rule 2: the library component and the units V2f a library component with a mistyped field [E]` / `Expected: <2>` / `Actual: <1>` / `message: jetcad.library "sample": LibraryComponent: "format" is not a int: 1`; `00:00 +107 -1: Some tests failed.`
- **M-V12b** `if (!base.x.isFinite)`:
  `00:00 +52 -1: rule 12: the base point V12b a base point whose y is non-finite [E]` / `the library was accepted; expected rule 12 naming [sample.table.high-top@2, non-finite base point]`; `00:00 +107 -1: Some tests failed.`
- **M-K4c** `foreign = kitOfKey(rest) != id;` (plan_kit.dart):
  `00:00 +3 -1: K4 a word id under another kit's id, in every namespace [E]` / `Expected: [KitProblemCode:KitProblemCode.foreignWordId]` / `Actual: []` / `tool:sample`; `00:00 +5 -1: Some tests failed.`
- **M-D13** `const ['lib', 'test', 'tool'].contains(path.split('/').first)` in `isPackageDartFile` (committed 096d1468):
  `00:00 +7 -1: the rule D13 every Dart file of a package but generated output [E]`; `00:02 +11 -2: the script D15 a kit's example/ and root files are read; .dart_tool is not [E]`; `00:04 +14 -2: Some tests failed.`
- **M-D15** added `if (!const ['lib', 'test', 'tool'].contains(top)) continue;` in the script's entry loop (a first attempt that rewrote the skip line did not compile: `check_kit_deps.dart:46:23: Error: The type 'Object' used in the 'for' loop must implement 'Iterable<dynamic>'.`; reverted, `revert diff exit 0`, then this form):
  `00:02 +12 -1: the script D15 a kit's example/ and root files are read; .dart_tool is not [E]` / `Expected: <1>` / `Actual: <0>`; `00:04 +15 -1: Some tests failed.`
- **M-D16** `final name = d.uri.pathSegments.lastWhere((s) => s.isNotEmpty);`:
  `00:02 +13 -1: the script D16 a package is picked by its pubspec name, not its directory [E]` / `Expected: <1>` / `Actual: <0>`; `00:04 +15 -1: Some tests failed.`
- **M-D10** `generatedDirectories = {'.dart_tool'}` (build not excluded):
  `00:00 +7 -1: the rule D13 ... [E]` / `Expected: false` / `Actual: <true>`; `00:01 +10 -2: the script D10 a kit naming the plan and another kit: exit 1, both named [E]` / `Expected: not contains 'build/'`; `00:04 +14 -2: Some tests failed.`
  (Two earlier attempts chained `git diff | grep '^[-+] ' && dart test ...`; the filter misses top-level lines, so grep failed and the test never ran; each was reverted, `revert diff exit 0`. The third attempt, output above, ran the test.)
- **M-DOC1** docs/kits.md `capacity: 2` → `capacity: 3` in the §7 block (committed d0a4349a; the docs file was committed earlier):
  `00:00 +0 -1: DOC1 every ```dart block of ../../docs/kits.md is verbatim in example/ [E]` / `Expected: true` / `Actual: <false>` / `not in any of (example/cafe_kit.dart, example/generate_cafe.dart, example/example.dart, example/cafe_conformance_test.dart):`; `00:00 +2 -1: Some tests failed.`
- **M-DOC1** README.md `CatalogCircle((600, 600), 350)` → `360`:
  `00:00 +1 -1: DOC1 every ```dart block of README.md is verbatim in example/ [E]` / `Expected: true` / `Actual: <false>`; `00:00 +2 -1: Some tests failed.`
- **M-DOC1e** example/example.dart `350` → `355` in the catalog:
  `00:00 +0 -1: DOC1 ... ../../docs/kits.md ... [E]`; `00:00 +0 -2: DOC1 ... README.md ... [E]`; `00:00 +1 -2: Some tests failed.`
- Not a mutation, for the record: I first named "M-DOC1b: match the block's first line only" in the test's comment. Applying that weakening of the test with a doc change gave `00:00 +3: All tests passed!`, i.e. it is a weakening of the test, not a mutation the test catches; I removed it from the comment (amended the unpushed FR7 commit, now d0a4349a) and replaced it with M-DOC1e. Reverted, `revert diff exit 0`.

## Gates (final lines, after all commits)

```
packages/jet_cad_2d_kit$ flutter test
00:01 +246: All tests passed!
packages/jet_cad_2d_kit$ flutter analyze
Analyzing jet_cad_2d_kit...
No issues found! (ran in 2.3s)
packages/jet_cad_2d_kit$ dart format --output=none --set-exit-if-changed .
Formatted 48 files (0 changed) in 0.07 seconds.
format exit 0
tool/ci$ dart test
00:06 +110: All tests passed!
$ dart run tool/ci/check_kit_deps.dart
kit dependencies: 1 package(s) checked, none names the plan library or another kit
exit 0
packages/jet_cad_2d_kit$ dart pub publish --dry-run
Total compressed archive size: 56 KB.
Validating package...
The server may enforce additional checks.

Package has 0 warnings.
exit 0
packages/jet_cad_2d_kit$ dart run test/fixtures/sample_kit/generate.dart
sample kit: 4 symbols written
sample diff exit 0      (git diff --quiet over sample.jetlib and sample_snapshot.json)
```

`tool/ci$ dart format --output=none --set-exit-if-changed lib test check_kit_deps.dart`: `Formatted 15 files (0 changed) in 0.03 seconds.`

The three CLAUDE.md gates (no file of those packages touched):

- `packages/jet_cad_2d`: `00:06 +1289 -2: Some tests failed.`, failing exactly `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing` and `... the default document is the one Plan 2 measured, byte for byte` (pre-existing, known); `dart analyze`: `No issues found!`; format: `Formatted 177 files (0 changed) in 0.41 seconds.`
- `packages/jet_cad_2d_flutter`: `00:23 +1450 ~1 -5: Some tests failed.`, failing exactly `test/golden/text_ladder_golden_test.dart: text ladder rung 1..5 (RenderBackend.canvas)` (pre-existing, known); `flutter analyze`: `No issues found! (ran in 3.6s)`; format: `Formatted 234 files (0 changed) in 0.48 seconds.`
- `packages/jet_cad_2d_gpu`: `00:00 +20: All tests passed!`, `No issues found! (ran in 2.7s)`, `Formatted 10 files (0 changed) in 0.02 seconds.`

`git status --short` after all gates: empty.

## Concerns / notes for the controller

- `dart analyze` in `tool/ci` reports 3 errors in `tool/ci/host_probe/lib/main.dart` (a tracked template whose pubspec is `pubspec.yaml.in`); pre-existing, not in my diff, and not part of the tools gate (`dart test`).
- FR9's leak fix cannot be proven by a red test (see item 3); B8 is a premise check.
- FR8's rule-11 threshold (linear² = 1e-18) is below double resolution for off-origin coordinates; it refuses exact degeneracy there. V11d/V11e pin the threshold near the origin.
- I amended K9's spec text and listed it under the new amendments (not explicitly asked by item 8, but K9 otherwise contradicts FR6's code).
- FR1 (push for CI) is untouched: the human's call.
