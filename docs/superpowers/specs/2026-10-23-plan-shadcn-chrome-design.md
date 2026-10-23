# The plan library's chrome in shadcn

**Date:** 2026-10-23. **Status:** draft, for the human's approval.
**Packages:** `jet_cad_2d_plan` (0.9.0 on pub.dev),
`jet_cad_2d_kit_architecture` (0.1.1), `jet_cad_2d_kit_restaurant` (0.1.0);
`packages/jet_cad_2d_integration`, `apps/restaurant_demo`,
`apps/architecture_demo`, `docs/host-guide.md`, `tool/screenshots`.

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
  menus and the dialogs (export and every other) are built from `shadcn_ui`
  components.
- **G2 — The host's shadcn theme wins.** When an ancestor `ShadTheme`
  exists, the chrome uses it as is (colours, radius, text, brightness).
- **G3 — No host has to wrap anything.** When no `ShadTheme` exists, the
  library supplies its own, derived from the ambient Material `ThemeData`
  (its `ColorScheme` and its brightness). A plain Material host keeps
  working, light and dark.
- **G4 — Lucide icons.** The library's own icons and the two kits' tool
  icons are `LucideIcons`. The API stays `IconData`: a kit may still give
  any icon.
- **G5 — Behaviour unchanged.** Every existing behaviour test stays green.
  A test changes only where the widget type it finds genuinely changed;
  each Material→shadcn mapping is one ruling covering all of its uses.
- **G6 — Words unchanged.** Every visible word still comes from
  `PlanStrings` (or a kit's `PlanWords`); no shadcn built-in string reaches
  the screen. The LK1 leak tests stay green unchanged.

## Non-goals

- **The canvas.** Canvas painting, the snap and the move logic belong to the
  alignment-guides session running in parallel; this work does not touch
  them. `PlanCanvas`, `plan_canvas_view.dart` and the in-canvas text entry
  (`text_entry_overlay.dart`, a field that mimics the text it edits) stay
  as they are.
- **`PlanTheme`'s fields.** No field is added, removed or reinterpreted.
- **The 1.0 release itself.** This lands under "Unreleased"; versions,
  tags and the README image links move with the release.
- **monepro's own integration.** It is the next sub-project, not this one.

## Anti-goals (it fails even if it works)

- A host has to wrap the editor in `ShadApp` or `ShadTheme` to see it
  right, or a plain Material host breaks or shows a broken chrome.
- A `Shad*` type appears in `jet_cad_2d_plan`'s public API (a parameter, a
  return type, a field, an export). A shadcn breaking release would then
  break the 1.0 API.
- An English word from shadcn's own localizations ("Cut", "Copy", "Paste",
  "Select All", "Done") shows in a Turkish or German editor.
- A behaviour test is weakened to pass: an assertion dropped, a finder made
  vaguer than the thing it checked.
- A widget key changes or disappears.

## Decisions the human made

1. **Theme ownership (G2, G3).** The editor looks for an ancestor
   `ShadTheme`; if found, it uses it; if not, it builds its own from the
   host's Material `ColorScheme`. No wrapper is required of a host.
2. **`PlanTheme` stays.** It keeps being a `ThemeExtension` on `ThemeData`,
   overridden field by field by a view's `theme:`. Its fields are the
   canvas's look and have nothing to do with the chrome. `kPosViewOverride`
   in the restaurant demo stays as is.
3. **The restaurant demo's POS look.** Its hand-built Material
   `ColorScheme` around the view (`posViewTheme`, `posColorScheme`) goes;
   instead the demo wraps the editor in a `ShadTheme` from shadcn's zinc
   palette, which is exactly what monepro does. `posPlanTheme` and
   `kPosViewOverride` stay.
4. **Dark mode.** With a host `ShadTheme`, the chrome follows its
   brightness (`ShadApp` picks `theme` or `darkTheme` by `themeMode`).
   Without one, the derived theme follows the Material `ThemeData`'s
   brightness. The canvas keeps following the paper and `PlanTheme`. A host
   whose `ShadTheme` and `ThemeData` disagree in brightness gets a dark
   chrome over a light canvas (or the reverse); this is accepted (monepro
   builds both from one brightness).
5. **Keys stay.** Every existing `Key` keeps its value and its meaning (it
   still finds the control that does the same thing).
6. **Test rulings per mapping.** A test that finds a Material type changes
   to the shadcn type that replaced it; one ruling per mapping (e.g.
   "`DropdownButton` → `ShadSelect`") covers every use. A test that reads a
   value out of the found widget reads the same value out of the new one.
7. **Lucide icons**, in the library and in both kits (G4); both kits
   therefore get an "Unreleased" CHANGELOG entry too.
8. **Dependency.** `shadcn_ui: '>=0.56.1 <0.58.0'` (monepro is on
   `^0.56.1`; 0.57.1 is current). CI resolves both ends. No `Shad*` type in
   the public API.

## Constraints

- **The frame path allocates nothing per entity in steady state.** The
  chrome is not on the frame path, but `paint_allocation_test` and
  `query_allocation_test` stay green.
- **Never commit `analysis_options.yaml`.** **Never synthesize test output.**
- **The alignment-guides branch must merge cleanly.** Its probable
  touch points are the canvas, `tools/move_resolver.dart`, the service
  drag and possibly a toggle on the editor bar (`PlanEditorAction`). This
  work does not touch the first three. If a toggle lands on the bar first,
  the bar's migration picks it up; if this lands first, the toggle uses the
  bar's new button helper. Whichever branch merges second rebases.
- **Phone and tablet layouts** (`editor_layout.dart`,
  `PlanEditorLayout`, `PlanLayoutBreakpoints`, `PlanDrawerHost`) keep
  their breakpoints (below 600, 600 to 1000, 1000 and up), their docked
  columns and their drawers. Only the look changes.
- **The host probe** (`tool/ci/host_probe`) and the old-host probes for
  the released tags stay green: no public signature changes.
- **README images pin per-package tags** (`tool/ci/check_screenshots.dart`).
  The PNGs are regenerated here; the links' tags move at release.
- **Every gate in CLAUDE.md** plus `packages/jet_cad_2d_integration`,
  both demos' tests, `tool/ci` (`dart test`), `tool/screenshots` and
  `tool/readme_probe`.

## The design

### The scope (G2, G3)

One internal widget, called `PlanShadScope` here (the builder may name
it), resolves the chrome's theme:

- If `ShadTheme.maybeOf(context)` is non-null, it returns its child
  unchanged.
- Otherwise it wraps the child in a `ShadTheme` whose `ShadThemeData` is
  derived from `Theme.of(context)`, plus whatever else `ShadApp` puts
  above an app that shadcn's components need to work (today
  `ShadMouseAreaSurface` and `ShadMouseCursorProvider`; the builder
  verifies the list against `shadcn_ui`'s `app.dart` at the pinned
  version).

The derived data is computed once per theme change (in
`didChangeDependencies` or memoised on the `ThemeData`), never per build
of a descendant.

**The mapping from Material.** `background` ← `surface`, `foreground` ←
`onSurface`, `card`/`popover` ← `surfaceContainerLow` with `onSurface`,
`primary`/`primaryForeground` ← `primary`/`onPrimary`,
`secondary`/`secondaryForeground` ← `secondaryContainer`/
`onSecondaryContainer`, `muted` ← `surfaceContainerHighest`,
`mutedForeground` ← `onSurfaceVariant`, `accent`/`accentForeground` ←
`surfaceContainerHigh`/`onSurface`, `destructive`/`destructiveForeground`
← `error`/`onError`, `border` ← `outlineVariant`, `input` ← `outline`,
`ring` ← `primary`, `selection` ← `primary` at low alpha. Brightness ←
`ThemeData.brightness`. The text theme takes the host's Material font
family (`textTheme.bodyMedium.fontFamily`), so a Material host does not
suddenly show shadcn's bundled Geist; with a host `ShadTheme`, its own text
theme is used. (Builder's call: the exact container tokens may be tuned
while looking at both demos, light and dark; the table above is the
starting point.)

**Where it is applied.** At the root of every public widget a host may
mount on its own: `PlanEditor`, `PlanToolPalette`, `PlanSymbolGallery`,
`PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel`,
`PlanServiceView`, and in every dialog or route the library pushes. Nested
scopes are cheap: an inner one finds the outer one's `ShadTheme` and does
nothing.

**Routes and dialogs.** `showShadDialog` does not capture inherited themes
(unlike Material's `showDialog`), and a dialog under the root navigator
sits above the scope. Every dialog the library shows (`showPlanExportDialog`
and any other) therefore captures the caller's `ShadTheme` (or derives it
there) and re-provides it, together with whatever the dialog's content
already needed from the caller (the `PlanStrings` scope, `PlanTheme`), in
its builder. A test mounts each dialog under a plain `MaterialApp` with
the editor inside a local `Theme` and checks the dialog takes the local
colours, not the app's.

**Overlays.** `ShadPopover`, `ShadSelect`, `ShadTooltip` and
`ShadContextMenu` render through `ShadPortal` from their own position, so
they inherit the scope; the builder confirms it with the same kind of test.

### Words (G6)

shadcn carries its own localizations (slang, `ShadLocalizations`) and falls
back to English when no delegate is present. Two of its components show
built-in words: `ShadInput`'s selection menu (Cut, Copy, Paste, Select All)
and the keyboard toolbar (Done); the date and time pickers are not used.
The library passes its own `contextMenuBuilder` to every `ShadInput`,
building the platform's adaptive toolbar whose labels come from
`MaterialLocalizations`, which is today's behaviour exactly (the host
already provides Material's delegates, `docs/host-guide.md` §3). No other
shadcn component with a built-in word is used; a new LK1-style test lists
the shadcn components the library imports and fails on one that carries
`ShadLocalizations` words not routed. (Builder's call how to enforce it:
a source scan in `test/l10n` is enough.)

`planLocalizationsDelegates` does not change.

### The component mapping

The starting mapping, by today's widget. Each line is one test ruling (G5,
decision 6) when a test finds that type.

| Today (Material) | shadcn | Where today |
|---|---|---|
| `IconButton` | `ShadIconButton` (ghost) | editor, palette, layer panel, layer row, gallery, service view |
| `TextButton`, `OutlinedButton`, `FilledButton` | `ShadButton.ghost` / `.outline` / default | property panel, gallery, export dialog |
| `TextField` | `ShadInput` | property panel, page panel, layer row, gallery |
| `DropdownButton` + `DropdownMenuItem` | `ShadSelect` + `ShadOption` | property panel, page panel |
| `SegmentedButton` | `ShadTabs` (or a row of toggled `ShadButton`s; builder's call per site, one ruling per final choice) | editor (mode switch), page panel, export dialog |
| `PopupMenuButton` + `PopupMenuItem` | `ShadContextMenuRegion` / `ShadPopover` with `ShadContextMenuItem` | layer picker, layer row |
| `Tooltip` | `ShadTooltip` | editor, layer panel, layer picker, colour row |
| `AlertDialog` via `showDialog` | `ShadDialog` via `showShadDialog` | export dialog |
| `ListTile`, `CheckboxListTile`, `SwitchListTile` | a row of shadcn parts (`ShadCheckbox`, `ShadSwitch` with a label) | palette, page panel, panels |
| `Divider` | `ShadSeparator` | palette |
| `InkWell` on a row | `ShadButton.ghost` or a `GestureDetector` with shadcn hover | layer panel, layer row, colour row, page panel |
| `Material` (as a surface) | a `DecoratedBox` / `ShadCard` from the scope's colours | panels, editor, service view |
| `Scaffold` | stays (layout only, no Material look) or a plain `Stack`; builder's call | editor |
| `Theme.of(context).colorScheme.*` in the chrome | `ShadTheme.of(context).colorScheme.*` | 25 sites |

`Theme.of(context)` stays where it reads `PlanTheme` (the extension) or the
brightness for the canvas.

**Tooltips and semantics.** Tests find tooltips by message
(`find.byTooltip`) in many places. `ShadTooltip` does not register the
same semantics as Material's `Tooltip`; the controls keep a `Semantics`
label equal to today's tooltip text, so screen readers and the
`byTooltip`-style finders' intent survive. The ruling for `Tooltip →
ShadTooltip` says how each such finder is rewritten (a `find.bySemanticsLabel`
or a finder on `ShadTooltip`'s builder) without losing what it checked.

### Icons (G4)

`jet_cad_2d_plan` takes `lucide_icons_flutter` directly (the range
`shadcn_ui` itself takes, `>=3.0.0 <4.0.0`); its 46 `Icons.*` uses become
`LucideIcons.*`. `jet_cad_2d_kit_architecture` (6 files) does the same for
its tools. `jet_cad_2d_kit_restaurant` has no icons of its own today; it
changes only if a check finds one. `PlanTool.icon` stays `IconData`.
`jet_cad_2d_flutter`'s one icon is the renderer's, out of scope.

A test that finds an icon (`find.byIcon(Icons.x)`) changes with the
mapping, one ruling for all icon finders, with the full old→new table in
the ruling.

### The restaurant demo (decision 3)

`demo_theme.dart` keeps `posPlanTheme`, `kPosPlanLight`, `kPosPlanDark` and
`kPosViewOverride`; `posColorScheme` and `posViewTheme` go and a
`ShadThemeData` light and dark from shadcn's zinc palette replace them,
wrapped around the view under `DemoLook.pos`. `DemoLook.standard` stays a
plain Material look and so exercises the derived theme.
`host_chrome_test` and the demo's other tests follow.

### The host guide

`docs/host-guide.md` §10 is rewritten: the chrome is shadcn; a shadcn host
puts nothing extra (its `ShadTheme` is used); a Material host puts nothing
either (the chrome is derived from its `ColorScheme`); `PlanTheme` is
unchanged; the paragraph telling a non-Material POS to hand-build a
`ColorScheme` is replaced by "wrap the view in your `ShadTheme`" (only
needed if the host's `ShadTheme` is not already above it). The migration
note says: tests that found Material types inside the planner find shadcn
types now; keys are unchanged. The guide's probe (`tool/ci/check_guide.dart`,
`tool/ci/host_probe`) stays green.

### Screenshots

`tool/screenshots` regenerates every PNG that shows chrome
(`plan_editor.png`, `plan_gallery.png`, the kits' gallery shots, any
other). `check_screenshots.dart` stays green (budget, sizes). README links
keep their current tags until release.

## Done means

- The chrome listed in G1 is shadcn; a grep of `jet_cad_2d_plan/lib` finds
  no Material widget outside the canvas files named in the non-goals and
  `PlanTheme`'s `ThemeExtension`.
- A test mounts every public widget and the export dialog under a bare
  `MaterialApp` (light and dark) with no `ShadTheme`, and under a
  `ShadTheme` with a distinctive colour, and checks the chrome took the
  right colours; a named mutation (the scope always derives; the scope
  never derives; the dialog does not re-provide) turns it red.
- No public API change: the barrel's exports and every public signature
  are unchanged (the host probe and the old-host probes are green), and no
  `Shad*` type is reachable from the barrel.
- Every existing behaviour test is green; each change to a test is under
  a mapping ruling in the results note.
- The LK1 leak tests are green unchanged; the shadcn-words test exists and
  a named mutation (a `ShadInput` without the library's menu builder)
  turns it red.
- Both demos run (light, dark; phone, tablet, desktop widths) and their
  tests are green.
- `docs/host-guide.md` is updated and its probe is green.
- `CHANGELOG.md` files of `jet_cad_2d_plan` and
  `jet_cad_2d_kit_architecture` (and `jet_cad_2d_kit_restaurant` if
  touched) have an "Unreleased" entry; the root index points at them.
- CI resolves `shadcn_ui` at 0.56.1 and at the newest below 0.58.0 and
  both are green.
- A results note in `docs/superpowers/notes/` holds the rulings, every
  mutation and the gates' real last lines; the human gets the report.

## Left to the builder

- The scope's name and file; the exact colour tokens after looking.
- `ShadTabs` or toggled buttons per `SegmentedButton` site.
- Whether `Scaffold` stays in `PlanEditor`.
- How the CI lower/upper bound check runs (a `dependency_overrides` job or
  a `pub downgrade` step).
- The task order, as long as each task ends green.
