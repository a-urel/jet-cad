# dev_harness → shadcn ribbon demo — design

**Date:** 2026-07-12
**Status:** Approved (design), pending implementation plan
**Scope:** `apps/dev_harness` only. No changes to `packages/jet_cad` public API.

## Goal

Restyle the throwaway dev harness with the `shadcn_ui` Flutter port and add an
Office/Fusion-style **tabbed CAD ribbon** at the top. The ribbon is presentation
only — most tools are decorative — while the live [JetCadViewport] and the four
already-working actions (Add box, Undo, Redo, Fit) keep functioning.

The harness stays a manual-verification app for the package's public surface.
This is not the eventual product UI; it is a nicer demo/harness.

## Non-goals

- No real CAD operations behind the decorative tools (no sketch, extrude,
  boolean, transform, view-preset logic).
- No persistence / file open-save.
- No new APIs on `package:jet_cad`. The package remains UI-agnostic; all UI
  lives in the harness. If the harness needs a `package:jet_cad/src/...`
  import, the package surface is wrong (existing invariant, preserved).

## Architecture

Today [apps/dev_harness/lib/main.dart] is a single file mixing app boot, session
lifecycle, and UI. Split into bounded, independently understandable units:

| File | Purpose | Depends on |
|---|---|---|
| `lib/main.dart` | `runApp(ShadApp)`, dark theme config, boot only | shadcn_ui, harness_page |
| `lib/harness_page.dart` | Owns `CadDocument`/`ViewportController`/status/selection lifecycle + action handlers (the live logic, moved from today's `_HarnessPageState`). Wires callbacks into the ribbon and status bar. | jet_cad, cad_ribbon, status_bar |
| `lib/ribbon/ribbon_model.dart` | Plain data types describing the ribbon. No Flutter widget imports beyond `IconData`. | flutter (IconData only) |
| `lib/ribbon/cad_ribbon.dart` | Renders tabs/groups/tools from a model. Pure presentational; receives the live callbacks. | shadcn_ui, ribbon_model |
| `lib/status_bar.dart` | Bottom bar: status text + selection badge. | shadcn_ui |

Rationale: the ribbon renders **from data**, so a decorative tool is simply a
tool whose `onPressed` is `null`. `cad_ribbon.dart` has no dependency on
`jet_cad` — it takes callbacks — so it is testable without the native library.

### Ribbon data model (`ribbon_model.dart`)

```dart
typedef RibbonAction = void Function();

class RibbonTool {
  const RibbonTool(this.label, this.icon, {this.onPressed});
  final String label;
  final IconData icon;
  final RibbonAction? onPressed; // null → decorative (not implemented)
}

class RibbonGroup {
  const RibbonGroup(this.title, this.tools);
  final String title;
  final List<RibbonTool> tools;
}

class RibbonTab {
  const RibbonTab(this.title, this.groups);
  final String title;
  final List<RibbonGroup> groups;
}
```

The concrete tab/group/tool list is built in `harness_page.dart` (so it can
close over the live callbacks) and passed into `CadRibbon`.

## Layout

```
┌ Quick access: ↶Undo  ↷Redo  ⤢Fit ──────────────┐  ← live, always visible
│ File | Sketch | [Model] | Modify | View         │  ← ShadTabs, Model default
│  ┌Primitives┐ ┌Features┐ ┌Boolean┐              │  ← ShadCard group boxes
│  │▢Box✔ ⬗Cyl…│ │Extrude…│ │∪ ∩ −  │              │  ← ribbon tool buttons
├─────────────────────────────────────────────────┤
│              JetCadViewport (live)               │  ← Expanded
├─────────────────────────────────────────────────┤
│ ● ready          selection: 12, 13               │  ← status bar
└─────────────────────────────────────────────────┘
```

- **Quick-access strip** (left of the tab bar, persistent across tabs): Undo,
  Redo, Fit — all live. Undo/Redo/Fit are global actions, so they do not belong
  inside a single tab.
- **ShadTabs** row: File, Sketch, Model (default selected), Modify, View.
- Each tab's body is a horizontal row of **group boxes** (a titled container per
  group), each holding icon+label tool buttons.
- The viewport fills remaining vertical space (`Expanded`).
- Status bar pinned at bottom.

### Tab / group / tool inventory

Live tools marked ✔; everything else decorative.

- **File** — New, Open, Save, Export.
- **Sketch** — Line, Rectangle, Circle, Arc, Polygon.
- **Model**
  - Primitives: **Box ✔**, Cylinder, Sphere, Cone.
  - Features: Extrude, Revolve, Fillet, Chamfer, Shell.
  - Boolean: Union, Subtract, Intersect.
- **Modify** — Move, Rotate, Scale, Mirror, Pattern.
- **View** — **Fit ✔** (also in quick access), Isometric, Front, Top, Wireframe.

Icons from `LucideIcons` (bundled with `shadcn_ui`); pick the nearest available
glyph per tool during implementation.

## Live wiring (preserved behavior)

Moved verbatim from today's harness, unchanged in semantics:

- **Box ✔** → `await doc.makeBox(const Vec3(40, 30, 20)); await controller.fitAll();`
- **Undo ✔** → `doc.undo`
- **Redo ✔** → `doc.redo`
- **Fit ✔** → `controller.fitAll`
- Selection: subscribe to `controller.selectionChanges`, render ids in status bar.
- All live actions run through the existing `_guard(...)` helper that sets
  status to `ready` on success or the error string on failure.

## States

- **Booting / lib missing / failed:** while `doc == null || controller == null`,
  show a centered `ShadCard` with the status text (and, for the missing-lib
  case, the existing hint to run `packages/jet_cad/tool/run_harness.sh`). Same
  status strings as today.
- **Ready:** full ribbon + viewport + status bar.

## Decorative tool behavior

Tapping a tool with `onPressed == null` shows a shadcn toast:
`🚧 <Tool label> — not implemented`. Chosen over a fully-disabled/greyed ribbon
so the demo feels alive while staying honest. Trivially switchable to a disabled
visual state later (the model already distinguishes live vs. decorative via the
null callback).

## Theming

- Wrap in `ShadApp` with a dark theme (`ShadThemeData` + a Zinc dark color
  scheme) to suit a CAD tool.
- Fallback: if any descendant needs a Material ancestor and errors at build
  time, switch the wrapper to `ShadApp.material` (keeps shadcn theming while
  providing a `MaterialApp` underneath). The viewport itself uses only
  `Texture`/`Transform`/`ColoredBox`/`LayoutBuilder`/`Listener`, none of which
  require Material, so plain `ShadApp` is expected to work.

## Dependencies

Add `shadcn_ui` to `apps/dev_harness/pubspec.yaml` via `flutter pub add
shadcn_ui` (resolves the latest version compatible with Flutter ≥ 3.24 /
Dart ^3.5.0). No other new dependencies. `uses-material-design: true` stays.

## Testing

- One widget test: `test/cad_ribbon_test.dart`. Pump `CadRibbon` with a small
  model containing one live tool (callback spy) and one decorative tool. Assert:
  (a) tab titles render, (b) tapping the live tool invokes its callback, (c)
  tapping the decorative tool does not throw (toast path). No native library
  required — `CadRibbon` depends only on shadcn_ui + the model.
- `HarnessPage` still needs the native `.dylib` to boot, so it stays
  manually verified via `run_harness.sh`, as today. No change there.
- `flutter analyze` clean for the `dev_harness` package.

## Risks

- **shadcn_ui API drift.** Widget/class names (`ShadTabs`, `ShadCard`,
  `ShadButton`, toast API) must be confirmed against the resolved package
  version during implementation; adapt to the actual API.
- **Material ancestor requirement.** Mitigated by the `ShadApp.material`
  fallback above.

[JetCadViewport]: ../../../packages/jet_cad/lib/src/viewport/jet_cad_viewport.dart
[apps/dev_harness/lib/main.dart]: ../../../apps/dev_harness/lib/main.dart
