# Task 1 report — The branch point, and `PageComponent`

## Branch point

`git log --oneline -1` at start: `1e5001d docs(plan): 04 page, grid and rulers — twelve tasks` (≥ `52dd8ae`, satisfied). `flutter pub get` had already been run in the worktree per the task context.

Four gate lines, run once, before any implementation:

- **Engine** (`packages/jet_cad_2d`, `CI=true dart test`): `00:03 +830: All tests passed!` — exit 0.
- **Render layer** (`packages/jet_cad_2d_flutter`, `CI=true flutter test`): `00:14 +771: Some tests failed.` with `~1` skip and `-5` failures — exit 1. The five failures are exactly:
  - `test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)`
  - `test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)`
  - `test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)`
  - `test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)`
  - `test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)`
  Nothing else failed — matches expected.
- **Harness** (`apps/dev_harness_2d`, `CI=true flutter test --concurrency=1`): `00:20 +82: All tests passed!` — exit 0.
- **App** (`apps/floor_planner`): `CI=true flutter test` → `00:00 +13: All tests passed!` — exit 0. `flutter build macos --debug` → `✓ Built build/macos/Build/Products/Debug/floor_planner.app` — exit 0. `flutter build web` → `✓ Built build/web` — exit 0.

All four lines matched the expected summary exactly: engine 830, render layer 771 + 1 skip + the five text-ladder goldens, harness 82, app 13 + both builds.

After the runs, `git status --short` showed only `packages/jet_cad/analysis_options.yaml` modified (the other two `analysis_options.yaml` files were not rewritten this time). Restored with `git checkout -- packages/jet_cad/analysis_options.yaml` before touching anything else.

## What was implemented

- `packages/jet_cad_2d/lib/src/document/page_component.dart` (new): `PageOrientation`, `DisplayUnit` (+ `DisplayUnitConversion` extension: `mmPerUnit`, `symbol`, `isImperial`), `SheetSize` (+ `presets`, `name`), `PageComponent` (fields, constructor validation, `effectiveWidthMm`/`effectiveHeightMm`, `preset`, `copyWith`, `toJson`/`fromJson`, `==`/`hashCode`/`toString`, `register`, `componentTypeId`) — copied verbatim from the brief's Step 4, with one deliberate deviation:
  - **Ruling 04-8 applied**: `SheetSize.name` is written as an if-chain over `SheetSize.presets`-adjacent constants (`a4`, `a3`, `letter`, `tabloid`) rather than the brief's `switch (this) { a4 => ... }` constant-pattern form, since `SheetSize` overrides `==`. This was applied proactively (the brief's own Step 4 code block still shows the switch form, but the task instructions call out Ruling 04-8 as binding). Behaviour is identical.
  - One additional fix beyond the brief's literal text: after `dart format` ran, `_requireFinite`'s single-statement `if` was split across two lines by the formatter, which then triggered `curly_braces_in_flow_control_structures` from `dart analyze`. Wrapped the throw in braces to keep analyze clean — this is a formatting/lint consequence, not a behavioral change.
- `packages/jet_cad_2d/lib/jet_cad_2d.dart`: added `export 'src/document/page_component.dart';` in alphabetical position, directly after `origin_component.dart`.
- `packages/jet_cad_2d/test/document/page_component_test.dart` (new): the eight tests from the brief's Step 2, verbatim (reformatted by `dart format`, no logic changes).

## TDD evidence

**RED** — `CI=true dart test test/document/page_component_test.dart` (run from `packages/jet_cad_2d`, before `page_component.dart` existed):

```
EXIT: 1
00:00 +0: loading test/document/page_component_test.dart
00:00 +0 -1: loading test/document/page_component_test.dart [E]
  Failed to load "test/document/page_component_test.dart":
  test/document/page_component_test.dart:8:53: Error: Undefined name 'PageOrientation'.
  ...
  test/document/page_component_test.dart:7:26: Error: Method not found: 'PageComponent'.
  ...
00:00 +0 -1: Some tests failed.

Failing tests:
  test/document/page_component_test.dart: loading test/document/page_component_test.dart
```//(full transcript captured in the session; abbreviated here — every undefined name is `PageComponent`, `PageOrientation`, `DisplayUnit`, or `SheetSize`, i.e. exactly the symbols not yet implemented)

**GREEN** — same command after implementing `page_component.dart` and the export:

```
EXIT: 0
00:00 +0: loading test/document/page_component_test.dart
00:00 +0: effective size follows orientation on a non-square sheet
00:00 +1: presets are recognised by exact dimensions, anything else is custom
00:00 +2: toJson keys are alphabetical and fromJson round-trips by value
00:00 +3: optional keys take their defaults, required keys throw
00:00 +4: copyWith can clear gridStepMm and leaves the rest alone
00:00 +5: validation refuses non-finite and non-positive values
00:00 +6: register makes the type known to a registry, once
00:00 +7: DisplayUnit conversions are exact
00:00 +8: All tests passed!
```

## Gate line (final, pristine)

Run from `packages/jet_cad_2d`:

```
$ CI=true dart test
...
00:03 +837: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +838: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +838: All tests passed!
EXIT: 0
```

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
EXIT: 0
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 119 files (0 changed) in 0.23 seconds.
EXIT: 0
```

830 → 838 is exactly +8, the new test file's count. No pre-existing test regressed.

(Note: an intermediate run of `dart format` — without `--output=none --set-exit-if-changed`, i.e. actually applying formatting — reformatted `page_component.dart` and `page_component_test.dart` for line-wrapping; that pass also surfaced the `curly_braces_in_flow_control_structures` lint fixed above. The final gate run shown here is after both fixes, with zero files needing reformatting and zero analyzer issues.)

## Files changed

- `packages/jet_cad_2d/lib/src/document/page_component.dart` (new, 235 lines)
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (+1 export line)
- `packages/jet_cad_2d/test/document/page_component_test.dart` (new)

Commit: `39ff5f2 feat(engine): PageComponent`. Trailer verified: `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

## Self-review

- **Completeness**: all 8 tests from the brief present and passing; `PageComponent`, `PageOrientation`, `DisplayUnit` (+ `mmPerUnit`/`symbol`/`isImperial`), `SheetSize` (+ `presets`), `PageComponent.register`, `effectiveWidthMm`/`effectiveHeightMm`, `preset`, `copyWith`, `fromJson`, `componentTypeId` all present per the brief's Interfaces list. Export added in alphabetical position.
- **Quality**: names match the brief exactly (no renames, no extra public API).
- **Discipline**: nothing implemented beyond the brief — no grid/ruler code, no Flutter-side changes, no touching `apps/dev_harness_2d` or the untouched-widget list. `PageComponent` is registered as non-internal (test asserts `isInternal` is `false`), matching the brief's implication that the application (not the engine) attaches it.
- **Testing**: final gate line output is pristine — 838 passed, `No issues found!`, `0 changed` on format. No warnings suppressed or ignored.

## Concerns

- The brief's own Step 4 code block writes `SheetSize.name` with the constant-pattern `switch` form, while the task instructions (and ledger's Ruling 04-8) direct the if-chain instead. Applied the if-chain proactively rather than trying the switch first and waiting for a failure, since Ruling 04-8 was given as a resolved ruling, not an open question — flagging this in case the reviewer expects to see the switch attempted first.
- `dart format` (applied, not just checked) reformatted the two new files for line width and one lint appeared as a result (`curly_braces_in_flow_control_structures`) which was fixed by braces around `_requireFinite`'s throw. This is a mechanical consequence of formatting, not a design choice, but it does mean the final `page_component.dart` differs slightly in whitespace/brace style from the brief's Step 4 snippet.
- No other concerns; all four branch-point gate lines matched the expected counts exactly, and the package's own gate line is green with zero deltas beyond the new test file's count.
