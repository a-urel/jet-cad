# The example apps in shadcn — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/restaurant_demo` and `apps/architecture_demo` root in a
plain `ShadApp`, build every widget of their own from `shadcn_ui` (zinc,
light and dark, Lucide icons), with every key, flow and string unchanged
and a guard that keeps Material out of their `lib/`.

**Architecture:** Each demo's `MaterialApp` becomes a `ShadApp` (it
derives the Material `ThemeData` the canvas reads from the `ShadTheme`);
the `Scaffold`, `AppBar` and `Drawer` go (a shadcn top pane, a right
`ShadSheet`); each Material control is swapped for its shadcn counterpart
under the same `Key`. Tests that found a Material type find the shadcn one,
under one ruling per change.

**Tech Stack:** Flutter pub workspace (Flutter 3.47.6 locally);
`shadcn_ui ^0.57.1` (resolves 0.57.3), `lucide_icons_flutter ^3.1.25`;
`flutter_test`, `integration_test`.

**Spec:** `docs/superpowers/specs/2026-10-24-demos-shadcn-design.md`
(rev 2, approved 2026-10-24: "onaylıyorum, planı yaz"). Read it whole
before any task. Decisions are cited as D1–D10, goals as G1–G5.

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

### Task 5: The guards

**Files:**
- Create: `apps/restaurant_demo/test/invariants/kept_material_test.dart`
- Create: `apps/architecture_demo/test/invariants/kept_material_test.dart`

- [ ] **Step 1: Write DKM1 and DKM2** (spec D8) per demo, modelled on
  `packages/jet_cad_2d_plan/test/invariants/kept_material_test.dart`
  (read it): scan `lib/**.dart`; DKM1 — every match of the Material
  construct list (the library's list: `MaterialApp`, `Scaffold`, `AppBar`,
  `Drawer`, `*Button`, `TextField`, `Tooltip`, `AlertDialog`,
  `SimpleDialog`, `showDialog`, `showMenu`, `PopupMenu*`, `Dropdown*`,
  `SegmentedButton`, `*ListTile`, `Switch(`, `Checkbox(`, `Material(`,
  `InkWell`, `Divider`, `Card(`, `SnackBar`, `ThemeData(`, `Theme.of`)
  is in an allow-list of (file, construct, reason); a stale entry fails;
  expected allow-list: empty. DKM2 — no `Icons.`.
- [ ] **Step 2: Run** — green (Tasks 1–4 removed them).
- [ ] **Mutations (controller):** an `IconButton` in
  `restaurant_demo/lib/side_panel.dart` → DKM1 red; `Icons.add` in
  `architecture_demo/lib/document_host.dart` → DKM2 red; a stale
  allow-list entry → DKM1 red.
- [ ] **Step 3: Commit** `test(demos): no Material and no Icons in the demos' lib`.

### Task 6: Docs, gates and results

**Files:**
- Modify: `docs/host-guide.md` (line 22's restaurant demo sentence if it
  names Material; §10 around line 1282: the POS look is now the canvas
  `PlanTheme`, the app is zinc `ShadApp`)
- Create: `docs/superpowers/notes/2026-10-24-demos-shadcn-results.md`
- Modify: `STATUS.md` (In-flight)
- Create: `docs/superpowers/ledgers/2026-10-24-demos-shadcn/` (the
  workspace's ledger, briefs, reports, `rulings.md`)

- [ ] **Step 1: Gates** (real last lines into the results note):
  `flutter test`/`analyze`/format in both demos; `cd
  packages/jet_cad_2d_plan && flutter test`; `cd
  packages/jet_cad_2d_integration && flutter test`; `cd tool/screenshots
  && flutter test`; `cd tool/ci && dart test`; `dart run
  tool/ci/check_guide.dart`; `dart run tool/ci/check_screenshots.dart`.
- [ ] **Step 2: Real runs:** `flutter build macos --debug` in both demos;
  `flutter test integration_test -d macos` in both.
- [ ] **Step 3: Look:** launch both demos on macOS, light and dark,
  screenshot each at desktop width; put them in the results note's
  evidence, say what was and was not looked at.
- [ ] **Step 4: Docs, results, STATUS, ledger archive; commit**
  `docs: results of the example apps in shadcn`.
