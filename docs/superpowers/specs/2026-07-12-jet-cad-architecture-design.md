# jet-cad Architecture Design

**Date:** 2026-07-12
**Status:** Approved (brainstorming phase)

## Summary

jet-cad is an open-source Flutter package providing a 3D CAD engine and viewport
widget, built on Open CASCADE Technology (OCCT), plus a demo app that composes a
full editor from the package's public API. The package is headless-first: it
ships the engine and a viewport widget, not opinionated UI, so it can serve
ERP, BIM, PLM, and custom applications. A separate optional `jet_cad_editor`
package may later provide a batteries-included editor.

## Decisions

| Question | Decision |
|---|---|
| Widget scope | Full solid modeling (create + edit) |
| Kernel | OCCT — only mature OSS B-rep kernel; LGPL 2.1 with exception |
| Platforms v1 | Desktop (macOS/Windows/Linux) + Mobile (iOS/Android) |
| Web | Deferred; architecture web-ready from day 1 (OCCT Emscripten/WebGL path) |
| Rendering | OCCT's own AIS/V3d viewer, composited via Flutter external texture |
| Modeling paradigm | Direct modeling in v1; document stores operation graph so parametric history can be added without format break |
| Package boundary | Viewport widget + headless document/controller API; no built-in toolbars or panels |
| Integration | Hybrid: C++ owns geometry session + viewer; Dart owns semantic document + op graph |

## Kernel choice rationale

Alternatives considered and rejected: Fornjot and truck (Rust B-rep kernels,
years from fillet/STEP maturity), CGAL (mesh processing, not B-rep CAD),
Parasolid/ACIS (commercial licensing incompatible with an OSS package). OCCT
provides modeling, STEP/IGES exchange, tessellation, and an interactive viewer
(AIS) in one library.

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
makes "web later" real rather than aspirational.

## KernelBridge contract

Coarse, asynchronous command API. Entity ids cross the boundary; geometry never
does.

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
}
```

Key contract decisions:

- **Ids, not native handles.** The C++ session keeps `map<uint64, TopoDS_Shape>`.
  Dart never owns native pointers, so there are no finalizer or lifetime bugs.
  Deletion is an explicit command.
- **Stable sub-entity ids.** A `FaceId` of the form (bodyId, faceIndex) is
  fragile: indices shuffle after boolean operations. Rule for v1: every
  modeling operation returns an id remap table (old id → new id) that the
  document applies. This is a deliberate down-payment on the persistent-naming
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

## Viewport and rendering

`JetCadViewport` is a Flutter `Texture` widget plus a gesture layer. OCCT V3d
renders offscreen into a GPU surface that Flutter composites.

| Platform | Texture path |
|---|---|
| Android | GL ES → `SurfaceTexture` (standard external-texture route) |
| iOS/macOS | GL ES via ANGLE → Metal-backed `IOSurface`/`CVPixelBuffer` |
| Windows | GL ES via ANGLE → D3D11 texture shared via DXGI handle |
| Linux | EGL offscreen FBO → embedder GL texture |
| Web (later) | OCCT Emscripten renders to WebGL canvas via `HtmlElementView`; no texture bridge |

The shim has a single GL ES 3.0 code path everywhere; ANGLE translates to
Metal/D3D on Apple/Windows. This sidesteps Apple's OpenGL deprecation now
rather than later, and avoids four divergent context-creation paths.

Interaction:

- Flutter gestures → `ViewportController` → orbit/pan/zoom commands → V3d
  camera. Hover/click → `pick()`; AIS handles selection highlighting natively.
- **Damage-driven redraw:** render only on command completion, camera change,
  or selection change — not every vsync. CAD viewports idle most of the time;
  battery and thermals matter on mobile.
- Resize and `devicePixelRatio` changes reallocate the texture, debounced.

## Document model (pure Dart)

```dart
class CadDocument {
  Map<EntityId, Entity> entities;   // bodies, face/edge refs, materials, names
  List<Operation> opLog;            // append-only op graph — the history-ready part
  UndoStack undo;
}

sealed class Operation {            // MakeBox, Extrude, Boolean, Fillet, ImportStep…
  final OpId id;
  final List<EntityId> inputs;      // dependencies = graph edges
  final Params params;              // typed, serializable
  final List<EntityId> outputs;
  final IdRemap remap;              // from kernel, applied on execution
}
```

- **Command flow:** app calls `doc.extrude(face, 10)` → document appends an
  `Operation`, sends the bridge command, applies the id remap on completion,
  and notifies listeners. The viewport is already updated on the AIS side.
- **Undo (v1):** inverse operations where cheap; otherwise kernel shape
  snapshots via OCCT `BRepTools` binary dump, bounded stack (N=50). The
  parametric phase later replaces this with replay-from-graph.
- **History-ready payoff:** `opLog` + params is exactly the input a parametric
  rebuild needs. V1 records the graph but never exposes editing it.
- **Persistence:** native format is the op log + entity metadata as versioned
  JSON (schema-version field from day 1), plus an optional geometry cache blob
  (BREP dump) so opening a file does not require full replay. STEP
  import/export via the kernel is interchange only, not the document format.
- **Reactivity:** the document exposes `Stream<DocChange>`; the viewport and
  user UI (trees, inspectors) subscribe. No widget rebuilds on kernel ticks.

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
compile OCCT.

## Demo app scope (v1)

Full editor composed from the public API only: toolbar (box, extrude, boolean,
fillet), entity tree, property inspector, STEP open/save, orbit/pan/zoom/fit
navigation, click selection with highlight.

## Out of scope for v1

- Web backend (architecture ready; implementation deferred)
- Parametric history editing (graph is recorded, not editable)
- `jet_cad_editor` batteries-included UI package
- 2D drafting/DXF
- Kernel process sandboxing
- Assemblies/constraints

## Key risks

| Risk | Mitigation |
|---|---|
| Texture interop plumbing per platform | ANGLE single GL path; Android first (simplest route), then others |
| OCCT binary size (~30–60 MB mobile) | Strip unused OCCT toolkits at build; document size honestly |
| Sub-entity id stability after booleans | Id remap tables from every op; full persistent naming deferred |
| flutter plugin_ffi + custom texture complexity | Spike per platform before committing milestone dates |
| OCCT crashes in-process | Catch OCCT exceptions in shim; sandbox out of scope v1 (documented) |
