# Task 22 report: the dimension tool and its notice (3a C3.6, C1.2, C1.5, C7)

Status: DONE_WITH_CONCERNS (one cost concern, below)
Commit: `2dbf27c1 feat(kit-architecture): the dimension tool and its notice (3a C3.6, C1.2)`

## Implementation summary

- `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_tool.dart` (new). It was generated from
  `jet_cad_floor_plan/lib/src/parametric/dimension_tool.dart` with the brief's line edits applied by script, so every other line is byte for byte the same. The edits:
  - the header, imports, `_kValueText` and the notice paragraph;
  - `class DimensionTool extends PlacementTool implements ToolNotice` with `DimensionTool({required this.live})` and `final LiveTypeOf live`;
  - the notice is a `ValueNotifier<KitText?>` holding `KitText('text:architecture.dimension-value', {'value': l.text})`;
  - `@visibleForTesting String? get debugValue`;
  - `live:` is passed to every `attachCandidates`, `thickestWall` and `wallsInDocument` call.
- **FREEZE RULE, an addition beyond the brief's line list (the dispatch asked for it).**
  - `_syncMemo` records the live walls (`_memoWalls`) and live openings (`_memoOpenings`) the hover memo was gathered among.
  - `_memoStillLive()` re-checks both lists through `live` in indexed loops, so it allocates nothing.
  - `_refresh`, the only reader of `_memo`, `_wallPoints` and the cached preview, now starts with `if (_memoGeneration == _generation && !_memoStillLive()) _generation++;`. A freeze emits no document change, so without this check the stream never hears it.
  - Openings are covered because `attachCandidates`' second query reaches a host through a live opening. The thickest-wall memo `_thickest` is rebuilt in the same `_syncMemo`.
  - Clicks and the commit already gather afresh (`_candidatesAt`).
- `dimension_plan.dart` gains `dimensionPlanTool`, as the brief specifies: id `architecture.dimension`, `Icons.straighten`, letter `I`, needs `{structure, components, geometry}`, no settings, `create: (s) => DimensionTool(live: liveTypesOf(s))`.
- `kit.dart` appends `dimensionPlanTool` last in `tools`.
- **The notice's separator.** Spec C3.6 and C1.6 (`KitWords.decimalSeparator`) say that "the area, the value and the dimension notice follow the page's (Q0)". So `value` is exactly the TEXT's string in the page's separator, never the UI's. This is pinned with a comma page under a point UI, and a point page under a comma (German) UI, in both the kit and the integration package.

## TDD evidence

- **Precondition** (Task 21 at HEAD 17294c58):
  - kit `flutter test`: `00:19 +393: All tests passed!`; `flutter analyze`: `No issues found!`
  - integration `flutter test --enable-vmservice`: `00:15 +90: All tests passed!`; `flutter analyze`: `No issues found!`
- **RED.** Both test files were written before the lib.
  - `flutter test test/dimension/dimension_notice_test.dart`:
    - `test/dimension/dimension_notice_test.dart:19:8: Error: Error when reading 'lib/src/dimension/dimension_tool.dart': No such file or directory`
    - `...:160:20: Error: Undefined name 'dimensionPlanTool'.`
  - `flutter test test/dimension/dimension_tool_test.dart`:
    - `test/dimension/dimension_tool_test.dart:33:8: Error: Error when reading 'lib/src/dimension/dimension_tool.dart': No such file or directory`
    - `...:56:16: Error: Method not found: 'DimensionTool'.`
- **GREEN** (both kit files): `00:01 +20: All tests passed!`. TL8 printed `612 walls, 0.3 px/mm: median per move over the band path 104.0 us idle ...`.

## Gates (final, after `dart format .`)

- **Kit:**
  - `flutter test`: `00:19 +413: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 3.3s)`
  - format gate exit 0 (`Formatted 109 files (0 changed)`)
  - `dart pub publish --dry-run` after the commit: `Package has 0 warnings.`
- **Integration:**
  - `flutter test --enable-vmservice`: `00:14 +94: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 2.8s)`
  - format gate exit 0
- **Root:** `dart run tool/ci/check_kit_deps.dart` printed `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
- `git status --short` was clean after the commit and after every mutation.
- **Non-ASCII check.**
  - All 60 non-ASCII lines of the source test outside the deleted spans appear unchanged in the kit file (a script compared them line for line), the header's `÷` among them.
  - Of the tool's non-ASCII lines, only `:75` is not present, and it sits inside the paragraph the brief replaces (`:73-76`). Its replacement carries `Dimension — 4.69` with U+2014.
  - The integration file holds `µ` (2), `—` U+2014 (6, including `'Dimension — 4.69'`), `×` (1) and `−` U+2212 (1).

## Mutations

Each mutation was applied to the committed files, the named tests were run, and the file was reverted with `git checkout --`. Every revert was followed by `git diff --quiet -- <file>`, which exited 0 each time.

| Mutation | Change | Red (quoted) |
|---|---|---|
| M-DT1 | `_notice.value = KitText(...)` → `= null` | DT-notice `Expected: KitText:<KitText(text:architecture.dimension-value, {value: 4.69})> Actual: <null>`; kit TL5 ×2 `Expected: '6.63' Actual: <null>`; kit TL5 ft-in `Expected: '21\'-9 1/4"'`; integration TL5 `Expected: '4.69' Actual: <null>` |
| M-DT2 | `_kValueText` → `'text:architecture.dimension'` | DT-notice `Actual: KitText:<KitText(text:architecture.dimension, {value: 4.69})>`; integration TL5 `Expected: '4.69' Actual: 'text:architecture.dimension'` |
| M-DT3 | `create:` with a wall-only `live` (+ `WallParams` import) | DT-plan-tool `Expected: <Instance of 'FixedEnd'> Actual: AttachedEnd:<12/0/left>` |
| M-DT4 | `letter: 'I'` → `'D'` | DT-plan-tool `Expected: 'I' Actual: 'D'`; integration TL7 `Expected: 'Dimension' Actual: 'Select'` |
| M-DT5 | `orthoBase` override deleted | TL2 ×2 `Expected: [1500.0, 2000.0] Actual: [1500.0, 1200.0]` |
| M-DT6 | `if (!shift) return DimKind.aligned;` deleted | TL1 ×2 `Expected: DimKind:<DimKind.aligned> Actual: DimKind:<DimKind.horizontal>` |
| M-DT7 (new) | `{'value': l.text}` → `{'value': l.text.replaceAll(',', '.')}` | DT-notice-separator `Expected: {'value': '4,69'} Actual: {'value': '4.69'}`; integration DT-notice-locale `Expected: 'Bemaßung — 4,69' Actual: 'Bemaßung — 4.69'` |
| M-DT8 (new) | the `_memoStillLive()` check in `_refresh` deleted | DT-freeze `Expected: <0> Actual: <1>`. A scratch copy split into one test per step (deleted afterwards, never committed) showed all four steps red **independently**: the wall itself, the neighbour (`_wallPoints`), the click as first reader, and the opening. |
| M-DT8b (new) | the openings loop's check in `_memoStillLive` deleted | DT-freeze `Expected: <0> Actual: <1>`. In the scratch split, only step 4 (the opening) went red. |

## Ported-test accounting

**Kit:** `packages/jet_cad_2d_kit_architecture/test/dimension/dimension_tool_test.dart` (16 tests).
- **Cases ported:** TL1 ×2, TL2 ×2, TL3 ×2, TL6 ×2, TL5 `:882` ×2, TL5 `:1147` ×2, TL8, M-DT-8.
- **Assertions:** unchanged, except DT-R4. Its 9 sites were `.notice.value` → `.debugValue`.
- **Change classes:**
  - imports and ids (C7 1);
  - `dims` reads the kit's test catalog;
  - `dimRig`'s `DimensionTool(live: liveOf(doc))`;
  - `live:` on the 6 `attachCandidates` calls, and `thickestWall(x, liveOf(x))` on its 6 calls (signature, Task 20).
- **Deleted, as the brief says:** the shell helpers (`:141-178`) and the shell cases TL4, TL7 and TL5's status-line case.
- **Twins added:** TL4k and TL5k (DT-R1), exactly as written in the brief. TL4k's first `hasLength(1)` held.

**Integration:** `packages/jet_cad_2d_integration/test/dimension/dimension_tool_test.dart`.
- **Cases ported:** TL4, TL5 (status line) and TL7, through `PlanEditor`.
- **Change classes:** DT-R2 (`c.activeTool.value`), DT-R3 (canvas width `greaterThan(4690 * 0.12)`), DT-R4 (`noticeText(c)`), and the brief's fixture change (`sampleIn` sets a page with `snapToGrid: false`).
- **No `ensureVisible`:** TL7's tap on `property-name` landed without it.

**New tests:**
- DT-notice, DT-plan-tool (brief);
- DT-notice-separator, DT-freeze (kit);
- DT-notice-locale (integration).

## Deviations

1. **Step 7 (R-P14).** The sample walls, openings, separator, column and seeds, and `addRoom`, already exist in `test/support/room_plans.dart`, byte-identical to the brief's copy source. The brief's `tapWorld` is the same behaviour as room_plans' `clickAt`.
   - So `dimension_plans.dart` re-exports these from room_plans rather than copying them a second time, and the integration test calls `clickAt` where the brief wrote `tapWorld`.
   - `dims`, `noticeText`, `centreOn` and `turnedBy` were added as the brief wrote them, along with the `jet_cad_2d_flutter` import showing `InteractionLayer, ViewportTransform` and `dart:math`.
   - The `groupFor` clash does not arise, because the test imports only `dimension_plans.dart`.
2. **The tool goes beyond the brief's line edits** with the FREEZE RULE re-check. It adds imports of `../ids.dart`, `OpeningParams` and `WallParams`, plus `_memoWalls`, `_memoOpenings`, `_memoStillLive` and the `_refresh` check. The class doc gains a **Freezes** paragraph.
3. **The notice test imports `package:flutter/painting.dart`** (`Canvas`, `Paint`, `Size`) for its ring counter, which is part of the added DT-freeze.
4. **DT-notice-locale sets the page after the editor is pumped.**
   - Reason: an untouched plan takes the UI's separator when the locale is first reported (`PlanController.reportLocale`, 2a P2), so a point page set inside the build becomes a comma page under German. This is correct plan behaviour.
   - What the test does: it sets the page by an edit, asserts it as a premise, and then asserts `Bemaßung — 4.69` and `Bemaßung — 4,69`.
   - The re-wording after the switch to English is asserted only after extra pumped frames, never in the same frame.

## Concerns

- **Cost of the FREEZE re-check.** It is O(live walls + live openings) per pointer event, the same order as Task 21's grip memo.
- **TL8, 612 walls** (all figures are medians printed by TL8, "printed, not asserted"):

  | Path | With the check | Without it (M-DT8 applied briefly, then reverted) | Old tool in jet_cad_floor_plan |
  |---|---|---|---|
  | Band path, idle | 104-116 µs | 44 µs | 38 µs |
  | Shift slide | 96 µs | 16 µs | 15 µs |

- All three fit inside D12's 1,000 µs budget. The test's `live` (`testCatalog().typeIdOf` per call) may cost more or less than the plan's `liveTypeIdOf`.
- **Cheaper alternatives:** re-check only the walls in `_wallPoints` and their reach neighbours, or have the plan expose a freeze generation. Either is a design decision for the controller.

## Files changed

- packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_tool.dart (new)
- packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_plan.dart
- packages/jet_cad_2d_kit_architecture/lib/src/kit.dart
- packages/jet_cad_2d_kit_architecture/test/dimension/dimension_tool_test.dart (new)
- packages/jet_cad_2d_kit_architecture/test/dimension/dimension_notice_test.dart (new)
- packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart
- packages/jet_cad_2d_integration/test/dimension/dimension_tool_test.dart (new)
