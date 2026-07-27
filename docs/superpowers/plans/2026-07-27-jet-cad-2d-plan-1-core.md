# jet_cad_2d Plan 1 — Engine Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Dart document core of `jet_cad_2d` — identity, columnar stores, scene tree, components, tables, commands with undo, and a minimal deterministic JSON codec — with no Flutter dependency and no rendering.

**Architecture:** A `DraftDocument` owns four kinds of state: object-per-record containers (nodes, definitions, table records), columnar stores for leaves (`EntityStore`, `GeometryStore`), sparse type-keyed component stores, and an opaque preserve-unknown blob. Mutation happens only through `DraftCommand`s, each of which declares a capability and produces its inverse; the document publishes a `DocChange` stream. Everything derived — working extents, world transforms, resolved style — is recomputed and never persisted.

**Tech Stack:** Dart 3.12+ (no Flutter), `package:vector_math/vector_math_64.dart` for `Vector2`, `package:meta` for `@immutable`, `package:test` for tests, `package:lints` for analysis.

**Spec:** [2026-07-27-jet-cad-2d-architecture-design.md](../specs/2026-07-27-jet-cad-2d-architecture-design.md) — Architecture v1.2. Read the *Document model* section before starting.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec.

- **No Flutter dependency in `jet_cad_2d`.** Tests run under `dart test`, never `flutter test`. A `flutter` import anywhere in `lib/` is a defect.
- **No FFI, no native build, no format names.** The strings `dxf` and `ifc` may appear in `jet_cad_2d` only as (a) the `SourceKind` enum and (b) `GroupNode.exportAsDxfGroup`. Nowhere else.
- **The handle space is 32-bit.** Entity columns are `Uint32List`; `2^32 - 1` is the ceiling on every platform. `Handle.none == Handle(0)` is the absent value. Fields never use `Handle?`.
- **`==` on doubles is prohibited for _geometric_ decisions.** Anything answering "are these the same point, length or angle" goes through `Tolerance`. That is the question tolerance exists for, and an exact comparison there is a defect.

  **Stored-value comparisons are exact, deliberately.** Value-record `operator ==` and fast-path guards answer a different question — "did the stored value change" — which must be bit-precise. A tolerance-based record equality would make undo miss real edits: a 1e-12 width change is still an edit the user made and must be undoable. It would also make `==` inconsistent with `hashCode`, which cannot be tolerance-based.

  This covers, without further exception: `Transform2.isIdentity` (fast-path guard; false negatives cost a redundant multiply, false positives are impossible), `closestPointOnSegment`'s `lengthSq == 0.0` (guards division by literal zero only — the clamp already handles near-degenerate segments), and every value record's `operator ==` (`DashPattern`, `PatternLine`, `TextStyleRecord`, `GroupNode`, `InstanceNode`, `Definition`, `EntityRecord`, …). Each should say so at its definition.
- **Coordinates are `Float64` in document units.** Screen coordinates never enter the model.
- **Slot lifetime rules apply to both `GeometryStore` and `EntityStore`:** (1) slots change only inside a command that rewrites every reference; no ambient compaction, ever. (2) Deletion frees the slot to a free list; the inverse command carries the *payload*, not the slot. (3) Compaction exists only as an explicit `purge()` that rewrites all references and clears the undo stack — not a command, not undoable.
- **Derived state is never persisted and never versioned:** working extents, world transforms, spatial index, resolved style, runtime overrides, text layout boxes. `importedExtents` is a *separate*, opaque, round-trip-only header value.
- **Components are immutable, value-equal, and `toJson` emits keys in a stable order.**
- **Serialization is deterministic:** the same document produces byte-identical JSON. Hash iteration order is prohibited in any codec path.
- **No layer discards data it does not understand.** Unknown component `typeId`s and unknown JSON fields are preserved verbatim.

---

## File Structure

```
packages/jet_cad_2d/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── CHANGELOG.md
├── lib/
│   ├── jet_cad_2d.dart              # public API barrel — the only export surface
│   └── src/
│       ├── core/
│       │   ├── handle.dart          # Handle, Handle.none, 32-bit invariant
│       │   ├── diagnostic.dart      # Diagnostic, DiagnosticSeverity
│       │   └── tolerance.dart       # Tolerance, double comparison helpers
│       ├── geometry/
│       │   ├── transform2.dart      # 2x3 affine, Float64 composition
│       │   ├── aabb2.dart           # Aabb2
│       │   └── primitives.dart      # point/segment/arc distance, segment intersection
│       ├── store/
│       │   ├── slot_allocator.dart  # shared free-list; the slot lifetime contract
│       │   ├── geometry_store.dart  # columnar coordinates
│       │   └── entity_store.dart    # columnar entity records incl. tier-1 style
│       ├── document/
│       │   ├── tables.dart          # LayerRecord, LinetypeRecord, TextStyleRecord, …
│       │   ├── style.dart           # DraftColor, encoded style sentinels
│       │   ├── node.dart            # Node, GroupNode, InstanceNode, Definition
│       │   ├── tree.dart            # tree mutation + cycle detection
│       │   ├── component.dart       # Component, ComponentStore, ComponentRegistry
│       │   ├── origin_component.dart
│       │   ├── extents.dart         # derived working extents
│       │   ├── doc_change.dart      # DocChange event hierarchy
│       │   ├── command.dart         # DraftCommand, DraftPermissions, dispatcher
│       │   ├── undo.dart            # undo/redo stacks
│       │   └── draft_document.dart  # assembly + public document API
│       └── codec/
│           ├── schema_version.dart  # version constant + guard
│           └── json_codec.dart      # deterministic encode/decode
└── test/
    ├── core/ · geometry/ · store/ · document/ · codec/    # mirrors lib/src
    └── invariants/                  # cross-cutting contract tests
```

**Why these boundaries:** `core/` and `geometry/` have no dependencies on anything else and are pure value types. `store/` depends only on those. `document/` composes stores into a document. `codec/` depends on `document/` and nothing depends on `codec/`. The dependency graph is a DAG with no cycles, so any file can be understood without reading its dependents.

---

### Task 1: Package scaffold and workspace wiring

**Files:**
- Create: `packages/jet_cad_2d/pubspec.yaml`
- Create: `packages/jet_cad_2d/analysis_options.yaml`
- Create: `packages/jet_cad_2d/README.md`
- Create: `packages/jet_cad_2d/CHANGELOG.md`
- Create: `packages/jet_cad_2d/lib/jet_cad_2d.dart`
- Modify: `pubspec.yaml` (root workspace list)

**Interfaces:**
- Consumes: nothing.
- Produces: a workspace package named `jet_cad_2d` that resolves and analyzes clean. Every later task adds files under this package.

**No test in this task.** A scaffold has no behaviour to assert, and a test whose only assertion is a tautology is a defect, not a smoke test. `dart pub get` proves the workspace wiring and `dart analyze` proves the package compiles; the first `dart test` run happens in Task 2, against real behaviour.

- [ ] **Step 1: Create the package pubspec**

Create `packages/jet_cad_2d/pubspec.yaml`:

```yaml
name: jet_cad_2d
description: >-
  Pure-Dart 2D CAD engine and document model. Independent of the jet_cad 3D
  package — no OCCT, no FFI, no native build, no Flutter dependency.
version: 0.1.0
repository: https://github.com/ahmeturel/jet-cad
resolution: workspace

environment:
  sdk: ^3.5.0
```

- [ ] **Step 2: Add the package to the workspace**

Modify the root `pubspec.yaml`. It currently reads:

```yaml
workspace:
  - packages/jet_cad
  - apps/dev_harness
```

Change it to:

```yaml
workspace:
  - packages/jet_cad
  - packages/jet_cad_2d
  - apps/dev_harness
```

- [ ] **Step 3: Add dependencies**

Run these from the repository root. Using `pub add` rather than hand-written constraints means the resolved versions are whatever is current and compatible, with no guessing:

```bash
cd packages/jet_cad_2d
dart pub add vector_math meta
dart pub add dev:test dev:lints
cd ../..
```

- [ ] **Step 4: Create the analysis options**

Create `packages/jet_cad_2d/analysis_options.yaml`. This is stricter than the 3D package's `flutter_lints` include, deliberately: the constraints in this plan (no implicit dynamic, no unawaited futures in a document that must stay deterministic) are cheaper to enforce mechanically than in review.

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    unused_import: error
    unused_local_variable: error

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - prefer_final_locals
    - unawaited_futures
```

- [ ] **Step 5: Create the public barrel**

Create `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
/// A pure-Dart 2D CAD engine and document model.
///
/// This package has no Flutter dependency and performs no rendering. The
/// widget layer lives in `jet_cad_2d_flutter`; format adapters live in their
/// own packages and use only this package's public API.
library;

// Exports are added by later tasks as each unit lands.
```

- [ ] **Step 6: Create README and CHANGELOG**

Create `packages/jet_cad_2d/README.md`:

```markdown
# jet_cad_2d

A pure-Dart 2D CAD engine and document model: identity, scene tree, columnar
geometry and entity stores, components, commands with undo, and a deterministic
document format.

**This package is independent of `jet_cad`.** Despite the shared name it does
not depend on it, does not link Open CASCADE, and shares no code with it. It has
no Flutter dependency and runs anywhere Dart runs.

Rendering and widgets live in `jet_cad_2d_flutter`. DXF and IFC support live in
separate adapter packages and use only this package's public API.

Status: pre-release. See
`docs/superpowers/specs/2026-07-27-jet-cad-2d-architecture-design.md`.
```

Create `packages/jet_cad_2d/CHANGELOG.md`:

```markdown
## 0.1.0

- Initial development release. Engine core: identity, stores, tree, components,
  commands, JSON codec.
```

- [ ] **Step 7: Verify the package resolves and analyzes clean**

```bash
cd packages/jet_cad_2d && dart pub get && dart analyze && cd ../..
```

Expected: dependencies resolve, then `No issues found!`.

If `dart pub get` reports that `jet_cad_2d` is not a workspace member, the root
`pubspec.yaml` edit in Step 2 did not take effect; re-apply it and run
`dart pub get` from the repository root.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d pubspec.yaml pubspec.lock
git commit -m "feat(jet_cad_2d): package scaffold and workspace wiring"
```

---

### Task 2: Handle

**Files:**
- Create: `packages/jet_cad_2d/lib/src/core/handle.dart`
- Create: `packages/jet_cad_2d/test/core/handle_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `extension type const Handle(int value)` with `Handle.none`, `bool get isNone`, `String toHex()`, `static Handle parseHex(String)`, `static Handle fromJson(Object? json)`, `int toJson()`.
  - `const int kMaxHandle = 0xFFFFFFFF;`
  - `class HandleRangeError implements Exception` with `final Object? value;` — `Object?` rather than `int` because `parseHex` records a `String` and `fromJson` records an arbitrary JSON value.
  - `class HandleSeed` with `Handle next()`, `Handle get current`, `void raiseTo(Handle)`.

Every later task uses `Handle` for identity and `HandleSeed` for allocation.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/core/handle_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  group('Handle', () {
    test('none is zero and reports isNone', () {
      expect(Handle.none.value, 0);
      expect(Handle.none.isNone, isTrue);
      expect(const Handle(1).isNone, isFalse);
    });

    test('hex round-trips in the DXF uppercase form', () {
      expect(const Handle(0x1A).toHex(), '1A');
      expect(const Handle(0xFFFFFFFF).toHex(), 'FFFFFFFF');
      expect(Handle.parseHex('1a'), const Handle(0x1A));
      expect(Handle.parseHex('FFFFFFFF'), const Handle(0xFFFFFFFF));
    });

    test('rejects values above the 32-bit ceiling', () {
      // The ceiling is a document invariant, not a web quirk: entity columns
      // are Uint32List on every platform.
      expect(() => Handle.parseHex('100000000'), throwsA(isA<HandleRangeError>()));
      expect(() => Handle.checked(kMaxHandle + 1), throwsA(isA<HandleRangeError>()));
      expect(Handle.checked(kMaxHandle), const Handle(kMaxHandle));
    });

    test('rejects negative values', () {
      expect(() => Handle.checked(-1), throwsA(isA<HandleRangeError>()));
    });

    test('fromJson wraps a bare int, because the extension type is erased', () {
      // A JSON decoder hands back `int`. Handle and int are the same type at
      // runtime, so the wrap has to be explicit at the boundary.
      expect(Handle.fromJson(26), const Handle(26));
      expect(const Handle(26).toJson(), 26);
      expect(() => Handle.fromJson('26'), throwsA(isA<HandleRangeError>()));
    });
  });

  group('HandleSeed', () {
    test('allocates monotonically from one', () {
      final seed = HandleSeed();
      expect(seed.next(), const Handle(1));
      expect(seed.next(), const Handle(2));
      expect(seed.current, const Handle(2));
    });

    test('raiseTo moves the seed forward but never backward', () {
      final seed = HandleSeed()..raiseTo(const Handle(100));
      expect(seed.next(), const Handle(101));
      seed.raiseTo(const Handle(5));
      expect(seed.next(), const Handle(102));
    });

    test('throws rather than wrapping past the ceiling', () {
      final seed = HandleSeed()..raiseTo(const Handle(kMaxHandle));
      expect(seed.next, throwsA(isA<HandleRangeError>()));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/core/handle_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'Handle'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/core/handle.dart`:

```dart
/// The document's handle ceiling.
///
/// Entity records store handles in `Uint32List` columns, so this is a storage
/// invariant on every platform rather than a `dart2js` integer-precision quirk.
/// Long-lived drawings do exceed it; import range-checks against this value and
/// compacts the handle space when it must, which is safe because the original
/// identifier survives in an origin component.
const int kMaxHandle = 0xFFFFFFFF;

/// Thrown when a value cannot be a handle.
class HandleRangeError implements Exception {
  final Object? value;
  final String message;
  const HandleRangeError(this.value, this.message);

  @override
  String toString() => 'HandleRangeError($value): $message';
}

/// Stable identifier for anything addressable in a document — nodes, entities,
/// definitions, and every table record — drawn from one shared space.
///
/// This is an extension type, so it is erased at runtime: `Map<Handle, X>` and
/// `Map<int, X>` are the same type, and a JSON decoder hands back a bare `int`.
/// The type provides static safety only; boundaries must wrap explicitly via
/// [Handle.fromJson].
extension type const Handle(int value) {
  /// The absent handle. DXF treats handle 0 as invalid, so fields use this
  /// rather than `Handle?` — a nullable handle and an implicit zero would both
  /// appear in the codebase and diverge.
  static const Handle none = Handle(0);

  bool get isNone => value == 0;

  /// Range-checked construction. Use at every boundary that accepts a number
  /// from outside the engine.
  static Handle checked(int value) {
    if (value < 0 || value > kMaxHandle) {
      throw HandleRangeError(value, 'outside 0..$kMaxHandle');
    }
    return Handle(value);
  }

  static Handle parseHex(String hex) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) throw HandleRangeError(hex, 'not hexadecimal');
    return checked(parsed);
  }

  static Handle fromJson(Object? json) {
    if (json is! int) throw HandleRangeError(json, 'expected int');
    return checked(json);
  }

  String toHex() => value.toRadixString(16).toUpperCase();

  int toJson() => value;
}

/// Monotonic handle allocator. One per document.
class HandleSeed {
  int _current;

  HandleSeed([Handle start = Handle.none]) : _current = start.value;

  Handle get current => Handle(_current);

  Handle next() {
    if (_current >= kMaxHandle) {
      throw const HandleRangeError(kMaxHandle, 'handle space exhausted');
    }
    return Handle(++_current);
  }

  /// Moves the seed forward to at least [handle]. Never moves it backward —
  /// import raises the seed above the highest handle it read, and a later
  /// smaller value must not reopen already-issued handles.
  void raiseTo(Handle handle) {
    if (handle.value > _current) _current = handle.value;
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Modify `packages/jet_cad_2d/lib/jet_cad_2d.dart`, replacing the trailing comment with:

```dart
export 'src/core/handle.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): Handle identity with the 32-bit document invariant"
```

---

### Task 3: Tolerance

**Files:**
- Create: `packages/jet_cad_2d/lib/src/core/tolerance.dart`
- Create: `packages/jet_cad_2d/test/core/tolerance_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class Tolerance` with `const Tolerance({double linear, double angular})`, `static const Tolerance standard`, `bool eq(double, double)`, `bool isZero(double)`, `bool eqPoint(Vector2, Vector2)`, `bool eqAngle(double, double)`, `int compare(double, double)`.

Every geometric comparison in later tasks goes through this. Interaction tolerance (screen pixels converted to world units) is a *different* concept and is not in this class; it arrives in Plan 2.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/core/tolerance_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  const t = Tolerance.standard;

  test('standard tolerance is absolute in document units', () {
    expect(t.linear, 1e-9);
    expect(t.angular, 1e-9);
  });

  test('eq accepts differences within the linear tolerance', () {
    expect(t.eq(1.0, 1.0 + 1e-12), isTrue);
    expect(t.eq(1.0, 1.0 + 1e-6), isFalse);
  });

  test('eq is absolute, not relative — it does not scale with magnitude', () {
    // A relative tolerance would call these equal. Geometric tolerance is tied
    // to document scale, so it must not.
    expect(t.eq(1e6, 1e6 + 1e-3), isFalse);
  });

  test('isZero and compare agree with eq', () {
    expect(t.isZero(1e-12), isTrue);
    expect(t.isZero(1e-6), isFalse);
    expect(t.compare(1.0, 1.0 + 1e-12), 0);
    expect(t.compare(1.0, 2.0), -1);
    expect(t.compare(2.0, 1.0), 1);
  });

  test('eqPoint compares both components', () {
    expect(t.eqPoint(Vector2(1, 2), Vector2(1 + 1e-12, 2 - 1e-12)), isTrue);
    expect(t.eqPoint(Vector2(1, 2), Vector2(1, 2.5)), isFalse);
  });

  test('eqAngle uses the angular tolerance, not the linear one', () {
    final loose = const Tolerance(linear: 1e-9, angular: 1e-3);
    expect(loose.eqAngle(0.0, 1e-4), isTrue);
    expect(loose.eq(0.0, 1e-4), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/core/tolerance_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'Tolerance'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/core/tolerance.dart`:

```dart
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

/// Geometric tolerance: absolute, in document units, unaffected by zoom.
///
/// This answers "are these two points the same point". It is deliberately not
/// the same thing as interaction tolerance, which is measured in screen pixels
/// and converted to world units per zoom level and answers "did the user click
/// here". Collapsing the two into one number makes geometric equality
/// zoom-dependent, so they never share a type.
///
/// The tolerance is absolute rather than relative because it is tied to the
/// document's scale: a drawing in millimetres and a drawing in kilometres want
/// different values, and that choice belongs to the document, not to the
/// magnitude of whatever pair of numbers is being compared.
@immutable
class Tolerance {
  final double linear;
  final double angular;

  const Tolerance({required this.linear, required this.angular});

  static const Tolerance standard = Tolerance(linear: 1e-9, angular: 1e-9);

  bool eq(double a, double b) => (a - b).abs() <= linear;

  bool isZero(double v) => v.abs() <= linear;

  bool eqAngle(double a, double b) => (a - b).abs() <= angular;

  bool eqPoint(Vector2 a, Vector2 b) => eq(a.x, b.x) && eq(a.y, b.y);

  /// Three-way comparison that treats near-equal values as equal, so sorts
  /// built on it stay consistent with [eq].
  int compare(double a, double b) {
    if (eq(a, b)) return 0;
    return a < b ? -1 : 1;
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/core/tolerance.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): absolute geometric tolerance"
```

---

### Task 4: Diagnostic and list equality

**Files:**
- Create: `packages/jet_cad_2d/lib/src/core/list_equality.dart`
- Create: `packages/jet_cad_2d/lib/src/core/diagnostic.dart`
- Create: `packages/jet_cad_2d/test/core/list_equality_test.dart`
- Create: `packages/jet_cad_2d/test/core/diagnostic_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle` (Task 2).
- Produces:
  - `bool listEquals<T>(List<T> a, List<T> b)` in `list_equality.dart`.
  - `enum DiagnosticSeverity { info, warning, loss, error }`
  - `class Diagnostic` with `const Diagnostic({required DiagnosticSeverity severity, required String code, required String message, List<Handle> handles, String? sourceLocation})`, value equality, and `Map<String, Object?> toJson()`.

`listEquals` lands here because `Diagnostic` is its first consumer, but it is
shared: **Tasks 8, 11 and 12 use it too, and must not write their own copy.**
Every value type in this package compares a list field in its `operator ==`, and
five private near-duplicates of the same four lines is the kind of thing a
reviewer flags and a refactor gets wrong in one place.

`Diagnostic` lives in the core package rather than in an adapter because the engine itself raises them — cycle detection on import, degraded fills — and every adapter reuses the type.

- [ ] **Step 1: Write the failing test for list equality**

Create `packages/jet_cad_2d/test/core/list_equality_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('compares element-wise', () {
    expect(listEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(listEquals([1, 2, 3], [1, 2, 4]), isFalse);
  });

  test('differing lengths are unequal', () {
    expect(listEquals([1, 2], [1, 2, 3]), isFalse);
    expect(listEquals(<int>[], <int>[]), isTrue);
  });

  test('identical instances short-circuit', () {
    final list = [1, 2, 3];
    expect(listEquals(list, list), isTrue);
  });

  test('works across list implementations with the same elements', () {
    // Float64List is a List<double>; the geometry payload compares these.
    expect(listEquals<double>(Float64List.fromList([1, 2]), [1.0, 2.0]), isTrue);
  });

  test('uses element equality, so value types compare by value', () {
    expect(listEquals([const Handle(1)], [const Handle(1)]), isTrue);
  });
}
```

- [ ] **Step 2: Implement list equality**

Create `packages/jet_cad_2d/lib/src/core/list_equality.dart`:

```dart
/// Element-wise list comparison, used by every value type in this package that
/// holds a list field.
///
/// One shared helper rather than a private copy per file: the bodies would be
/// identical, and a fix applied to four of five copies is worse than no helper
/// at all.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

- [ ] **Step 3: Write the failing test for Diagnostic**

Create `packages/jet_cad_2d/test/core/diagnostic_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('carries severity, a machine-matchable code, and affected handles', () {
    const d = Diagnostic(
      severity: DiagnosticSeverity.loss,
      code: 'fill.image_degraded',
      message: 'Raster fill unavailable; wrote a solid fill.',
      handles: [Handle(0x2A)],
    );
    expect(d.severity, DiagnosticSeverity.loss);
    expect(d.code, 'fill.image_degraded');
    expect(d.handles.single, const Handle(0x2A));
    expect(d.sourceLocation, isNull);
  });

  test('handles defaults to empty, not null', () {
    const d = Diagnostic(
      severity: DiagnosticSeverity.info,
      code: 'x',
      message: 'y',
    );
    expect(d.handles, isEmpty);
  });

  test('is value-equal so tests can assert on expected diagnostic sets', () {
    const a = Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'tree.cycle_dropped',
      message: 'm',
      handles: [Handle(1), Handle(2)],
    );
    const b = Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'tree.cycle_dropped',
      message: 'm',
      handles: [Handle(1), Handle(2)],
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('toJson emits keys in a stable order and omits absent fields', () {
    const d = Diagnostic(
      severity: DiagnosticSeverity.error,
      code: 'c',
      message: 'm',
      handles: [Handle(3)],
    );
    expect(d.toJson().keys.toList(), ['severity', 'code', 'message', 'handles']);
    expect(d.toJson()['handles'], [3]);
  });
}
```

- [ ] **Step 4: Run both tests to verify they fail**

```bash
cd packages/jet_cad_2d && dart test test/core/ && cd ../..
```

Expected: `list_equality_test.dart` passes (Step 2 already implemented it);
`diagnostic_test.dart` fails to compile — `Undefined name 'Diagnostic'`.

- [ ] **Step 5: Write the implementation**

Create `packages/jet_cad_2d/lib/src/core/diagnostic.dart`:

```dart
import 'package:meta/meta.dart';

import 'handle.dart';
import 'list_equality.dart';

enum DiagnosticSeverity {
  /// Informational; nothing was changed or dropped.
  info,

  /// Something was unexpected but fully representable.
  warning,

  /// Data could not be represented and was approximated or dropped. Every
  /// exporter enumerates these: loss is declared, never discovered.
  loss,

  /// The operation failed.
  error,
}

/// A structured report from the engine or from a format adapter.
///
/// Lives in the core package because the engine raises diagnostics itself —
/// cycle detection, degraded fills — and every adapter reuses the type rather
/// than inventing its own.
@immutable
class Diagnostic {
  final DiagnosticSeverity severity;

  /// Stable and machine-matchable, so tests and callers can assert on a
  /// specific condition without matching prose.
  final String code;

  final String message;

  /// What the diagnostic concerns. May be empty.
  final List<Handle> handles;

  /// Adapter-defined position within the source, such as a line or byte
  /// offset. The engine never interprets it.
  final String? sourceLocation;

  const Diagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.handles = const [],
    this.sourceLocation,
  });

  Map<String, Object?> toJson() => {
        'severity': severity.name,
        'code': code,
        'message': message,
        if (handles.isNotEmpty)
          'handles': [for (final h in handles) h.toJson()],
        if (sourceLocation != null) 'sourceLocation': sourceLocation,
      };

  @override
  bool operator ==(Object other) =>
      other is Diagnostic &&
      other.severity == severity &&
      other.code == code &&
      other.message == message &&
      other.sourceLocation == sourceLocation &&
      listEquals(other.handles, handles);

  @override
  int get hashCode => Object.hash(
        severity,
        code,
        message,
        sourceLocation,
        Object.hashAll(handles),
      );

  @override
  String toString() => '[${severity.name}] $code: $message';
}
```

- [ ] **Step 6: Export both from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/core/diagnostic.dart';
export 'src/core/list_equality.dart';
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): Diagnostic and shared list equality"
```

---

### Task 5: Transform2 — full 2×3 affine

**Files:**
- Create: `packages/jet_cad_2d/lib/src/geometry/transform2.dart`
- Create: `packages/jet_cad_2d/test/geometry/transform2_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Tolerance` (Task 3).
- Produces: `class Transform2` with fields `a, b, c, d, e, f`; constructors `Transform2(...)`, `Transform2.identity()`, `Transform2.translation(double, double)`, `Transform2.rotation(double)`, `Transform2.scale(double, double)`; methods `Transform2 multiply(Transform2 other)`, `Vector2 transformPoint(Vector2)`, `Vector2 transformDirection(Vector2)`, `double get determinant`, `double get scaleMagnitude`, `double get anisotropyRatio`, `Transform2 invert()`, `bool get isIdentity`, `bool equals(Transform2, Tolerance)`, `List<double> toJson()`, `static Transform2 fromJson(Object?)`; and `class SingularTransformError implements Exception`.

Affine rather than translate-rotate-scale because DXF INSERT carries independent per-axis scale factors that may be negative. Mirrored blocks are common and TRS cannot represent them. `scaleMagnitude` and `anisotropyRatio` exist for the renderer's paper-space stroke policy in Plan 3; they are defined here because they are properties of the transform.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/geometry/transform2_test.dart`:

```dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  const t = Tolerance.standard;

  test('identity leaves points untouched', () {
    final id = Transform2.identity();
    expect(id.isIdentity, isTrue);
    expect(t.eqPoint(id.transformPoint(Vector2(3, -7)), Vector2(3, -7)), isTrue);
  });

  test('translation moves points but not directions', () {
    final tr = Transform2.translation(10, 20);
    expect(t.eqPoint(tr.transformPoint(Vector2(1, 2)), Vector2(11, 22)), isTrue);
    // A direction has no position, so translation must not affect it.
    expect(t.eqPoint(tr.transformDirection(Vector2(1, 2)), Vector2(1, 2)), isTrue);
  });

  test('rotation by a quarter turn maps +x to +y', () {
    final rot = Transform2.rotation(math.pi / 2);
    final p = rot.transformPoint(Vector2(1, 0));
    expect(p.x, closeTo(0, 1e-12));
    expect(p.y, closeTo(1, 1e-12));
  });

  test('negative scale mirrors and flips the determinant sign', () {
    final mirror = Transform2.scale(-1, 1);
    expect(t.eqPoint(mirror.transformPoint(Vector2(2, 3)), Vector2(-2, 3)), isTrue);
    expect(mirror.determinant, lessThan(0));
  });

  test('multiply applies the argument first, then the receiver', () {
    // Composition order is the chain rule the renderer depends on:
    // parent.multiply(child) is the child's transform in the parent's space.
    final scaleThenMove =
        Transform2.translation(10, 0).multiply(Transform2.scale(2, 2));
    expect(t.eqPoint(scaleThenMove.transformPoint(Vector2(1, 0)), Vector2(12, 0)),
        isTrue);

    final moveThenScale =
        Transform2.scale(2, 2).multiply(Transform2.translation(10, 0));
    expect(t.eqPoint(moveThenScale.transformPoint(Vector2(1, 0)), Vector2(22, 0)),
        isTrue);
  });

  test('invert round-trips an arbitrary affine', () {
    final m = Transform2.translation(4.5e6, -3.2e6)
        .multiply(Transform2.rotation(0.7))
        .multiply(Transform2.scale(3, -2));
    final p = Vector2(12.5, -8.25);
    final back = m.invert().transformPoint(m.transformPoint(p));
    expect(back.x, closeTo(p.x, 1e-6));
    expect(back.y, closeTo(p.y, 1e-6));
  });

  test('invert throws on a singular transform rather than producing NaN', () {
    expect(Transform2.scale(0, 5).invert, throwsA(isA<SingularTransformError>()));
  });

  test('scaleMagnitude is the geometric mean of the axis scales', () {
    expect(Transform2.scale(4, 4).scaleMagnitude, closeTo(4, 1e-12));
    expect(Transform2.scale(1, 100).scaleMagnitude, closeTo(10, 1e-12));
    // Mirroring must not produce a negative or NaN magnitude.
    expect(Transform2.scale(-3, 3).scaleMagnitude, closeTo(3, 1e-12));
  });

  test('anisotropyRatio is 1 for rotation and uniform scale', () {
    expect(Transform2.rotation(0.9).anisotropyRatio, closeTo(1, 1e-9));
    expect(Transform2.scale(7, 7).anisotropyRatio, closeTo(1, 1e-9));
  });

  test('anisotropyRatio reports the stretch factor for non-uniform scale', () {
    // This is the number the renderer thresholds on before deciding whether a
    // single baked stroke width can be correct for the instance.
    expect(Transform2.scale(1, 10).anisotropyRatio, closeTo(10, 1e-9));
    expect(Transform2.scale(10, 1).anisotropyRatio, closeTo(10, 1e-9));
  });

  test('json round-trips as six ordered doubles', () {
    final m = Transform2(1, 2, 3, 4, 5, 6);
    expect(m.toJson(), [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
    expect(Transform2.fromJson(m.toJson()).equals(m, t), isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/geometry/transform2_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'Transform2'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/geometry/transform2.dart`:

```dart
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../core/tolerance.dart';

class SingularTransformError implements Exception {
  const SingularTransformError();

  @override
  String toString() => 'SingularTransformError: transform is not invertible';
}

/// A full 2×3 affine transform:
///
///     [ a  c  e ]
///     [ b  d  f ]
///
/// Affine rather than translate-rotate-scale because DXF INSERT carries
/// independent per-axis scale factors which may be negative. Mirrored blocks
/// are common, and a TRS-only transform cannot represent one.
///
/// Only containers carry a transform. Leaf entity coordinates live in their
/// owner's space, which is both DXF-correct and what keeps large documents
/// free of per-entity matrices.
@immutable
class Transform2 {
  final double a, b, c, d, e, f;

  const Transform2(this.a, this.b, this.c, this.d, this.e, this.f);

  factory Transform2.identity() => const Transform2(1, 0, 0, 1, 0, 0);

  factory Transform2.translation(double dx, double dy) =>
      Transform2(1, 0, 0, 1, dx, dy);

  factory Transform2.scale(double sx, double sy) =>
      Transform2(sx, 0, 0, sy, 0, 0);

  factory Transform2.rotation(double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Transform2(cos, sin, -sin, cos, 0, 0);
  }

  /// True only for a bit-exact identity.
  ///
  /// Deliberately not tolerance-based: this is a cheap fast-path guard, not
  /// an equality decision. A near-identity answering `false` costs one
  /// redundant multiply; there is no answer it can get dangerously wrong.
  /// A tolerance-based version could report identity for a sub-tolerance
  /// transform, and a fast path would then skip it — silently discarding a
  /// real transform. For semantic comparison use `equals(other, tolerance)`.
  bool get isIdentity =>
      a == 1 && b == 0 && c == 0 && d == 1 && e == 0 && f == 0;

  /// Composition. The argument is applied **first**, then the receiver, so
  /// `parent.multiply(child)` yields the child's transform expressed in the
  /// parent's space. The renderer relies on this order when it collapses
  /// `camera ∘ ancestors ∘ instance ∘ rebase` into one matrix in Float64.
  Transform2 multiply(Transform2 other) => Transform2(
        a * other.a + c * other.b,
        b * other.a + d * other.b,
        a * other.c + c * other.d,
        b * other.c + d * other.d,
        a * other.e + c * other.f + e,
        b * other.e + d * other.f + f,
      );

  Vector2 transformPoint(Vector2 p) =>
      Vector2(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Like [transformPoint] but without the translation, for vectors that
  /// represent a direction or an offset rather than a position.
  Vector2 transformDirection(Vector2 v) =>
      Vector2(a * v.x + c * v.y, b * v.x + d * v.y);

  double get determinant => a * d - b * c;

  /// Geometric mean of the axis scales, `sqrt(|det|)`.
  ///
  /// This is the representative scale the renderer uses to pre-divide baked
  /// stroke widths and dash lengths, which are paper-space quantities and must
  /// stay constant on screen regardless of the instance transform. It is
  /// always non-negative, so mirroring cannot produce a negative width.
  double get scaleMagnitude => math.sqrt(determinant.abs());

  /// Ratio of the larger singular value to the smaller — how far the transform
  /// is from conformal.
  ///
  /// Returns [double.infinity] for a degenerate transform. The renderer
  /// thresholds on this: within the threshold a single baked stroke width is
  /// close enough; beyond it the instance bypasses the definition picture cache
  /// and draws with exact per-axis handling, because no single width is right.
  double get anisotropyRatio {
    final sumSq = a * a + b * b + c * c + d * d;
    final diffSq = a * a + b * b - c * c - d * d;
    final cross = a * c + b * d;
    final q = math.sqrt(diffSq * diffSq / 4 + cross * cross);
    final half = sumSq / 2;
    final maxSq = half + q;
    // Rounding can push this a hair below zero for a conformal transform.
    final minSq = math.max(half - q, 0.0);
    if (minSq == 0.0) return double.infinity;
    return math.sqrt(maxSq / minSq);
  }

  Transform2 invert() {
    final det = determinant;
    if (det == 0.0 || !det.isFinite) throw const SingularTransformError();
    final inv = 1.0 / det;
    return Transform2(
      d * inv,
      -b * inv,
      -c * inv,
      a * inv,
      (c * f - d * e) * inv,
      (b * e - a * f) * inv,
    );
  }

  /// Component-wise comparison under a tolerance. There is deliberately no
  /// `operator ==`: exact double equality on a composed transform is almost
  /// always a bug, and nothing in the architecture uses a transform as a map
  /// key.
  bool equals(Transform2 other, Tolerance tol) =>
      tol.eq(a, other.a) &&
      tol.eq(b, other.b) &&
      tol.eq(c, other.c) &&
      tol.eq(d, other.d) &&
      tol.eq(e, other.e) &&
      tol.eq(f, other.f);

  List<double> toJson() => [a, b, c, d, e, f];

  static Transform2 fromJson(Object? json) {
    if (json is! List || json.length != 6) {
      throw FormatException('Transform2 expects six numbers, got: $json');
    }
    final v = [for (final n in json) (n as num).toDouble()];
    return Transform2(v[0], v[1], v[2], v[3], v[4], v[5]);
  }

  @override
  String toString() => 'Transform2($a, $b, $c, $d, $e, $f)';
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/geometry/transform2.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): Transform2 full affine with anisotropy metrics"
```

---

### Task 6: Aabb2 and geometry primitives

**Files:**
- Create: `packages/jet_cad_2d/lib/src/geometry/aabb2.dart`
- Create: `packages/jet_cad_2d/lib/src/geometry/primitives.dart`
- Create: `packages/jet_cad_2d/test/geometry/aabb2_test.dart`
- Create: `packages/jet_cad_2d/test/geometry/primitives_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Transform2` (Task 5), `Tolerance` (Task 3).
- Produces:
  - `class Aabb2` with `Aabb2(Vector2 min, Vector2 max)`, `Aabb2.empty()`, `Aabb2.fromPoints(Iterable<Vector2>)`, `bool get isEmpty`, `Vector2 get center`, `Vector2 get size`, `Aabb2 expandedToPoint(Vector2)`, `Aabb2 union(Aabb2)`, `Aabb2 expandedBy(double)`, `bool containsPoint(Vector2)`, `bool intersects(Aabb2)`, `Aabb2 transformedBy(Transform2)`, `List<double> toJson()`, `static Aabb2 fromJson(Object?)`.
  - Top-level functions in `primitives.dart`: `Vector2 closestPointOnSegment(Vector2 p, Vector2 a, Vector2 b)`, `double distancePointToSegment(Vector2 p, Vector2 a, Vector2 b)`, `Vector2? segmentIntersection(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2, Tolerance tol)`, `bool angleInSweep(double angle, double startAngle, double sweepAngle)`, `Aabb2 arcBounds(Vector2 center, double radius, double startAngle, double sweepAngle)`.

`transformedBy` returns the **conservative** axis-aligned bound of the transformed box, not a rotated box. Plan 2's spatial index depends on that being conservative: it inverse-transforms a query region into a definition's local space and must never lose a hit.

- [ ] **Step 1: Write the failing Aabb2 test**

Create `packages/jet_cad_2d/test/geometry/aabb2_test.dart`:

```dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('empty absorbs the first point instead of stretching from the origin', () {
    // A zero-initialised box would silently include (0,0) and inflate every
    // extent computation on a drawing that sits far from the origin.
    final box = Aabb2.empty().expandedToPoint(Vector2(4.5e6, -3.2e6));
    expect(box.isEmpty, isFalse);
    expect(box.min.x, 4.5e6);
    expect(box.max.x, 4.5e6);
    expect(Aabb2.empty().isEmpty, isTrue);
  });

  test('fromPoints bounds every point', () {
    final box = Aabb2.fromPoints([Vector2(1, 5), Vector2(-3, 2), Vector2(0, 9)]);
    expect(box.min, Vector2(-3, 2));
    expect(box.max, Vector2(1, 9));
    expect(box.center, Vector2(-1, 5.5));
    expect(box.size, Vector2(4, 7));
  });

  test('union with an empty box is the identity', () {
    final box = Aabb2(Vector2(0, 0), Vector2(2, 2));
    expect(box.union(Aabb2.empty()).max, Vector2(2, 2));
    expect(Aabb2.empty().union(box).max, Vector2(2, 2));
  });

  test('containsPoint and intersects use closed bounds', () {
    final box = Aabb2(Vector2(0, 0), Vector2(2, 2));
    expect(box.containsPoint(Vector2(2, 2)), isTrue);
    expect(box.containsPoint(Vector2(2.001, 1)), isFalse);
    expect(box.intersects(Aabb2(Vector2(2, 2), Vector2(3, 3))), isTrue);
    expect(box.intersects(Aabb2(Vector2(2.5, 0), Vector2(3, 3))), isFalse);
  });

  test('expandedBy grows in both directions', () {
    final box = Aabb2(Vector2(0, 0), Vector2(2, 2)).expandedBy(1);
    expect(box.min, Vector2(-1, -1));
    expect(box.max, Vector2(3, 3));
  });

  test('transformedBy returns a conservative bound under rotation', () {
    // A 45-degree rotation of the unit square must produce a box that contains
    // the rotated square, which is larger than the original — never smaller.
    final rotated = Aabb2(Vector2(0, 0), Vector2(1, 1))
        .transformedBy(Transform2.rotation(math.pi / 4));
    final halfDiagonal = math.sqrt(2);
    expect(rotated.max.y, closeTo(halfDiagonal, 1e-12));
    expect(rotated.min.x, closeTo(-math.sqrt(2) / 2, 1e-12));
  });

  test('transformedBy handles mirroring without inverting min and max', () {
    final mirrored = Aabb2(Vector2(1, 1), Vector2(3, 2))
        .transformedBy(Transform2.scale(-1, 1));
    expect(mirrored.min.x, closeTo(-3, 1e-12));
    expect(mirrored.max.x, closeTo(-1, 1e-12));
  });

  test('json round-trips, and empty survives the round trip', () {
    final box = Aabb2(Vector2(1, 2), Vector2(3, 4));
    expect(box.toJson(), [1.0, 2.0, 3.0, 4.0]);
    expect(Aabb2.fromJson(box.toJson()).max, Vector2(3, 4));
    expect(Aabb2.fromJson(Aabb2.empty().toJson()).isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Write the failing primitives test**

Create `packages/jet_cad_2d/test/geometry/primitives_test.dart`:

```dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  const tol = Tolerance.standard;

  group('segment distance', () {
    final a = Vector2(0, 0);
    final b = Vector2(10, 0);

    test('projects onto the interior when the foot lies within', () {
      expect(distancePointToSegment(Vector2(3, 4), a, b), closeTo(4, 1e-12));
      expect(closestPointOnSegment(Vector2(3, 4), a, b), Vector2(3, 0));
    });

    test('clamps to the endpoints when the foot lies outside', () {
      expect(distancePointToSegment(Vector2(-3, 4), a, b), closeTo(5, 1e-12));
      expect(distancePointToSegment(Vector2(13, 4), a, b), closeTo(5, 1e-12));
    });

    test('degenerate segment behaves as a point', () {
      expect(distancePointToSegment(Vector2(3, 4), a, a), closeTo(5, 1e-12));
    });
  });

  group('segment intersection', () {
    test('finds a crossing point', () {
      final hit = segmentIntersection(
          Vector2(0, 0), Vector2(10, 10), Vector2(0, 10), Vector2(10, 0), tol);
      expect(hit, isNotNull);
      expect(tol.eqPoint(hit!, Vector2(5, 5)), isTrue);
    });

    test('returns null when the segments miss', () {
      expect(
          segmentIntersection(
              Vector2(0, 0), Vector2(1, 1), Vector2(5, 0), Vector2(6, 1), tol),
          isNull);
    });

    test('returns null for parallel and for collinear overlap', () {
      // Collinear overlap has no single intersection point; callers that need
      // the overlap interval ask a different question.
      expect(
          segmentIntersection(
              Vector2(0, 0), Vector2(10, 0), Vector2(0, 1), Vector2(10, 1), tol),
          isNull);
      expect(
          segmentIntersection(
              Vector2(0, 0), Vector2(10, 0), Vector2(5, 0), Vector2(15, 0), tol),
          isNull);
    });

    test('touching endpoints count as an intersection', () {
      final hit = segmentIntersection(
          Vector2(0, 0), Vector2(5, 0), Vector2(5, 0), Vector2(5, 5), tol);
      expect(hit, isNotNull);
      expect(tol.eqPoint(hit!, Vector2(5, 0)), isTrue);
    });
  });

  group('arcBounds', () {
    final c = Vector2(0, 0);

    test('a full circle bounds the whole circle', () {
      final box = arcBounds(c, 2, 0, 2 * math.pi);
      expect(box.min.x, closeTo(-2, 1e-12));
      expect(box.max.y, closeTo(2, 1e-12));
    });

    test('a quarter arc bounds only its own quadrant', () {
      final box = arcBounds(c, 1, 0, math.pi / 2);
      expect(box.min.x, closeTo(0, 1e-12));
      expect(box.min.y, closeTo(0, 1e-12));
      expect(box.max.x, closeTo(1, 1e-12));
      expect(box.max.y, closeTo(1, 1e-12));
    });

    test('includes an axis extreme that falls inside the sweep', () {
      // From -45 to +45 the endpoints both have x = cos(45) < 1, but the arc
      // passes through 0 degrees where x = 1. Bounding only the endpoints is
      // the classic arc-extents bug.
      final box = arcBounds(c, 1, -math.pi / 4, math.pi / 2);
      expect(box.max.x, closeTo(1, 1e-12));
      expect(box.max.y, closeTo(math.sqrt(2) / 2, 1e-12));
      expect(box.min.y, closeTo(-math.sqrt(2) / 2, 1e-12));
    });

    test('handles a negative (clockwise) sweep', () {
      final box = arcBounds(c, 1, math.pi / 4, -math.pi / 2);
      expect(box.max.x, closeTo(1, 1e-12));
      expect(box.max.y, closeTo(math.sqrt(2) / 2, 1e-12));
    });

    test('is offset by the centre', () {
      final box = arcBounds(Vector2(100, 50), 1, 0, 2 * math.pi);
      expect(box.min.x, closeTo(99, 1e-12));
      expect(box.max.y, closeTo(51, 1e-12));
    });
  });

  group('angleInSweep', () {
    test('accepts angles inside a counter-clockwise sweep', () {
      expect(angleInSweep(math.pi / 4, 0, math.pi / 2), isTrue);
      expect(angleInSweep(math.pi, 0, math.pi / 2), isFalse);
    });

    test('accepts angles inside a clockwise sweep', () {
      expect(angleInSweep(-math.pi / 4, 0, -math.pi / 2), isTrue);
      expect(angleInSweep(math.pi / 4, 0, -math.pi / 2), isFalse);
    });

    test('normalises across the 2π wrap', () {
      expect(angleInSweep(0, 7 * math.pi / 4, math.pi / 2), isTrue);
    });
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

```bash
cd packages/jet_cad_2d && dart test test/geometry/ && cd ../..
```

Expected: compile failure — `Undefined name 'Aabb2'`.

- [ ] **Step 4: Implement Aabb2**

Create `packages/jet_cad_2d/lib/src/geometry/aabb2.dart`:

```dart
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import 'transform2.dart';

/// An axis-aligned bounding box in document units.
///
/// The empty box is represented by inverted infinite bounds rather than zeros,
/// so that expanding an empty box absorbs the first point exactly. A
/// zero-initialised box would silently include the origin, which inflates every
/// extent on a drawing that sits far from it — the common case in site plans.
@immutable
class Aabb2 {
  final Vector2 min;
  final Vector2 max;

  Aabb2(Vector2 min, Vector2 max)
      : min = min.clone(),
        max = max.clone();

  factory Aabb2.empty() => Aabb2(
        Vector2(double.infinity, double.infinity),
        Vector2(double.negativeInfinity, double.negativeInfinity),
      );

  factory Aabb2.fromPoints(Iterable<Vector2> points) {
    var box = Aabb2.empty();
    for (final p in points) {
      box = box.expandedToPoint(p);
    }
    return box;
  }

  bool get isEmpty => min.x > max.x || min.y > max.y;

  Vector2 get center => Vector2((min.x + max.x) / 2, (min.y + max.y) / 2);

  Vector2 get size => Vector2(max.x - min.x, max.y - min.y);

  Aabb2 expandedToPoint(Vector2 p) => Aabb2(
        Vector2(math.min(min.x, p.x), math.min(min.y, p.y)),
        Vector2(math.max(max.x, p.x), math.max(max.y, p.y)),
      );

  Aabb2 union(Aabb2 other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return Aabb2(
      Vector2(math.min(min.x, other.min.x), math.min(min.y, other.min.y)),
      Vector2(math.max(max.x, other.max.x), math.max(max.y, other.max.y)),
    );
  }

  Aabb2 expandedBy(double amount) => isEmpty
      ? this
      : Aabb2(
          Vector2(min.x - amount, min.y - amount),
          Vector2(max.x + amount, max.y + amount),
        );

  bool containsPoint(Vector2 p) =>
      p.x >= min.x && p.x <= max.x && p.y >= min.y && p.y <= max.y;

  bool intersects(Aabb2 other) =>
      !isEmpty &&
      !other.isEmpty &&
      min.x <= other.max.x &&
      max.x >= other.min.x &&
      min.y <= other.max.y &&
      max.y >= other.min.y;

  /// The **conservative** axis-aligned bound of this box under [t] — the bound
  /// of the four transformed corners, not a rotated box.
  ///
  /// Conservative is the contract, not an approximation to be tightened later:
  /// the spatial index inverse-transforms a query region into a definition's
  /// local space, and a bound that were ever tighter than the true region would
  /// drop hits. Mirroring is handled by taking min and max of the corners
  /// rather than assuming the corner order is preserved.
  Aabb2 transformedBy(Transform2 t) {
    if (isEmpty) return this;
    return Aabb2.fromPoints([
      t.transformPoint(Vector2(min.x, min.y)),
      t.transformPoint(Vector2(max.x, min.y)),
      t.transformPoint(Vector2(min.x, max.y)),
      t.transformPoint(Vector2(max.x, max.y)),
    ]);
  }

  List<double> toJson() => [min.x, min.y, max.x, max.y];

  static Aabb2 fromJson(Object? json) {
    if (json is! List || json.length != 4) {
      throw FormatException('Aabb2 expects four numbers, got: $json');
    }
    final v = [for (final n in json) (n as num).toDouble()];
    return Aabb2(Vector2(v[0], v[1]), Vector2(v[2], v[3]));
  }

  @override
  String toString() => 'Aabb2(${min.x}, ${min.y} .. ${max.x}, ${max.y})';
}
```

- [ ] **Step 5: Implement the primitives**

Create `packages/jet_cad_2d/lib/src/geometry/primitives.dart`:

```dart
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../core/tolerance.dart';
import 'aabb2.dart';

/// The point on segment `a`–`b` nearest to `p`, clamped to the endpoints.
Vector2 closestPointOnSegment(Vector2 p, Vector2 a, Vector2 b) {
  final abx = b.x - a.x;
  final aby = b.y - a.y;
  final lengthSq = abx * abx + aby * aby;
  if (lengthSq == 0.0) return a.clone();
  var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / lengthSq;
  t = t.clamp(0.0, 1.0);
  return Vector2(a.x + t * abx, a.y + t * aby);
}

double distancePointToSegment(Vector2 p, Vector2 a, Vector2 b) =>
    (p - closestPointOnSegment(p, a, b)).length;

/// The single crossing point of two segments, or null.
///
/// Parallel segments return null, and so does collinear overlap: an overlap has
/// no single intersection point, and a caller that needs the overlap interval
/// is asking a different question and gets a different function when one is
/// needed. Touching endpoints do intersect.
Vector2? segmentIntersection(
  Vector2 p1,
  Vector2 p2,
  Vector2 q1,
  Vector2 q2,
  Tolerance tol,
) {
  final r = p2 - p1;
  final s = q2 - q1;
  final denominator = r.x * s.y - r.y * s.x;
  if (tol.isZero(denominator)) return null; // parallel or collinear
  final qp = q1 - p1;
  final t = (qp.x * s.y - qp.y * s.x) / denominator;
  final u = (qp.x * r.y - qp.y * r.x) / denominator;
  if (t < 0.0 || t > 1.0 || u < 0.0 || u > 1.0) return null;
  return Vector2(p1.x + t * r.x, p1.y + t * r.y);
}

/// Whether [angle] lies within the sweep that starts at [startAngle] and turns
/// by [sweepAngle], counter-clockwise when the sweep is positive.
bool angleInSweep(double angle, double startAngle, double sweepAngle) {
  const twoPi = 2 * math.pi;
  if (sweepAngle.abs() >= twoPi) return true;
  final delta = sweepAngle >= 0 ? angle - startAngle : startAngle - angle;
  var normalized = delta % twoPi;
  if (normalized < 0) normalized += twoPi;
  return normalized <= sweepAngle.abs();
}

/// Bounds of a circular arc.
///
/// Bounding only the two endpoints is the classic arc-extents bug: an arc from
/// -45° to +45° has both endpoints at x = cos 45°, yet passes through x = r at
/// 0°. Each of the four axis extremes is therefore tested for membership in the
/// sweep and included when it falls inside.
Aabb2 arcBounds(
  Vector2 center,
  double radius,
  double startAngle,
  double sweepAngle,
) {
  final endAngle = startAngle + sweepAngle;
  var box = Aabb2.fromPoints([
    Vector2(center.x + radius * math.cos(startAngle),
        center.y + radius * math.sin(startAngle)),
    Vector2(center.x + radius * math.cos(endAngle),
        center.y + radius * math.sin(endAngle)),
  ]);

  const extremes = <Vector2Function>[
    _right,
    _top,
    _left,
    _bottom,
  ];
  for (var quadrant = 0; quadrant < 4; quadrant++) {
    final angle = quadrant * math.pi / 2;
    if (angleInSweep(angle, startAngle, sweepAngle)) {
      box = box.expandedToPoint(extremes[quadrant](center, radius));
    }
  }
  return box;
}

typedef Vector2Function = Vector2 Function(Vector2 center, double radius);

Vector2 _right(Vector2 c, double r) => Vector2(c.x + r, c.y);
Vector2 _top(Vector2 c, double r) => Vector2(c.x, c.y + r);
Vector2 _left(Vector2 c, double r) => Vector2(c.x - r, c.y);
Vector2 _bottom(Vector2 c, double r) => Vector2(c.x, c.y - r);
```

- [ ] **Step 6: Export both from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/geometry/aabb2.dart';
export 'src/geometry/primitives.dart';
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): Aabb2 and analytic geometry primitives"
```

---

### Task 7: SlotAllocator — the shared slot lifetime contract

**Files:**
- Create: `packages/jet_cad_2d/lib/src/store/slot_allocator.dart`
- Create: `packages/jet_cad_2d/test/store/slot_allocator_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class SlotAllocator` with `int allocate()`, `void free(int slot)`, `bool isLive(int slot)`, `int get capacity`, `int get liveCount`, `Iterable<int> get liveSlots`, `List<int> compact()`, `void clear()`; and `class SlotStateError implements Exception`.

Both `GeometryStore` (Task 8) and `EntityStore` (Task 10) own one of these. The spec's slot-lifetime rules are identical for both stores, so the rules live in one class rather than being restated — an invariant applied to one store and not the other simply leaks.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/store/slot_allocator_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('allocates densely from zero', () {
    final slots = SlotAllocator();
    expect(slots.allocate(), 0);
    expect(slots.allocate(), 1);
    expect(slots.allocate(), 2);
    expect(slots.capacity, 3);
    expect(slots.liveCount, 3);
  });

  test('reuses a freed slot rather than growing', () {
    // Rule 2: deletion returns the slot to a free list. Growing instead would
    // leak capacity across an edit-heavy session.
    final slots = SlotAllocator();
    slots.allocate();
    final second = slots.allocate();
    slots.allocate();
    slots.free(second);
    expect(slots.liveCount, 2);
    expect(slots.allocate(), second);
    expect(slots.capacity, 3);
  });

  test('isLive and liveSlots report only live slots, in ascending order', () {
    final slots = SlotAllocator();
    for (var i = 0; i < 5; i++) {
      slots.allocate();
    }
    slots.free(1);
    slots.free(3);
    expect(slots.isLive(1), isFalse);
    expect(slots.isLive(2), isTrue);
    // Ascending order is required: query results must be stably ordered, and
    // hash iteration order would make tests flaky.
    expect(slots.liveSlots.toList(), [0, 2, 4]);
  });

  test('rejects double free and out-of-range free', () {
    final slots = SlotAllocator();
    slots.allocate();
    slots.free(0);
    expect(() => slots.free(0), throwsA(isA<SlotStateError>()));
    expect(() => slots.free(7), throwsA(isA<SlotStateError>()));
    expect(() => slots.free(-1), throwsA(isA<SlotStateError>()));
  });

  test('compact returns a dense remap that preserves relative order', () {
    // Rule 3: compaction exists only inside an explicit purge, which rewrites
    // every reference using exactly this map.
    final slots = SlotAllocator();
    for (var i = 0; i < 5; i++) {
      slots.allocate();
    }
    slots.free(1);
    slots.free(3);

    final remap = slots.compact();
    expect(remap.length, 5);
    expect(remap[0], 0);
    expect(remap[1], -1); // dead
    expect(remap[2], 1);
    expect(remap[3], -1); // dead
    expect(remap[4], 2);

    expect(slots.capacity, 3);
    expect(slots.liveCount, 3);
    expect(slots.liveSlots.toList(), [0, 1, 2]);
    // The free list is empty after compaction, so the next allocation grows.
    expect(slots.allocate(), 3);
  });

  test('clear resets to the initial state', () {
    final slots = SlotAllocator();
    slots.allocate();
    slots.allocate();
    slots.clear();
    expect(slots.capacity, 0);
    expect(slots.liveCount, 0);
    expect(slots.allocate(), 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/store/slot_allocator_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'SlotAllocator'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/store/slot_allocator.dart`:

```dart
class SlotStateError implements Exception {
  final int slot;
  final String message;
  const SlotStateError(this.slot, this.message);

  @override
  String toString() => 'SlotStateError(slot $slot): $message';
}

/// Allocates and recycles slots for a columnar store, and owns the slot
/// lifetime rules that both stores share.
///
/// 1. Slot values are opaque and change **only** inside a command that also
///    rewrites every reference to them. There is no ambient compaction: not on
///    delete, not on load, not on idle. Without this rule the id-remapping
///    problem rejected for the 3D document reappears one layer down.
/// 2. Deletion returns the slot to a free list. An inverse command carries the
///    **payload**, never the slot, so undo may legitimately land in a different
///    slot and update the referencing record.
/// 3. [compact] exists only to serve an explicit `purge()` maintenance
///    operation, which rewrites all references and clears the undo stack. It is
///    not a command and is not undoable.
class SlotAllocator {
  final List<bool> _live = [];
  final List<int> _free = [];

  /// One past the highest slot ever allocated — the length the columns must
  /// have, including dead slots.
  int get capacity => _live.length;

  int get liveCount => _live.length - _free.length;

  bool isLive(int slot) =>
      slot >= 0 && slot < _live.length && _live[slot];

  /// Live slots in ascending order. Ascending rather than insertion or hash
  /// order because every query built on a store must be stably ordered.
  Iterable<int> get liveSlots sync* {
    for (var i = 0; i < _live.length; i++) {
      if (_live[i]) yield i;
    }
  }

  int allocate() {
    if (_free.isNotEmpty) {
      final slot = _free.removeLast();
      _live[slot] = true;
      return slot;
    }
    _live.add(true);
    return _live.length - 1;
  }

  void free(int slot) {
    if (slot < 0 || slot >= _live.length) {
      throw SlotStateError(slot, 'outside 0..${_live.length - 1}');
    }
    if (!_live[slot]) throw SlotStateError(slot, 'already free');
    _live[slot] = false;
    _free.add(slot);
  }

  /// Collapses live slots into a dense range and returns the remap.
  ///
  /// The result is indexed by old slot; the value is the new slot, or -1 if the
  /// slot was dead. Relative order is preserved so that any ordering a caller
  /// derived from slot numbers survives. The caller is responsible for moving
  /// its columns and rewriting every reference — this class only decides the
  /// mapping.
  List<int> compact() {
    final remap = List<int>.filled(_live.length, -1);
    var next = 0;
    for (var i = 0; i < _live.length; i++) {
      if (_live[i]) remap[i] = next++;
    }
    _live
      ..clear()
      ..addAll(List<bool>.filled(next, true));
    _free.clear();
    return remap;
  }

  void clear() {
    _live.clear();
    _free.clear();
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/store/slot_allocator.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): SlotAllocator owning the shared slot lifetime rules"
```

---

### Task 8: GeometryStore

**Files:**
- Create: `packages/jet_cad_2d/lib/src/store/geometry_store.dart`
- Create: `packages/jet_cad_2d/test/store/geometry_store_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `SlotAllocator` (Task 7), `Transform2` (Task 5), `Aabb2` (Task 6), `listEquals` (Task 4).
- Produces:
  - `class GeometryPayload` — `Float64List coords`, `Float64List scalars`, `int get pointCount`, `Vector2 pointAt(int)`, `GeometryPayload transformedBy(Transform2)`, value equality, `Map<String, Object?> toJson()`, `static GeometryPayload fromJson(Object?)`.
  - `class GeometryStore` — `int add(GeometryPayload)`, `GeometryPayload read(int slot)`, `void remove(int slot)`, `void replace(int slot, GeometryPayload)`, `Aabb2 pointBounds(int slot)`, `int get liveCount`, `List<int> purge()`, `void clear()`.

**Why two pools.** `coords` holds x/y pairs; `scalars` holds everything that is not a coordinate — radius, start angle, sweep, text height. They are separate because transforming geometry must transform points and must *not* transform a radius or an angle the same way. One mixed pool would make that distinction a per-kind lookup at every call site.

The store is deliberately kind-agnostic: it stores blobs, not circles. Interpreting a payload belongs to whoever knows the entity kind, which keeps new geometry kinds from touching this file at all.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/store/geometry_store_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload lineFrom(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

void main() {
  test('stores and reads back a payload unchanged', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 10, 5));
    final read = store.read(slot);
    expect(read.pointCount, 2);
    expect(read.pointAt(1), Vector2(10, 5));
    expect(read.scalars, isEmpty);
  });

  test('read returns a copy, so mutating it cannot corrupt the store', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 1, 1));
    store.read(slot).coords[0] = 999;
    expect(store.read(slot).coords[0], 0);
  });

  test('keeps coordinates and scalars in separate pools', () {
    // An arc: centre in coords, radius and angles in scalars. A transform
    // applies to the centre but not to the radius or the angles.
    final store = GeometryStore();
    final arc = GeometryPayload(
      coords: Float64List.fromList([100, 200]),
      scalars: Float64List.fromList([50, 0, 1.5707963267948966]),
    );
    final slot = store.add(arc);
    final read = store.read(slot);
    expect(read.pointCount, 1);
    expect(read.scalars.length, 3);
    expect(read.scalars[0], 50);
  });

  test('transformedBy moves points and leaves scalars alone', () {
    final arc = GeometryPayload(
      coords: Float64List.fromList([1, 0]),
      scalars: Float64List.fromList([50, 0, 3.14]),
    );
    final moved = arc.transformedBy(Transform2.translation(10, 20));
    expect(moved.pointAt(0), Vector2(11, 20));
    expect(moved.scalars[0], 50);
    expect(moved.scalars[2], 3.14);
  });

  test('pointBounds bounds only the coordinate pool', () {
    final store = GeometryStore();
    final slot = store.add(GeometryPayload(
      coords: Float64List.fromList([-3, 4, 7, -2]),
      scalars: Float64List.fromList([1e9]), // must not affect the bounds
    ));
    final box = store.pointBounds(slot);
    expect(box.min, Vector2(-3, -2));
    expect(box.max, Vector2(7, 4));
  });

  test('remove frees the slot and reading it throws', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 1, 1));
    store.remove(slot);
    expect(store.liveCount, 0);
    expect(() => store.read(slot), throwsA(isA<SlotStateError>()));
  });

  test('a removed slot is reused, and undo restoring a payload may land elsewhere', () {
    // Rule 2: the inverse command carries the payload, not the slot. This test
    // pins that behaviour so nobody later "fixes" the store to preserve slots.
    final store = GeometryStore();
    final a = store.add(lineFrom(0, 0, 1, 1));
    final payload = store.read(a);
    final b = store.add(lineFrom(2, 2, 3, 3));
    store.remove(a);

    final restored = store.add(payload);
    expect(restored, a, reason: 'free list is LIFO, so this happens to match');
    expect(store.read(b).pointAt(0), Vector2(2, 2));
  });

  test('replace swaps the payload in place without changing the slot', () {
    final store = GeometryStore();
    final slot = store.add(lineFrom(0, 0, 1, 1));
    store.replace(slot, lineFrom(5, 5, 6, 6));
    expect(store.read(slot).pointAt(0), Vector2(5, 5));
    expect(store.liveCount, 1);
  });

  test('purge compacts and reports the remap for the caller to apply', () {
    final store = GeometryStore();
    final a = store.add(lineFrom(0, 0, 1, 1));
    final b = store.add(lineFrom(2, 2, 3, 3));
    final c = store.add(lineFrom(4, 4, 5, 5));
    store.remove(b);

    final remap = store.purge();
    expect(remap[a], 0);
    expect(remap[b], -1);
    expect(remap[c], 1);
    expect(store.read(remap[c]).pointAt(0), Vector2(4, 4));
    expect(store.liveCount, 2);
  });

  test('payload json round-trips', () {
    final payload = GeometryPayload(
      coords: Float64List.fromList([1, 2, 3, 4]),
      scalars: Float64List.fromList([9]),
    );
    expect(GeometryPayload.fromJson(payload.toJson()), payload);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/store/geometry_store_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'GeometryPayload'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/store/geometry_store.dart`:

```dart
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../core/list_equality.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import 'slot_allocator.dart';

/// One entity's geometry, detached from any store.
///
/// Commands carry payloads rather than slots: the inverse of a delete has to be
/// able to restore geometry into whichever slot is free at the time.
@immutable
class GeometryPayload {
  /// Interleaved x, y pairs in document units.
  final Float64List coords;

  /// Everything that is not a coordinate: radius, start angle, sweep, text
  /// height. Kept apart from [coords] because a transform applies to points and
  /// must not apply to a radius or an angle in the same way.
  final Float64List scalars;

  const GeometryPayload({required this.coords, required this.scalars});

  int get pointCount => coords.length ~/ 2;

  Vector2 pointAt(int index) =>
      Vector2(coords[index * 2], coords[index * 2 + 1]);

  GeometryPayload transformedBy(Transform2 t) {
    final out = Float64List(coords.length);
    for (var i = 0; i < coords.length; i += 2) {
      out[i] = t.a * coords[i] + t.c * coords[i + 1] + t.e;
      out[i + 1] = t.b * coords[i] + t.d * coords[i + 1] + t.f;
    }
    return GeometryPayload(
      coords: out,
      scalars: Float64List.fromList(scalars),
    );
  }

  Map<String, Object?> toJson() => {
        'coords': coords.toList(),
        'scalars': scalars.toList(),
      };

  static GeometryPayload fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('GeometryPayload expects an object, got: $json');
    }
    return GeometryPayload(
      coords: _readDoubles(json['coords']),
      scalars: _readDoubles(json['scalars']),
    );
  }

  static Float64List _readDoubles(Object? json) {
    if (json is! List) {
      throw FormatException('expected a list of numbers, got: $json');
    }
    final out = Float64List(json.length);
    for (var i = 0; i < json.length; i++) {
      out[i] = (json[i] as num).toDouble();
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is GeometryPayload &&
      listEquals<double>(other.coords, coords) &&
      listEquals<double>(other.scalars, scalars);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(coords), Object.hashAll(scalars));
}

/// Columnar storage for leaf geometry.
///
/// Deliberately kind-agnostic: it stores blobs, not circles. Interpreting a
/// payload belongs to code that knows the entity kind, which is what keeps a
/// new geometry kind from needing to touch this file.
class GeometryStore {
  final SlotAllocator _slots = SlotAllocator();
  final List<GeometryPayload> _payloads = [];

  int get liveCount => _slots.liveCount;

  Iterable<int> get liveSlots => _slots.liveSlots;

  int add(GeometryPayload payload) {
    final slot = _slots.allocate();
    final stored = GeometryPayload(
      coords: Float64List.fromList(payload.coords),
      scalars: Float64List.fromList(payload.scalars),
    );
    if (slot == _payloads.length) {
      _payloads.add(stored);
    } else {
      _payloads[slot] = stored;
    }
    return slot;
  }

  /// A defensive copy. Callers routinely hand the result to a command as an
  /// inverse payload, and a shared buffer would let a later edit rewrite
  /// history.
  GeometryPayload read(int slot) {
    _requireLive(slot);
    final p = _payloads[slot];
    return GeometryPayload(
      coords: Float64List.fromList(p.coords),
      scalars: Float64List.fromList(p.scalars),
    );
  }

  void replace(int slot, GeometryPayload payload) {
    _requireLive(slot);
    _payloads[slot] = GeometryPayload(
      coords: Float64List.fromList(payload.coords),
      scalars: Float64List.fromList(payload.scalars),
    );
  }

  void remove(int slot) {
    _requireLive(slot);
    _slots.free(slot);
    // Blank the dead entry so its buffers are released now rather than being
    // pinned until the slot is reused.
    _payloads[slot] =
        GeometryPayload(coords: Float64List(0), scalars: Float64List(0));
  }

  Aabb2 pointBounds(int slot) {
    _requireLive(slot);
    final p = _payloads[slot];
    var box = Aabb2.empty();
    for (var i = 0; i < p.coords.length; i += 2) {
      box = box.expandedToPoint(Vector2(p.coords[i], p.coords[i + 1]));
    }
    return box;
  }

  /// Explicit maintenance compaction. Returns the old-slot to new-slot remap;
  /// the caller must rewrite every reference and clear the undo stack. Never
  /// call this from a command.
  List<int> purge() {
    final remap = _slots.compact();
    final compacted = <GeometryPayload>[];
    for (var old = 0; old < remap.length; old++) {
      if (remap[old] >= 0) compacted.add(_payloads[old]);
    }
    _payloads
      ..clear()
      ..addAll(compacted);
    return remap;
  }

  void clear() {
    _slots.clear();
    _payloads.clear();
  }

  void _requireLive(int slot) {
    if (!_slots.isLive(slot)) throw SlotStateError(slot, 'not live');
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/store/geometry_store.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): GeometryStore with separated coordinate and scalar pools"
```

---

### Task 9: Tier-1 style values and their column encoding

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/style.dart`
- Create: `packages/jet_cad_2d/test/document/style_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle` (Task 2).
- Produces:
  - `sealed class DraftColor` with `final class ByLayerColor`, `ByBlockColor`, `IndexedColor(int aci)`, `TrueColor(int rgb)`; all value-equal.
  - `const int kByLayer = -1;`, `const int kByBlock = -2;`, `const int kLineweightDefault = -3;`
  - `int encodeColor(DraftColor)`, `DraftColor decodeColor(int)`.
  - `abstract final class ReservedHandles` with `layerZero`, `byLayerLinetype`, `byBlockLinetype`, `continuousLinetype`, `standardTextStyle`, and `static const Handle firstFree`.
  - `abstract final class EntityFlags` with `static const int invisible = 1 << 0;`

**Two deliberate refinements to the spec's illustrative `EntityStore` sketch**, both visible here because this is where the encoding is decided:

1. The spec writes `TrueColor { final int argb }`. This task uses **`rgb`** (24 bits). DXF transparency is an independent field that may itself be `BYLAYER`/`BYBLOCK`, so an alpha channel inside the colour would be a second, conflicting source of truth. The spec's own *Appearance model* section requires transparency to resolve separately; `rgb` is what makes that true.
2. The spec writes `Uint8List transparency`. That cannot hold the `BYLAYER`/`BYBLOCK` sentinels the same section requires, so Task 10 uses **`Int16List`**.

`ReservedHandles` exists because DXF's `BYLAYER` and `BYBLOCK` linetypes are real table records, not magic values. Modelling them as reserved handles means the linetype column needs no sentinels at all and the resolver walks one uniform path.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/style_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  group('DraftColor encoding', () {
    test('round-trips every variant', () {
      const colors = <DraftColor>[
        ByLayerColor(),
        ByBlockColor(),
        IndexedColor(1),
        IndexedColor(255),
        TrueColor(0x000000),
        TrueColor(0xFF8800),
        TrueColor(0xFFFFFF),
      ];
      for (final c in colors) {
        expect(decodeColor(encodeColor(c)), c, reason: '$c');
      }
    });

    test('sentinels are the shared negative constants', () {
      expect(encodeColor(const ByLayerColor()), kByLayer);
      expect(encodeColor(const ByBlockColor()), kByBlock);
    });

    test('indexed and true colour never collide', () {
      // Indexed ACI is 1..255. A true colour of 0x0000FF must not decode as
      // ACI 255, which is what a naive untagged encoding would do.
      expect(decodeColor(encodeColor(const TrueColor(0x0000FF))),
          const TrueColor(0x0000FF));
      expect(decodeColor(encodeColor(const IndexedColor(255))),
          const IndexedColor(255));
      expect(encodeColor(const TrueColor(0x0000FF)),
          isNot(encodeColor(const IndexedColor(255))));
    });

    test('rejects an out-of-range ACI', () {
      expect(() => encodeColor(const IndexedColor(0)), throwsArgumentError);
      expect(() => encodeColor(const IndexedColor(256)), throwsArgumentError);
    });

    test('rejects an rgb value outside 24 bits', () {
      expect(() => encodeColor(const TrueColor(0x1000000)), throwsArgumentError);
      expect(() => encodeColor(const TrueColor(-1)), throwsArgumentError);
    });

    test('colours are value-equal so they can be compared in tests and undo', () {
      expect(const TrueColor(0x123456), const TrueColor(0x123456));
      expect(const IndexedColor(7).hashCode, const IndexedColor(7).hashCode);
      expect(const ByLayerColor(), isNot(const ByBlockColor()));
    });

    test('an unknown encoding is rejected rather than silently defaulted', () {
      expect(() => decodeColor(-99), throwsArgumentError);
    });
  });

  group('ReservedHandles', () {
    test('are distinct, non-none, and below firstFree', () {
      const reserved = <Handle>[
        ReservedHandles.layerZero,
        ReservedHandles.byLayerLinetype,
        ReservedHandles.byBlockLinetype,
        ReservedHandles.continuousLinetype,
        ReservedHandles.standardTextStyle,
      ];
      expect(reserved.toSet().length, reserved.length);
      for (final h in reserved) {
        expect(h.isNone, isFalse);
        expect(h.value, lessThan(ReservedHandles.firstFree.value));
      }
    });
  });

  test('EntityFlags.invisible is a single bit', () {
    expect(EntityFlags.invisible, 1);
    expect(0 | EntityFlags.invisible, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/style_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'DraftColor'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/style.dart`:

```dart
import 'package:meta/meta.dart';

import '../core/handle.dart';

/// Inherit from the record's layer.
const int kByLayer = -1;

/// Inherit from the placing instance's own value.
const int kByBlock = -2;

/// Lineweight only: use the document default.
const int kLineweightDefault = -3;

/// Tags a true colour so it cannot be confused with an indexed one.
const int _kTrueColorTag = 0x01000000;

/// A tier-1 CAD colour: a native field, not a component.
///
/// Alpha is deliberately absent. DXF transparency is an independent field that
/// may itself be BYLAYER or BYBLOCK, so carrying alpha here would create a
/// second, conflicting source of truth for the same pixel.
@immutable
sealed class DraftColor {
  const DraftColor();
}

final class ByLayerColor extends DraftColor {
  const ByLayerColor();
  @override
  bool operator ==(Object other) => other is ByLayerColor;
  @override
  int get hashCode => kByLayer;
  @override
  String toString() => 'ByLayerColor()';
}

final class ByBlockColor extends DraftColor {
  const ByBlockColor();
  @override
  bool operator ==(Object other) => other is ByBlockColor;
  @override
  int get hashCode => kByBlock;
  @override
  String toString() => 'ByBlockColor()';
}

/// AutoCAD Color Index, 1..255.
final class IndexedColor extends DraftColor {
  final int aci;
  const IndexedColor(this.aci);
  @override
  bool operator ==(Object other) => other is IndexedColor && other.aci == aci;
  @override
  int get hashCode => Object.hash('aci', aci);
  @override
  String toString() => 'IndexedColor($aci)';
}

/// 24-bit RGB, `0xRRGGBB`.
final class TrueColor extends DraftColor {
  final int rgb;
  const TrueColor(this.rgb);
  @override
  bool operator ==(Object other) => other is TrueColor && other.rgb == rgb;
  @override
  int get hashCode => Object.hash('rgb', rgb);
  @override
  String toString() => 'TrueColor(0x${rgb.toRadixString(16).padLeft(6, '0')})';
}

/// Packs a colour into the single `Int32` an entity column holds.
///
/// True colours are tagged rather than stored raw, because an untagged 24-bit
/// value overlaps the 1..255 indexed range: `0x0000FF` and ACI 255 would be the
/// same integer.
int encodeColor(DraftColor color) => switch (color) {
      ByLayerColor() => kByLayer,
      ByBlockColor() => kByBlock,
      IndexedColor(:final aci) when aci >= 1 && aci <= 255 => aci,
      IndexedColor(:final aci) =>
        throw ArgumentError.value(aci, 'aci', 'must be 1..255'),
      TrueColor(:final rgb) when rgb >= 0 && rgb <= 0xFFFFFF =>
        _kTrueColorTag | rgb,
      TrueColor(:final rgb) =>
        throw ArgumentError.value(rgb, 'rgb', 'must be 0..0xFFFFFF'),
    };

DraftColor decodeColor(int encoded) {
  if (encoded == kByLayer) return const ByLayerColor();
  if (encoded == kByBlock) return const ByBlockColor();
  if (encoded >= 1 && encoded <= 255) return IndexedColor(encoded);
  // Range check, not `encoded & _kTrueColorTag != 0`: under two's complement
  // every negative int has bit 24 set, so the bitwise form would classify
  // decodeColor(-99) as a true colour instead of rejecting it.
  if (encoded >= _kTrueColorTag && encoded <= (_kTrueColorTag | 0xFFFFFF)) {
    return TrueColor(encoded & 0xFFFFFF);
  }
  throw ArgumentError.value(encoded, 'encoded', 'not a colour encoding');
}

/// Handles the document reserves for records that must always exist.
///
/// DXF's BYLAYER and BYBLOCK linetypes are real table records rather than magic
/// values, and layer 0 carries the block-inheritance rule. Reserving their
/// handles means the linetype column needs no sentinels and style resolution
/// walks one uniform path.
abstract final class ReservedHandles {
  static const Handle layerZero = Handle(1);
  static const Handle byLayerLinetype = Handle(2);
  static const Handle byBlockLinetype = Handle(3);
  static const Handle continuousLinetype = Handle(4);
  static const Handle standardTextStyle = Handle(5);

  /// The document's handle seed is raised to at least this value, so no
  /// allocated handle can ever collide with a reserved one.
  static const Handle firstFree = Handle(16);
}

/// Bit flags in the entity `flags` column.
abstract final class EntityFlags {
  /// DXF group code 60: the entity exists but is not drawn.
  static const int invisible = 1 << 0;
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/style.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): tier-1 style values with tagged column encoding"
```

---

### Task 10: EntityStore — columnar leaf records

**Files:**
- Create: `packages/jet_cad_2d/lib/src/store/entity_store.dart`
- Create: `packages/jet_cad_2d/test/store/entity_store_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle`, `SlotAllocator`, `DraftColor`/`encodeColor`, `EntityFlags`, `kByLayer`.
- Produces:
  - `enum EntityKind { point, line, polyline, circle, arc, text, attrib }`
  - `class EntityRecord` — immutable, value-equal, with `handle`, `owner`, `kind`, `layer`, `linetype`, `linetypeScale`, `geomIndex`, `color` (`DraftColor`), `lineweight`, `transparency`, `flags`; plus `EntityRecord copyWith({...})`, `Map<String, Object?> toJson()`, `static EntityRecord fromJson(Object?)`.
  - `class EntityStore` — `int add(EntityRecord)`, `EntityRecord read(int slot)`, `void replace(int slot, EntityRecord)`, `void remove(int slot)`, `int? slotOf(Handle)`, `bool containsHandle(Handle)`, `Iterable<int> get liveSlots`, `int get liveCount`, column accessors `kindAt/ownerAt/layerAt/linetypeAt/linetypeScaleAt/geomIndexAt/colorAt/lineweightAt/transparencyAt/flagsAt`, `List<int> purge()`, `void clear()`; and `class DuplicateHandleError implements Exception`.

The record is a **view constructed on demand**, never the stored representation. One object per entity is exactly what the columnar decision exists to avoid; the column accessors are what hot paths use.

`purge()` renumbers **entity** slots only. `geomIndex` values point into `GeometryStore` and are untouched — purging the two stores are two independent operations.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/store/entity_store_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

EntityRecord lineRecord(int handle, {int geomIndex = 0, int owner = 100}) =>
    EntityRecord(
      handle: Handle(handle),
      owner: Handle(owner),
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: geomIndex,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

void main() {
  test('round-trips a record through the columns', () {
    final store = EntityStore();
    final record = lineRecord(0x2A, geomIndex: 7).copyWith(
      color: const TrueColor(0xFF8800),
      lineweight: 35,
      transparency: 128,
      flags: EntityFlags.invisible,
      linetypeScale: 2.5,
    );
    final slot = store.add(record);
    expect(store.read(slot), record);
  });

  test('column accessors agree with the record view', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(1, geomIndex: 9, owner: 55));
    expect(store.kindAt(slot), EntityKind.line);
    expect(store.ownerAt(slot), const Handle(55));
    expect(store.geomIndexAt(slot), 9);
    expect(store.layerAt(slot), ReservedHandles.layerZero);
    expect(store.colorAt(slot), kByLayer);
    expect(store.linetypeScaleAt(slot), 1.0);
    expect(store.flagsAt(slot), 0);
  });

  test('stores a handle at the 32-bit ceiling without truncating', () {
    // The columns are Uint32List, which is why the handle space is capped.
    final store = EntityStore();
    final slot = store.add(lineRecord(1, owner: kMaxHandle));
    expect(store.ownerAt(slot), const Handle(kMaxHandle));
  });

  test('rejects a duplicate handle', () {
    final store = EntityStore();
    store.add(lineRecord(5));
    expect(() => store.add(lineRecord(5)), throwsA(isA<DuplicateHandleError>()));
  });

  test('slotOf resolves a handle and returns null after removal', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(5));
    expect(store.slotOf(const Handle(5)), slot);
    expect(store.containsHandle(const Handle(5)), isTrue);
    store.remove(slot);
    expect(store.slotOf(const Handle(5)), isNull);
    expect(store.containsHandle(const Handle(5)), isFalse);
  });

  test('a removed slot is reused and the handle may be re-added', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(5));
    store.remove(slot);
    // Undo restores the record; it may legitimately land in a different slot,
    // which is why the inverse command carries the record, not the slot.
    final restored = store.add(lineRecord(5));
    expect(store.read(restored).handle, const Handle(5));
    expect(store.liveCount, 1);
  });

  test('grows past the initial capacity without corrupting earlier rows', () {
    final store = EntityStore();
    for (var i = 1; i <= 300; i++) {
      store.add(lineRecord(i, geomIndex: i * 2));
    }
    expect(store.liveCount, 300);
    expect(store.geomIndexAt(store.slotOf(const Handle(1))!), 2);
    expect(store.geomIndexAt(store.slotOf(const Handle(300))!), 600);
  });

  test('liveSlots is ascending', () {
    final store = EntityStore();
    final a = store.add(lineRecord(1));
    final b = store.add(lineRecord(2));
    final c = store.add(lineRecord(3));
    store.remove(b);
    expect(store.liveSlots.toList(), [a, c]);
  });

  test('replace swaps the record in place and keeps the handle index correct', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(5));
    store.replace(slot, lineRecord(5).copyWith(geomIndex: 42));
    expect(store.geomIndexAt(slot), 42);
    expect(store.slotOf(const Handle(5)), slot);
  });

  test('purge compacts entity slots and leaves geomIndex untouched', () {
    // Purging the entity store and purging the geometry store are independent
    // operations; geomIndex points into the other store.
    final store = EntityStore();
    final a = store.add(lineRecord(1, geomIndex: 10));
    final b = store.add(lineRecord(2, geomIndex: 20));
    final c = store.add(lineRecord(3, geomIndex: 30));
    store.remove(b);

    final remap = store.purge();
    expect(remap[a], 0);
    expect(remap[b], -1);
    expect(remap[c], 1);
    expect(store.geomIndexAt(remap[c]), 30);
    expect(store.slotOf(const Handle(3)), remap[c]);
    expect(store.slotOf(const Handle(2)), isNull);
  });

  test('record json round-trips', () {
    final record = lineRecord(0x2A).copyWith(color: const IndexedColor(7));
    expect(EntityRecord.fromJson(record.toJson()), record);
  });

  test('record json emits keys in a stable order', () {
    expect(lineRecord(1).toJson().keys.toList(), [
      'handle',
      'owner',
      'kind',
      'layer',
      'linetype',
      'linetypeScale',
      'geomIndex',
      'color',
      'lineweight',
      'transparency',
      'flags',
    ]);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/store/entity_store_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'EntityRecord'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/store/entity_store.dart`:

```dart
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/handle.dart';
import '../document/style.dart';
import 'slot_allocator.dart';

enum EntityKind { point, line, polyline, circle, arc, text, attrib }

class DuplicateHandleError implements Exception {
  final Handle handle;
  const DuplicateHandleError(this.handle);

  @override
  String toString() => 'DuplicateHandleError(${handle.toHex()})';
}

/// A detached leaf record.
///
/// This is a **view**, constructed on demand — never the stored representation.
/// One object per entity is precisely what the columnar decision exists to
/// avoid; hot paths use the store's column accessors instead. Commands carry
/// records for the same reason they carry geometry payloads: an inverse must be
/// able to restore into whichever slot is free.
@immutable
class EntityRecord {
  final Handle handle;

  /// The definition, group node, instance node, or document root that owns
  /// this leaf. Leaf coordinates are expressed in the owner's space.
  final Handle owner;

  final EntityKind kind;
  final Handle layer;
  final Handle linetype;
  final double linetypeScale;

  /// Index into the document's [GeometryStore]. Opaque here.
  final int geomIndex;

  final DraftColor color;

  /// 1/100 mm, or one of [kByLayer], [kByBlock], [kLineweightDefault].
  final int lineweight;

  /// 0..255, or one of [kByLayer], [kByBlock].
  final int transparency;

  /// Bitmask; see [EntityFlags].
  final int flags;

  const EntityRecord({
    required this.handle,
    required this.owner,
    required this.kind,
    required this.layer,
    required this.linetype,
    required this.linetypeScale,
    required this.geomIndex,
    required this.color,
    required this.lineweight,
    required this.transparency,
    required this.flags,
  });

  EntityRecord copyWith({
    Handle? handle,
    Handle? owner,
    EntityKind? kind,
    Handle? layer,
    Handle? linetype,
    double? linetypeScale,
    int? geomIndex,
    DraftColor? color,
    int? lineweight,
    int? transparency,
    int? flags,
  }) =>
      EntityRecord(
        handle: handle ?? this.handle,
        owner: owner ?? this.owner,
        kind: kind ?? this.kind,
        layer: layer ?? this.layer,
        linetype: linetype ?? this.linetype,
        linetypeScale: linetypeScale ?? this.linetypeScale,
        geomIndex: geomIndex ?? this.geomIndex,
        color: color ?? this.color,
        lineweight: lineweight ?? this.lineweight,
        transparency: transparency ?? this.transparency,
        flags: flags ?? this.flags,
      );

  /// Key order is fixed, because serialization must be byte-deterministic.
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'owner': owner.toJson(),
        'kind': kind.name,
        'layer': layer.toJson(),
        'linetype': linetype.toJson(),
        'linetypeScale': linetypeScale,
        'geomIndex': geomIndex,
        'color': encodeColor(color),
        'lineweight': lineweight,
        'transparency': transparency,
        'flags': flags,
      };

  static EntityRecord fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('EntityRecord expects an object, got: $json');
    }
    return EntityRecord(
      handle: Handle.fromJson(json['handle']),
      owner: Handle.fromJson(json['owner']),
      kind: EntityKind.values.byName(json['kind']! as String),
      layer: Handle.fromJson(json['layer']),
      linetype: Handle.fromJson(json['linetype']),
      linetypeScale: (json['linetypeScale']! as num).toDouble(),
      geomIndex: json['geomIndex']! as int,
      color: decodeColor(json['color']! as int),
      lineweight: json['lineweight']! as int,
      transparency: json['transparency']! as int,
      flags: json['flags']! as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntityRecord &&
      other.handle == handle &&
      other.owner == owner &&
      other.kind == kind &&
      other.layer == layer &&
      other.linetype == linetype &&
      other.linetypeScale == linetypeScale &&
      other.geomIndex == geomIndex &&
      other.color == color &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.flags == flags;

  @override
  int get hashCode => Object.hash(handle, owner, kind, layer, linetype,
      linetypeScale, geomIndex, color, lineweight, transparency, flags);

  @override
  String toString() => 'EntityRecord(${kind.name} ${handle.toHex()})';
}

/// Columnar storage for leaf entity records, including tier-1 style.
///
/// Style lives in columns here rather than in a component store because these
/// are native CAD fields required for lossless round-trip, whereas components
/// are the extension mechanism. Defaults are `BYLAYER` sentinels, so the common
/// case costs one small integer per column.
class EntityStore {
  static const int _initialCapacity = 64;

  final SlotAllocator _slots = SlotAllocator();
  final Map<Handle, int> _slotOf = {};

  Uint8List _kind = Uint8List(_initialCapacity);
  Uint32List _owner = Uint32List(_initialCapacity);
  Uint32List _handle = Uint32List(_initialCapacity);
  Uint32List _layer = Uint32List(_initialCapacity);
  Uint32List _linetype = Uint32List(_initialCapacity);
  Float64List _linetypeScale = Float64List(_initialCapacity);
  Uint32List _geomIndex = Uint32List(_initialCapacity);
  Int32List _color = Int32List(_initialCapacity);
  Int16List _lineweight = Int16List(_initialCapacity);

  /// `Int16` rather than `Uint8`: transparency may itself be BYLAYER or
  /// BYBLOCK, and those sentinels are negative.
  Int16List _transparency = Int16List(_initialCapacity);

  Uint8List _flags = Uint8List(_initialCapacity);

  int get liveCount => _slots.liveCount;

  Iterable<int> get liveSlots => _slots.liveSlots;

  int? slotOf(Handle handle) => _slotOf[handle];

  bool containsHandle(Handle handle) => _slotOf.containsKey(handle);

  int add(EntityRecord record) {
    if (_slotOf.containsKey(record.handle)) {
      throw DuplicateHandleError(record.handle);
    }
    final slot = _slots.allocate();
    _ensureCapacity(_slots.capacity);
    _write(slot, record);
    _slotOf[record.handle] = slot;
    return slot;
  }

  EntityRecord read(int slot) {
    _requireLive(slot);
    return EntityRecord(
      handle: Handle(_handle[slot]),
      owner: Handle(_owner[slot]),
      kind: EntityKind.values[_kind[slot]],
      layer: Handle(_layer[slot]),
      linetype: Handle(_linetype[slot]),
      linetypeScale: _linetypeScale[slot],
      geomIndex: _geomIndex[slot],
      color: decodeColor(_color[slot]),
      lineweight: _lineweight[slot],
      transparency: _transparency[slot],
      flags: _flags[slot],
    );
  }

  void replace(int slot, EntityRecord record) {
    _requireLive(slot);
    final existing = Handle(_handle[slot]);
    if (record.handle != existing) {
      if (_slotOf.containsKey(record.handle)) {
        throw DuplicateHandleError(record.handle);
      }
      _slotOf.remove(existing);
      _slotOf[record.handle] = slot;
    }
    _write(slot, record);
  }

  void remove(int slot) {
    _requireLive(slot);
    _slotOf.remove(Handle(_handle[slot]));
    _slots.free(slot);
  }

  EntityKind kindAt(int slot) => EntityKind.values[_kind[slot]];
  Handle ownerAt(int slot) => Handle(_owner[slot]);
  Handle handleAt(int slot) => Handle(_handle[slot]);
  Handle layerAt(int slot) => Handle(_layer[slot]);
  Handle linetypeAt(int slot) => Handle(_linetype[slot]);
  double linetypeScaleAt(int slot) => _linetypeScale[slot];
  int geomIndexAt(int slot) => _geomIndex[slot];
  int colorAt(int slot) => _color[slot];
  int lineweightAt(int slot) => _lineweight[slot];
  int transparencyAt(int slot) => _transparency[slot];
  int flagsAt(int slot) => _flags[slot];

  /// Explicit maintenance compaction of **entity** slots.
  ///
  /// Returns the old-slot to new-slot remap. `geomIndex` values are references
  /// into the geometry store and are deliberately untouched: purging the two
  /// stores are independent operations. The caller must rewrite every reference
  /// to an entity slot and clear the undo stack.
  List<int> purge() {
    final remap = _slots.compact();
    for (var old = 0; old < remap.length; old++) {
      final to = remap[old];
      if (to < 0 || to == old) continue;
      _kind[to] = _kind[old];
      _owner[to] = _owner[old];
      _handle[to] = _handle[old];
      _layer[to] = _layer[old];
      _linetype[to] = _linetype[old];
      _linetypeScale[to] = _linetypeScale[old];
      _geomIndex[to] = _geomIndex[old];
      _color[to] = _color[old];
      _lineweight[to] = _lineweight[old];
      _transparency[to] = _transparency[old];
      _flags[to] = _flags[old];
    }
    _slotOf.clear();
    for (final slot in _slots.liveSlots) {
      _slotOf[Handle(_handle[slot])] = slot;
    }
    return remap;
  }

  void clear() {
    _slots.clear();
    _slotOf.clear();
  }

  void _write(int slot, EntityRecord r) {
    _kind[slot] = r.kind.index;
    _owner[slot] = r.owner.value;
    _handle[slot] = r.handle.value;
    _layer[slot] = r.layer.value;
    _linetype[slot] = r.linetype.value;
    _linetypeScale[slot] = r.linetypeScale;
    _geomIndex[slot] = r.geomIndex;
    _color[slot] = encodeColor(r.color);
    _lineweight[slot] = r.lineweight;
    _transparency[slot] = r.transparency;
    _flags[slot] = r.flags;
  }

  /// Growth reallocates and copies. It never reorders live slots, because a
  /// slot value may only change inside a command that rewrites every reference
  /// to it — and growing is not such a command.
  void _ensureCapacity(int needed) {
    if (needed <= _kind.length) return;
    var capacity = _kind.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    _kind = Uint8List(capacity)..setAll(0, _kind);
    _owner = Uint32List(capacity)..setAll(0, _owner);
    _handle = Uint32List(capacity)..setAll(0, _handle);
    _layer = Uint32List(capacity)..setAll(0, _layer);
    _linetype = Uint32List(capacity)..setAll(0, _linetype);
    _linetypeScale = Float64List(capacity)..setAll(0, _linetypeScale);
    _geomIndex = Uint32List(capacity)..setAll(0, _geomIndex);
    _color = Int32List(capacity)..setAll(0, _color);
    _lineweight = Int16List(capacity)..setAll(0, _lineweight);
    _transparency = Int16List(capacity)..setAll(0, _transparency);
    _flags = Uint8List(capacity)..setAll(0, _flags);
  }

  void _requireLive(int slot) {
    if (!_slots.isLive(slot)) throw SlotStateError(slot, 'not live');
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/store/entity_store.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): columnar EntityStore with tier-1 style columns"
```

---

### Task 11: Document tables

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/tables.dart`
- Create: `packages/jet_cad_2d/test/document/tables_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle`, `DraftColor`, `ReservedHandles`, `kByLayer`, `kLineweightDefault`, `listEquals` (Task 4).
- Produces:
  - `abstract class TableRecord` — `Handle get handle`, `String get name`, `Map<String, Object?> toJson()`.
  - `class TableSection<T extends TableRecord>` — `void add(T)`, `T? operator [](Handle)`, `T? byName(String)`, `Iterable<T> get records` (ascending handle), `void remove(Handle)`, `bool contains(Handle)`, `int get length`.
  - Records: `LayerRecord`, `LinetypeRecord` (with `class DashPattern`), `TextStyleRecord`, `PatternRecord` (with `class PatternLine`), `DimStyleRecord`, `AppIdRecord`.
  - `class DocumentTables` — fields `layers`, `linetypes`, `textStyles`, `patterns`, `dimStyles`, `appIds`; `factory DocumentTables.standard()`.

`DimStyleRecord` is deliberately opaque beyond its name: dimension *editing* is a non-goal, so the record preserves whatever an importer read and never interprets it. Modelling DIMSTYLE properly would be building the engine this architecture explicitly does not build.

`TableSection` is generic rather than six near-identical classes; the only behaviour that differs per table is the record type.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/tables_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  group('TableSection', () {
    test('adds, looks up by handle and by name', () {
      final layers = TableSection<LayerRecord>();
      const record = LayerRecord(
        handle: Handle(20),
        name: 'A-WALL',
        color: IndexedColor(7),
        linetype: ReservedHandles.continuousLinetype,
        lineweight: kLineweightDefault,
        transparency: 0,
      );
      layers.add(record);
      expect(layers[const Handle(20)], record);
      expect(layers.byName('A-WALL'), record);
      expect(layers.byName('missing'), isNull);
      expect(layers.length, 1);
    });

    test('name lookup is case-insensitive, as DXF table names are', () {
      final layers = TableSection<LayerRecord>()
        ..add(const LayerRecord(
          handle: Handle(20),
          name: 'A-Wall',
          color: ByLayerColor(),
          linetype: ReservedHandles.continuousLinetype,
          lineweight: kLineweightDefault,
          transparency: 0,
        ));
      expect(layers.byName('a-wall'), isNotNull);
      expect(layers.byName('A-WALL'), isNotNull);
    });

    test('records iterate in ascending handle order, never insertion order', () {
      // Determinism: serialization walks this iterator, and byte-identical
      // output cannot depend on insertion or hash order.
      final ids = TableSection<AppIdRecord>()
        ..add(const AppIdRecord(handle: Handle(30), name: 'C'))
        ..add(const AppIdRecord(handle: Handle(10), name: 'A'))
        ..add(const AppIdRecord(handle: Handle(20), name: 'B'));
      expect([for (final r in ids.records) r.name], ['A', 'B', 'C']);
    });

    test('rejects a duplicate handle and a duplicate name', () {
      final ids = TableSection<AppIdRecord>()
        ..add(const AppIdRecord(handle: Handle(10), name: 'A'));
      expect(() => ids.add(const AppIdRecord(handle: Handle(10), name: 'B')),
          throwsA(isA<DuplicateHandleError>()));
      expect(() => ids.add(const AppIdRecord(handle: Handle(11), name: 'a')),
          throwsA(isA<DuplicateTableNameError>()));
    });

    test('remove clears both indices', () {
      final ids = TableSection<AppIdRecord>()
        ..add(const AppIdRecord(handle: Handle(10), name: 'A'))
        ..remove(const Handle(10));
      expect(ids[const Handle(10)], isNull);
      expect(ids.byName('A'), isNull);
    });
  });

  group('DocumentTables.standard', () {
    final tables = DocumentTables.standard();

    test('seeds layer 0 at its reserved handle', () {
      final zero = tables.layers[ReservedHandles.layerZero];
      expect(zero, isNotNull);
      expect(zero!.name, '0');
      // Layer 0 carries the block-inheritance rule, so it must always exist.
      expect(tables.layers.byName('0'), same(zero));
    });

    test('seeds BYLAYER, BYBLOCK and CONTINUOUS linetypes as real records', () {
      expect(tables.linetypes[ReservedHandles.byLayerLinetype]?.name, 'ByLayer');
      expect(tables.linetypes[ReservedHandles.byBlockLinetype]?.name, 'ByBlock');
      final continuous =
          tables.linetypes[ReservedHandles.continuousLinetype];
      expect(continuous?.name, 'Continuous');
      expect(continuous?.pattern.dashes, isEmpty);
    });

    test('seeds the Standard text style', () {
      final std = tables.textStyles[ReservedHandles.standardTextStyle];
      expect(std, isNotNull);
      expect(std!.name, 'Standard');
      expect(std.widthFactor, 1.0);
      expect(std.isShx, isFalse);
    });

    test('pattern and dimstyle tables start empty', () {
      expect(tables.patterns.length, 0);
      expect(tables.dimStyles.length, 0);
    });
  });

  group('records', () {
    test('LayerRecord json round-trips with stable key order', () {
      const record = LayerRecord(
        handle: Handle(20),
        name: 'A-WALL',
        color: TrueColor(0x00FF00),
        linetype: ReservedHandles.continuousLinetype,
        lineweight: 25,
        transparency: 0,
        visible: false,
        locked: true,
      );
      expect(record.toJson().keys.toList(), [
        'handle',
        'name',
        'color',
        'linetype',
        'lineweight',
        'transparency',
        'visible',
        'locked',
      ]);
      expect(LayerRecord.fromJson(record.toJson()), record);
    });

    test('LinetypeRecord carries a dash pattern in paper units', () {
      const record = LinetypeRecord(
        handle: Handle(21),
        name: 'Dashed',
        description: '__ __ __',
        pattern: DashPattern(dashes: [0.5, -0.25], totalLength: 0.75),
      );
      expect(LinetypeRecord.fromJson(record.toJson()), record);
    });

    test('PatternRecord carries hatch pattern lines', () {
      const record = PatternRecord(
        handle: Handle(22),
        name: 'ANSI31',
        lines: [
          PatternLine(
            angle: 0.785398,
            baseX: 0,
            baseY: 0,
            deltaX: 0,
            deltaY: 0.125,
            dashes: [],
          ),
        ],
      );
      expect(PatternRecord.fromJson(record.toJson()), record);
    });

    test('DimStyleRecord preserves opaque data it never interprets', () {
      // Dimension editing is a non-goal; the record exists so an imported
      // DIMSTYLE survives a round-trip untouched.
      const record = DimStyleRecord(
        handle: Handle(23),
        name: 'ISO-25',
        opaque: {'dimtxt': 2.5, 'dimclrd': 256},
      );
      expect(DimStyleRecord.fromJson(record.toJson()), record);
      expect(record.opaque['dimtxt'], 2.5);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/tables_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'TableSection'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/tables.dart`:

```dart
import 'package:meta/meta.dart';

import '../core/handle.dart';
import '../core/list_equality.dart';
import '../store/entity_store.dart' show DuplicateHandleError;
import 'style.dart';

class DuplicateTableNameError implements Exception {
  final String name;
  const DuplicateTableNameError(this.name);

  @override
  String toString() => 'DuplicateTableNameError($name)';
}

@immutable
abstract class TableRecord {
  Handle get handle;
  String get name;
  Map<String, Object?> toJson();
}

/// One named table — layers, linetypes, text styles, and so on.
///
/// Generic rather than six near-identical classes: the only thing that varies
/// per table is the record type.
class TableSection<T extends TableRecord> {
  final Map<Handle, T> _byHandle = {};
  final Map<String, Handle> _byName = {};

  int get length => _byHandle.length;

  bool contains(Handle handle) => _byHandle.containsKey(handle);

  T? operator [](Handle handle) => _byHandle[handle];

  /// DXF table names are case-insensitive, so lookup folds case.
  T? byName(String name) {
    final handle = _byName[name.toLowerCase()];
    return handle == null ? null : _byHandle[handle];
  }

  /// Ascending handle order. Serialization walks this, and byte-identical
  /// output cannot depend on insertion or hash order.
  Iterable<T> get records {
    final handles = _byHandle.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final h in handles) _byHandle[h]!];
  }

  void add(T record) {
    if (_byHandle.containsKey(record.handle)) {
      throw DuplicateHandleError(record.handle);
    }
    final key = record.name.toLowerCase();
    if (_byName.containsKey(key)) throw DuplicateTableNameError(record.name);
    _byHandle[record.handle] = record;
    _byName[key] = record.handle;
  }

  void remove(Handle handle) {
    final record = _byHandle.remove(handle);
    if (record != null) _byName.remove(record.name.toLowerCase());
  }

  void clear() {
    _byHandle.clear();
    _byName.clear();
  }
}

@immutable
class LayerRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final DraftColor color;
  final Handle linetype;
  final int lineweight;
  final int transparency;
  final bool visible;
  final bool locked;

  const LayerRecord({
    required this.handle,
    required this.name,
    required this.color,
    required this.linetype,
    required this.lineweight,
    required this.transparency,
    this.visible = true,
    this.locked = false,
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'color': encodeColor(color),
        'linetype': linetype.toJson(),
        'lineweight': lineweight,
        'transparency': transparency,
        'visible': visible,
        'locked': locked,
      };

  static LayerRecord fromJson(Map<String, Object?> json) => LayerRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        color: decodeColor(json['color']! as int),
        linetype: Handle.fromJson(json['linetype']),
        lineweight: json['lineweight']! as int,
        transparency: json['transparency']! as int,
        visible: json['visible']! as bool,
        locked: json['locked']! as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is LayerRecord &&
      other.handle == handle &&
      other.name == name &&
      other.color == color &&
      other.linetype == linetype &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.visible == visible &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(handle, name, color, linetype, lineweight,
      transparency, visible, locked);
}

/// A linetype's dash sequence, in **paper** units.
///
/// Positive values are dashes, negative values are gaps — the DXF convention.
/// Paper units, not world units, because a dash pattern must not stretch when
/// the drawing is zoomed.
@immutable
class DashPattern {
  final List<double> dashes;
  final double totalLength;

  const DashPattern({required this.dashes, required this.totalLength});

  Map<String, Object?> toJson() =>
      {'dashes': dashes, 'totalLength': totalLength};

  static DashPattern fromJson(Map<String, Object?> json) => DashPattern(
        dashes: [
          for (final d in json['dashes']! as List) (d as num).toDouble(),
        ],
        totalLength: (json['totalLength']! as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is DashPattern &&
      other.totalLength == totalLength &&
      listEquals(other.dashes, dashes);

  @override
  int get hashCode => Object.hash(Object.hashAll(dashes), totalLength);
}

@immutable
class LinetypeRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final String description;
  final DashPattern pattern;

  const LinetypeRecord({
    required this.handle,
    required this.name,
    required this.description,
    required this.pattern,
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'description': description,
        'pattern': pattern.toJson(),
      };

  static LinetypeRecord fromJson(Map<String, Object?> json) => LinetypeRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        description: json['description']! as String,
        pattern:
            DashPattern.fromJson((json['pattern']! as Map).cast<String, Object?>()),
      );

  @override
  bool operator ==(Object other) =>
      other is LinetypeRecord &&
      other.handle == handle &&
      other.name == name &&
      other.description == description &&
      other.pattern == pattern;

  @override
  int get hashCode => Object.hash(handle, name, description, pattern);
}

@immutable
class TextStyleRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;

  /// The font used for display. SHX styles map here too — see [isShx].
  final String fontFamily;

  final double widthFactor;
  final double obliqueAngle;

  /// Zero means the height is supplied per text entity.
  final double fixedHeight;

  /// True when the original style named an SHX font. Display maps to
  /// [fontFamily] and is declared lossy; the flag and [shxFileName] exist so
  /// the original survives a round-trip.
  final bool isShx;
  final String shxFileName;

  const TextStyleRecord({
    required this.handle,
    required this.name,
    required this.fontFamily,
    this.widthFactor = 1.0,
    this.obliqueAngle = 0.0,
    this.fixedHeight = 0.0,
    this.isShx = false,
    this.shxFileName = '',
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'fontFamily': fontFamily,
        'widthFactor': widthFactor,
        'obliqueAngle': obliqueAngle,
        'fixedHeight': fixedHeight,
        'isShx': isShx,
        'shxFileName': shxFileName,
      };

  static TextStyleRecord fromJson(Map<String, Object?> json) => TextStyleRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        fontFamily: json['fontFamily']! as String,
        widthFactor: (json['widthFactor']! as num).toDouble(),
        obliqueAngle: (json['obliqueAngle']! as num).toDouble(),
        fixedHeight: (json['fixedHeight']! as num).toDouble(),
        isShx: json['isShx']! as bool,
        shxFileName: json['shxFileName']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is TextStyleRecord &&
      other.handle == handle &&
      other.name == name &&
      other.fontFamily == fontFamily &&
      other.widthFactor == widthFactor &&
      other.obliqueAngle == obliqueAngle &&
      other.fixedHeight == fixedHeight &&
      other.isShx == isShx &&
      other.shxFileName == shxFileName;

  @override
  int get hashCode => Object.hash(handle, name, fontFamily, widthFactor,
      obliqueAngle, fixedHeight, isShx, shxFileName);
}

/// One line family of a hatch pattern, in the `.pat` sense.
@immutable
class PatternLine {
  final double angle;
  final double baseX;
  final double baseY;
  final double deltaX;
  final double deltaY;
  final List<double> dashes;

  const PatternLine({
    required this.angle,
    required this.baseX,
    required this.baseY,
    required this.deltaX,
    required this.deltaY,
    required this.dashes,
  });

  Map<String, Object?> toJson() => {
        'angle': angle,
        'baseX': baseX,
        'baseY': baseY,
        'deltaX': deltaX,
        'deltaY': deltaY,
        'dashes': dashes,
      };

  static PatternLine fromJson(Map<String, Object?> json) => PatternLine(
        angle: (json['angle']! as num).toDouble(),
        baseX: (json['baseX']! as num).toDouble(),
        baseY: (json['baseY']! as num).toDouble(),
        deltaX: (json['deltaX']! as num).toDouble(),
        deltaY: (json['deltaY']! as num).toDouble(),
        dashes: [for (final d in json['dashes']! as List) (d as num).toDouble()],
      );

  @override
  bool operator ==(Object other) =>
      other is PatternLine &&
      other.angle == angle &&
      other.baseX == baseX &&
      other.baseY == baseY &&
      other.deltaX == deltaX &&
      other.deltaY == deltaY &&
      listEquals(other.dashes, dashes);

  @override
  int get hashCode => Object.hash(
      angle, baseX, baseY, deltaX, deltaY, Object.hashAll(dashes));
}

@immutable
class PatternRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final List<PatternLine> lines;

  const PatternRecord({
    required this.handle,
    required this.name,
    required this.lines,
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'lines': [for (final l in lines) l.toJson()],
      };

  static PatternRecord fromJson(Map<String, Object?> json) => PatternRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        lines: [
          for (final l in json['lines']! as List)
            PatternLine.fromJson((l as Map).cast<String, Object?>()),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is PatternRecord &&
      other.handle == handle &&
      other.name == name &&
      listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(handle, name, Object.hashAll(lines));
}

/// A dimension style, preserved but never interpreted.
///
/// Dimension *editing* is a non-goal: regenerating dimension geometry needs a
/// full DIMSTYLE engine, which this architecture explicitly does not build. The
/// record exists so an imported style survives a round-trip unchanged.
@immutable
class DimStyleRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final Map<String, Object?> opaque;

  const DimStyleRecord({
    required this.handle,
    required this.name,
    this.opaque = const {},
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        // Sorted so serialization stays byte-deterministic across runs.
        'opaque': {
          for (final key in opaque.keys.toList()..sort()) key: opaque[key],
        },
      };

  static DimStyleRecord fromJson(Map<String, Object?> json) => DimStyleRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        opaque: (json['opaque']! as Map).cast<String, Object?>(),
      );

  @override
  bool operator ==(Object other) =>
      other is DimStyleRecord &&
      other.handle == handle &&
      other.name == name &&
      _sameOpaque(other.opaque, opaque);

  static bool _sameOpaque(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(handle, name, opaque.length);
}

@immutable
class AppIdRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;

  const AppIdRecord({required this.handle, required this.name});

  @override
  Map<String, Object?> toJson() =>
      {'handle': handle.toJson(), 'name': name};

  static AppIdRecord fromJson(Map<String, Object?> json) => AppIdRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is AppIdRecord && other.handle == handle && other.name == name;

  @override
  int get hashCode => Object.hash(handle, name);
}

/// Every named table a document owns.
class DocumentTables {
  final TableSection<LayerRecord> layers = TableSection();
  final TableSection<LinetypeRecord> linetypes = TableSection();
  final TableSection<TextStyleRecord> textStyles = TableSection();
  final TableSection<PatternRecord> patterns = TableSection();
  final TableSection<DimStyleRecord> dimStyles = TableSection();
  final TableSection<AppIdRecord> appIds = TableSection();

  DocumentTables();

  /// Seeds the records a document cannot function without.
  ///
  /// BYLAYER and BYBLOCK are real linetype records rather than magic values, so
  /// the entity linetype column needs no sentinels; layer 0 must exist because
  /// it carries the block-inheritance rule.
  factory DocumentTables.standard() {
    final tables = DocumentTables();
    tables.linetypes
      ..add(const LinetypeRecord(
        handle: ReservedHandles.byLayerLinetype,
        name: 'ByLayer',
        description: '',
        pattern: DashPattern(dashes: [], totalLength: 0),
      ))
      ..add(const LinetypeRecord(
        handle: ReservedHandles.byBlockLinetype,
        name: 'ByBlock',
        description: '',
        pattern: DashPattern(dashes: [], totalLength: 0),
      ))
      ..add(const LinetypeRecord(
        handle: ReservedHandles.continuousLinetype,
        name: 'Continuous',
        description: 'Solid line',
        pattern: DashPattern(dashes: [], totalLength: 0),
      ));
    tables.layers.add(const LayerRecord(
      handle: ReservedHandles.layerZero,
      name: '0',
      color: IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
    ));
    tables.textStyles.add(const TextStyleRecord(
      handle: ReservedHandles.standardTextStyle,
      name: 'Standard',
      fontFamily: 'Roboto',
    ));
    return tables;
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/tables.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): document tables with reserved standard records"
```

---

### Task 12: Node and Definition value types

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/node.dart`
- Create: `packages/jet_cad_2d/test/document/node_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle`, `Transform2`, `Tolerance`, `listEquals` (Task 4).
- Produces:
  - `sealed class Node` — `Handle get handle`, `Handle get parent`, `Transform2 get transform`, `bool get visible`, `Map<String, Object?> toJson()`, `static Node fromJson(Object?)`.
  - `final class GroupNode extends Node` — plus `List<Handle> children`, `bool exportAsDxfGroup`, `GroupNode copyWith({...})`.
  - `final class InstanceNode extends Node` — plus `Handle definition`, `Handle layer`, `InstanceNode copyWith({...})`.
  - `final class Definition` — `handle`, `name`, `Vector2 basePoint`, `List<Handle> children`, `bool isXref`, `String xrefPath`, `copyWith({...})`, `toJson()`, `fromJson`.

All four are **immutable and value-equal**. Commands replace a node wholesale rather than mutating it, which is what makes value-diff undo work without snapshots.

Only containers are nodes. Leaf entities live in `EntityStore` and carry no transform, which is both DXF-correct and what keeps a large document free of per-entity matrices.

`Definition` is not a `Node`: it is a prototype, so it has no parent and no transform of its own. `basePoint` is required — DXF BLOCK carries one, and insertion alignment is wrong on import without it.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/node_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('GroupNode', () {
    final group = GroupNode(
      handle: const Handle(10),
      parent: Handle.none,
      transform: Transform2.translation(5, 5),
      children: const [Handle(11), Handle(12)],
    );

    test('defaults: visible, not a DXF group', () {
      expect(group.visible, isTrue);
      // Only a group that arrived as a DXF GROUP exports as one; groups made
      // in the designer export as anonymous blocks.
      expect(group.exportAsDxfGroup, isFalse);
    });

    test('child order is preserved, because it is draw order', () {
      expect(group.children, [const Handle(11), const Handle(12)]);
    });

    test('copyWith replaces one field and leaves the rest', () {
      final hidden = group.copyWith(visible: false);
      expect(hidden.visible, isFalse);
      expect(hidden.children, group.children);
      expect(hidden.handle, group.handle);
    });

    test('json round-trips through the Node dispatcher', () {
      final decoded = Node.fromJson(group.toJson());
      expect(decoded, isA<GroupNode>());
      expect(decoded, group);
    });

    test('json key order is stable', () {
      expect(group.toJson().keys.toList(),
          ['type', 'handle', 'parent', 'transform', 'visible', 'children', 'exportAsDxfGroup']);
    });
  });

  group('InstanceNode', () {
    final instance = InstanceNode(
      handle: const Handle(20),
      parent: const Handle(10),
      transform: Transform2.scale(-1, 2),
      definition: const Handle(30),
      layer: ReservedHandles.layerZero,
    );

    test('carries a definition reference and its own layer', () {
      expect(instance.definition, const Handle(30));
      expect(instance.layer, ReservedHandles.layerZero);
    });

    test('supports a mirroring transform', () {
      // Negative scale is explicitly supported; a TRS-only transform could not
      // represent it, which is why Transform2 is a full affine.
      expect(instance.transform.determinant, lessThan(0));
    });

    test('has no attributes field — ATTRIBs are child entities', () {
      // A Map<String,String> could not reconstruct a DXF ATTRIB, which is a
      // full text entity with its own placement, style and flags. This test
      // exists so nobody adds the field back.
      expect(instance.toJson().containsKey('attributes'), isFalse);
    });

    test('json round-trips through the Node dispatcher', () {
      final decoded = Node.fromJson(instance.toJson());
      expect(decoded, isA<InstanceNode>());
      expect(decoded, instance);
    });
  });

  group('Definition', () {
    final definition = Definition(
      handle: const Handle(30),
      name: 'Table-4Seat',
      basePoint: Vector2(0.5, 0.25),
      children: const [Handle(31), Handle(32)],
    );

    test('carries a base point, which insertion alignment depends on', () {
      expect(definition.basePoint, Vector2(0.5, 0.25));
    });

    test('is not a Node — a prototype has no parent and no transform', () {
      expect(definition, isNot(isA<Node>()));
    });

    test('defaults to not being an xref', () {
      expect(definition.isXref, isFalse);
      expect(definition.xrefPath, isEmpty);
    });

    test('an xref records its path so it survives a round-trip unresolved', () {
      final xref = definition.copyWith(isXref: true, xrefPath: 'site.dwg');
      expect(xref.isXref, isTrue);
      expect(Definition.fromJson(xref.toJson()), xref);
    });

    test('json round-trips', () {
      expect(Definition.fromJson(definition.toJson()), definition);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/node_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'GroupNode'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/node.dart`:

```dart
import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';
import '../core/list_equality.dart';
import '../core/tolerance.dart';
import '../geometry/transform2.dart';

/// A container in the scene tree.
///
/// Only containers carry a transform. Leaf entities live in the entity store,
/// express their coordinates in their owner's space, and have no transform of
/// their own — DXF-correct, and what keeps a million-entity document free of
/// per-entity matrices.
///
/// Nodes are immutable: a command replaces a node wholesale, which is what lets
/// undo be a plain value diff with no snapshots.
@immutable
sealed class Node {
  final Handle handle;

  /// [Handle.none] at the document root.
  final Handle parent;

  final Transform2 transform;
  final bool visible;

  const Node({
    required this.handle,
    required this.parent,
    required this.transform,
    required this.visible,
  });

  Map<String, Object?> toJson();

  static Node fromJson(Object? json) {
    if (json is! Map) throw FormatException('Node expects an object: $json');
    final map = json.cast<String, Object?>();
    return switch (map['type']) {
      'group' => GroupNode.fromJson(map),
      'instance' => InstanceNode.fromJson(map),
      final other => throw FormatException('unknown node type: $other'),
    };
  }
}

/// A one-off arrangement that owns its children.
///
/// Exports as an anonymous block rather than a DXF GROUP, because GROUP is a
/// flat handle list that can represent neither nesting nor a transform. A GROUP
/// read on import sets [exportAsDxfGroup] so a file that arrived with GROUPs
/// leaves with GROUPs.
final class GroupNode extends Node {
  final List<Handle> children;
  final bool exportAsDxfGroup;

  const GroupNode({
    required super.handle,
    required super.parent,
    required super.transform,
    required this.children,
    super.visible = true,
    this.exportAsDxfGroup = false,
  });

  GroupNode copyWith({
    Handle? handle,
    Handle? parent,
    Transform2? transform,
    bool? visible,
    List<Handle>? children,
    bool? exportAsDxfGroup,
  }) =>
      GroupNode(
        handle: handle ?? this.handle,
        parent: parent ?? this.parent,
        transform: transform ?? this.transform,
        visible: visible ?? this.visible,
        children: children ?? this.children,
        exportAsDxfGroup: exportAsDxfGroup ?? this.exportAsDxfGroup,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'group',
        'handle': handle.toJson(),
        'parent': parent.toJson(),
        'transform': transform.toJson(),
        'visible': visible,
        'children': [for (final c in children) c.toJson()],
        'exportAsDxfGroup': exportAsDxfGroup,
      };

  static GroupNode fromJson(Map<String, Object?> json) => GroupNode(
        handle: Handle.fromJson(json['handle']),
        parent: Handle.fromJson(json['parent']),
        transform: Transform2.fromJson(json['transform']),
        visible: json['visible']! as bool,
        children: [
          for (final c in json['children']! as List) Handle.fromJson(c),
        ],
        exportAsDxfGroup: json['exportAsDxfGroup']! as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is GroupNode &&
      other.handle == handle &&
      other.parent == parent &&
      other.transform.equals(transform, const Tolerance(linear: 0, angular: 0)) &&
      other.visible == visible &&
      other.exportAsDxfGroup == exportAsDxfGroup &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(handle, parent, visible, exportAsDxfGroup,
      Object.hashAll(children));

  @override
  String toString() => 'GroupNode(${handle.toHex()}, ${children.length} children)';
}

/// A placement of a shared [Definition].
///
/// The same concept as DXF's INSERT and as IFC's occurrence. Attribute text is
/// not a field here: ATTRIBs are entities owned by this node, because a DXF
/// ATTRIB is a full text entity with its own placement, style and flags, and a
/// string map could not reconstruct one. That ownership also places attribute
/// text in the per-instance draw pass, where it belongs.
final class InstanceNode extends Node {
  final Handle definition;
  final Handle layer;

  const InstanceNode({
    required super.handle,
    required super.parent,
    required super.transform,
    required this.definition,
    required this.layer,
    super.visible = true,
  });

  InstanceNode copyWith({
    Handle? handle,
    Handle? parent,
    Transform2? transform,
    bool? visible,
    Handle? definition,
    Handle? layer,
  }) =>
      InstanceNode(
        handle: handle ?? this.handle,
        parent: parent ?? this.parent,
        transform: transform ?? this.transform,
        visible: visible ?? this.visible,
        definition: definition ?? this.definition,
        layer: layer ?? this.layer,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'instance',
        'handle': handle.toJson(),
        'parent': parent.toJson(),
        'transform': transform.toJson(),
        'visible': visible,
        'definition': definition.toJson(),
        'layer': layer.toJson(),
      };

  static InstanceNode fromJson(Map<String, Object?> json) => InstanceNode(
        handle: Handle.fromJson(json['handle']),
        parent: Handle.fromJson(json['parent']),
        transform: Transform2.fromJson(json['transform']),
        visible: json['visible']! as bool,
        definition: Handle.fromJson(json['definition']),
        layer: Handle.fromJson(json['layer']),
      );

  @override
  bool operator ==(Object other) =>
      other is InstanceNode &&
      other.handle == handle &&
      other.parent == parent &&
      other.transform.equals(transform, const Tolerance(linear: 0, angular: 0)) &&
      other.visible == visible &&
      other.definition == definition &&
      other.layer == layer;

  @override
  int get hashCode =>
      Object.hash(handle, parent, visible, definition, layer);

  @override
  String toString() => 'InstanceNode(${handle.toHex()} of ${definition.toHex()})';
}

/// A reusable prototype subtree — DXF BLOCK, IFC type object.
///
/// Not a [Node]: a prototype is not placed, so it has no parent and no
/// transform. [basePoint] is DXF's block base point; insertion alignment is
/// wrong without it.
@immutable
final class Definition {
  final Handle handle;
  final String name;
  final Vector2 basePoint;
  final List<Handle> children;

  /// True when this block names an external drawing. Xref resolution is a
  /// non-goal: the record and its inserts are preserved so the reference
  /// survives a round-trip, and nothing tries to load the file.
  final bool isXref;
  final String xrefPath;

  Definition({
    required this.handle,
    required this.name,
    required Vector2 basePoint,
    required this.children,
    this.isXref = false,
    this.xrefPath = '',
  }) : basePoint = basePoint.clone();

  Definition copyWith({
    Handle? handle,
    String? name,
    Vector2? basePoint,
    List<Handle>? children,
    bool? isXref,
    String? xrefPath,
  }) =>
      Definition(
        handle: handle ?? this.handle,
        name: name ?? this.name,
        basePoint: basePoint ?? this.basePoint,
        children: children ?? this.children,
        isXref: isXref ?? this.isXref,
        xrefPath: xrefPath ?? this.xrefPath,
      );

  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'basePoint': [basePoint.x, basePoint.y],
        'children': [for (final c in children) c.toJson()],
        'isXref': isXref,
        'xrefPath': xrefPath,
      };

  static Definition fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('Definition expects an object: $json');
    }
    final base = json['basePoint']! as List;
    return Definition(
      handle: Handle.fromJson(json['handle']),
      name: json['name']! as String,
      basePoint:
          Vector2((base[0] as num).toDouble(), (base[1] as num).toDouble()),
      children: [for (final c in json['children']! as List) Handle.fromJson(c)],
      isXref: json['isXref']! as bool,
      xrefPath: json['xrefPath']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Definition &&
      other.handle == handle &&
      other.name == name &&
      other.basePoint == basePoint &&
      other.isXref == isXref &&
      other.xrefPath == xrefPath &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
      handle, name, basePoint.x, basePoint.y, isXref, xrefPath,
      Object.hashAll(children));

  @override
  String toString() => 'Definition(${handle.toHex()} "$name")';
}
```

The node `operator ==` uses `Transform2.equals` with a zero tolerance. That is
exact comparison written explicitly rather than `==` on doubles: the prohibition
exists to stop *accidental* exact comparison, and equality of a stored record is
the one place it is intended.

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/node.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): immutable Node, GroupNode, InstanceNode and Definition"
```

---

### Task 13: DocumentTree and cycle detection

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/tree.dart`
- Create: `packages/jet_cad_2d/test/document/tree_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Node`, `GroupNode`, `InstanceNode`, `Definition`, `Transform2`, `Handle`, `Diagnostic`.
- Produces:
  - `class DocumentTree` — `Handle get root`, `Node? operator [](Handle)`, `Definition? definition(Handle)`, `Iterable<Node> get nodes`, `Iterable<Definition> get definitions`, `void addNode(Node)`, `void replaceNode(Node)`, `void removeNode(Handle)`, `void addDefinition(Definition)`, `void replaceDefinition(Definition)`, `void removeDefinition(Handle)`, `List<Handle> ancestorsOf(Handle)`, `Transform2 accumulatedTransform(Handle)`, `bool definitionReaches(Handle from, Handle target)`, `bool wouldCreateCycle({required Handle ownerDefinition, required Handle referencedDefinition})`, `List<Diagnostic> repairCycles()`, `void clear()`.
  - `class CycleDetectedError implements Exception`.

**`accumulatedTransform` composes upward until it reaches the root or a definition**, and it composes in `Float64`. "World" is not a meaningful word for a node inside a definition — a prototype has no world position — so the method is named for what it actually does: the transform from the enclosing space (the root, or the definition) down to the node.

The cycle check lives in `addNode`/`replaceNode` rather than in each command, so *no* command can close a cycle by forgetting to ask.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/tree_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

const tol = Tolerance.standard;

DocumentTree emptyTree() => DocumentTree(
      rootNode: GroupNode(
        handle: const Handle(100),
        parent: Handle.none,
        transform: Transform2.identity(),
        children: const [],
      ),
    );

Definition definitionWith(int handle, List<Handle> children) => Definition(
      handle: Handle(handle),
      name: 'D$handle',
      basePoint: Vector2.zero(),
      children: children,
    );

InstanceNode instanceIn(int handle, int parent, int definition) => InstanceNode(
      handle: Handle(handle),
      parent: Handle(parent),
      transform: Transform2.identity(),
      definition: Handle(definition),
      layer: ReservedHandles.layerZero,
    );

void main() {
  group('storage', () {
    test('root exists and is addressable', () {
      final tree = emptyTree();
      expect(tree.root, const Handle(100));
      expect(tree[tree.root], isA<GroupNode>());
    });

    test('nodes iterate in ascending handle order', () {
      final tree = emptyTree()
        ..addNode(instanceIn(30, 100, 200))
        ..addNode(instanceIn(10, 100, 200))
        ..addNode(instanceIn(20, 100, 200));
      tree.addDefinition(definitionWith(200, const []));
      expect([for (final n in tree.nodes) n.handle.value], [10, 20, 30, 100]);
    });

    test('replaceNode swaps the node and removeNode drops it', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 100, 200));
      tree.replaceNode(instanceIn(10, 100, 200).copyWith(visible: false));
      expect(tree[const Handle(10)]!.visible, isFalse);
      tree.removeNode(const Handle(10));
      expect(tree[const Handle(10)], isNull);
    });
  });

  group('accumulatedTransform', () {
    test('composes ancestor transforms in order', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(GroupNode(
        handle: const Handle(10),
        parent: const Handle(100),
        transform: Transform2.translation(10, 0),
        children: const [Handle(11)],
      ));
      tree.addNode(InstanceNode(
        handle: const Handle(11),
        parent: const Handle(10),
        transform: Transform2.scale(2, 2),
        definition: const Handle(200),
        layer: ReservedHandles.layerZero,
      ));
      final composed = tree.accumulatedTransform(const Handle(11));
      // Scale first, then the parent's translation.
      expect(tol.eqPoint(composed.transformPoint(Vector2(1, 0)), Vector2(12, 0)),
          isTrue);
    });

    test('stays exact at site-plan magnitudes', () {
      // The composition is Float64 all the way; only the renderer's residual
      // matrix is ever float32.
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(GroupNode(
        handle: const Handle(10),
        parent: const Handle(100),
        transform: Transform2.translation(4.5e6, -3.2e6),
        children: const [Handle(11)],
      ));
      tree.addNode(instanceIn(11, 10, 200));
      final p = tree
          .accumulatedTransform(const Handle(11))
          .transformPoint(Vector2(0.125, 0.125));
      expect(p.x, 4.5e6 + 0.125);
      expect(p.y, -3.2e6 + 0.125);
    });

    test('stops at a definition, because a prototype has no world position', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(11)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(InstanceNode(
        handle: const Handle(11),
        parent: const Handle(200), // owned by a definition, not the root
        transform: Transform2.translation(7, 0),
        definition: const Handle(201),
        layer: ReservedHandles.layerZero,
      ));
      final composed = tree.accumulatedTransform(const Handle(11));
      expect(tol.eqPoint(composed.transformPoint(Vector2.zero()), Vector2(7, 0)),
          isTrue);
    });

    test('ancestorsOf lists nearest first and excludes the node itself', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(GroupNode(
        handle: const Handle(10),
        parent: const Handle(100),
        transform: Transform2.identity(),
        children: const [Handle(11)],
      ));
      tree.addNode(instanceIn(11, 10, 200));
      expect(tree.ancestorsOf(const Handle(11)),
          [const Handle(10), const Handle(100)]);
    });
  });

  group('cycle detection', () {
    test('definitionReaches finds a direct and a transitive reference', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const [Handle(22)]));
      tree.addDefinition(definitionWith(202, const []));
      tree.addNode(instanceIn(21, 200, 201));
      tree.addNode(instanceIn(22, 201, 202));
      expect(tree.definitionReaches(const Handle(200), const Handle(201)), isTrue);
      expect(tree.definitionReaches(const Handle(200), const Handle(202)), isTrue);
      expect(tree.definitionReaches(const Handle(202), const Handle(200)), isFalse);
    });

    test('finds a reference nested inside a group within a definition', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(GroupNode(
        handle: const Handle(21),
        parent: const Handle(200),
        transform: Transform2.identity(),
        children: const [Handle(22)],
      ));
      tree.addNode(instanceIn(22, 21, 201));
      expect(tree.definitionReaches(const Handle(200), const Handle(201)), isTrue);
    });

    test('rejects a self-reference and leaves the tree unmutated', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      expect(() => tree.addNode(instanceIn(21, 200, 200)),
          throwsA(isA<CycleDetectedError>()));
      expect(tree[const Handle(21)], isNull);
    });

    test('rejects a mutual reference and leaves the tree unmutated', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(instanceIn(21, 200, 201)); // 200 -> 201, fine
      expect(() => tree.addNode(instanceIn(22, 201, 200)),
          throwsA(isA<CycleDetectedError>()));
      expect(tree[const Handle(22)], isNull);
      expect(tree.definitionReaches(const Handle(201), const Handle(200)), isFalse);
    });

    test('wouldCreateCycle answers without mutating', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(instanceIn(21, 200, 201));
      expect(
          tree.wouldCreateCycle(
              ownerDefinition: const Handle(201),
              referencedDefinition: const Handle(200)),
          isTrue);
      expect(
          tree.wouldCreateCycle(
              ownerDefinition: const Handle(200),
              referencedDefinition: const Handle(201)),
          isFalse);
    });

    test('repairCycles drops the offending instance and reports it', () {
      // Import must not fail the whole file over one bad reference: it
      // diagnoses and recovers.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const [Handle(22)]));
      tree.addNodeUnchecked(instanceIn(21, 200, 201));
      tree.addNodeUnchecked(instanceIn(22, 201, 200)); // closes the cycle

      final diagnostics = tree.repairCycles();
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.code, 'tree.cycle_dropped');
      expect(diagnostics.single.severity, DiagnosticSeverity.warning);
      expect(diagnostics.single.handles, contains(const Handle(22)));
      expect(tree[const Handle(22)], isNull);
      expect(tree.definition(const Handle(201))!.children, isEmpty);
      expect(tree.repairCycles(), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/tree_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'DocumentTree'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/tree.dart`:

```dart
import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../geometry/transform2.dart';
import 'node.dart';

class CycleDetectedError implements Exception {
  final Handle ownerDefinition;
  final Handle referencedDefinition;

  const CycleDetectedError(this.ownerDefinition, this.referencedDefinition);

  @override
  String toString() =>
      'CycleDetectedError: definition ${ownerDefinition.toHex()} cannot '
      'contain an instance of ${referencedDefinition.toHex()}';
}

/// The scene tree: container nodes plus the definitions they instance.
///
/// Leaf entities are not here — they live in the entity store and reference
/// their owner by handle.
class DocumentTree {
  final Map<Handle, Node> _nodes = {};
  final Map<Handle, Definition> _definitions = {};
  Handle _root;

  DocumentTree({required GroupNode rootNode}) : _root = rootNode.handle {
    _nodes[rootNode.handle] = rootNode;
  }

  Handle get root => _root;

  Node? operator [](Handle handle) => _nodes[handle];

  Definition? definition(Handle handle) => _definitions[handle];

  /// Ascending handle order — serialization walks this, and byte-identical
  /// output cannot depend on hash order.
  Iterable<Node> get nodes {
    final handles = _nodes.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final h in handles) _nodes[h]!];
  }

  Iterable<Definition> get definitions {
    final handles = _definitions.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final h in handles) _definitions[h]!];
  }

  /// Adds a node, rejecting anything that would close a definition cycle.
  ///
  /// The check lives here rather than in each command so that no command can
  /// close a cycle by forgetting to ask. Nothing is mutated when it throws.
  void addNode(Node node) {
    _guardCycle(node);
    _nodes[node.handle] = node;
  }

  /// Adds without the cycle check. Only an importer should use this, and only
  /// when it intends to call [repairCycles] afterwards — a file may legitimately
  /// contain a cycle that has to be diagnosed rather than rejected mid-parse.
  void addNodeUnchecked(Node node) => _nodes[node.handle] = node;

  void replaceNode(Node node) {
    _guardCycle(node);
    _nodes[node.handle] = node;
  }

  void removeNode(Handle handle) => _nodes.remove(handle);

  void addDefinition(Definition definition) =>
      _definitions[definition.handle] = definition;

  void replaceDefinition(Definition definition) =>
      _definitions[definition.handle] = definition;

  void removeDefinition(Handle handle) => _definitions.remove(handle);

  /// Ancestors of [handle], nearest first, excluding the node itself. Stops at
  /// the root or at a definition.
  List<Handle> ancestorsOf(Handle handle) {
    final chain = <Handle>[];
    var current = _nodes[handle]?.parent ?? Handle.none;
    while (!current.isNone && _nodes.containsKey(current)) {
      chain.add(current);
      current = _nodes[current]!.parent;
    }
    return chain;
  }

  /// The transform from the enclosing space down to [handle], composed in
  /// `Float64`.
  ///
  /// The enclosing space is the root for a placed node, or the definition for a
  /// node inside a prototype — "world" would be the wrong word, since a
  /// prototype has no world position. The walk stops at a definition handle
  /// because a definition carries no transform of its own.
  Transform2 accumulatedTransform(Handle handle) {
    final node = _nodes[handle];
    if (node == null) return Transform2.identity();
    final chain = <Transform2>[node.transform];
    for (final ancestor in ancestorsOf(handle)) {
      chain.add(_nodes[ancestor]!.transform);
    }
    var composed = Transform2.identity();
    // Outermost first, so the node's own transform is applied last.
    for (final t in chain.reversed) {
      composed = composed.multiply(t);
    }
    return composed;
  }

  /// Whether the subtree of definition [from] contains, at any depth, an
  /// instance of [target].
  bool definitionReaches(Handle from, Handle target) {
    final visited = <Handle>{};
    // walkNode is declared FIRST: Dart does not hoist local function
    // declarations, so referencing walkNode from walkDefinition before its
    // declaration is a compile error ("Local variable can't be referenced
    // before it is declared"). The mutual recursion is closed by passing the
    // definition-walker in as `into` rather than calling it by name.
    bool walkNode(Handle nodeHandle, bool Function(Handle) into) {
      final node = _nodes[nodeHandle];
      switch (node) {
        case InstanceNode(:final definition):
          if (definition == target) return true;
          return into(definition);
        case GroupNode(:final children):
          for (final child in children) {
            if (walkNode(child, into)) return true;
          }
          return false;
        case null:
          return false; // an entity handle, not a node
      }
    }

    // `visited` makes an already-expanded definition terminate immediately.
    // Without it a legitimately shared but acyclic definition graph is
    // re-walked exponentially, and a cyclic one never terminates.
    bool walkDefinition(Handle definitionHandle) {
      if (!visited.add(definitionHandle)) return false;
      final def = _definitions[definitionHandle];
      if (def == null) return false;
      for (final child in def.children) {
        if (walkNode(child, walkDefinition)) return true;
      }
      return false;
    }

    return walkDefinition(from);
  }

  bool wouldCreateCycle({
    required Handle ownerDefinition,
    required Handle referencedDefinition,
  }) =>
      ownerDefinition == referencedDefinition ||
      definitionReaches(referencedDefinition, ownerDefinition);

  /// Breaks every definition cycle by dropping the instance that closes it.
  ///
  /// Import calls this: a malformed file must not fail wholesale over one bad
  /// reference. Each drop is reported.
  List<Diagnostic> repairCycles() {
    final diagnostics = <Diagnostic>[];
    // Find the BACK edge — the reference that closes the cycle — not the first
    // edge encountered walking definitions in handle order. Scanning in handle
    // order drops the forward edge instead, which removes a legitimate
    // reference and leaves the offending one in place.
    //
    // Each pass drops exactly one instance and then rescans from scratch, so
    // the scan never walks a collection it is mutating. Every pass removes a
    // node, so the loop is bounded by the node count and converges; on a clean
    // tree the first scan finds nothing and the result is empty.
    for (var edge = _findBackEdge(); edge != null; edge = _findBackEdge()) {
      final (:instance, :owner) = edge;
      _dropInstance(instance);
      diagnostics.add(Diagnostic(
        severity: DiagnosticSeverity.warning,
        code: 'tree.cycle_dropped',
        message: 'Dropped instance ${instance.handle.toHex()}: definition '
            '${owner.toHex()} cannot contain '
            '${instance.definition.toHex()}.',
        handles: [instance.handle, owner, instance.definition],
      ));
    }
    return diagnostics;
  }

  /// Returns the instance whose reference closes a definition cycle, or null.
  ///
  /// Implemented as a white/grey/black depth-first search over the definition
  /// graph: an edge into a *grey* definition is a back edge, and the instance
  /// carrying it is the one to drop. See the shipped implementation in
  /// `lib/src/document/tree.dart` for the full walk.
  ({InstanceNode instance, Handle owner})? _findBackEdge() { /* see source */ }

  void clear() {
    _nodes.clear();
    _definitions.clear();
  }

  /// The definition that ultimately owns [handle], or [Handle.none] if the node
  /// hangs off the root instead.
  /// Walks up from [start] — a node's declared PARENT, never its own handle.
  /// On [addNode] the node is not in the tree yet, so starting from its handle
  /// finds nothing and the caller's guard silently passes.
  Handle _enclosingDefinitionAbove(Handle start) {
    var current = start;
    while (!current.isNone) {
      if (_definitions.containsKey(current)) return current;
      final parent = _nodes[current];
      if (parent == null) return Handle.none;
      current = parent.parent;
    }
    return Handle.none;
  }

  void _guardCycle(Node node) {
    if (node is! InstanceNode) return;
    // Walk up from the node's declared PARENT, not from the node's own handle:
    // on addNode the node is not in the tree yet, so a lookup keyed on its
    // handle finds nothing and the guard silently skips the check for every
    // instance nested in a group inside a definition.
    final owner = _enclosingDefinitionAbove(node.parent);
    if (owner.isNone) return; // placed under the root: never a cycle
    if (owner == node.definition || definitionReaches(node.definition, owner)) {
      throw CycleDetectedError(owner, node.definition);
    }
  }

  void _dropInstance(InstanceNode node, Handle owner) {
    _nodes.remove(node.handle);
    final parent = _nodes[node.parent];
    if (parent is GroupNode) {
      _nodes[parent.handle] = parent.copyWith(
        children: [...parent.children]..remove(node.handle),
      );
      return;
    }
    final definition = _definitions[node.parent];
    if (definition != null) {
      _definitions[definition.handle] = definition.copyWith(
        children: [...definition.children]..remove(node.handle),
      );
    }
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/tree.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): DocumentTree with definition cycle detection and repair"
```

---

### Task 14: Components, registry, and OriginComponent

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/component.dart`
- Create: `packages/jet_cad_2d/lib/src/document/origin_component.dart`
- Create: `packages/jet_cad_2d/test/document/component_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle`.
- Produces:
  - `abstract class Component` — `String get typeId`, `Map<String, Object?> toJson()`.
  - `typedef ComponentFactory<T extends Component> = T Function(Map<String, Object?> json);`
  - `class ComponentStore<T extends Component>` — `T? operator [](Handle)`, `void set(Handle, T)`, `void remove(Handle)`, `Iterable<Handle> get handles` (ascending), `int get length`.
  - `class ComponentRegistry` — `void register<T extends Component>(String typeId, ComponentFactory<T> factory, {bool internal})`, `void attach<T extends Component>(Handle, T)`, `T? get<T extends Component>(Handle)`, `void detach<T extends Component>(Handle)`, `Iterable<Handle> withComponent<T extends Component>()`, `bool isInternal(String typeId)`, `void attachUnknown(Handle, Map<String, Object?>)`, `List<Map<String, Object?>> unknownOf(Handle)`, `Map<String, Object?> toJson()`, `void loadJson(Map<String, Object?>)`, `void clear()`.
  - `class UnregisteredComponentError implements Exception`.
  - `enum SourceKind { native, dxf, ifc }` and `class OriginComponent implements Component`.

**Contract for every component:** immutable, value-equal, and `toJson` emits keys in a fixed order. Value equality is what makes value-diff undo able to compare and restore component state; fixed key order is what keeps serialization byte-deterministic.

**Why stores are sparse and type-keyed** rather than a map on each entity: entity records stay lean at scale, and the runtime's core query — every handle carrying a given component — costs the component count, not the entity count.

Dart generics are reified, so `withComponent<T>()` keys the store by `Type`, while `typeId` stays the serialization name. Both directions of that mapping live in the registry.

`SourceKind` is one of only two places the engine may name a foreign format; the other is `GroupNode.exportAsDxfGroup`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/component_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A domain component defined by the *test*, not by the engine — the engine
/// deliberately defines no domain types.
class SeatingComponent implements Component {
  final int number;
  final int capacity;

  const SeatingComponent({required this.number, required this.capacity});

  @override
  String get typeId => 'test.seating';

  @override
  Map<String, Object?> toJson() => {'number': number, 'capacity': capacity};

  static SeatingComponent fromJson(Map<String, Object?> json) =>
      SeatingComponent(
        number: json['number']! as int,
        capacity: json['capacity']! as int,
      );

  @override
  bool operator ==(Object other) =>
      other is SeatingComponent &&
      other.number == number &&
      other.capacity == capacity;

  @override
  int get hashCode => Object.hash(number, capacity);
}

ComponentRegistry registryWithSeating() => ComponentRegistry()
  ..register<SeatingComponent>('test.seating', SeatingComponent.fromJson);

void main() {
  test('attaches, reads back, and detaches', () {
    final registry = registryWithSeating();
    registry.attach(const Handle(10), const SeatingComponent(number: 4, capacity: 6));
    expect(registry.get<SeatingComponent>(const Handle(10)),
        const SeatingComponent(number: 4, capacity: 6));
    registry.detach<SeatingComponent>(const Handle(10));
    expect(registry.get<SeatingComponent>(const Handle(10)), isNull);
  });

  test('attaching an unregistered type throws instead of silently dropping', () {
    expect(
      () => ComponentRegistry()
          .attach(const Handle(10), const SeatingComponent(number: 1, capacity: 2)),
      throwsA(isA<UnregisteredComponentError>()),
    );
  });

  test('withComponent returns ascending handles and only carriers', () {
    // The runtime's core query. Ascending because query results must be stably
    // ordered; sized by component count, not entity count.
    final registry = registryWithSeating();
    for (final h in [30, 10, 20]) {
      registry.attach(Handle(h), SeatingComponent(number: h, capacity: 4));
    }
    expect([for (final h in registry.withComponent<SeatingComponent>()) h.value],
        [10, 20, 30]);
  });

  test('attaches to nodes and entities alike — one handle space', () {
    final registry = registryWithSeating();
    registry.attach(const Handle(10), const SeatingComponent(number: 1, capacity: 2));
    registry.attach(const Handle(9999), const SeatingComponent(number: 2, capacity: 2));
    expect(registry.withComponent<SeatingComponent>(), hasLength(2));
  });

  test('an unknown typeId is preserved verbatim through a round-trip', () {
    // No layer discards data it does not understand. A plugin's component type
    // must survive an app build that has never heard of it.
    final source = ComponentRegistry()
      ..attachUnknown(const Handle(10), {
        'typeId': 'acme.plumbing',
        'diameter': 32,
        'nested': {'a': 1},
      });
    final json = source.toJson();

    final loaded = ComponentRegistry()..loadJson(json);
    final preserved = loaded.unknownOf(const Handle(10));
    expect(preserved, hasLength(1));
    expect(preserved.single['typeId'], 'acme.plumbing');
    expect(preserved.single['diameter'], 32);
    expect((preserved.single['nested']! as Map)['a'], 1);
    expect(loaded.toJson(), json);
  });

  test('a registered component round-trips through json', () {
    final source = registryWithSeating()
      ..attach(const Handle(10), const SeatingComponent(number: 4, capacity: 6));
    final loaded = registryWithSeating()..loadJson(source.toJson());
    expect(loaded.get<SeatingComponent>(const Handle(10)),
        const SeatingComponent(number: 4, capacity: 6));
  });

  test('a registered type read by a registry that lacks it is still preserved', () {
    final source = registryWithSeating()
      ..attach(const Handle(10), const SeatingComponent(number: 4, capacity: 6));
    final json = source.toJson();

    final ignorant = ComponentRegistry()..loadJson(json);
    expect(ignorant.unknownOf(const Handle(10)), hasLength(1));
    expect(ignorant.toJson(), json, reason: 'preserved byte-for-byte');
  });

  test('toJson orders type ids and handles deterministically', () {
    final registry = registryWithSeating();
    for (final h in [300, 100, 200]) {
      registry.attach(Handle(h), SeatingComponent(number: h, capacity: 1));
    }
    registry.attachUnknown(const Handle(50), {'typeId': 'aaa.first'});
    final json = registry.toJson();
    expect(json.keys.toList(), ['aaa.first', 'test.seating']);
    expect((json['test.seating']! as Map).keys.toList(), ['100', '200', '300']);
  });

  group('OriginComponent', () {
    test('records the source format and original identifier', () {
      final registry = ComponentRegistry()..registerBuiltIns();
      registry.attach(const Handle(10),
          const OriginComponent(source: SourceKind.dxf, id: '2A'));
      expect(registry.get<OriginComponent>(const Handle(10))!.id, '2A');
    });

    test('is internal, so it is never written as foreign extended data', () {
      final registry = ComponentRegistry()..registerBuiltIns();
      expect(registry.isInternal(OriginComponent.componentTypeId), isTrue);
      expect(registry.isInternal('test.seating'), isFalse);
    });

    test('round-trips through the document format', () {
      final source = ComponentRegistry()..registerBuiltIns();
      source.attach(const Handle(10),
          const OriginComponent(source: SourceKind.ifc, id: '3xY7\$0abcd'));
      final loaded = ComponentRegistry()..registerBuiltIns();
      loaded.loadJson(source.toJson());
      final origin = loaded.get<OriginComponent>(const Handle(10))!;
      expect(origin.source, SourceKind.ifc);
      expect(origin.id, '3xY7\$0abcd');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/component_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'Component'`.

- [ ] **Step 3: Implement the component machinery**

Create `packages/jet_cad_2d/lib/src/document/component.dart`:

```dart
import '../core/handle.dart';
import 'origin_component.dart';

/// Extension data attached to any handle.
///
/// Contract for every implementation: **immutable, value-equal, and [toJson]
/// emits keys in a fixed order.** Value equality lets value-diff undo compare
/// and restore component state; fixed key order keeps serialization
/// byte-deterministic.
///
/// Data only, never behavior. Behavior lives in application-side systems, so
/// that the document stays serializable, deterministic and undoable.
abstract class Component {
  String get typeId;
  Map<String, Object?> toJson();
}

typedef ComponentFactory<T extends Component> = T Function(
    Map<String, Object?> json);

class UnregisteredComponentError implements Exception {
  final Type type;
  const UnregisteredComponentError(this.type);

  @override
  String toString() =>
      'UnregisteredComponentError($type): call registry.register first';
}

/// Sparse storage for one component type.
class ComponentStore<T extends Component> {
  final Map<Handle, T> _byHandle = {};

  int get length => _byHandle.length;

  T? operator [](Handle handle) => _byHandle[handle];

  void set(Handle handle, T component) => _byHandle[handle] = component;

  void remove(Handle handle) => _byHandle.remove(handle);

  /// Ascending, so query results are stably ordered.
  Iterable<Handle> get handles {
    final list = _byHandle.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  void clear() => _byHandle.clear();
}

/// All component stores for one document, plus the type-id mapping.
///
/// Stores are sparse and keyed by `Type` rather than living on each entity:
/// entity records stay lean at scale, and "every handle carrying component X"
/// costs the component count rather than the entity count.
class ComponentRegistry {
  final Map<Type, ComponentStore<Component>> _stores = {};
  final Map<Type, String> _typeIdOf = {};
  final Map<String, ComponentFactory<Component>> _factories = {};
  final Map<String, Type> _typeOf = {};
  final Set<String> _internal = {};

  /// Preserved verbatim: types this build has never heard of.
  final Map<Handle, List<Map<String, Object?>>> _unknown = {};

  void register<T extends Component>(
    String typeId,
    ComponentFactory<T> factory, {
    bool internal = false,
  }) {
    _stores[T] = ComponentStore<Component>();
    _typeIdOf[T] = typeId;
    _typeOf[typeId] = T;
    _factories[typeId] = factory;
    if (internal) _internal.add(typeId);
  }

  /// Registers the component types the engine owns.
  void registerBuiltIns() {
    register<OriginComponent>(
      OriginComponent.componentTypeId,
      OriginComponent.fromJson,
      internal: true,
    );
  }

  /// True when a component type must never be written to a foreign format as
  /// extended data.
  bool isInternal(String typeId) => _internal.contains(typeId);

  void attach<T extends Component>(Handle handle, T component) {
    final store = _stores[T];
    if (store == null) throw UnregisteredComponentError(T);
    store.set(handle, component);
  }

  T? get<T extends Component>(Handle handle) => _stores[T]?[handle] as T?;

  void detach<T extends Component>(Handle handle) => _stores[T]?.remove(handle);

  Iterable<Handle> withComponent<T extends Component>() =>
      _stores[T]?.handles ?? const <Handle>[];

  /// Records a component whose `typeId` this build does not know. The payload
  /// is stored exactly as read and written back unchanged.
  void attachUnknown(Handle handle, Map<String, Object?> json) =>
      _unknown.putIfAbsent(handle, () => []).add(json);

  List<Map<String, Object?>> unknownOf(Handle handle) =>
      _unknown[handle] ?? const [];

  /// Shape: `{ typeId: { handleDecimal: payload } }`.
  ///
  /// Type ids sort lexicographically and handles sort numerically, so the same
  /// registry always produces the same bytes.
  Map<String, Object?> toJson() {
    final byTypeId = <String, Map<String, Object?>>{};

    for (final entry in _stores.entries) {
      final typeId = _typeIdOf[entry.key]!;
      for (final handle in entry.value.handles) {
        (byTypeId[typeId] ??= {})[handle.value.toString()] =
            entry.value[handle]!.toJson();
      }
    }

    final unknownHandles = _unknown.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final handle in unknownHandles) {
      for (final payload in _unknown[handle]!) {
        final typeId = payload['typeId']! as String;
        // Strip typeId from the WRITTEN form: the enclosing map key already
        // names the type, and the registered branch's toJson() never embeds
        // it. Writing it here makes a round-trip through a registry that
        // lacks the type non-byte-identical — the second emission carries a
        // typeId the first did not. `unknownOf` keeps the stored copy intact.
        final withoutTypeId = {
          for (final e in payload.entries)
            if (e.key != 'typeId') e.key: e.value,
        };
        (byTypeId[typeId] ??= {})[handle.value.toString()] = withoutTypeId;
      }
    }

    final sortedTypeIds = byTypeId.keys.toList()..sort();
    return {
      for (final typeId in sortedTypeIds)
        typeId: _sortedByHandle(byTypeId[typeId]!),
    };
  }

  static Map<String, Object?> _sortedByHandle(Map<String, Object?> raw) {
    final keys = raw.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return {for (final k in keys) k: raw[k]};
  }

  void loadJson(Map<String, Object?> json) {
    clear();
    for (final typeId in json.keys.toList()..sort()) {
      final perHandle = (json[typeId]! as Map).cast<String, Object?>();
      final handleKeys = perHandle.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      final factory = _factories[typeId];
      for (final key in handleKeys) {
        final handle = Handle.checked(int.parse(key));
        final payload = (perHandle[key]! as Map).cast<String, Object?>();
        if (factory == null) {
          // Unknown to this build: keep it exactly as read, including the
          // typeId, so it can be written back untouched.
          attachUnknown(handle, {'typeId': typeId, ...payload});
          continue;
        }
        _stores[_typeOf[typeId]!]!.set(handle, factory(payload));
      }
    }
  }

  void clear() {
    for (final store in _stores.values) {
      store.clear();
    }
    _unknown.clear();
  }
}
```

> The unknown payload keeps its `typeId` key so a preserved component can be
> written back with no extra bookkeeping. A registered component's payload does
> *not* carry `typeId`, because the enclosing map key already names it — which
> is why the unknown branch re-inserts it on load.

- [ ] **Step 4: Implement OriginComponent**

Create `packages/jet_cad_2d/lib/src/document/origin_component.dart`:

```dart
import 'component.dart';

/// Where a handle's identity came from.
///
/// One of only two places the engine may name a foreign format; the other is
/// `GroupNode.exportAsDxfGroup`.
enum SourceKind { native, dxf, ifc }

/// The original identifier a record carried in the file it was imported from.
///
/// Renumbering handles on import silently breaks references inside preserved
/// raw data, so the original is kept rather than discarded. Export reuses it
/// when present and mints a new identifier otherwise, which is what makes
/// merging two files safe.
///
/// Registered as **internal**: it is engine bookkeeping and is never written to
/// a foreign format as extended data.
class OriginComponent implements Component {
  static const String componentTypeId = 'jetcad.origin';

  final SourceKind source;

  /// A DXF handle in hex, or an IFC GlobalId.
  final String id;

  const OriginComponent({required this.source, required this.id});

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'source': source.name, 'id': id};

  static OriginComponent fromJson(Map<String, Object?> json) => OriginComponent(
        source: SourceKind.values.byName(json['source']! as String),
        id: json['id']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is OriginComponent && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);

  @override
  String toString() => 'OriginComponent(${source.name}:$id)';
}
```

- [ ] **Step 5: Export both from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/component.dart';
export 'src/document/origin_component.dart';
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): component registry with unknown-type preservation"
```

---

### Task 15: Commands, capabilities, change stream, undo

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/doc_change.dart`
- Create: `packages/jet_cad_2d/lib/src/document/command.dart`
- Create: `packages/jet_cad_2d/lib/src/document/undo.dart`
- Create: `packages/jet_cad_2d/test/document/command_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle`, `EntityStore`, `GeometryStore`, `DocumentTree`, `DocumentTables`, `ComponentRegistry`, `HandleSeed`.
- Produces:
  - `sealed class DocChange` with `CommandApplied`, `CommandUndone`, `CommandRedone`, `DocumentLoaded`, `DocumentPurged` — each carrying `Set<Handle> get touched` where meaningful.
  - `enum Capability { transform, components, geometry, structure }`
  - `class DraftPermissions` — four bools, `bool allows(Capability)`, `static const all`, `static const runtime`, `static const readOnly`.
  - `class PermissionDeniedError implements Exception`.
  - `abstract class CommandTarget` — `EntityStore get entities`, `GeometryStore get geometry`, `DocumentTree get tree`, `DocumentTables get tables`, `ComponentRegistry get components`, `HandleSeed get handleSeed`, `void invalidateDerived()`.
  - `class CommandResult` — `DraftCommand inverse`, `Set<Handle> touched`.
  - `abstract class DraftCommand` — `Capability get capability`, `String get label`, `CommandResult apply(CommandTarget)`.
  - `class UndoStack` — `int limit`, `void push(DraftCommand)`, `bool get canUndo`, `bool get canRedo`, `DraftCommand takeUndo()`, `DraftCommand takeRedo()`, `void pushRedo(DraftCommand)`, `void clear()`, `int get undoDepth`.
  - `class CommandDispatcher` — `Stream<DocChange> get changes`, `DraftPermissions permissions`, `void execute(DraftCommand)`, `void undo()`, `void redo()`, `bool get canUndo/canRedo`, `void notifyLoaded()`, `void clearHistory()`, `Future<void> dispose()`.

**Why a `CommandTarget` interface rather than `DraftDocument` directly:** commands land before the document does, and the seam lets this task be tested against a small fake. It also states exactly what a command is allowed to touch.

**Every command declares its capability, and the dispatcher checks it in one place.** That is what makes "a point-of-sale runtime may move a table and edit its properties but may not draw walls" a configuration rather than a code path.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/command_test.dart`:

```dart
import 'dart:async';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// Minimal target: the stores a command may touch, and nothing else.
class FakeTarget implements CommandTarget {
  @override
  final EntityStore entities = EntityStore();
  @override
  final GeometryStore geometry = GeometryStore();
  @override
  final DocumentTables tables = DocumentTables.standard();
  @override
  final ComponentRegistry components = ComponentRegistry()..registerBuiltIns();
  @override
  final HandleSeed handleSeed = HandleSeed(ReservedHandles.firstFree);
  @override
  late final DocumentTree tree = DocumentTree(
    rootNode: GroupNode(
      handle: handleSeed.next(),
      parent: Handle.none,
      transform: Transform2.identity(),
      children: const [],
    ),
  );

  int invalidations = 0;
  @override
  void invalidateDerived() => invalidations++;
}

/// A command that only records that it ran, so the dispatcher can be tested
/// without depending on any concrete command.
class CounterCommand extends DraftCommand {
  static int applied = 0;

  final Capability _capability;
  final Handle target;

  CounterCommand(this._capability, this.target);

  @override
  Capability get capability => _capability;

  @override
  String get label => 'counter';

  @override
  CommandResult apply(CommandTarget t) {
    applied++;
    t.invalidateDerived();
    return CommandResult(
      inverse: CounterCommand(_capability, target),
      touched: {target},
    );
  }
}

class ThrowingCommand extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'throwing';
  @override
  CommandResult apply(CommandTarget t) => throw StateError('boom');
}

void main() {
  setUp(() => CounterCommand.applied = 0);

  group('DraftPermissions', () {
    test('runtime allows transform and components, not geometry or structure', () {
      // Exactly the point-of-sale case: move a table, change its properties,
      // but never draw a wall or alter a block definition.
      const p = DraftPermissions.runtime;
      expect(p.allows(Capability.transform), isTrue);
      expect(p.allows(Capability.components), isTrue);
      expect(p.allows(Capability.geometry), isFalse);
      expect(p.allows(Capability.structure), isFalse);
    });

    test('all allows everything and readOnly allows nothing', () {
      for (final c in Capability.values) {
        expect(DraftPermissions.all.allows(c), isTrue);
        expect(DraftPermissions.readOnly.allows(c), isFalse);
      }
    });
  });

  group('CommandDispatcher', () {
    test('executes a permitted command and emits CommandApplied', () async {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(target: target);
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);

      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(42)));
      await Future<void>.delayed(Duration.zero);

      expect(CounterCommand.applied, 1);
      expect(events.single, isA<CommandApplied>());
      expect((events.single as CommandApplied).touched, {const Handle(42)});
      expect(target.invalidations, 1);
      unawaited(sub.cancel());
    });

    test('rejects a command the permissions forbid, without applying it', () {
      final target = FakeTarget();
      final dispatcher = CommandDispatcher(
        target: target,
        permissions: DraftPermissions.runtime,
      );
      expect(
        () => dispatcher
            .execute(CounterCommand(Capability.geometry, const Handle(1))),
        throwsA(isA<PermissionDeniedError>()),
      );
      expect(CounterCommand.applied, 0);
      expect(dispatcher.canUndo, isFalse);
    });

    test('a throwing command does not land on the undo stack', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      expect(() => dispatcher.execute(ThrowingCommand()), throwsStateError);
      expect(dispatcher.canUndo, isFalse);
    });

    test('undo and redo run the stored inverses and emit their events', () async {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);

      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      expect(dispatcher.canUndo, isTrue);
      expect(dispatcher.canRedo, isFalse);

      dispatcher.undo();
      expect(dispatcher.canUndo, isFalse);
      expect(dispatcher.canRedo, isTrue);

      dispatcher.redo();
      expect(dispatcher.canUndo, isTrue);
      expect(CounterCommand.applied, 3, reason: 'apply, undo, redo each ran');

      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.runtimeType).toList(),
          [CommandApplied, CommandUndone, CommandRedone]);
      unawaited(sub.cancel());
    });

    test('a new command clears the redo stack', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.undo();
      expect(dispatcher.canRedo, isTrue);
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(2)));
      expect(dispatcher.canRedo, isFalse);
    });

    test('undo respects permissions too', () {
      // Runtime undo must be able to reverse a runtime edit, and must not
      // become a back door to a forbidden one.
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.permissions = DraftPermissions.runtime;
      expect(dispatcher.undo, throwsA(isA<PermissionDeniedError>()));
    });

    test('the undo stack honours its depth limit', () {
      // Runtime may cap the depth; the mechanism is unchanged.
      final dispatcher = CommandDispatcher(target: FakeTarget(), undoLimit: 2);
      for (var i = 0; i < 5; i++) {
        dispatcher.execute(CounterCommand(Capability.geometry, Handle(i + 1)));
      }
      var undone = 0;
      while (dispatcher.canUndo) {
        dispatcher.undo();
        undone++;
      }
      expect(undone, 2);
    });

    test('clearHistory drops both stacks', () {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.clearHistory();
      expect(dispatcher.canUndo, isFalse);
      expect(dispatcher.canRedo, isFalse);
    });

    test('notifyLoaded emits DocumentLoaded and clears history', () async {
      final dispatcher = CommandDispatcher(target: FakeTarget());
      final events = <DocChange>[];
      final sub = dispatcher.changes.listen(events.add);
      dispatcher.execute(CounterCommand(Capability.geometry, const Handle(1)));
      dispatcher.notifyLoaded();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isA<DocumentLoaded>());
      expect(dispatcher.canUndo, isFalse);
      unawaited(sub.cancel());
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/command_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'CommandTarget'`.

- [ ] **Step 3: Implement DocChange**

Create `packages/jet_cad_2d/lib/src/document/doc_change.dart`:

```dart
import '../core/handle.dart';

/// Typed document events.
///
/// Selection is deliberately absent: selection is view state and belongs to the
/// widget layer's own controller, which is a `Stream` for the same reason this
/// is — both carry deltas rather than snapshots.
sealed class DocChange {
  const DocChange();

  /// Handles whose state changed. Empty when the whole document changed.
  Set<Handle> get touched => const {};
}

final class CommandApplied extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;
  const CommandApplied({required this.label, required this.touched});
}

final class CommandUndone extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;
  const CommandUndone({required this.label, required this.touched});
}

final class CommandRedone extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;
  const CommandRedone({required this.label, required this.touched});
}

/// The whole document was replaced.
final class DocumentLoaded extends DocChange {
  const DocumentLoaded();
}

/// Slots were compacted by an explicit purge. Every derived structure keyed by
/// a slot is invalid; the undo stack has been cleared.
final class DocumentPurged extends DocChange {
  const DocumentPurged();
}
```

- [ ] **Step 4: Implement commands and permissions**

Create `packages/jet_cad_2d/lib/src/document/command.dart`:

```dart
import 'package:meta/meta.dart';

import '../core/handle.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'component.dart';
import 'tables.dart';
import 'tree.dart';

/// What a command is allowed to change.
///
/// The split is only possible because leaves carry no transform: moving an
/// instance and editing geometry are already distinct operations.
enum Capability {
  /// Move or rotate an instance or group.
  transform,

  /// Edit component data.
  components,

  /// Change coordinates, add or remove entities.
  geometry,

  /// Change the tree, definitions, or groups.
  structure,
}

@immutable
class DraftPermissions {
  final bool transform;
  final bool components;
  final bool geometry;
  final bool structure;

  const DraftPermissions({
    required this.transform,
    required this.components,
    required this.geometry,
    required this.structure,
  });

  static const DraftPermissions all = DraftPermissions(
      transform: true, components: true, geometry: true, structure: true);

  /// A point-of-sale runtime: staff may move a table and change its
  /// properties, but cannot draw walls or alter a block definition.
  static const DraftPermissions runtime = DraftPermissions(
      transform: true, components: true, geometry: false, structure: false);

  static const DraftPermissions readOnly = DraftPermissions(
      transform: false, components: false, geometry: false, structure: false);

  bool allows(Capability capability) => switch (capability) {
        Capability.transform => transform,
        Capability.components => components,
        Capability.geometry => geometry,
        Capability.structure => structure,
      };
}

class PermissionDeniedError implements Exception {
  final Capability capability;
  final String label;
  const PermissionDeniedError(this.capability, this.label);

  @override
  String toString() =>
      'PermissionDeniedError: "$label" needs ${capability.name}';
}

/// Everything a command may touch — and nothing more.
abstract class CommandTarget {
  EntityStore get entities;
  GeometryStore get geometry;
  DocumentTree get tree;
  DocumentTables get tables;
  ComponentRegistry get components;
  HandleSeed get handleSeed;

  /// Marks derived state stale: working extents, cached world transforms, and
  /// any index built over the stores. Derived state is never persisted, so this
  /// is the only bookkeeping a mutation owes it.
  void invalidateDerived();
}

@immutable
class CommandResult {
  final DraftCommand inverse;
  final Set<Handle> touched;
  const CommandResult({required this.inverse, required this.touched});
}

/// A single reversible mutation.
///
/// Undo is a plain value diff — there is no kernel and therefore no snapshot,
/// which is why an inverse can be an ordinary command carrying a payload.
abstract class DraftCommand {
  Capability get capability;

  /// Short, human-readable, and used in [DocChange] events.
  String get label;

  /// Applies the change and returns its inverse plus the handles it touched.
  /// Must either complete fully or leave the target unmutated.
  CommandResult apply(CommandTarget target);
}
```

- [ ] **Step 5: Implement the undo stack and dispatcher**

Create `packages/jet_cad_2d/lib/src/document/undo.dart`:

```dart
import 'dart:async';

import 'command.dart';
import 'doc_change.dart';

/// Bounded undo and redo stacks.
///
/// The depth limit exists because a runtime viewer wants recoverable edits
/// without an unbounded history; the mechanism is identical to the designer's.
class UndoStack {
  final int limit;
  final List<DraftCommand> _undo = [];
  final List<DraftCommand> _redo = [];

  UndoStack({this.limit = 200});

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoDepth => _undo.length;

  void push(DraftCommand inverse) {
    _undo.add(inverse);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  DraftCommand takeUndo() => _undo.removeLast();

  void pushRedo(DraftCommand inverse) => _redo.add(inverse);

  DraftCommand takeRedo() => _redo.removeLast();

  void pushUndoOnly(DraftCommand inverse) => _undo.add(inverse);

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}

/// Applies commands, enforces capabilities in one place, and publishes changes.
class CommandDispatcher {
  final CommandTarget target;
  final UndoStack _history;
  final StreamController<DocChange> _changes =
      StreamController<DocChange>.broadcast();

  DraftPermissions permissions;

  CommandDispatcher({
    required this.target,
    this.permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) : _history = UndoStack(limit: undoLimit);

  Stream<DocChange> get changes => _changes.stream;

  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void execute(DraftCommand command) {
    _require(command);
    // The inverse is pushed only after apply returns, so a command that throws
    // leaves no history behind.
    final result = command.apply(target);
    _history.push(result.inverse);
    _changes.add(CommandApplied(label: command.label, touched: result.touched));
  }

  void undo() {
    if (!_history.canUndo) return;
    final inverse = _history.takeUndo();
    final CommandResult result;
    try {
      _require(inverse);
      // apply is inside the try too. DraftCommand's contract is that a
      // command either completes fully or leaves the target unmutated, so a
      // throwing inverse means nothing changed — restoring the entry keeps
      // it retryable. Leaving apply outside reproduces the very defect this
      // block exists to fix, just via a different trigger.
      result = inverse.apply(target);
    } catch (_) {
      // Restore the popped entry. Checking after the pop and not putting it
      // back means a single denied undo silently and permanently strands
      // that edit — it is gone from both stacks with nothing reported.
      _history.pushUndoOnly(inverse);
      rethrow;
    }
    _history.pushRedo(result.inverse);
    _changes.add(CommandUndone(label: inverse.label, touched: result.touched));
  }

  void redo() {
    if (!_history.canRedo) return;
    final inverse = _history.takeRedo();
    final CommandResult result;
    try {
      _require(inverse);
      result = inverse.apply(target);
    } catch (_) {
      _history.pushRedo(inverse);
      rethrow;
    }
    _history.pushUndoOnly(result.inverse);
    _changes.add(CommandRedone(label: inverse.label, touched: result.touched));
  }

  /// The whole document was replaced; history no longer applies to it.
  void notifyLoaded() {
    _history.clear();
    _changes.add(const DocumentLoaded());
  }

  /// Slots were compacted. Every slot-keyed derived structure is invalid and
  /// history cannot be replayed against the new numbering.
  void notifyPurged() {
    _history.clear();
    _changes.add(const DocumentPurged());
  }

  void clearHistory() => _history.clear();

  Future<void> dispose() => _changes.close();

  void _require(DraftCommand command) {
    if (!permissions.allows(command.capability)) {
      throw PermissionDeniedError(command.capability, command.label);
    }
  }
}
```

`redo` uses `pushUndoOnly` rather than `push` because `push` clears the redo
stack — correct for a new command, wrong when replaying one.

- [ ] **Step 6: Export them from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/command.dart';
export 'src/document/doc_change.dart';
export 'src/document/undo.dart';
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): command dispatcher with capabilities, undo and change stream"
```

---

### Task 16: The concrete commands

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Create: `packages/jet_cad_2d/test/document/commands_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `DraftCommand`, `CommandTarget`, `CommandResult`, `Capability`, `EntityRecord`, `GeometryPayload`, `Node`, `Component`.
- Produces: `AddEntityCommand`, `RemoveEntityCommand`, `TransformNodeCommand`, `AddNodeCommand`, `RemoveNodeCommand`, `SetComponentCommand<T>`.

One command per capability at minimum, so all four are exercised end to end.

**The rule these commands exist to demonstrate:** a delete's inverse carries the **payload**, never the slot. Undo may legitimately restore into a different slot, and every reference is rewritten by the command that moved it.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/commands_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

class TestTarget implements CommandTarget {
  @override
  final EntityStore entities = EntityStore();
  @override
  final GeometryStore geometry = GeometryStore();
  @override
  final DocumentTables tables = DocumentTables.standard();
  @override
  final ComponentRegistry components = ComponentRegistry()..registerBuiltIns();
  @override
  final HandleSeed handleSeed = HandleSeed(ReservedHandles.firstFree);
  late final Handle rootHandle = handleSeed.next();
  @override
  late final DocumentTree tree = DocumentTree(
    rootNode: GroupNode(
      handle: rootHandle,
      parent: Handle.none,
      transform: Transform2.identity(),
      children: const [],
    ),
  );
  @override
  void invalidateDerived() {}
}

GeometryPayload line(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

EntityRecord recordFor(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

void main() {
  test('AddEntityCommand stores geometry and record, and reports the handle', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final handle = target.handleSeed.next();

    dispatcher.execute(AddEntityCommand(
      record: recordFor(handle, target.rootHandle),
      payload: line(0, 0, 10, 0),
    ));

    final slot = target.entities.slotOf(handle)!;
    expect(target.entities.read(slot).handle, handle);
    expect(target.geometry.read(target.entities.geomIndexAt(slot)).pointAt(1),
        Vector2(10, 0));
  });

  test('AddEntityCommand needs the geometry capability', () {
    final dispatcher = CommandDispatcher(
      target: TestTarget(),
      permissions: DraftPermissions.runtime,
    );
    expect(
      () => dispatcher.execute(AddEntityCommand(
        record: recordFor(const Handle(50), const Handle(16)),
        payload: line(0, 0, 1, 1),
      )),
      throwsA(isA<PermissionDeniedError>()),
    );
  });

  test('undo of an add removes both the record and the geometry', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final handle = target.handleSeed.next();
    dispatcher.execute(AddEntityCommand(
      record: recordFor(handle, target.rootHandle),
      payload: line(0, 0, 1, 1),
    ));
    dispatcher.undo();
    expect(target.entities.slotOf(handle), isNull);
    expect(target.geometry.liveCount, 0);
  });

  test("a delete's inverse carries the payload, so undo may use another slot", () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);

    final first = target.handleSeed.next();
    final second = target.handleSeed.next();
    dispatcher.execute(AddEntityCommand(
        record: recordFor(first, target.rootHandle), payload: line(0, 0, 1, 1)));
    dispatcher.execute(AddEntityCommand(
        record: recordFor(second, target.rootHandle), payload: line(9, 9, 8, 8)));

    dispatcher.execute(RemoveEntityCommand(first));
    dispatcher.execute(RemoveEntityCommand(second));
    dispatcher.undo(); // restores `second`
    dispatcher.undo(); // restores `first`

    // Both are back with their own geometry, whatever slots they landed in.
    final firstSlot = target.entities.slotOf(first)!;
    final secondSlot = target.entities.slotOf(second)!;
    expect(target.geometry.read(target.entities.geomIndexAt(firstSlot)).pointAt(0),
        Vector2(0, 0));
    expect(
        target.geometry.read(target.entities.geomIndexAt(secondSlot)).pointAt(0),
        Vector2(9, 9));
  });

  test('TransformNodeCommand needs only the transform capability', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(
      target: target,
      permissions: DraftPermissions.runtime,
    );
    final node = GroupNode(
      handle: target.handleSeed.next(),
      parent: target.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    );
    target.tree.addNode(node);

    dispatcher.execute(
        TransformNodeCommand(node.handle, Transform2.translation(3, 4)));
    expect(
      target.tree[node.handle]!.transform
          .transformPoint(Vector2.zero()),
      Vector2(3, 4),
    );

    dispatcher.undo();
    expect(target.tree[node.handle]!.transform.isIdentity, isTrue);
  });

  test('AddNodeCommand and RemoveNodeCommand need the structure capability', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final node = GroupNode(
      handle: target.handleSeed.next(),
      parent: target.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    );

    dispatcher.execute(AddNodeCommand(node));
    expect(target.tree[node.handle], isNotNull);

    dispatcher.execute(RemoveNodeCommand(node.handle));
    expect(target.tree[node.handle], isNull);

    dispatcher.undo();
    expect(target.tree[node.handle], isNotNull);

    dispatcher.permissions = DraftPermissions.runtime;
    expect(() => dispatcher.execute(RemoveNodeCommand(node.handle)),
        throwsA(isA<PermissionDeniedError>()));
  });

  test('SetComponentCommand attaches, detaches, and reverses both', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    const handle = Handle(1000);

    dispatcher.execute(SetComponentCommand<OriginComponent>(
      handle,
      const OriginComponent(source: SourceKind.dxf, id: '2A'),
    ));
    expect(target.components.get<OriginComponent>(handle)!.id, '2A');

    dispatcher.execute(SetComponentCommand<OriginComponent>(handle, null));
    expect(target.components.get<OriginComponent>(handle), isNull);

    dispatcher.undo();
    expect(target.components.get<OriginComponent>(handle)!.id, '2A');

    dispatcher.undo();
    expect(target.components.get<OriginComponent>(handle), isNull);
  });

  test('SetComponentCommand runs under runtime permissions', () {
    // Editing a table's properties is exactly what a runtime is allowed to do.
    final target = TestTarget();
    final dispatcher = CommandDispatcher(
      target: target,
      permissions: DraftPermissions.runtime,
    );
    dispatcher.execute(SetComponentCommand<OriginComponent>(
      const Handle(1000),
      const OriginComponent(source: SourceKind.native, id: 'x'),
    ));
    expect(target.components.get<OriginComponent>(const Handle(1000)), isNotNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/commands_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'AddEntityCommand'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/commands.dart`:

```dart
import '../core/handle.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'command.dart';
import 'component.dart';
import 'node.dart';

/// Adds one leaf entity together with its geometry.
///
/// The record's `geomIndex` is ignored on the way in: the geometry slot is
/// whatever the store hands back, and the stored record is rewritten to match.
class AddEntityCommand extends DraftCommand {
  final EntityRecord record;
  final GeometryPayload payload;

  AddEntityCommand({required this.record, required this.payload});

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Add ${record.kind.name}';

  @override
  CommandResult apply(CommandTarget target) {
    final geomIndex = target.geometry.add(payload);
    target.entities.add(record.copyWith(geomIndex: geomIndex));
    target.handleSeed.raiseTo(record.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: RemoveEntityCommand(record.handle),
      touched: {record.handle},
    );
  }
}

/// Removes one leaf entity and its geometry.
///
/// The inverse carries the record and the geometry **payload**, never the
/// slots: undo may legitimately land in different slots, and the restored
/// record is rewritten to point at whichever geometry slot it gets.
class RemoveEntityCommand extends DraftCommand {
  final Handle handle;

  RemoveEntityCommand(this.handle);

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Remove entity';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) {
      throw StateError('no entity with handle ${handle.toHex()}');
    }
    final record = target.entities.read(slot);
    final payload = target.geometry.read(record.geomIndex);
    target.entities.remove(slot);
    target.geometry.remove(record.geomIndex);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddEntityCommand(record: record, payload: payload),
      touched: {handle},
    );
  }
}

/// Replaces a container's transform.
///
/// Distinct from editing geometry, which is what makes the `transform` and
/// `geometry` capabilities separable at all.
class TransformNodeCommand extends DraftCommand {
  final Handle handle;
  final Transform2 transform;

  TransformNodeCommand(this.handle, this.transform);

  @override
  Capability get capability => Capability.transform;

  @override
  String get label => 'Move';

  @override
  CommandResult apply(CommandTarget target) {
    final node = target.tree[handle];
    if (node == null) throw StateError('no node with handle ${handle.toHex()}');
    final previous = node.transform;
    target.tree.replaceNode(switch (node) {
      GroupNode() => node.copyWith(transform: transform),
      InstanceNode() => node.copyWith(transform: transform),
    });
    target.invalidateDerived();
    return CommandResult(
      inverse: TransformNodeCommand(handle, previous),
      touched: {handle},
    );
  }
}

class AddNodeCommand extends DraftCommand {
  final Node node;

  AddNodeCommand(this.node);

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Add node';

  @override
  CommandResult apply(CommandTarget target) {
    // addNode rejects anything that would close a definition cycle, and throws
    // before mutating, so a rejected command leaves no history.
    target.tree.addNode(node);
    target.handleSeed.raiseTo(node.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: RemoveNodeCommand(node.handle),
      touched: {node.handle},
    );
  }
}

class RemoveNodeCommand extends DraftCommand {
  final Handle handle;

  RemoveNodeCommand(this.handle);

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Remove node';

  @override
  CommandResult apply(CommandTarget target) {
    final node = target.tree[handle];
    if (node == null) throw StateError('no node with handle ${handle.toHex()}');
    target.tree.removeNode(handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddNodeCommand(node),
      touched: {handle},
    );
  }
}

/// Attaches, replaces, or (with a null value) detaches one component.
///
/// Editing component data is what a runtime is allowed to do without being
/// allowed to touch geometry — a table's number and capacity change; the walls
/// do not.
class SetComponentCommand<T extends Component> extends DraftCommand {
  final Handle handle;
  final T? value;

  SetComponentCommand(this.handle, this.value);

  @override
  Capability get capability => Capability.components;

  @override
  String get label => value == null ? 'Clear component' : 'Set component';

  @override
  CommandResult apply(CommandTarget target) {
    final previous = target.components.get<T>(handle);
    if (value == null) {
      target.components.detach<T>(handle);
    } else {
      target.components.attach<T>(handle, value as T);
    }
    target.invalidateDerived();
    return CommandResult(
      inverse: SetComponentCommand<T>(handle, previous),
      touched: {handle},
    );
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/commands.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): entity, node, transform and component commands"
```

---

### Task 17: Header, preserved raw data, and entity bounds

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/header.dart`
- Create: `packages/jet_cad_2d/lib/src/document/raw_data.dart`
- Create: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Create: `packages/jet_cad_2d/test/document/header_test.dart`
- Create: `packages/jet_cad_2d/test/document/raw_data_test.dart`
- Create: `packages/jet_cad_2d/test/document/extents_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: `Handle`, `SourceKind`, `Aabb2`, `arcBounds`, `EntityKind`, `GeometryPayload`.
- Produces:
  - `enum DrawingUnits { unitless, millimeters, centimeters, meters, inches, feet }`
  - `class DocumentHeader` — `DrawingUnits units`, `double scale`, `Aabb2? importedExtents`, `Map<String, Object?> customVariables`; `toJson`/`fromJson` with sorted custom variables.
  - `class RawDataStore` — `void set(Handle, SourceKind, Object?)`, `Object? get(Handle, SourceKind)`, `Map<SourceKind, Object?> allFor(Handle)`, `void remove(Handle)`, `Iterable<Handle> get handles`, `Map<String, Object?> toJson()`, `void loadJson(Map<String, Object?>)`, `bool get isEmpty`, `void clear()`.
  - `abstract class TextMeasurer` with `Aabb2 measure({required String text, required Handle style, required double height, required Vector2 insertion})` — named parameters, matching the Step 5 code; and `class InsertionPointMeasurer implements TextMeasurer`.
  - `Aabb2 entityBounds({required EntityKind kind, required GeometryPayload payload, required TextMeasurer measurer, required Handle textStyle, String text = ''})`.

**`importedExtents` versus working extents.** `importedExtents` is stored: an opaque value preserved so `$EXTMIN`/`$EXTMAX` survive a round-trip unchanged. Working extents are derived, recomputed, and never persisted — a text entity's contribution comes from a font-dependent layout, so persisting them would make the same document serialize differently on two machines.

**`TextMeasurer` is an interface** because real layout needs Flutter and this package must not depend on it. The engine ships `InsertionPointMeasurer`, which contributes only the insertion point; the widget layer supplies a real implementation in Plan 3.

- [ ] **Step 1: Write the failing tests**

Create `packages/jet_cad_2d/test/document/header_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
// hide Aabb2: vector_math_64 exports its own, colliding with ours.
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  test('defaults to unitless with unit scale and no imported extents', () {
    final header = DocumentHeader();
    expect(header.units, DrawingUnits.unitless);
    expect(header.scale, 1.0);
    expect(header.importedExtents, isNull);
    expect(header.customVariables, isEmpty);
  });

  test('importedExtents is stored verbatim and never recomputed', () {
    // It exists only so $EXTMIN/$EXTMAX survive a round-trip. Working extents
    // are a separate, derived value.
    final header = DocumentHeader()
      ..importedExtents = Aabb2(Vector2(0, 0), Vector2(100, 50));
    expect(DocumentHeader.fromJson(header.toJson()).importedExtents!.max,
        Vector2(100, 50));
  });

  test('json key order is stable and custom variables are sorted', () {
    final header = DocumentHeader()
      ..units = DrawingUnits.millimeters
      ..customVariables['zeta'] = 1
      ..customVariables['alpha'] = 2;
    expect(header.toJson().keys.toList(),
        ['units', 'scale', 'importedExtents', 'customVariables']);
    expect((header.toJson()['customVariables']! as Map).keys.toList(),
        ['alpha', 'zeta']);
  });

  test('round-trips', () {
    final header = DocumentHeader()
      ..units = DrawingUnits.meters
      ..scale = 0.001
      ..customVariables['acadver'] = 'AC1027';
    final decoded = DocumentHeader.fromJson(header.toJson());
    expect(decoded.units, DrawingUnits.meters);
    expect(decoded.scale, 0.001);
    expect(decoded.customVariables['acadver'], 'AC1027');
  });
}
```

Create `packages/jet_cad_2d/test/document/raw_data_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('stores an opaque blob per handle per source', () {
    // The engine never inspects the payload; only the adapter that wrote it
    // knows its shape. That is what keeps this from being a DXF concept in the
    // core document.
    final raw = RawDataStore()
      ..set(const Handle(10), SourceKind.dxf, {'70': 1, 'unknown': [1, 2]});
    expect((raw.get(const Handle(10), SourceKind.dxf)! as Map)['70'], 1);
    expect(raw.get(const Handle(10), SourceKind.ifc), isNull);
  });

  test('keeps sources independent for the same handle', () {
    final raw = RawDataStore()
      ..set(const Handle(10), SourceKind.dxf, {'a': 1})
      ..set(const Handle(10), SourceKind.ifc, {'b': 2});
    expect(raw.allFor(const Handle(10)).keys,
        containsAll([SourceKind.dxf, SourceKind.ifc]));
  });

  test('round-trips unchanged, including nested structures', () {
    final source = RawDataStore()
      ..set(const Handle(300), SourceKind.dxf, {
        'nested': {'deep': [1, 'two', 3.0]},
      })
      ..set(const Handle(10), SourceKind.dxf, {'x': 1});
    final json = source.toJson();
    final loaded = RawDataStore()..loadJson(json);
    expect(loaded.toJson(), json);
    expect(
      ((loaded.get(const Handle(300), SourceKind.dxf)! as Map)['nested']
          as Map)['deep'],
      [1, 'two', 3.0],
    );
  });

  test('serialises handles in numeric order for determinism', () {
    final raw = RawDataStore()
      ..set(const Handle(300), SourceKind.dxf, {'x': 1})
      ..set(const Handle(10), SourceKind.dxf, {'x': 2})
      ..set(const Handle(200), SourceKind.dxf, {'x': 3});
    expect(raw.toJson().keys.toList(), ['10', '200', '300']);
  });

  test('remove clears every source for a handle', () {
    final raw = RawDataStore()
      ..set(const Handle(10), SourceKind.dxf, {'a': 1})
      ..remove(const Handle(10));
    expect(raw.allFor(const Handle(10)), isEmpty);
    expect(raw.isEmpty, isTrue);
  });
}
```

Create `packages/jet_cad_2d/test/document/extents_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload payload(List<double> coords, [List<double> scalars = const []]) =>
    GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    );

void main() {
  const measurer = InsertionPointMeasurer();

  test('line bounds its endpoints', () {
    final box = entityBounds(
      kind: EntityKind.line,
      payload: payload([0, 0, 10, -5]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.min, Vector2(0, -5));
    expect(box.max, Vector2(10, 0));
  });

  test('circle bounds centre plus radius, not just the centre point', () {
    final box = entityBounds(
      kind: EntityKind.circle,
      payload: payload([100, 50], [10]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.min, Vector2(90, 40));
    expect(box.max, Vector2(110, 60));
  });

  test('arc includes an axis extreme inside its sweep', () {
    // The same trap arcBounds exists to avoid, reached through the entity path.
    final box = entityBounds(
      kind: EntityKind.arc,
      payload: payload([0, 0], [1, -math.pi / 4, math.pi / 2]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.max.x, closeTo(1, 1e-12));
  });

  test('polyline bounds every vertex', () {
    final box = entityBounds(
      kind: EntityKind.polyline,
      payload: payload([0, 0, 5, 12, -3, 4]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.min, Vector2(-3, 0));
    expect(box.max, Vector2(5, 12));
  });

  test('text uses the injected measurer, so the engine needs no font stack', () {
    final box = entityBounds(
      kind: EntityKind.text,
      payload: payload([7, 8], [2.5]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
      text: 'Table 12',
    );
    // The default measurer contributes the insertion point only; a real layout
    // arrives with the widget layer.
    expect(box.min, Vector2(7, 8));
    expect(box.max, Vector2(7, 8));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd packages/jet_cad_2d && dart test test/document/ && cd ../..
```

Expected: compile failure — `Undefined name 'DocumentHeader'`.

- [ ] **Step 3: Implement the header**

Create `packages/jet_cad_2d/lib/src/document/header.dart`:

```dart
import '../geometry/aabb2.dart';

/// Drawing units, mirroring DXF `$INSUNITS` for the values this engine cares
/// about.
enum DrawingUnits { unitless, millimeters, centimeters, meters, inches, feet }

/// Document-wide stored settings.
class DocumentHeader {
  DrawingUnits units = DrawingUnits.unitless;
  double scale = 1.0;

  /// Extents exactly as they were read from an imported file, preserved so
  /// `$EXTMIN`/`$EXTMAX` survive a round-trip.
  ///
  /// This is **not** the document's working extents. Working extents are
  /// derived and recomputed, because a text entity's contribution comes from a
  /// font- and platform-dependent layout; persisting them would make the same
  /// document serialize differently on two machines and break both the
  /// determinism guarantee and the round-trip property test.
  Aabb2? importedExtents;

  /// Header variables this engine does not model, preserved verbatim.
  final Map<String, Object?> customVariables = {};

  DocumentHeader();

  Map<String, Object?> toJson() => {
        'units': units.name,
        'scale': scale,
        'importedExtents': importedExtents?.toJson(),
        'customVariables': {
          for (final key in customVariables.keys.toList()..sort())
            key: customVariables[key],
        },
      };

  static DocumentHeader fromJson(Map<String, Object?> json) {
    final header = DocumentHeader()
      ..units = DrawingUnits.values.byName(json['units']! as String)
      ..scale = (json['scale']! as num).toDouble();
    final extents = json['importedExtents'];
    if (extents != null) header.importedExtents = Aabb2.fromJson(extents);
    header.customVariables
        .addAll((json['customVariables']! as Map).cast<String, Object?>());
    return header;
  }
}
```

- [ ] **Step 4: Implement the raw data store**

Create `packages/jet_cad_2d/lib/src/document/raw_data.dart`:

```dart
import '../core/handle.dart';
import 'origin_component.dart';

/// The preserve-unknown slot: an opaque blob per handle, per source format.
///
/// The engine stores, serializes and returns these payloads and never inspects
/// them. Modelling them as DXF group codes would have put a format concept in
/// the core document; keeping them opaque is what makes "the engine names no
/// format" true even here.
class RawDataStore {
  final Map<Handle, Map<SourceKind, Object?>> _byHandle = {};

  bool get isEmpty => _byHandle.isEmpty;

  Iterable<Handle> get handles {
    final list = _byHandle.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  void set(Handle handle, SourceKind source, Object? payload) =>
      (_byHandle[handle] ??= {})[source] = payload;

  Object? get(Handle handle, SourceKind source) => _byHandle[handle]?[source];

  /// Read-only. Returning the live inner map would let a caller mutate stored
  /// data behind [set] and [remove] — the same aliasing defect as returning a
  /// mutable `Vector2` or a growable children list, which this package has now
  /// hit three times.
  Map<SourceKind, Object?> allFor(Handle handle) =>
      Map.unmodifiable(_byHandle[handle] ?? const {});

  void remove(Handle handle) => _byHandle.remove(handle);

  /// Shape: `{ handleDecimal: { sourceName: payload } }`, handles in numeric
  /// order and sources in enum order, so output is byte-deterministic.
  Map<String, Object?> toJson() => {
        for (final handle in handles)
          handle.value.toString(): {
            for (final source in SourceKind.values)
              if (_byHandle[handle]!.containsKey(source))
                source.name: _byHandle[handle]![source],
          },
      };

  void loadJson(Map<String, Object?> json) {
    clear();
    final keys = json.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    for (final key in keys) {
      final handle = Handle.checked(int.parse(key));
      final perSource = (json[key]! as Map).cast<String, Object?>();
      for (final sourceName in perSource.keys) {
        set(handle, SourceKind.values.byName(sourceName), perSource[sourceName]);
      }
    }
  }

  void clear() => _byHandle.clear();
}
```

- [ ] **Step 5: Implement text measurement and entity bounds**

Create `packages/jet_cad_2d/lib/src/document/extents.dart`:

```dart
import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';
import '../geometry/aabb2.dart';
import '../geometry/primitives.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

/// Supplies the laid-out box of a text entity.
///
/// An interface rather than an implementation because real layout needs a font
/// stack, and this package must not depend on Flutter. The widget layer
/// supplies a real measurer; the engine ships [InsertionPointMeasurer].
abstract class TextMeasurer {
  Aabb2 measure({
    required String text,
    required Handle style,
    required double height,
    required Vector2 insertion,
  });
}

/// Contributes only the insertion point.
///
/// Correct-but-minimal: extents computed with it are a lower bound, which is
/// the honest answer when no font stack is present. It also keeps engine tests
/// deterministic across machines.
class InsertionPointMeasurer implements TextMeasurer {
  const InsertionPointMeasurer();

  @override
  Aabb2 measure({
    required String text,
    required Handle style,
    required double height,
    required Vector2 insertion,
  }) =>
      Aabb2(insertion, insertion);
}

/// Bounds one entity in its **owner's** space.
///
/// Callers transform the result into the enclosing space; this function knows
/// geometry, not placement.
Aabb2 entityBounds({
  required EntityKind kind,
  required GeometryPayload payload,
  required TextMeasurer measurer,
  required Handle textStyle,
  String text = '',
}) {
  switch (kind) {
    case EntityKind.point:
    case EntityKind.line:
    case EntityKind.polyline:
      var box = Aabb2.empty();
      for (var i = 0; i < payload.pointCount; i++) {
        box = box.expandedToPoint(payload.pointAt(i));
      }
      return box;

    case EntityKind.circle:
      final centre = payload.pointAt(0);
      final radius = payload.scalars[0];
      return Aabb2(
        Vector2(centre.x - radius, centre.y - radius),
        Vector2(centre.x + radius, centre.y + radius),
      );

    case EntityKind.arc:
      return arcBounds(
        payload.pointAt(0),
        payload.scalars[0],
        payload.scalars[1],
        payload.scalars[2],
      );

    case EntityKind.text:
    case EntityKind.attrib:
      return measurer.measure(
        text: text,
        style: textStyle,
        height: payload.scalars.isEmpty ? 0 : payload.scalars[0],
        insertion: payload.pointAt(0),
      );
  }
}
```

- [ ] **Step 6: Export them from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/extents.dart';
export 'src/document/header.dart';
export 'src/document/raw_data.dart';
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): header, opaque raw-data slot, and entity bounds"
```

---

### Task 18: DraftDocument

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/draft_document.dart`
- Create: `packages/jet_cad_2d/test/document/draft_document_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: everything from Tasks 2–17.
- Produces: `class DraftDocument implements CommandTarget` — `factory DraftDocument.empty({TextMeasurer measurer, DraftPermissions permissions, int undoLimit})`, `DocumentHeader get header`, `RawDataStore get rawData`, `CommandDispatcher get commands`, `Stream<DocChange> get changes`, `Handle get rootHandle`, `Aabb2 get extents`, `Aabb2 definitionBounds(Handle)`, `void invalidateDerived()`, `void purge()`, `Future<void> dispose()`, plus the `CommandTarget` members.

**Working extents are derived and cached**, recomputed on first read after any mutation. They are never persisted — see Task 17.

**Definition bounds are computed once per definition and reused by every instance**, which mirrors the two-level structure the spatial index and picture cache will use in later plans. The recursion is memoized per computation pass.

Extents scanning is linear over live entity slots. That is acceptable because extents are cached behind `invalidateDerived`; Plan 2's spatial index is what makes it cheap, and this plan deliberately does not pre-build that.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/draft_document_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload line(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

EntityRecord lineRecord(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

void main() {
  test('empty document has standard tables, a root, and empty extents', () {
    final doc = DraftDocument.empty();
    expect(doc.tables.layers[ReservedHandles.layerZero], isNotNull);
    expect(doc.tree[doc.rootHandle], isA<GroupNode>());
    expect(doc.extents.isEmpty, isTrue);
    // Reserved handles can never be reissued.
    expect(doc.handleSeed.next().value,
        greaterThanOrEqualTo(ReservedHandles.firstFree.value));
  });

  test('extents cover entities placed under the root', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(handle, doc.rootHandle),
      payload: line(0, 0, 10, 5),
    ));
    expect(doc.extents.min, Vector2(0, 0));
    expect(doc.extents.max, Vector2(10, 5));
  });

  test('extents are recomputed after a mutation, not stale', () {
    final doc = DraftDocument.empty();
    final first = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(first, doc.rootHandle),
      payload: line(0, 0, 1, 1),
    ));
    expect(doc.extents.max, Vector2(1, 1));

    final second = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(second, doc.rootHandle),
      payload: line(0, 0, 20, 20),
    ));
    expect(doc.extents.max, Vector2(20, 20));

    doc.commands.undo();
    expect(doc.extents.max, Vector2(1, 1));
  });

  test('an instance contributes its definition bounds under its transform', () {
    final doc = DraftDocument.empty();

    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: [entityHandle],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));

    // The definition alone is not placed, so it contributes nothing yet.
    expect(doc.extents.isEmpty, isTrue);

    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.translation(100, 0).multiply(Transform2.scale(3, 3)),
      definition: defHandle,
      layer: ReservedHandles.layerZero,
    )));

    expect(doc.extents.min, Vector2(100, 0));
    expect(doc.extents.max, Vector2(106, 6));
  });

  test('definitionBounds is computed once and reused across instances', () {
    final doc = DraftDocument.empty();
    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: [entityHandle],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));
    expect(doc.definitionBounds(defHandle).max, Vector2(2, 2));
    expect(doc.definitionBounds(defHandle).max, Vector2(2, 2));
  });

  test('purge compacts both stores, rewrites geomIndex, and clears history', () {
    final doc = DraftDocument.empty();
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: lineRecord(a, doc.rootHandle), payload: line(0, 0, 1, 1)));
    doc.commands.execute(AddEntityCommand(
        record: lineRecord(b, doc.rootHandle), payload: line(5, 5, 6, 6)));
    doc.commands.execute(RemoveEntityCommand(a));

    doc.purge();

    final slot = doc.entities.slotOf(b)!;
    // The surviving entity still points at its own geometry after both stores
    // were renumbered.
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(5, 5));
    expect(doc.geometry.liveCount, 1);
    expect(doc.commands.canUndo, isFalse,
        reason: 'purge is not undoable, so history cannot survive it');
  });

  test('purge emits DocumentPurged', () async {
    final doc = DraftDocument.empty();
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);
    doc.purge();
    await Future<void>.delayed(Duration.zero);
    expect(events.last, isA<DocumentPurged>());
    await sub.cancel();
    await doc.dispose();
  });

  test('runtime permissions forbid geometry but allow transform', () {
    final doc = DraftDocument.empty(permissions: DraftPermissions.runtime);
    expect(
      () => doc.commands.execute(AddEntityCommand(
        record: lineRecord(const Handle(1000), doc.rootHandle),
        payload: line(0, 0, 1, 1),
      )),
      throwsA(isA<PermissionDeniedError>()),
    );
    doc.commands.execute(
        TransformNodeCommand(doc.rootHandle, Transform2.translation(1, 1)));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/document/draft_document_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'DraftDocument'`.

- [ ] **Step 3: Write the implementation**

Create `packages/jet_cad_2d/lib/src/document/draft_document.dart`:

```dart
import 'dart:async';

import '../core/handle.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'command.dart';
import 'commands.dart';
import 'component.dart';
import 'doc_change.dart';
import 'extents.dart';
import 'header.dart';
import 'node.dart';
import 'raw_data.dart';
import 'style.dart';
import 'tables.dart';
import 'tree.dart';
import 'undo.dart';

/// The 2D CAD document.
///
/// Owns four kinds of state: object-per-record containers (nodes, definitions,
/// table records), columnar stores for leaves, sparse component stores, and the
/// opaque preserve-unknown slot. Mutation happens only through commands.
class DraftDocument implements CommandTarget {
  @override
  final EntityStore entities;
  @override
  final GeometryStore geometry;
  @override
  final DocumentTables tables;
  @override
  final ComponentRegistry components;
  @override
  final HandleSeed handleSeed;
  @override
  final DocumentTree tree;

  final DocumentHeader header;
  final RawDataStore rawData;
  TextMeasurer textMeasurer;

  late final CommandDispatcher commands;

  Aabb2? _extentsCache;

  DraftDocument._({
    required this.entities,
    required this.geometry,
    required this.tables,
    required this.components,
    required this.handleSeed,
    required this.tree,
    required this.header,
    required this.rawData,
    required this.textMeasurer,
    required DraftPermissions permissions,
    required int undoLimit,
  }) {
    commands = CommandDispatcher(
      target: this,
      permissions: permissions,
      undoLimit: undoLimit,
    );
  }

  factory DraftDocument.empty({
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) {
    // The seed starts past every reserved handle, so an allocated handle can
    // never collide with layer 0 or the BYLAYER linetype.
    final seed = HandleSeed(ReservedHandles.firstFree);
    final root = GroupNode(
      handle: seed.next(),
      parent: Handle.none,
      transform: Transform2.identity(),
      children: const [],
    );
    return DraftDocument._(
      entities: EntityStore(),
      geometry: GeometryStore(),
      tables: DocumentTables.standard(),
      components: ComponentRegistry()..registerBuiltIns(),
      handleSeed: seed,
      tree: DocumentTree(rootNode: root),
      header: DocumentHeader(),
      rawData: RawDataStore(),
      textMeasurer: measurer,
      permissions: permissions,
      undoLimit: undoLimit,
    );
  }

  Handle get rootHandle => tree.root;

  Stream<DocChange> get changes => commands.changes;

  @override
  void invalidateDerived() => _extentsCache = null;

  /// Working extents, in root space. Derived: recomputed on first read after a
  /// mutation, and never persisted.
  Aabb2 get extents => _extentsCache ??= _computeExtents();

  /// Bounds of a definition in its own local space.
  ///
  /// Computed once per definition and reused by every instance — the same
  /// sharing the spatial index and the picture cache rely on in later plans.
  Aabb2 definitionBounds(Handle definition) =>
      _boundsOfContainer(definition, <Handle>{}, <Handle, Aabb2>{});

  /// Compacts both columnar stores and clears history.
  ///
  /// Not a command and not undoable: slot values change, so no recorded inverse
  /// could be replayed against the new numbering.
  void purge() {
    final geometryRemap = geometry.purge();
    for (final slot in entities.liveSlots.toList()) {
      final record = entities.read(slot);
      final moved = geometryRemap[record.geomIndex];
      if (moved >= 0 && moved != record.geomIndex) {
        entities.replace(slot, record.copyWith(geomIndex: moved));
      }
    }
    entities.purge();
    invalidateDerived();
    commands.notifyPurged();
  }

  Future<void> dispose() => commands.dispose();

  Aabb2 _computeExtents() {
    final memo = <Handle, Aabb2>{};
    return _boundsOfContainer(tree.root, <Handle>{}, memo);
  }

  /// Union of everything a container holds, expressed in that container's own
  /// space. Works for both a group node and a definition.
  Aabb2 _boundsOfContainer(
    Handle container,
    Set<Handle> visiting,
    Map<Handle, Aabb2> memo,
  ) {
    final cached = memo[container];
    if (cached != null) return cached;
    // Cycles are rejected on insert and repaired on import, but a guard here
    // keeps a malformed in-memory tree from recursing forever.
    if (!visiting.add(container)) return Aabb2.empty();

    var box = Aabb2.empty();

    for (final slot in entities.liveSlots) {
      if (entities.ownerAt(slot) != container) continue;
      final record = entities.read(slot);
      box = box.union(entityBounds(
        kind: record.kind,
        payload: geometry.read(record.geomIndex),
        measurer: textMeasurer,
        textStyle: ReservedHandles.standardTextStyle,
      ));
    }

    for (final child in _childrenOf(container)) {
      final node = tree[child];
      switch (node) {
        case GroupNode(:final transform):
          box = box.union(
              _boundsOfContainer(child, visiting, memo).transformedBy(transform));
        case InstanceNode(:final definition, :final transform):
          box = box.union(_boundsOfContainer(definition, visiting, memo)
              .transformedBy(transform));
        case null:
          break; // an entity handle, already covered above
      }
    }

    visiting.remove(container);
    memo[container] = box;
    return box;
  }

  List<Handle> _childrenOf(Handle container) {
    final node = tree[container];
    if (node is GroupNode) return node.children;
    return tree.definition(container)?.children ?? const [];
  }
}
```

- [ ] **Step 4: Export it from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/document/draft_document.dart';
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

If `extents` reports empty for an entity added under the root, check that
`AddEntityCommand` set the record's `owner` to `doc.rootHandle` — an entity
owned by a handle that is neither the root nor a definition contributes to
nothing, by design.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): DraftDocument with derived extents and explicit purge"
```

---

### Task 19: Deterministic JSON codec

**Files:**
- Create: `packages/jet_cad_2d/lib/src/codec/schema_version.dart`
- Create: `packages/jet_cad_2d/lib/src/codec/json_codec.dart`
- Create: `packages/jet_cad_2d/test/codec/json_codec_test.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart` (add `unknownDocumentFields`)
- Modify: `packages/jet_cad_2d/lib/src/document/tree.dart` (add `setRoot`)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`

**Interfaces:**
- Consumes: everything.
- Produces:
  - `const int kSchemaVersion = 1;` and `class SchemaVersionError implements Exception`.
  - `class DraftDocumentCodec` — `static Map<String, Object?> encode(DraftDocument)`, `static DraftDocument decode(Map<String, Object?>, {TextMeasurer measurer, DraftPermissions permissions, int undoLimit})`, `static String encodeToString(DraftDocument)`, `static DraftDocument decodeString(String, {...})`.
  - On `DraftDocument`: `final Map<String, Object?> unknownDocumentFields = {};`

**Slots are never persisted.** Each entity is written with its geometry payload inline; the loader re-adds the payload and takes whatever slot it gets. Persisting a slot would make the file depend on allocation history, and would let a load silently violate the rule that a slot changes only inside a command that rewrites every reference.

**Determinism** comes from every `toJson` building its map in a fixed order plus every collection being emitted in ascending-handle order. Dart's `jsonEncode` preserves insertion order, so no sorting happens at encode time — the ordering discipline is in the model, where it can be tested.

- [ ] **Step 1: Add the unknown-fields slot to the document**

In `packages/jet_cad_2d/lib/src/document/draft_document.dart`, add this field next to `rawData`:

```dart
  /// Top-level document fields written by a newer version of this package.
  ///
  /// Preserved verbatim and written back unchanged: no layer discards data it
  /// does not understand, and a document edited by an older build must not lose
  /// what a newer one wrote.
  final Map<String, Object?> unknownDocumentFields = {};
```

- [ ] **Step 2: Let the tree be re-rooted after a load**

`DocumentTree.clear()` drops every node including the root, so loading needs to
re-point the tree at the root it just read. Add this method to `DocumentTree` in
`packages/jet_cad_2d/lib/src/document/tree.dart`, next to `clear`:

```dart
  /// Re-points the tree at a root that was just loaded.
  ///
  /// Only the codec uses this: a live document's root never changes, which is
  /// why it is not a command.
  void setRoot(Handle handle) => _root = handle;
```

- [ ] **Step 3: Write the failing test**

Create `packages/jet_cad_2d/test/codec/json_codec_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

DraftDocument sampleDocument() {
  final doc = DraftDocument.empty();
  doc.header
    ..units = DrawingUnits.millimeters
    ..importedExtents = Aabb2(Vector2(0, 0), Vector2(500, 400));

  final defHandle = doc.handleSeed.next();
  final defEntity = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
    handle: defHandle,
    name: 'Table-4Seat',
    basePoint: Vector2(0.5, 0.5),
    children: [defEntity],
  ));
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: defEntity,
      owner: defHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));

  final instance = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: instance,
    parent: doc.rootHandle,
    transform: Transform2.translation(4.5e6, -3.2e6),
    definition: defHandle,
    layer: ReservedHandles.layerZero,
  )));
  doc.commands.execute(SetComponentCommand<OriginComponent>(
    instance,
    const OriginComponent(source: SourceKind.dxf, id: '2A'),
  ));
  doc.rawData.set(instance, SourceKind.dxf, {'1001': 'ACME', '1000': 'x'});
  return doc;
}

void main() {
  test('encodes the schema version and a fixed top-level key order', () {
    final json = DraftDocumentCodec.encode(DraftDocument.empty());
    expect(json['schemaVersion'], kSchemaVersion);
    expect(json.keys.toList(), [
      'schemaVersion',
      'header',
      'tables',
      'definitions',
      'root',
      'nodes',
      'entities',
      'components',
      'rawData',
      'handleSeed',
    ]);
  });

  test('refuses a document with no schema version', () {
    expect(() => DraftDocumentCodec.decode(const {}),
        throwsA(isA<SchemaVersionError>()));
  });

  test('refuses a schema version from the future', () {
    expect(
      () => DraftDocumentCodec.decode({'schemaVersion': kSchemaVersion + 1}),
      throwsA(isA<SchemaVersionError>()),
    );
  });

  test('round-trips a document structurally', () {
    final source = sampleDocument();
    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(source));

    expect(loaded.header.units, DrawingUnits.millimeters);
    expect(loaded.header.importedExtents!.max, Vector2(500, 400));
    expect(loaded.tree.definitions, hasLength(1));
    expect(loaded.tree.definitions.single.name, 'Table-4Seat');
    expect(loaded.entities.liveCount, 1);
    expect(loaded.extents.min.x, closeTo(4.5e6, 1e-9));
  });

  test('geometry is stored inline, so slots are never persisted', () {
    final json = DraftDocumentCodec.encode(sampleDocument());
    final entity = (json['entities']! as List).single as Map;
    expect(entity.keys.toList(), ['record', 'geometry']);
    // A persisted slot would make the file depend on allocation history.
    expect((entity['record']! as Map).containsKey('geomIndex'), isTrue,
        reason: 'the record still has the field; the loader overwrites it');
    final loaded = DraftDocumentCodec.decode(json);
    final slot = loaded.entities.liveSlots.single;
    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot)).pointAt(1),
        Vector2(1, 1));
  });

  test('serialization is idempotent, which is the determinism guarantee', () {
    // save(load(save(d))) == save(d). The naive save(load(x)) == x form only
    // holds when x was already produced canonically.
    final once = DraftDocumentCodec.encodeToString(sampleDocument());
    final twice =
        DraftDocumentCodec.encodeToString(DraftDocumentCodec.decodeString(once));
    expect(twice, once);
  });

  test('two documents built the same way encode identically', () {
    expect(DraftDocumentCodec.encodeToString(sampleDocument()),
        DraftDocumentCodec.encodeToString(sampleDocument()));
  });

  test('unknown top-level fields survive a round-trip', () {
    final json = DraftDocumentCodec.encode(DraftDocument.empty())
      ..['futureSection'] = {'written': 'by a newer build'};
    final loaded = DraftDocumentCodec.decode(json);
    expect(loaded.unknownDocumentFields['futureSection'], isNotNull);
    final again = DraftDocumentCodec.encode(loaded);
    expect(again['futureSection'], {'written': 'by a newer build'});
  });

  test('preserved raw data and components survive a round-trip', () {
    final loaded =
        DraftDocumentCodec.decode(DraftDocumentCodec.encode(sampleDocument()));
    final instance =
        loaded.tree.nodes.whereType<InstanceNode>().single.handle;
    expect(loaded.components.get<OriginComponent>(instance)!.id, '2A');
    expect((loaded.rawData.get(instance, SourceKind.dxf)! as Map)['1001'],
        'ACME');
  });

  test('the handle seed is restored so reloaded documents cannot reissue', () {
    final source = sampleDocument();
    final before = source.handleSeed.current;
    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(source));
    expect(loaded.handleSeed.current, before);
    expect(loaded.handleSeed.next().value, greaterThan(before.value));
  });

  test('a loaded document starts with no undo history', () {
    final loaded =
        DraftDocumentCodec.decode(DraftDocumentCodec.encode(sampleDocument()));
    expect(loaded.commands.canUndo, isFalse);
  });

  test('encodeToString produces parseable canonical JSON', () {
    final text = DraftDocumentCodec.encodeToString(sampleDocument());
    expect(jsonDecode(text), isA<Map<String, Object?>>());
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

```bash
cd packages/jet_cad_2d && dart test test/codec/json_codec_test.dart && cd ../..
```

Expected: compile failure — `Undefined name 'DraftDocumentCodec'`.

- [ ] **Step 5: Implement the schema version guard**

Create `packages/jet_cad_2d/lib/src/codec/schema_version.dart`:

```dart
/// The document schema this build writes.
///
/// Bump it whenever the on-disk shape changes, and add a migration for the
/// previous value. An unversioned document is not readable: guessing at the
/// shape of a file that never declared one is how silent corruption starts.
const int kSchemaVersion = 1;

class SchemaVersionError implements Exception {
  final Object? found;
  const SchemaVersionError(this.found);

  @override
  String toString() => found == null
      ? 'SchemaVersionError: document has no schemaVersion'
      : 'SchemaVersionError: unsupported schemaVersion $found '
          '(this build writes $kSchemaVersion)';
}
```

- [ ] **Step 6: Implement the codec**

Create `packages/jet_cad_2d/lib/src/codec/json_codec.dart`:

```dart
import 'dart:convert';

import '../core/handle.dart';
import '../document/command.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/header.dart';
import '../document/node.dart';
import '../document/tables.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'schema_version.dart';

/// Reads and writes the canonical document format.
///
/// Deterministic by construction: every `toJson` builds its map in a fixed key
/// order and every collection is emitted in ascending-handle order, so no
/// sorting happens here. The ordering discipline lives in the model, where it
/// is testable.
class DraftDocumentCodec {
  static const List<String> _knownKeys = [
    'schemaVersion',
    'header',
    'tables',
    'definitions',
    'root',
    'nodes',
    'entities',
    'components',
    'rawData',
    'handleSeed',
  ];

  static Map<String, Object?> encode(DraftDocument doc) => {
        'schemaVersion': kSchemaVersion,
        'header': doc.header.toJson(),
        'tables': {
          'layers': [for (final r in doc.tables.layers.records) r.toJson()],
          'linetypes': [
            for (final r in doc.tables.linetypes.records) r.toJson(),
          ],
          'textStyles': [
            for (final r in doc.tables.textStyles.records) r.toJson(),
          ],
          'patterns': [for (final r in doc.tables.patterns.records) r.toJson()],
          'dimStyles': [
            for (final r in doc.tables.dimStyles.records) r.toJson(),
          ],
          'appIds': [for (final r in doc.tables.appIds.records) r.toJson()],
        },
        'definitions': [for (final d in doc.tree.definitions) d.toJson()],
        'root': doc.rootHandle.toJson(),
        'nodes': [for (final n in doc.tree.nodes) n.toJson()],
        'entities': [
          // Ascending slot order, which is ascending insertion order and is
          // stable across a save/load cycle.
          for (final slot in doc.entities.liveSlots)
            {
              'record': doc.entities.read(slot).toJson(),
              // Inline, because a slot is not durable state.
              'geometry':
                  doc.geometry.read(doc.entities.geomIndexAt(slot)).toJson(),
            },
        ],
        'components': doc.components.toJson(),
        'rawData': doc.rawData.toJson(),
        'handleSeed': doc.handleSeed.current.toJson(),
        // Anything a newer build wrote, written back untouched.
        ...doc.unknownDocumentFields,
      };

  static String encodeToString(DraftDocument doc) => jsonEncode(encode(doc));

  static DraftDocument decode(
    Map<String, Object?> json, {
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) {
    final version = json['schemaVersion'];
    if (version is! int || version > kSchemaVersion) {
      throw SchemaVersionError(version);
    }

    final doc = DraftDocument.empty(
      measurer: measurer,
      permissions: permissions,
      undoLimit: undoLimit,
    );

    for (final key in json.keys) {
      if (!_knownKeys.contains(key)) doc.unknownDocumentFields[key] = json[key];
    }

    _loadHeader(doc, json['header']);
    _loadTables(doc, json['tables']);
    _loadTree(doc, json);
    _loadEntities(doc, json['entities']);

    doc.components.loadJson((json['components']! as Map).cast<String, Object?>());
    doc.rawData.loadJson((json['rawData']! as Map).cast<String, Object?>());
    doc.handleSeed.raiseTo(Handle.fromJson(json['handleSeed']));

    doc.invalidateDerived();
    // A loaded document has no history: the stacks describe edits to a
    // document that is now gone.
    doc.commands.notifyLoaded();
    return doc;
  }

  static DraftDocument decodeString(
    String source, {
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) =>
      decode(
        (jsonDecode(source) as Map).cast<String, Object?>(),
        measurer: measurer,
        permissions: permissions,
        undoLimit: undoLimit,
      );

  static void _loadHeader(DraftDocument doc, Object? json) {
    final header = DocumentHeader.fromJson((json! as Map).cast<String, Object?>());
    doc.header
      ..units = header.units
      ..scale = header.scale
      ..importedExtents = header.importedExtents
      ..customVariables.addAll(header.customVariables);
  }

  static void _loadTables(DraftDocument doc, Object? json) {
    final tables = (json! as Map).cast<String, Object?>();
    doc.tables.layers.clear();
    doc.tables.linetypes.clear();
    doc.tables.textStyles.clear();
    doc.tables.patterns.clear();
    doc.tables.dimStyles.clear();
    doc.tables.appIds.clear();
    for (final r in tables['linetypes']! as List) {
      doc.tables.linetypes
          .add(LinetypeRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['layers']! as List) {
      doc.tables.layers
          .add(LayerRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['textStyles']! as List) {
      doc.tables.textStyles
          .add(TextStyleRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['patterns']! as List) {
      doc.tables.patterns
          .add(PatternRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['dimStyles']! as List) {
      doc.tables.dimStyles
          .add(DimStyleRecord.fromJson((r as Map).cast<String, Object?>()));
    }
    for (final r in tables['appIds']! as List) {
      doc.tables.appIds
          .add(AppIdRecord.fromJson((r as Map).cast<String, Object?>()));
    }
  }

  static void _loadTree(DraftDocument doc, Map<String, Object?> json) {
    doc.tree.clear();
    for (final d in json['definitions']! as List) {
      doc.tree.addDefinition(Definition.fromJson(d));
    }
    // Unchecked, then repaired: a file may contain a cycle, and import
    // diagnoses and recovers rather than failing mid-parse.
    for (final n in json['nodes']! as List) {
      doc.tree.addNodeUnchecked(Node.fromJson(n));
    }
    doc.tree.repairCycles();
    doc.tree.setRoot(Handle.fromJson(json['root']));
  }

  static void _loadEntities(DraftDocument doc, Object? json) {
    doc.entities.clear();
    doc.geometry.clear();
    for (final e in json! as List) {
      final entry = (e as Map).cast<String, Object?>();
      final record = EntityRecord.fromJson(entry['record']);
      final payload = GeometryPayload.fromJson(entry['geometry']);
      // The stored slot is discarded: whatever slot the payload lands in is
      // what the restored record points at.
      final geomIndex = doc.geometry.add(payload);
      doc.entities.add(record.copyWith(geomIndex: geomIndex));
    }
  }
}
```

- [ ] **Step 7: Export the codec from the barrel**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/codec/json_codec.dart';
export 'src/codec/schema_version.dart';
```

- [ ] **Step 8: Run the tests to verify they pass**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 9: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): deterministic versioned JSON codec"
```

---

### Task 20: Cross-cutting invariant tests

**Files:**
- Create: `packages/jet_cad_2d/test/invariants/preserve_unknown_test.dart`
- Create: `packages/jet_cad_2d/test/invariants/slot_lifetime_test.dart`
- Create: `packages/jet_cad_2d/test/invariants/large_coordinates_test.dart`

**Interfaces:**
- Consumes: the whole public API.
- Produces: no production code. These pin the invariants that no single unit owns, and that a future refactor is most likely to break quietly.

Per-unit tests already prove each piece. These prove the *contracts stated in the spec* hold across pieces — the ones that will otherwise be rediscovered as bugs.

- [ ] **Step 1: Write the preserve-unknown invariant test**

Create `packages/jet_cad_2d/test/invariants/preserve_unknown_test.dart`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// "No layer discards data it does not understand."
///
/// The rule appears in three places, which is what makes it an architectural
/// invariant rather than a coincidence. All three are exercised in one document
/// so that a change which breaks one of them cannot pass by fixing the others.
void main() {
  test('all three unknown-data layers survive one round-trip', () {
    final doc = DraftDocument.empty();
    const target = Handle(1000);

    // 1. A component type this build has never heard of.
    doc.components.attachUnknown(target, {
      'typeId': 'acme.plumbing',
      'diameter': 32,
      'nested': {'material': 'copper'},
    });

    // 2. An opaque per-source blob from an adapter.
    doc.rawData.set(target, SourceKind.dxf, {'1001': 'ACME', 'codes': [1, 2, 3]});

    // 3. A top-level document field written by a newer build.
    final encoded = DraftDocumentCodec.encode(doc)
      ..['futureSection'] = {'anything': [1, 'two']};

    final loaded = DraftDocumentCodec.decode(encoded);

    expect(loaded.components.unknownOf(target).single['diameter'], 32);
    expect((loaded.rawData.get(target, SourceKind.dxf)! as Map)['1001'], 'ACME');
    expect(loaded.unknownDocumentFields['futureSection'], isNotNull);

    // And the second write is byte-identical to the first.
    expect(DraftDocumentCodec.encode(loaded)['futureSection'],
        {'anything': [1, 'two']});
    expect(DraftDocumentCodec.encodeToString(loaded),
        DraftDocumentCodec.encodeToString(DraftDocumentCodec.decode(encoded)));
  });
}
```

- [ ] **Step 2: Write the slot lifetime invariant test**

Create `packages/jet_cad_2d/test/invariants/slot_lifetime_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

EntityRecord record(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

GeometryPayload at(double x) => GeometryPayload(
      coords: Float64List.fromList([x, 0, x + 1, 1]),
      scalars: Float64List(0),
    );

/// The slot rules from the spec, exercised through the document rather than
/// through either store alone.
void main() {
  test('delete then undo then redo keeps every reference intact', () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 4; i++) doc.handleSeed.next(),
    ];
    for (var i = 0; i < handles.length; i++) {
      doc.commands.execute(AddEntityCommand(
        record: record(handles[i], doc.rootHandle),
        payload: at(i * 10.0),
      ));
    }

    // Delete out of order, so the free list is not a simple reversal.
    doc.commands.execute(RemoveEntityCommand(handles[1]));
    doc.commands.execute(RemoveEntityCommand(handles[3]));
    doc.commands.execute(RemoveEntityCommand(handles[0]));

    for (var i = 0; i < 3; i++) {
      doc.commands.undo();
    }

    for (var i = 0; i < handles.length; i++) {
      final slot = doc.entities.slotOf(handles[i])!;
      final geometry = doc.geometry.read(doc.entities.geomIndexAt(slot));
      expect(geometry.pointAt(0), Vector2(i * 10.0, 0),
          reason: 'entity $i must still point at its own geometry');
    }

    for (var i = 0; i < 3; i++) {
      doc.commands.redo();
    }
    expect(doc.entities.liveCount, 1);
    expect(doc.entities.slotOf(handles[2]), isNotNull);
  });

  test('purge rewrites references and is not undoable', () {
    final doc = DraftDocument.empty();
    final keep = doc.handleSeed.next();
    final drop = doc.handleSeed.next();
    doc.commands.execute(
        AddEntityCommand(record: record(drop, doc.rootHandle), payload: at(0)));
    doc.commands.execute(
        AddEntityCommand(record: record(keep, doc.rootHandle), payload: at(50)));
    doc.commands.execute(RemoveEntityCommand(drop));

    doc.purge();

    final slot = doc.entities.slotOf(keep)!;
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(50, 0));
    expect(doc.geometry.liveCount, 1);
    expect(doc.entities.liveCount, 1);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
  });

  test('a save/load cycle does not preserve slots, and does not need to', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(
        AddEntityCommand(record: record(handle, doc.rootHandle), payload: at(7)));

    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(doc));
    final slot = loaded.entities.slotOf(handle)!;
    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(7, 0));
  });
}
```

- [ ] **Step 3: Write the large-coordinate invariant test**

Create `packages/jet_cad_2d/test/invariants/large_coordinates_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// The model is Float64 end to end.
///
/// Only the renderer's residual matrix is ever float32, and it gets there by
/// rebasing — which is a Plan 3 concern. What this plan owes that design is a
/// model that has not already lost the precision, so these assertions are
/// exact rather than approximate.
void main() {
  const siteX = 4.5e6;
  const siteY = -3.2e6;

  test('a composed instance transform is exact at site-plan magnitudes', () {
    final doc = DraftDocument.empty();
    final group = doc.handleSeed.next();
    final instance = doc.handleSeed.next();
    final definition = doc.handleSeed.next();

    doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.tree.addNode(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(siteX, siteY),
      children: [instance],
    ));
    doc.tree.addNode(InstanceNode(
      handle: instance,
      parent: group,
      transform: Transform2.translation(0.125, 0.25),
      definition: definition,
      layer: ReservedHandles.layerZero,
    ));

    final point = doc.tree
        .accumulatedTransform(instance)
        .transformPoint(Vector2(0.0625, 0.0625));
    expect(point.x, siteX + 0.1875);
    expect(point.y, siteY + 0.3125);
  });

  test('extents at site-plan magnitudes keep sub-millimetre detail', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([siteX, siteY, siteX + 0.001, siteY + 0.001]),
        scalars: Float64List(0),
      ),
    ));
    expect(doc.extents.size.x, closeTo(0.001, 1e-9));
  });

  test('a large-coordinate document survives a byte-identical round-trip', () {
    final doc = DraftDocument.empty();
    doc.tree.addNode(GroupNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      transform: Transform2.translation(siteX, siteY),
      children: const [],
    ));
    final once = DraftDocumentCodec.encodeToString(doc);
    final twice =
        DraftDocumentCodec.encodeToString(DraftDocumentCodec.decodeString(once));
    expect(twice, once);
  });
}
```

- [ ] **Step 4: Run the whole suite**

```bash
cd packages/jet_cad_2d && dart test && dart analyze && cd ../..
```

Expected: all tests pass, `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "test(jet_cad_2d): cross-cutting invariant tests"
```

---

## What this plan deliberately leaves to later plans

Recorded so a reviewer can tell an omission from a decision.

| Spec item | Plan |
|---|---|
| Two-level spatial index, `HitPath`, snap engine, query-throughput gate | 2 |
| `StyleResolver`, `StyleContext`, the picture-cache contract, and the layer-0/BYBLOCK **resolution** conformance test | 3 |
| Coordinate rebasing through the renderer; the frame-time gate | 3 |
| Real text layout (`TextMeasurer` implementation), fills, patterns, dashes, lineweight policy | 3 |
| Interaction, selection, overlays, widget presets | 4 |
| Migration chain, file I/O, autosave | 5 — this plan ships `kSchemaVersion` and the guard, which is what migrations later attach to |
| DXF and IFC adapters, real-file corpus | future |

Two spec contracts are **stated in code here but only provable later**: the
layer-0/BYBLOCK inheritance rule has no resolver to test against until Plan 3,
and paper-space stroke invariance needs a renderer. The model-side halves —
sentinel encoding, reserved linetype records, `Transform2.anisotropyRatio` — are
delivered and tested in this plan.
