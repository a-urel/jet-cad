# jet-cad Architecture Design

**Date:** 2026-07-12
**Status:** Approved — Architecture v1.0 (frozen; evolves only on concrete implementation findings)

## Summary

jet-cad is an open-source Flutter package providing a 3D CAD engine and viewport
widget, built on Open CASCADE Technology (OCCT), plus a demo app that composes a
full editor from the package's public API. The package is headless-first: it
ships the engine and a viewport widget, not opinionated UI, so it can serve
ERP, BIM, PLM, and custom applications. A separate optional `jet_cad_editor`
package may later provide a batteries-included editor.

## Non-goals

JetCAD is not intended to compete with FreeCAD or commercial CAD systems in
its initial releases. The primary goal is a reusable Flutter-native CAD SDK
and viewport that can be embedded into other applications. Advanced features
such as assemblies, constraints, parametric editing, drafting, CAM, and
photorealistic rendering are intentionally deferred.

## Decisions

| Question | Decision |
|---|---|
| Widget scope | Full solid modeling (create + edit) |
| Kernel | OCCT — only mature OSS B-rep kernel; distributed under LGPL 2.1 with the Open CASCADE Exception (third-party license; JetCAD itself remains Apache 2.0) |
| Platforms v1 | Desktop only (Windows/macOS/Linux) |
| Mobile | Deferred until viewport stabilizes; FFI path already supports it |
| Web | Deferred; the architecture permits a future WebAssembly backend without changing the public Dart API (OCCT Emscripten/WebGL path) |
| Rendering | OCCT's own AIS/V3d viewer, composited via Flutter external texture |
| Modeling paradigm | Direct modeling in v1; document stores operation graph so parametric history can be added without format break |
| Package boundary | Viewport widget + headless document/controller API; no built-in toolbars or panels |
| Integration | Hybrid: C++ owns geometry session + viewer; Dart owns semantic document + op graph |

## Kernel choice rationale

Alternatives considered and rejected: Fornjot and truck (Rust B-rep kernels,
years from fillet/STEP maturity), CGAL (mesh processing, not B-rep CAD),
Parasolid/ACIS (commercial licensing incompatible with an OSS package). OCCT
provides modeling, STEP/IGES exchange, tessellation, and an interactive viewer
(AIS) in one library. OCCT is distributed under the GNU LGPL v2.1 with the
Open CASCADE Exception; it remains a third-party dependency with its own
license, independent of JetCAD's Apache 2.0 license.

## Architecture

### Repository layout

```
jet-cad/  (melos monorepo)
├── packages/
│   ├── jet_cad/                 # the pub.dev package
│   │   ├── lib/
│   │   │   ├── src/document/    # CadDocument, entities, op graph, undo (pure Dart)
│   │   │   ├── src/kernel/      # KernelBridge interface + FFI impl (+ WASM impl later)
│   │   │   ├── src/viewport/    # JetCadViewport widget, camera/gesture controller
│   │   │   └── jet_cad.dart     # public API
│   │   └── src/native/          # C++ shim: session, command dispatch, AIS setup
│   └── jet_cad_editor/          # later; optional batteries-included UI
├── apps/demo/                   # demo app: full editor composed from jet_cad parts
└── third_party/                 # OCCT prebuilt binaries (fetched, never committed)
```

Scaffold starts from `flutter create --template=plugin_ffi` for the
CMake/Gradle/CocoaPods native build glue.

### Layers

```
JetCadViewport (widget)     CadDocument (pure Dart: entities, op graph, undo)
        └──────────┬────────────┘
             KernelBridge (abstract Dart interface — coarse commands)
                   │
         FfiKernel (v1)  ·  WasmKernel (later, same interface)
                   │
         C++ shim: Session { OCCT shapes, AIS context, V3d viewer }
```

Hard rule: nothing above `KernelBridge` may import `dart:ffi`. The document
layer is pure Dart and unit-testable without a native build. This rule is what
permits a future WASM backend without public API changes.

## KernelBridge contract

Coarse, asynchronous command API. Entity ids cross the boundary; geometry never
does.

**Session ownership (contractual):** one `CadDocument` owns exactly one kernel
session. Sessions are never shared between documents; closing the document
disposes the session.

```dart
abstract interface class KernelBridge {
  Future<SessionHandle> createSession(RenderTarget target);

  // modeling — each returns new/modified entity ids plus an id remap table
  Future<BodyId> makeBox(SessionHandle s, Vec3 size);
  Future<BodyId> extrude(SessionHandle s, FaceId face, double depth);
  Future<BodyId> booleanOp(SessionHandle s, BodyId a, BodyId b, BoolOp op);
  Future<BodyId> fillet(SessionHandle s, List<EdgeId> edges, double radius);

  // interaction
  Future<PickResult?> pick(SessionHandle s, Offset screenPos, PickFilter filter);
  Future<void> setSelection(SessionHandle s, List<EntityId> ids);

  // viewer (signatures elided: resize, rotate, pan, zoom, fitAll)
  Future<void> resizeViewport(SessionHandle s, Size size, double pixelRatio);

  // io
  Future<List<BodyId>> importStep(SessionHandle s, Uint8List bytes);
  Future<Uint8List> exportStep(SessionHandle s, List<BodyId> ids);

  // session persistence — kernel state reconstruction
  Future<KernelSnapshot> saveSnapshot(SessionHandle s);          // BREP dump + id map
  Future<void> restoreSession(SessionHandle s, KernelSnapshot snapshot);
}
```

Key contract decisions:

- **Ids, not native handles.** The C++ session keeps `map<uint64, TopoDS_Shape>`.
  Dart never owns native pointers, so there are no finalizer or lifetime bugs.
  Deletion is an explicit command.
- **Stable sub-entity ids.** Every exposed entity (body, face, edge, vertex)
  is assigned a stable application identifier (UUID) managed by the session
  layer — OCCT itself has no identity facility; the shim generates and owns
  the mapping. Never an index like (bodyId, faceIndex), which shuffles after
  boolean operations. Every modeling operation returns an id remap table
  (old UUID → new UUIDs) that the document applies. The session derives
  remaps from OCCT's built-in operation history
  (`Generated`/`Modified`/`IsDeleted` maps on `BRepBuilderAPI`/`BRepAlgoAPI`
  operations). This is a deliberate down-payment on the persistent-naming
  problem; the full solution is deferred to the parametric phase.
- **Threading.** OCCT boolean operations can take seconds. All commands run on
  a dedicated native worker thread; FFI calls return immediately and complete
  via Dart `NativePort` callbacks surfaced as `Future`s. One command in flight
  per session (queued) because OCCT is not thread-safe per document.
- **Errors.** Every command returns a status plus optional error payload. OCCT
  exceptions are caught in C++ and never cross the boundary as crashes. The
  bridge throws typed `KernelException`; the document layer decides rollback.
- **Async everywhere**, so the future WASM/web-worker backend needs no API
  change.

### API evolution notes (not frozen)

- The per-operation bridge methods (`makeBox`, `extrude`, …) are the v1 shape,
  not a permanent contract. As the operation set grows (sweep, loft, shell,
  draft, mirror, pattern, offset, split), the bridge is expected to migrate to
  a generic `execute(KernelCommand)` dispatch — better for versioning than a
  new abstract method per release. Public `CadDocument` methods stay ergonomic
  either way.
- The kernel is not assumed to be the lowest semantic layer forever. A future
  sketch/constraint-solver stage will sit between the document and the kernel;
  nothing today should be named or coupled as if geometry commands always
  originate directly from the document.

## Viewport and rendering

`JetCadViewport` is a Flutter `Texture` widget plus a gesture layer. OCCT V3d
renders offscreen into a GPU surface that Flutter composites.

| Platform | Texture path |
|---|---|
| Windows (v1) | GL ES via ANGLE → D3D11 texture shared via DXGI handle (native Windows GL drivers are unreliable) |
| macOS (v1) | Native OpenGL (CGL) → `IOSurface`-backed FBO → Metal texture. Deprecated but present and stable; avoids shipping ANGLE |
| Linux (v1) | EGL offscreen FBO → embedder GL texture |
| Android (later) | GL ES → `SurfaceTexture` (standard external-texture route) |
| iOS (later) | Native GL ES via `CVOpenGLESTextureCache`, or ANGLE — decided at mobile phase |
| Web (later) | OCCT Emscripten renders to WebGL canvas via `HtmlElementView`; no texture bridge |

OCCT abstracts desktop GL vs GL ES internally, so the shim's rendering code is
shared; only context creation differs per platform. Context creation lives in
one isolated module per platform so that swapping macOS to ANGLE later (if
Apple removes OpenGL) is a contained change, not a rewrite.

Interaction:

- Flutter gestures → `ViewportController` → orbit/pan/zoom commands → V3d
  camera. Hover/click → `pick()`; AIS handles selection highlighting natively.
- **Damage-driven redraw:** render only on command completion, camera change,
  or selection change — not every vsync. CAD viewports idle most of the time;
  battery and thermals matter on laptops now and mobile later.
- Resize and `devicePixelRatio` changes reallocate the texture, debounced.

## Document model (pure Dart)

```dart
class CadDocument {
  Map<EntityId, Entity> entities;   // bodies, face/edge refs, materials, names
  List<Operation> ops;              // immutable operations, ordered
  int head;                         // timeline position: ops[0..head) are applied
}

sealed class Operation {            // MakeBox, Extrude, Boolean, Fillet, ImportStep…
  final OpId id;
  final List<EntityId> inputs;      // dependencies = graph edges
  final Params params;              // typed, serializable
  final List<EntityId> outputs;
  final IdRemap remap;              // from kernel, applied on execution
}
```

- **Timeline, not append-only log.** Operations are immutable; document state
  is defined by `ops[0..head)`. Undo decrements `head`, redo increments it.
  A new operation while `head < ops.length` truncates the redo branch (linear
  history in v1). This keeps replay deterministic: the applied state is always
  a prefix of the operation list.
- **Command flow:** app calls `doc.extrude(face, 10)` → document appends an
  `Operation` (truncating any redo branch), sends the bridge command, applies
  the id remap on completion, advances `head`, and notifies listeners. The
  viewport is already updated on the AIS side.
- **Undo strategy is explicit per operation type** so memory usage stays
  predictable:

  | Operation type | Undo strategy |
  |---|---|
  | Move/Transform | Inverse operation |
  | Boolean | Kernel snapshot (`BRepTools` binary dump of affected bodies) |
  | Fillet | Kernel snapshot |
  | Extrude/MakeBox | Delete created entities |
  | Import STEP | Delete created entities |

  Snapshot stack is bounded (N=50 undo steps); beyond that, oldest snapshots
  are dropped and those steps become un-undoable. Selection is transient view
  state, not a document mutation — it never enters the operation list and is
  not undoable. The parametric phase later replaces snapshots with
  replay-from-graph.
- **History-ready payoff:** `ops` + params is exactly the input a parametric
  rebuild needs. V1 records the graph but never exposes editing it.
- **Persistence:** native format is the operation list + `head` + entity
  metadata as versioned JSON, plus a geometry cache blob: a `KernelSnapshot`
  containing BREP dumps and the UUID ↔ shape id map. The header records
  `schema-version`, `kernel-version` (shim), and `occt-version` from day 1 —
  cheap now, essential for migrations later. STEP import/export via the kernel
  is interchange only, not the document format.
- **Session reconstruction:** opening a file creates a fresh kernel session and
  calls `restoreSession(snapshot)` — shapes and id maps load directly, no op
  replay needed. If the cache blob is missing or corrupt, fallback is replaying
  `ops[0..head)` through the bridge. The same contract serves crash recovery
  and, later, collaborative sync and background regeneration.
- **Reactivity:** the document exposes `Stream<DocChange>` with typed events
  from day one — no string matching:

  ```dart
  sealed class DocChange {}
  class EntitiesAdded implements DocChange { ... }
  class EntitiesRemoved implements DocChange { ... }
  class OperationCommitted implements DocChange { ... }
  class UndoPerformed implements DocChange { ... }
  class RedoPerformed implements DocChange { ... }
  class DocumentLoaded implements DocChange { ... }
  ```

  The viewport and user UI (trees, inspectors) subscribe. No widget rebuilds on
  kernel ticks. `SelectionChanged` is deliberately *not* a `DocChange`:
  selection is view state, so it is emitted by the `ViewportController`'s own
  stream.

## Error handling

Kernel failure → typed `KernelException` → document rolls back the pending
operation (op log unchanged, no orphan entities). OCCT hard-crash-class errors
(segfaults inside boolean ops happen in practice) are contained where possible
by catching OCCT exceptions in C++; true native crashes are a documented known
limitation in v1. Process/isolate sandboxing of the kernel is explicitly out of
scope for v1.

## Testing

| Layer | Strategy |
|---|---|
| Document (pure Dart) | Unit tests with `FakeKernelBridge`; no native build; runs in any CI |
| C++ shim | GoogleTest against real OCCT; geometry golden tests (volumes, face counts) |
| Bridge integration | Dart FFI tests on desktop CI (Linux runner, headless EGL) |
| Viewport | Widget tests with fake bridge; golden screenshots on desktop CI only |
| Demo app | Composed exclusively from the public API; doubles as dogfood and integration test |

## Binary distribution

OCCT + shim are prebuilt per platform and published as GitHub release
artifacts. Package build hooks (CMake `FetchContent`, Gradle, CocoaPods
`prepare_command`) download them at consumer build time, pinned by checksum.
This keeps the pub.dev package under the 100 MB limit and consumers never
compile OCCT. The OCCT license texts (LGPL v2.1 with the Open CASCADE
Exception) are distributed alongside the prebuilt binaries (e.g. under
`LICENSES/` or `THIRD_PARTY.md` in the release artifacts); OCCT's license
applies to those binaries only and does not affect JetCAD's own Apache 2.0
license.

## Demo app scope (v1)

Full editor composed from the public API only: toolbar (box, extrude, boolean,
fillet), entity tree, property inspector, STEP open/save, orbit/pan/zoom/fit
navigation, click selection with highlight.

## Out of scope for v1

- Mobile (iOS/Android) — deferred until desktop viewport stabilizes; touch CAD
  UX is its own design project. FFI architecture already supports it.
- Web backend — the architecture permits a WASM backend without public API
  changes; implementation is a major separate effort.
- Parametric history editing (graph is recorded, not editable)
- `jet_cad_editor` batteries-included UI package
- 2D drafting/DXF
- Kernel process sandboxing
- Assemblies/constraints
- Selection undo (selection is transient view state, never in the op list)

## Key risks

| Risk | Mitigation |
|---|---|
| Texture interop plumbing per platform | Windows first (cleanest external-texture path via ANGLE/D3D11), then macOS, then Linux; context creation isolated per platform |
| Apple removes OpenGL in a future macOS | Context-creation module isolation keeps ANGLE swap-in a contained change |
| OCCT binary size (~30–60 MB) | Strip unused OCCT toolkits at build; document size honestly |
| Sub-entity id stability after booleans | Subshape UUIDs + remap tables from every op; full persistent naming deferred |
| flutter plugin_ffi + custom texture complexity | Spike per platform before committing milestone dates |
| OCCT crashes in-process | Catch OCCT exceptions in shim; sandbox out of scope v1 (documented) |
