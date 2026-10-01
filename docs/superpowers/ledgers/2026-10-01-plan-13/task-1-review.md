# Task 1 review: the page camera and the export fixture (spec D2, T-1)

Reviewer: independent. Commit `c96bb9b` (parent `7fab442`), reviewed in the detached worktree
`.claude/worktrees/plan-13-review`. Scratch: `.../scratchpad/r1/p13t1/`. Nothing committed. The worktree
was clean at the end (`git status --short` printed nothing).

## 1. Render gate, re-run by me (`packages/jet_cad_2d_flutter`, `CI=true`)

```
01:02 +1023 ~1 -7: Some tests failed.
```
There were 7 failures. All are the standing Linux golden failures, and no others (`grep '\[E\]'`, deduplicated):
```
test/golden/text_ladder_golden_test.dart: text ladder rung 1..5 (RenderBackend.canvas) [E]      (5)
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1, 2 (RenderBackend.canvas) [E] (2)
```
`flutter analyze`: `No issues found! (ran in 4.0s)`, exit 0.
`dart format --output=none --set-exit-if-changed .`: `Formatted 186 files (0 changed) in 0.75 seconds.`, exit 0.
Result: 1,023 pass, 1 skip, 7 standing failures. This matches the expected counts and the implementer's report.

## 2. Diff scope against `7fab442`

`git diff --name-only 7fab442 c96bb9b` lists only these files:
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (one line: `export 'src/export/page_camera.dart';`)
- `packages/jet_cad_2d_flutter/lib/src/export/page_camera.dart`
- `packages/jet_cad_2d_flutter/test/export/page_camera_test.dart`
- `packages/jet_cad_2d_flutter/test/support/export_fixture.dart`
- `packages/jet_cad_2d_flutter/test/support/export_fixture_test.dart`

`git diff --stat 7fab442 c96bb9b -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants`
printed nothing. The engine, the app, the goldens and both allocation invariant tests are unchanged. No pubspec
or `analysis_options.yaml` was touched. The commit trailers are correct.

## 3. `page_camera.dart` against spec D2

- `Transform2(a,b,c,d,e,f)` maps a point to `(a·x + c·y + e, b·x + d·y + f)` (`transform2.dart:71-72`). The
  code passes `(k, 0, 0, -k, -S.minX·k, S.maxY·k)`. That is `x' = (x − S.minX)·k` and `y' = (S.maxY − y)·k`,
  which is D2 exactly.
- `S = sheetWorldRect(page)` and `k = u / page.scaleDenominator`. Correct.
- The size is `Size(effectiveWidthMm·u, effectiveHeightMm·u)`, unrounded, and `pixelsPerPaperMm = u`. Correct.
- The function reads only the page: it has no camera, viewport or extents parameter. It throws `ArgumentError`
  for a non-finite or non-positive `u`, as plan Task 1 requires.
- `minTextCapPixels: 0` is the painter's concern (D4/D5) and is not in scope here.

The T-1 test computes the expected corners from the page's raw fields, not through `sheetWorldRect`, so the
camera's own helper does not serve as the oracle. It covers every case plan Task 1 lists:
- A4 landscape 1:50 with the fixture origin, A4 portrait 1:100 at (−2500, 4200), A3 landscape 1:20 at
  (12000, 800);
- 1,000 mm segments along x and along y;
- an unrounded size at 150 dpi;
- a point above the sheet mapping to a negative y.

## 4. Mutants (fired by me: cp backup, mutate, run the one test file in the foreground, cp back, `diff` exit 0)

| id | file:line | mutation | result (real line) | red tests |
|---|---|---|---|---|
| M-13f | page_camera.dart:48 | `sheetWorldRect(page.copyWith(originX: 0, originY: 0))` | `00:00 +8 -7: Some tests failed.` | corners ×3, above-sheet ×3, fixture instance origin |
| M-13g | page_camera.dart:56,58 | `-k`→`k`, `sheet.maxY*k`→`-sheet.minY*k` (no flip) | `00:00 +5 -10: Some tests failed.` | corners ×3, 1,000 mm ×3, above-sheet ×3, instance origin |
| R-swap | page_camera.dart:62-63 | size from `widthMm`/`heightMm` (orientation ignored) | `00:00 +12 -3: Some tests failed.` | size A4 landscape, size A3 landscape, unrounded at 150 dpi |
| R-den | page_camera.dart:49 | `k = unitsPerPaperMm` (scale denominator ignored) | `00:00 +5 -10: Some tests failed.` | corners ×3, 1,000 mm ×3, above-sheet ×3, instance origin |
| R-round | page_camera.dart:63 | height `.roundToDouble()` | `00:00 +11 -4: Some tests failed.` | size ×3, unrounded at 150 dpi |
| R-guard | page_camera.dart:41 | `<= 0` → `< 0` | `00:00 +14 -1: Some tests failed.` | "a non-finite or non-positive unit throws ArgumentError" |
| FX-rot | export_fixture.dart:98 | rotation π/6 → π/4 | `00:00 +6 -1: Some tests failed.` | "the instance: rotated 30 degrees, scaled (1.5, -0.75), overrides" |
| FX-out | export_fixture.dart:196 | outside line `[20000,10000,…]` → `[17000,8000,…]` (now crosses into the sheet) | `00:00 +7: All tests passed!` | **survives**: see finding 1 |

Process note: my first attempt to fire M-13f and M-13g used a broken shell script. It exited after mutating
and did not restore the file. I restored `page_camera.dart` from a backup that I first checked was
byte-identical to `git show c96bb9b:…/page_camera.dart`. Then I re-fired both mutants with a corrected
script. That script restores the file in a trap and checks it with `diff` afterwards. All the results in the
table come from the corrected runs. The worktree is clean.

## 5. The fixture (`test/support/export_fixture.dart`) against spec Testing and plan P-3

Every element the spec lists is present:

| spec item | fixture |
|---|---|
| A4 landscape 1:50, origin (3000, −1500), background 0xFF303030 | yes, :116-122; pinned by the self-test |
| line | `line` (TrueColor 0x1565C0, lw 35) |
| closed polyline | `closedPolyline` (closing pair repeated) |
| dashed polyline | `dashed`, DASHED handle 6, `[200, −100]` / 300; values match the app's `kDashedLinetypeRecord` (`separator.dart:128-133`) |
| arc of sweep −110° | `arc`, scalars `[1200, 0.4, −110°]`; the order r/start/sweep matches `draft_painter.dart:851-853` |
| circle | `circle` r 800 |
| fill alpha 0x80 | `fill`, transparency 127; `style_resolver.dart:211` gives alpha 255−127 = 0x80 |
| "Yatak Odası" 250 mm, "WC" 25 mm | `labelBig`, `labelWc` |
| point inside the instance | `pointInInstance` (BYBLOCK) |
| outer group with its own line, its own instance, and a nested group with one line | `outerGroup`, `outerGroupLine`, `outerGroupInstance` (of `outerDefinition` with leaf `outerInstanceLeaf`), `nestedGroup`, `nestedLine`; every transform is off the identity |
| instance rotated 30°, scaled (1.5, −0.75), red / 0.70 mm overrides, `basePoint` off the origin | `instance` T(7000,5600)·R(30°)·S(1.5,−0.75), TrueColor 0xFF0000, lw 70; `basePoint` (120, 45); the self-test checks each matrix entry |
| ACI 7 line | `aci7Line` IndexedColor(7) |
| separator-like group | `separatorGroup`: childless, rotated and translated, one dashed polyline `separatorLine` |
| one line wholly outside the sheet | `outsideLine`: outside at 1:50 only (finding 1) |

- **Named handles.** Every handle plan Task 1 lists is present. The implementer added `separatorLine`,
  `definition`, `instanceLine`, `instancePolyline`, `outerDefinition`, `outerInstanceLeaf` and `fillBoundary`.
  Tasks 2–6 can name every leaf they need. Handles come from `handleSeed`, so draw order is creation order.
- **`scaleDenominator` and `measurer` parameters.** These are sensible for T-4 (1:100) and T-5/T-6
  (`FlutterTextMeasurer`).
- **Degeneracy.** The fixture is not degenerate where it matters:
  - nothing sits at the origin (the self-test checks `extents.minX > 0`);
  - every node transform is off the identity;
  - the instance is mirrored, so a lost sign shows;
  - the root leaves carry explicit non-default colour and lineweight;
  - the page sits on a dark background.

### The implementer's remarks

1. **The renderer does not read `basePoint`.** Confirmed. `basePoint` appears in the render lib nowhere. In
   the engine it appears only in `node.dart`, whose doc comment (`node.dart:317-318`) says "insertion
   alignment is wrong without it", and in `testing/generate_document.dart`. The fixture's (120, 45) is
   therefore a stored value that no export test can observe. This is not a Task 1 defect. The spec's Testing
   paragraph should be amended at execution to say so, and the gap between that doc comment and the renderer
   is an engine question for the human. It is outside plan 13.
2. **`pdf_content.dart` location.** The spec's Architecture table names `test/support/pdf_content.dart`, while
   plan P-2 puts it in `lib/src/export/testing/`. The plan wins. This should be recorded in the spec's
   "Amended at execution" in Task 11.
3. **The separator keeps the real separator's default-looking style** (ByLayer, DASHED, lw 35). Accepted.
   Fidelity to F-8 matters more here than P-3's "no default style", and it is the one documented exception.

## Findings

1. **Minor. The outside line is outside the sheet only at 1:50.**
   - Where: `test/support/export_fixture.dart:192-199`, and the self-test at
     `test/support/export_fixture_test.dart:131-144`.
   - Problem at 1:100: `exportFixture(scaleDenominator: 100)`, the variant the fixture offers for T-4, puts
     the sheet at x 3000..32700 and y −1500..19500. The outside line (20000..22500, 10000..11200) then lies
     **wholly inside** it. The doc comment on `outsideLine` and the fixture's description both claim "wholly
     outside the sheet".
   - Problem in the self-test: it asserts only `doc.extents.maxX > sheet.maxX`, so it does not pin "wholly".
     Mutant FX-out moves the line to cross the sheet edge, and the self-test still passes
     (`00:00 +7: All tests passed!`).
   - Risk: a later test at 1:100 that leans on "nothing from the outside line" passes or fails for the wrong
     reason.
   - Fix: place the line left of or below the origin, which is outside at every scale because
     `sheet.minX = 3000` and `sheet.minY = −1500` do not depend on the scale. For example, use
     `[-6000, 2500, -3500, 3700]`; that keeps it away from the world origin. Then add a self-test that the
     line's bounding box is disjoint from `sheetWorldRect` for both `exportFixture()` and
     `exportFixture(scaleDenominator: 100)`. FX-out (and the 1:100 case) must then go red. This can land as a
     fixup before Task 2, or in Task 2's commit.

2. **Note. Some styles stay at their defaults.**
   - Where: `test/support/export_fixture.dart:303-336` and `:338-369`.
   - What: every leaf has `linetypeScale: 1.0`, layer 0 and transparency 0 (except the fill), and both texts
     have rotation 0 with default attrs. The spec's fixture list does not require otherwise, and T-5's
     text-direction check still sees the page flip.
   - Effect: a sink or export that ignores `linetypeScale`, or a text rotation, is not exercised by
     fixture-based tests. No change is required for Task 1. If Task 4 or 5 wants a rotated-text check, it can
     add a rotated label to the fixture then (new handle, appended last so the existing draw order is kept).

3. **Note. The spec's Testing paragraph overstates `basePoint`** (remark 1 above). Record it in the spec's
   "Amended at execution" (Task 11). No code change.

## Verdict

**Approved with notes.** The page camera is D2 exactly, T-1 is a real oracle, and M-13f and M-13g go red, as
do all four of my own camera mutants. The gate counts are exact, and the diff is confined to the render
package's camera, the library export and the test files. Finding 1 is a cheap fix to the fixture that later
tasks build on: apply it before or with Task 2.
