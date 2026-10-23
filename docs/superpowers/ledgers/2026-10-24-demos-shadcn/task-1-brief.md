### Task 1: The restaurant demo's root and look

**Files:**
- Modify: `apps/restaurant_demo/pubspec.yaml` (add `lucide_icons_flutter: ^3.1.25`)
- Modify: `apps/restaurant_demo/lib/main.dart` (the app widget's `build`, `_theme`, `_viewTheme`, `_viewKey`)
- Modify: `apps/restaurant_demo/lib/demo_theme.dart` (`posShadTheme` → `demoShadTheme`)
- Modify: `apps/restaurant_demo/test/look_test.dart`
- Create: `apps/restaurant_demo/test/app_root_test.dart`

**Interfaces:**
- Produces: `ShadThemeData demoShadTheme(Brightness brightness)` in
  `demo_theme.dart` (zinc, `ShadTextTheme(family: 'Roboto')`, today's
  `posShadTheme` body). Task 2 and 3 read colours through
  `ShadTheme.of(context)`.

- [ ] **Step 1: Write the failing tests** in `app_root_test.dart`:
  - `RD1` the app pumped by the rig: `find.byType(ShadApp)` finds one,
    `find.byType(MaterialApp)` none; `ShadTheme.of(editorContext)`
    `.colorScheme` equals `demoShadTheme(b).colorScheme` for the platform
    brightness `b`.
  - `RD2` with `platformBrightnessTestValue` dark, then light (one pump
    each): `Theme.of(editorContext).brightness` follows, and
    `Theme.of(editorContext).colorScheme.surface ==
    demoShadTheme(b).colorScheme.background`.
  - `RD3` under the POS look, `Theme.of(editorContext).extension<PlanTheme>()`
    is `posPlanTheme(b)`; under Standard it is null.
- [ ] **Step 2: Run them** — `cd apps/restaurant_demo && flutter test test/app_root_test.dart`; expected: RD1, RD2 fail (a `MaterialApp`).
- [ ] **Step 3: Implement** (spec D1, D2): `ShadApp(theme:
  demoShadTheme(light), darkTheme: demoShadTheme(dark), themeMode:
  ThemeMode.system, materialThemeBuilder: (context, t) => _look ==
  DemoLook.pos ? t.copyWith(extensions: [posPlanTheme(t.brightness)]) : t,
  …today's title, locale, delegates, home)`. Remove `_seed`'s use for the
  theme, `_theme`, `_viewTheme` and its `ShadTheme` wrap; keep `_viewKey`
  only if the editor still needs it to stay mounted (the wrap was the
  reason). The view's `theme: kPosViewOverride` stays.
- [ ] **Step 4: Retarget `look_test.dart`** (spec D2), one ruling per
  assertion changed: "no `ShadTheme` under Standard" → the `ShadTheme` above
  the view is the app's (`demoShadTheme`) under both looks; "the bar is the
  derived background" → the bar is `demoShadTheme(b).colorScheme.background`
  under both; what differs between the looks (selection colour, 3 px width,
  52 px bar, canvas background `kPosPlan*.canvasBackground`) stays asserted.
  `find.byType(Scaffold)` at line 82 → the editor's own `Scaffold` (inside
  `PlanEditor`) or the view key, whichever the test meant (read it).
- [ ] **Step 5: Run** `flutter test` in the demo; all green.
- [ ] **Mutation (controller):** `materialThemeBuilder` returns `t`
  always → RD3 and the look test go red.
- [ ] **Step 6: Commit** `feat(restaurant_demo): a ShadApp root, zinc, the look on the canvas`.

## Global Constraints

- Never commit `analysis_options.yaml` (`git status --short` before every
  commit); never synthesize output; English code, comments, commits;
  trailer `Co-Authored-By: <model> <noreply@anthropic.com>`.
- Never merge, push, tag or publish.
- **No change under `packages/`** (spec N1). A library defect found on the
  way: stop the task, report it; never a demo-side workaround.
- **Keys:** every `Key` in the demos' `lib/` keeps its value and lands on
  the widget a user acts on (spec D6).
- **Strings:** every visible word stays where it comes from today
  (`DemoStrings`, `AppStrings`, `PlanStrings`); no shadcn component that
  shows its own English words (no `ShadSelect.withSearch`, no date picker).
- **No `Icons.`** in a demo's `lib/` once its task is done: `LucideIcons`.
- **Rulings:** a test changes only under a ruling in
  `.superpowers/sdd/2026-10-24-demos-shadcn/rulings.md`: file:line,
  old → new, how the new finder checks the same thing on the same key.
  Never drop an assertion; never widen a tolerance.
- **Self-review per task** (the human's rule: no reviewer subagents): the
  controller reads the diff, runs the task's named mutation itself and
  re-runs the gates.
- **A task ends green** in the demo it touched: `flutter test`,
  `flutter analyze`, `dart format --output=none --set-exit-if-changed .`.

## Review Focus

1. **The system flips light/dark at runtime:** `ShadApp`'s derived
   Material theme flips with it, so the canvas background and the paper
   follow, as they did under `MaterialApp`. → Task 1 test `RD2`, Task 4
   test `AD2`.
2. **The language switch at runtime** (EN → DE → TR): the top pane's tabs,
   the sheet's switches and the dialogs show the new words with no stale
   English. → Task 2 test `RT4`.
3. **Phone width (375 px):** the top pane's controls scroll, the sheet
   opens from the side button and fits, nothing overflows. → Task 2 test
   `RT2`.
4. **Large text (`TextScaler.linear(2.0)`)** at 375 and 1300 px: the top
   pane and the side panel do not overflow. → Task 2 test `RT3`.
5. **Keyboard only in the architecture demo's dialogs:** Save has the focus,
   Enter saves, Escape cancels, the name prompt's Enter submits. → Task 4
   test `AD4`.

---
