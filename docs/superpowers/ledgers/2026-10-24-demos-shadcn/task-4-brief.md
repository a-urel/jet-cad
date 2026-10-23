### Task 4: The architecture demo

**Files:**
- Modify: `apps/architecture_demo/pubspec.yaml` (add `shadcn_ui: ^0.57.1`, `lucide_icons_flutter: ^3.1.25`)
- Modify: `apps/architecture_demo/lib/main.dart` (`_app`, `kAppSeed`'s use), `lib/document_host.dart`
- Create: `apps/architecture_demo/lib/app_theme.dart` (`ShadThemeData appShadTheme(Brightness)`: zinc, Roboto)
- Modify: tests that break: `document_commands_test.dart:86,93,802-821`, `document_replace_test.dart:43`, `app_words_test.dart:36`, `document_save_test.dart:227`, `app_shell_test.dart:31`, `support/app_rig.dart:82` (comment)
- Create: `apps/architecture_demo/test/app_root_test.dart`

- [ ] **Step 1: Write the failing tests** in `app_root_test.dart`:
  - `AD1` one `ShadApp`, no `MaterialApp`, no demo-built `Scaffold`
    (the editor's own excluded), `toolbar-open-sample` is a
    `ShadIconButton`.
  - `AD2` as RD2 with `appShadTheme`.
  - `AD3` a failed open shows a `ShadDialog` keyed `document-error` with
    `document-error-title`, `-text`, `-ok`; OK closes it.
  - `AD4` with the plan dirty, New: the `ShadDialog` keyed
    `replace-dialog`; the focus is on `replace-save`; Escape →
    `SaveChoice.cancel` (the dialog closes, the plan unchanged); a tap
    outside does nothing (`barrierDismissible: false`); the name prompt's
    field is a `ShadInput` keyed `name-prompt-field`, Enter submits.
- [ ] **Step 2: Run** — red.
- [ ] **Step 3: Implement** (spec D1, D5): `ShadApp(navigatorKey:,
  onGenerateTitle:, delegates, theme: appShadTheme(light), darkTheme:
  appShadTheme(dark), themeMode: ThemeMode.system, builder: today's
  `CallbackShortcuts`, home:)`; `kAppSeed` goes if nothing else reads it.
  `DocumentHost` returns the `PlanEditor` without a `Scaffold`. Dialogs:
  `showShadDialog` with `ShadDialog.alert` (error), `ShadDialog` (save
  changes: `ShadButton.ghost` don't save, `ShadButton.outline` cancel,
  `ShadButton` save with `autofocus`; Escape kept), the name prompt
  (`ShadInput` under a `Text(fileName)` label, `onSubmitted`). The title's
  `Tooltip` → `ShadTooltip`; the open sample button →
  `ShadIconButton.ghost(icon: Icon(LucideIcons.house, size: 20))` with a
  `ShadTooltip` of `openSample`.
- [ ] **Step 4: Retarget the old tests** (one ruling each): the
  `is IconButton` helpers → `is ShadIconButton` (`onPressed`; the tooltip
  read from the wrapping `ShadTooltip`'s builder output by hovering, or
  from a test-visible source the implementer names in the ruling);
  `find.byTooltip('Edited')` → hover the title, `find.text('Edited')`;
  `TextField.controller.text` → `ShadInput.controller.text`;
  `app_shell_test.dart:31` the test's own `AlertDialog`/`TextField`
  fixture → `showShadDialog`/`ShadDialog`/`ShadInput` (the chord is still
  consumed above the route).
- [ ] **Step 5: Run** `flutter test` in the demo; all green.
- [ ] **Mutation (controller):** `barrierDismissible: true` on the save
  dialog → AD4 red; Save without `autofocus` → AD4 red.
- [ ] **Step 6: Commit** `feat(architecture_demo): a ShadApp root and shadcn dialogs`.

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
