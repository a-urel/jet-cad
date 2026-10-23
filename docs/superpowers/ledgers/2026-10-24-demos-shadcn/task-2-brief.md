### Task 2: The restaurant demo's top pane, sheet and controls

**Files:**
- Modify: `apps/restaurant_demo/lib/main.dart` (`_scaffoldFor` and the controls list; `_scaffold` key goes)
- Modify: tests that break: `layout_test.dart`, `layouts_test.dart`, `host_chrome_test.dart`, `zones_test.dart`, `look_test.dart` (the `byTooltip` ones), `support/demo_rig.dart` as needed
- Create: `apps/restaurant_demo/test/top_pane_test.dart`

**Interfaces:**
- Consumes: `demoShadTheme` (Task 1).

- [ ] **Step 1: Write the failing tests** in `top_pane_test.dart`:
  - `RT1` at 1300 px: no `Scaffold`/`AppBar`/`Drawer`/`SegmentedButton`/
    `TextField` built by the demo (`find.descendant(of: DemoHome, …)`
    excluding the `PlanEditor` subtree); keys `find-table`,
    `language-toggle`, `look-toggle`, `area-toggle`, `mode-toggle` are
    `ShadInput`/`ShadTabs` (or their key carriers, see Step 3).
  - `RT2` at 375×812: `side-panel-button` taps open a `ShadSheet` keyed
    `side-panel-drawer` of width 320 holding `DemoSidePanel`; it fits on
    screen; `app-controls` scrolls horizontally; no overflow exception.
  - `RT3` `TextScaler.linear(2.0)` at 375 and 1300 px: no overflow
    (`tester.takeException()` null).
  - `RT4` tap `lang-de` then `lang-tr`: the mode tabs read
    `PlanStrings`/`DemoStrings` in that language; `find.text('Design')`
    (English) gone.
- [ ] **Step 2: Run** — red (Material widgets).
- [ ] **Step 3: Implement** (spec D3, D4, D5 rows TextField, SegmentedButton,
  Tooltip, IconButton): a `ColoredBox(background)` → `Column`: the top pane
  (`Padding` + `Row`: title in `ShadTheme.textTheme.large`; docked: the
  controls; undocked: a `ShadIconButton.ghost(LucideIcons.slidersHorizontal)`
  keyed `side-panel-button`, its tooltip `words.hostChoices` by
  `ShadTooltip`, then the `app-controls` scroll row), a `ShadSeparator`,
  then today's body `Row`. The find field: `ShadInput` keyed `find-table`,
  `placeholder: Text(words.findTable)`, `leading: Icon(LucideIcons.search,
  size: 16)`, `onSubmitted: _find`. Each `SegmentedButton<T>` → `ShadTabs<T>`
  with `ShadTab(value:, child: Text(... key: same label key))`, no
  `content`, `value:` the current selection, `onChanged:` today's callback;
  the toggle's key on the `ShadTabs`. The look toggle's `Tooltip` →
  `ShadTooltip`. The sheet: `showShadSheet(context: context, side:
  ShadSheetSide.right, builder: (_) => ShadSheet(key:
  Key('side-panel-drawer'), constraints: BoxConstraints.tightFor(width:
  320), child: SafeArea(child: DemoSidePanel(home: this))))`.
- [ ] **Step 4: Retarget the old tests**, one ruling each:
  `zones_test.dart:87` `SegmentedButton.selected` → `ShadTabs.value`
  (the zone toggle is in `side_panel.dart`: Task 3 owns the widget; if
  Task 2 leaves it Material, leave this line for Task 3);
  `layouts_test.dart:59` the drawer width → the sheet's width;
  `look_test.dart:409-419` `find.byTooltip` → hover the look toggle,
  pump past the tooltip's wait, `find.text(word)`. Any layout number that
  followed from the `AppBar`'s height: recompute from the measured pane,
  ruling with old → new.
- [ ] **Step 5: Run** `flutter test` in the demo; all green.
- [ ] **Mutation (controller):** the sheet without its key → RT2 red; a
  `Tooltip` back on the look toggle → RT1 red.
- [ ] **Step 6: Commit** `feat(restaurant_demo): a shadcn top pane and side sheet`.

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
