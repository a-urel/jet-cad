## 0.2.0

- Native FFI/OCCT backend (`FfiKernelBridge`): per-session command queue, real
  geometry for box/extrude/boolean/fillet/transform, STEP import/export, and
  id-preserving snapshots against actual Open CASCADE shapes.
- Unified `KernelSnapshot` blob shared by body-level and whole-session
  restore, with atomic restore and typed corrupt-snapshot errors.
- `CadDocument.save()` returns the full persisted document plus a base64
  kernel geometry blob (`saveSnapshot`); `CadDocument.load` restores the
  kernel session from that blob via `restoreSession` when present, so a
  loaded document has real, editable geometry rather than metadata only.
  Loading a document with operations but no geometry blob throws
  `StateError` (op replay is deferred to the parametric phase). Entity/op
  entries are now validated individually, with `FormatException` reporting
  the failing index; a session created during a failed `load` is disposed,
  never leaked.

## 0.1.0

- Initial development release: pure-Dart CAD document layer (entities, sealed operations, timeline undo/redo, JSON persistence) over an abstract `KernelBridge` with an in-memory `FakeKernelBridge`. No native/OCCT backend yet.
