# jet_cad

A headless-first CAD engine and viewport package for Flutter, built on Open
CASCADE Technology (OCCT).

## Status

This is Plan 1: the pure-Dart CAD document layer only. `jet_cad` currently
ships:

- Typed entity ids and a semantic `Entity`/`EntityKind` model
- A sealed `Operation` hierarchy (make box, extrude, boolean, fillet,
  transform, STEP import/export) with JSON round-tripping
- `CadDocument`: an operation timeline with bounded undo/redo and a
  `DocChange` event stream
- Versioned JSON persistence (`CadDocumentCodec`)
- An abstract `KernelBridge` contract plus `FakeKernelBridge`, an in-memory
  implementation for tests and for consumers who want to exercise document
  logic without a native build

There is no native geometry kernel or viewport yet — every modeling
operation is routed through `KernelBridge`, and `FakeKernelBridge` tracks
topology counts only, not real geometry.

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

## Roadmap

The native OCCT-backed `KernelBridge` implementation (FFI) and the Flutter
viewport widget arrive in later milestones. Until then, `jet_cad` is usable
as a standalone document/undo-timeline library over `FakeKernelBridge`.

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
