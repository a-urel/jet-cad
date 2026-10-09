# Slice 3, Task 1: `FloorPlanTheme` and its resolution (independent review)

- **Commit under review:** `620dabd` (parent `a57785e`), branch `claude/exciting-pasteur-9m22jv`.
- **Where:** my own clones, `/home/user/review-s3t1` (gates), `/home/user/review-s3t1-m` (mutants) and `/home/user/review-s3t1-fix` (probes and a candidate fix). Nothing was edited, committed or pushed in `/home/user/jet-cad` apart from this file. See "Incident" at the end.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.

## Verdict

**Changes required. The fix is small and local to `lerp`.**

- The structure is right, and so are the scope, P-1 and P-6 and the resolution's seat (S-11). Every gate is green with real counts. Every named and task-local mutant is red.
- Three defects remain, all in `FloorPlanTheme.lerp`. They show up only during an **animated** theme switch, which no Task 1 test runs: every test uses `themeAnimationDuration: Duration.zero`.
  - **R-1 (Important):** two valid themes can produce an out-of-range theme mid-animation, and the view throws.
  - **R-2 (Minor, becomes Important in Task 3):** a theme that is the same on both sides is "changed" on most frames.
  - **R-3 (Minor):** a caption or chip style whose colour is null on one side fades from transparent. This is the harm T1-b names, one level down.
- A candidate fix for R-1 and R-2 was applied in my fix clone. The existing 24 tests still pass with it, and the probes go from red to clean (figures under each finding).
- R-4 (Minor) and R-5 (Nit) can go into the same commit or be ruled away.

## 1. Scope and P-1

- **The diff is Task 1 only.** It touches seven files: the barrel (+1 line), `floor_plan_theme.dart` (new), `floor_plan_view.dart`, `service_view.dart`, `planner_shell.dart`, `barrel_test.dart` and `floor_plan_theme_test.dart` (new). It does not touch the engine, `jet_cad_2d_flutter`, the painters, the goldens or the counter and allocation tests.
- **The barrel gains exactly `FloorPlanTheme`** (`export 'src/host/floor_plan_theme.dart' show FloorPlanTheme;`).
- **The only edited existing test is B1**, which gains one name (`git diff a57785e 620dabd -- test/host/barrel_test.dart`).
- **No internal name leaks.**
  - `FloorPlanThemeScope`, `InheritedFloorPlanTheme` and `validateFloorPlanTheme` are not reachable from any barrel.
  - `lib/editor.dart` exports `src/planner_shell.dart` whole, but `planner_shell.dart` only **imports** `host/floor_plan_theme.dart`, and imports do not re-export.
  - `symbols.dart` and `symbol_sources.dart` do not touch the file.
  - The only references outside the file are the three `import`s and the uses in `floor_plan_view.dart:352`, `service_view.dart:372` and `planner_shell.dart:281`.
- **No existing signature, `==`, `hashCode` or `toString` changes.** `FloorPlanView` gains a named optional `theme`. `PlannerShell` and `ServiceView` gain only private state.

## 2. Correctness

| Item | Finding |
|---|---|
| `merge` | Every one of the sixteen fields takes `other`'s value when set. The two styles use `base.merge(over)`, so a null base takes `over` and a null `over` keeps the base. `merge(null)` returns `this` itself. Correct. |
| `lerp` | Both sides set: the per-type lerp. One side null: the `t < 0.5` side (S-4). A null or foreign `other`: `this`. Through `ThemeData.lerp`, an extension only in the first theme stays as it is (tested). This is correct as specified for `t` in [0, 1] and for different values, **but see R-1, R-2 and R-3**. |
| `copyWith` | It can set every field (O5 is red). It cannot clear a field, which is Flutter's convention, and the doc says so. **Ruling: correct, it should not clear.** A host that wants the ambient theme minus one field builds a new theme. The doc's "[merge] a theme to set fields" is accurate. |
| `==` / `hashCode` | Both cover all sixteen fields and are consistent: `0.0` and `-0.0` give an equal theme with an equal hash (probe P5). The hash allocates a Map on each call (R-5). |
| `toString` | Names the set fields only. Correct. |
| Range checks (S-5) | Every bound and both ends are covered. NaN and infinity are refused, and so is the ambient theme. The error's `name` is the field. O6, O7, O8, O9, O12, O18 and O20 are all red. |
| Scope | Notifies only on `!=` (T1-c and O10 red). Only the scope reads the ambient theme, so `FloorPlanView.build` reads no theme (O11 red: both G-5 tests). The scope hands `InheritedFloorPlanTheme` the same child. |
| Bare `PlannerShell` | Reads the ambient extension (O23 red), unvalidated (R-4). |
| Export dialog (S-12) | Gets the ambient theme only: a plain `InheritedWidget`, which `showDialog` does not capture. The test pins the local `ColorScheme` and the dialog's `Material` colour. |
| Light→dark ambient switch | Reaches both modes after one pump at zero animation (tested in each mode). |
| Rebuild storms | With different themes on the two sides, the ambient notifies the modes once per animation frame. That is the theme rate, as S-12 accepts. With an **equal** theme on both sides it notifies on most frames, needlessly (R-2). |

## 3. Gates (rerun in `/home/user/review-s3t1` at `620dabd`)

| Gate | Result |
|---|---|
| Planner | `flutter test --enable-vmservice --file-reporter json:…`: "+1623: All tests passed!", exit 0. The JSON has 1623 visible tests, 0 skipped and 0 failed. `expect_failures` (path form): "packages/jet_cad_floor_plan: 1623 tests; the standing failures and skips, exactly", exit 0. `flutter analyze`: "No issues found!". Format: "Formatted 261 files (0 changed)", exit 0. |
| `apps/restaurant_demo` | "+57: All tests passed!"; analyze "No issues found!"; format "6 files (0 changed)", exit 0. |
| `apps/floor_planner` | "+212: All tests passed!"; analyze "No issues found!"; format "47 files (0 changed)", exit 0. |
| Engine `packages/jet_cad_2d` | `dart test` exit 1, as expected with the 2 standing failures. Comparison: "1258 tests; the standing failures and skips, exactly", exit 0. |
| Render `packages/jet_cad_2d_flutter` | `flutter test` exit 1, as expected with 7 failures plus 1 skip. Comparison: "1379 tests; the standing failures and skips, exactly", exit 0. |

- These match the implementer's counts.
- `git status` in the clone was clean after the gates: no `analysis_options.yaml` drift.

## 4. Mutants

- **Method:** each mutant was applied by script in `/home/user/review-s3t1-m`. The script asserts exactly one match per mutant, restores from the in-memory original, and the clone's `git status` was clean afterwards.
- **Run against:** `test/host/floor_plan_theme_test.dart`.

| Mutant | Result | Red killers |
|---|---|---|
| **M-H30** `view ?? ambient` | RED | M-H30 (design), M-H30 (selection); both G-5 tests; the barrel test |
| **M-H30 reversed** `view?.merge(ambient) ?? ambient` | RED | M-H30 (design), M-H30 (selection) (precedence, 5 over 3); both G-5 tests; S-12 |
| **T1-a** styles whole (`over ?? base`) | RED | the sixteen-field merge test; T1-a; the barrel test |
| **T1-b** `Color.lerp` for `groupFrameColor` (fades) | RED | T1-b |
| **T1-c** notify by identity | RED | `updateShouldNotify…`; "a host rebuild with an equal, non-identical view theme…" |
| O1 `==` omits `focusVeilOpacity` | RED | "each field changed alone makes != and a different hash" |
| O2 `_fields` omits `serviceBarHeight` (hash, toString) | RED | the field-table test; the `!=`/hash test |
| O3 `merge` drops the view's `canvasBackground` | RED | the sixteen-field merge test; "a null view is the ambient itself…" |
| O4 `lerp` of `groupChipRadius` stuck at `a` | RED | "two full themes at 0, 0.25, 0.5 and 1…" |
| O5 `copyWith` ignores `selectionOnDark` | RED | the merge test; the `!=`/hash test |
| O6 opacity bound `v < 1` | RED | validation |
| O7 `positive` accepts 0 | RED | validation |
| O8 `notNegative` refuses 0 | RED | validation |
| O9 the ambient unchecked (only the view validated) | RED | validation (refused as ambient) |
| O10 `updateShouldNotify` always true | RED | both T1-c tests |
| O11 `Theme.of(context)` read in `FloorPlanView.build` | RED | both G-5, H-8 tests |
| O12 `groupChipTextStyle` unchecked | RED | validation |
| O13 the switch at `t <= 0.5` | RED | T1-b |
| O14 `of()` uses `getInheritedWidgetOfExactType` (no dependency) | RED | "a host rebuild with an equal, non-identical view theme notifies no dependent; a different one does" |
| O15 `ServiceView._theme.value = …` dropped | **SURVIVED** | none (expected: no reader yet) |
| O16 `PlannerShell._floorTheme = …` dropped | **SURVIVED** | none (expected: no reader yet) |
| O17 the scope only when `widget.theme != null` | RED | validation (ambient refused); P-6 (design), P-6 (selection) |
| O18 padding `bottom` unchecked | RED | validation |
| O19 style merge reversed (ambient wins inside a style) | RED | the merge test; T1-a |
| O20 opacity check lets NaN through | RED | validation |
| O21 `lerp(null)` returns the empty theme | RED | "lerp(null, t) is the theme itself"; the `ThemeData.lerp` test |
| O22 `hashCode` over the names only | RED | the `!=`/hash test |
| O23 `of()` without a scope returns null | RED | "a bare PlannerShell reads the ambient extension"; S-12 |

**Summary:** 5 named and 23 of mine. 26 are red. 2 survived, O15 and O16, both expected (finding 2). Grep confirms neither field has a reader at `620dabd`: `service_view.dart:248, 372, 396` and `planner_shell.dart:233, 281`. Tasks 2 and 3 own their killers.

The mutants of R-1, R-2 and R-3 are the current code: no Task 1 test animates a theme.

## Findings

### R-1 (Important): two valid themes animate into an invalid one, and the view throws mid-switch

**What happens.**
- `lerp` uses plain `lerpDouble`.
- `ThemeData.lerp` is driven by the host's `themeAnimationCurve` (`MaterialApp`) or `AnimatedTheme.curve`. Overshooting curves such as `Curves.easeOutBack`, `easeInBack` and `elasticOut` take `t` outside [0, 1].
- An opacity lerped between two valid values then leaves [0, 1], and `FloorPlanThemeScope.build` throws.
- Widths, padding sides and font sizes can also cross their bounds under a large overshoot.

**Evidence** (probe P2 in `/home/user/review-s3t1-m`, at `620dabd`):
- Setup: light `FloorPlanTheme(statusFillOpacity: 0.8)`, dark `FloorPlanTheme(statusFillOpacity: 1.0)`, `themeAnimationCurve: Curves.easeOutBack`, switch to dark, 25 pumps of 10 ms.
- Result: `P2 exceptions during the animation: 12 Invalid argument (statusFillOpacity): must be in [0, 1]: 1.0037369360774755`.
- So for 12 frames the view is an `ErrorWidget`, and each frame reports a `FlutterError`.

**Fix.** In `lerp`, clamp each interpolated double to the interval of its two ends. Both ends are in range whenever the themes are valid, so the result is too. In `/home/user/review-s3t1-fix` I used:

```dart
static double _lerpBetween(double a, double b, double t) =>
    clampDouble(lerpDouble(a, b, t)!, math.min(a, b), math.max(a, b));
```

- Use it for the seven doubles in place of `lerpDouble`.
- Do the same per side for `groupChipPadding`.
- Clamp the lerped style's `fontSize` the same way.
- With this, P2 prints `exceptions during the animation: 0`, and the existing 24 tests pass.

**Killers:**
- **Unit tests:**
  - `FloorPlanTheme(statusFillOpacity: 0.8).lerp(FloorPlanTheme(statusFillOpacity: 1.0), 1.1).statusFillOpacity == 1.0`;
  - `selectionWidth` 0.5 → 3 at `t = -0.5` is ≥ 0.5;
  - padding `EdgeInsets.zero` → `fromLTRB(7, 3, 9, 4)` at `t = -0.2` has no negative side.
- **Through the view:** P2's setup, with no exception on any frame.

### R-2 (Minor now, Important once Task 3 keys the painters on the theme): an unchanged theme is "changed" on most frames of a switch

**What happens.**
- `Color.lerp(x, y, t)` with `x == y` recomputes each channel as `a*(1-t)+b*t`, and is not guaranteed to return an equal colour. `lerpDouble` short-circuits `a == b`; `Color.lerp` does not.
- So `theme.lerp(equalTheme, t) != theme` for most `t`.
- A host that puts the same `FloorPlanTheme` in its light and dark `ThemeData` (the natural setup when only widths or the selection colours are set) gets a "new" resolved theme on most frames of the 200 ms switch.
- `InheritedFloorPlanTheme` then notifies on each of those frames. T-3 keys every painter on this value, so in Task 3 every painter would rebuild on every frame of the switch. With a page (paper unchanged), today nothing rebuilds then. S-12 accepts the animation rate only when the look actually changes.

**Evidence:**
- **P1:** `fullA.lerp(fullA, i/100) != fullA` for **82 of 99** values of `t`.
- **P3:** the embedding fixture, `fullA` in both `ThemeData`s, a `ThemeReader` overlay depending on the scope, an animated light→dark switch (default 200 ms, 25 × 10 ms pumps): **18 notifications**.

**Fix.**
- At the top of `lerp`: `if (other is! FloorPlanTheme || this == other) return this;`.
- In `_lerp`: `a == b ? a : lerp(a, b, t)` when both are set.
- With the fix, P1 gives **0 of 99** and P3 gives **0** notifications.

**Killers:** P1 as a unit test (every `t` in 0.01…0.99), and P3 as a widget test (0 dependency changes).

### R-3 (Minor): a style colour null on one side fades from transparent

**What happens.**
- S-4 states the rule: a null value is paper-dependent, and `Color.lerp(null, c, t)` fades from transparent, so a one-sided null takes the nearer side.
- The implementation applies the rule to whole fields only. Inside `statusCaptionStyle` and `groupChipTextStyle`, `TextStyle.lerp` lerps a `color` that one side leaves null with `Color.lerp(null, c, t)`.
- A null caption colour is today's automatic black or white ink: exactly the paper-dependent value S-4 protects. Task 3 will draw a non-null lerped colour as given, so the captions fade out and back in across the switch.
- The implementer's finding 4 saw the mechanism and attributed it to Flutter. **Ruling: Flutter's rule, but our hazard.**

**Evidence** (probe P6):
- Light `TextStyle(fontSize: 14)`, dark `TextStyle(fontSize: 14, color: 0xFFFFFFFF)`.
- Light→dark at t = 0.1, 0.25, 0.75, 0.9 gives white at alpha **0.10, 0.25, 0.75, 0.90**.
- Dark→light gives 0.90 … 0.10, then null at the end.

**Fix.** When exactly one side's `color` is null, switch the whole style at 0.5 instead of `TextStyle.lerp`:

```dart
(a.color == null) != (b.color == null) ? (t < 0.5 ? a : b) : TextStyle.lerp(a, b, t)
```

**Killer:** P6's pair: `lerp(…, 0.25).statusCaptionStyle!.color == null`; `lerp(…, 0.75).statusCaptionStyle!.color == 0xFFFFFFFF` with alpha 1. The same for the chip style. This is T1-b's form, one level down.

### R-4 (Minor): a bare `PlannerShell` takes an out-of-range ambient theme unvalidated

- **This is the implementer's finding 5, confirmed.** Probe P4: `MaterialApp(theme: light + FloorPlanTheme(selectionWidth: -3), home: PlannerShell())` raises no exception.
- **Why it matters.** `PlannerShell` is public through `lib/editor.dart`, and `FloorPlanTheme` through the host barrel. Task 2 draws `selectionWidth` in the shell, so a negative or NaN width would reach `Paint.strokeWidth` in the floor planner app or any `editor.dart` host.
- **Fix.** In `FloorPlanThemeScope.of`'s fallback, validate before returning: `final ambient = Theme.of(context).extension<FloorPlanTheme>(); if (ambient != null) validateFloorPlanTheme(ambient); return ambient;`. This is the view's contract, thrown from the shell's `didChangeDependencies`.
- **Killer:** a bare shell under `selectionWidth: -3` → `takeException()` is an `ArgumentError` named `selectionWidth`.
- **Alternative:** the controller rules it accepted, and the field's doc says the bare shell does not validate.

### R-5 (Nit): `hashCode` and `toString` build a 16-entry `Map` on each call

- This is not on the frame path: nothing hashes a theme per frame.
- `Object.hash(statusCaptionStyle, …, serviceBarHeight)` (16 of its 20 slots) allocates nothing and keeps `==`'s field list in one place.
- No action is required.

## Rulings on the implementer's findings

1. **`// ignore: unused_field` on `_floorTheme`: accepted.** Task 2 must drop it when it reads the field. Its in-flight script already mutates the shell's read of `_floorTheme`.
2. **The wiring of `_theme` and `_floorTheme` is unobservable in Task 1: confirmed and accepted.** O15 and O16 survive. Task 2 owns their killers; its runner already lists "F2 shell drops `_floorTheme` assignment" and "F2 service drops `_theme` assignment".
3. **`InheritedFloorPlanTheme` public in `src/` with `@internal`: accepted.** P-1 holds: no barrel reaches it, and `editor.dart` does not re-export the theme file.
4. **`TextStyle.lerp` at t = 0 is not `==` its start: the test's reading is right, but the colour case is a defect.** See R-3.
5. **A bare shell is unvalidated: confirmed.** See R-4 (Minor): fix it or rule it.
6. **"No view can be remounted on the same controller within one frame": not reproduced by me.** It is outside Task 1's change either way: the scope is always present, so giving or removing a theme does not change the tree's shape. O17, the scope only when a theme is given, is red, through validation and P-6 rather than a remount test. **Accepted** as a test-shape note.

## Notes (no action)

- **The whole extension is asymmetric under `ThemeData.lerp`.**
  - Light with an extension → dark without one keeps A to the last frame (`lerp(null) → this`), then drops it at `t == 1`, where `Tween.transform` returns the end exactly.
  - Light without → dark with one takes B on the first frame.
  - This is Flutter's `_lerpThemeExtensions` and S-4 as ruled; it is recorded so Task 3's reading is not surprised.
- **`ServiceView._theme` is assigned in `didChangeDependencies`, as `_paper` already is.** A Task 3 listener must not `setState` an ancestor from it.

## Incident (for the controller)

**What happened.**
- My first mutation run used `scratchpad/mut/run.py`. That path is **shared** with the Task 2 implementer working in `/home/user/jet-cad`, and their own `run.py` replaced mine between my write and my run.
- So at about 16:08 UTC my background command **executed their runner**. Their runner mutates `/home/user/jet-cad` directly.
- It applied their first mutant (`M-H33(canvasBackground) shell`, `planner_shell.dart`'s `_surfaceArgb` line) for one `flutter test` run. It crashed parsing a `run.json` that was probably being written concurrently, and its `finally` block restored the file.
- I also overwrote their `scratchpad/mut/out.txt`.

**What I checked.** Read-only: `planner_shell.dart:285` and `service_view.dart:377` in `/home/user/jet-cad` hold the unmutated `_canvasColour(...)` lines.

**What the Task 2 implementer should do.**
- Re-run any mutant whose result they collected around 16:08.
- Check that no edit they made to `planner_shell.dart` in that window was lost.

**Afterwards.** All my later work used my own clones and `scratchpad/rv-s3t1-reviewer/`.
