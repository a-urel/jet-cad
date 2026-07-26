# jet_cad_2d Architecture Design

**Date:** 2026-07-27
**Status:** Approved — Architecture v1.0 (frozen; evolves only on concrete implementation findings)

## Summary

`jet_cad_2d` is a pure-Dart 2D CAD engine and a Flutter widget layer built on it.
It targets two consumers from one codebase: a WYSIWYG **designer** for authoring
plans (walls, regions, furniture), and a lightweight **viewer** for runtime use
(a point-of-sale app showing a restaurant floor plan, selecting a table, acting
on it).

The engine carries no native dependency. It does not use OCCT, does not build
C/C++, and does not require Impeller or the Flutter master channel. It renders
with Flutter's own `Canvas`. Consequently every Flutter target — web, iOS,
Android, macOS, Windows, Linux — is available from day one.

The long-term interoperability goal is **lossless DXF round-trip**. That goal
does not appear in the first milestones, but it constrains the document model
from day one: the model is DXF-shaped even while the on-disk format is our own.

## Relationship to `jet_cad` (3D)

`packages/jet_cad` (OCCT-backed 3D engine, v0.3.0) is **frozen and archived**.
`jet_cad_2d` is independent: it does not depend on it, does not link OCCT, and
shares no code with it. The name expresses brand lineage, not a dependency.

Two patterns are deliberately reused from the 3D package because they proved
correct there, but as patterns only — the code is not shared:

- Damage-driven repaint (repaint on events, not on vsync).
- A change stream the widgets subscribe to, instead of rebuilding widget trees.

The 3D package's `CadDocument` is explicitly **not** reused. Its `Entity` is
metadata-only ("never geometry"), its undo is bound to `KernelSnapshot`, and
every operation returns an `IdRemap`. That is the right shape for a parametric
B-rep kernel and the wrong shape for 2D drafting, where geometry *is* the
document and direct manipulation must reach coordinates synchronously.

If OCCT ever returns to this project, the likely reason is full 3D IFC/BIM
support, not 2D CAD. Archiving rather than deleting `jet_cad` preserves that
option.

## Non-goals

Frozen for this architecture. Each may become a separate spec later; none may
be assumed by implementation work under this one.

- 3D of any kind.
- **DWG**. No open, license-compatible DWG reader exists (LibreDWG is GPL-3,
  incompatible with this repository's Apache-2.0 licensing; ODA's SDK is
  commercial). DWG is handled — if at all — as an *external* conversion to DXF,
  outside the engine.
- IFC export.
- Constraint solver / parametric sketching.
- Paper space, layouts, plotting.
- DIMENSION **editing**. A DXF DIMENSION stores both a definition and an
  anonymous block holding the geometry that was drawn for it. On import that
  block becomes an ordinary `Definition` plus `InstanceNode`, so dimensions
  display correctly, while the DIMENSION's own tags are preserved verbatim for
  export. A DIMSTYLE generation engine — required to *edit* a dimension and have
  its geometry regenerate — is out of scope.
- SHX font interpretation. SHX text maps to TTF for display.
- Batteries-included UI (toolbars, layer panels, property inspectors). The
  packages ship widgets and tool classes; applications compose the UI. This
  matches the boundary already set by the 3D architecture.
- Real-time multi-user collaboration. The command model does not preclude it;
  nothing implements it.
- Polygon boolean/offset (Clipper-class algorithms). Deferred until hatch
  boundaries or wall offsets actually require them.

## Decisions

| Question | Decision |
|---|---|
| Language / runtime | Pure Dart. No FFI, no native build, no WASM dependency |
| Rendering | Flutter `Canvas` / `CustomPainter` |
| Platforms | All Flutter targets from v1 (web, mobile, desktop) |
| Geometry kernel | None. 2D analytic geometry written in-package; no topology layer |
| Document identity | Single handle space, integer handles, DXF-native |
| Structure | Scene tree: `GroupNode` / `InstanceNode` / `Definition` + leaf entities |
| Leaf transforms | None. Leaf coordinates live in owner space; only containers carry transforms |
| Layers | Orthogonal to the tree, with DXF `BYLAYER` / `BYBLOCK` inheritance |
| Extensibility | Data-only components in sparse, type-keyed stores |
| Widget shape | One primitive (`DraftCanvas`) plus thin presets (`DraftViewer`, `DraftDesigner`) |
| Editing granularity | Capability set (`transform` / `components` / `geometry` / `structure`), not a boolean |
| Canonical file format | Versioned JSON, deterministic byte output |
| Foreign formats | Separate adapter packages; the engine never names a format |
| Interop end goal | Lossless DXF round-trip; IFC plan-only import |

---

## Architecture

### Repository layout

```
jet-cad/  (pub workspace)
├── packages/
│   ├── jet_cad_2d/            # pure Dart. Engine + document. No Flutter, no OCCT
│   ├── jet_cad_2d_flutter/    # Canvas renderer, DraftCanvas/Viewer/Designer, tools
│   ├── jet_cad_2d_dxf/        # future — DXF adapter
│   ├── jet_cad_2d_ifc/        # future — IFC plan-only import adapter
│   └── jet_cad/               # 3D/OCCT — frozen at 0.3.0, archived
└── apps/
    └── jet_cad_2d_harness/    # development app: tool palette, panels (never shipped in a package)
```

Dependency direction is one-way: `jet_cad_2d ← jet_cad_2d_flutter`, and each
format adapter depends on `jet_cad_2d`. Nothing depends on a format adapter
except an application that chooses one.

`jet_cad_2d` having no Flutter dependency is deliberate: format conversion can
run server-side, and engine tests run under `dart test`.

Class names keep a `Draft` prefix (`DraftDocument`, `DraftCanvas`). Package
names carry the brand; class names carry ergonomics.

### Document model

#### Identity

Every addressable thing — node, entity, layer, linetype, text style, block
definition — has a handle from one shared space.

```dart
extension type const Handle(int value) {
  String toHex() => value.toRadixString(16).toUpperCase();
}
```

The document holds a monotonically increasing seed (DXF `$HANDSEED`).

**Web constraint:** under `dart2js`, `int` is a JS number with 53 bits of
integer precision. Real DXF handles stay far below that, but import must
range-check and fail loudly rather than silently truncate.

#### Structure

```
DraftDocument
  header       units ($INSUNITS), scale, handseed, extents, custom variables
  tables       layers · linetypes · textStyles · dimStyles · patterns · appIds
  definitions  Handle → Definition      (block prototypes)
  root         GroupNode                (model space)
  nodes        Handle → Node            (flat lookup)
  entities     Handle → Entity          (leaves)
  geometry     GeometryStore            (structure-of-arrays coordinates)
  components   ComponentRegistry        (sparse, type-keyed)
  rawTags      Handle → List<RawTag>    (preserve-unknown slot)
  schemaVersion
```

#### Nodes and entities

```dart
sealed class Node {                    // CONTAINER — carries a transform
  Handle handle;
  Handle? parent;
  Transform2 transform;
  bool visible;
}
final class GroupNode    extends Node { List<Handle> children; }
final class InstanceNode extends Node {
  Handle definition;
  Handle layer;
  Map<String, String> attributes;      // DXF ATTRIB
}

final class Entity {                   // LEAF — no transform
  Handle handle;
  Handle owner;
  EntityKind kind;                     // line, polyline, arc, circle, text, …
  Handle layer;
  int geomIndex;                       // index into GeometryStore
}
```

Leaves carry no transform. This is simultaneously DXF-correct (in DXF only
INSERT has a transform; entity coordinates live in their owner's space) and
performance-correct (a million lines cost no matrices and no per-entity node
objects). It also produces the natural editing split: moving a group changes a
transform; moving a single line changes coordinates.

`Definition` is a reusable prototype subtree; `InstanceNode` references one.
Nested instances are permitted; **cycle detection is required**.

This pair is the same concept as Unity's prefab/instance and as DXF's
BLOCK/INSERT — and, as the mapping table below shows, as IFC's type/occurrence.

#### Layers

A layer assignment is orthogonal to tree position: an entity's layer does not
depend on its parent. Visibility is the conjunction of two independent
switches — a layer may be off, a node may be hidden.

Two DXF inheritance rules are part of the model contract, not a rendering
detail, because imported files render incorrectly without them:

- An entity on layer `0` inside a block definition inherits the layer of the
  INSERT that placed it.
- A `BYBLOCK` color/linetype resolves against the instance chain; `BYLAYER`
  resolves against the layer.

#### Components

```dart
abstract class Component {
  String get typeId;                   // 'jetcad.table', 'acme.plumbing'
  Map<String, Object?> toJson();
}

class ComponentStore<T extends Component> { final Map<Handle, T> byHandle; }

class ComponentRegistry {
  final Map<String, ComponentStore> _typed;
  final Map<Handle, List<Map<String, Object?>>> _unknown;   // preserved verbatim
}
```

Rules:

- **Data only, never behavior.** The document must stay serializable,
  deterministic and undoable; behavior lives in application-side systems.
- Attach to nodes and entities alike — one handle space, one mechanism.
- Components are stored in sparse type-keyed stores, *not* as a map on each
  entity. This keeps entity objects lean at scale and makes the runtime's core
  query — "every handle with a `TableComponent`" — proportional to the component
  count rather than the entity count.
- Unknown `typeId`s are preserved as raw JSON.
- Built-in components may be marked `internal`, meaning they are never written
  to foreign formats as extended data.

Application-domain concepts (table, zone, seat count) are components and block
attributes. **The engine defines no domain types.** Runtime state (occupied,
reserved) is not in the document at all; it is supplied to the view layer.

#### Geometry store

Leaf coordinates live in typed arrays (`Float64List` plus offset tables),
grouped by kind; the entity holds only an index. The frozen decision is
structure-of-arrays with index-only entities; the exact packing is an
implementation detail. Rationale: per-entity object churn is what kills large
documents, and the data layout cannot be retrofitted later.

#### Change and undo

Command pattern: every command produces its inverse. The document publishes a
`DocChange` stream; widgets subscribe rather than rebuilding.

Undo here is a plain value diff. The 3D package's undo pattern is reused, its
implementation is not — there is no kernel and therefore no snapshot.

Each command declares which capability it requires (see *Interaction*), and the
dispatcher rejects unauthorized commands in one place.

#### Preserve-unknown

`rawTags` is unused until DXF import exists. The slot is present from day one
because it cannot be added retroactively without rewriting the model.

### Geometry engine

#### Tolerance — two distinct concepts

```dart
class Tolerance {
  final double linear;    // document units — geometric equality
  final double angular;   // radians
}

double worldPickRadius(double screenPx, double scale) => screenPx / scale;
```

**Geometric tolerance** is absolute, tied to document scale, unaffected by zoom:
it answers "are these two points the same point". **Interaction tolerance** is
measured in screen pixels and converted to world units per zoom level: it
answers "did the user click here". Collapsing them into one number makes
geometric equality zoom-dependent.

`==` on doubles is prohibited. Coordinates are `Float64` in document units.
Screen coordinates never enter the model.

#### Spatial index — two-level, definition-shared

```
Top level:   world-space AABBs of root-level nodes (instances, groups, entities)
Definition:  local-space AABBs of that definition's entities — built once, shared
```

A world query hits the top level, then inverse-transforms the query rectangle
into each hit instance's local space and queries that definition's own index.
Nested instances recurse with composed transforms.

This matters because floor plans are repetitive: 500 identical tables share one
index; dragging a table updates one top-level record rather than one per
entity; editing the definition rebuilds one shared index rather than 500.

Index implementation: a packed R-tree (STR bulk-load, typed arrays) plus a small
linearly-scanned dirty list for recently edited entities, rebuilt when the dirty
list exceeds a threshold. This avoids dynamic R*-tree complexity and matches the
real usage profile of long reads punctuated by short edit bursts.

#### Hit-testing — the engine returns a path, not a decision

```dart
class HitPath {
  final List<Handle> chain;      // root → … → leaf
  final Handle entity;
  final Vector2 worldPoint;
  final HitKind kind;            // vertex | edge | fill
}
```

The engine reports what was hit; policy lives in the widget layer. `DraftViewer`
selects `chain.first` (the top-level instance — tapping a chair selects its
table). `DraftDesigner` additionally supports descending into a group on
double-click.

Priority: vertex/endpoint → edge → fill; ties broken by topmost node, then draw
order. **Query results must be stably ordered** (by handle or draw order). Hash
iteration order makes tests flaky and selection jump.

#### Snapping

| Snap kind | Cost |
|---|---|
| endpoint, midpoint, center, quadrant, insertion | cheap — constant per entity |
| nearest, perpendicular, tangent | moderate — one projection per entity |
| intersection | expensive — pairwise among candidates in the query rect |
| grid, ortho/polar | free — no geometry query |

One best candidate is returned, ordered by (kind priority, distance).
Intersection snapping considers only candidates inside the query rectangle, with
a candidate cap.

**Hard budget: a snap query allocates nothing and completes in under 1 ms.** It
runs at pointer-move rate. This shapes the API — results are written into a
preallocated buffer.

Snapping crosses instance boundaries (snapping to a chair's corner inside a
table instance) and returns a world point plus a `HitPath`. Snapping is an
engine service, available to any tool, in the viewer as well as the designer.

#### Queries

```dart
Iterable<Handle> entitiesInRect(Aabb2 world);           // render culling
HitPath?         pick(Vector2 world, double radius);
SnapResult?      snap(Vector2 world, double radius, SnapMask mask);
Iterable<Handle> withComponent<T extends Component>();  // runtime lookup
Iterable<Handle> onLayer(Handle layer);
Iterable<Handle> instancesOf(Handle definition);
```

#### No topology

2D CAD needs no B-rep topology layer. Entities are independent geometries; a
"room" is a closed polyline, not a topological face. Holding this line is what
keeps the engine small and pure Dart.

In scope now: intersection, distance, trim/extend, 2D fillet/chamfer — pairwise
analytic math. Deferred: polyline offset and polygon boolean, written in Dart
when hatch boundaries or wall offsets require them.

### Rendering

#### Camera

A single `Matrix3` (world → screen) carrying pan, zoom and optional rotation.
`CameraController` is a `ValueNotifier`; a change repaints inside a
`RepaintBoundary` without rebuilding the widget tree.

#### Two-level picture cache

Mirroring the spatial index:

1. **Definition cache** — each `Definition` is recorded once into a `Picture`;
   every instance replays it under its own transform.
2. **Tile cache** — static root-level geometry is recorded into world-space
   tiles. Panning replays tiles; crossing a zoom band invalidates them.

Culling uses `entitiesInRect` against the visible world rectangle.

Geometry is drawn under `Canvas.transform`; screen-space decorations (handles,
snap markers, selection) are drawn in a separate pass at constant pixel size.

#### Damage model

Repaint on events, never per vsync. Triggers: `DocChange`, camera change,
selection change, `StyleResolver` invalidation, tool state change. A CAD
viewport is idle most of the time.

#### Draw order

```
tile / geometry cache        static
entity under active edit     live, outside the cache
selection highlight, handles screen space
snap indicators              screen space, whenever a tool requests snapping
application overlay          widgets (see Interaction)
```

#### Three CAD subtleties that reach the renderer

1. **Lineweight is a paper-space width, not a world width** (DXF stores 1/100 mm).
   It does not grow with zoom. The renderer picks an explicit policy — fixed
   pixels, or scaled by print scale. Treating it as a world unit makes walls
   swell on zoom.
2. **Linetype dashes are likewise in paper units**, multiplied by global
   `$LTSCALE` and a per-entity scale. Flutter's `Canvas` has no dash API; path
   splitting is written by hand. This is a real, sized task.
3. **Transparency** is an independent DXF field (0–255) that may itself be
   `BYLAYER`/`BYBLOCK`; it resolves separately from color.

### Interaction

#### Tools are open-ended

```dart
abstract class InteractionTool {
  void onPointerDown(ToolContext ctx);
  void onPointerMove(ToolContext ctx);
  void onPointerUp(ToolContext ctx);
  Widget? buildOverlay(BuildContext context, ViewportTransform vt) => null;
}
```

`DraftCanvas` takes a tool list. The engine ships geometric tools (`SelectTool`,
`MoveTool`, `RotateTool`, `LineTool`, `RegionTool`, …); an application writes
its own domain tools (assign an order to a table, merge two tables) and adds
them to the same list.

This distinction is load-bearing: **geometric tools mutate geometry; application
actions mutate component data or application state.** The engine must not know
the second kind, but it must expose the hooks they need, or applications will
route around the canvas.

#### Overlays are widgets, not painted pixels

```dart
class ViewportTransform {
  Offset  worldToScreen(Vector2 world);
  Vector2 screenToWorld(Offset screen);
  Rect    screenRectOf(Handle handle);
  double  get scale;
}

// DraftCanvas parameter:
final Widget Function(BuildContext, ViewportTransform)? overlayBuilder;
```

Runtime tooling needs tappable, themed, animated Flutter widgets anchored to
world positions — context menus, status badges, floating action bars. A
`CustomPainter` cannot provide them. The application positions real widgets
using `ViewportTransform`, which is republished when the camera changes.

#### Selection is first-class

```dart
class SelectionController extends ChangeNotifier {
  Set<Handle> get selection;                  // multi-select
  Stream<SelectionChange> get changes;
}
```

Selection cannot be private widget state: the canvas and the application's own
panels observe the same selection.

#### Capabilities, not an `editable` flag

```dart
class DraftPermissions {
  final bool transform;    // move/rotate an instance
  final bool components;   // edit component data
  final bool geometry;     // change coordinates, add/remove entities
  final bool structure;    // change the tree, definitions, groups
}
```

A point-of-sale runtime uses `transform: true, components: true,
geometry: false, structure: false` — staff may move a table and change its
properties, but cannot draw walls or alter a block definition.

This decomposition is only possible because leaves carry no transform: moving an
instance and editing geometry are already distinct operations.

Undo exists in the viewer too — a misplaced table must be recoverable. Runtime
may cap stack depth; the mechanism is the same.

#### Widget presets

```dart
class DraftCanvas   extends StatefulWidget { … }   // camera, painting, hit-test, tools
class DraftViewer   extends StatelessWidget { … }  // preset: [SelectTool()]
class DraftDesigner extends StatefulWidget { … }   // preset: geometric tools + snap + undo bindings
```

There are not two parallel widgets; there is one primitive and two thin presets,
with everything in between expressible by composing a tool list and a permission
set.

A mode flag on a single widget was rejected for a measurable reason: a widget
that dispatches to the tool state machine on a flag makes tool code *reachable*,
so Dart's tree shaker cannot remove it, and a viewer-only application still
ships the whole editor. Layered composition keeps the reachability boundary and
therefore the bundle size.

### Appearance model

#### Two tiers

| Tier | Contents | Round-trip |
|---|---|---|
| CAD-native style | color, linetype, lineweight, transparency, fill | lossless — native DXF fields |
| Rich appearance components | raster textures, custom gradients, render hints | lossy — preserved as extended data, approximated on export, reported as a `Diagnostic` |

#### Color resolution

```dart
sealed class DraftColor {}
class ByLayer   extends DraftColor {}
class ByBlock   extends DraftColor {}
class Indexed   extends DraftColor { final int aci; }     // DXF ACI 1–255
class TrueColor extends DraftColor { final int argb; }
```

Effective color resolves in this order:

```
application runtime override (StyleResolver)   ← highest: "occupied table is red"
  else entity color
    if ByBlock → the instance chain's color
    if ByLayer → the layer's color
      else default
```

`StyleResolver` maps `(entity, instance chain, application state) → paint`. It
is the single place where both the authored appearance and the runtime override
are resolved, and it is shared by viewer and designer.

Per-instance color is how "table color" works: geometry inside the definition is
authored `ByBlock`, and each `InstanceNode` carries its own color. 500 tables
share one geometry and render in different colors, and this round-trips to DXF
losslessly. Runtime status coloring sits above this as a separate layer and
never touches the document, so the two never overwrite each other.

#### Fills and floor patterns

The model follows DXF: a **boundary entity** and an **associated fill entity**,
separate but linked, with the fill updating when the boundary changes.

```dart
sealed class Fill {}
class SolidFill    extends Fill { DraftColor color; }
class GradientFill extends Fill { DraftColor a, b; double angle; GradientKind kind; }
class PatternFill  extends Fill { String name; double scale, angle; DraftColor color; }
class ImageFill    extends Fill { Handle imageRef; Transform2 placement; }   // lossy
```

The first three map losslessly to DXF HATCH. `ImageFill` maps to a DXF raster
image reference when the source raster is available to the exporter, and
otherwise degrades to a solid fill using the fill's dominant color; either way
the outcome is reported as a `Diagnostic`.

The model is not simplified into a single region entity, because non-associative
hatches and multi-loop boundaries would not fit and round-trip fidelity would
suffer. Instead the *tool* is simplified: a single region tool creates and edits
the boundary/fill pair, and the user never sees two entities. Complexity is
confined to one tool rather than embedded in the model.

A region is also the natural target for IFC's `IfcSpace`: a closed boundary plus
a component. A floor pattern is that region's fill.

Pattern rendering generates vector line geometry clipped to the boundary, cached
as a `Picture` keyed by `(pattern, scale, angle, boundary)` inside the existing
tile cache and invalidated on zoom-band change. A repeating-shader fast path may
be added if profiling requires it; it is not written now.

The `patterns` table holds hatch pattern definitions. A small embedded subset of
the standard patterns ships with the package; custom patterns are stored in the
document.

### Persistence and versioning

The canonical format is **JSON**: diffable in git, debuggable, and migratable.
A floor plan is thousands of entities, not millions, so the cost is irrelevant.
Compression is optional gzip.

If storing a very large imported drawing in our own format ever becomes a
bottleneck, a binary serialization may be added behind the same schema. It is
not written now.

- `schemaVersion` is an integer. A migration chain converts old versions
  forward; each migration is a pure function with its own fixture test. An
  unversioned document is not readable.
- **Deterministic output:** the same document serializes to byte-identical JSON.
  Key ordering is stable; hash iteration order is prohibited in serialization.
  Meaningful git diffs and byte-identity round-trip tests both depend on this.
- Plan 1 ships only a minimal round-trip codec plus the `schemaVersion` field.
  Migration infrastructure, file I/O and autosave arrive with Plan 5.

#### One recurring invariant

The same rule appears in three places, which makes it an architectural
invariant rather than a coincidence:

| Layer | Unknown data |
|---|---|
| DXF import | unrecognized entities and group codes → `rawTags` |
| Component registry | unrecognized `typeId` → raw JSON |
| Own format | unrecognized field → preserved |

**No layer discards data it does not understand.** Every codec has a test that
proves it.

### Format-at-the-edge contract

```dart
abstract class DraftImporter {
  Future<ImportResult> import(Uint8List bytes, ImportOptions options);
}
class ImportResult {
  final DraftDocument document;
  final List<Diagnostic> diagnostics;   // skipped, approximated, preserved
}

abstract class DraftExporter {
  Future<ExportResult> export(DraftDocument doc, ExportOptions options);
}
class ExportResult {
  final Uint8List bytes;
  final List<Diagnostic> lossy;         // everything not representable
}
```

Three frozen rules:

1. **Adapters use only the public document API.** They never reach into engine
   internals. This is what allows them to live in separate packages.
2. **The engine names no format.** The string `dxf` or `ifc` does not appear in
   `jet_cad_2d`, with the single exception of the `OriginComponent.source` enum.
3. **Loss is declared, not discovered.** Every exporter enumerates what it could
   not represent. Silent data loss is a defect.

#### Identity across formats

Renumbering handles on import silently breaks references inside preserved raw
data. The fix is a built-in component rather than a new mechanism:

```dart
class OriginComponent implements Component {
  final SourceKind source;   // dxf | ifc | native
  final String id;           // DXF handle (hex) | IFC GlobalId
}
```

Export reuses the original identifier when present and mints a new one
otherwise, so merging two files cannot collide. `OriginComponent` is `internal`
and is never written as extended data.

#### Concept mapping

| Internal | DXF | IFC |
|---|---|---|
| `Handle` | handle (hex) | `GlobalId` |
| `Definition` | BLOCK / BLOCK_RECORD | `IfcTypeObject` (`IfcFurnitureType`, …) |
| `InstanceNode` | INSERT | occurrence + `IfcRelDefinesByType` |
| `GroupNode` | anonymous block / GROUP | `IfcGroup` / `IfcZone` |
| leaf entity | LINE, LWPOLYLINE, ARC, … | representation item / profile |
| `Component` | XDATA / XRECORD | `IfcPropertySet` + `IfcRelDefinesByProperties` |
| instance attribute | ATTRIB | property set on the occurrence |
| layer | LAYER table | weak — `IfcPresentationLayerAssignment` |
| units | `$INSUNITS` | `IfcUnitAssignment` |
| region (closed boundary + component) | LWPOLYLINE + HATCH | `IfcSpace` |
| root | model space | `IfcProject → Site → Building → BuildingStorey` |

The `Definition`/`InstanceNode` split is exactly IFC's type/occurrence pattern,
and `Component` is exactly `IfcPropertySet`. The model was designed against DXF
blocks and fits IFC without adaptation, because both encode the same industry
reality: a shared type, a placed occurrence, and properties attached to the
occurrence. This is the strongest available evidence that IFC support will not
require architectural debt.

Layers are the weak link — IFC has no true equivalent. This is an accepted loss,
declared on export.

#### DXF format notes carried into the adapter's design

Recorded here so they are not rediscovered:

- Real-world DXF diverges from the published reference. Autodesk documents the
  format but owns it; there is no standards body and the documentation is
  incomplete. `ezdxf` (Python, MIT) is the de facto knowledge base and
  independently implements the preserve-unknown pattern.
- Pre-R2007 DXF is not UTF-8. It uses `$DWGCODEPAGE` (cp1254 for Turkish) plus
  `\M+` escapes. Naive UTF-8 reading corrupts text irreversibly on round-trip.
  Code page support is required in the parser from the start.
- DXF is 3D throughout: "2D" entities carry an extrusion direction (group code
  210) and live in an object coordinate system. Flattening naively to x/y breaks
  round-trip for mirrored or rotated drawings; OCS must be preserved.
- DIMENSION stores both a definition and an anonymous block of the drawn
  geometry, which is why round-tripping dimensions is possible while editing
  them is out of scope.
- The DXF work splits naturally into a format-only layer (group codes, tables,
  entity graph, preserve-unknown — publishable standalone as `jet_dxf`) and an
  adapter to `DraftDocument`. Whether to actually split the packages is deferred
  to the DXF plan.

---

## Testing strategy

| Test | Guarantees |
|---|---|
| round-trip property: `doc → save → load → structural equality` | codec integrity |
| byte identity: `save(load(x)) == x` | deterministic serialization |
| migration fixtures, one document per historical version | backward compatibility |
| unknown-preservation: injected foreign field / component / tag survives | the recurring invariant |
| synthetic benchmark at 50k and 500k entities | the rendering scale assumption |
| (format plans) **real-file corpus** — AutoCAD, BricsCAD, QCAD, LibreCAD, Revit exports | conformance to reality |

The last row is the standard for format work: the criterion is not "does it
match the specification" but "does round-trip survive files produced by real
applications". The corpus starts being collected in the DXF plan.

Engine tests run under `dart test` with no Flutter dependency. Widget-layer
tests use `flutter_test`; rendering goldens are limited to the widget package.

## Roadmap

| Plan | Scope |
|---|---|
| **1** | Handles, document, tree, components, layer/style tables, tolerance and geometry primitives, structure-of-arrays store, command/undo/`DocChange`, minimal JSON codec |
| **2** | Two-level spatial index, hit-testing and `HitPath`, snap engine, query API, **scale benchmark** |
| **3** | Camera, definition and tile picture caches, `StyleResolver` and resolution order, fills/patterns/dashes/lineweight, damage model, `DraftCanvas` |
| **4** | `InteractionTool`, `SelectionController`, `DraftPermissions`, `ViewportTransform` and `overlayBuilder`, geometric tool set, `DraftViewer`/`DraftDesigner` presets, harness |
| **5** | `schemaVersion` and migration chain, file I/O, autosave and recovery, deterministic serialization, unknown-preservation tests |
| future | DXF import · IFC plan-only import · DXF round-trip export |

### Validation gate

Plan 2 ends with a synthetic benchmark: generated documents of 50k and 500k
entities, measuring frame time during pan and zoom. Flutter `Canvas` performance
at this scale is the architecture's largest unvalidated technical assumption and
must not survive past Plan 4 unmeasured — the cost of reversing it grows sharply
after the render and interaction layers are built on it.

### First milestone success criteria

In the harness: draw walls → define a table block → place 200 instances →
select and move one with snapping → color instances by runtime state → save and
reload → sustain 60fps pan/zoom on a 50k-entity document.

## Open decisions

- **Order of the two importers.** DXF import is cheaper (roughly 2–4 weeks
  versus 4–6 for IFC plan extraction) and more widely applicable, since every
  venue has a drawing while few have a BIM model; IFC carries richer semantics.
  This architecture makes both equally reachable and does not decide the order.
- **Whether to split `jet_dxf` out of `jet_cad_2d_dxf`.** Deferred to the DXF
  plan.

## Risks

| Risk | Where it is addressed |
|---|---|
| Flutter `Canvas` insufficient at 500k entities | Plan 2 benchmark gate |
| Web `int` is 53-bit; handle overflow | Plan 1 — range check on import |
| Flutter has no dash API; written by hand | Plan 3 task |
| The assumption that AutoCAD preserves foreign XDATA is unverified | DXF plan — real-file corpus |
| Hatch pattern generation cost at large scales | Plan 3 — picture cache; shader fast path held in reserve |
