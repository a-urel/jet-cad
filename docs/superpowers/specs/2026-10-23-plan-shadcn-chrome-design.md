# The plan library's chrome in shadcn

**Date:** 2026-10-23. **Status:** rev 2, for the human's approval. Rev 1
was reviewed by OpenCode (GPT-6.1-sol, the human's request); its 18
findings are folded in (Appendix A), and the human decided the two that
were theirs: the gallery (decision 9) and the version floor (decision 8).
**Packages:** `jet_cad_2d_plan` (0.9.0 on pub.dev),
`jet_cad_2d_kit_architecture` (0.1.1), `jet_cad_2d_kit_restaurant` (0.1.0);
`packages/jet_cad_2d_integration`, `apps/restaurant_demo`,
`apps/architecture_demo`, `apps/dev_harness`, `docs/host-guide.md`,
`tool/screenshots`, `tool/ci`. **Not** `jet_cad_2d_flutter`.

## Intent

monepro, the first real host, is a shadcn application: `ShadApp.custom` with
a `MaterialApp.router` inside (`monepro-frontend/lib/app.dart`). The plan
editor's chrome is Material today, and inside monepro the two design
systems stand side by side and look wrong (the human, 2026-10-23: *"monepro'da
Material ile shadcn yan yana göze batıyor"*). This sub-project moves the plan
library's chrome to `shadcn_ui`, so the editor looks like the app it is
mounted in, before 1.0 freezes the API.

jet-cad still knows nothing about monepro. Every host keeps working with no
change: a host that provides no `ShadTheme` (the architecture demo, any
plain `MaterialApp`) gets a shadcn chrome coloured from its own Material
`ColorScheme`.

## Goals

- **G1 — The chrome is shadcn.** The editor bar, the tool palette, the
  symbol gallery, the property, layer and page panels, the service bar, the
  menus and the export dialog (the library's only dialog today) are built
  from `shadcn_ui` components, with shadcn typography and foregrounds.
- **G2 — The host's shadcn theme wins.** When an ancestor `ShadTheme`
  exists, the chrome uses it as is (colours, radius, text, brightness).
- **G3 — No host has to wrap anything.** When no `ShadTheme` exists, the
  library supplies its own, derived from the ambient Material `ThemeData`.
  A plain Material host keeps working, light and dark, including every
  public entry point used on its own (`showPlanExportDialog` called from a
  bare `MaterialApp`, a standalone `PlanServiceView`).
- **G4 — Lucide icons.** The library's own icons and the architecture
  kit's tool icons are `LucideIcons`. The API stays `IconData`: a kit may
  still give any icon.
- **G5 — Behaviour unchanged.** Every existing behaviour test stays green.
  A test changes only under a named ruling (Test rulings below); a ruling
  never drops an assertion and never makes a finder vaguer than what it
  checked.
- **G6 — Words unchanged.** Every visible word still comes from
  `PlanStrings` (or a kit's `PlanWords`); no shadcn built-in string reaches
  the screen. The leak tests keep every assertion and every allowlist;
  their collectors are extended to see shadcn content (same or stronger
  coverage).

## Non-goals

- **The canvas.** Canvas painting, the snap and the move logic belong to the
  alignment-guides session running in parallel; this work does not touch
  them. `PlanCanvas`, `plan_canvas_view.dart` and the in-canvas text entry
  (`text_entry_overlay.dart`, a field that mimics the text it edits) stay
  as they are.
- **The renderer.** `jet_cad_2d_flutter` (its `SymbolGallery` included)
  is not changed and gets no release (decision 9).
- **`PlanTheme`'s fields.** No field is added, removed or reinterpreted.
- **The 1.0 release itself.** This lands under "Unreleased"; versions,
  tags and the README image links move with the release.
- **monepro's own integration**, including its move to `shadcn_ui
  ^0.57.1` (decision 8). It is the next sub-project.

## Anti-goals (it fails even if it works)

- A host has to wrap the editor in `ShadApp` or `ShadTheme` to see it
  right, or a plain Material host breaks or shows a broken chrome.
- A `Shad*` type is reachable from `jet_cad_2d_plan`'s public API (a
  parameter, a return type, a field, a supertype, an export).
- An English word from shadcn's own localizations ("Cut", "Copy", "Paste",
  "Select All", "Done") shows in a Turkish or German editor.
- A behaviour test is weakened to pass.
- A widget key changes or disappears.
- A host's own Material widget in a host slot (bar `leading`/`trailing`,
  an inspector, the service view's side panel, a unit overlay) loses its
  `Material` ancestor and throws or loses its ink.

## Decisions the human made

1. **Theme ownership (G2, G3).** The library looks for an ancestor
   `ShadTheme`; if found, it uses it; if not, it builds its own from the
   host's Material `ThemeData`. No wrapper is required of a host.
2. **`PlanTheme` stays.** It keeps being a `ThemeExtension` on `ThemeData`,
   overridden field by field by a view's `theme:`. Its fields are the
   canvas's look, except `serviceBarHeight`, which sizes the service bar
   and keeps doing so. `kPosViewOverride` in the restaurant demo stays.
3. **The restaurant demo's POS look.** Its hand-built Material
   `ColorScheme` around the view (`posViewTheme`, `posColorScheme`) goes;
   instead the demo wraps the editor in a `ShadTheme` from shadcn's zinc
   palette, which is what monepro does. `posPlanTheme` and
   `kPosViewOverride` stay.
4. **Dark mode.** With a host `ShadTheme`, the chrome follows its
   brightness. Without one, the derived theme follows the Material
   `ThemeData`'s brightness. The canvas keeps following the paper,
   `PlanTheme` and the Material `ThemeData` (see "Canvas-owned reads"). A
   host whose `ShadTheme` and `ThemeData` disagree in brightness gets a
   dark chrome over a light canvas (or the reverse); this is accepted.
5. **Keys stay.** Every existing `Key` keeps its value and its meaning (it
   still finds the control that does the same thing), including the
   renderer gallery's `symbol-group-<id>` and `symbol-cell-<id>`, which
   the library's own gallery now carries.
6. **Test rulings per mapping.** One ruling per mapping covers every use
   (Test rulings below).
7. **Lucide icons** in the library and the architecture kit (G4).
8. **Dependency: `shadcn_ui: ^0.57.1`** (the human chose the 0.57.1
   floor over 0.56.1 with mitigations). monepro moves from `^0.56.1` to
   `^0.57.1` in its own integration work. One version, so CI needs no
   second resolution.
9. **The gallery is the library's own** (the human chose this over hooks
   in the renderer): `PlanSymbolGallery` stops using the renderer's
   `SymbolGallery` and builds a shadcn gallery of its own, reusing the
   renderer's `SymbolThumbnails` for the pictures.

## Constraints

- **The frame path allocates nothing per entity in steady state.**
  `paint_allocation_test` and `query_allocation_test` stay green.
- **Never commit `analysis_options.yaml`.** **Never synthesize test output.**
- **The alignment-guides branch must merge cleanly.** Its touch points are
  the canvas, `tools/move_resolver.dart`, the service drag and possibly a
  toggle on the editor bar (`PlanEditorAction`). This work does not touch
  the first three. Whichever branch merges second rebases; a bar toggle
  then uses the bar's shadcn button.
- **Phone and tablet layouts** (`editor_layout.dart`, `PlanEditorLayout`,
  `PlanLayoutBreakpoints`, `PlanDrawerHost`) keep their breakpoints, their
  docked columns and their drawers. Only the look changes.
- **No public signature changes.** The host probe and the old-host probes
  for the released tags stay green.
- **README images pin per-package tags** (`tool/ci/check_screenshots.dart`).
  The PNGs are regenerated here; the links' tags move at release.
- **Every gate in CLAUDE.md** plus `packages/jet_cad_2d_integration`, both
  demos' tests, `apps/dev_harness`, `tool/ci` (`dart test`),
  `tool/screenshots` and `tool/readme_probe`.

## The design

### Dependency (decision 8)

`jet_cad_2d_plan` takes `shadcn_ui: ^0.57.1` and `lucide_icons_flutter`
(the range `shadcn_ui` 0.57.1 itself takes). `jet_cad_2d_kit_architecture`
takes `lucide_icons_flutter` only, never `shadcn_ui`. `apps/dev_harness`,
in the same pub workspace, moves from `^0.55.0` to `^0.57.1` and its
existing shadcn code (`harness_page.dart`, `status_bar.dart`, `main.dart`,
`ribbon/cad_ribbon.dart`) is fixed for whatever 0.56/0.57 changed; its
tests and analyze stay green. No `dependency_overrides`.

### The scope (G2, G3)

One internal widget, `PlanShadScope` here (the builder may name it),
resolves the chrome's theme:

- If `ShadTheme.maybeOf(context)` is non-null, it uses that data.
- Otherwise it provides a `ShadTheme` whose `ShadThemeData` is derived from
  `Theme.of(context)`, plus whatever else `ShadApp` puts above an app that
  shadcn's components need (at 0.57.1: `ShadMouseAreaSurface` and
  `ShadMouseCursorProvider`; the builder verifies the list in
  `shadcn_ui`'s `app.dart`).
- In both cases it installs a `DefaultTextStyle` and an `IconTheme` from
  the resolved shadcn theme (its text theme's body style and its
  `foreground`), because `ShadTheme` alone sets neither, so the chrome's
  plain `Text` and `Icon` take shadcn typography and foregrounds. Panel
  headings and read-outs that read `Theme.of(context).textTheme` today
  read the shadcn text theme.
- It keeps a transparent `Material` (type `MaterialType.transparency`)
  around every host slot (the editor bar's `leading`/`trailing`, the
  service bar's, inspectors and `contextualPanels`, the service view's
  side panel, unit overlays) and around the editor and service view
  bodies, so host Material widgets keep working (anti-goal). This is
  infrastructure, not look; `Scaffold` may stay for the same reason.

The derived data is computed when the `ThemeData` changes, never per build
of a descendant.

**The mapping from Material.** `background` ← `surface`, `foreground` ←
`onSurface`, `card`/`cardForeground` and `popover`/`popoverForeground` ←
`surfaceContainerLow`/`onSurface`, `primary`/`primaryForeground` ←
`primary`/`onPrimary`, `secondary`/`secondaryForeground` ←
`secondaryContainer`/`onSecondaryContainer`, `muted` ←
`surfaceContainerHighest`, `mutedForeground` ← `onSurfaceVariant`,
`accent`/`accentForeground` ← `surfaceContainerHigh`/`onSurface`,
`destructive`/`destructiveForeground` ← `error`/`onError`, `border` ←
`outlineVariant`, `input` ← `outline`, `ring` ← `primary`, `selection` ←
`primary` at low alpha. Brightness ← `ThemeData.brightness`. The text
theme takes the host's Material font family
(`textTheme.bodyMedium.fontFamily`), so a Material host does not show
shadcn's bundled Geist. (Builder's call: the container tokens may be tuned
while looking at both demos, light and dark.)

**Where it is applied.** At the root of every public widget a host may
mount on its own: `PlanEditor`, `PlanToolPalette`, `PlanSymbolGallery`,
`PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel`,
`PlanServiceView`; and inside every route the library pushes. Nested
scopes are cheap: an inner one finds the outer `ShadTheme`.

### Canvas-owned reads

Some `Theme.of(context)` reads outside the canvas files feed the canvas or
the paper, not the chrome, and **stay Material**: the layer panel's swatch
ink (`PlanLayerPanel._foreground`, from the surface and brightness, because
the swatch shows the layer's colour as the paper draws it), the service
view's canvas background, paper and brightness
(`plan_service_view.dart`'s reads that build the canvas), and every
`PlanTheme` read. The builder lists each kept read with its reason in the
results note. At a site that reads both, the canvas value and the chrome
value become two variables. A test sets a `ShadTheme` and a `ThemeData`
that disagree in brightness and surface, and checks the chrome took the
first and the canvas the second.

### The export dialog

`showPlanExportDialog(context, ...)` is public and may be called from a
bare `MaterialApp`. `showShadDialog` reads `ShadTheme.of(context)` **before**
it pushes, so it cannot be called with the host's context. The library
pushes its own route instead (a `RawDialogRoute`/`showGeneralDialog`, or
`ShadDialogRoute` if exported, builder's call) whose page is a
`PlanShadScope` with the theme data resolved at the call site (the host's
`ShadTheme` if any, else derived from the caller's `ThemeData`), together
with whatever the dialog already took from the caller (the `PlanStrings`
scope, `PlanTheme`), and a `ShadDialog` inside. A test calls
`showPlanExportDialog` directly under a bare `MaterialApp`, with no editor,
in light and dark, and under a local `Theme` and checks the dialog takes
the local colours.

**Overlays.** `ShadPopover`, `ShadSelect`, `ShadTooltip` and
`ShadContextMenu` render through `ShadPortal` from their own position, so
they inherit the scope; the builder confirms it with the same kind of test.

### Words (G6)

- No keyboard toolbar: `keyboardToolbarBuilder` stays null on every
  `ShadInput` (its "Done" never shows).
- Every `ShadInput` gets the library's `contextMenuBuilder`, building the
  platform's adaptive toolbar whose labels come from
  `MaterialLocalizations`, today's behaviour (the host provides Material's
  delegates, host guide §3). On web, `useBrowserContextMenu` stays as
  today's `TextField` (the browser's own menu, in the browser's language).
- No `ShadSelect` uses its search variant (it builds an internal
  `ShadInput` the library does not configure). If a search is needed
  later, it is a library-built input.
- No date or time picker is used.
- A new test (`test/l10n`) scans the library's sources: every `ShadInput`
  sets `contextMenuBuilder`, none sets `keyboardToolbarBuilder`, no
  `ShadSelect.withSearch` (or the search constructor at 0.57.1), and no
  shadcn component outside an allowlist the test carries; a named mutation
  (one `ShadInput` without the builder) turns it red.

`planLocalizationsDelegates` does not change.

### The component mapping

Each line is one test ruling when a test finds or reads that type.

| Today (Material) | shadcn | Where today |
|---|---|---|
| `IconButton` | `ShadIconButton` (ghost) | editor, palette, layer panel, layer row, gallery, service view |
| `TextButton`, `OutlinedButton`, `FilledButton` | `ShadButton.ghost` / `.outline` / default | property panel, gallery, export dialog |
| `TextField` (+ `InputDecoration` label, suffix, error) | `ShadInput` inside a labelled field (label above, suffix as trailing, error below), keys on the input | property panel, page panel, layer row, gallery search |
| `InputDecorator` (read-only displays: choice labels, value and text displays, symbol metadata, capacity) | a labelled read-only row from the same field parts | property panel |
| `DropdownButton` + `DropdownMenuItem` | `ShadSelect` + `ShadOption`, controlled (below) | property panel, page panel |
| `SegmentedButton` | `ShadTabs` or toggled `ShadButton`s (builder's call per site, one ruling per final choice), controlled (below) | editor's Tools/Symbols switch, page panel (×2), export dialog (×2) |
| `PopupMenuButton` + `PopupMenuItem` | `ShadContextMenu` driven by a controller, opened by a `ShadIconButton`'s primary click or tap (below) | layer picker, layer row |
| `Tooltip` | `ShadTooltip`, with semantics kept (below) | editor, layer panel, layer picker, colour row |
| `showDialog` + `AlertDialog` | the library's route + `ShadDialog` (above) | export dialog |
| `ListTile` | a row of shadcn parts with explicit selected semantics | palette, page panel |
| `CheckboxListTile`, `SwitchListTile` | `ShadCheckbox` / `ShadSwitch` with their label | palette, page panel (×3), property panel |
| `Divider` | `ShadSeparator` | palette |
| `Scrollbar` | `Scrollbar` kept, themed from the shadcn scope (no shadcn scrollbar exists) | layer panel |
| `CircularProgressIndicator` | `ShadProgress` (indeterminate) or a spinner from the scope's colours, builder's call | gallery loading |
| `InkWell` on a row | `ShadButton.ghost` / a focusable shadcn-hover row with `Semantics(button:)` and keyboard activation; never a bare `GestureDetector` | layer panel, layer row, colour row, page panel |
| `Material` as a surface | a `DecoratedBox` / `ShadCard` from the scope's colours; transparent `Material` kept where host slots need it | panels, editor, service view |
| `Theme.of(context)` in the chrome (colours, text) | `ShadTheme.of(context)` | every chrome site except the canvas-owned reads |

**Fields (`TextField` → `ShadInput`).**
- *Tap group.* Every `ShadInput` passes `groupId: EditableText` (the
  default group every `TextField` shares), so a click on another field is
  still not outside this one (`plan_page_panel.dart`'s documented rule)
  and the editor's toolbar, the canvas text entry and host fields stay in
  the same group. `onTapOutside` becomes `onPressedOutside`.
- *Read-only.* Today a property field the permissions lock is
  `readOnly`: it keeps its focus node, can be focused, and its text can be
  selected and copied. `ShadInput` turns `canRequestFocus` off and absorbs
  pointers when read-only. The library keeps today's behaviour (builder's
  call how: a wrapper that does not pass `readOnly` to `ShadInput` but
  refuses edits, or a read-only selectable display that swaps in);
  tests cover a permission change while a field is focused, focusing after
  it, copying, and going back to editable.

**Choices (`DropdownButton` → `ShadSelect`; segmented controls).** The
model is the authority. `ShadSelect` sets its own value before it calls
back; the library drives it through a private `ShadSelectController` (or
re-keys it) so that after every write attempt, refused or not, and after
undo, redo and a document replace, it shows the model's value. A null or
"custom" value (the page panel's custom size) is an explicit option or a
placeholder, builder's call, decided once and ruled. The same rule binds
the segmented-control replacement. No shadcn controller leaves the
library.

**Menus (`PopupMenuButton` → `ShadContextMenu`).** `ShadContextMenuRegion`
opens on a normal tap only on mobile, and `ShadContextMenuItem` needs a
`ShadContextMenu` ancestor, so the library uses a `ShadContextMenu` with a
`ShadContextMenuController`, opened by its trigger's primary click or tap
on every platform. Kept: keyboard activation of the trigger, Escape,
outside dismissal, the selected entry marked, focus back to the trigger,
and the live permission checks of an open menu (`layer_row.dart`'s and
`layer_picker.dart`'s).

**Semantics.** `ShadTooltip` adds no semantics and `ShadButton` reports no
selected state. Per control category the library sets: the accessible name
(today's tooltip text where the tooltip *was* the name; the stable label
where the tooltip explained a block, as the colour swatch does today:
label stays the colour's name, the blocked reason stays a tooltip), the
enabled state, the selected or toggled state (the palette's selected tool,
selected rows, swatches), and keyboard activation.

### The gallery (decision 9)

`PlanSymbolGallery` keeps its public signature (`controller`, `filter`,
`query`) and builds its own shadcn gallery in `jet_cad_2d_plan`: the search
`ShadInput`, collapsible category headers (keys `symbol-group-<id>`), cells
(keys `symbol-cell-<id>`) with the renderer's `SymbolThumbnails` pictures,
the selected cell marked (selected semantics), the loading and no-match
states. It keeps the renderer gallery's behaviour: collapse state per
category, lazily built cells, the thumbnail cache's ownership (the
controller's `thumbnails`), the selected id, `enabled`. The renderer's
`SymbolGallery` stays for its own users. Tests that found the renderer's
types inside the planner (`plan_symbol_gallery_test`, `plan_editor_test`,
`editor_layout_test`, `host_kit_test`, `example_test`, the integration's
`leak_test` and `determinism_test`, `apps/architecture_demo`'s
`library_gaps_test`, `tool/screenshots`' `plan_scenes_test`) follow under
one ruling.

### Icons (G4)

The library's 44 `Icons.*` become `LucideIcons.*`; the architecture
kit's 8 the same. `jet_cad_2d_kit_restaurant` has none and is not changed
(the builder confirms with a grep). `PlanTool.icon` stays `IconData`. One
ruling covers every `find.byIcon`, with the full old→new table.

### Test rulings

A ruling names the mapping, lists every test it touches, and states how
each rewritten finder or read still checks the same thing, anchored to the
same key, with a negative control where a looser finder could match a
neighbour. Expected rulings (the builder adds any it meets):

- one per row of the component mapping (type finders);
- **labels, suffixes and errors**: reads of `decoration.labelText`,
  `errorText`, `suffixText` move to the field's label and error widgets,
  found under the same key;
- **tooltip finders**: `find.byTooltip` and reads of `Tooltip.message`
  move to the semantics label (with semantics enabled in the test) or to
  the opened `ShadTooltip`'s content;
- **surface and token reads**: tests that read a `Container`'s decoration
  or a Material token (`page_panel_theme_test`) read the shadcn surface
  and its token;
- **the restaurant demo's look**: `look_test` and `host_chrome_test`
  observe the `ShadTheme` around the view, not `posColorScheme`;
- **the gallery** (above); **icons** (above);
- **the leak collectors** (G6): LK1's (`editor_words_test`) and LK2's
  (integration `leak_test`) collectors also collect field labels and
  errors, open each `ShadTooltip` and menu and collect its content, and
  enter search text through the `ShadInput`; every assertion and allowlist
  stays; a leak mutation per new category (a raw word in a tooltip, a
  label, a menu entry) turns them red.

### Public API boundary

A new test resolves the barrel's exported library elements with the
analyzer (as `tool/ci`'s guide check does) and fails if any public
member's type, any parameter, any return type, any type argument or any
supertype of an exported element is declared in `package:shadcn_ui` or
`package:lucide_icons_flutter`. Existing Flutter and Material exposure
(`PlanTheme extends ThemeExtension`, `Widget`, `IconData`) is allowed. A
named mutation (a public `ShadThemeData` field on `PlanEditor`) turns it
red. The barrel test's name list and the host probes are unchanged.

### The restaurant demo (decision 3)

`demo_theme.dart` keeps `posPlanTheme`, `kPosPlanLight`, `kPosPlanDark` and
`kPosViewOverride`; `posColorScheme` and `posViewTheme` go, and a
`ShadThemeData` light and dark from shadcn's zinc palette replace them,
wrapped around the view under `DemoLook.pos`. `DemoLook.standard` stays a
plain Material look and so exercises the derived theme.

### The host guide

`docs/host-guide.md` §10 is rewritten: the chrome is shadcn; a shadcn host
puts nothing extra (its `ShadTheme` is used); a Material host puts nothing
either (the chrome is derived from its `ThemeData`); `PlanTheme` is
unchanged; the paragraph telling a non-Material POS to hand-build a
`ColorScheme` is replaced by "the `ShadTheme` above the view is used". A
migration note: tests that found Material types inside the planner find
shadcn types now; keys are unchanged; a host on `shadcn_ui` needs
`^0.57.1`. The guide's checks (`tool/ci/check_guide.dart`,
`tool/ci/host_probe`) stay green.

### Screenshots

`tool/screenshots` regenerates every PNG that shows the library's chrome
(`plan_editor.png`, `plan_gallery.png`, the kits' gallery shots, any
other). `check_screenshots.dart` stays green. README links keep their
current tags until release.

## Done means

- The chrome listed in G1 is shadcn. An exact allowlist (in the results
  note and in a source-scan test) names every Material widget kept in
  `jet_cad_2d_plan/lib` and why (the canvas files, `PlanTheme`, transparent
  `Material` for host slots, `Scaffold` if kept, `Scrollbar`, the canvas-
  owned theme reads); anything else fails the scan.
- Theme tests: every public widget and `showPlanExportDialog` under a bare
  `MaterialApp` (light, dark) with no `ShadTheme`, and under a `ShadTheme`
  with distinctive colours **and** a distinctive font, check the chrome's
  surfaces, text style and icon colour; the disagreeing-brightness test
  checks the canvas-owned reads. Named mutations (the scope always
  derives; never derives; no `DefaultTextStyle`; the dialog uses the
  caller's context) turn them red.
- Host-slot test: a Material `TextField` and an `InkWell` in each host
  slot, under a bare `MaterialApp`, build and respond (a mutation that
  drops the transparent `Material` turns it red).
- Field, choice, menu and semantics behaviours above have tests, each with
  a named mutation.
- No public signature change; the API-boundary test is green.
- Every existing behaviour test is green; each change is under a ruling in
  the results note.
- The leak tests are green with extended collectors; the shadcn-words scan
  exists.
- `apps/dev_harness` resolves and is green at `^0.57.1`.
- Both demos run (light, dark; phone, tablet, desktop widths) and their
  tests are green.
- `docs/host-guide.md` is updated and its checks are green.
- `CHANGELOG.md` of `jet_cad_2d_plan` and `jet_cad_2d_kit_architecture`
  have an "Unreleased" entry; the root index points at them.
- A results note in `docs/superpowers/notes/` holds the rulings, the
  kept-Material allowlist, every mutation and the gates' real last lines;
  the human gets the report.

## Left to the builder

- The scope's name and file; the exact colour tokens after looking.
- `ShadTabs` or toggled buttons per segmented site; the null/custom
  choice representation; the read-only field technique; the export route
  type; the gallery's loading indicator; whether `Scaffold` stays.
- The task order, as long as each task ends green.

## Appendix A — rev 1 review (OpenCode, GPT-6.1-sol), and what rev 2 did

1. dev_harness `^0.55.0` blocks resolution → in scope, `^0.57.1`.
2. The gallery's chrome is the renderer's → decision 9, the library's own.
3. `showShadDialog` reads the theme before pushing → the library's own route.
4. `InputDecorator`, `CircularProgressIndicator`, `Scrollbar` missing → mapped.
5. `ShadTheme` sets no text style or icon theme → the scope installs both.
6. Canvas-owned theme reads; `serviceBarHeight` is chrome → "Canvas-owned reads", decision 2.
7. Host slots need a `Material` ancestor → transparent `Material` kept, tested.
8. `ShadInput`'s private tap group → `groupId: EditableText`.
9. `readOnly` differs → today's behaviour kept, tested.
10. `ShadSelect` sets its value first → controlled by the model.
11. Context menu construction → a controller-driven `ShadContextMenu`.
12. Semantics per category → specified.
13. LK1 "unchanged" impossible → collectors extended, assertions kept.
14. Label, error, token and look reads → rulings.
15. 0.56.1 vs 0.57.1 differences → decision 8, `^0.57.1`.
16. Keyboard toolbar, web menu, search select → specified.
17. Barrel test checks names only → the API-boundary test.
18. Inventory errors (Scaffold vs grep, the editor's segmented control, 44 icons) → corrected.
