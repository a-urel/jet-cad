### Task 2: Identifiers, `SymbolComponent` and `UnitComponent` (K2)

**Files:**
- Create: `packages/jet_cad_2d_kit/lib/src/model/kit_ids.dart`, `lib/src/model/json_fields.dart`, `lib/src/model/symbol_component.dart`, `lib/src/model/unit_component.dart`, `lib/src/model/model.dart`
- Modify: `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart`, `packages/jet_cad_2d_kit/lib/authoring.dart` (add `export 'src/model/model.dart';`)
- Test: `packages/jet_cad_2d_kit/test/model/kit_ids_test.dart`, `test/model/symbol_component_test.dart`, `test/model/unit_component_test.dart`

(All paths below are under `packages/jet_cad_2d_kit/` unless they start at the repository root.)

**Interfaces:**
- Consumes: `Component`, `listEquals` from `package:jet_cad_2d/jet_cad_2d.dart`.
- Produces (exported from both barrels through `model.dart`):
  - `bool isKitId(String id)`, `bool isKind(String kind)`, `bool isSymbolKey(String key)`, `String kitOfKey(String id)`.
  - `final class SymbolComponent implements Component` — `static const String componentTypeId = 'jetcad.symbol'`; `SymbolComponent({required String key, required int version, required String name, required String category, required List<String> tags, List<String> attachTo = const [], String? family})`; fields `key`, `version`, `name`, `category`, `tags`, `attachTo`, `family`; `String get id` (`'$key@$version'`); `static SymbolComponent fromJson(Map<String, Object?> json)`.
  - `enum UnitLabelling { numbered, assigned }`; `abstract final class UnitKinds { static const String table = 'table'; static const String seat = 'seat'; }`; `final class UnitComponent implements Component` — `static const String componentTypeId = 'jetcad.unit'`; `UnitComponent({required String kind, required int capacity, UnitLabelling labelling = UnitLabelling.numbered})`; `static UnitComponent fromJson(Map<String, Object?> json)`.
  - Not exported: `T field<T>(Map<String, Object?> json, String key, String type)` and `List<String> stringList(Map<String, Object?> json, String key, String type)` in `json_fields.dart` (each throws `FormatException` naming `"<key>"`).

Plan decision: a symbol key must also have a kit id as its first segment (K2's words "the kit id, then"), not only match K2's regex — the regex alone admits `my-kit.a.b`.
Plan decision: a tag must not have outer white space (`' couch'` is refused) — two tags differing only in a leading space would read as duplicates in a gallery.
Plan decision: `family` is always written, `null` when absent, and every field is required by `fromJson` — one fixed key set, as K2's fixed key order implies; a field `fromJson` does not know is ignored (a newer toolkit's field does not break an older reader).

- [ ] **Step 1: Write the failing tests.** Create `test/model/kit_ids_test.dart`:

```dart
// Spec K2: the identifier patterns. Each list holds the edge a plausible
// mutation of the pattern lets through.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('I1 a kit id is a lower-case letter, then letters and digits', () {
    for (final id in ['restaurant', 'a', 'kit2', 'architecture']) {
      expect(isKitId(id), isTrue, reason: id);
    }
    // M-I1: `^[a-z0-9][a-z0-9]*$` lets '2kit' through.
    for (final id in [
      '',
      '2kit',
      'Restaurant',
      'my-kit',
      'my_kit',
      'a.b',
      'kit ',
      'kit\n',
    ]) {
      expect(isKitId(id), isFalse, reason: id);
    }
  });

  test('I2 a kind is lower-case letters and digits joined by single hyphens',
      () {
    for (final kind in ['wall-face', 'table', 'seat', 'bed-double', 'a1-2b']) {
      expect(isKind(kind), isTrue, reason: kind);
    }
    // M-I2: `^[a-z0-9-]+$` lets 'wall--face', '-wall' and 'wall-' through.
    for (final kind in [
      '',
      'Wall-face',
      'wall--face',
      '-wall',
      'wall-',
      'wall face',
      'wall_face',
      'wall.face',
      'wall-face\n',
    ]) {
      expect(isKind(kind), isFalse, reason: kind);
    }
  });

  test('I3 a key is a kit id, then two or more segments', () {
    for (final key in [
      'restaurant.table.rect',
      'restaurant.table.rect.four',
      'sample.table.high-top',
      'sample.a1.b-2.c',
    ]) {
      expect(isSymbolKey(key), isTrue, reason: key);
    }
    for (final key in [
      'restaurant.table', // M-I3a: `{1,}` in place of `{2,}`
      'restaurant',
      'Restaurant.table.rect',
      'my-kit.table.rect', // M-I3b: the kit-id check on the first segment dropped
      '2kit.table.rect', // M-I3b too
      'restaurant..table.rect',
      'restaurant.table.rect.',
      'restaurant.table rect.x',
      'restaurant.Table.rect',
      'restaurant.table.rect\n',
    ]) {
      expect(isSymbolKey(key), isFalse, reason: key);
    }
  });

  test('I4 kitOfKey is the first dot-separated segment', () {
    expect(kitOfKey('restaurant.table.rect'), 'restaurant');
    expect(kitOfKey('architecture.wall'), 'architecture');
    expect(kitOfKey('wall'), 'wall');
  });
}
```

Create `test/model/symbol_component_test.dart`:

```dart
// Spec K2: the symbol identity. Every field refused in the constructor
// (ArgumentError, never an assert), every field in equality, a pinned JSON
// text, fromJson refusals one field at a time (ported from
// jet_cad_floor_plan's symbol_component_test SC1-SC6).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

/// Every field away from its default: version 3, three unsorted tags, two
/// attachment kinds, a family.
SymbolComponent sofa({
  String key = 'sample.sofa.three',
  int version = 3,
  String name = 'Three-seat sofa',
  String category = 'Living Room',
  List<String> tags = const ['sofa', 'seating', 'couch'],
  List<String> attachTo = const ['wall-face', 'room-corner'],
  String? family = 'sofa-long',
  bool noFamily = false,
}) =>
    SymbolComponent(
      key: key,
      version: version,
      name: name,
      category: category,
      tags: tags,
      attachTo: attachTo,
      family: noFamily ? null : family,
    );

Matcher refusedOn(String field) =>
    throwsA(isA<ArgumentError>().having((e) => e.name, 'name', field));

const Map<String, Object?> full = {
  'attachTo': ['wall-face', 'room-corner'],
  'category': 'Living Room',
  'family': 'sofa-long',
  'key': 'sample.sofa.three',
  'name': 'Three-seat sofa',
  'tags': ['sofa', 'seating', 'couch'],
  'version': 3,
};

void main() {
  group('value semantics', () {
    test('C1 equality sees every field, each differing once', () {
      expect(sofa(), sofa());
      expect(sofa().hashCode, sofa().hashCode);
      expect(sofa(), isNot(sofa(key: 'sample.sofa.four')));
      expect(sofa(), isNot(sofa(version: 4)));
      expect(sofa(), isNot(sofa(name: 'Four-seat sofa')));
      expect(sofa(), isNot(sofa(category: 'Office')));
      expect(sofa(), isNot(sofa(tags: const ['sofa', 'seating'])));
      // M-C1 (the spec's own): drop attachTo from == and this goes red.
      expect(sofa(), isNot(sofa(attachTo: const ['wall-face'])));
      expect(sofa(), isNot(sofa(family: 'sofa-short')));
      expect(sofa(), isNot(sofa(noFamily: true)));
    });

    test('C2 tag and attachment order matter', () {
      expect(sofa(), isNot(sofa(tags: const ['couch', 'sofa', 'seating'])));
      expect(sofa(),
          isNot(sofa(attachTo: const ['room-corner', 'wall-face'])));
    });

    test('C3 tags and attachTo are unmodifiable copies', () {
      final tags = ['sofa', 'seating', 'couch'];
      final kinds = ['wall-face'];
      final s = sofa(tags: tags, attachTo: kinds);
      tags[0] = 'mutated';
      kinds[0] = 'mutated';
      expect(s.tags, ['sofa', 'seating', 'couch']);
      expect(s.attachTo, ['wall-face']);
      expect(() => s.tags.add('x'), throwsUnsupportedError);
      expect(() => s.attachTo.add('x'), throwsUnsupportedError);
    });

    test('C4 id is key@version and typeId is jetcad.symbol', () {
      expect(sofa().id, 'sample.sofa.three@3');
      expect(sofa().typeId, 'jetcad.symbol');
      expect(SymbolComponent.componentTypeId, 'jetcad.symbol');
    });
  });

  group('constructor refusals, named by field', () {
    final cases = <String, (String, SymbolComponent Function())>{
      'a key of two segments': ('key', () => sofa(key: 'sample.sofa')),
      'an upper-case key': ('key', () => sofa(key: 'sample.Sofa.three')),
      'a key with a space': ('key', () => sofa(key: 'sample.sofa three.x')),
      'a key whose kit id has a hyphen': (
        'key',
        () => sofa(key: 'my-kit.sofa.three')
      ),
      'version 0': ('version', () => sofa(version: 0)),
      'version -2': ('version', () => sofa(version: -2)),
      'an empty name': ('name', () => sofa(name: '')),
      'a blank name': ('name', () => sofa(name: '   ')),
      'an empty category': ('category', () => sofa(category: '')),
      'an upper-case tag': ('tags', () => sofa(tags: const ['sofa', 'Seating'])),
      'an empty tag': ('tags', () => sofa(tags: const ['sofa', ''])),
      'a tag with outer white space': (
        'tags',
        () => sofa(tags: const ['sofa', ' couch'])
      ),
      'a repeated tag': ('tags', () => sofa(tags: const ['sofa', 'x', 'sofa'])),
      'an upper-case target kind': (
        'attachTo',
        () => sofa(attachTo: const ['Wall-face'])
      ),
      'a target kind with a space': (
        'attachTo',
        () => sofa(attachTo: const ['wall face'])
      ),
      'a repeated target kind': (
        'attachTo',
        () => sofa(attachTo: const ['wall-face', 'wall-face'])
      ),
      'an upper-case family': ('family', () => sofa(family: 'Sofa-long')),
      'an empty family': ('family', () => sofa(family: '')),
      'a family with a double hyphen': (
        'family',
        () => sofa(family: 'sofa--long')
      ),
    };
    // M-C5: delete any one check of the constructor; its case goes red.
    for (final MapEntry(key: what, value: (field, make)) in cases.entries) {
      test('C5 $what is refused on "$field"', () {
        expect(make, refusedOn(field));
      });
    }

    test('C6 the allowed edges are accepted', () {
      expect(sofa(version: 1).version, 1);
      // Review Focus 2. M-C6: an ASCII-only tag pattern refuses these.
      expect(sofa(tags: const ['bar stool', 'çocuk', 'ışık']).tags,
          ['bar stool', 'çocuk', 'ışık']);
      expect(sofa(tags: const []).tags, isEmpty);
      expect(sofa(attachTo: const []).attachTo, isEmpty);
      expect(sofa(noFamily: true).family, isNull);
      expect(sofa(key: 'sample.table.high-top.x2').key,
          'sample.table.high-top.x2');
    });
  });

  group('JSON', () {
    test('C7 the key order and the text are pinned', () {
      expect(sofa().toJson().keys.toList(),
          ['attachTo', 'category', 'family', 'key', 'name', 'tags', 'version']);
      // M-C7: write the keys in declaration order; the text differs.
      expect(
          jsonEncode(sofa().toJson()),
          '{"attachTo":["wall-face","room-corner"],"category":"Living Room",'
          '"family":"sofa-long","key":"sample.sofa.three",'
          '"name":"Three-seat sofa","tags":["sofa","seating","couch"],'
          '"version":3}');
      expect(jsonEncode(sofa(noFamily: true).toJson()),
          contains('"family":null,'));
    });

    test('C8 fromJson reads back what toJson wrote', () {
      for (final s in [sofa(), sofa(noFamily: true, attachTo: const [])]) {
        final back = SymbolComponent.fromJson(
            (jsonDecode(jsonEncode(s.toJson())) as Map)
                .cast<String, Object?>());
        expect(back, s);
      }
      expect(SymbolComponent.fromJson(full), sofa());
    });

    // M-C9: a default in place of any one missing field turns its case red.
    for (final field in full.keys) {
      test('C9 fromJson refuses a map without "$field"', () {
        final json = {...full}..remove(field);
        expect(
            () => SymbolComponent.fromJson(json),
            throwsA(isA<FormatException>()
                .having((e) => e.message, 'message', contains('"$field"'))));
      });
    }

    final mistyped = <String, Object?>{
      'version': '3',
      'tags': 'sofa',
      'attachTo': null,
      'family': 4,
      'key': 7,
    };
    // M-C10: an `as` cast in place of the type check throws a TypeError.
    for (final MapEntry(key: field, value: value) in mistyped.entries) {
      test('C10 fromJson refuses "$field": $value with a FormatException', () {
        expect(() => SymbolComponent.fromJson({...full, field: value}),
            throwsFormatException);
      });
    }
    test('C10 a tag that is not a string is a FormatException', () {
      expect(
          () => SymbolComponent.fromJson({
                ...full,
                'tags': ['sofa', 3],
              }),
          throwsFormatException);
    });

    test("C11 a pattern refusal on read is the constructor's ArgumentError",
        () {
      expect(
          () => SymbolComponent.fromJson({...full, 'key': 'Sample.sofa.three'}),
          refusedOn('key'));
    });

    test('C12 a field this build does not know is ignored', () {
      // Review Focus 3. M-C12: refuse unknown keys; this goes red.
      expect(SymbolComponent.fromJson({...full, 'newerField': 1}), sofa());
    });
  });
}
```

Create `test/model/unit_component_test.dart`:

```dart
// Spec K2 and umbrella A6: the service unit (ported from
// jet_cad_floor_plan's seating_test SE1-SE3, `seats` now `capacity`).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

UnitComponent table({
  String kind = UnitKinds.table,
  int capacity = 6,
  UnitLabelling labelling = UnitLabelling.numbered,
}) =>
    UnitComponent(kind: kind, capacity: capacity, labelling: labelling);

void main() {
  test('U1 refusals: a kind off the pattern, a capacity below one', () {
    // M-U1: drop either check; its line goes red.
    expect(() => table(kind: 'Table'),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kind')));
    expect(() => table(kind: 'bar table'), throwsArgumentError);
    expect(() => table(capacity: 0),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'capacity')));
    expect(() => table(capacity: -4), throwsArgumentError);
    expect(table(capacity: 1).capacity, 1);
    expect(table(kind: 'bed-space').kind, 'bed-space');
  });

  test('U2 the named kinds and the default labelling', () {
    expect(UnitKinds.table, 'table');
    expect(UnitKinds.seat, 'seat');
    expect(UnitComponent(kind: UnitKinds.seat, capacity: 1).labelling,
        UnitLabelling.numbered);
  });

  test('U3 equality sees every field', () {
    expect(table(), table());
    expect(table().hashCode, table().hashCode);
    expect(table(), isNot(table(kind: UnitKinds.seat)));
    expect(table(), isNot(table(capacity: 5)));
    // M-U3: drop labelling from ==.
    expect(table(), isNot(table(labelling: UnitLabelling.assigned)));
  });

  test('U4 the JSON text is pinned and reads back', () {
    expect(table().typeId, 'jetcad.unit');
    expect(jsonEncode(table().toJson()),
        '{"capacity":6,"kind":"table","labelling":"numbered"}');
    final seat = table(
        kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned);
    expect(jsonEncode(seat.toJson()),
        '{"capacity":1,"kind":"seat","labelling":"assigned"}');
    expect(UnitComponent.fromJson(seat.toJson()), seat);
  });

  test('U5 fromJson refusals', () {
    const full = <String, Object?>{
      'capacity': 6,
      'kind': 'table',
      'labelling': 'numbered',
    };
    expect(UnitComponent.fromJson(full), table());
    for (final field in full.keys) {
      expect(() => UnitComponent.fromJson({...full}..remove(field)),
          throwsFormatException,
          reason: field);
    }
    // M-U5: `UnitLabelling.values.byName` throws an ArgumentError instead.
    expect(() => UnitComponent.fromJson({...full, 'labelling': 'random'}),
        throwsFormatException);
    expect(() => UnitComponent.fromJson({...full, 'capacity': '6'}),
        throwsFormatException);
    expect(() => UnitComponent.fromJson({...full, 'capacity': 0}),
        throwsArgumentError);
  });
}
```

- [ ] **Step 2: Run them to see them fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model`. Expected: compilation errors (`Undefined name 'isKitId'`, `Undefined class 'SymbolComponent'`).

- [ ] **Step 3: The identifiers.** Create `lib/src/model/kit_ids.dart`:

```dart
// The identifier patterns of the kit contract (spec K2, umbrella A7).
//
// Pure Dart: no Flutter, no dart:io.

final RegExp _kitId = RegExp(r'^[a-z][a-z0-9]*$');
final RegExp _kind = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final RegExp _key =
    RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*){2,}$');

/// Whether [id] is a kit id: a lower-case letter, then lower-case letters
/// and digits. No dot and no hyphen: it is the first segment of every key,
/// type id and tool id.
bool isKitId(String id) => _kitId.hasMatch(id);

/// Whether [kind] is a target kind, a size family or a unit kind: lower-case
/// letters and digits joined by single hyphens.
bool isKind(String kind) => _kind.hasMatch(kind);

/// Whether [key] is a symbol key: a kit id, then two or more dot-separated
/// segments, each lower-case letters and digits joined by single hyphens.
bool isSymbolKey(String key) => _key.hasMatch(key) && isKitId(kitOfKey(key));

/// The first dot-separated segment of [id] (a key, a type id or a tool id):
/// its kit. [id] itself when it holds no dot.
String kitOfKey(String id) {
  final dot = id.indexOf('.');
  return dot < 0 ? id : id.substring(0, dot);
}
```

- [ ] **Step 4: The JSON field readers.** Create `lib/src/model/json_fields.dart`:

```dart
// Reading a component's JSON (spec K2): a missing or mistyped field is a
// FormatException naming it, never a TypeError from an `as` cast.
//
// Pure Dart: no Flutter, no dart:io. Not exported.

/// [json]'s value at [key], which must be present and a [T] (a nullable [T]
/// admits null). [type] names the component in the message.
T field<T>(Map<String, Object?> json, String key, String type) {
  if (!json.containsKey(key)) {
    throw FormatException('$type: missing "$key"');
  }
  final value = json[key];
  if (value is! T) {
    throw FormatException('$type: "$key" is not a $T: $value');
  }
  return value;
}

/// [json]'s list of strings at [key].
List<String> stringList(Map<String, Object?> json, String key, String type) {
  final list = field<List<Object?>>(json, key, type);
  return [
    for (final item in list)
      item is String
          ? item
          : throw FormatException('$type: "$key" holds $item, not a string'),
  ];
}
```

- [ ] **Step 5: `SymbolComponent`.** Create `lib/src/model/symbol_component.dart`:

```dart
// The symbol identity (spec K2): what a definition is, in a library and,
// once copied, in a plan. On a definition's handle. Ported from
// jet_cad_floor_plan's SymbolComponent, with K2's patterns, the attachment
// kinds and the size family as fields (umbrella A5).
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// A symbol's identity and display data, on a definition's handle.
///
/// Immutable and value-equal, [tags] and [attachTo] compared in order;
/// [toJson] keys are alphabetical. Every bad value is an [ArgumentError]
/// from the constructor, named by its field.
@immutable
final class SymbolComponent implements Component {
  /// Throws [ArgumentError] (never an assert: a release build refuses too)
  /// when a field breaks spec K2.
  SymbolComponent({
    required this.key,
    required this.version,
    required this.name,
    required this.category,
    required List<String> tags,
    List<String> attachTo = const [],
    this.family,
  })  : tags = List.unmodifiable(tags),
        attachTo = List.unmodifiable(attachTo) {
    if (!isSymbolKey(key)) {
      throw ArgumentError.value(
          key,
          'key',
          'must be a kit id, then two or more dot-separated segments of '
              'lower-case letters and digits joined by single hyphens');
    }
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'must be at least 1');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'must not be empty');
    }
    final seenTags = <String>{};
    for (final tag in this.tags) {
      if (tag.isEmpty || tag.trim() != tag || tag != tag.toLowerCase()) {
        throw ArgumentError.value(tag, 'tags',
            'must be lower case, not empty, without outer white space');
      }
      if (!seenTags.add(tag)) {
        throw ArgumentError.value(tag, 'tags', 'is repeated');
      }
    }
    final seenKinds = <String>{};
    for (final kind in this.attachTo) {
      if (!isKind(kind)) {
        throw ArgumentError.value(kind, 'attachTo',
            'must be lower-case letters and digits joined by single hyphens');
      }
      if (!seenKinds.add(kind)) {
        throw ArgumentError.value(kind, 'attachTo', 'is repeated');
      }
    }
    final f = family;
    if (f != null && !isKind(f)) {
      throw ArgumentError.value(f, 'family',
          'must be lower-case letters and digits joined by single hyphens');
    }
  }

  static const String componentTypeId = 'jetcad.symbol';

  /// The kit id, then two or more segments: `restaurant.table.rect.four`.
  final String key;

  /// At least 1. A published `key@version` never changes its geometry or
  /// its unit (umbrella A16).
  final int version;

  /// English; a kit's words translate it (K4).
  final String name;

  /// English; a kit's words translate it (K4).
  final String category;

  /// Search words only, lower case, no duplicates. They carry no behaviour.
  final List<String> tags;

  /// The attachment target kinds this symbol attaches to (umbrella A5);
  /// empty for none.
  final List<String> attachTo;

  /// The size family this symbol belongs to, or null.
  final String? family;

  /// `key@version`, the definition's name in a library.
  String get id => '$key@$version';

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'attachTo': attachTo,
        'category': category,
        'family': family,
        'key': key,
        'name': name,
        'tags': tags,
        'version': version,
      };

  /// Throws [FormatException] for a missing or mistyped field, and the
  /// constructor's [ArgumentError] for a value K2 refuses. A field this
  /// build does not know is ignored.
  static SymbolComponent fromJson(Map<String, Object?> json) {
    const t = 'SymbolComponent';
    return SymbolComponent(
      key: field<String>(json, 'key', t),
      version: field<int>(json, 'version', t),
      name: field<String>(json, 'name', t),
      category: field<String>(json, 'category', t),
      tags: stringList(json, 'tags', t),
      attachTo: stringList(json, 'attachTo', t),
      family: field<String?>(json, 'family', t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SymbolComponent &&
      other.key == key &&
      other.version == version &&
      other.name == name &&
      other.category == category &&
      listEquals(other.tags, tags) &&
      listEquals(other.attachTo, attachTo) &&
      other.family == family;

  @override
  int get hashCode => Object.hash(key, version, name, category,
      Object.hashAll(tags), Object.hashAll(attachTo), family);

  @override
  String toString() => 'SymbolComponent($id, $name, $category)';
}
```

- [ ] **Step 6: `UnitComponent`.** Create `lib/src/model/unit_component.dart`:

```dart
// The service unit (spec K2, umbrella A6): a symbol definition that carries
// one is served -- a table, a seat -- with its capacity and how its label is
// formed. On a definition's handle. Replaces jet_cad_floor_plan's
// SeatingComponent.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// How a placed unit's label is formed.
enum UnitLabelling {
  /// The plan gives a placed unit the next free number (a table).
  numbered,

  /// A kit's type sets the label (a seat in a row).
  assigned,
}

/// The unit kinds the contract names. Others are allowed.
abstract final class UnitKinds {
  static const String table = 'table';
  static const String seat = 'seat';
}

/// A served unit: its [kind], its [capacity] and its [labelling].
@immutable
final class UnitComponent implements Component {
  /// Throws [ArgumentError] when [kind] breaks K2's kind pattern or
  /// [capacity] is below 1.
  UnitComponent({
    required this.kind,
    required this.capacity,
    this.labelling = UnitLabelling.numbered,
  }) {
    if (!isKind(kind)) {
      throw ArgumentError.value(kind, 'kind',
          'must be lower-case letters and digits joined by single hyphens');
    }
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be at least 1');
    }
  }

  static const String componentTypeId = 'jetcad.unit';

  final String kind;
  final int capacity;
  final UnitLabelling labelling;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'capacity': capacity,
        'kind': kind,
        'labelling': labelling.name,
      };

  /// Throws [FormatException] for a missing or mistyped field or an unknown
  /// labelling, and the constructor's [ArgumentError] for a bad value.
  static UnitComponent fromJson(Map<String, Object?> json) {
    const t = 'UnitComponent';
    final name = field<String>(json, 'labelling', t);
    final labelling = UnitLabelling.values.asNameMap()[name];
    if (labelling == null) {
      throw FormatException('$t: "labelling" is not a labelling: $name');
    }
    return UnitComponent(
      kind: field<String>(json, 'kind', t),
      capacity: field<int>(json, 'capacity', t),
      labelling: labelling,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UnitComponent &&
      other.kind == kind &&
      other.capacity == capacity &&
      other.labelling == labelling;

  @override
  int get hashCode => Object.hash(kind, capacity, labelling);

  @override
  String toString() => 'UnitComponent($kind, $capacity, ${labelling.name})';
}
```

- [ ] **Step 7: The model's export list and the barrels.** Create `lib/src/model/model.dart`:

```dart
// The model's single export list: both public libraries export this file,
// so the contract and the authoring toolkit carry the same model.
export 'kit_ids.dart';
export 'symbol_component.dart';
export 'unit_component.dart';
```

In `lib/jet_cad_2d_kit.dart` and in `lib/authoring.dart`, add after `library;`:

```dart

export 'src/model/model.dart';
```

- [ ] **Step 8: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/model test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 9: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-I1, M-I2, M-I3a, M-I3b as commented in `kit_ids_test.dart` (each turns its I-test red); M-C1 (remove `listEquals(other.attachTo, attachTo) &&`) → C1 red; M-C5 (delete the `seenTags.add` check) → C5 "a repeated tag" red; M-C6 (replace the tag condition with `!RegExp(r'^[a-z ]+$').hasMatch(tag)`) → C6 red; M-C7 (swap `'key'` and `'family'` in `toJson`) → C7 red; M-C9 (`family: json['family'] as String?` without `field`) → C9 `"family"` red; M-C10 (`version: json['version']! as int`) → C10 `"version"` red; M-U3 (drop `other.labelling == labelling`) → U3 red; M-U5 (`UnitLabelling.values.byName(name)`) → U5 red. Quote each red line.

- [ ] **Step 10: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/lib/authoring.dart packages/jet_cad_2d_kit/lib/src/model/kit_ids.dart packages/jet_cad_2d_kit/lib/src/model/json_fields.dart packages/jet_cad_2d_kit/lib/src/model/symbol_component.dart packages/jet_cad_2d_kit/lib/src/model/unit_component.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/test/model/kit_ids_test.dart packages/jet_cad_2d_kit/test/model/symbol_component_test.dart packages/jet_cad_2d_kit/test/model/unit_component_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the identifier patterns, SymbolComponent and UnitComponent (K2)

jetcad.symbol carries the key under its kit id, the attachment kinds and
the size family as fields; jetcad.unit carries the unit's kind, capacity
and labelling. Both refuse bad values with ArgumentError, compare every
field and write their keys in alphabetical order.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
