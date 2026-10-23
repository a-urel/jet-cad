# The example apps in shadcn

**Date:** 2026-10-24. **Status:** rev 2, for the human's approval. Rev 1
followed monepro's skeleton; the human then ruled (2026-10-24): *"monepro'da
hatalar olmuş. mümkün olan her durumda shadcn tercih et."* monepro is now a
reference, not a template: wherever shadcn can do it, shadcn does it.
**Branch:** `claude/shadcn-ui-75d8dc` (the human: "bu branch'te"), at `main`'s
tip `8f9a444b`.
**Apps:** `apps/restaurant_demo`, `apps/architecture_demo`. **Not**
`apps/dev_harness` (already `ShadApp`, zinc dark), **not**
`apps/dev_harness_2d` (decision 10). **No library change** (non-goal N1).

## Intent

The plan library's chrome is shadcn since `f8d56f3f`. The two example apps
around it are still Material: an `AppBar`, `SegmentedButton`s,
`AlertDialog`s, a `DropdownButton`, `SwitchListTile`s, Material icons. The
demos are read by two people (the human, 2026-10-24: "ikisi de, ama öncelik
monepro örneği"):

1. **First, a monepro developer.** monepro is the first real host and a
   shadcn app, but its skeleton carries Material it does not need
   (`ShadApp.custom` around a `MaterialApp.router`, a `Scaffold` with
   Material `Drawer`s and `IconButton`s, `monepro-frontend/lib/app.dart`,
   `base_layout.dart`). The demos show the shadcn-first way to mount the
   planner, which monepro can move towards.
2. **Then, someone from pub.dev** trying the library: the same code shows
   them how a shadcn host mounts the planner.

## Goals

- **G1 — shadcn first.** Both demos root in a plain `ShadApp` (no
  `MaterialApp`, no `Scaffold`); every widget the demo itself builds is a
  shadcn one wherever shadcn has one.
- **G2 — Zinc.** Both demos are shadcn zinc, light and dark, following the
  system (the human: "zinc olsun, monepro gibi"). The architecture demo's
  `kAppSeed` Material look goes.
- **G3 — No Material** in either demo's `lib/`, except what decision 7
  lists with its reason (expected: nothing the user sees). No `Icons.`:
  Lucide.
- **G4 — Behaviour unchanged.** Every key, callback, flow and string stays.
  The demos' tests stay green; a test changes only where a widget type
  changed, and each change is a ruling (old → new, why the same thing is
  still checked).
- **G5 — Guarded.** A test per demo fails when a Material component or an
  `Icons.` comes back into `lib/` (decision 8).

## Non-goals

- **N1 — The library.** `packages/*` do not change. A library defect found
  on the way is a ruling plus a separate fix, never a demo-side workaround
  that hides it.
- **N2 — monepro's own tokens.** Stock `ShadZincColorScheme`, not monepro's
  `AppTheme`.
- **N3 — Routing.** No `go_router`: neither demo has routes.
- **N4 — The canvas.** Painting, snap, move: untouched.

## Anti-goals

- A key renamed or a flow reordered "while we are there".
- A test loosened to pass (a premise dropped, a pixel tolerance widened)
  instead of retargeted at the new widget.

## Decisions

**1. The root (both demos): a plain `ShadApp`.** Not `ShadApp.custom`.
shadcn 0.57.3's `ShadApp` (`ShadAppType.shadcn`) builds a `WidgetsApp`
with `MaterialPageRoute`s, adds the Material, Cupertino, widgets and shadcn
localization delegates, and puts an `AnimatedTheme` with a Material
`ThemeData` *derived from the `ShadTheme`* above it (`app.dart`
`materialTheme`: primary, surface = background, brightness, font family).
That derived theme is what the canvas reads (`Theme.of`: background,
paper, brightness), so no hand-written `ThemeData` is needed.

```dart
ShadApp(
  theme: demoShadTheme(Brightness.light),
  darkTheme: demoShadTheme(Brightness.dark),
  themeMode: ThemeMode.system,
  materialThemeBuilder: (context, theme) => ..., // only to add extensions
  ...today's locale, delegates, title, navigatorKey, builder, home...
)
```

Everything `MaterialApp` carries today (the restaurant demo's `locale`, the
architecture demo's `navigatorKey`, `onGenerateTitle` and its
`CallbackShortcuts` `builder`) moves onto `ShadApp`, which takes the same
parameters. The restaurant demo's POS `PlanTheme` extension, today added in
`_theme`, goes through `materialThemeBuilder` (`theme.copyWith(extensions:
...)`). `demoShadTheme` is zinc with the planner's bundled `Roboto` (both
demos bundle it; the same glyphs on every platform keep the screenshots
stable) — my call. No `Scaffold` in the demos: `PlanEditor` keeps its own
(the library's ruling 7); the demo's page paints the `ShadTheme`'s
`background` itself.

**2. The restaurant demo's look toggle.** Today *Standard* has no
`ShadTheme` above the view (the planner derives its chrome from the
Material theme) and *POS* puts a zinc `ShadTheme` around it (`look_test.dart`
pins both). Under a `ShadApp` root every view has the app's zinc
`ShadTheme` above it, so the derived chrome is not shown any more; the
library's own tests (SC1–SC10) keep covering it. The toggle stays and
changes the canvas side: *Standard* is the library's default `PlanTheme`;
*POS* is the POS `PlanTheme`s, the 3 px selection and the 52 px service bar.
The per-view `ShadTheme` wrap (`_viewTheme`) goes. `look_test`'s "no
`ShadTheme` under Standard" and "derived bar" assertions become rulings,
retargeted at what the toggle now changes. Accepted by the human's rule
("mümkün olan her durumda shadcn").

**3. The restaurant demo's bar: no `AppBar`.** A top pane above the
editor, built from shadcn parts on the `ShadTheme`'s `background`, with a
bottom `ShadSeparator`: the title, then, docked (≥ `kDockedSidePanel`), the
controls in the row; below it, a tune `ShadIconButton`
(`side-panel-button`) at the end and the controls in a horizontal scroll row
under the title (`app-controls`). Heights may differ from the `AppBar`'s;
the layout tests' numbers that follow from them are rulings.

**4. The side panel, undocked: a `ShadSheet`** from the right
(`showShadSheet(side: ShadSheetSide.right)`), 320 wide, keyed
`side-panel-drawer`, holding `DemoSidePanel`. It replaces the `Scaffold`'s
`endDrawer` and the `GlobalKey<ScaffoldState>`. Docked, the panel stays
beside the editor as today. monepro uses a Material `Drawer` here; the
human's rule overrides that.

**5. The mapping.**

| Today | Becomes | Where |
|---|---|---|
| `AlertDialog`, `SimpleDialog` + `showDialog` | `ShadDialog` (`.alert` for the error) + `showShadDialog` | architecture `document_host.dart`; restaurant `export_flow.dart` |
| `TextButton`, `FilledButton`, `FilledButton.tonal` | `ShadButton.ghost` / `ShadButton` / `ShadButton.secondary` | dialogs, `side_panel.dart`, `own_bar.dart` |
| `IconButton` | `ShadIconButton.ghost` | open sample, side panel button |
| `Tooltip` | `ShadTooltip` | document title, look toggle |
| `TextField` | `ShadInput` (find table: leading `LucideIcons.search`) | find table, side panel, name prompt |
| `SegmentedButton` | `ShadTabs` (tabs only, no content) | language, look, area, mode, side panel ×2 |
| `DropdownButton` in an `InputDecorator` | `ShadSelect` under a label | `editor_profiles.dart` |
| `SwitchListTile` | `ShadSwitch` with `label`/`sublabel` | `side_panel.dart` ×8 |
| `showMenu` + `PopupMenuItem` | `ShadContextMenu` at a `ShadGlobalAnchor` (the title item disabled, a divider) | `table_menu.dart`; `showTableMenu`'s signature stays |
| `Material(color: surfaceContainerHigh)` | `ColoredBox` with the shadcn `muted` | `own_bar.dart` |
| `Theme.of(context).colorScheme`/`textTheme` in the badges | `ShadTheme.of(context)` tokens | `badges.dart` |
| `Scaffold`, `AppBar`, `Drawer` | decisions 1, 3, 4 | `main.dart` (both), `document_host.dart` |
| `Theme.of(context).textTheme.*`, `.colorScheme.error` in host chrome | `ShadTheme.of(context).textTheme.*`, `.colorScheme.destructive` | `side_panel.dart` |
| `Icons.*` | `LucideIcons.*` | everywhere |

The save-changes dialog keeps `barrierDismissible: false`, Escape →
cancel and the focus on Save. If a shadcn component cannot carry a behaviour
the Material one had (a key, a disabled item, focus), the builder rules,
keeps the behaviour, and records the ruling.

**6. Keys are the contract.** Every `Key` in both demos' `lib/` keeps its
value and lands on the widget a user acts on (the button, the tab, the
switch, the option), so tests that tap by key keep working.

**7. Material kept, with the reason.** Expected: none in either demo's
`lib/`. The canvas reads the Material theme `ShadApp` derives; the demo
does not build one. A construct the builder cannot replace (a shadcn
component missing, or one that cannot carry a behaviour the demo has) goes
in decision 8's allow-list with its reason and a ruling.

**8. The guard.** `test/invariants/kept_material_test.dart` in each demo,
as the library's KM1/KM2: (DKM1) every Material construct in `lib/` is in a
listed (file, construct, reason) allow-list, and a listed entry that matches
nothing fails; (DKM2) no `Icons.` in `lib/`. Named mutations: an
`IconButton` added to `side_panel.dart` turns DKM1 red; an `Icons.add`
turns DKM2 red; a stale allow-list entry turns DKM1 red.

**9. The dependencies.** Both demos depend on `shadcn_ui: ^0.57.1` and
`lucide_icons_flutter: ^3.1.25` (the library's floors); the architecture
demo adds both.

**10. `dev_harness_2d` stays out.** It is a measurement harness (R2, R4a,
R4b in profile mode); changing its root moves the frame-time baseline it
exists to measure, and nobody copies it. `dev_harness` is already shadcn.

## What must hold at the end

- `restaurant_demo` and `architecture_demo`: `flutter test`, `flutter
  analyze`, `dart format --set-exit-if-changed` green; their
  `integration_test`s pass on macOS; `flutter build macos --debug` builds.
- The packages' gates as before (no package changes; run the plan
  library's and `jet_cad_2d_integration`'s anyway, they share the
  workspace's resolution).
- `tool/screenshots` and `tool/ci` green; `check_screenshots` holds; any
  screenshot of a demo is regenerated and looked at.
- `docs/host-guide.md`: the sentences that describe the demos (the
  introduction's restaurant demo, §10's POS look at `demo_theme.dart`) match
  them. The host probe is untouched (no library change), `check_guide`
  green.
- Every test change is in the ledger's `rulings.md`.
- The CHANGELOGs: the demos are `publish_to: none` and the root CHANGELOG
  only lists the packages, so no CHANGELOG entry; the results note and
  `STATUS.md` record it. My call — this revises the playback's "CHANGELOG".

## Left to the builder

The exact spacing and heights of the top pane, which Lucide glyph replaces
each Material one, how `ShadTabs` is sized in the scroll row, and how a
behaviour shadcn lacks is kept (decision 5's last paragraph).
