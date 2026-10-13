# Final fix wave: scoped re-review

Fix base `fea46c30`, head `6464ad7f`, diff `review-fea46c30..6464ad7f.diff` (9 commits, 13 files).
Read in two passes (docs, then code and tests). No test re-run: no claim raised a doubt that the
report's quoted output and the diff do not answer. FR1 (CI never ran) is the human's call, out of scope.

### Finding Verdicts

- **FR2 Rule 15's tolerance decisions unpinned** — ADDRESSED. `symbol_library_test.dart` (diff
  1095-1131, 1177-1190): V15t/V15u radius `linear/2` refused, V15v/V15w exactly `linear` refused,
  V15x `2*linear` loads (circle and arc), V15y a line `linear/2` long off the origin (120, 340)
  refused, V15z `2*linear` loads. M-V15t (`<= 0`), M-V15u (`<`), M-V15y (exact `==`) each quoted red
  in the report. The code decision is unchanged (`symbol_library.dart` radius `<=
  Tolerance.standard.linear`, line `isDegenerateSegment`).
- **FR3 Results note over-states its record** — ADDRESSED. Notes diff 183-189, 212-219, 241-244,
  272-273: "(macOS)" gone; hash tests "fail identically on the clean main checkout" (matches
  progress.md:24); goldens "reported pre-existing"; Task 1's flaky `query_allocation_test` run added
  (matches task-1-report.md:11); Task 9's left mutation reverted by the controller named (matches
  progress.md:69); `[E]` markers Task 3 only; "As the task reports record". The new fix-wave
  section's mutation table and gate lines match `final-fix-report.md`.
- **FR4 Retired symbol has no mechanism** — ADDRESSED. `docs/kits.md` §8 (diff 132-139) now says the
  contract has no retired mark and that the gallery side is sub-project 2's; spec "Inputs for
  sub-project 2" R2 (diff 484-488) records the optional `retired` field, absent read as `false`.
- **FR5 Conformance claim and §9 checklist** — ADDRESSED. `docs/kits.md` §2 (diff 69-75): keys only
  today, types/tools when the code side arrives, `PlanKit.validate` already reports foreign
  `tool:`/`type:` words; §9 item 6 (diff 161-165) asks for a `kit.validate()`-is-empty test.
- **FR6 check_kit_deps reads lib/test/tool only, picks by directory** — ADDRESSED.
  `tool/ci/lib/kit_deps.dart` `isPackageDartFile`, `packageName`, `generatedDirectories`;
  `check_kit_deps.dart` walks every top-level entry except `build/`/`.dart_tool/` and picks by
  pubspec name. D13-D16 with M-D13/M-D15/M-D16/M-D10 quoted red. Spec K9 and docs §1 amended to match.
- **FR7 Nothing keeps doc blocks verbatim in example/** — ADDRESSED.
  `test/invariants/doc_snippets_test.dart`: rule stated exactly in the header (contiguous run of
  whole lines, nothing normalised; leading example comments simply fall outside the run); block
  counts pinned (4 and 1) against a vacuous parser; M-DOC1 (doc side) and M-DOC1e (example side)
  quoted red; the report's self-correction (dropping the bogus "M-DOC1b") is honest.
- **FR8 Zero-length polyline and zero-area outline pass** — ADDRESSED as ruled.
  `symbol_library.dart` `_allWithinTolerance` (pairwise `isDegenerateSegment`, early exit, so O(n)
  for any real polyline) under rule 15; `_enclosedArea` (fan shoelace relative to vertex 0, `.abs()`)
  `<= linear*linear` under rule 11, polylines only (circles covered by rule 15). One-fault fixtures
  off the origin where the double allows (V15aa, V15ab, V11c), positive controls V15ac/V15ad/V11e/V11f,
  each with a quoted red mutation. A closed outline of two distinct points (A, B, A) now gives area 0
  and is refused, which was the review's case.
- **FR9 buildLibraryDocument leaks its document on a throw** — ADDRESSED (code path).
  `builder.dart` diff 594-640: everything after `DraftDocument.empty()` in `try`, `catch (_) {
  unawaited(doc.dispose()); rethrow; }`; `dart:async` imported. B8 pins that the empty closed
  polyline throws after the document exists and the `StateError` reaches both callers unchanged.
- **Cheap minors (brief item 4)** — ADDRESSED. V2f (`format: '1'` -> `FormatException` -> rule 2,
  M-V2f red); V12b (non-finite y, M-V12b red); K4 `tool:sample` (M-K4c red); `parseSnapshot` doc
  says white space only, number spelling kept, fails closed (`snapshot.dart` diff 671-675).

### The two implementer concerns

- **FR8 rule-11 threshold (linear², below double resolution off the origin)** — the concern is
  valid and goes further than the report says: the threshold is not scale-aware at all. A sliver
  600 mm long and 1e-9 mm wide (narrower than the tolerance) has area 6e-7 mm², far above 1e-18, so
  it loads anywhere, origin included. In practice rule 11 refuses exact degeneracy (collinear or
  back-and-forth outlines with exactly representable coordinates) and microscopic outlines only;
  a nearly-collinear outline whose points went through trig and 1e-6 cleaning passes. It is what the
  ruling asked for and the code implements it faithfully, so it does not block. Recommend (Minor):
  either record in the spec amendment that linear² catches exact degeneracy only, or, in
  sub-project 2 when outlines are filled, switch to a width criterion (e.g. `2 * area / perimeter
  <= linear`), which is the Tolerance-consistent form of "fills nothing".
- **FR9 untestable from outside** — agree. `DraftDocument.dispose()` is `commands.dispose()`
  (`packages/jet_cad_2d/lib/src/document/draft_document.dart:213`); the document never reaches the
  caller on a throw and the engine keeps no registry of live documents, so deleting the dispose line
  survives every test. Observing it would need a seam (an injected document factory) in the public
  API for no user benefit. B8 as a labelled premise check plus the read code path is the right call;
  the brief allowed exactly this ("else document why").

### New Breakage in the Fix Diff

None Critical or Important. Minor:

- `symbol_library.dart` `_enclosedArea`: net signed area, so a self-intersecting outline whose
  lobes cancel (a symmetric bow-tie) is refused as "encloses no area (0.0)". Defensible (service
  mode's fill of such an outline is ill-defined), but the spec's wording ("enclosing an area")
  does not say so.
- `check_kit_deps.dart`: `build/` and `.dart_tool/` are excluded at the package's top level only;
  a nested Flutter `example/` app's own `example/.dart_tool/` (e.g. `dart_plugin_registrant.dart`)
  would be read. It can only report a dependency the example app really has, so it fails closed.
- `check_kit_deps.dart`: every package directory's pubspec is now parsed; a malformed YAML pubspec
  in any package (not only a kit) now makes `kitDepsProblems`' `loadYaml` throw. Fails closed; all
  current pubspecs parse.

### Out-of-Scope Observations

None.

### Verdict

**Fix round:** All findings addressed (FR2-FR9 and the cheap minors), no new Critical/Important
breakage. FR1 (push for CI) remains open as the human's call.
