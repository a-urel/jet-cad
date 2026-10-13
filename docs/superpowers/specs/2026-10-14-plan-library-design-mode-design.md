# The plan library, design mode (sub-project 2a) — design

**Date:** 2026-10-14. **Status:** revision 1, written after the human approved
the design section by section in chat; awaiting the human's review of this
file.

**Binds:** the umbrella spec
[2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(A1-A17) and the contract spec
[2026-10-13-kit-contract-design.md](2026-10-13-kit-contract-design.md)
(K1-K9, its amendments, and "Inputs for sub-project 2", R1-R7). Where this
file and the umbrella differ, the umbrella's amendment at the end of this
file says which wins.

**Branch:** `feat/plan-library-2a`, cut by hand from `main` at `6083906`
(`origin/main` at `27244bf`, an ancestor), worktree
`.claude/worktrees/plan-library-2a`.

## Decisions taken in the brainstorm (the human, 2026-10-14)

1. **Sub-project 2 is split in two** (*"İkiye böl"*): **2a**, this spec, is
   the contract's code side and the plan library in design mode; **2b** is
   the service mode (units, statuses, the band, groups, zones, focus,
   overlays, events, host data), with its themes, touch and keyboard
   parts. Each has its own spec, plan, branch and review; the wave (A10)
   still ships them together.
2. **Approach 1, thin adapters over the Flutter layer** (*"onaylıyorum"*):
   a kit contributes the engine's own `ParametricType`, the Flutter layer's
   `Tool` and `ObjectGripProvider`, wrapped in contract descriptors; the
   plan library composes them. Rejected: a plan-library object model hiding
   the engine (it re-writes the parametric and grip layers and loses the
   ported tests as an oracle, A12), and kits registering into the engine
   directly (no failure boundary, no declarative properties).
3. **Sections 1-5 below were approved one by one** (*"uygun, devam et"*).
4. **`DraftDocument` keeps its name** (*"DraftDocument kalsın"*): the
   `Draft*` family stays whole; an importer returns a plan's text, so a host
   never names the engine's document (5a).

## Facts (at `6083906`, read from the code)

- **The Flutter layer has no controller.** State is split over
  `CameraController` (`jet_cad_2d_flutter/lib/src/camera_controller.dart:44`),
  `SelectionController` (`selection.dart:106`), `ToolController`
  (`tool.dart:164`), `ToolContext` (`tool.dart:92`: document, index, camera,
  selection, page, snap, grips), `PageNotifier`, `SnapSettings` (the F3
  flag only). `PlannerShell` assembles them by hand
  (`jet_cad_floor_plan/lib/src/planner_shell.dart:273-669`).
- **`Tool`** (`tool.dart:99`) is a `ChangeNotifier` with pointer, key,
  cancel and overlay members; a tool commits by `ctx.execute(DraftCommand)`;
  one command is one undo step. `PlacementTool`, `SelectTool` (with a
  `MoveResolver` and `SelectGates`) and the six draw tools ship there.
- **Grips:** `ObjectGripProvider` (`grip_cache.dart:33`: `gripsOf`, `drag`,
  `preview`, `movable`) is the seam; today one `ObjectGrips` dispatches to
  five types through an if-chain (`parametric/object_grips.dart:80-86`).
- **Undo** is the engine's `CommandDispatcher` (`document/undo.dart`):
  `execute`, `undo`, `redo`, `stateId`, permissions, one `expander` slot
  (`:151`), called **before** the command applies (`:190`), so an expander
  that throws refuses a command with nothing changed.
- **`ParametricCatalog`** (`parametric/parametric_system.dart:488`) has
  `register` and no listing query; `ParametricSystem.install` takes the
  expander slot and throws if it is taken (`:566`). Regeneration runs inside
  the expanded command's `apply`.
- **One expander per document** is why the shell needs `DocumentSystems`, a
  reference-counted `Expando` with a "two shells on one document" trap
  (`document_systems.dart:22`).
- **Closed lists** (umbrella Facts): the `FloorPlanTool` enum, the palette
  entries, `kShellLetterKeys`, the per-type sections of `SelectionPanel`
  (`selection_panel.dart:1251`), `isParametricObject`, `ObjectGrips._of`,
  `exportOmitOwners`, `pickedColors`.
- **Wall attachment** reaches `SymbolPlaceTool` and `SelectTool`'s move
  resolver through constructor arguments (`WallFaces`, `againstWallTag`);
  `ToolContext` has no attachment field.
- **Load discards diagnostics** (`FloorPlanController._decode`,
  `floor_plan_controller.dart:1313`).
- **`jet_cad_2d_kit` today:** `PlanKit(id, version, symbols, names)`,
  `SymbolLibrarySource(label, read)`, `KitNames`, the four `jetcad.*`
  components, the library format, `KitProblemCode` (19 values), the pure
  `authoring.dart`. It depends on Flutter and the engine, **not on
  `jet_cad_2d_flutter`**.

## P1. The contract's code side (`jet_cad_2d_kit`)

`jet_cad_2d_kit` gains a dependency on `jet_cad_2d_flutter` (A1's graph
already places it there). `authoring.dart` stays pure Dart; the existing
purity test keeps it so.

```dart
final class PlanKit {
  const PlanKit({
    required this.id, required this.version,
    this.symbols = const [], this.types = const [], this.tools = const [],
    this.attachments = const [], this.names = KitNames.empty,
  });
  final List<PlanType<Component>> types;
  final List<PlanTool> tools;
  final List<AttachmentProvider Function(PlanServices)> attachments;
}

final class PlanType<T extends Component> {
  final String id;                                  // '<kit>.<type>'
  final ComponentFactory<T> fromJson;
  final ParametricType<T> parametric;               // the engine's
  final ObjectGripProvider Function(PlanServices)? grips;
  final List<PropertySpec<T>> properties;           // P3
  final PropertySectionBuilder<T>? section;         // A4's escape hatch
  final bool exported;                              // default true
}

final class PlanTool {
  final String id;                                  // '<kit>.<tool>'
  final IconData icon;
  final String? letter;                             // a suggestion (P2)
  final bool draws;                                 // needs Capability.geometry
  final PlanToolSettings<Object>? settings;         // P3
  final Tool Function(PlanServices) create;
}

abstract interface class PlanServices {
  DraftDocument get document;
  SpatialIndex get index;
  SnapSettings get snap;
  AttachmentRegistry get attachments;
  KitWords get words;                               // the calling kit's, current locale
  S settingsOf<S extends Object>(String toolId);
  T shared<T extends Object>(T Function(PlanServices) create);
}
```

- **`shared`** is a per-plan cache keyed by the requested type: the first
  call creates, later calls return the same instance, the plan disposes it
  (when it implements `Disposable`) with its document. It replaces the
  shell-owned `WallBands`, `WallFaces` and `RoomInputs`, which a kit's tool,
  grips and provider then share.
- **Generic ids:** the plan library's own tools are `plan.select`,
  `plan.line`, `plan.polyline`, `plan.rectangle`, `plan.circle`,
  `plan.arc`, `plan.text` and `plan.symbol`; `plan` is a reserved kit id.
- **`KitWords`** is a kit's `KitNames` seen at one locale, falling back to
  English.
- **The engine's types stay visible to kits** (`DraftDocument`,
  `DraftCommand`, `ParametricType`, `Component`): decision 2 and R5.

## P2. `jet_cad_2d_plan`: the controller and the widgets

### `PlanController`

- **Owns** the validated kit set (P4), the document and its manifest, one
  `ParametricSystem` over one `ParametricCatalog` holding every kit's types,
  the spatial index, page, camera, selection, tool controller, snap
  setting, grip cache (one `ObjectGripProvider` dispatching by type id), the
  attachment registry, `PlanServices` (one view per kit, for `words`), the
  tool settings, the `shared` cache and the diagnostics. The host creates it
  with `PlanController(kits: [...], permissions:, exporters:, importers:)`
  and disposes it.
- **Commands:** `newPlan()`, `load(String)`, `save()` → `String`, `dirty`,
  `markSaved()`, `undo()`, `redo()`, `canUndo`, `canRedo`,
  `selectTool(String id)`, `activeTool`, `deleteSelection()`,
  `export(String exporterId, PlanExportChoice choice)` → `Uint8List`,
  `print(PlanExportChoice choice)`, `import(String importerId, Uint8List
  bytes)`, `missingKits`, `diagnostics`. `PlanExportChoice` is today's
  export choice (page or drawing, resolution, colour) without the format,
  which the exporter's id now names.
- **Events:** `Stream<PlanChange>`: object added, changed, removed; plan
  replaced. Domain-neutral (today's `FloorPlanDesignChange` speaks of
  tables).
- **Swapping documents.** `load`, `newPlan` and `import` replace the
  document inside the controller, install its systems once, and notify. The
  systems belong to the controller, so `DocumentSystems` and its trap are
  not ported.
- **Permissions:** `PlanPermissions`: the allowed tool ids (`null` = all)
  and the flags move, rotate, mirror, reshape, delete, changeLayer, recolor,
  undo, export, print. Enforced at the command level by the controller (a
  widget cannot bypass them). This is the design-mode half of today's
  `FloorPlanEditorCapabilities`; 2b adds the service flags.

### The widgets

Each takes only the controller.

| Widget | Role |
|---|---|
| `PlanCanvas` | Rulers, camera gestures, the interaction layer, page chrome, the drawing, the selection and grip overlay, text entry; fits the plan on its first frame (today's `PlannerView`). 2b adds `PlanMode.service`. |
| `PlanToolPalette` | The generic tools, then each kit's, grouped in kit order; labels from `tool:<id>`; the fill toggle. |
| `PlanSymbolGallery` | The loaded kits' symbols: search over names and tags, categories, retired symbols hidden (R2); choosing one arms `plan.symbol`. |
| `PlanPropertyPanel` | One object selected: its type's specs (P3), or the generic symbol section (name, rotation, mirror, the family's Size menu). Nothing selected: the active tool's settings. The layer field always. |
| `PlanLayerPanel`, `PlanPagePanel` | Today's panels; "live object" comes from the catalog's types (E1). |
| `PlanEditor` | Today's shell layout: top bar; palette or gallery tab on the left; canvas; property, layer and page panels on the right. Parameters choose the visible panels, rulers, grid and snapping, and take the host's file callbacks. |
| `PlanShortcuts` | The keyboard (below). `PlanEditor` wraps itself in it; a host composing its own layout uses it. |

### The keyboard

- File commands (new, open, save, save as, export, print) call the host's
  callbacks, as today; undo and redo; F3 snapping; F fill; Escape back to
  `plan.select`.
- **Tool letters** come from the loaded tools: the plan library's first,
  then the kits' in load order. A letter wanted twice goes to the earlier
  tool; the later one gets none and a diagnostic (A3).
- **Text fields keep their keys:** the guard is built from the letters
  actually in use, not today's fixed list of 16.

## P3. Properties and attachment

### Property specs (A4)

```dart
sealed class PropertySpec<T> {
  final String id;                    // word 'property:<type id>.<id>'
  final bool Function(T)? enabled;
}
final class LengthProperty<T>    extends PropertySpec<T> { read, write, min, max }      // mm
final class AngleProperty<T>     extends PropertySpec<T> { read, write }                // radians stored, degrees shown
final class NumberProperty<T>    extends PropertySpec<T> { read, write, min, max, decimals }
final class ChoiceProperty<T, V> extends PropertySpec<T> { values, read, write }        // words 'property:<id>.<value>'
final class ToggleProperty<T>    extends PropertySpec<T> { read, write }
final class TextProperty<T>      extends PropertySpec<T> { read, write, maxLength }
```

- `read(T)` reads; `write(T, value)` returns a changed copy. The panel
  commits one `SetComponentCommand<T>`; the parametric system regenerates;
  one undo step.
- **Focus rules are today's:** the target is pinned when a field gains
  focus; the value commits on focus loss or Enter. Out-of-range input is
  refused and the field shows the stored value again. Lengths print with
  the plan's decimal separator (Q0).
- **Tool settings** are `PlanToolSettings<S>(initial, specs)`: the
  controller holds one value of `S` per tool, the panel edits it with the
  same specs, the tool reads it through `PlanServices.settingsOf`.
- **The escape hatch:** `section: (context, value, commit) => Widget`, with
  `commit(T)` and the kit's words.
- Multiple selection is out of scope, as today.

### Attachment (A5)

```dart
abstract interface class AttachmentProvider {
  String get kind;                                  // 'wall-face'
  Attachment? attach(AttachmentQuery query);
}
final class AttachmentQuery {
  final Aabb2 footprint;          // the symbol's local box
  final Vector2 pointer;          // raw world point
  final double capture, edgeCapture;
  final bool mirrored;
  final Set<Handle> exclude;      // the object being moved
  final Attachment? keep;         // the previous answer (hysteresis)
}
final class Attachment {
  final Transform2 transform;     // where the symbol goes
  final Vector2 marker;           // where the plan draws its marker
  final Object token;             // the provider's own (a face run)
}
abstract interface class AttachmentRegistry {
  Attachment? attach(List<String> kinds, AttachmentQuery query);
}
```

- The registry asks the providers of every kind in the symbol's `attachTo`;
  when several answer, the marker nearest the pointer wins.
- `plan.symbol` and `plan.select`'s move resolver use the registry alone:
  no `WallFaces` and no `againstWallTag` in the plan library. The plan
  library paints the marker and the ghost, so every kit's attachment looks
  alike. `M` mirrors while attached.
- Today's wall-attach tests (09c) move with the wall-face provider in
  sub-project 3; 2a tests the registry with the test kit's `test-edge`.

## P4. The plan file, the kit set, a missing kit, the failure boundary

### The plan file (A8)

- **Save:** the engine's JSON with `jetcad.manifest` on the root: format 1
  and `{kit id: version}` for each kit the plan uses (a type id or a symbol
  key under that kit's id appears in it). A loaded kit's entry is written
  with its version; a missing kit's entry is kept as read.
- **Load refuses** with `PlanFormatException` and a code: no manifest;
  format above 1; the engine's schema check (unchanged). Load diagnostics
  are kept, not discarded.
- **Versions (R6)** are parsed as semver. A plan saved by a newer version of
  a loaded kit opens with a warning diagnostic. A version that does not
  parse is not compared and never refuses a load.

### The kit set (A3)

`PlanController(kits:)` throws one `ArgumentError` listing every problem:
a duplicate kit id, type id, tool id or `key@N`; the reserved id `plan`; a
type or tool outside its kit's id; each kit's own `validate()`. A letter
wanted twice and an `attachTo` kind no provider offers are diagnostics only.
The new `KitProblemCode` values, and 2b's, land before 0.1.0 (R4).

### A missing kit (A9)

- The plan opens; the missing kit's objects draw as saved and are locked:
  selectable whole, no grips, no property section, no regeneration, not
  moved, not deleted, their children not edited directly.
  `PlanController.missingKits` lists them.
- **The lock** is an expander that runs before the parametric one and
  throws `PlanLocked` for a command touching a locked object. The
  dispatcher calls the expander before applying (Facts), so nothing
  changes; the controller catches `PlanLocked` where it executes.

### The failure boundary (A9)

| Throws | Outcome |
|---|---|
| `generate`, on an edit | The whole command is not applied; the object keeps its last geometry (E2). |
| grips | That object has none; a drag in flight is cancelled. |
| an attachment provider | Taken as no attachment. |
| a tool's factory | The tool is disabled. |
| a tool's event | The tool is cancelled; back to `plan.select`. |
| a property's `write` | The field shows its stored value. |
| a section builder | A small "section failed" box in its place. |

Each produces a `KitDiagnostic` (kit id, type or tool id, code, error), one
per subject and code; `PlanController.diagnostics` is a listenable list.

## P5. Export and import, words, theme

- **Registries (A17.4):** `PlanExporter { id, extension, export(request) }`
  and `PlanImporter { id, extensions, import(bytes) → String }` (a plan's
  text, decision 4). PDF and PNG are built in (`plan.pdf`, `plan.png`); a
  host adds its own. An imported drawing opens as plain geometry with a
  manifest naming no kit (A17.5). A type with `exported: false` is left out
  (today's `exportOmitOwners`). The export dialog and printing work as
  today, listing the registry instead of a closed enum.
- **Words:** `PlanStrings` (English, German, Turkish) holds the plan
  library's own; a kit's words come from `KitNames` with English fallback.
  The locale is the app's `Localizations`.
- **Theme:** `PlanTheme`, a `ThemeExtension`: the generic part of
  `FloorPlanTheme` (canvas, selection, grips, the attachment marker). 2b
  adds statuses and groups. Touch comes from the Flutter layer, as today.

## P6. The remaining contract inputs

- **R2:** `jetcad.symbol` and `CatalogSymbol` gain an optional `retired`
  (absent reads `false`); the gallery hides retired symbols.
- **R3:** `conformance()` gains additive named parameters: type, tool and
  property ids and their words; each id under the kit's id, English
  complete.
- **R5:** `docs/kits.md` says why the engine's types bind the contract and
  what the codec's byte equality means for a kit's CI.
- **R7:** rule 11 refuses an outline whose width `2·area/perimeter` is at or
  under `Tolerance.linear`, instead of its area.
- **R1 and 2b's codes of R4** belong to 2b.

## E. Engine seams (A12)

Each is argued here and lands with its own test.

- **E1 `ParametricCatalog.typeIds`** and **`typeIdOf(CommandTarget,
  Handle)`**: which types are registered, and which one a group is. They
  replace `isParametricObject` and the if-chain of `ObjectGrips`.
- **E2 Atomic refusal of a failing regeneration:** when a type's `generate`
  throws inside an expanded command, the edit applies its own inverse and
  rethrows `ParametricFailure(typeId, error)`; the document is as before.
- **E3 Chained expanders:** `ParametricSystem` exposes its expansion as a
  function instead of only taking the slot, so the controller installs one
  expander: the lock check (P4), then the parametric expansion.

The Flutter layer needs no change.

## Package layout

```
packages/jet_cad_2d_kit/lib/src/kit/   plan_kit, plan_type, plan_tool, plan_services,
                                       properties, attachment, kit_diagnostic
packages/jet_cad_2d_plan/lib/
  jet_cad_2d_plan.dart                 the barrel
  src/controller/                      PlanController, permissions, services, shared cache
  src/kits/                            kit-set validation, catalog and grip composition, guard
  src/file/                            manifest, load, save, PlanFormatException
  src/canvas/  src/panels/  src/editor/  src/shortcuts/
  src/tools/                           the generic tools, plan.symbol, the move resolver
  src/attach/                          the registry, marker painting
  src/export/                          the registries, PDF, PNG, print
  src/l10n/  src/theme/
packages/jet_cad_2d_plan/example/      PlanEditor with no kit
```

## Tests

- **The test kit** (`test/support/test_kit.dart`): one parametric type with
  all six property kinds, grips and an escape-hatch section; one tool with
  settings; a `test-edge` attachment provider; English and Turkish words,
  no German (the fallback).
- **The throwing kit:** every hook throws; one named mutant per hook (the
  guard removed) turns a test red.
- **Each widget alone,** with only a controller: the composition is real.
- **Ported, assertions unchanged (A12):** selection and its band, layers,
  page, undo, export, text entry, the shortcut guard, the panel-focus traps
  (Plan 06's lessons).
- **The invariant:** a paint-allocation test for the plan library's canvas
  (A12, CLAUDE.md).
- **The engine seams** each with a test whose named mutant is the seam
  removed.
- **The manifest:** refusals by code; a missing kit's entry kept on save; a
  newer kit warns; an unparseable version opens.

## Exit gate

- CLAUDE.md's gates, `jet_cad_2d_kit`'s and `jet_cad_2d_plan`'s
  (`flutter test`, `flutter analyze`, `dart format`), `cd tool/ci && dart
  test`, `dart run tool/ci/check_kit_deps.dart`.
- CI: a `jet_cad_2d_plan` job and a publishable dry-run entry (0 warnings).
- One Opus review of the whole branch; its fix wave; the ledger archived
  onto the branch as its last commit.
- The old packages untouched (A12).

## Out of scope

- The service mode and everything in decision 1's 2b list; R1.
- The architecture kit's types, the furniture library, the wall-face
  provider (sub-project 3); the restaurant kit, demos, pictures, the host
  guide and parity (sub-project 4).
- Multiple selection in the property panel.
- Renaming the engine's `Draft*` family (decision 4).

## Risks

- **The contract settled against a test kit only.** Sub-project 3's six
  types are the real test; a field they need goes into this spec as an
  amendment before the wave publishes 0.1.0.
- **E2 touches the parametric core.** Its test fires a mutant per path
  (inverse not applied, error swallowed).
- **The size of the port.** The ported tests are the oracle (A12).

## Amendment to the umbrella spec

A13's sub-project 2 is carried by two specs: this one (2a) and 2b's (the
service mode). A6's "sub-project 3's spec fixes the names" of the service
API reads "2b's spec".
