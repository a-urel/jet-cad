### Task 3: `LibraryComponent`, `ManifestComponent` and `registerKitComponents` (K2)

**Files:**
- Create: `lib/src/model/library_component.dart`, `lib/src/model/manifest_component.dart`, `lib/src/model/register.dart`
- Modify: `lib/src/model/model.dart`
- Test: `test/model/library_component_test.dart`, `test/model/manifest_component_test.dart`, `test/model/register_test.dart`

**Interfaces:**
- Consumes: `field`, `stringList` (Task 2), `isKitId` (Task 2), `SymbolComponent`, `UnitComponent`, `UnitKinds` (Task 2); from `jet_cad_2d`: `Component`, `ComponentRegistry`, `DraftDocument.empty()`, `DraftDocumentCodec.encodeToString/decodeString(..., registerComponents:)`, `AddDefinitionCommand`, `SetComponentCommand<T>`, `AddEntityCommand`, `CompoundCommand(children, label:)`, `Definition`, `EntityRecord`, `ReservedHandles`, `ByBlockColor`, `kByBlock`, `linePayload`, `PageComponent`, `OriginComponent`.
- Produces:
  - `final class LibraryComponent implements Component` — `static const String componentTypeId = 'jetcad.library'`; `LibraryComponent({required String kit, int format = 1})`; `static LibraryComponent fromJson(Map<String, Object?> json)`.
  - `final class ManifestComponent implements Component` — `static const String componentTypeId = 'jetcad.manifest'`; `ManifestComponent({int format = 1, required Map<String, String> kits})`; `kits` sorted by kit id and unmodifiable; `static ManifestComponent fromJson(Map<String, Object?> json)`.
  - `void registerKitComponents(ComponentRegistry registry)` (exported).
  - Not exported (Task 4 uses it): `typedef ComponentRead = T Function<T extends Component>(String typeId, Map<String, Object?> json, T Function(Map<String, Object?> json) read);` and `void registerKitComponentsWrapped(ComponentRegistry registry, ComponentRead read)`.

Plan decision: the `LibraryComponent` and `ManifestComponent` constructors accept any `format` of 1 or more; the validator (K3 rule 2) refuses a library format other than 1, and sub-project 2 decides how the plan refuses a newer manifest — a constructor that refused 2 would make a newer file unreadable instead of refused with a message.
Plan decision: a manifest's version strings are only required to be non-empty (no semver parsing: the plan library writes them from `PlanKit.version`), and `kits` is stored and written sorted by kit id, so the bytes do not depend on insertion order.
Plan decision: `registerKitComponents` is one line over `registerKitComponentsWrapped(registry, direct)`, so the decoder (Task 4) registers exactly the same four types through guarded factories and the two lists cannot drift.

- [ ] **Step 1: Write the failing tests.** Create `test/model/library_component_test.dart`:

```dart
// Spec K2: the library component on a library's root.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('L1 refusals: a kit that is not a kit id, a format below one', () {
    for (final kit in ['Sample', 'my-kit', '', 'sample.x']) {
      expect(() => LibraryComponent(kit: kit),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kit')),
          reason: kit);
    }
    // M-L1: drop the format check.
    expect(() => LibraryComponent(kit: 'sample', format: 0),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'format')));
  });

  test('L2 a newer format is a value the validator refuses, not the '
      'constructor', () {
    expect(LibraryComponent(kit: 'sample', format: 2).format, 2);
  });

  test('L3 equality, typeId and the pinned JSON', () {
    final a = LibraryComponent(kit: 'sample');
    expect(a, LibraryComponent(kit: 'sample'));
    expect(a.hashCode, LibraryComponent(kit: 'sample').hashCode);
    expect(a, isNot(LibraryComponent(kit: 'other')));
    // M-L3: drop format from ==.
    expect(a, isNot(LibraryComponent(kit: 'sample', format: 2)));
    expect(a.typeId, 'jetcad.library');
    expect(jsonEncode(a.toJson()), '{"format":1,"kit":"sample"}');
  });

  test('L4 fromJson reads back and refuses a missing or mistyped field', () {
    const full = <String, Object?>{'format': 1, 'kit': 'sample'};
    expect(LibraryComponent.fromJson(full), LibraryComponent(kit: 'sample'));
    for (final field in full.keys) {
      expect(() => LibraryComponent.fromJson({...full}..remove(field)),
          throwsFormatException,
          reason: field);
    }
    expect(() => LibraryComponent.fromJson({...full, 'format': '1'}),
        throwsFormatException);
  });

  test('L5 a field this build does not know is ignored', () {
    expect(
        LibraryComponent.fromJson(
            const {'format': 1, 'kit': 'sample', 'newer': true}),
        LibraryComponent(kit: 'sample'));
  });
}
```

Create `test/model/manifest_component_test.dart`:

```dart
// Spec K2, umbrella A8: the manifest on a plan's root.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('MF1 refusals: a key that is not a kit id, an empty version, format 0',
      () {
    expect(() => ManifestComponent(kits: const {'Restaurant': '0.1.0'}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kits')));
    expect(() => ManifestComponent(kits: const {'restaurant': ' '}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kits')));
    expect(() => ManifestComponent(format: 0, kits: const {}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'format')));
    expect(ManifestComponent(kits: const {}).kits, isEmpty);
  });

  test('MF2 kits are written sorted by id, whatever the insertion order', () {
    final m = ManifestComponent(
        kits: const {'restaurant': '0.1.0', 'architecture': '0.2.1'});
    // M-MF2: keep the caller's order; the text differs.
    expect(jsonEncode(m.toJson()),
        '{"format":1,"kits":{"architecture":"0.2.1","restaurant":"0.1.0"}}');
    expect(m.typeId, 'jetcad.manifest');
  });

  test('MF3 equality ignores insertion order and sees every value', () {
    final a = ManifestComponent(
        kits: const {'restaurant': '0.1.0', 'architecture': '0.2.1'});
    final b = ManifestComponent(
        kits: const {'architecture': '0.2.1', 'restaurant': '0.1.0'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    // M-MF3: compare the key sets only.
    expect(
        a,
        isNot(ManifestComponent(
            kits: const {'architecture': '0.2.2', 'restaurant': '0.1.0'})));
    expect(a, isNot(ManifestComponent(kits: const {'architecture': '0.2.1'})));
    expect(
        a,
        isNot(ManifestComponent(format: 2, kits: const {
          'architecture': '0.2.1',
          'restaurant': '0.1.0',
        })));
  });

  test('MF4 kits is an unmodifiable copy', () {
    final source = {'restaurant': '0.1.0'};
    final m = ManifestComponent(kits: source);
    source['restaurant'] = '9.9.9';
    expect(m.kits, {'restaurant': '0.1.0'});
    expect(() => m.kits['x'] = '1', throwsUnsupportedError);
  });

  test('MF5 fromJson reads back and refuses what is not a string map', () {
    final m = ManifestComponent(kits: const {'restaurant': '0.1.0'});
    expect(
        ManifestComponent.fromJson(
            (jsonDecode(jsonEncode(m.toJson())) as Map).cast<String, Object?>()),
        m);
    expect(() => ManifestComponent.fromJson(const {'format': 1}),
        throwsFormatException);
    expect(
        () => ManifestComponent.fromJson(const {'format': 1, 'kits': 'x'}),
        throwsFormatException);
    expect(
        () => ManifestComponent.fromJson(const {
              'format': 1,
              'kits': {'restaurant': 1},
            }),
        throwsFormatException);
  });
}
```

Create `test/model/register_test.dart`:

```dart
// Spec K2: registerKitComponents registers the four contract components and
// nothing else; a document carrying them saves and loads typed and
// byte-identical, and without the registration it is preserved verbatim
// (ported from jet_cad_floor_plan's symbol_component_test SC7-SC8).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

SymbolComponent highTop() => SymbolComponent(
      key: 'sample.table.high-top',
      version: 2,
      name: 'High-top table',
      category: 'Bar',
      tags: const ['table', 'bar', 'high'],
      attachTo: const ['wall-face'],
    );

/// A document off the origin carrying all four components: the manifest and
/// the library on the root, the symbol and the unit on a definition.
({DraftDocument doc, Handle def}) withEveryComponent() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  final def = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: 'sample.table.high-top@2',
        basePoint: Vector2(1250, 860),
        children: const [])),
    SetComponentCommand<SymbolComponent>(def, highTop()),
    SetComponentCommand<UnitComponent>(
        def, UnitComponent(kind: UnitKinds.table, capacity: 4)),
    SetComponentCommand<ManifestComponent>(
        doc.rootHandle,
        ManifestComponent(
            kits: const {'sample': '0.3.1', 'architecture': '0.1.0'})),
    SetComponentCommand<LibraryComponent>(
        doc.rootHandle, LibraryComponent(kit: 'sample')),
    AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
      ),
      payload: linePayload(Vector2(950, 560), Vector2(1550, 1160)),
    ),
  ], label: 'Every kit component'));
  doc.commands.clearHistory();
  return (doc: doc, def: def);
}

void main() {
  test('R1 the four components, and nothing else', () {
    final registry = ComponentRegistry();
    registerKitComponents(registry);
    expect(registry.isRegistered<SymbolComponent>(), isTrue);
    expect(registry.isRegistered<UnitComponent>(), isTrue);
    expect(registry.isRegistered<LibraryComponent>(), isTrue);
    expect(registry.isRegistered<ManifestComponent>(), isTrue);
    // M-R1: call registry.registerBuiltIns() inside registerKitComponents.
    expect(registry.isRegistered<OriginComponent>(), isFalse);
    expect(registry.isRegistered<PageComponent>(), isFalse);
  });

  test('R2 saved and loaded typed, re-encoded byte-identically', () {
    final r = withEveryComponent();
    addTearDown(r.doc.dispose);
    final saved = DraftDocumentCodec.encodeToString(r.doc);
    final loaded = DraftDocumentCodec.decodeString(saved,
        registerComponents: registerKitComponents);
    addTearDown(loaded.dispose);
    expect(loaded.components.get<SymbolComponent>(r.def), highTop());
    expect(loaded.components.get<UnitComponent>(r.def),
        UnitComponent(kind: UnitKinds.table, capacity: 4));
    expect(loaded.components.get<LibraryComponent>(loaded.rootHandle),
        LibraryComponent(kit: 'sample'));
    expect(
        loaded.components.get<ManifestComponent>(loaded.rootHandle),
        ManifestComponent(
            kits: const {'architecture': '0.1.0', 'sample': '0.3.1'}));
    expect(DraftDocumentCodec.encodeToString(loaded), saved);
  });

  test('R3 without the registration every component is kept verbatim', () {
    final r = withEveryComponent();
    addTearDown(r.doc.dispose);
    final saved = DraftDocumentCodec.encodeToString(r.doc);
    final bare = DraftDocumentCodec.decodeString(saved);
    addTearDown(bare.dispose);
    expect(bare.components.get<SymbolComponent>(r.def), isNull);
    expect(bare.components.unknownOf(r.def), hasLength(2));
    expect(bare.components.unknownOf(bare.rootHandle), hasLength(2));
    expect(DraftDocumentCodec.encodeToString(bare), saved);
  });

  test('R4 the components as the file holds them', () {
    final r = withEveryComponent();
    addTearDown(r.doc.dispose);
    final saved = DraftDocumentCodec.encodeToString(r.doc);
    final root = r.doc.rootHandle.value;
    expect(
        saved,
        contains('"jetcad.unit":{"${r.def.value}":'
            '{"capacity":4,"kind":"table","labelling":"numbered"}}'));
    expect(
        saved,
        contains('"jetcad.manifest":{"$root":{"format":1,'
            '"kits":{"architecture":"0.1.0","sample":"0.3.1"}}}'));
    expect(saved,
        contains('"jetcad.library":{"$root":{"format":1,"kit":"sample"}}'));
  });
}
```

- [ ] **Step 2: Run them to see them fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model/library_component_test.dart test/model/manifest_component_test.dart test/model/register_test.dart`. Expected: compilation errors (`Undefined class 'LibraryComponent'`).

- [ ] **Step 3: `LibraryComponent`.** Create `lib/src/model/library_component.dart`:

```dart
// The library component (spec K2, K3): on a library's root, the kit whose
// symbols the library holds and the library format.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// A library's kit and format, on its root.
@immutable
final class LibraryComponent implements Component {
  /// Throws [ArgumentError] when [kit] is not a kit id or [format] is below
  /// 1. A format above 1 is constructed and refused by the validator.
  LibraryComponent({required this.kit, this.format = 1}) {
    if (!isKitId(kit)) {
      throw ArgumentError.value(kit, 'kit', 'must be a kit id');
    }
    if (format < 1) {
      throw ArgumentError.value(format, 'format', 'must be at least 1');
    }
  }

  static const String componentTypeId = 'jetcad.library';

  final String kit;
  final int format;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'format': format, 'kit': kit};

  static LibraryComponent fromJson(Map<String, Object?> json) {
    const t = 'LibraryComponent';
    return LibraryComponent(
      kit: field<String>(json, 'kit', t),
      format: field<int>(json, 'format', t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryComponent && other.kit == kit && other.format == format;

  @override
  int get hashCode => Object.hash(kit, format);

  @override
  String toString() => 'LibraryComponent($kit, format $format)';
}
```

- [ ] **Step 4: `ManifestComponent`.** Create `lib/src/model/manifest_component.dart`:

```dart
// The plan manifest (spec K2, umbrella A8): on a plan's root, the plan
// format and, per kit the plan uses, the version that last saved it.
// Defined here; the plan library writes and checks it (sub-project 2).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:collection';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// A plan's format and its kits' versions, on its root.
@immutable
final class ManifestComponent implements Component {
  /// Throws [ArgumentError] when [format] is below 1, a key of [kits] is not
  /// a kit id or a version is empty. [kits] is copied, sorted by kit id.
  ManifestComponent({this.format = 1, required Map<String, String> kits})
      : kits = Map.unmodifiable(SplayTreeMap<String, String>.of(kits)) {
    if (format < 1) {
      throw ArgumentError.value(format, 'format', 'must be at least 1');
    }
    for (final MapEntry(:key, :value) in this.kits.entries) {
      if (!isKitId(key)) {
        throw ArgumentError.value(key, 'kits', 'names a kit id it is not');
      }
      if (value.trim().isEmpty) {
        throw ArgumentError.value(
            value, 'kits', 'gives the kit "$key" an empty version');
      }
    }
  }

  static const String componentTypeId = 'jetcad.manifest';

  final int format;

  /// Kit id → the kit's version that last saved the plan, sorted by id.
  final Map<String, String> kits;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'format': format, 'kits': {...kits}};

  static ManifestComponent fromJson(Map<String, Object?> json) {
    const t = 'ManifestComponent';
    final raw = field<Map<Object?, Object?>>(json, 'kits', t);
    final kits = <String, String>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is! String || value is! String) {
        throw FormatException('$t: "kits" maps $key to $value; both must be '
            'strings');
      }
      kits[key] = value;
    }
    return ManifestComponent(format: field<int>(json, 'format', t), kits: kits);
  }

  @override
  bool operator ==(Object other) {
    if (other is! ManifestComponent ||
        other.format != format ||
        other.kits.length != kits.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in kits.entries) {
      if (other.kits[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(format,
      Object.hashAll([for (final e in kits.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'ManifestComponent(format $format, $kits)';
}
```

- [ ] **Step 5: The registration.** Create `lib/src/model/register.dart`:

```dart
// The contract's registry function (spec K2): the four contract components
// and nothing else. The wrapped form lets the library decoder (K3) read
// through guarded factories while registering exactly the same types.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'library_component.dart';
import 'manifest_component.dart';
import 'symbol_component.dart';
import 'unit_component.dart';

/// Reads one component of type [T]: [read] is its `fromJson`, [typeId] its
/// type id. Not exported.
typedef ComponentRead = T Function<T extends Component>(String typeId,
    Map<String, Object?> json, T Function(Map<String, Object?> json) read);

/// Registers `jetcad.library`, `jetcad.manifest`, `jetcad.symbol` and
/// `jetcad.unit` on [registry], and nothing else. Once per registry:
/// `register` replaces a type's store.
void registerKitComponents(ComponentRegistry registry) =>
    registerKitComponentsWrapped(registry, _direct);

/// [registerKitComponents] with every factory read through [read]. Not
/// exported.
void registerKitComponentsWrapped(
    ComponentRegistry registry, ComponentRead read) {
  registry
    ..register<LibraryComponent>(
        LibraryComponent.componentTypeId,
        (json) => read(
            LibraryComponent.componentTypeId, json, LibraryComponent.fromJson))
    ..register<ManifestComponent>(
        ManifestComponent.componentTypeId,
        (json) => read(ManifestComponent.componentTypeId, json,
            ManifestComponent.fromJson))
    ..register<SymbolComponent>(
        SymbolComponent.componentTypeId,
        (json) => read(
            SymbolComponent.componentTypeId, json, SymbolComponent.fromJson))
    ..register<UnitComponent>(
        UnitComponent.componentTypeId,
        (json) =>
            read(UnitComponent.componentTypeId, json, UnitComponent.fromJson));
}

T _direct<T extends Component>(String typeId, Map<String, Object?> json,
        T Function(Map<String, Object?> json) read) =>
    read(json);
```

In `lib/src/model/model.dart`, the list becomes:

```dart
export 'kit_ids.dart';
export 'library_component.dart';
export 'manifest_component.dart';
export 'register.dart' show registerKitComponents;
export 'symbol_component.dart';
export 'unit_component.dart';
```

- [ ] **Step 6: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model test/invariants`. Expected: `All tests passed!` (P1 now walks the new files and reaches them through `model.dart`).

- [ ] **Step 7: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-L1 (drop the `format < 1` check) → L1 red; M-L3 (drop `&& other.format == format`) → L3 red; M-MF2 (`kits = Map.unmodifiable(kits)` without the `SplayTreeMap`) → MF2 red; M-MF3 (compare `other.kits.keys.toSet()` with `kits.keys.toSet()` only) → MF3 red; M-R1 (add `registry.registerBuiltIns();` at the top of `registerKitComponentsWrapped`) → R1 red; M-R2 (omit the `UnitComponent` registration) → R2 red. Quote each red line.

- [ ] **Step 8: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/model/library_component.dart packages/jet_cad_2d_kit/lib/src/model/manifest_component.dart packages/jet_cad_2d_kit/lib/src/model/register.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/test/model/library_component_test.dart packages/jet_cad_2d_kit/test/model/manifest_component_test.dart packages/jet_cad_2d_kit/test/model/register_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): LibraryComponent, ManifestComponent, registerKitComponents (K2)

jetcad.library names a library's kit and format; jetcad.manifest holds a
plan's format and its kits' versions, sorted by kit id. The registry
function registers the four contract components and nothing else; a
document carrying them round-trips byte for byte, and without the
registration keeps them verbatim.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
