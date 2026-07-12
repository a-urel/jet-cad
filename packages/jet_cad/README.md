# jet_cad

A headless-first CAD engine and viewport package for Flutter, built on Open
CASCADE Technology (OCCT).

## Status

`jet_cad` currently ships:

- Typed entity ids and a semantic `Entity`/`EntityKind` model
- A sealed `Operation` hierarchy (make box, extrude, boolean, fillet,
  transform, STEP import/export) with JSON round-tripping
- `CadDocument`: an operation timeline with bounded undo/redo and a
  `DocChange` event stream
- Versioned JSON persistence (`CadDocumentCodec`), including a kernel
  geometry blob so a loaded document has real, editable geometry
- An abstract `KernelBridge` contract with two implementations:
  `FakeKernelBridge`, an in-memory stand-in for tests (topology counts
  only, not real geometry), and `FfiKernelBridge`, backed by a real Open
  CASCADE session over FFI
- `JetCadViewport` + `ViewportController`: an interactive macOS viewport
  (camera navigation, click pick, selection highlight) over the same
  `KernelBridge` contract — see [Viewport (macOS)](#viewport-macos) below

## Usage

```dart
import 'package:jet_cad/jet_cad.dart';

Future<void> main() async {
  final doc = await CadDocument.create(FakeKernelBridge());

  final box = await doc.makeBox(const Vec3(10, 10, 10));
  final other = await doc.makeBox(const Vec3(4, 4, 4));
  await doc.booleanCombine(box, other, BoolOp.cut);

  await doc.undo(); // back to the two separate boxes
  await doc.redo(); // forward to the cut result again

  final json = CadDocumentCodec.encode(doc);
  await doc.dispose();
}
```

## Viewport (macOS)

```dart
final bridge = FfiKernelBridge.auto();
final doc = await CadDocument.create(bridge, target: const TextureTarget());
final controller = ViewportController(document: doc);

// In your widget tree:
JetCadViewport(controller: controller)

// Navigation: left-drag orbit, right-drag pan, scroll zoom.
controller.selectionChanges.listen((e) => print('selected: ${e.selection}'));
await doc.makeBox(const Vec3(40, 30, 20));
await controller.fitAll();
```

Rendering is damage-driven (frames draw only on document/camera/selection
changes) via OCCT's AIS/V3d viewer composited as a Flutter external texture
(IOSurface). macOS only for now; Windows/Linux follow the same
`KernelBridge` contract in later milestones. Selection is view state — it
never enters the document or undo history.

## Roadmap

`jet_cad` is usable today as a document/undo-timeline library with real
OCCT geometry (`FfiKernelBridge`) and an interactive macOS viewport. Still
ahead: a full demo app, Windows/Linux viewport texture paths, and binary
distribution of the native library and Flutter plugin.

## Native development

`src/native/` is a standalone CMake project that builds the OCCT-backed
`jet_cad_native` C ABI library and its GoogleTest smoke suite. It is not
wired into the Flutter plugin platform builds yet (that lands in a later
plan) — it exists so the native toolchain can be built and tested on its
own.

Prerequisites (macOS, via Homebrew):

```bash
brew install opencascade cmake ninja
```

Build the library and run its tests:

```bash
packages/jet_cad/tool/build_native.sh
```

This configures CMake (locating OCCT via `find_package(OpenCASCADE)`),
builds `build/native/libjet_cad_native.{dylib|so}`, and runs the GoogleTest
suite via `ctest`.

The pure-Dart test suite (`flutter test`) never needs any of this — it runs
entirely against `FakeKernelBridge` and has no dependency on OCCT, CMake, or
the native build.
