# jet_cad_2d Architecture Design

**Date:** 2026-07-27
**Status:** Approved — Architecture v1.2 (frozen; evolves only on concrete implementation findings)

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
- **External references (xrefs).** An xref INSERT names a drawing this engine
  will not load. Xref block records and their inserts are preserved verbatim for
  export and render as their insertion-point marker only. Resolving, editing or
  binding an xref is out of scope.
- DIMENSION **editing**. A DXF DIMENSION stores both a definition and an
  anonymous block holding the geometry that was drawn for it. On import that
  block becomes an ordinary `Definition` plus `InstanceNode`, so dimensions
  display correctly, while the DIMENSION's own tags are preserved verbatim for
  export. A DIMSTYLE generation engine — required to *edit* a dimension and have
  its geometry regenerate — is out of scope.
- SHX font interpretation. SHX text maps to TTF for display; glyph shapes and
  advance widths will differ from AutoCAD's. Declared lossy for display, lossless
  for round-trip (the style record is preserved).
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
| Document identity | Single handle space, integer handles, DXF-native, `Handle.none == 0` |
| Structure | Scene tree: `GroupNode` / `InstanceNode` / `Definition` + leaf entities |
| Leaf transforms | None. Leaf coordinates live in owner space; only containers carry transforms |
| Container transform | Full 2×3 affine — DXF INSERT permits non-uniform and negative scale |
| Entity records | Columnar (structure-of-arrays), including tier-1 style; `Entity` is a view |
| Layers | Orthogonal to the tree, with DXF `BYLAYER` / `BYBLOCK` inheritance |
| Style resolution | Explicit `StyleResolver` producing a value-equal `StyleContext`; it is the picture-cache key |
| Cache invalidation | Two channels: `documentRevision` (global, rare) and per-instance `overrideChanges` (local, frequent) — runtime state never invalidates globally |
| Derived vs stored | Explicit split; extents, resolved style, world transforms and text layout are derived and never persisted |
| Render precision | World coordinates rebased to a local origin before reaching `Canvas` (Skia is float32) |
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
    ├── dev_harness/           # existing 3D harness — stays with the frozen package
    └── jet_cad_2d_harness/    # new: tool palette, panels (never shipped in a package)
```

The 2D harness is **greenfield**, not a retarget of `apps/dev_harness`. That app
is wired to the 3D session, texture viewport and controller, none of which
survive here. Its shadcn ribbon shell
([2026-07-12-harness-shadcn-ribbon-design.md](2026-07-12-harness-shadcn-ribbon-design.md))
is UI-only and is a **source to copy from**, not a dependency — Plan 4 is sized
on the assumption that the shell is lifted and the rest is written.

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
  static const none = Handle(0);          // DXF treats handle 0 as invalid
  bool get isNone => value == 0;
  String toHex() => value.toRadixString(16).toUpperCase();
}
```

`Handle.none` is the absent value. Fields do not use `Handle?`; a nullable
handle and an implicit zero would both appear and diverge.

**Erasure:** an extension type is compile-time only. `Map<Handle, X>` and
`Map<int, X>` are the same type at runtime, and a JSON decoder hands back bare
`int`s. Codecs must wrap explicitly at the boundary; the type gives static
safety, never a runtime check.

**The handle space is 32-bit.** This is a document invariant on every platform,
not a web quirk: entity columns store handles in `Uint32List` (see *Entity
records*), so 2^32 is the ceiling everywhere. Long-lived drawings do exceed it,
so import range-checks against 32 bits and fails loudly rather than truncating.
The escape hatch is **handle-space compaction on import** — renumber into a
dense range — which is safe precisely because `OriginComponent` preserves each
original identifier for export.

The `dart2js` 53-bit integer limit is therefore not the binding constraint, but
it is another reason no code may assume 64-bit handles.

#### Structure

```
DraftDocument
  header       units ($INSUNITS), scale, handseed, custom variables,
               importedExtents (opaque, round-trip only — never recomputed)
  tables       layers · linetypes · textStyles · dimStyles · patterns · appIds
  definitions  Handle → Definition      (block prototypes)
  root         GroupNode                (model space)
  nodes        Handle → Node            (containers only — see below)
  entities     EntityStore              (columnar leaf records, incl. tier-1 style)
  geometry     GeometryStore            (columnar coordinates)
  components   ComponentRegistry        (sparse, type-keyed)
  rawTags      Handle → Map<SourceKind, Object?>   (preserve-unknown slot, opaque)
  schemaVersion
```

The preserve-unknown slot is an **opaque per-source blob**, not a list of DXF
group codes. Its payload shape is owned entirely by the adapter that produced
it; the engine only stores, serializes and returns it. Naming it `RawTag` would
have put a DXF concept in the core document.

#### Derived versus stored

Every value in the document is one or the other, and the distinction is load-
bearing rather than descriptive: derived state that leaks into stored bytes
breaks determinism, and derived state that leaks into a document-level revision
counter breaks caching.

| Stored | Derived — never persisted, never versioned |
|---|---|
| header, tables, definitions, nodes, entity records, geometry, components, `rawTags` | working extents |
| `importedExtents` — preserved verbatim from an imported file for round-trip, never recomputed from geometry | world transforms and their cache |
| | spatial index |
| | resolved style (`StyleContext`, `ResolvedStyle`) |
| | runtime style overrides |
| | text layout boxes |

Working extents are recomputed on load and after edits. They are not persisted
because a text entity's contribution comes from a platform- and font-dependent
layout, so persisting them would make the same document serialize differently on
two machines — defeating both the determinism guarantee and the round-trip
property test. `importedExtents` is a separate, opaque header value that exists
only so `$EXTMIN`/`$EXTMAX` survive a round-trip unchanged.

#### Transforms

```dart
/// Full 2×3 affine: [a c e]
///                  [b d f]
class Transform2 { final double a, b, c, d, e, f; }
```

Affine, not translate-rotate-scale. DXF INSERT carries independent X/Y scale
factors which may be negative; mirrored blocks are common and a TRS-only
transform cannot represent them.

#### Nodes

```dart
sealed class Node {                    // CONTAINER — carries a transform
  Handle handle;
  Handle parent;                       // Handle.none at the root
  Transform2 transform;
  bool visible;
}

final class GroupNode extends Node {
  List<Handle> children;
  bool exportAsDxfGroup;               // set on import of a DXF GROUP
}

final class InstanceNode extends Node {
  Handle definition;
  Handle layer;
  // ATTRIBs are child entities owned by this node — not a field. See below.
}

final class Definition {
  Handle handle;
  String name;
  Vector2 basePoint;                   // DXF BLOCK base point; import alignment depends on it
  List<Handle> children;
  bool isXref;
}
```

Containers are objects; leaves are not (see *Entity records*).

`Definition` is a reusable prototype subtree; `InstanceNode` references one.
Nested instances are permitted; **cycle detection is required**, with defined
behavior: a command that would close a cycle is rejected with a typed error and
mutates nothing; an import that contains one emits a `Diagnostic` and drops the
offending nested instance rather than failing the whole file.

This pair is the same concept as Unity's prefab/instance and as DXF's
BLOCK/INSERT — and, as the mapping table below shows, as IFC's type/occurrence.

#### Block attributes are entities, not a map

A DXF ATTRIB is a full text entity: its own position, text style, height,
rotation, alignment, visibility flags, and an MTEXT variant. A
`Map<String, String>` on the instance cannot reconstruct any of that, so it
would forfeit the round-trip goal.

ATTRIBs are therefore **entities owned by the `InstanceNode`** — the same
ownership relation DXF uses. `attributesOf(instance)` is a query, not a field.

This also settles a rendering question: attribute text is *per-instance content*
and can never live inside a shared definition picture. Modeling it as a child of
the instance places it in the per-instance draw pass automatically.

#### Entity records — columnar

```dart
/// Leaf records are columnar. `EntityView` is constructed on demand and is
/// never the stored representation.
class EntityStore {
  final Map<Handle, int> slotOf;

  Uint8List   kind;            // line, polyline, arc, circle, text, attrib, hatch, …
  Uint32List  owner;           // definition, group node, instance node, or root
  Uint32List  layer;
  Uint32List  geomIndex;       // into GeometryStore

  // Tier-1 CAD style — native DXF fields, not components
  Int32List   color;           // encoded DraftColor, with BYLAYER/BYBLOCK sentinels
  Uint32List  linetype;
  Float32List linetypeScale;
  Int16List   lineweight;      // 1/100 mm, with BYLAYER/BYBLOCK/DEFAULT sentinels
  Uint8List   transparency;
  Uint8List   flags;           // DXF invisibility (code 60), …
}
```

One object per entity contradicts the structure-of-arrays claim at the scale the
validation gate targets, so the entity record itself is columnar, not only its
geometry. Tier-1 style is then simply more columns.

The `owner`, `layer` and `linetype` columns hold **handles**, not slots — the
targets are nodes and table records that live outside this store. That is the
concrete reason the handle space is capped at 32 bits.

Style must live here rather than in components: components are the *extension*
mechanism, and these are native DXF fields required for lossless round-trip.
Defaults are `BYLAYER` sentinels, so the common case costs one small integer per
column.

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

Both make effective style **path-dependent**, which is why style resolution has
an explicit contract (see *Style resolution*).

#### Components

```dart
abstract class Component {
  String get typeId;                   // 'jetcad.table', 'acme.plumbing'
  Map<String, Object?> toJson();
}

class ComponentStore<T extends Component> { final Map<Handle, T> byHandle; }

class ComponentRegistry {
  final Map<Type, ComponentStore> _stores;              // runtime lookup
  final Map<String, ComponentFactory> _byTypeId;        // decode
  final Map<Type, String> _typeIdOf;                    // encode
  final Map<Handle, List<Map<String, Object?>>> _unknown;   // preserved verbatim

  void register<T extends Component>(String typeId, ComponentFactory<T> f);
  Iterable<Handle> withComponent<T extends Component>();
}
```

Dart generics are reified, so `withComponent<T>()` keys the store by `Type`
while `typeId` remains the serialization name. Both directions of that mapping
live in `ComponentRegistry`, populated by `register`.

Rules:

- **Data only, never behavior.** The document must stay serializable,
  deterministic and undoable; behavior lives in application-side systems.
- **Immutable, value-equal, stable key order.** Value-diff undo has to compare
  and restore component state, and deterministic serialization requires
  `toJson` to emit keys in a fixed order. `StyleContext` carries the same
  requirement for a different reason (it is a cache key); this one exists for
  undo and byte-determinism.
- Attach to nodes and entities alike — one handle space, one mechanism.
- Components are stored in sparse type-keyed stores, *not* on each entity. This
  keeps entity records lean at scale and makes the runtime's core query —
  "every handle with a `TableComponent`" — proportional to the component count
  rather than the entity count.
- Unknown `typeId`s are preserved as raw JSON.
- Built-in components may be marked `internal`, meaning they are never written
  to foreign formats as extended data.

Application-domain concepts (table, zone, seat count) are components and block
attributes. **The engine defines no domain types.** Runtime state (occupied,
reserved) is not in the document at all; it is supplied to the view layer.

#### Slot lifetime — one contract for both columnar stores

Leaf coordinates live in typed arrays grouped by kind; the entity record holds
only `geomIndex`. The frozen decision is columnar storage with index-only entity
records; the exact packing is an implementation detail.

**Slot lifetime is not an implementation detail.** Without a rule here, the
`IdRemap` problem rejected for the 3D document reappears one layer down. The
same three rules govern **both** `GeometryStore`'s `geomIndex` and
`EntityStore`'s `slotOf` — delete and undo churn them identically, so an
invariant applied to one and not the other simply leaks.

1. Slot values are opaque and may change **only** inside a command that also
   rewrites every reference to them. No ambient compaction, ever — not on
   delete, not on load, not on idle.
2. Deletion returns the slot to a free list. The inverse command carries the
   **payload** (geometry, or the full entity record), not the slot, so undo may
   legitimately restore into a different slot and update every referencing
   record accordingly.
3. Compaction exists only as an explicit `purge()` maintenance operation. It
   rewrites all references and **clears the undo stack**. It is not a command
   and is not undoable.

Column growth follows the same discipline: arrays grow by reallocation, and a
grow never reorders live slots.

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

**Anisotropy under non-uniform transforms.** Because `Transform2` is a full
affine, inverse-transforming a circular pick radius yields an ellipse and a
query rectangle yields a rotated parallelogram. The broad phase therefore uses a
conservative axis-aligned bound of the inverse-transformed query region — never
the region itself — and accepts false positives. The narrow phase measures
distance **in world space**, transforming the candidate rather than the query.
This is exact under any affine and avoids ellipse math entirely.

Index implementation: a packed R-tree (STR bulk-load, typed arrays) plus a small
linearly-scanned dirty list for recently edited entities, rebuilt when the dirty
list exceeds a threshold. This avoids dynamic R*-tree complexity and matches the
real usage profile of long reads punctuated by short edit bursts.

#### Hit-testing — the engine returns a path, not a decision

```dart
class HitPath {
  final Uint32List chain;        // root → … → leaf, caller-owned buffer
  final int chainLength;
  final Handle entity;
  final Vector2 worldPoint;
  final HitKind kind;            // vertex | edge | fill
}
```

The engine reports what was hit; policy lives in the widget layer. `DraftViewer`
selects the first chain element (the top-level instance — tapping a chair
selects its table). `DraftDesigner` additionally supports descending into a
group on double-click.

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

**Budget: a snap query allocates nothing.** It runs at pointer-move rate. This
shapes the API rather than the implementation: the caller owns the result,
including the `HitPath` chain buffer, and the query writes into it.

```dart
void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out);
```

A `SnapResult` returning a freshly allocated `List<Handle>` would violate the
budget it is declared under; the fixed-capacity `Uint32List` chain plus an
explicit length is the shape that satisfies it. Chains deeper than the buffer
are truncated from the root and flagged, which only affects deeply nested
instances and never correctness of the leaf hit.

Snapping crosses instance boundaries (snapping to a chair's corner inside a
table instance). Snapping is an engine service, available to any tool, in the
viewer as well as the designer.

#### Queries

```dart
// Per-frame path — allocation-free, same budget as snap
void forEachInRect(Aabb2 world, void Function(int slot) visit);   // render culling
bool pickInto(Vector2 world, double radius, HitPath out);
void snapInto(Vector2 world, double radius, SnapMask mask, SnapResult out);

// Non-frame callers — convenience, allocation permitted
Iterable<Handle> entitiesInRect(Aabb2 world);
Iterable<Handle> withComponent<T extends Component>();
Iterable<Handle> onLayer(Handle layer);
Iterable<Handle> instancesOf(Handle definition);
Iterable<Handle> attributesOf(Handle instance);
```

Culling runs at the same rate as snapping, so it carries the same
zero-allocation budget and the same shape: a visitor callback over slots, with
no iterator object and no boxing. The `Iterable` form remains for tools,
adapters and tests, which are not on the frame path.

#### No topology

2D CAD needs no B-rep topology layer. Entities are independent geometries; a
"room" is a closed polyline, not a topological face. Holding this line is what
keeps the engine small and pure Dart.

In scope now: intersection, distance, trim/extend, 2D fillet/chamfer — pairwise
analytic math. Deferred: polyline offset and polygon boolean, written in Dart
when hatch boundaries or wall offsets require them.

### Appearance model

#### Two tiers

| Tier | Contents | Storage | Round-trip |
|---|---|---|---|
| CAD-native style | color, linetype, linetype scale, lineweight, transparency, invisibility, fill | entity store columns | lossless — native DXF fields |
| Rich appearance components | raster textures, custom gradients, render hints | component stores | lossy — preserved as extended data, approximated on export, reported |

#### Color

```dart
sealed class DraftColor {}
class ByLayer   extends DraftColor {}
class ByBlock   extends DraftColor {}
class Indexed   extends DraftColor { final int aci; }     // DXF ACI 1–255
class TrueColor extends DraftColor { final int argb; }
```

Stored encoded in an `Int32List` column with reserved sentinel values for
`ByLayer` and `ByBlock`.

Per-instance color is how "table color" works: geometry inside the definition is
authored `ByBlock`, and each `InstanceNode` carries its own color. 500 tables
share one geometry and render in different colors, and this round-trips to DXF
losslessly.

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

The `patterns` table holds hatch pattern definitions. A small embedded subset of
the standard patterns ships with the package; custom patterns are stored in the
document.

### Rendering

#### Style resolution — the contract the caches depend on

Effective style is path-dependent (`BYBLOCK`, `BYLAYER`, the layer-0 rule), and
a `Picture` bakes concrete `Paint` objects. A definition cannot be cached "once"
and replayed under different inherited styles. The cache key must therefore
carry the resolution context, and that context needs a defined shape:

```dart
/// Everything a definition's BYBLOCK / layer-0 contents resolve against.
/// Value equality and a stable hashCode are required — this is a cache key.
final class StyleContext {
  final int      color;            // resolved, concrete
  final Handle   linetype;
  final double   linetypeScale;
  final int      lineweight;
  final int      transparency;
  final Handle   layer;            // inherited layer for layer-0 entities
}

abstract class StyleResolver {
  /// The context an instance imposes on its definition's contents.
  StyleContext contextFor(Handle instance, StyleContext inherited);

  /// Concrete paint for one entity under a context.
  ResolvedStyle styleFor(Handle entity, StyleContext ctx);

  /// Monotonic. Bumped ONLY by document-level style edits — a layer colour,
  /// a linetype table record. Invalidates every cached picture.
  int get documentRevision;

  /// Instances whose style is overridden by application runtime state.
  /// Excluded from the static tile cache; drawn in the per-instance pass.
  Set<Handle> get overriddenInstances;

  /// Which instances changed override. Repaints those instances only —
  /// it must never touch documentRevision.
  Stream<Set<Handle>> get overrideChanges;
}
```

Resolution order inside `styleFor`:

```
application runtime override                  ← highest: "occupied table is red"
  else the entity's own column value
    if ByBlock → the StyleContext
    if ByLayer → the layer record
      else default
```

**Two invalidation channels, deliberately separate.** A single revision counter
covering both document edits and runtime state would make the primary workload
pathological: one table going occupied would rebuild every tile and every
definition picture in the drawing. Runtime override is per-instance and
highest-priority, so it must not be a global channel.

- `documentRevision` — layer and style-table edits. Global invalidation. Rare.
- `overrideChanges` — runtime state. Changes only which `StyleContext` those
  instances resolve to, so an affected table swaps to a *different, already
  cached* picture. Zero tiles invalidated, zero pictures rebuilt.

For that to hold, instances in `overriddenInstances` must be excluded from the
static tile cache and drawn in the per-instance pass — the same treatment, and
the same reason, as ATTRIB text.

**Cache key.** The definition picture cache is keyed by
`(definition, StyleContext, scaleBand, documentRevision)` — never by definition
alone.

**`scaleBand` is a band of the composed world→screen scale**, not of camera zoom:
camera scale × the accumulated scale of every ancestor × this instance's own
scale. It has to be, because a definition picture bakes concrete stroke widths
and dash lengths, and both are **paper-space** quantities that must stay
constant on screen. A picture recorded once and replayed under a 0.1× instance
and a 10× instance would render wall thicknesses differing by 100×. Stroke
widths and dash lengths are therefore baked pre-divided by the band's
representative scale, so replay yields the correct paper-space result.

**Anisotropy policy.** Under non-uniform instance scale there is no single
correct stroke width. The representative scale is `sqrt(|det|)` — the geometric
mean — while the ratio of the transform's singular values stays within a
threshold. Beyond that threshold the instance bypasses the definition cache and
draws directly with exact per-axis handling. Bounded and declared, rather than
silently wrong on mirrored or stretched blocks.

**Declared degeneration.** If `contextFor` returns a distinct context per
instance — every table a unique colour — the cache would grow one entry per
instance. The renderer bounds entries per definition; past the bound, those
instances bypass the definition cache and draw directly.

**Never in a definition picture, under any key:** per-instance *content*
(ATTRIB text) and instances carrying a runtime override. Both differ per
instance by construction.

#### Coordinate rebasing — Float64 model, float32 raster

The model is `Float64`; Skia's matrices and points are float32, with a 24-bit
mantissa. At site-plan coordinates around 4.5e6 — ordinary in DXF — the
representable spacing is roughly 0.5 units. Geometry jitters, and screen-space
decorations drift away from the geometry they annotate as zoom changes.

The renderer therefore never hands absolute world coordinates to `Canvas`:

- Every cached picture is recorded around a **rebase origin** — the tile origin
  for tile cache entries, the definition's base point for definition pictures.
- `CameraController` holds the world→screen transform in `Float64` and
  subtracts the rebase origin before the residual reaches the float32 matrix.
- **The whole chain composes in `Float64`, and exactly one residual matrix
  reaches `Canvas` per draw.** Instance transforms are never pushed as separate
  `canvas.transform` calls stacked on the camera: an instance placed at world
  4.5e6 carries that magnitude in its own `e`/`f`, so pushing it independently
  would feed the absolute coordinate straight back into the float32 matrix and
  undo the rebase. `camera ∘ ancestors ∘ instance ∘ rebase` is multiplied out in
  `Float64` and the result — small numbers — is what gets pushed.
- `ViewportTransform.worldToScreen` / `screenToWorld` perform the offset in
  `Float64`.

Golden tests must include a document at large coordinates; a fixture near the
origin cannot catch this class of defect.

#### Camera

A single world→screen affine carrying pan, zoom and optional rotation, held in
`Float64`. `CameraController` is a `ValueNotifier`; a change repaints inside a
`RepaintBoundary` without rebuilding the widget tree.

#### Two-level picture cache

Mirroring the spatial index:

1. **Definition cache** — a definition is recorded into a `Picture` per
   `(StyleContext, scaleBand, documentRevision)`; instances sharing a key replay
   one picture under their own composed transform.
2. **Tile cache** — static root-level geometry is recorded into world-space
   tiles, each around its own rebase origin. Panning replays tiles; crossing a
   scale band or a `documentRevision` bump invalidates them. Instances in
   `overriddenInstances` and all ATTRIB text are excluded from tiles, so runtime
   state changes never invalidate one.

Culling uses `forEachInRect` against the visible world rectangle.

Geometry is drawn under the camera transform; screen-space decorations (handles,
snap markers, selection) are drawn in a separate pass at constant pixel size.

#### Text

Text is not a detail here — for the runtime case it is the payload, since table
numbers and room labels are what the user reads.

- **Entities.** `TEXT` (single line) and `MTEXT` (multi-line with a declared
  subset of inline formatting codes). `ATTRIB` is a `TEXT` variant owned by an
  instance. Unsupported MTEXT inline codes are preserved in `rawTags` and
  stripped for display.
- **Attributes.** Height, width factor, oblique angle, rotation, alignment
  (DXF codes 72/73), and a `textStyles` table handle. Width factor is applied as
  a horizontal canvas scale, not a font feature.
- **World-space height.** Model-space text height is in document units, so text
  scales with zoom like geometry. It therefore lives in the same tile and
  definition pictures under the same zoom-band invalidation as everything else,
  and needs no separate damage rule.
- **Layout cost.** `ParagraphBuilder` / `Paragraph` construction is expensive
  relative to a path draw. Laid-out paragraphs are cached by
  `(string, style handle, resolved height band)` and are reused across the
  entities that share them — which, for repeated attribute values, is most of
  them.
- **Extents and hit-testing.** A text entity's laid-out box contributes to
  document extents and is its hit-test geometry, reported as `HitKind.fill`.
  Text metrics therefore must be available to the engine, not only the renderer;
  the engine holds a measurement interface that the Flutter layer implements.
- **SHX.** Mapped to TTF, declared lossy for display, preserved for round-trip.
- **Mirrored blocks.** Negative instance scale is explicitly supported, so text
  inside such a block is transformed into unreadable mirrored glyphs unless the
  renderer counter-transforms it. **v1 renders text faithfully mirrored**,
  matching the transform the file specifies. Whether to match AutoCAD's own
  convention instead is deferred until the real-file corpus exists to check it
  against; guessing at it now would be unverifiable either way.

Plan 3 owns all of the above.

#### Damage model

Repaint on events, never per vsync. Triggers: `DocChange`, camera change,
selection change, `documentRevision` bump, `overrideChanges` (repainting the
per-instance pass only), tool state change. A CAD viewport is idle most of the
time.

#### Draw order

```
tile / geometry cache        static, rebased, excludes overridden instances
definition pictures          per (StyleContext, scaleBand, documentRevision)
per-instance pass            ATTRIB text, runtime-overridden instances
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
   `BYLAYER`/`BYBLOCK`; it resolves separately from color, which is why it is
   its own field in `StyleContext`.

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
  Offset  worldToScreen(Vector2 world);     // Float64 internally, rebased
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

#### Selection

```dart
class SelectionController {
  Set<Handle> get selection;                  // multi-select
  Stream<SelectionChange> get changes;        // the only notification channel
}
```

One concern, one channel. Selection changes carry deltas that a multi-select UI
needs, so the channel is a `Stream`; it does not additionally implement
`ChangeNotifier`, because two channels over one concern have no defined ordering
between them. The general rule for this codebase: **deltas are exposed as a
`Stream`, snapshots as a `Listenable`, and never both for the same concern.**
`CameraController` is a `Listenable` because a camera has no meaningful delta;
`DraftDocument` and `SelectionController` are `Stream`s because theirs do.

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
  Meaningful git diffs and the round-trip tests both depend on this.
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

/// Lives in the core package, not in an adapter: the engine itself raises
/// diagnostics (cycle detection, degraded fills), and every adapter reuses
/// the same type. Delivered in Plan 1.
class Diagnostic {
  final DiagnosticSeverity severity;    // info | warning | loss | error
  final String code;                    // stable, machine-matchable
  final String message;
  final List<Handle> handles;           // what it concerns; may be empty
  final String? sourceLocation;         // adapter-defined (line, offset, …)
}
```

Three frozen rules:

1. **Adapters use only the public document API.** They never reach into engine
   internals. This is what allows them to live in separate packages.
2. **The engine names no format.** The string `dxf` or `ifc` does not appear in
   `jet_cad_2d`, with two deliberate exceptions: the `OriginComponent.source`
   enum and `GroupNode.exportAsDxfGroup`. The preserve-unknown slot is *not* a
   third exception — it holds an opaque blob keyed by `SourceKind`, whose
   payload shape the engine never inspects.
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
| `Definition` | BLOCK / BLOCK_RECORD (+ base point) | `IfcTypeObject` (`IfcFurnitureType`, …) |
| `InstanceNode` | INSERT | occurrence + `IfcRelDefinesByType` |
| `GroupNode` | **anonymous BLOCK + INSERT** (see below) | `IfcGroup` / `IfcZone` |
| leaf entity | LINE, LWPOLYLINE, ARC, … | representation item / profile |
| ATTRIB child entity | ATTRIB | property on the occurrence |
| `Component` | XDATA / XRECORD | `IfcPropertySet` + `IfcRelDefinesByProperties` |
| layer | LAYER table | weak — `IfcPresentationLayerAssignment` |
| units | `$INSUNITS` | `IfcUnitAssignment` |
| region (closed boundary + component) | LWPOLYLINE + HATCH | `IfcSpace` |
| root | model space | `IfcProject → Site → Building → BuildingStorey` |

**`GroupNode` maps to an anonymous block, not to DXF GROUP.** GROUP is a flat
named list of handles whose members keep model-space ownership; it can represent
neither nesting nor a transform, and `GroupNode` has both. An anonymous
BLOCK + INSERT preserves both, at the cost of moving members into the block's
coordinate space. A DXF GROUP encountered on import becomes a `GroupNode` with
an identity transform and `exportAsDxfGroup` set, so a file that arrived with
GROUPs leaves with GROUPs. Groups created in the designer export as anonymous
blocks; this is declared in the exporter's diagnostics.

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
- INSERT scale factors are independent per axis and may be negative. This is why
  `Transform2` is a full affine.
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
| serialization idempotence: `save(load(save(d))) == save(d)` | deterministic output |
| migration fixtures, one document per historical version | backward compatibility |
| unknown-preservation: injected foreign field / component / blob survives | the recurring invariant |
| slot lifetime: delete → undo → redo → reference integrity, both stores | the shared slot rules |
| extents determinism: same document serialized on two font configurations | derived-versus-stored |
| large-coordinate golden (document near 4.5e6, including a nested instance placed there) | coordinate rebasing through the whole chain |
| style-context cache: same definition under N contexts renders N distinct results | the cache key contract |
| runtime override isolation: one instance's state change invalidates no tile and rebuilds no picture | the two-channel split |
| paper-space invariance: same definition instanced at 0.1× and 10× renders identical stroke width | `scaleBand` and pre-divided stroke baking |
| inheritance conformance: layer-0 and BYBLOCK resolved through two levels of nesting | the layer/style model contract |
| cycle detection: command rejected and document unmutated; import diagnosed and recovered | the stated cycle behavior |
| query benchmark at 50k / 500k entities (Plan 2) | spatial index scale |
| frame-time benchmark at 50k / 500k entities (Plan 3) | rendering scale |
| (format plans) **real-file corpus** — AutoCAD, BricsCAD, QCAD, LibreCAD, Revit exports | conformance to reality |

`save(load(x)) == x` would only hold for an `x` already produced canonically;
the idempotence form above is the correct statement.

The corpus row is the standard for format work: the criterion is not "does it
match the specification" but "does round-trip survive files produced by real
applications". Collection starts in the DXF plan.

Engine tests run under `dart test` with no Flutter dependency. Widget-layer
tests use `flutter_test`; rendering goldens are limited to the widget package.

## Roadmap

| Plan | Scope |
|---|---|
| **1** | Handles, document, tree, `Transform2`, columnar entity and geometry stores with the shared slot-lifetime rules, derived-versus-stored split, components with the `Type`/`typeId` registry, `Diagnostic`, layer and style tables, tolerance and geometry primitives, command/undo/`DocChange`, minimal JSON codec |
| **2** | Two-level spatial index, hit-testing and `HitPath`, snap engine with the zero-allocation query API, query set, **query-throughput benchmark** |
| **3** | Camera and coordinate rebasing, `StyleResolver` and the picture-cache contract, definition and tile caches, text, fills/patterns/dashes/lineweight, damage model, `DraftCanvas`, **frame-time benchmark** |
| **4** | `InteractionTool`, `SelectionController`, `DraftPermissions`, `ViewportTransform` and `overlayBuilder`, geometric tool set, `DraftViewer`/`DraftDesigner` presets, harness |
| **5** | `schemaVersion` and migration chain, file I/O, autosave and recovery, deterministic serialization, unknown-preservation tests |
| future | DXF import · IFC plan-only import · DXF round-trip export |

### Validation gates

Flutter `Canvas` performance at scale is this architecture's largest unvalidated
technical assumption. It is measured in two stages, because the two halves of it
become measurable at different times:

- **End of Plan 2 — query throughput.** `forEachInRect`, `pick` and `snap`
  against generated 50k and 500k entity documents, with no painting. This
  measures the spatial index, which is complete at that point. It deliberately
  does not measure rendering.

  | Measurement | Threshold | Verdict if missed |
  |---|---|---|
  | `forEachInRect` returning ~2k visible entities from 500k | < 2 ms | **fail** — index design returns to Plan 2 |
  | `pick` at 500k | < 1 ms | **fail** |
  | `snap` at 500k, all kinds enabled | < 1 ms, zero allocation | **fail** |

- **End of Plan 3 — frame time.** Pan and zoom on the same documents with the
  definition and tile caches active. This is the gate on the actual assumption,
  and the one that can send the rendering design back.

  | Document | Threshold | Verdict if missed |
  |---|---|---|
  | 50k entities, at large world coordinates | p95 frame < 16.6 ms (60fps) sustained | **fail** — blocks Plan 4; render design reopens |
  | 500k entities | p95 frame < 33 ms (30fps) | **informational** — does not block, but caps the documented supported scale and is recorded in the README |
  | one runtime override toggled per frame, 50k document | no tile invalidation, no picture rebuild | **fail** — the two-channel split is not working |

The 50k figure is the product requirement: an authored floor plan. The 500k
figure is the imported-architectural-drawing stretch, which is why it is
declared informational rather than pretended to be a gate — a soft number that
cannot fail anything is not a gate, and calling it one would be dishonest about
what blocks what.

Neither gate may be deferred into Plan 4. The cost of reversing the render
design grows sharply once interaction is built on it.

### First milestone success criteria

In the harness: draw walls → define a table block → place 200 instances →
select and move one with snapping → color instances by runtime state → render
attribute text on each → save and reload → sustain 60fps pan/zoom on a
50k-entity document positioned at large world coordinates.

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
| Flutter `Canvas` insufficient at 500k entities | Plan 3 frame-time gate (Plan 2 gate covers the index half) |
| Style contexts fail to collapse, so definition caching degenerates | Plan 3 — per-definition entry bound with declared bypass |
| Paragraph layout cost dominates on text-heavy plans | Plan 3 — layout cache keyed by string/style/height band |
| Handle space is 32-bit (columns are `Uint32List`); long-lived drawings exceed it | Plan 1 — range check plus handle-space compaction on import, made safe by `OriginComponent` |
| Flutter has no dash API; written by hand | Plan 3 task |
| The assumption that AutoCAD preserves foreign XDATA is unverified | DXF plan — real-file corpus |
| Hatch pattern generation cost at large scales | Plan 3 — picture cache; shader fast path held in reserve |
