# Q4 report: the wall thickness bound, the triangulator's far-away area, the panel's number text

Implementer, branch `fix/post-11`, worktree `.claude/worktrees/fix-post-11`, branch point `363efd0`. Three commits, not pushed. The working tree is clean at the end, and no `analysis_options.yaml` was committed or left modified.

| Part | Commit | Subject |
|---|---|---|
| 1 (c) | `0f8b073` | fix(app): a wall thickness above 1e7 mm is refused by the panel and the Wall tool (post-11 (c)) |
| 2 (B) | `9352103` | fix(engine): the triangulator's winding decision sums the shoelace relative to the first vertex (post-11 (B)) |
| 3 | `1ba7b94` | fix(app): the Selection panel shows a number as text that parses back to it exactly (post-11 _number) |

## 1. (c) The bound: `0f8b073`

**The change.** In `apps/floor_planner/lib/parametric/wall.dart`:
- New `const double kWallMaxThickness = 1e7;` with a doc comment giving the reason: the probe's smallest collapsing thickness was 1.33e10 mm (t/L 1.15e16) and none collapsed at or below 1e10, so the margin is about 1,300; the value is also below 2^53.
- `isWallThickness(t)` is now `t.isFinite && t > wallJoin.linear && t <= kWallMaxThickness`. Its doc now names the known limit for loaded files.

**Callers.** Every caller goes through the same predicate:
- the panel's `_valid` (a wall's thickness);
- `_validSetting` (tool-mode keystroke writes);
- the tool's own `_addWall` guard.

So a value above the bound is refused exactly like one at or below `wallJoin.linear` (WS3's behaviour): the field reverts to the model's or setting's value, no step is written, and no message is shown. The Wall tool commits nothing with such a setting and ends the chain (WT18's behaviour; the settings are a public notifier).

**Tests:**
- **WS10**, in `selection_panel_test.dart`, runs twice: with `1e100` (the probe's value) and with `1e25`. Each run pumps the `panelDoc` shell, presses W, types the value into Thickness without Enter, then clicks `plan(400, 900)` and then `plan(1900, 800)`. That wall is diagonal (the plan is turned 23°) and sits at the far origin. The test expects:
  - `takeException()` null;
  - exactly one new wall, at thickness **200**;
  - `undoDepth` 1;
  - the handles the seed advanced over equal exactly the new group plus its generated children;
  - the settings still 200;
  - the field reverted to "200" by the focus loss;
  - no drift.

  **Why 200:** `enterText` delivers the whole text in one `onChanged`. The bound refuses it, so the settings keep the default 200. If the value were typed key by key, the prefixes "1" and "1e1" (= 10) are valid and would be written, and "1e10" onwards would be refused. The settings would then keep **10**. This is the "last valid prefix" behaviour 07 D11 already records. It is not tested key by key.
- **WS11**: `nextUp(kWallMaxThickness)` (text "10000000.000000002") on wall A, which is turned and in its own rotated group. Enter, then a focus loss by tap. Each is refused, the field shows "200", `undoDepth` is 0, and `enc(doc)` is byte-identical.
- **WP5**, in `wall_params_test.dart`:
  - `isWallThickness(kWallMaxThickness)` is true and `isWallThickness(nextUp(kWallMaxThickness))` is false;
  - at the floor, `nextUp(wallJoin.linear)` is true and `wallJoin.linear` is false;
  - 1e10, 1e100, maxFinite and infinity are all false;
  - it also pins `kWallMaxThickness == 1e7`.

**Red before the fix.** The tests ran with the constant defined but the clause absent, which is exactly `M-q4-noUpperBound`:
- WP5: Expected false, Actual true.
- WS10 (1e100) and WS10 (1e25): `Expected: null, Actual: ArgumentError:<Invalid argument(s): 1455 generated a region whose boundary is not a closed ...`.
- WS11: `Expected: '200', Actual: '10000000.000000002'`.

**Doc.** Spec 07 D11 has a new paragraph, "Amended by fix/post-11". It covers the ceiling and why, that it is refused the same way as the floor, the probe's numbers, and the known limit: a loaded thicker wall still throws on the Wall tool's and grips' regenerating edits, while the panel's edits stay caught.

## 2. (B) The triangulator's signed area: `9352103`

**The change.** In `packages/jet_cad_2d/lib/src/geometry/triangulate.dart`, `_signedArea` subtracts the first vertex of the (deduplicated) `index` loop from every point before the shoelace sum.
- The caller already guarantees at least 3 entries.
- It is scalar code and allocates nothing, the same as before. The triangulator as a whole allocates (index lists) and is off the frame path, as before.
- The doc comment gives the reason.
- The probe's patch (`q4p-shoelace.patch`) is the same for the engine. Its app half (`wall_geometry.dart`'s `signedArea`) was **not** applied, as ruled.

**Other shoelace sums in `packages/jet_cad_2d/lib`.** I searched for shoelace, signedArea, area and the `x*y - x*y` cross-sum pattern. `_signedArea` is the only one. `insideClosedPolyline` (`distance.dart`) is an even-odd ray cast, not a sum, and `primitives.dart`'s cross products are segment intersection. Nothing else changed.

**Tests:**
- **Engine**, `test/geometry/triangulate_test.dart`, group "a ring far from the origin keeps its winding (fix/post-11 (B))". It uses the probe's exact ring: 150 × 0.01 mm at 23°, near (1e9, 1e9), anticlockwise.
  - At 1e9, anticlockwise: expects 2 anticlockwise triangles with area 1.5 ± 1e-4.
  - At 1e9, clockwise (the reversal branch): the same expectations.
  - The control: the same ring moved by (−1e9, −1e9). The test asserts the move is exact (Sterbenz: `v + 1e9 == far[i]`). Both windings give 2 triangles.
- **App**, `wall_tool_test.dart`, **WT19**: a **3.2 mm** wall, 50 thick, from (498765432.5, 5498765432.25) to (498765433.7503396, 5498765435.195616). These are UTM-like mm coordinates, and the direction is 67°.
  - It is drawn through the shell's Wall tool. Each click snaps onto a survey tick's endpoint (a root LINE), with the camera at 100 px/mm, so the stored endpoints are exact.
  - The thickness is set through the tool's settings notifier.
  - The test expects no exception, a single wall with exactly those endpoints and thickness 50, one undo step, fill, outline and centreline children, and no drift.

  **How I found the fixture.** I ran a scratch sweep with the **original** triangulator restored. It was a temporary test in the app's test directory, now deleted; the output is in `scratchpad/q4-search-orig.out`. At the two georeferenced sites, 22 directions and L from 1 to 3.2 mm, `execute` threw in 12 cases at t = 200 (L up to 1.55 mm) and in 191 cases at t = 50 (L up to 3.2 mm). The fixed file was then copied back and `diff`ed (exit 0).

**Red before the fix:**
- Engine: `+10 -2`. Both far rings failed with `Expected: <6>, Actual: <0>`; the control passed.
- WT19 was first run on the fixed engine. It is red on the pre-fix code through `M-q4-absShoelace`, which is exactly that code: `Expected: null, Actual: ArgumentError:<Invalid argument(s): 14 generated a region whose boundary is not a closed ...`.

**Doc.** The engine spec that owns the triangulator is `docs/superpowers/specs/2026-08-21-jet-cad-2d-plan-3e-design.md`, § "The algorithm" ("Winding is normalised to counter-clockwise …"). It gets an "Amended by fix/post-11" paragraph.

## 3. The panel's number text: `1ba7b94`

**How the field parses.** `_parse` uses `double.tryParse(text.trim())`. There is no unit parser.

**The change.** In `apps/floor_planner/lib/selection_panel.dart`, the static `_number` is replaced by a top-level `@visibleForTesting String panelNumberText(double v)`, and `_show` is its one caller.
- A whole number with |v| < 2^53 (not −0) shows as `v.toInt().toString()`, so there is still no ".0".
- Anything else shows as `v.toString()`, Dart's shortest round-trip form, which `double.parse` reads back exactly. Examples: "100000000000000000000.0", "1e+300", "0.1", "9007199254740992.0".
- −0.0 shows "-0.0" and parses back to −0.0. The Position field can hold −0: `value >= 0` accepts a typed "-0". I found this by reading.

**Tests:**
- **SE17**: a Box width of `1e20` by Enter, which also hands focus back, so it is Enter followed by a focus loss. Then a second focus loss by tapping the section title. The test expects:
  - exactly one undo step;
  - `BoxParams(1e20, height)`;
  - `double.parse(shown) == 1e20`;
  - after undo, the width is no longer 1e20.
- **SE18**: a round trip, exact and with the same sign bit, over 0, −0, 1, 200, −40, 262.5, 0.1, 1e-12, 5e-324, 2^53 − 1, 2^53, 2^53 + 2, 2^63 − 1 (as a double), 1e20, 1e300, −1e300 and maxFinite. It also checks the exact texts '0', '1', '200', '-40', '9007199254740991'.

**Red before the fix.** SE17 on the old code: `Expected: <3>, Actual: <4>` (undoDepth: the second, silent step).

## Mutants

For each one I copied the file to `scratchpad/q4-bak-<name>`, mutated it, ran, copied it back, and ran `diff` (exit 0 every time). The runner is `scratchpad/q4-mutant.sh`, and the outputs are `scratchpad/q4-mut-<name>.out`.

| Mutant | Change | Run | Result |
|---|---|---|---|
| M-q4-noUpperBound | `t.isFinite && t > wallJoin.linear` | selection_panel + wall_params | **red**, +30 −4: WS10 (1e100), WS10 (1e25), WS11, WP5 |
| M-q4-boundary | `t < kWallMaxThickness` | same | **red**, +33 −1: WP5 |
| M-q4-hugeBound | `kWallMaxThickness = 1e30` | same | **red**, +32 −2: WS10 (1e25) behaviourally (a 1e25 setting collapses the band and the click throws), and WP5 (`Expected <1e7>, Actual <1e+30>`) |
| M-q4-absShoelace (engine) | raw `c[p*2]*c[q*2+1] - c[q*2]*c[p*2+1]` | triangulate_test | **red**, +10 −2: both far rings |
| M-q4-absShoelace (app) | same | wall_tool_test | **red**, +19 −1: WT19 (the ArgumentError out of the click) |
| M-q4-oldNumber | `v == v.roundToDouble() ? v.round().toString() : v.toString()` | selection_panel_test | **red**, +22 −2: SE17 (undoDepth 4 vs 3), SE18 (the first failure is at −0.0: "0" parses to +0) |

## Gates at HEAD `1ba7b94`

`export PATH=/root/flutter/bin:$PATH`. Every test command ran with `CI=true`.

| Gate | Test | analyze | format | Other |
|---|---|---|---|---|
| [engine] `packages/jet_cad_2d` | `00:24 +1090 -2: Some tests failed.`, exit 1. The standing 2 are `generate_document_test` "both text fractions default to zero and change nothing" and "the default document is the one Plan 2 measured, byte for byte". | "No issues found!", exit 0 | "Formatted 157 files (0 changed)", exit 0 | |
| [render] `packages/jet_cad_2d_flutter` | `01:05 +940 ~1 -7: Some tests failed.`, exit 1. The standing 7 are `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2. | "No issues found!", exit 0 | "Formatted 177 files (0 changed)", exit 0 | |
| [app] `apps/floor_planner` | `03:16 +500: All tests passed!`, exit 0 | "No issues found!", exit 0 | "Formatted 102 files (0 changed)", exit 0 | `flutter build web --release` "✓ Built build/web", exit 0 |
| [harness] `apps/dev_harness_2d` (`--concurrency=1`) | `00:53 +82: All tests passed!`, exit 0 | "No issues found!", exit 0 | "Formatted 22 files (0 changed)", exit 0 | |

**Counts at the branch point (`363efd0`).** I did not re-run these myself; they come from the ledger.
- Engine +1087 −2 (Q3; no engine file changed since).
- Render +940 ~1 −7.
- App +493 (Q1+Q2).
- Harness: no recorded number, and I did not run it at the branch point.

**Deltas.** Engine +3 (the far-ring group) and app +7 (WS10 ×2, WS11, WP5, WT19, SE17, SE18), both consistent with the branch point. The standing failures are unchanged.

## Deviations

1. **A second WS10 value, 1e25.** Neither 1e100 nor a value one ulp above the bound kills M-q4-hugeBound, because 1e30 still refuses both. 1e25 kills it behaviourally. WP5's literal `kWallMaxThickness == 1e7` pins the ruling's value as well.
2. **WS10 does not override `FlutterError.onError`.** My first draft did, and the test binding asserted ("A test overrode FlutterError.onError …"), after which the run hung. WS10 relies on `tester.takeException()`, which is where the probe's pointer-event ArgumentError is reported, as shown in the red runs.
3. **WT19 is a 3.2 mm wall at t = 50**, not "a 3 mm wall". I picked it from the sweep as the longest refused case with a realistic thickness. Its thickness comes through the Wall tool's settings notifier, not by typing in the panel.
4. **`_number` became the top-level `@visibleForTesting panelNumberText`**, so SE18 can test the round trip directly.
5. **Commits.** Each commit's own touched test files were run green before committing. The full gates ran once, at the final HEAD.

## Outside scope (reported, not fixed)

- **The app's `signedArea` / `isSimpleCcw` is still raw-coordinate, as ruled.** WT19's wall lands, but with a spurious `wall.fallback`: "wall 14 is shorter than its corners: both of its ends are square". So a far, short wall loses its joints. I printed this once and did not assert it, because it is the ruled debt (WG10, WR12 and KJ1 would move).
- **A non-finite value in the panel (by reading, not driven).** The old `_number` called `.round()` on infinity (`inf == inf.roundToDouble()`), which throws `UnsupportedError`. So a loaded file with an infinite Box side or wall thickness would have thrown from `_show`. `panelNumberText` shows "Infinity" or "NaN" instead.
- **Known limit, in the spec.** A loaded wall thicker than 1e7 still throws on the Wall tool's and grips' regenerating edits.
