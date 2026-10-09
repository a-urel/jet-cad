# Slice 3, Task 1: `FloorPlanTheme` and its resolution (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `a57785e`.
- **Commit:** `620dabd`. Pushed as `a57785e..620dabd`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, with `CI=true`.
- **`analysis_options.yaml`:** none touched or committed. `git status` was clean apart from the seven task files before the commit, and clean after it.
- **Scope:** nothing of Tasks 2 and 3. The engine, `jet_cad_2d_flutter`, the painters, the goldens, the counter tests and the allocation tests are not edited. Nothing is drawn from the theme yet.

## Files

| File | What |
|---|---|
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart` (new, 399 lines) | See "The theme file" below. |
| `lib/src/host/floor_plan_view.dart` (+24) | See "Changes to existing files". |
| `lib/src/host/service_view.dart` (+8) | See "Changes to existing files". |
| `lib/src/planner_shell.dart` (+9) | See "Changes to existing files". |
| `lib/jet_cad_floor_plan.dart` (+1) | `export 'src/host/floor_plan_theme.dart' show FloorPlanTheme;` |
| `test/host/barrel_test.dart` (+1) | B1 gains `'FloorPlanTheme'`, the plan's one allowed edit. |
| `test/host/floor_plan_theme_test.dart` (new, 784 lines, 24 tests) | The tests below. |

### The theme file

- **`FloorPlanTheme`**: a `final class` that extends `ThemeExtension<FloorPlanTheme>`.
  - It has a `const` constructor that never throws.
  - It has sixteen nullable fields, typed as S-5 says. Each field's doc gives its unit, what null means and the mode it reaches.
- **`copyWith`:** a null argument keeps the field.
- **`merge(other)`:**
  - `other`'s set fields win, field by field.
  - The two `TextStyle` fields merge with `TextStyle.merge` (S-3).
  - A null `other` returns `this`, the same object.
- **`lerp`:**
  - When both sides are set it uses `Color.lerp`, `lerpDouble`, `TextStyle.lerp` or `EdgeInsets.lerp`.
  - When one side is null it takes the `t < 0.5` side (S-4).
  - A null or foreign `other` returns `this`.
- **`==` and `hashCode`:** over all sixteen fields; `hashCode` uses `Object.hashAll`.
- **`toString`:** names the set fields only, e.g. `FloorPlanTheme(selectionWidth: 4.0)`, or `FloorPlanTheme()` when none is set.
- **`validateFloorPlanTheme`** (`@internal`) applies S-5's ranges and throws `ArgumentError.value` naming the field:
  - opacities must be in [0, 1], and NaN is refused;
  - the two widths and the bar height must be finite and above 0;
  - the margin, the radius and each padding side must be finite and not negative;
  - a style's `fontSize`, when set, must be finite and above 0.
- **`FloorPlanThemeScope`** (`@internal`, a `StatelessWidget`):
  - `build` reads the ambient `Theme.of(context).extension<FloorPlanTheme>()`.
  - It resolves `ambient == null ? view : ambient.merge(view)` and validates the result.
  - It provides the result through `InheritedFloorPlanTheme`, always with the same `child`.
  - `FloorPlanThemeScope.of` depends on that inherited widget. With no scope above it, `of` falls back to the ambient extension.
- **`InheritedFloorPlanTheme`** (`@internal`): a plain `InheritedWidget`, not an `InheritedTheme` (S-12). `updateShouldNotify` is `theme != oldWidget.theme`.
  - It is public inside `src/` only so the test can call `updateShouldNotify` (T1-c). It is not in the barrel.

### Changes to existing files

- **`floor_plan_view.dart`:**
  - New parameter `final FloorPlanTheme? theme`, documented with T-2's text and S-12's export-dialog sentence.
  - `build` always returns `FloorPlanThemeScope(view: widget.theme, child: _modes(...))`.
  - The existing `ListenableBuilder` moved, unchanged, into `_modes`. This keeps the diff small.
- **`service_view.dart`:**
  - New `final ValueNotifier<FloorPlanTheme?> _theme`.
  - It is set from `FloorPlanThemeScope.of(context)` in `didChangeDependencies`.
  - It is disposed with `_paper`.
- **`planner_shell.dart`:**
  - New `FloorPlanTheme? _floorTheme`, set in `didChangeDependencies`.

## Tests (`test/host/floor_plan_theme_test.dart`)

**Fixtures:**
- Two full themes, `fullA` and `fullB`. `fullA` uses the plan's values:
  - colours: selection `0xFFD81B60` on light and `0xFFFFD54F` on dark, frame `0xFF00897B`, chip `0xFF3949AB`, veil `0xFF6D4C41`, canvas `0xFF263238`;
  - widths and sizes: selection 4, frame 3, margin 300, radius 8, bar 60;
  - padding `fromLTRB(7, 3, 9, 4)`;
  - opacities: fill 0.5, veil 0.35;
  - styles: caption 14 bold, chip 13.
- `fullB` has a different value in every field.
- The plan is the embedding fixture with a page, under `embeddingCamera()`.
- The themes come from `palette_fixture`'s seed themes via `copyWith(extensions:)`.
- A table of the sixteen fields (getter, `copyWith` setter, per-type lerp) drives the per-field loops.

| Group | Tests |
|---|---|
| Field table | All sixteen fields are set in both full themes, null in the empty theme, and different between the two. |
| `merge` | For each of the sixteen fields, a view setting only that field over the full ambient: that field is the view's (a style is `ambient.merge(view)`), and the 15 others are the ambient's. A null view returns the ambient itself; an empty view keeps it. **T1-a:** ambient caption 14 px and view bold give 14 and bold; the chip style the same way; the view's size wins where both set it. |
| `lerp` | Between the two full themes at 0, 0.25, 0.5 and 1, each field equals its type's lerp (doubles `closeTo` 1e-12). Every non-style field is its end value at 0 and at 1. **T1-b:** from no `groupFrameColor` to `0xFF00897B`, the value is null at 0.25, and at 0.75 it is `0xFF00897B` with alpha 1; a one-sided full theme switches at 0.5 in both directions. `lerp(null, t)` is the theme itself. Through `ThemeData.lerp`: a light theme with the extension and a dark one without give back the first's extension (identical); both with it give `fullA.lerp(fullB, t)`. |
| Value semantics | `copyWith()` is equal but not identical, with the same hash. Each field changed alone makes `!=` and a different hash, and leaves the other fields as they were. Each single field set makes a theme `!=` the empty one, with a different hash. `toString` checks three exact strings; `type == FloorPlanTheme`. |
| Validation, through the view with `takeException` | Accepted values each return null, with `ServiceView` mounted and the theme resolved: opacities 0, 1 and 0.35; widths and bar 0.5; margin, radius and padding 0; font size 0.5; the full theme. The accepted values are also accepted as the ambient theme. Refused values each throw an `ArgumentError` whose `name` is the field, as the view's theme **and** as the ambient: opacities -0.01, 1.01, NaN and infinity; widths, bar and font sizes 0, -1, infinity and NaN; margin, radius and each padding side -1, infinity and NaN. |
| Resolution, in both modes | **P-6:** no theme gives `null`; ambient only gives the ambient itself; view only gives the view itself. **M-H30:** ambient `{groupFrameColor}` and view `{selectionOnLight}` resolve to both; ambient `selectionWidth` 3 and view 5 resolve to 5. An ambient switch, light with A to dark with B at zero animation, reaches the mode after one pump. |
| Bare `PlannerShell` | It reads the ambient extension (identical), and null without one. |
| T1-c | `updateShouldNotify`: false for equal, non-identical themes and for null and null; true for different themes and for null against a theme. Through the view: a `ThemeReader` overlay widget logs each of its dependency changes. A host rebuild with an equal, non-identical view theme logs nothing; a different theme logs once. |
| G-5 / H-8 | An ambient switch from light (`fullA`) to dark (another theme) leaves the builder at 7 calls, while the resolved theme does change. A scope-only change, the host's `Theme` around the same view instance, leaves it at 7 calls, while the resolved theme changes. Control: a host rebuild of the view raises it to 14. |
| S-12 | The local `Theme` is a hand-built zinc `ColorScheme` with extension `{groupFrameColor}`; the view's theme is `fullB`; Export is pressed from the service bar. In the dialog: `Theme.of` is that scheme, and the dialog's `Material` colour is the scheme's `surfaceContainerHigh`. `FloorPlanThemeScope.of(dialog)` is the local theme's extension, not the merged theme. |
| Barrel | `host.FloorPlanTheme` (prefixed barrel import) in `ThemeData(extensions:)` and in `host.FloorPlanView(theme:)` resolves to the expected merge. |

## Mutants

Each mutant was applied by script (`scratchpad/mut/run.py`), run against `floor_plan_theme_test.dart`, then restored from a copy. The script asserts that each mutant changed the file, and no `.bak` was left.

| Mutant | Red killers (test names) |
|---|---|
| **M-H30** `view ?? ambient` | `M-H30 (design)`, `M-H30 (selection)` (plus both G-5 tests and the barrel test) |
| **M-H30 reversed**, ambient wins (`view?.merge(ambient) ?? ambient`) | `M-H30 (design)`, `M-H30 (selection)` (the precedence check, 5 over 3), both G-5 tests, S-12 |
| **T1-a** styles replaced whole (`over ?? base`) | `T1-a: the text styles merge property by property…`, the sixteen-field merge test, the barrel test |
| **T1-b** colour lerp fades (`Color.lerp(a, b, t)` for the six colour fields) | `T1-b: a field null on one side switches at 0.5 and never fades…` |
| **T1-c** notify by identity | `updateShouldNotify: false for equal themes, true for different`; `a host rebuild with an equal, non-identical view theme notifies no dependent…` |
| X1: `FloorPlanView.build` reads `Theme.of` (resolution in the view, S-11's alternative) | both `G-5, H-8` tests |
| X2: `InheritedFloorPlanTheme` as an `InheritedTheme` | `S-12: the export dialog…` |
| X3: the opacity check misses NaN | the validation test |
| X4: the padding checks the left side only | the validation test |
| X5: `merge(null)` returns a copy | `a null view is the ambient itself…`, `P-6 (design)`, `P-6 (selection)` |
| X6: one side null always takes `b` | `T1-b…` |
| X7: `==` ignores `groupChipPadding` | `each field changed alone makes != and a different hash` |
| X8: `toString` names null fields | `toString names the set fields only` |
| X9: `of` without a scope returns null | `a bare PlannerShell reads the ambient extension`, S-12 |
| X10: the scope does not validate | the validation test |

The first run of the reversed M-H30 used `view == null ? ambient : view.merge(ambient)`, which did not compile because a public field is not promoted. It was re-run in the `?.` form shown above and is red.

## Gates (real results)

| Gate | Result |
|---|---|
| Planner `packages/jet_cad_floor_plan` | `flutter test --enable-vmservice --file-reporter json:…`: "All tests passed!", **1623 tests** (1599 + 24). `expect_failures`: "the standing failures and skips, exactly", exit 0. `flutter analyze`: No issues found. Format exit 0. |
| `apps/restaurant_demo` | `flutter test`: 57, all passed. Analyze: no issues. Format exit 0. |
| `apps/floor_planner` | `flutter test`: 212, all passed. Analyze: no issues. Format exit 0. |
| Engine `packages/jet_cad_2d` | `dart test` through the comparison: "1258 tests; the standing failures and skips, exactly", exit 0. |
| Render `packages/jet_cad_2d_flutter` | `flutter test` through the comparison: "1379 tests; the standing failures and skips, exactly", exit 0. |

The P-6 files are unedited and green: `view_test`, `table_overlay_test`, `controller_test`, `planner_shell_test` and `widget_theme_test`. `barrel_test` changed only in B1's one name. All of them are in the planner's 1623.

## Findings and deviations

1. **`PlannerShell._floorTheme` carries `// ignore: unused_field`.**
   - The field is only written in Task 1, and `flutter analyze` reported `unused_field` (a warning, which fails the gate).
   - The ignore line is commented "the selection's colours and width read it (Slice 3, Task 2)". **Task 2 should drop the ignore** when it reads the field.
2. **The wiring of `ServiceView._theme` and `PlannerShell._floorTheme` is not observable in Task 1**, because nothing reads either field yet.
   - The tests read the scope's value from an element under each mode's view, as the plan says. They do not read the state's fields.
   - A mutant that drops either assignment would survive Task 1. Tasks 2 and 3, which draw from the fields, own that killer.
3. **`InheritedFloorPlanTheme` is a public class in `src/`**, marked `@internal` and not in the barrel. The plan says "an internal `InheritedWidget`"; public-in-`src` is what lets T1-c's killer call `updateShouldNotify` directly.
4. **`TextStyle.lerp` at t = 0 is not `==` its start** when the other side sets a property this side leaves null, such as a colour, which it lerps from transparent. This is Flutter's own rule inside a style.
   - The lerp test therefore compares each field to its type's lerp, and checks the ends only on the non-style fields.
   - S-4's switch rule applies to a whole field that is null on one side, not to properties inside a style.
5. **`FloorPlanThemeScope.of` without a scope returns the ambient extension unvalidated.**
   - Validation runs only in the scope, under `FloorPlanView`, as the plan places it.
   - So a bare `PlannerShell` (the floor planner app) under an out-of-range ambient theme is not refused. No such host exists today.
6. **No view can be remounted on the same controller within one frame:** it throws "the dispatcher already has an expander".
   - So the two G-5 checks are separate tests, each keeping its tree shape fixed.
   - This is existing behaviour, not a change.

## Fixes

The review's R-1 to R-5, as the controller ruled them (all accepted). Applied on top of Task 2 (`58c4a60`). The only files touched are `lib/src/host/floor_plan_theme.dart` and Task 1's own `test/host/floor_plan_theme_test.dart`. Scratch files are in my own `scratchpad/s3t1-fix/`.

### Changes

| R | Change in `floor_plan_theme.dart` |
|---|---|
| R-1 | Every interpolated double is clamped between its two ends. `_lerpBetween` (`clampDouble(lerpDouble(a, b, t)!, min, max)`) covers the seven double fields. `_lerpInsets` covers each `groupChipPadding` side. `_lerpStyle` clamps the lerped `fontSize`, and calls `copyWith` only when the clamp actually changes the value. |
| R-2 | `lerp` returns `this` when `other is! FloorPlanTheme \|\| this == other`. `_lerp` returns `a` when `a == b`. |
| R-3 | `_lerpStyle`: when exactly one side's `color` is null, the whole style switches at 0.5 (`t < 0.5 ? a : b`). Otherwise it uses `TextStyle.lerp` with the clamp. |
| R-4 | `FloorPlanThemeScope.of`'s fallback (no scope above) validates the ambient extension with `validateFloorPlanTheme`, the same `ArgumentError` that names the field. It is read only in `didChangeDependencies` (the shell and the service view), so the check runs when the theme changes, never per frame. |
| R-5 | `hashCode` is `Object.hash` over the sixteen fields: no `Map`. `toString` keeps `_fields`. |

`lerp`'s doc states the clamp, the colour switch and the equal-theme rule.

### Tests (Task 1's file: extended, nothing removed)

- **The field table's `_style` (an edit):** it now encodes R-2 and R-3. An equal style gives itself, and a colour null on exactly one side switches whole; otherwise it is `TextStyle.lerp`. This was needed: `fullA`'s styles have no colour and `fullB`'s do, so under R-3 they switch.
- **The end check at 0 and 1 (stronger):** it now covers all sixteen fields, the styles included, where it used to skip the styles.
- **New fixtures:**
  - `edgeA`/`edgeB` are two valid themes with their doubles at or near the range edges and colours on both styles.
  - `expectWithinEnds` checks that each double field, padding side and style `fontSize` lies between its ends.

The new tests:

- **R-1 (unit):** `t` in {-0.2, 1.2}, both directions. Every value is within its ends, and `validateFloorPlanTheme` returns normally. Three overshoots stop exactly at the end they pass.
- **R-1 (view):** an `AnimatedTheme` with `Curves.easeOutBack` (200 ms) runs light `edgeA` → dark `edgeB` → light `edgeA`, with 25 × 10 ms frames each way. On every frame, `takeException()` is null and the resolved theme is within its ends. Each switch lands on its end.
- **R-2 (unit):** for `t = i/100`, `i` in 1..99:
  - `fullA.lerp(fullA, t) == fullA`;
  - `fullA.lerp(fullA.copyWith(), t)` is `identical` to `fullA`;
  - `fullA.lerp(fullA.copyWith(selectionWidth: 5), t)` has every other field exactly `==` to `fullA`'s.
- **R-2 (view):** an animated switch (`AnimatedTheme`, 200 ms) from light `fullA` to dark `fullA.copyWith()`.
  - The `ThemeReader` overlay logs no dependency change, and the brightness did switch.
  - Control: a switch to `fullB` notifies the reader.
- **R-3 (unit), for both style fields:**
  - With `TextStyle(fontSize: 14)` and the same plus white, `t` < 0.5 gives the near side exactly (colour null), and `t` ≥ 0.5 gives white at alpha 1. The same holds back the other way.
  - A colour on both sides lerps the colour and the size.
  - No colour on either side lerps the size.
- **R-4 (view):** a bare `PlannerShell` under the ambient `fullA` merged with `selectionWidth: -3`, then with `focusVeilOpacity: NaN`.
  - `takeException()` is an `ArgumentError` named after the field.
  - Control: `fullA` alone is accepted and resolves.

### Mutants

Each mutant was applied by `scratchpad/s3t1-fix/mutate.py` to `floor_plan_theme.dart` and run against `test/host/floor_plan_theme_test.dart`. The script asserts exactly one match per replacement and restores the file from its in-memory original. A `cmp` against the copy taken before the run was equal.

| Mutant | Result | Red tests |
|---|---|---|
| R-1 unfixed (no clamp on doubles, padding or font size) | RED | R-1 unit; R-1 `AnimatedTheme` |
| R-1a doubles only unclamped | RED | R-1 unit; R-1 `AnimatedTheme` |
| R-1b padding via `EdgeInsets.lerp` | RED | R-1 unit; R-1 `AnimatedTheme` |
| R-1c `fontSize` unclamped | RED | R-1 unit; R-1 `AnimatedTheme` |
| R-2 unfixed (neither equality short-circuit) | RED | R-2 unit; R-2 animated switch |
| R-2a no `this == other` | RED | R-2 unit (`identical`) |
| R-2b no `a == b` | RED | R-2 unit (exact field equality) |
| R-3 unfixed (the style colour fades) | RED | R-3; the field-table lerp test |
| R-4 unfixed (bare shell unvalidated) | RED | R-4 |
| R-5 `Object.hash` omits `serviceBarHeight` | RED | "each field changed alone makes != and a different hash" |

R-5's unfixed form (the `Map`) has no behavioural mutant, because it changes allocation only. The hash mutant above shows that the existing test still guards the new form.

### Gates (real results)

| Gate | Result |
|---|---|
| Planner | `flutter test --enable-vmservice --file-reporter json:…`: "+1649: All tests passed!", exit 0. `expect_failures`: "packages/jet_cad_floor_plan: 1649 tests; the standing failures and skips, exactly", exit 0. `flutter analyze`: "No issues found!". Format: "Formatted 262 files (0 changed)", exit 0. |
| `apps/restaurant_demo` | "+57: All tests passed!"; analyze "No issues found!"; format "6 files (0 changed)", exit 0. |
| `apps/floor_planner` | "+212: All tests passed!"; analyze "No issues found!"; format "47 files (0 changed)", exit 0. |
| Engine | `dart test` exit 1, as expected with the standing failures. Comparison: "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly", exit 0. |
| Render | `flutter test` exit 1, as expected with the standing failures. Comparison: "packages/jet_cad_2d_flutter: 1389 tests; the standing failures and skips, exactly", exit 0. |

- The planner's 1649 includes Task 2's tests. `floor_plan_theme_test.dart` alone went from 24 to 30 tests ("+30: All tests passed!").
- After the gates, `git status` showed only the two files: no `analysis_options.yaml` drift.
