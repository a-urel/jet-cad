# Task 9 review (551985c8..5229bd1b): words, fonts, theme (spec P5)

### Spec Compliance

- ✅ Spec compliant. Every file the brief lists has its hunk (32 files in the diff stat, matching the brief's Files block and Step 13's add list). Checks run:
  - **The strings port.** A script compared member lists against `packages/jet_cad_floor_plan/lib/src/l10n/strings*.dart`. The source has 125 members and the port has 80, which is the source minus exactly the brief's 48 stay-behind members plus `lockedHint`, `sectionFailed` and `planDamaged`. No stay-behind member survives. In each of en/de/tr, every kept `@override` body is byte-identical to the source after the `FloorPlanColor`→`PlanSwatch` and `FloorPlanStrings`→`PlanStrings` renames. The only body that differs is `colorName`, and only by its parameter name. The three new words match the brief in all three languages (strings_en.dart, strings_de.dart, strings_tr.dart, in the diff at 1523-1531, 1820-1826 and 2113-2120).
  - **Files copied from the brief.** `swatch.dart`, `plan_theme.dart`, `plan_fonts.dart` and `localizations.dart` are identical to the brief's code blocks (`diff` is empty). `locale_scope.dart` differs only by `import 'strings.dart';` (locale_scope.dart:10). The brief needs that import for its own code to compile, so it is a valid deviation.
  - **Rename-only ports.** `number_text.dart`, `search_fold.dart`, `numbered_names.dart`, `document_separator.dart` and `panel_number.dart` were diffed against the source. The only differences are the renames, the import paths and the header comments. The `numbered_names.dart` header drops the room phrase, as the brief asks. `panel_number.dart` gains a new one-line header.
  - **Ported tests keep their assertions.**
    - `l10n_test.dart` is the source after the five renames. It differs only in its imports and formatting.
    - VW1 (`value_words_test.dart`) is verbatim.
    - NN2's first loop is verbatim. The `roomName` assertion moved to sub-project 3, and the brief lists that move.
    - FR1 (`fonts_register_test.dart`) differs only in renames, the import and the header.
    - NS7a and NS7 (`document_separator_test.dart`) keep every expectation of `jet_cad_floor_plan/test/host/new_plan_separator_test.dart:96-127`. Only the brief's listed substitutions change (`_Shows`, `c.document`, the `PageComponent` read).
    - PA6 and PA8 are unchanged apart from renames.
  - **The NS7 ruling** is implemented as the brief gives it.
    - `push` reports the locale and `PlanStrings.of(context)` (locale_scope.dart:26-31).
    - `reportLocale(locale, {strings})` stores `_reportedStrings` (plan_controller.dart:575-578).
    - `_separatorOf` (plan_controller.dart:266) is used by the settle path (:584) and by `newPlan` (:322).
  - **"Never notify during a build."** The report is posted after the frame, guarded by `context.mounted` (locale_scope.dart:29-30). W-L4 pins this: the listener phase is `postFrameCallbacks`, and an unchanged locale writes once only.
  - **R-h.** `PlanSwatch` is exported from `jet_cad_2d_kit.dart` only, and the CHANGELOG has its bullet. `authoring.dart` is untouched, and the swatch file has no imports.
  - **The fonts move unchanged.** The SHA-256 of `lib/fonts/Roboto-Regular.ttf` (79e85140…6d95) equals the source's, and `Roboto_LICENSE.txt` is byte-identical to the source's (`cmp`).
  - **Untouched packages.** `git diff --stat` over `jet_cad_floor_plan`, `jet_cad_2d`, `jet_cad_2d_flutter` and every `analysis_options.yaml` is empty.
- **Extras, all acceptable:**
  - PA6 and PA8 are ported beyond the brief's PA1 and PA5. They are faithful ports of `package_assets_test.dart:97-120`, and each is pinned by a mutation the report claims.
  - Three unnecessary imports were removed under Step 12's allowance.
  - The `[color]`→`[swatch]` doc fix is correct, because the old reference would have pointed at nothing.
- ⚠️ **Cannot verify from diff:**
  - R-i (panel fields use the language's separator). Task 9 only supplies `formatPanelNumber` and `parsePanelNumber`. The use belongs to Tasks 17 and 18.
  - That every Task 13 and 15-20 widget calls `PlanLocaleScope.push`. This lives in later tasks.

### Strengths

- The strings port is exact, as the member-by-member check above confirms. The implementer's own script asserted 48 removals per file, which is the right guard for a mechanical port of this size.
- `push` does what the brief requires:
  - it reads the locale and the strings at dependency time, which registers the dependency;
  - it defers the write to a post-frame callback with `ensureVisualUpdate`;
  - it checks `context.mounted`.
  W-L4 asserts the scheduler phase directly, not merely "no exception".
- The theme tests run over a field table (`fields`, plan_theme_test.dart) with non-default fixtures (`fullA` and `fullB` off today's values and off each other). TH0 checks that the table is not degenerate. This is the right defence against the identity-fixture trap.
- The report flags its own two concerns honestly: the dead `decimalSeparatorFor` and the `_reportedStrings` lifecycle.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)

1. **plan_controller.dart:322: `newPlan`'s use of the reported strings is not pinned.**
   - The mutation `_separatorOf(reported)` → `decimalSeparatorFor(reported)` in `newPlan` survives.
   - W-L3 (locale_scope_test.dart:149) reports with no `strings`, so the two expressions agree there. NS7 exercises only the settle path in `reportLocale`. No Task 8 test can pass `strings:`, because the parameter is new.
   - The ruling says "a new plan's separator comes from those strings", and `newPlan()` after a host-class report is that exact case.
   - Fix: add an NS7b. Pump `_Shows` under `_FrDelegate`, call `c.newPlan()`, and expect `DecimalSeparator.comma`. Name the mutation above.
2. **new_plan.dart:39: `decimalSeparatorFor` has no caller in `lib/` or `test/` (plan-mandated).**
   - Step 10 rewrites it and says "W-L3 pins it". It no longer does: the controller calls `_separatorOf`, so the function is dead and no mutation of it can turn anything red.
   - Fix: delete it, or have `_separatorOf` call `decimalSeparatorFor(locale)` as its fallback so there is one mapping.
3. **The barrel's new exports are not exercised by any test.** These are `PlanTheme`, `ensurePlanFonts`, `kPlanFontFamily` and `registerFontLicences` (jet_cad_2d_plan.dart, new `show` lines).
   - Removing the barrel import from `plan_theme_test.dart` and `plan_assets_test.dart` was legitimate under Step 12. As a result, though, dropping one of those export lines would stay green until Task 20.
   - Fix: give each test a `show`-limited barrel import (for example `import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanTheme;`) and use the symbol through it.
4. **locale_scope.dart:29-30: the post-frame callback checks `context.mounted` but not that `controller` is still live.**
   - Suppose a host swaps the widget's controller and disposes the old one in the same frame as a pending push. `reportLocale` then writes to a disposed `ValueNotifier`, which asserts in debug when the locale differs.
   - This is low-likelihood: it needs `didChangeDependencies` with the old controller and the dispose in one frame.
   - Fix (optional): have the later widgets compare against their current controller, or guard inside the callback.
5. **Several tests carry no `M-` line in code (plan-mandated):** TH2, TH5, TH7, TH8, TH10, TH13, TH14 and TH17 (plan_theme_test.dart:179, 221, 261, 267, 311, 366, 384, 458), plus PA1, PA5 and NS7a.
   - They are verbatim brief code and ports of source tests that had none, so arguably they fall under the "ported" exemption.
   - Recorded so the human can decide whether the global "every test names its mutation" rule applies to them.

### Assessment

**Task quality:** Approved

**Reasoning:** The port is mechanically exact, with the strings, the helpers and the ported tests verified against their sources. The new locale scope and the NS7 controller change match the ruling, and W-L4 pins the never-during-build rule. The only gaps are one unpinned `newPlan` branch, a plan-mandated dead helper, and barrel exports no test exercises.
