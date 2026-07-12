# Plan 1: Scaffold + Document Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Monorepo scaffold plus the complete pure-Dart document layer of jet_cad: entity/id types, operations, `KernelBridge` interface, `FakeKernelBridge`, `CadDocument` with timeline undo/redo, typed events, and JSON persistence — fully unit-tested with zero native code.

**Architecture:** This is Plan 1 of 5 for the spec at `docs/superpowers/specs/2026-07-12-jet-cad-architecture-design.md`. It implements everything above the `KernelBridge` line. The fake bridge stands in for the OCCT shim (Plan 2) and must honor the same contracts the real one will: deterministic entity ids, id remap tables from every modeling op, and **id-preserving snapshot restore** (snapshots carry their UUIDs back — undo/redo depends on it).

**Tech Stack:** Flutter ≥ 3.24 / Dart ≥ 3.5 (pub workspaces, extension types), `vector_math` for `Matrix4`, `flutter_test`. No melos yet (pub workspace suffices; add melos only when cross-package scripts appear). No `dart:ffi` anywhere in this plan.

> **Plan authority:** this plan is authoritative for sequencing and interface
> contracts, not for exact code. If implementation reveals a cleaner shape,
> simplify — and update the task's Interfaces block to match.

## Global Constraints

- **Definition of Done (every task):** `flutter analyze` clean, `flutter test`
  green (full suite, not just the new file), `dart format lib test` produces no
  diff, no `TODO` comments introduced, and the public API surface changes only
  when the task's Interfaces block says so.
- **Public APIs are provisional until Plan 3 completes** — don't preserve a
  pre-viewport API out of inertia.
- Every plan/milestone keeps at least one test importing only
  `package:jet_cad/jet_cad.dart` (public-API-only), guarding export regressions.
- Dart SDK floor `^3.5.0`, Flutter floor `3.24.0` (workspace + extension-type support).
- Nothing above `KernelBridge` may import `dart:ffi` (spec hard rule). Plan 1 imports it nowhere.
- Package ships engine + viewport only; no opinionated UI (spec package boundary).
- All bridge-touching public APIs are async (spec: WASM-ready contract).
- Selection is never a document mutation — no selection ops, no selection undo (spec).
- Snapshot/undo bound: 50 steps (spec).
- Persistence header must carry `schemaVersion`, `kernelVersion`, `occtVersion` (spec).
- Commit style: conventional commits (`feat:`, `test:`, `chore:`), each task commits.
- Run all tests from `packages/jet_cad/` with `flutter test`.

---

### Task 1: Monorepo scaffold

**Files:**
- Create: `pubspec.yaml` (workspace root)
- Create: `packages/jet_cad/` (via `flutter create`, then trimmed)

**Interfaces:**
- Consumes: nothing
- Produces: a `jet_cad` package where `flutter test` and `flutter analyze` run clean; directory contract `lib/src/document/`, `lib/src/kernel/` for all later tasks

- [ ] **Step 1: Create workspace root pubspec**

Write `/pubspec.yaml` (repo root):

```yaml
name: jet_cad_workspace
publish_to: none
environment:
  sdk: ^3.5.0
workspace:
  - packages/jet_cad
```

- [ ] **Step 2: Scaffold the plugin package**

```bash
flutter create --template=plugin_ffi --platforms=macos,windows,linux --project-name jet_cad packages/jet_cad
```

Expected: package generated with `src/` (C scaffolding), `macos/`, `windows/`, `linux/` build glue. The native side stays untouched until Plan 2.

- [ ] **Step 3: Trim generated code**

```bash
rm -rf packages/jet_cad/example
rm -f packages/jet_cad/lib/jet_cad.dart packages/jet_cad/lib/jet_cad_bindings_generated.dart
mkdir -p packages/jet_cad/lib/src/document packages/jet_cad/lib/src/kernel packages/jet_cad/test/document packages/jet_cad/test/kernel
```

Create `packages/jet_cad/lib/jet_cad.dart` containing exactly:

```dart
/// A headless-first CAD engine and viewport for Flutter, backed by OCCT.
library;
```

- [ ] **Step 4: Edit package pubspec**

In `packages/jet_cad/pubspec.yaml`: set `description: A headless-first CAD engine and viewport widget for Flutter, built on Open CASCADE Technology.`, `version: 0.1.0`, add under top level `resolution: workspace`, set `environment: {sdk: ^3.5.0, flutter: ">=3.24.0"}`, and add dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
  vector_math: ^2.1.4
```

Ensure `dev_dependencies` contains `flutter_test: {sdk: flutter}` (add it if the
template didn't generate it). Keep the generated `plugin:` section (ffiPlugin
platforms) — Plan 2 needs it.

- [ ] **Step 5: Verify**

```bash
cd packages/jet_cad && flutter pub get && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore: scaffold pub workspace and jet_cad ffi plugin package"
```

---

### Task 2: Id, entity, and kernel value types

**Files:**
- Create: `packages/jet_cad/lib/src/document/entity.dart`
- Create: `packages/jet_cad/lib/src/kernel/kernel_types.dart`
- Test: `packages/jet_cad/test/document/entity_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `EntityId(String value)`, `BodyId`, `FaceId`, `EdgeId`, `VertexId` (extension types over `String`; the typed ids implement `EntityId`), `OpId(int value)`
  - `enum EntityKind { body, face, edge, vertex }`
  - `class Entity { EntityId id; EntityKind kind; String name; BodyId? parent; toJson(); Entity.fromJson(Map); ==/hashCode }`
  - `class IdRemap { Map<EntityId, List<EntityId>> mapping; static const empty; toJson(); IdRemap.fromJson(Map) }` (empty list = deleted)
  - `class Vec3 { double x, y, z; toJson(); Vec3.fromJson(List); == }`
  - `enum BoolOp { fuse, cut, common }`
  - `SessionHandle(int value)` extension type
  - `sealed class RenderTarget` with `final class HeadlessTarget extends RenderTarget { const HeadlessTarget(); }`
  - `class KernelSnapshot { Uint8List bytes; }`
  - `class KernelVersionInfo { String kernelVersion; String occtVersion; }`
  - `class KernelException implements Exception { String message; }`
  - `class CreateResult { BodyId body; List<FaceId> faces; List<EdgeId> edges; List<VertexId> vertices; IdRemap remap; }`

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/document/entity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';

void main() {
  test('typed ids are assignable to EntityId and compare by value', () {
    const EntityId id = BodyId('b1');
    expect(id, const BodyId('b1'));
    expect(id.value, 'b1');
  });

  test('Entity JSON round-trips', () {
    const face = Entity(
      id: FaceId('f1'),
      kind: EntityKind.face,
      name: 'Face',
      parent: BodyId('b1'),
    );
    expect(Entity.fromJson(face.toJson()), face);
  });

  test('IdRemap JSON round-trips including deletions', () {
    const remap = IdRemap({
      EntityId('b1'): [EntityId('b3')],
      EntityId('f2'): <EntityId>[],
    });
    final restored = IdRemap.fromJson(remap.toJson());
    expect(restored.mapping[const EntityId('b1')], [const EntityId('b3')]);
    expect(restored.mapping[const EntityId('f2')], isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/document/entity_test.dart`
Expected: FAIL — `entity.dart` does not exist.

- [ ] **Step 3: Implement entity.dart**

`packages/jet_cad/lib/src/document/entity.dart`:

```dart
/// Stable application identifier for anything the kernel exposes.
///
/// Real ids are UUIDs generated by the session layer (never by OCCT, which
/// has no identity facility). Extension types keep this zero-cost.
extension type const EntityId(String value) {
  String toJson() => value;
}

extension type const BodyId(String value) implements EntityId {}
extension type const FaceId(String value) implements EntityId {}
extension type const EdgeId(String value) implements EntityId {}
extension type const VertexId(String value) implements EntityId {}

/// Identifier of an [Operation] in a document's timeline. Monotonic per doc.
extension type const OpId(int value) {
  int toJson() => value;
}

enum EntityKind { body, face, edge, vertex }

/// Semantic record of one kernel entity: metadata only, never geometry.
class Entity {
  final EntityId id;
  final EntityKind kind;
  final String name;
  final BodyId? parent;

  const Entity({
    required this.id,
    required this.kind,
    required this.name,
    this.parent,
  });

  Map<String, Object?> toJson() => {
        'id': id.value,
        'kind': kind.name,
        'name': name,
        if (parent != null) 'parent': parent!.value,
      };

  factory Entity.fromJson(Map<String, Object?> json) => Entity(
        id: EntityId(json['id']! as String),
        kind: EntityKind.values.byName(json['kind']! as String),
        name: json['name']! as String,
        parent:
            json['parent'] == null ? null : BodyId(json['parent']! as String),
      );

  @override
  bool operator ==(Object other) =>
      other is Entity &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.parent == parent;

  @override
  int get hashCode => Object.hash(id, kind, name, parent);

  @override
  String toString() => 'Entity(${kind.name} ${id.value} "$name")';
}

/// Old id -> new ids table returned by every modeling operation.
/// An empty list means the old entity was consumed/deleted.
class IdRemap {
  final Map<EntityId, List<EntityId>> mapping;

  const IdRemap(this.mapping);

  static const IdRemap empty = IdRemap({});

  Map<String, Object?> toJson() => {
        for (final e in mapping.entries)
          e.key.value: [for (final id in e.value) id.value],
      };

  factory IdRemap.fromJson(Map<String, Object?> json) => IdRemap({
        for (final e in json.entries)
          EntityId(e.key): [
            for (final v in e.value! as List) EntityId(v as String),
          ],
      });
}
```

- [ ] **Step 4: Implement kernel_types.dart**

`packages/jet_cad/lib/src/kernel/kernel_types.dart`:

```dart
import 'dart:typed_data';

import '../document/entity.dart';

/// Immutable 3D vector for the public API (kernel-facing math only).
class Vec3 {
  final double x, y, z;

  const Vec3(this.x, this.y, this.z);

  List<double> toJson() => [x, y, z];

  factory Vec3.fromJson(List<Object?> json) => Vec3(
        (json[0]! as num).toDouble(),
        (json[1]! as num).toDouble(),
        (json[2]! as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

enum BoolOp { fuse, cut, common }

/// Opaque handle to a kernel session. One CadDocument owns exactly one.
extension type const SessionHandle(int value) {}

/// Where a session renders. Plan 1 is headless; Plan 3 adds texture targets.
sealed class RenderTarget {
  const RenderTarget();
}

final class HeadlessTarget extends RenderTarget {
  const HeadlessTarget();
}

/// Opaque whole-session geometry dump (BREP data + id map in the real shim).
class KernelSnapshot {
  final Uint8List bytes;

  const KernelSnapshot(this.bytes);
}

class KernelVersionInfo {
  final String kernelVersion;
  final String occtVersion;

  const KernelVersionInfo({
    required this.kernelVersion,
    required this.occtVersion,
  });
}

/// Kernel-side failure surfaced as a typed exception. Never a crash.
class KernelException implements Exception {
  final String message;

  const KernelException(this.message);

  @override
  String toString() => 'KernelException: $message';
}

/// Topology created or modified by one modeling command.
class CreateResult {
  final BodyId body;
  final List<FaceId> faces;
  final List<EdgeId> edges;
  final List<VertexId> vertices;
  final IdRemap remap;

  const CreateResult({
    required this.body,
    required this.faces,
    required this.edges,
    required this.vertices,
    this.remap = IdRemap.empty,
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/document/entity_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: entity ids, Entity, IdRemap, and kernel value types"
```

---

### Task 3: Operations

**Files:**
- Create: `packages/jet_cad/lib/src/document/operation.dart`
- Test: `packages/jet_cad/test/document/operation_test.dart`

**Interfaces:**
- Consumes: `entity.dart` types, `kernel_types.dart` (`Vec3`, `BoolOp`), `Matrix4` from `package:vector_math/vector_math_64.dart`
- Produces:
  - `sealed class Operation { OpId id; List<EntityId> inputs; List<EntityId> outputs; IdRemap remap; Map<String,Object?> toJson(); static Operation fromJson(Map) }`
  - `final class MakeBoxOp extends Operation { Vec3 size; }` (inputs `[]`)
  - `final class ExtrudeOp extends Operation { FaceId face; double depth; }` (inputs `[face]`)
  - `final class BooleanCombineOp extends Operation { BodyId a; BodyId b; BoolOp op; }` (inputs `[a, b]`)
  - `final class FilletOp extends Operation { List<EdgeId> edges; double radius; }` (inputs = edges)
  - `final class TransformOp extends Operation { List<BodyId> bodies; Matrix4 matrix; }` (inputs = bodies)
  - `final class ImportStepOp extends Operation { Uint8List stepBytes; }` (inputs `[]`; bytes kept for replay fallback)

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/document/operation_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/document/operation.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('MakeBoxOp round-trips through JSON', () {
    final op = MakeBoxOp(
      id: const OpId(1),
      size: const Vec3(10, 20, 30),
      outputs: const [BodyId('b1')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(op.toJson()) as MakeBoxOp;
    expect(restored.id, const OpId(1));
    expect(restored.size, const Vec3(10, 20, 30));
    expect(restored.outputs, const [BodyId('b1')]);
    expect(restored.inputs, isEmpty);
  });

  test('BooleanCombineOp round-trips with remap', () {
    final op = BooleanCombineOp(
      id: const OpId(2),
      a: const BodyId('b1'),
      b: const BodyId('b2'),
      op: BoolOp.cut,
      outputs: const [BodyId('b3')],
      remap: const IdRemap({
        EntityId('b1'): [EntityId('b3')],
        EntityId('f1'): <EntityId>[],
      }),
    );
    final restored = Operation.fromJson(op.toJson()) as BooleanCombineOp;
    expect(restored.op, BoolOp.cut);
    expect(restored.inputs, const [BodyId('b1'), BodyId('b2')]);
    expect(restored.remap.mapping[const EntityId('f1')], isEmpty);
  });

  test('TransformOp preserves the matrix', () {
    final m = Matrix4.identity()..translate(5.0, 0.0, 0.0);
    final op = TransformOp(
      id: const OpId(3),
      bodies: const [BodyId('b1')],
      matrix: m,
      outputs: const [BodyId('b1')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(op.toJson()) as TransformOp;
    expect(restored.matrix.storage, m.storage);
  });

  test('ImportStepOp keeps bytes for replay fallback', () {
    final bytes = Uint8List.fromList(utf8.encode('ISO-10303-21;'));
    final op = ImportStepOp(
      id: const OpId(4),
      stepBytes: bytes,
      outputs: const [BodyId('b1')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(op.toJson()) as ImportStepOp;
    expect(restored.stepBytes, bytes);
  });

  test('unknown operation type throws FormatException', () {
    expect(
      () => Operation.fromJson({'type': 'loft'}),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/document/operation_test.dart`
Expected: FAIL — `operation.dart` does not exist.

- [ ] **Step 3: Implement operation.dart**

`packages/jet_cad/lib/src/document/operation.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../kernel/kernel_types.dart';
import 'entity.dart';

/// One immutable step in a document's timeline. The applied state of a
/// document is always ops[0..head) — see the architecture spec.
sealed class Operation {
  final OpId id;
  final List<EntityId> inputs;
  final List<EntityId> outputs;
  final IdRemap remap;

  Operation({
    required this.id,
    required this.inputs,
    required this.outputs,
    required this.remap,
  });

  Map<String, Object?> toJson();

  Map<String, Object?> _baseJson(String type) => {
        'type': type,
        'id': id.value,
        'inputs': [for (final e in inputs) e.value],
        'outputs': [for (final e in outputs) e.value],
        'remap': remap.toJson(),
      };

  static OpId _id(Map<String, Object?> json) => OpId(json['id']! as int);

  static List<EntityId> _ids(Map<String, Object?> json, String key) =>
      [for (final v in json[key]! as List) EntityId(v as String)];

  static IdRemap _remap(Map<String, Object?> json) =>
      IdRemap.fromJson((json['remap']! as Map).cast<String, Object?>());

  static Operation fromJson(Map<String, Object?> json) {
    final type = json['type']! as String;
    return switch (type) {
      'makeBox' => MakeBoxOp(
          id: _id(json),
          size: Vec3.fromJson(json['size']! as List),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'extrude' => ExtrudeOp(
          id: _id(json),
          face: FaceId(json['face']! as String),
          depth: (json['depth']! as num).toDouble(),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'boolean' => BooleanCombineOp(
          id: _id(json),
          a: BodyId(json['a']! as String),
          b: BodyId(json['b']! as String),
          op: BoolOp.values.byName(json['op']! as String),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'fillet' => FilletOp(
          id: _id(json),
          edges: [for (final e in json['edges']! as List) EdgeId(e as String)],
          radius: (json['radius']! as num).toDouble(),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'transform' => TransformOp(
          id: _id(json),
          bodies: [
            for (final b in json['bodies']! as List) BodyId(b as String),
          ],
          matrix: Matrix4.fromList([
            for (final v in json['matrix']! as List) (v as num).toDouble(),
          ]),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'importStep' => ImportStepOp(
          id: _id(json),
          stepBytes: base64Decode(json['stepBytes']! as String),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      _ => throw FormatException('unknown operation type: $type'),
    };
  }
}

final class MakeBoxOp extends Operation {
  final Vec3 size;

  MakeBoxOp({
    required super.id,
    required this.size,
    required super.outputs,
    required super.remap,
  }) : super(inputs: const []);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('makeBox'), 'size': size.toJson()};
}

final class ExtrudeOp extends Operation {
  final FaceId face;
  final double depth;

  ExtrudeOp({
    required super.id,
    required this.face,
    required this.depth,
    required super.outputs,
    required super.remap,
  }) : super(inputs: [face]);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('extrude'), 'face': face.value, 'depth': depth};
}

final class BooleanCombineOp extends Operation {
  final BodyId a;
  final BodyId b;
  final BoolOp op;

  BooleanCombineOp({
    required super.id,
    required this.a,
    required this.b,
    required this.op,
    required super.outputs,
    required super.remap,
  }) : super(inputs: [a, b]);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('boolean'), 'a': a.value, 'b': b.value, 'op': op.name};
}

final class FilletOp extends Operation {
  final List<EdgeId> edges;
  final double radius;

  FilletOp({
    required super.id,
    required this.edges,
    required this.radius,
    required super.outputs,
    required super.remap,
  }) : super(inputs: List<EntityId>.from(edges));

  @override
  Map<String, Object?> toJson() => {
        ..._baseJson('fillet'),
        'edges': [for (final e in edges) e.value],
        'radius': radius,
      };
}

final class TransformOp extends Operation {
  final List<BodyId> bodies;
  final Matrix4 matrix;

  TransformOp({
    required super.id,
    required this.bodies,
    required this.matrix,
    required super.outputs,
    required super.remap,
  }) : super(inputs: List<EntityId>.from(bodies));

  @override
  Map<String, Object?> toJson() => {
        ..._baseJson('transform'),
        'bodies': [for (final b in bodies) b.value],
        'matrix': matrix.storage.toList(),
      };
}

final class ImportStepOp extends Operation {
  final Uint8List stepBytes;

  ImportStepOp({
    required super.id,
    required this.stepBytes,
    required super.outputs,
    required super.remap,
  }) : super(inputs: const []);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('importStep'), 'stepBytes': base64Encode(stepBytes)};
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/document/operation_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: sealed Operation hierarchy with JSON round-trip"
```

---

### Task 4: KernelBridge interface + FakeKernelBridge

**Files:**
- Create: `packages/jet_cad/lib/src/kernel/kernel_bridge.dart`
- Create: `packages/jet_cad/lib/src/kernel/fake_kernel_bridge.dart`
- Test: `packages/jet_cad/test/kernel/fake_kernel_bridge_test.dart`

**Interfaces:**
- Consumes: Task 2 and 3 types.
- Produces:
  - `abstract interface class KernelBridge` with exactly: `createSession(RenderTarget) → Future<SessionHandle>`, `disposeSession(SessionHandle)`, `versionInfo() → Future<KernelVersionInfo>`, `makeBox(SessionHandle, Vec3) → Future<CreateResult>`, `extrude(SessionHandle, FaceId, double) → Future<CreateResult>`, `booleanOp(SessionHandle, BodyId, BodyId, BoolOp) → Future<CreateResult>`, `fillet(SessionHandle, List<EdgeId>, double) → Future<CreateResult>`, `transform(SessionHandle, List<BodyId>, Matrix4) → Future<void>`, `importStep(SessionHandle, Uint8List) → Future<List<CreateResult>>`, `exportStep(SessionHandle, List<BodyId>) → Future<Uint8List>`, `snapshotBodies(SessionHandle, List<BodyId>) → Future<Uint8List>`, `restoreBodies(SessionHandle, Uint8List) → Future<void>`, `deleteBodies(SessionHandle, List<BodyId>) → Future<void>`, `saveSnapshot(SessionHandle) → Future<KernelSnapshot>`, `restoreSession(SessionHandle, KernelSnapshot) → Future<void>`.
    (Viewer/pick/selection methods arrive in Plan 3 — the spec marks the bridge as not frozen.)
  - `class FakeKernelBridge implements KernelBridge` — deterministic ids `b1, f2, e3…`; boxes have 6 faces/12 edges/8 vertices; `restoreBodies`/`restoreSession` are **id-preserving**; invalid inputs throw `KernelException`.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/kernel/fake_kernel_bridge_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  late FakeKernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = FakeKernelBridge();
    session = await bridge.createSession(const HeadlessTarget());
  });

  test('makeBox returns box topology with deterministic ids', () async {
    final r = await bridge.makeBox(session, const Vec3(1, 1, 1));
    expect(r.faces, hasLength(6));
    expect(r.edges, hasLength(12));
    expect(r.vertices, hasLength(8));
    expect(r.body.value, startsWith('b'));

    final bridge2 = FakeKernelBridge();
    final s2 = await bridge2.createSession(const HeadlessTarget());
    final r2 = await bridge2.makeBox(s2, const Vec3(1, 1, 1));
    expect(r2.body, r.body, reason: 'ids are deterministic per bridge');
  });

  test('booleanOp consumes inputs and reports remap', () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.fuse);

    expect(c.remap.mapping[a.body], [EntityId(c.body.value)]);
    expect(c.remap.mapping[b.body], [EntityId(c.body.value)]);
    expect(c.remap.mapping[a.faces.first], isEmpty);

    await expectLater(
      bridge.booleanOp(session, a.body, c.body, BoolOp.cut),
      throwsA(isA<KernelException>()),
      reason: 'body a was consumed',
    );
  });

  test('fillet replaces edges with new faces on the same body', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final edge = box.edges.first;
    final r = await bridge.fillet(session, [edge], 0.1);
    expect(r.body, box.body);
    expect(r.faces, hasLength(1));
    expect(r.remap.mapping[edge], hasLength(1));
  });

  test('snapshot and restore preserve ids', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final snapshot = await bridge.snapshotBodies(session, [box.body]);
    await bridge.deleteBodies(session, [box.body]);
    await expectLater(
      bridge.exportStep(session, [box.body]),
      throwsA(isA<KernelException>()),
    );

    await bridge.restoreBodies(session, snapshot);
    final step = await bridge.exportStep(session, [box.body]);
    expect(step, isNotEmpty, reason: 'body restored under its original id');
  });

  test('invalid inputs throw KernelException without corrupting state',
      () async {
    await expectLater(
      bridge.extrude(session, const FaceId('nope'), 5),
      throwsA(isA<KernelException>()),
    );
    await expectLater(
      bridge.makeBox(session, const Vec3(-1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    await expectLater(
      bridge.importStep(session, Uint8List(0)),
      throwsA(isA<KernelException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/kernel/fake_kernel_bridge_test.dart`
Expected: FAIL — bridge files do not exist.

- [ ] **Step 3: Implement kernel_bridge.dart**

`packages/jet_cad/lib/src/kernel/kernel_bridge.dart`:

```dart
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../document/entity.dart';
import 'kernel_types.dart';

/// Coarse, asynchronous command contract between the pure-Dart document
/// layer and a geometry kernel backend (FFI shim in v1, WASM later).
///
/// Ids cross this boundary; geometry never does. Implementations MUST make
/// [restoreBodies] and [restoreSession] id-preserving: a snapshot restores
/// entities under the exact ids it was taken with. Undo/redo depends on it.
///
/// This interface is intentionally not frozen. Viewer, pick, and selection
/// methods arrive in the viewport phase, and the per-operation methods may
/// evolve into a generic execute(KernelCommand) dispatcher before v1.0.
abstract interface class KernelBridge {
  Future<SessionHandle> createSession(RenderTarget target);
  Future<void> disposeSession(SessionHandle session);
  Future<KernelVersionInfo> versionInfo();

  Future<CreateResult> makeBox(SessionHandle session, Vec3 size);
  Future<CreateResult> extrude(SessionHandle session, FaceId face, double depth);
  Future<CreateResult> booleanOp(
      SessionHandle session, BodyId a, BodyId b, BoolOp op);
  Future<CreateResult> fillet(
      SessionHandle session, List<EdgeId> edges, double radius);
  Future<void> transform(
      SessionHandle session, List<BodyId> bodies, Matrix4 matrix);

  Future<List<CreateResult>> importStep(SessionHandle session, Uint8List bytes);
  Future<Uint8List> exportStep(SessionHandle session, List<BodyId> bodies);

  Future<Uint8List> snapshotBodies(SessionHandle session, List<BodyId> bodies);
  Future<void> restoreBodies(SessionHandle session, Uint8List snapshot);
  Future<void> deleteBodies(SessionHandle session, List<BodyId> bodies);

  Future<KernelSnapshot> saveSnapshot(SessionHandle session);
  Future<void> restoreSession(SessionHandle session, KernelSnapshot snapshot);
}
```

- [ ] **Step 4: Implement fake_kernel_bridge.dart**

`packages/jet_cad/lib/src/kernel/fake_kernel_bridge.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../document/entity.dart';
import 'kernel_bridge.dart';
import 'kernel_types.dart';

/// In-memory [KernelBridge] for tests and for consumers of jet_cad who need
/// to test their own document logic without a native build.
///
/// Honors the real shim's contracts: deterministic ids, remap tables from
/// every modeling op, id-preserving restore, KernelException on bad input.
/// It models topology counts only — no actual geometry.
class FakeKernelBridge implements KernelBridge {
  int _idCounter = 0;
  int _sessionCounter = 0;
  final Map<int, Map<String, _FakeBody>> _sessions = {};

  String _next(String prefix) => '$prefix${++_idCounter}';

  Map<String, _FakeBody> _session(SessionHandle s) =>
      _sessions[s.value] ?? (throw KernelException('unknown session: ${s.value}'));

  _FakeBody _body(Map<String, _FakeBody> bodies, BodyId id) =>
      bodies[id.value] ?? (throw KernelException('unknown body: ${id.value}'));

  _FakeBody _newBody(Map<String, _FakeBody> bodies) {
    final body = _FakeBody(
      id: _next('b'),
      faces: [for (var i = 0; i < 6; i++) _next('f')],
      edges: [for (var i = 0; i < 12; i++) _next('e')],
      vertices: [for (var i = 0; i < 8; i++) _next('v')],
    );
    bodies[body.id] = body;
    return body;
  }

  CreateResult _result(_FakeBody b, [IdRemap remap = IdRemap.empty]) =>
      CreateResult(
        body: BodyId(b.id),
        faces: [for (final f in b.faces) FaceId(f)],
        edges: [for (final e in b.edges) EdgeId(e)],
        vertices: [for (final v in b.vertices) VertexId(v)],
        remap: remap,
      );

  @override
  Future<SessionHandle> createSession(RenderTarget target) async {
    final handle = ++_sessionCounter;
    _sessions[handle] = {};
    return SessionHandle(handle);
  }

  @override
  Future<void> disposeSession(SessionHandle session) async {
    _sessions.remove(session.value);
  }

  @override
  Future<KernelVersionInfo> versionInfo() async => const KernelVersionInfo(
      kernelVersion: 'fake-1.0', occtVersion: 'none');

  @override
  Future<CreateResult> makeBox(SessionHandle session, Vec3 size) async {
    final bodies = _session(session);
    if (size.x <= 0 || size.y <= 0 || size.z <= 0) {
      throw const KernelException('box dimensions must be positive');
    }
    return _result(_newBody(bodies));
  }

  @override
  Future<CreateResult> extrude(
      SessionHandle session, FaceId face, double depth) async {
    final bodies = _session(session);
    final owner = bodies.values
        .where((b) => b.faces.contains(face.value))
        .firstOrNull;
    if (owner == null) {
      throw KernelException('unknown face: ${face.value}');
    }
    if (depth == 0) {
      throw const KernelException('extrude depth must be non-zero');
    }
    return _result(_newBody(bodies));
  }

  @override
  Future<CreateResult> booleanOp(
      SessionHandle session, BodyId a, BodyId b, BoolOp op) async {
    final bodies = _session(session);
    final bodyA = _body(bodies, a);
    final bodyB = _body(bodies, b);
    bodies.remove(a.value);
    bodies.remove(b.value);
    final result = _newBody(bodies);
    return _result(
      result,
      IdRemap({
        EntityId(bodyA.id): [EntityId(result.id)],
        EntityId(bodyB.id): [EntityId(result.id)],
        for (final sub in bodyA.subshapes.followedBy(bodyB.subshapes))
          EntityId(sub): const [],
      }),
    );
  }

  @override
  Future<CreateResult> fillet(
      SessionHandle session, List<EdgeId> edges, double radius) async {
    final bodies = _session(session);
    if (edges.isEmpty) {
      throw const KernelException('fillet needs at least one edge');
    }
    if (radius <= 0) {
      throw const KernelException('fillet radius must be positive');
    }
    final owner = bodies.values
        .where((b) => b.edges.contains(edges.first.value))
        .firstOrNull;
    if (owner == null) {
      throw KernelException('unknown edge: ${edges.first.value}');
    }
    for (final e in edges) {
      if (!owner.edges.contains(e.value)) {
        throw KernelException('edge not on body ${owner.id}: ${e.value}');
      }
    }
    final mapping = <EntityId, List<EntityId>>{};
    final newFaces = <String>[];
    for (final e in edges) {
      owner.edges.remove(e.value);
      final face = _next('f');
      owner.faces.add(face);
      newFaces.add(face);
      mapping[EntityId(e.value)] = [EntityId(face)];
    }
    return CreateResult(
      body: BodyId(owner.id),
      faces: [for (final f in newFaces) FaceId(f)],
      edges: const [],
      vertices: const [],
      remap: IdRemap(mapping),
    );
  }

  @override
  Future<void> transform(
      SessionHandle session, List<BodyId> bodies, Matrix4 matrix) async {
    final all = _session(session);
    for (final b in bodies) {
      _body(all, b);
    }
    // The fake tracks no coordinates; validation is the whole job.
  }

  @override
  Future<List<CreateResult>> importStep(
      SessionHandle session, Uint8List bytes) async {
    final bodies = _session(session);
    if (bytes.isEmpty) {
      throw const KernelException('empty STEP payload');
    }
    return [_result(_newBody(bodies))];
  }

  @override
  Future<Uint8List> exportStep(
      SessionHandle session, List<BodyId> bodies) async {
    final all = _session(session);
    for (final b in bodies) {
      _body(all, b);
    }
    final ids = [for (final b in bodies) b.value].join(',');
    return Uint8List.fromList(utf8.encode('FAKE-STEP:$ids'));
  }

  @override
  Future<Uint8List> snapshotBodies(
      SessionHandle session, List<BodyId> bodies) async {
    final all = _session(session);
    final dump = [for (final b in bodies) _body(all, b).toJson()];
    return Uint8List.fromList(utf8.encode(jsonEncode(dump)));
  }

  @override
  Future<void> restoreBodies(SessionHandle session, Uint8List snapshot) async {
    final bodies = _session(session);
    final dump = jsonDecode(utf8.decode(snapshot)) as List;
    for (final entry in dump) {
      final body = _FakeBody.fromJson((entry as Map).cast<String, Object?>());
      bodies[body.id] = body; // id-preserving by construction
    }
  }

  @override
  Future<void> deleteBodies(SessionHandle session, List<BodyId> bodies) async {
    final all = _session(session);
    for (final b in bodies) {
      all.remove(b.value);
    }
  }

  @override
  Future<KernelSnapshot> saveSnapshot(SessionHandle session) async {
    final bodies = _session(session);
    final dump = [for (final b in bodies.values) b.toJson()];
    return KernelSnapshot(Uint8List.fromList(utf8.encode(jsonEncode(dump))));
  }

  @override
  Future<void> restoreSession(
      SessionHandle session, KernelSnapshot snapshot) async {
    final bodies = _session(session)..clear();
    final dump = jsonDecode(utf8.decode(snapshot.bytes)) as List;
    for (final entry in dump) {
      final body = _FakeBody.fromJson((entry as Map).cast<String, Object?>());
      bodies[body.id] = body;
    }
  }
}

class _FakeBody {
  final String id;
  final List<String> faces;
  final List<String> edges;
  final List<String> vertices;

  _FakeBody({
    required this.id,
    required this.faces,
    required this.edges,
    required this.vertices,
  });

  Iterable<String> get subshapes =>
      faces.followedBy(edges).followedBy(vertices);

  Map<String, Object?> toJson() =>
      {'id': id, 'faces': faces, 'edges': edges, 'vertices': vertices};

  factory _FakeBody.fromJson(Map<String, Object?> json) => _FakeBody(
        id: json['id']! as String,
        faces: List<String>.from(json['faces']! as List),
        edges: List<String>.from(json['edges']! as List),
        vertices: List<String>.from(json['vertices']! as List),
      );
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/kernel/fake_kernel_bridge_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: KernelBridge contract and FakeKernelBridge"
```

---

### Task 5: CadDocument commands + DocChange events

**Files:**
- Create: `packages/jet_cad/lib/src/document/doc_change.dart`
- Create: `packages/jet_cad/lib/src/document/undo.dart`
- Create: `packages/jet_cad/lib/src/document/cad_document.dart`
- Test: `packages/jet_cad/test/document/cad_document_test.dart`

**Interfaces:**
- Consumes: `KernelBridge`, `FakeKernelBridge` (tests), all Task 2–3 types.
- Produces:
  - `sealed class DocChange` with `EntitiesAdded(List<EntityId> ids)`, `EntitiesRemoved(List<EntityId> ids)`, `OperationCommitted(Operation operation)`, `UndoPerformed(Operation operation)`, `RedoPerformed(Operation operation)`, `DocumentLoaded()` — all `final class … extends DocChange`.
  - `class UndoRecord { Uint8List? preSnapshot; List<BodyId> preBodies; Uint8List? postSnapshot; List<BodyId> postBodies; Map<EntityId, Entity> entitiesBefore; Map<EntityId, Entity> entitiesAfter; }` (library-private to the package, not exported).
  - `class CadDocument`:
    - `static Future<CadDocument> create(KernelBridge bridge)`
    - `Map<EntityId, Entity> get entities` (unmodifiable), `List<Operation> get operations` (unmodifiable), `int get head`, `bool get canUndo`, `bool get canRedo`, `Stream<DocChange> get changes`, `KernelVersionInfo get kernelVersions`
    - `Future<BodyId> makeBox(Vec3 size)`, `Future<BodyId> extrude(FaceId face, double depth)`, `Future<BodyId> booleanCombine(BodyId a, BodyId b, BoolOp op)`, `Future<List<FaceId>> fillet(List<EdgeId> edges, double radius)`, `Future<void> transform(List<BodyId> bodies, Matrix4 matrix)`, `Future<List<BodyId>> importStep(Uint8List bytes)`, `Future<Uint8List> exportStep(List<BodyId> bodies)`
    - `Future<void> dispose()`
    - Event order per command: `EntitiesRemoved` (if any) → `EntitiesAdded` (if any) → `OperationCommitted`.
    - Undo/redo methods come in Task 6; this task ships `canUndo`/`canRedo` returning correct values with `_undoFloor = 0`.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/document/cad_document_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/document/doc_change.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/document/operation.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  late CadDocument doc;

  setUp(() async {
    doc = await CadDocument.create(FakeKernelBridge());
  });

  tearDown(() => doc.dispose());

  test('makeBox registers body and subshape entities and commits an op',
      () async {
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);

    final body = await doc.makeBox(const Vec3(10, 10, 10));
    await Future<void>.delayed(Duration.zero);

    expect(doc.entities, hasLength(1 + 6 + 12 + 8));
    expect(doc.entities[body]!.kind, EntityKind.body);
    expect(doc.entities[body]!.name, 'Box 1');
    expect(doc.operations, hasLength(1));
    expect(doc.operations.single, isA<MakeBoxOp>());
    expect(doc.head, 1);

    expect(events, hasLength(2));
    expect(events[0], isA<EntitiesAdded>());
    expect(events[1], isA<OperationCommitted>());
    await sub.cancel();
  });

  test('booleanCombine consumes inputs and applies the remap', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final entitiesBefore = doc.entities.length;

    final c = await doc.booleanCombine(a, b, BoolOp.cut);

    expect(doc.entities.containsKey(a), isFalse);
    expect(doc.entities.containsKey(b), isFalse);
    expect(doc.entities[c]!.kind, EntityKind.body);
    // two full boxes (27 each) removed, one new box (27) added
    expect(doc.entities.length, entitiesBefore - 27);
    expect(doc.head, 3);
  });

  test('fillet keeps the body and swaps edge entities for face entities',
      () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    final edge = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge)
        .id as EdgeId;

    final newFaces = await doc.fillet([edge], 0.2);

    expect(doc.entities.containsKey(edge), isFalse);
    expect(doc.entities[newFaces.single]!.kind, EntityKind.face);
    expect(doc.entities[newFaces.single]!.parent, body);
    expect(doc.entities.containsKey(body), isTrue);
  });

  test('unknown input id throws ArgumentError and mutates nothing', () async {
    await expectLater(
      doc.extrude(const FaceId('nope'), 5),
      throwsArgumentError,
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
  });

  test('kernel failure surfaces as KernelException and mutates nothing',
      () async {
    await expectLater(
      doc.makeBox(const Vec3(-1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
    expect(doc.head, 0);
  });

  test('exportStep round-trips through the bridge', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    final bytes = await doc.exportStep([body]);
    expect(bytes, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/document/cad_document_test.dart`
Expected: FAIL — `cad_document.dart` does not exist.

- [ ] **Step 3: Implement doc_change.dart**

`packages/jet_cad/lib/src/document/doc_change.dart`:

```dart
import 'entity.dart';
import 'operation.dart';

/// Typed document events. Selection is deliberately NOT here: selection is
/// view state and belongs to the viewport controller's own stream (spec).
sealed class DocChange {
  const DocChange();
}

final class EntitiesAdded extends DocChange {
  final List<EntityId> ids;
  const EntitiesAdded(this.ids);
}

final class EntitiesRemoved extends DocChange {
  final List<EntityId> ids;
  const EntitiesRemoved(this.ids);
}

final class OperationCommitted extends DocChange {
  final Operation operation;
  const OperationCommitted(this.operation);
}

final class UndoPerformed extends DocChange {
  final Operation operation;
  const UndoPerformed(this.operation);
}

final class RedoPerformed extends DocChange {
  final Operation operation;
  const RedoPerformed(this.operation);
}

final class DocumentLoaded extends DocChange {
  const DocumentLoaded();
}
```

- [ ] **Step 4: Implement undo.dart**

`packages/jet_cad/lib/src/document/undo.dart`:

```dart
import 'dart:typed_data';

import 'entity.dart';

/// Everything needed to walk one operation backward or forward again.
///
/// Uniform algorithm (transform ops skip snapshots and use their inverse
/// matrix instead):
///   undo: delete postBodies, restore preSnapshot, swap entity maps back
///   redo: delete preBodies,  restore postSnapshot, swap entity maps forward
/// Snapshots are id-preserving, which is what makes redo safe: restored
/// bodies keep the ids that later operations reference.
class UndoRecord {
  final Uint8List? preSnapshot;
  final List<BodyId> preBodies;
  final Uint8List? postSnapshot;
  final List<BodyId> postBodies;
  final Map<EntityId, Entity> entitiesBefore;
  final Map<EntityId, Entity> entitiesAfter;

  const UndoRecord({
    this.preSnapshot,
    this.preBodies = const [],
    this.postSnapshot,
    this.postBodies = const [],
    this.entitiesBefore = const {},
    this.entitiesAfter = const {},
  });
}
```

- [ ] **Step 5: Implement cad_document.dart**

`packages/jet_cad/lib/src/document/cad_document.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../kernel/kernel_bridge.dart';
import '../kernel/kernel_types.dart';
import 'doc_change.dart';
import 'entity.dart';
import 'operation.dart';
import 'undo.dart';

/// The semantic CAD document: entities, operation timeline, undo/redo.
/// Pure Dart — geometry lives on the other side of [KernelBridge].
///
/// State is defined by operations[0..head). One document owns exactly one
/// kernel session (spec contract); [dispose] releases it.
class CadDocument {
  CadDocument._(this._bridge, this._session, this._versions);

  final KernelBridge _bridge;
  final SessionHandle _session;
  final KernelVersionInfo _versions;

  final Map<EntityId, Entity> _entities = {};
  final List<Operation> _ops = [];
  int _head = 0;
  int _undoFloor = 0;
  int _nextOpId = 1;
  final Map<String, int> _nameCounters = {};

  static const int maxUndoDepth = 50;
  final Map<OpId, UndoRecord> _undoRecords = {};

  final StreamController<DocChange> _changes =
      StreamController<DocChange>.broadcast();

  static Future<CadDocument> create(KernelBridge bridge) async {
    final session = await bridge.createSession(const HeadlessTarget());
    final versions = await bridge.versionInfo();
    return CadDocument._(bridge, session, versions);
  }

  Map<EntityId, Entity> get entities => Map.unmodifiable(_entities);
  List<Operation> get operations => List.unmodifiable(_ops);
  int get head => _head;
  bool get canUndo => _head > _undoFloor;
  bool get canRedo => _head < _ops.length;
  Stream<DocChange> get changes => _changes.stream;
  KernelVersionInfo get kernelVersions => _versions;

  Future<void> dispose() async {
    await _bridge.disposeSession(_session);
    await _changes.close();
  }

  OpId _newOpId() => OpId(_nextOpId++);

  String _nextName(String base) {
    final n = (_nameCounters[base] ?? 0) + 1;
    _nameCounters[base] = n;
    return '$base $n';
  }

  void _requireEntity(EntityId id) {
    if (!_entities.containsKey(id)) {
      throw ArgumentError('unknown entity: ${id.value}');
    }
  }

  Map<EntityId, Entity> _entitiesFor(CreateResult r, String bodyName) => {
        r.body: Entity(id: r.body, kind: EntityKind.body, name: bodyName),
        for (final f in r.faces)
          f: Entity(id: f, kind: EntityKind.face, name: 'Face', parent: r.body),
        for (final e in r.edges)
          e: Entity(id: e, kind: EntityKind.edge, name: 'Edge', parent: r.body),
        for (final v in r.vertices)
          v: Entity(
              id: v, kind: EntityKind.vertex, name: 'Vertex', parent: r.body),
      };

  void _commit(
    Operation op,
    UndoRecord record, {
    required Map<EntityId, Entity> added,
    required List<EntityId> removed,
  }) {
    // A new operation while head < ops.length truncates the redo branch.
    if (_head < _ops.length) {
      for (final dropped in _ops.sublist(_head)) {
        _undoRecords.remove(dropped.id);
      }
      _ops.removeRange(_head, _ops.length);
    }
    for (final id in removed) {
      _entities.remove(id);
    }
    _entities.addAll(added);
    _ops.add(op);
    _head++;
    _undoRecords[op.id] = record;
    _enforceUndoBound();
    if (removed.isNotEmpty) _changes.add(EntitiesRemoved(removed));
    if (added.isNotEmpty) _changes.add(EntitiesAdded(added.keys.toList()));
    _changes.add(OperationCommitted(op));
  }

  void _enforceUndoBound() {
    // Called right after commit, so any redo-branch records were already
    // dropped by truncation: every record belongs to ops[_undoFloor.._head).
    // Evicting from the floor is therefore O(1) — never scan _ops here
    // (a scan makes every commit O(n) and the timeline O(n^2)).
    while (_undoRecords.length > maxUndoDepth && _undoFloor < _head) {
      _undoRecords.remove(_ops[_undoFloor].id);
      _undoFloor++;
    }
  }

  Future<BodyId> makeBox(Vec3 size) async {
    final result = await _bridge.makeBox(_session, size);
    final post = await _bridge.snapshotBodies(_session, [result.body]);
    final added = _entitiesFor(result, _nextName('Box'));
    _commit(
      MakeBoxOp(
        id: _newOpId(),
        size: size,
        outputs: [result.body],
        remap: result.remap,
      ),
      UndoRecord(
        postSnapshot: post,
        postBodies: [result.body],
        entitiesAfter: added,
      ),
      added: added,
      removed: const [],
    );
    return result.body;
  }

  Future<BodyId> extrude(FaceId face, double depth) async {
    _requireEntity(face);
    final result = await _bridge.extrude(_session, face, depth);
    final post = await _bridge.snapshotBodies(_session, [result.body]);
    final added = _entitiesFor(result, _nextName('Extrude'));
    _commit(
      ExtrudeOp(
        id: _newOpId(),
        face: face,
        depth: depth,
        outputs: [result.body],
        remap: result.remap,
      ),
      UndoRecord(
        postSnapshot: post,
        postBodies: [result.body],
        entitiesAfter: added,
      ),
      added: added,
      removed: const [],
    );
    return result.body;
  }

  Future<BodyId> booleanCombine(BodyId a, BodyId b, BoolOp op) async {
    _requireEntity(a);
    _requireEntity(b);
    final pre = await _bridge.snapshotBodies(_session, [a, b]);
    final result = await _bridge.booleanOp(_session, a, b, op);
    final post = await _bridge.snapshotBodies(_session, [result.body]);
    final removed = result.remap.mapping.keys.toList();
    final before = <EntityId, Entity>{
      for (final id in removed)
        if (_entities[id] != null) id: _entities[id]!,
    };
    final added = _entitiesFor(result, _nextName('Boolean'));
    _commit(
      BooleanCombineOp(
        id: _newOpId(),
        a: a,
        b: b,
        op: op,
        outputs: [result.body],
        remap: result.remap,
      ),
      UndoRecord(
        preSnapshot: pre,
        preBodies: [a, b],
        postSnapshot: post,
        postBodies: [result.body],
        entitiesBefore: before,
        entitiesAfter: added,
      ),
      added: added,
      removed: removed,
    );
    return result.body;
  }

  Future<List<FaceId>> fillet(List<EdgeId> edges, double radius) async {
    for (final e in edges) {
      _requireEntity(e);
    }
    final body = _entities[edges.first]!.parent!;
    final pre = await _bridge.snapshotBodies(_session, [body]);
    final result = await _bridge.fillet(_session, edges, radius);
    final post = await _bridge.snapshotBodies(_session, [result.body]);
    final removed = result.remap.mapping.keys.toList();
    final before = <EntityId, Entity>{
      for (final id in removed)
        if (_entities[id] != null) id: _entities[id]!,
    };
    final added = <EntityId, Entity>{
      for (final f in result.faces)
        f: Entity(
            id: f, kind: EntityKind.face, name: 'Face', parent: result.body),
    };
    _commit(
      FilletOp(
        id: _newOpId(),
        edges: edges,
        radius: radius,
        outputs: [result.body, ...result.faces],
        remap: result.remap,
      ),
      UndoRecord(
        preSnapshot: pre,
        preBodies: [body],
        postSnapshot: post,
        postBodies: [result.body],
        entitiesBefore: before,
        entitiesAfter: added,
      ),
      added: added,
      removed: removed,
    );
    return result.faces;
  }

  Future<void> transform(List<BodyId> bodies, Matrix4 matrix) async {
    for (final b in bodies) {
      _requireEntity(b);
    }
    if (matrix.determinant() == 0) {
      throw ArgumentError('transform matrix must be invertible');
    }
    await _bridge.transform(_session, bodies, matrix);
    _commit(
      TransformOp(
        id: _newOpId(),
        bodies: bodies,
        matrix: matrix,
        outputs: List<EntityId>.from(bodies),
        remap: IdRemap.empty,
      ),
      const UndoRecord(),
      added: const {},
      removed: const [],
    );
  }

  Future<List<BodyId>> importStep(Uint8List bytes) async {
    final results = await _bridge.importStep(_session, bytes);
    final bodyIds = [for (final r in results) r.body];
    final post = await _bridge.snapshotBodies(_session, bodyIds);
    final added = <EntityId, Entity>{
      for (final r in results) ..._entitiesFor(r, _nextName('Import')),
    };
    _commit(
      ImportStepOp(
        id: _newOpId(),
        stepBytes: bytes,
        outputs: List<EntityId>.from(bodyIds),
        remap: IdRemap.empty,
      ),
      UndoRecord(
        postSnapshot: post,
        postBodies: bodyIds,
        entitiesAfter: added,
      ),
      added: added,
      removed: const [],
    );
    return bodyIds;
  }

  Future<Uint8List> exportStep(List<BodyId> bodies) {
    for (final b in bodies) {
      _requireEntity(b);
    }
    return _bridge.exportStep(_session, bodies);
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/document/cad_document_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: CadDocument command flow with typed DocChange events"
```

---

### Task 6: Undo/redo timeline

**Files:**
- Modify: `packages/jet_cad/lib/src/document/cad_document.dart` (add `undo`, `redo`)
- Test: `packages/jet_cad/test/document/undo_redo_test.dart`

**Interfaces:**
- Consumes: Task 5's `CadDocument` internals (`_undoRecords`, `_head`, `_undoFloor`).
- Produces: `Future<void> undo()`, `Future<void> redo()` on `CadDocument`; both throw `StateError` when unavailable; emit `EntitiesRemoved`/`EntitiesAdded` (as applicable) then `UndoPerformed`/`RedoPerformed`.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/document/undo_redo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  late CadDocument doc;

  setUp(() async {
    doc = await CadDocument.create(FakeKernelBridge());
  });

  tearDown(() => doc.dispose());

  test('undo/redo of makeBox restores the same ids', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    expect(doc.canUndo, isTrue);

    await doc.undo();
    expect(doc.head, 0);
    expect(doc.entities, isEmpty);
    expect(doc.canUndo, isFalse);
    expect(doc.canRedo, isTrue);
    expect(doc.operations, hasLength(1), reason: 'timeline keeps the op');

    await doc.redo();
    expect(doc.head, 1);
    expect(doc.entities.containsKey(body), isTrue,
        reason: 'id-preserving restore');
    expect(doc.canRedo, isFalse);
  });

  test('undo of boolean restores both consumed bodies', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final c = await doc.booleanCombine(a, b, BoolOp.fuse);

    await doc.undo();
    expect(doc.entities.containsKey(a), isTrue);
    expect(doc.entities.containsKey(b), isTrue);
    expect(doc.entities.containsKey(c), isFalse);

    await doc.redo();
    expect(doc.entities.containsKey(a), isFalse);
    expect(doc.entities.containsKey(c), isTrue);
  });

  test('undo of transform applies the inverse via the bridge', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    final m = Matrix4.identity()..translate(5.0, 0.0, 0.0);
    await doc.transform([body], m);
    expect(doc.head, 2);

    await doc.undo();
    expect(doc.head, 1);
    expect(doc.entities.containsKey(body), isTrue,
        reason: 'transform undo never touches entities');
  });

  test('new command after undo truncates the redo branch', () async {
    await doc.makeBox(const Vec3(1, 1, 1));
    await doc.makeBox(const Vec3(2, 2, 2));
    await doc.undo();
    expect(doc.canRedo, isTrue);

    await doc.makeBox(const Vec3(3, 3, 3));
    expect(doc.canRedo, isFalse);
    expect(doc.operations, hasLength(2));
    expect(doc.head, 2);
  });

  test('chained booleans remap across generations (A -> C -> D)', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final c = await doc.booleanCombine(a, b, BoolOp.fuse);
    final e = await doc.makeBox(const Vec3(3, 3, 3));
    final d = await doc.booleanCombine(c, e, BoolOp.cut);

    expect(doc.entities.containsKey(d), isTrue);
    expect(doc.entities.containsKey(c), isFalse);
    expect(doc.entities.containsKey(a), isFalse);

    await doc.undo(); // back to C + E
    expect(doc.entities.containsKey(c), isTrue);
    expect(doc.entities.containsKey(e), isTrue);
    expect(doc.entities.containsKey(d), isFalse);

    await doc.undo(); // undoes makeBox E
    expect(doc.entities.containsKey(e), isFalse);
    expect(doc.entities.containsKey(c), isTrue);

    await doc.redo();
    await doc.redo(); // forward to D again
    expect(doc.entities.containsKey(d), isTrue,
        reason: 'redo across generations needs id-preserving restore');
    expect(doc.entities.containsKey(c), isFalse);
  });

  test('undo depth is bounded at maxUndoDepth', () async {
    for (var i = 0; i < CadDocument.maxUndoDepth + 5; i++) {
      await doc.makeBox(const Vec3(1, 1, 1));
    }
    var undone = 0;
    while (doc.canUndo) {
      await doc.undo();
      undone++;
    }
    expect(undone, CadDocument.maxUndoDepth);
    expect(() => doc.undo(), throwsStateError);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/document/undo_redo_test.dart`
Expected: FAIL — `undo`/`redo` not defined.

- [ ] **Step 3: Add undo/redo to cad_document.dart**

Append inside `class CadDocument` (after `exportStep`):

```dart
  Future<void> undo() async {
    if (!canUndo) {
      throw StateError('nothing to undo');
    }
    final op = _ops[_head - 1];
    final record = _undoRecords[op.id]!;
    if (op is TransformOp) {
      await _bridge.transform(
          _session, op.bodies, Matrix4.inverted(op.matrix));
    } else {
      if (record.postBodies.isNotEmpty) {
        await _bridge.deleteBodies(_session, record.postBodies);
      }
      if (record.preSnapshot != null) {
        await _bridge.restoreBodies(_session, record.preSnapshot!);
      }
    }
    final removed = record.entitiesAfter.keys.toList();
    for (final id in removed) {
      _entities.remove(id);
    }
    _entities.addAll(record.entitiesBefore);
    _head--;
    if (removed.isNotEmpty) _changes.add(EntitiesRemoved(removed));
    if (record.entitiesBefore.isNotEmpty) {
      _changes.add(EntitiesAdded(record.entitiesBefore.keys.toList()));
    }
    _changes.add(UndoPerformed(op));
  }

  Future<void> redo() async {
    if (!canRedo) {
      throw StateError('nothing to redo');
    }
    final op = _ops[_head];
    final record = _undoRecords[op.id]!;
    if (op is TransformOp) {
      await _bridge.transform(_session, op.bodies, op.matrix);
    } else {
      if (record.preBodies.isNotEmpty) {
        await _bridge.deleteBodies(_session, record.preBodies);
      }
      if (record.postSnapshot != null) {
        await _bridge.restoreBodies(_session, record.postSnapshot!);
      }
    }
    final removed = record.entitiesBefore.keys.toList();
    for (final id in removed) {
      _entities.remove(id);
    }
    _entities.addAll(record.entitiesAfter);
    _head++;
    if (removed.isNotEmpty) _changes.add(EntitiesRemoved(removed));
    if (record.entitiesAfter.isNotEmpty) {
      _changes.add(EntitiesAdded(record.entitiesAfter.keys.toList()));
    }
    _changes.add(RedoPerformed(op));
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/document/undo_redo_test.dart`
Expected: PASS (6 tests). Also run the full suite: `flutter test` — all previous tests still pass.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: timeline undo/redo with bounded snapshot records"
```

---

### Task 7: JSON persistence

**Files:**
- Create: `packages/jet_cad/lib/src/document/codec.dart`
- Modify: `packages/jet_cad/lib/src/document/cad_document.dart` (add `static Future<CadDocument> load`)
- Test: `packages/jet_cad/test/document/codec_test.dart`

**Interfaces:**
- Consumes: `CadDocument`, `Operation.fromJson`, `Entity.fromJson`.
- Produces:
  - `class CadDocumentCodec { static const int schemaVersion = 1; static Map<String, Object?> encode(CadDocument doc); }`
  - `static Future<CadDocument> load(Map<String, Object?> json, KernelBridge bridge)` on `CadDocument`. Restores document state (entities, ops, head) and emits `DocumentLoaded`. Pre-load operations are not undoable (`_undoFloor = head`). Kernel-side geometry reconstruction via `restoreSession` is wired in Plan 2 when a real `KernelSnapshot` blob exists; this task documents that in a doc comment on `load`.
  - Throws `FormatException` on unknown `schemaVersion`.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/document/codec_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/document/codec.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  test('encode/load round-trips ops, entities, and head', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    await doc.booleanCombine(a, b, BoolOp.fuse);
    await doc.undo(); // head = 2 of 3

    final json =
        jsonDecode(jsonEncode(CadDocumentCodec.encode(doc)))
            as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect(json['kernelVersion'], 'fake-1.0');
    expect(json['occtVersion'], 'none');

    final restored = await CadDocument.load(json, FakeKernelBridge());
    expect(restored.head, doc.head);
    expect(restored.operations.length, doc.operations.length);
    expect(restored.entities, doc.entities);
    expect(restored.canUndo, isFalse,
        reason: 'pre-load ops are not undoable in v1');
    await doc.dispose();
    await restored.dispose();
  });

  test('load emits DocumentLoaded and continues numbering ops', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    await doc.makeBox(const Vec3(1, 1, 1));
    final json = CadDocumentCodec.encode(doc);

    final restored = await CadDocument.load(json, FakeKernelBridge());
    await restored.makeBox(const Vec3(2, 2, 2));
    final ids = [for (final op in restored.operations) op.id.value];
    expect(ids.toSet().length, ids.length, reason: 'op ids stay unique');
    await doc.dispose();
    await restored.dispose();
  });

  test('unknown schema version throws FormatException', () async {
    await expectLater(
      CadDocument.load({'schemaVersion': 99}, FakeKernelBridge()),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/document/codec_test.dart`
Expected: FAIL — `codec.dart` does not exist.

- [ ] **Step 3: Implement codec.dart**

`packages/jet_cad/lib/src/document/codec.dart`:

```dart
import 'cad_document.dart';

/// JSON document format. The header carries schemaVersion plus the kernel
/// and OCCT versions that produced the file (spec: recorded from day 1).
class CadDocumentCodec {
  static const int schemaVersion = 1;

  static Map<String, Object?> encode(CadDocument doc) => {
        'schemaVersion': schemaVersion,
        'kernelVersion': doc.kernelVersions.kernelVersion,
        'occtVersion': doc.kernelVersions.occtVersion,
        'head': doc.head,
        'ops': [for (final op in doc.operations) op.toJson()],
        'entities': [for (final e in doc.entities.values) e.toJson()],
      };
}
```

- [ ] **Step 4: Add load to cad_document.dart**

Add import to `cad_document.dart`: `import 'codec.dart';`
Append inside `class CadDocument` (after `create`):

```dart
  /// Restores document state from [CadDocumentCodec.encode] output.
  ///
  /// v1 restores the semantic document only. Kernel geometry reconstruction
  /// (restoreSession with a real KernelSnapshot blob, or replay of
  /// ops[0..head) as fallback) is wired when the FFI backend lands.
  /// Pre-load operations are not undoable.
  static Future<CadDocument> load(
      Map<String, Object?> json, KernelBridge bridge) async {
    final schema = json['schemaVersion'];
    if (schema != CadDocumentCodec.schemaVersion) {
      throw FormatException('unsupported schema version: $schema');
    }
    final doc = await create(bridge);
    for (final e in json['entities']! as List) {
      final entity = Entity.fromJson((e as Map).cast<String, Object?>());
      doc._entities[entity.id] = entity;
    }
    var maxOpId = 0;
    for (final o in json['ops']! as List) {
      final op = Operation.fromJson((o as Map).cast<String, Object?>());
      doc._ops.add(op);
      if (op.id.value > maxOpId) maxOpId = op.id.value;
    }
    doc._head = json['head']! as int;
    doc._undoFloor = doc._head;
    doc._nextOpId = maxOpId + 1;
    doc._changes.add(const DocumentLoaded());
    return doc;
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/document/codec_test.dart`
Expected: PASS (3 tests). Full suite: `flutter test` — all pass.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: versioned JSON persistence with document load"
```

---

### Task 8: Public API surface + stress test

**Files:**
- Modify: `packages/jet_cad/lib/jet_cad.dart`
- Test: `packages/jet_cad/test/public_api_test.dart`
- Test: `packages/jet_cad/test/document/stress_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: the pub-facing API — consumers import only `package:jet_cad/jet_cad.dart`. `UndoRecord` and `_FakeBody` stay private; `FakeKernelBridge` IS exported (consumers need it to test their own code).

- [ ] **Step 1: Write the failing test**

`packages/jet_cad/test/public_api_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  test('the public surface is usable end-to-end from one import', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final c = await doc.booleanCombine(a, b, BoolOp.cut);
    await doc.transform([c], Matrix4.identity()..translate(1.0, 0.0, 0.0));
    await doc.undo();
    await doc.redo();
    final json = CadDocumentCodec.encode(doc);
    final restored = await CadDocument.load(json, FakeKernelBridge());
    expect(restored.head, doc.head);
    await doc.dispose();
    await restored.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/public_api_test.dart`
Expected: FAIL — names not exported from `jet_cad.dart`.

- [ ] **Step 3: Write the export file**

`packages/jet_cad/lib/jet_cad.dart`:

```dart
/// A headless-first CAD engine and viewport for Flutter, backed by OCCT.
///
/// v1 surface: pure-Dart document model over an abstract kernel bridge.
/// The FFI/OCCT backend and the viewport widget arrive in later milestones.
library;

export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'src/document/cad_document.dart' show CadDocument;
export 'src/document/codec.dart' show CadDocumentCodec;
export 'src/document/doc_change.dart';
export 'src/document/entity.dart';
export 'src/document/operation.dart';
export 'src/kernel/fake_kernel_bridge.dart' show FakeKernelBridge;
export 'src/kernel/kernel_bridge.dart' show KernelBridge;
export 'src/kernel/kernel_types.dart';
```

- [ ] **Step 4: Add the stress test**

`packages/jet_cad/test/document/stress_test.dart` (public-API-only import;
guards against accidental O(n²) in the timeline — document models rot that
way. The generous wall-clock bound is a smoke alarm, not a benchmark):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  test('5000 operations do not blow up quadratically', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < 5000; i++) {
      await doc.makeBox(const Vec3(1, 1, 1));
    }
    stopwatch.stop();
    expect(doc.operations, hasLength(5000));
    expect(doc.entities, hasLength(5000 * 27));
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    await doc.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 5: Run tests + analyze + format to verify**

```bash
flutter test && flutter analyze && dart format --set-exit-if-changed lib test
```

Expected: all tests PASS, `No issues found!`, no format diff.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad && git commit -m "feat: public API exports and timeline stress test"
```

---

## Deferred to later plans (explicit)

- Plan 2: C++ shim, real `FfiKernelBridge`, OCCT via Homebrew for dev, GoogleTest, `restoreSession` wiring in `CadDocument.load`, replay fallback.
- Plan 3: `JetCadViewport`, `ViewportController` (+ its `SelectionChanged` stream), bridge viewer/pick/selection methods, macOS texture path first.
- Plan 4: demo app.
- Plan 5: prebuilt binary distribution, CI matrix, remaining desktop platforms.
