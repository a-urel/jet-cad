### Task 3: The restaurant demo's side panel and host widgets

**Files:**
- Modify: `apps/restaurant_demo/lib/side_panel.dart`, `editor_profiles.dart`, `own_bar.dart`, `export_flow.dart`, `table_menu.dart`, `badges.dart`
- Modify: tests that break: `layout_test.dart:97,104,252` (`FilledButton`), `host_chrome_test.dart:207,257,323` (`TextButton`, `Icons.check`), `zones_test.dart:87,89`, `statuses_test.dart:111` (`PopupMenuItem.enabled`), `support/demo_rig.dart:255` (`DropdownButton.value`)

**Interfaces:**
- Consumes: `demoShadTheme` (Task 1). `showTableMenu`'s and
  `showDemoExportDialog`'s signatures stay.

- [ ] **Step 1: Retarget first, so they go red on today's code** (one
  ruling each): `FilledButton.onPressed` → `ShadButton.onPressed`;
  `TextButton` → `ShadButton`; `find.byIcon(Icons.check)` →
  `find.byIcon(LucideIcons.check)`; `SegmentedButton.selected` →
  `ShadTabs.value`; `SwitchListTile.value` → `ShadSwitch.value`;
  `PopupMenuItem.enabled` → `ShadContextMenuItem.enabled`;
  `DropdownButton.value` → `ShadSelect.initialValue` read through the
  select's controller or the shown option's text (the helper's contract:
  the id shown).
- [ ] **Step 2: Run** — red on the type casts.
- [ ] **Step 3: Implement** (spec D5's table): `FilledButton` →
  `ShadButton`, `.tonal` → `ShadButton.secondary`; `TextField` →
  `ShadInput`; `SegmentedButton` ×2 → `ShadTabs`; `SwitchListTile` ×8 →
  `ShadSwitch(label:, sublabel:)` keeping each key on the switch; the
  section titles and the error text from `ShadTheme.of(context)`
  (`textTheme.small`/`large`, `colorScheme.destructive`); the profile combo
  → a label `Text` over `ShadSelect<String>` keyed `pos-id`, options keyed
  `pos-id-none`, `pos-id-<id>`, the unknown-id option kept; `own_bar.dart`
  → `ColoredBox(ShadTheme muted)` and `ShadButton.ghost` per key; the
  export chooser → `showShadDialog` + `ShadDialog` keyed
  `demo-export-dialog` with one `ShadButton.ghost` per choice (same keys,
  `LucideIcons.check` on the current one) and cancel; the table menu → an
  overlay `ShadContextMenu` anchored with `ShadGlobalAnchor(at)`, visible
  on open, items keyed as today, the title item disabled, a separator,
  completing the returned `Future<String?>` on choice and with null on
  dismiss; the badges' colours and text style from `ShadTheme.of(context)`
  and `LucideIcons.user`.
- [ ] **Step 4: Run** `flutter test` in the demo; all green.
- [ ] **Mutation (controller):** the menu's "Select only this" always
  enabled → `statuses_test` red; the profile select ignores the unknown id
  → its test red.
- [ ] **Step 5: Commit** `feat(restaurant_demo): shadcn side panel, menus and dialogs`.

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
