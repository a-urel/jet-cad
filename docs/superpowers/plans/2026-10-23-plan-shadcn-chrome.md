# The plan library's chrome in shadcn — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The plan library's chrome (editor bar, tool palette, symbol
gallery, property, layer and page panels, service bar, menus, export dialog)
is built from `shadcn_ui`, takes the host's `ShadTheme` when there is one and
derives one from the host's Material `ThemeData` when there is not, with no
public API change and every behaviour test green.

**Architecture:** A new internal `lib/src/chrome/` holds the scope (theme
resolution, default text and icon style, a transparent `Material` for host
slots) and a small set of chrome parts (`PlanIconButton`, `PlanTextField`,
`PlanSelect`, `PlanSegmented`, `PlanMenuButton`, rows) that wrap shadcn
components and fix, once, the behaviours the spec pins (tap group,
read-only, model authority, menu opening, semantics, words). Each surface
is then migrated onto those parts, one task per surface. Tests that found a
Material type find the part that replaced it, under one ruling per mapping.

**Tech Stack:** Dart/Flutter pub workspace (Flutter 3.47.6 locally);
`shadcn_ui ^0.57.1`, `lucide_icons_flutter`; `flutter_test`; `tool/ci`
(analyzer 13.3.0).

**Spec:** `docs/superpowers/specs/2026-10-23-plan-shadcn-chrome-design.md`
(rev 2, approved 2026-10-23). Read it whole before any task. Decisions are
cited as D1–D9, goals as G1–G6, review findings as A1–A18.

## Global Constraints

- CLAUDE.md non-negotiables: no per-entity allocation on the frame path
  (`query_allocation_test.dart`, `paint_allocation_test.dart` green); never
  commit `analysis_options.yaml` (`git status --short` before every
  commit); never synthesize output; English code, comments, commits;
  trailer `Co-Authored-By: <model> <noreply@anthropic.com>`.
- Never merge, push, tag or publish. `dart pub publish --dry-run` only.
- **Do not touch** the canvas (`lib/src/canvas/**`), `tools/move_resolver.dart`,
  the snap, the service drag (`service/service_tool.dart`), or
  `jet_cad_2d_flutter`. The alignment-guides branch owns them.
- **No public signature change** in `jet_cad_2d_plan`; no `Shad*` or
  `LucideIcons` type reachable from its barrel (Task 1's check).
- **Keys:** every existing `Key` keeps its value and its meaning. A key that
  sat on a Material widget sits on the chrome part that replaced it.
- **Words:** every visible word from `PlanStrings` or a kit's `PlanWords`;
  no `ShadInput` without the library's `contextMenuBuilder`; no
  `keyboardToolbarBuilder`; no `ShadSelect.withSearch`; no date/time picker.
- **Canvas-owned reads stay Material** (spec "Canvas-owned reads"):
  `PlanLayerPanel._foreground`, the service view's canvas background /
  paper / brightness reads, every `PlanTheme` read.
- **Rulings:** a test changes only under a ruling in
  `.superpowers/sdd/2026-10-23-plan-shadcn-chrome/rulings.md`: mapping,
  every test touched (file:line), how the new finder checks the same
  thing, anchored to the same key. Never drop an assertion.
- **Self-review per task** (the human's rule: no reviewer subagents): the
  controller reads the diff, runs the task's named mutation itself and
  re-runs the gates.
- **A task ends green:** in every package it touched, its tests, analyze
  and `dart format --output=none --set-exit-if-changed .`; plus
  `packages/jet_cad_2d_integration` (`flutter test`) for any plan-library
  change; plus `cd tool/ci && dart test`.
- Versions are not bumped; CHANGELOG lines go under `## Unreleased`.

## Review Focus

1. **The host flips light/dark while a select or menu is open** (monepro's
   theme toggle): the open overlay and the chrome take the new theme, no
   exception. → Task 2 test `SC6`, Task 3 test `CP9`.
2. **A Material 2 host** (`useMaterial3: false`, or a hand-built
   `ColorScheme` with default container tokens): the derived theme has
   readable foreground on every surface. → Task 2 test `SC7`.
3. **Keyboard only:** Tab reaches every bar and panel control, Enter/Space
   activates an icon button, a menu opens from the keyboard and Escape
   closes it with the focus back on its trigger. → Task 3 tests `CP6`, `CP7`.
4. **Large text** (`TextScaler.linear(1.5)` and `2.0`): the editor bar and
   the panels at 375, 800 and 1280 px do not overflow. → Task 5 test `ED6`.
5. **Phone width:** a select or menu opened inside a phone drawer (375 px)
   lays out fully on screen. → Task 6 test `PP7`.

---

### Task 1: Dependencies and the API boundary check

**Files:**
- Modify: `packages/jet_cad_2d_plan/pubspec.yaml` (add `shadcn_ui: ^0.57.1`,
  `lucide_icons_flutter: ^3.1.25`; `environment.sdk: ^3.11.0`)
- Modify: `apps/dev_harness/pubspec.yaml` (`shadcn_ui: ^0.57.1`,
  `sdk: ^3.11.0`, `flutter: ">=3.41.0"`), and its `lib/` if 0.56/0.57
  broke anything
- Create: `tool/ci/lib/api_boundary.dart`, `tool/ci/check_api_boundary.dart`
- Test: `tool/ci/test/api_boundary_test.dart`
- Modify: `.github/workflows/ci.yml` (run `dart run tool/ci/check_api_boundary.dart` beside `check_guide.dart`)

**Interfaces:**
- Produces: `List<String> apiBoundaryProblems(LibraryElement barrel, {Set<String> forbiddenPackages = const {'shadcn_ui', 'lucide_icons_flutter'}})`
  — one problem per exported element whose public member type, parameter,
  return type, type argument, bound or supertype (transitively through
  exported types only) is declared in a forbidden package; the problem
  names the element, the member and the type. Resolved the way
  `tool/ci/lib/guide.dart` resolves (read it first).

- [ ] **Step 1: Resolve the workspace.** `flutter pub get` at the root; it
  must resolve `shadcn_ui 0.57.1` with no override. If `intl` or another
  transitive pin conflicts, report it to the controller; do not override.
- [ ] **Step 2: Write failing tests** in `api_boundary_test.dart`:
  `AB1 a clean barrel has no problems` (a fixture package in a temp dir
  exporting a class with `Widget`/`IconData` members → `[]`);
  `AB2 a Shad-typed public field is a problem` (fixture with
  `final ShadThemeData theme;` → one problem naming the field);
  `AB3 a Shad supertype is a problem`; `AB4 a Shad type argument in a
  return type is a problem` (`List<ShadOption> f()`); `AB5 a private member
  is not`; `AB6 the real jet_cad_2d_plan barrel is clean`.
- [ ] **Step 3: Run** `cd tool/ci && dart test test/api_boundary_test.dart` → AB1–AB5 FAIL (no function).
- [ ] **Step 4: Implement** `apiBoundaryProblems` and the CLI (exit 1 with the problems listed).
- [ ] **Step 5: Run** the test → PASS; `dart run tool/ci/check_api_boundary.dart` → prints no problem, exit 0.
- [ ] **Step 6: Mutation** M-AB: add `final ShadThemeData? shad = null;` to
  `PlanEditor` → the CLI and AB6 go red; revert.
- [ ] **Step 7: dev_harness green:** `cd apps/dev_harness && flutter analyze && flutter test`.
- [ ] **Step 8: All gates** (Global Constraints) and `dart run tool/ci/check_host_lock.dart` on the probe as CI does; commit
  `build(plan): shadcn_ui ^0.57.1 and the API boundary check`.

### Task 2: The scope

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/chrome/shad_scope.dart`, `lib/src/chrome/host_slot.dart`
- Modify: the root `build` of `PlanEditor`, `PlanToolPalette`,
  `PlanSymbolGallery`, `PlanPropertyPanel`, `PlanLayerPanel`,
  `PlanPagePanel`, `PlanServiceView` (wrap in `PlanShadScope`); wrap every
  host slot in `PlanHostSlot` (editor bar and service bar `leading` /
  `trailing`, `inspectorBuilder`/`unitInspectorBuilder` output,
  `contextualPanels`, the service view's side panel, `unitOverlayBuilder`
  output)
- Test: `packages/jet_cad_2d_plan/test/chrome/shad_scope_test.dart`, `test/chrome/host_slot_test.dart`

**Interfaces:**
- Produces:
  - `ShadThemeData planShadThemeFrom(ThemeData theme)` — the spec's
    mapping table, brightness from `theme.brightness`, text theme family
    from `theme.textTheme.bodyMedium?.fontFamily`.
  - `ShadThemeData planShadThemeOf(BuildContext context)` — the ancestor
    `ShadTheme`'s data, else `planShadThemeFrom(Theme.of(context))`
    (memoised per `ThemeData` identity).
  - `class PlanShadScope extends StatelessWidget { const PlanShadScope({super.key, required Widget child, ShadThemeData? data}); }`
    — `data` given (routes) → provides it; else ancestor `ShadTheme` →
    passes through; else provides the derived data plus
    `ShadMouseAreaSurface` and `ShadMouseCursorProvider` (check
    `shadcn_ui-0.57.1/lib/src/app.dart`). In every case installs
    `DefaultTextStyle` (`theme.textTheme.p` with `colorScheme.foreground`)
    and `IconTheme` (`colorScheme.foreground`, size 16).
  - `class PlanHostSlot extends StatelessWidget { const PlanHostSlot({super.key, required Widget child}); }`
    — `Material(type: MaterialType.transparency, child: child)`.

- [ ] **Step 1: Write failing tests** (`shad_scope_test.dart`):
  `SC1 under a bare MaterialApp a scope provides a ShadTheme whose
  background is the ColorScheme's surface and foreground its onSurface`
  (use a hand-built scheme with distinct, non-default colours);
  `SC2 under an ancestor ShadTheme the scope's descendants read that
  ShadTheme's colours` (distinct primary `0xFF123456`);
  `SC3 dark ThemeData → derived brightness dark`;
  `SC4 a plain Text below the scope takes the ShadTheme's font family and
  foreground` (host ShadTheme with family `'ScopeTestFont'`);
  `SC5 an Icon below the scope takes the foreground`;
  `SC6 switching the ancestor ShadTheme light→dark rebuilds descendants
  with the dark colours, no exception`;
  `SC7 a useMaterial3:false ThemeData and a ColorScheme built with only
  the required fields derive a theme where foreground/background and
  primaryForeground/primary contrast ratio ≥ 4.5`;
  `SC8 the derived data is computed once for one ThemeData across two
  rebuilds` (count through a test hook `@visibleForTesting int debugPlanShadDerivations`).
  `host_slot_test.dart`: `HS1 a Material TextField and an InkWell in each
  host slot of PlanEditor and of a standalone PlanServiceView build under
  a bare MaterialApp and respond to a tap` (one case per slot listed in
  Files).
- [ ] **Step 2: Run** `flutter test test/chrome` → FAIL.
- [ ] **Step 3: Implement** both files and the wrapping.
- [ ] **Step 4: Run** `flutter test test/chrome` → PASS; the whole suite → green (a failure from `DefaultTextStyle` alone is a ruling "default text style", recorded, not an assertion change).
- [ ] **Step 5: Mutations** M-SC1 the scope always derives (SC2 red);
  M-SC2 never derives (SC1 red: no ShadTheme); M-SC3 no `DefaultTextStyle`
  (SC4 red); M-HS drop `PlanHostSlot`'s `Material` (HS1 red). Revert each.
- [ ] **Step 6: Gates; commit** `feat(plan): the shadcn scope and host slots`.

### Task 3: The chrome parts

**Files:**
- Create under `packages/jet_cad_2d_plan/lib/src/chrome/`:
  `words_carrier.dart`, `icon_button.dart`, `text_field.dart`,
  `select.dart`, `segmented.dart`, `menu_button.dart`, `rows.dart`
- Test: `test/chrome/parts_test.dart`, `test/l10n/shadcn_words_test.dart`

**Interfaces:**
- Consumes: `PlanShadScope` (Task 2).
- Produces (all internal, none exported):
  - `abstract interface class PlanWordsCarrier { Iterable<String> get visibleWords; }`
    — implemented by every part below; returns every string the part can
    put on screen (label, tooltip, placeholder, error, suffix, every menu
    or option label), open or closed.
  - `PlanIconButton({Key? key, required IconData icon, required String label, VoidCallback? onPressed, bool? selected, String? tooltip})`
    — `ShadIconButton.ghost` in a `ShadTooltip` showing `tooltip ?? label`;
    `Semantics(button: true, label: label, selected: selected, enabled: onPressed != null)`;
    `selected == true` draws the secondary variant. `key` on the part.
  - `PlanTextField({Key? key, required TextEditingController controller, FocusNode? focusNode, String? label, String? suffix, String? errorText, String? placeholder, bool readOnly = false, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, VoidCallback? onEditingComplete, TapRegionCallback? onTapOutside})`
    — label above, `ShadInput` (`groupId: EditableText`,
    `contextMenuBuilder:` the library's adaptive toolbar,
    `keyboardToolbarBuilder` null, `onPressedOutside: onTapOutside`),
    suffix as trailing, error below in `destructive`. **Read-only keeps
    today's `TextField(readOnly: true)` behaviour** (focusable, text
    selectable and copyable, not editable): builder's technique, pinned by
    CP3.
  - `PlanReadOnlyField({Key? key, required String label, required Widget child})` — the `InputDecorator` replacement.
  - `PlanSelect<T>({Key? key, required T? value, required List<PlanOption<T>> options, required ValueChanged<T> onChanged, bool enabled = true, String? label, String? placeholder})`
    and `PlanOption<T>(T value, String label)` — `ShadSelect<T>` driven by
    a private `ShadSelectController<T>`; after `onChanged` returns, and on
    every `didUpdateWidget`, the controller is set back to `value` (the
    model is the authority).
  - `PlanSegmented<T>({Key? key, required T value, required List<PlanSegment<T>> segments, required ValueChanged<T> onChanged, bool enabled = true})`
    and `PlanSegment<T>(T value, String label, {IconData? icon, Key? key})` —
    toggled `ShadButton`s (secondary when selected), each with
    `Semantics(selected:)`; same authority rule. Segment keys go on the
    segment buttons.
  - `PlanMenuButton<T>({Key? key, required IconData icon, required String label, required List<PlanMenuEntry<T>> Function() entries, required ValueChanged<T> onSelected, T? selected})`
    and `PlanMenuEntry<T>(T value, String label, {bool enabled = true, Key? key})` —
    a `PlanIconButton` trigger opening a `ShadContextMenu` through a
    `ShadContextMenuController` on primary click, tap, Enter or Space, on
    every platform; `entries()` is re-read on every build while open (live
    permissions); Escape and outside tap close it and return the focus to
    the trigger; the `selected` entry is marked.
  - `PlanCheckRow({Key? key, required String label, required bool value, ValueChanged<bool>? onChanged})`,
    `PlanSwitchRow(...)` same shape, `PlanListRow({Key? key, required Widget title, Widget? leading, bool selected = false, VoidCallback? onTap})`
    — focusable, `Semantics(button:, selected:)`, Enter/Space activate.
  - `Widget planTextContextMenu(BuildContext context, EditableTextState state)`
    — `AdaptiveTextSelectionToolbar.editableText(editableTextState: state)`.

- [ ] **Step 1: Write failing tests** (`parts_test.dart`, each part mounted under a bare `MaterialApp` in a `PlanShadScope`):
  `CP1 two PlanTextFields: tapping the second does not call the first's onTapOutside`;
  `CP2 tapping outside both calls it once`;
  `CP3 a readOnly field: focusable, its text selectable and copyable
  (Clipboard holds the selection), typing changes nothing; set readOnly
  while focused → stays focused; back to editable → typing edits`;
  `CP4 a PlanSelect whose onChanged refuses (does not change value) shows
  the old option's label after the pick`;
  `CP5 a PlanSelect rebuilt with a new value shows it` (undo/replace case);
  `CP6 PlanMenuButton opens on a primary mouse click on desktop
  (debugDefaultTargetPlatformOverride = macOS) and on a tap on Android;
  Enter on the focused trigger opens it; Escape closes it and the trigger
  has focus`;
  `CP7 Tab moves focus across a row of three PlanIconButtons; Space
  activates the focused one`;
  `CP8 an entry disabled by entries() while the menu is open becomes
  disabled without reopening`;
  `CP9 flipping the ancestor ShadTheme to dark with the select open: no
  exception, the open popover's background is the dark one`;
  `CP10 PlanIconButton(selected: true) exposes a selected semantics node
  labelled label; selected: false does not`;
  `CP11 every part's visibleWords lists its label, tooltip, placeholder,
  error and every entry/option label`.
  (`shadcn_words_test.dart`): `SW1 every ShadInput( in lib/ is inside
  lib/src/chrome/text_field.dart`; `SW2 text_field.dart passes
  contextMenuBuilder and no keyboardToolbarBuilder`; `SW3 no
  withSearch, ShadDatePicker, ShadTimePicker, ShadCalendar in lib/`;
  `SW4 every shadcn identifier used in lib/ is in kAllowedShad` (a const
  list in the test; an unused entry is red too, as `theme_colours_test`
  does).
- [ ] **Step 2: Run** `flutter test test/chrome/parts_test.dart test/l10n/shadcn_words_test.dart` → FAIL.
- [ ] **Step 3: Implement** the parts.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Mutations** M-CP1 drop `groupId` (CP1 red); M-CP4 no
  controller reset (CP4 red); M-CP6 use `ShadContextMenuRegion` (CP6 red on
  macOS); M-CP10 drop `selected:` from semantics (CP10 red); M-SW drop
  `contextMenuBuilder` (SW2 red). Revert each.
- [ ] **Step 6: Gates; commit** `feat(plan): the shadcn chrome parts`.

### Task 4: The leak collectors see the parts

**Files:**
- Modify: `packages/jet_cad_2d_plan/test/editor/editor_words_test.dart` (`visibleTexts`)
- Modify: `packages/jet_cad_2d_integration/test/l10n/leak_test.dart` (its collector), `test/l10n/panel_words_test.dart` if it collects
- Test: the same files

**Interfaces:**
- Consumes: `PlanWordsCarrier` (Task 3) through `package:jet_cad_2d_plan/src/chrome/words_carrier.dart` (tests may import `src`; check the integration package already does elsewhere, else add a `@visibleForTesting` re-export in an existing test-support barrel).

- [ ] **Step 1:** Extend each collector: today's `Text` and `Tooltip.message`, **plus** `visibleWords` of every widget that `is PlanWordsCarrier`. Every assertion and allowlist stays as it is.
- [ ] **Step 2:** Leak mutations (test-only fixtures, not lib): a
  `PlanIconButton(label: 'Raw')` mounted in the editor's bar `trailing`
  slot in a Turkish run → LK1 red; a `PlanMenuButton` entry `'Raw'` → red;
  a `PlanTextField(errorText: 'Raw')` → red. Keep them as tests
  `LK1x tooltip`, `LK1x menu entry`, `LK1x field error` (expect the leak
  to be reported).
- [ ] **Step 3:** Record ruling R-LK ("collectors extended, no assertion changed").
- [ ] **Step 4: Gates; commit** `test(plan): the leak collectors read the chrome parts`.

### Task 5: The editor, its bar and the tool palette

**Files:**
- Modify: `lib/src/editor/plan_editor.dart`, `plan_tool_palette.dart`, `editor_layout.dart`
- Test: the existing `test/editor/*`, `test/shortcuts/plan_shortcuts_test.dart`, integration `test/editor/*`, `test/phone/phone_design_test.dart`; new `test/editor/editor_chrome_test.dart`

**Interfaces:**
- Consumes: Tasks 2–3.

- [ ] **Step 1: Write failing tests** (`editor_chrome_test.dart`):
  `ED1 under a host ShadTheme (primary 0xFF123456) the bar's Undo is a
  PlanIconButton and the palette's selected tool button's background is
  the ShadTheme's secondary`;
  `ED2 the Tools/Symbols switch is a PlanSegmented whose segments keep
  today's keys`;
  `ED3 under a bare MaterialApp the bar's surface is the derived
  background`;
  `ED4 desktop, tablet (800) and phone (375) layouts still build with
  their docked columns and drawers` (the layout keys `editor_layout_test`
  uses);
  `ED5 the palette's selected tool exposes selected semantics`;
  `ED6 at TextScaler.linear(1.5) and 2.0, widths 375, 800 and 1280: no
  overflow error in the editor` (`tester.takeException()` is null).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Migrate:** every `IconButton` → `PlanIconButton`, the
  `SegmentedButton` → `PlanSegmented`, `Tooltip` → the part's tooltip,
  `ListTile`/`CheckboxListTile` → `PlanListRow`/`PlanCheckRow`, `Divider` →
  `ShadSeparator.horizontal`, surfaces from `ShadTheme.of(context)`,
  `Icons.*` → `LucideIcons.*` (record each pair in the icon ruling's
  table). `Scaffold` may stay (record the choice). Keys move onto the parts.
- [ ] **Step 4: Run** the package and integration suites; rewrite failing
  finders under rulings (`IconButton → PlanIconButton`, `SegmentedButton →
  PlanSegmented`, `Tooltip → PlanIconButton.tooltip/semantics`, `ListTile →
  PlanListRow`, icons). Each rewritten finder anchors on the same key.
- [ ] **Step 5: Mutation** M-ED1: the palette reads `Theme.of(context).colorScheme.secondaryContainer` for the selected tool → ED1 red. Revert.
- [ ] **Step 6: Gates (plan, integration, tool/ci); commit** `feat(plan): the editor's chrome in shadcn`.

### Task 6: The property panel

**Files:**
- Modify: `lib/src/panels/plan_property_panel.dart`, `symbol_section.dart`, `unit_section.dart` (if they read Material)
- Test: `test/panels/property_panel_test.dart`, `selection_*_test.dart`, `symbol_section_test.dart`, `unit_section_test.dart`, `object_view_panel_test.dart`, integration `test/{room,opening,dimension,panels}/*`; new `test/panels/property_chrome_test.dart`

- [ ] **Step 1: Write failing tests** (`property_chrome_test.dart`):
  `PP1 a numeric property field is a PlanTextField with today's key, label
  and suffix`;
  `PP2 a field locked by permissions while focused stays focused,
  selectable, uneditable; unlocked again it edits` (the spec's read-only
  case on the real panel);
  `PP3 a choice property whose write is refused shows the model's value
  after the pick`; `PP4 undo after a choice change shows the old choice`;
  `PP5 read-only displays (value, text, symbol metadata, capacity) are
  PlanReadOnlyField with today's labels`;
  `PP6 a boolean property is a PlanSwitchRow`;
  `PP7 at 375 px in the phone drawer a PlanSelect's popover lies fully
  inside the screen`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Migrate** (`TextField` →
  `PlanTextField` keeping `readOnly: !editable`, focus node, commit and
  hand-back callbacks; `DropdownButton` → `PlanSelect`; `InputDecorator` →
  `PlanReadOnlyField`; `SwitchListTile` → `PlanSwitchRow`; buttons →
  `ShadButton` variants; headings from the shadcn text theme).
- [ ] **Step 4: Run; rulings** (`TextField → PlanTextField` with
  `decoration.labelText/errorText/suffixText → label/errorText/suffix`;
  `DropdownButton → PlanSelect` with `.value`; `InputDecorator →
  PlanReadOnlyField`).
- [ ] **Step 5: Mutation** M-PP3: `PlanSelect` forwards without reset in this panel only (bypass the part) → PP3 red. Revert.
- [ ] **Step 6: Gates; commit** `feat(plan): the property panel in shadcn`.

### Task 7: The page panel, the layer panel and their rows

**Files:**
- Modify: `lib/src/panels/plan_page_panel.dart`, `plan_layer_panel.dart`, `layer_row.dart`, `layer_picker.dart`, `colour_row.dart`
- Test: `test/panels/{page_panel,page_panel_theme,page_scale_field,orientation_row,layer_panel,layer_picker,layer_page_controller,colour_row,hover_removal}_test.dart`, `test/l10n/layer_page_words_test.dart`, integration `test/{layers,panels}/*`; new `test/panels/layer_page_chrome_test.dart`

- [ ] **Step 1: Write failing tests** (`layer_page_chrome_test.dart`):
  `LP1 clicking the page panel's scale field then a Selection panel field
  does not commit the scale` (today's documented rule, `plan_page_panel.dart:154`);
  `LP2 the layer row's menu opens on a click on desktop, its entries
  follow a permission change while open`;
  `LP3 the layer picker marks the current layer`;
  `LP4 a blocked colour swatch's semantics label is the colour's name and
  its tooltip the blocked reason`;
  `LP5 PlanLayerPanel's swatch ink still follows Theme.of(context)'s
  surface/brightness when a ShadTheme of the other brightness is above
  it` (canvas-owned read);
  `LP6 the custom paper size shows as today's choice label and refusing a
  size keeps the model's`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Migrate** (`SegmentedButton` ×2
  → `PlanSegmented`; `DropdownButton` ×3 → `PlanSelect` with the custom
  size as an explicit option or placeholder, recorded; `CheckboxListTile`
  ×3 → `PlanCheckRow`; `ListTile`; `PopupMenuButton` → `PlanMenuButton`;
  `InkWell` rows → `PlanListRow`; `Scrollbar` kept, themed; `Tooltip` →
  parts; `colour_row`'s `Tooltip`/`Semantics`/`InkWell` → a focusable
  swatch keeping its `Semantics` and key `color-swatch-<key>`).
- [ ] **Step 4: Run; rulings** (`PopupMenuButton → PlanMenuButton`,
  `CheckboxListTile → PlanCheckRow`, `page_panel_theme_test`'s token reads
  → the shadcn surface, `byTooltip` → semantics label with
  `tester.ensureSemantics()`).
- [ ] **Step 5: Mutations** M-LP1 the scale field drops `groupId` (bypass) → LP1 red; M-LP5 `_foreground` reads `ShadTheme` → LP5 red. Revert.
- [ ] **Step 6: Gates; commit** `feat(plan): the page and layer panels in shadcn`.

### Task 8: The library's own symbol gallery

**Files:**
- Create: `lib/src/panels/gallery_grid.dart` (the shadcn gallery body)
- Modify: `lib/src/panels/plan_symbol_gallery.dart` (stop using `SymbolGallery`/`GalleryCategory`/`GallerySymbol`)
- Test: `test/panels/plan_symbol_gallery_test.dart`, `test/editor/{plan_editor,editor_layout}_test.dart`, `test/host/host_kit_test.dart`, `test/example_test.dart`, integration `test/l10n/{leak,determinism}_test.dart`, `apps/architecture_demo/test/library_gaps_test.dart`, `tool/screenshots/test/plan_scenes_test.dart`; new `test/panels/gallery_grid_test.dart`

**Interfaces:**
- Produces: `class PlanGalleryGrid extends StatefulWidget` (internal) —
  `PlanGalleryGrid({required List<PlanGalleryGroup> groups, required String? selectedId, required bool enabled, required ValueChanged<String> onSelect, required SymbolThumbnails thumbnails})`;
  `PlanGalleryGroup(String id, String name, List<PlanGalleryCell> cells)`;
  `PlanGalleryCell(String id, String label, Object thumbnailKey, DraftDocument Function() thumbnailDocument)`.
  Headers keyed `symbol-group-<id>`, cells `symbol-cell-<id>`.

- [ ] **Step 1: Write failing tests** (`gallery_grid_test.dart`):
  `GG1 a header tap collapses and expands its group; collapse survives a
  rebuild with new groups of the same ids`;
  `GG2 cells are built lazily: with 500 symbols only the visible cells
  build` (count builds);
  `GG3 thumbnails come from the given SymbolThumbnails (the controller's)
  and no other cache is created`;
  `GG4 the selected cell exposes selected semantics; enabled:false → taps
  ignored`;
  `GG5 the search field is a PlanTextField; the loading state shows a
  progress indicator from the scope's colours; no-match shows today's
  words`.
  Read the renderer's `packages/jet_cad_2d_flutter/lib/src/symbol_gallery.dart` for the behaviour to keep (do not modify it).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** and wire into `PlanSymbolGallery` (public signature unchanged).
- [ ] **Step 4: Run; ruling** R-GAL (`SymbolGallery`/`GalleryCategory` finders → `PlanGalleryGrid`/`PlanGalleryGroup`, same keys).
- [ ] **Step 5: Mutation** M-GG1 collapse state keyed by index instead of id → GG1 red. Revert.
- [ ] **Step 6: Gates (plan, integration, architecture_demo, tool/screenshots `flutter test`); commit** `feat(plan): the library's own shadcn symbol gallery`.

### Task 9: The service view and its bar

**Files:**
- Modify: `lib/src/service/view/plan_service_view.dart` (and `unit_groups_toolbar` sources if they read Material)
- Test: `test/service/view/{service_bar,unit_groups_toolbar,service_keys}_test.dart`, `test/editor/editor_service_view_test.dart`, `test/theme/theme_service_mode_test.dart`; new `test/service/view/service_chrome_test.dart`

- [ ] **Step 1: Write failing tests:** `SV1 the service bar's buttons are
  PlanIconButtons with today's keys under a host ShadTheme`;
  `SV2 PlanTheme.serviceBarHeight still sizes the bar`;
  `SV3 the canvas background, paper and brightness still come from
  ThemeData/PlanTheme when the ShadTheme's brightness differs`;
  `SV4 a standalone PlanServiceView under a bare MaterialApp builds, light
  and dark`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Migrate** (split mixed reads into
  a canvas variable and a chrome variable; record each kept read with its
  reason for the results note).
- [ ] **Step 4: Run; rulings.** **Step 5: Mutation** M-SV3 the canvas background reads `ShadTheme` → SV3 red. Revert.
- [ ] **Step 6: Gates; commit** `feat(plan): the service view's chrome in shadcn`.

### Task 10: The export dialog

**Files:**
- Modify: `lib/src/export/export_dialog.dart` (and `editor_page_flows.dart` only if it builds chrome)
- Test: `test/export/{export_dialog,page_flows}_test.dart`, `test/support/flows_bar.dart`, `apps/architecture_demo/test/support/export_rig.dart` users; new `test/export/export_dialog_chrome_test.dart`

**Interfaces:**
- Consumes: `planShadThemeOf`, `PlanShadScope(data:)`.
- Keeps: `showPlanExportDialog(BuildContext, PlanExportAnswer, List<PlanExporter>)` and `typedef PlanExportDialog` unchanged.

- [ ] **Step 1: Write failing tests:** `EX1 showPlanExportDialog called
  directly under a bare MaterialApp (no editor) opens, light and dark`;
  `EX2 called from inside a local Theme with a distinct ColorScheme, the
  dialog's card is that scheme's derived card colour`;
  `EX3 called under a host ShadTheme, the dialog uses it`;
  `EX4 the dialog's words come from the caller's PlanStrings (Turkish)`;
  `EX5 Escape and the barrier dismiss it with null; the primary button
  returns the answer`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement:** resolve
  `planShadThemeOf(context)`, the `PlanStrings` and `PlanTheme` at the call
  site; push `ShadDialogRoute` (exported at 0.57.1) or `RawDialogRoute`
  whose page is `PlanShadScope(data: resolved, child: <the captured
  scopes>(ShadDialog(...)))`; `SegmentedButton` ×2 → `PlanSegmented`;
  buttons → `ShadButton`.
- [ ] **Step 4: Run; rulings** (`AlertDialog → ShadDialog`). **Step 5: Mutation** M-EX call `showShadDialog(context: context, ...)` → EX1 red. Revert.
- [ ] **Step 6: Gates (plan, integration, both demos); commit** `feat(plan): the export dialog in shadcn`.

### Task 11: The architecture kit's icons and the kept-Material scan

**Files:**
- Modify: `packages/jet_cad_2d_kit_architecture/pubspec.yaml` (`lucide_icons_flutter: ^3.1.25`), its 6 files with `Icons.*`, `CHANGELOG.md`
- Create: `packages/jet_cad_2d_plan/test/invariants/kept_material_test.dart`
- Test: kit tests, integration `test/editor/architecture_palette_test.dart`

- [ ] **Step 1:** Kit icons → `LucideIcons.*` (pairs in the icon ruling);
  `grep -rn "Icons\." packages/jet_cad_2d_kit_restaurant/lib` must print
  nothing (record it). `dart run tool/ci/check_kit_deps.dart` green.
- [ ] **Step 2: Write** `KM1`: scan `jet_cad_2d_plan/lib` for every Material
  widget constructor and `Theme.of(` use; each hit must match
  `kKeptMaterial`, a const list of (file, exact construct, reason) in the
  test (the canvas files, `PlanTheme`, `PlanHostSlot`'s `Material`,
  `Scaffold` if kept, `Scrollbar`, each canvas-owned `Theme.of` read); an
  unused entry is red too. `KM2`: `grep Icons\.` in `jet_cad_2d_plan/lib`
  finds nothing.
- [ ] **Step 3: Run** → PASS (it describes the end state). **Mutation** M-KM add an `IconButton` to `plan_layer_panel.dart` → KM1 red. Revert.
- [ ] **Step 4: Gates (kit, plan, integration, tool/ci); commit** `feat(kit_architecture): Lucide icons; test(plan): the kept-Material scan`.

### Task 12: The demos

**Files:**
- Modify: `apps/restaurant_demo/lib/demo_theme.dart`, `lib/main.dart`, `pubspec.yaml` (`shadcn_ui: ^0.57.1`), its tests (`look_test`, `host_chrome_test`, `editor_profiles_test`, `statuses_test`, `zones_test`, `support/demo_rig.dart`, `invariants/theme_colours_test.dart`'s allowlist)
- Modify: `apps/architecture_demo/test/*` that found Material types inside the planner

- [ ] **Step 1:** `demo_theme.dart`: remove `posColorScheme`, `posViewTheme`;
  add `ShadThemeData posShadTheme(Brightness)` from shadcn's zinc palette
  (`ShadZincColorScheme.light()/.dark()`); under `DemoLook.pos` wrap the
  view in `ShadTheme(data: posShadTheme(brightness))`. Keep `posPlanTheme`,
  `kPosPlanLight`, `kPosPlanDark`, `kPosViewOverride`.
- [ ] **Step 2: Tests:** `look_test` and `host_chrome_test` observe the
  `ShadTheme` around the view (ruling R-LOOK); add `DL-S1 under
  DemoLook.pos the bar's surface is zinc's background, under standard the
  derived one`. Mutation M-DL drop the wrap → DL-S1 red.
- [ ] **Step 3:** Run both demos' tests; run each demo
  (`flutter run -d macos`) light and dark, at phone, tablet and desktop
  widths; screenshot each state into the ledger folder and look at them.
- [ ] **Step 4: Gates (both demos, integration); commit** `feat(restaurant_demo): the POS look is a ShadTheme`.

### Task 13: Host guide, CHANGELOGs, screenshots

**Files:**
- Modify: `docs/host-guide.md` §10 (+ the migration note and the
  `shadcn_ui ^0.57.1` line), `packages/jet_cad_2d_plan/CHANGELOG.md`,
  `packages/jet_cad_2d_kit_architecture/CHANGELOG.md` (if Task 11 did not),
  root `CHANGELOG.md` index, the PNGs under `packages/*/doc/screenshots/`
  that show chrome

- [ ] **Step 1:** Rewrite §10 per the spec "The host guide"; every Dart block
  in the guide still analyses: `dart run tool/ci/check_guide.dart` and the
  host probe build as CI runs them → green.
- [ ] **Step 2:** CHANGELOG "Unreleased": the chrome is shadcn; `shadcn_ui
  ^0.57.1` and Dart `^3.11.0`; tests that found Material types inside the
  planner find the library's parts now, keys unchanged; Lucide icons.
- [ ] **Step 3:** `cd tool/screenshots && UPDATE_SCREENSHOTS=1 flutter test`
  (its README); look at each regenerated PNG;
  `dart run tool/ci/check_screenshots.dart` green; README links untouched.
- [ ] **Step 4: Gates (tool/ci, readme_probe); commit** `docs: the host guide, CHANGELOGs and screenshots for the shadcn chrome`.

### Task 14: Close

- [ ] **Step 1:** Every gate in every touched package (CLAUDE.md's three,
  `jet_cad_2d_kit_architecture`, `jet_cad_2d_integration`, both demos,
  `apps/dev_harness`, `tool/ci`, `tool/screenshots`, `tool/readme_probe`),
  `dart pub publish --dry-run` in `jet_cad_2d_plan` and the architecture
  kit (0 warnings). Paste real last lines.
- [ ] **Step 2:** Results note
  `docs/superpowers/notes/2026-10-23-plan-shadcn-chrome-results.md`: every
  ruling with its tests, the icon table, the kept-Material allowlist with
  reasons, every mutation (name, the test that went red, reverted), the
  gates' last lines, what was not done.
- [ ] **Step 3:** Archive the ledger to
  `docs/superpowers/ledgers/2026-10-23-plan-shadcn-chrome/`; STATUS.md "In
  flight" entry; commit `docs: results and ledger of the shadcn chrome`.
- [ ] **Step 4:** Report to the human (Turkish, terse): commits, gates,
  rulings count, open points, and that monepro must move to
  `shadcn_ui ^0.57.1`.
