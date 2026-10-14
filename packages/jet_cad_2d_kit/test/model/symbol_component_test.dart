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
  bool retired = false,
}) =>
    SymbolComponent(
      key: key,
      version: version,
      name: name,
      category: category,
      tags: tags,
      attachTo: attachTo,
      family: noFamily ? null : family,
      retired: retired,
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
      expect(sofa(), isNot(sofa(attachTo: const ['room-corner', 'wall-face'])));
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
      'an upper-case tag': (
        'tags',
        () => sofa(tags: const ['sofa', 'Seating'])
      ),
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

  group('retired (contract R2)', () {
    test('R2-1 written only when true, in its alphabetical place', () {
      expect(sofa().retired, isFalse);
      // M-R2a: always write the key; C7's pinned text goes red too.
      expect(sofa().toJson().containsKey('retired'), isFalse);
      expect(sofa(retired: true).toJson().keys.toList(), [
        'attachTo',
        'category',
        'family',
        'key',
        'name',
        'retired',
        'tags',
        'version',
      ]);
      expect(
          jsonEncode(sofa(retired: true).toJson()),
          '{"attachTo":["wall-face","room-corner"],"category":"Living Room",'
          '"family":"sofa-long","key":"sample.sofa.three",'
          '"name":"Three-seat sofa","retired":true,'
          '"tags":["sofa","seating","couch"],"version":3}');
    });

    test('R2-2 absent reads false; present must be a bool', () {
      // M-R2b: read it with `field` (required): a map without it, every
      // library and plan saved before R2, is refused.
      expect(SymbolComponent.fromJson(full).retired, isFalse);
      expect(SymbolComponent.fromJson({...full, 'retired': true}),
          sofa(retired: true));
      expect(SymbolComponent.fromJson({...full, 'retired': false}), sofa());
      // M-R2c: `json['retired'] == true` (anything else reads false).
      for (final bad in <Object?>['true', 1, null]) {
        expect(() => SymbolComponent.fromJson({...full, 'retired': bad}),
            throwsFormatException,
            reason: '$bad');
      }
    });

    test('R2-3 equality and the hash see it', () {
      // M-R2d: drop `retired` from ==.
      expect(sofa(retired: true), isNot(sofa()));
      expect(sofa(retired: true), sofa(retired: true));
      expect(sofa(retired: true).hashCode, sofa(retired: true).hashCode);
      expect('${sofa(retired: true)}', endsWith(', retired)'));
    });

    test('R2-4 it reads back through JSON text', () {
      final s = sofa(retired: true, noFamily: true);
      expect(
          SymbolComponent.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map)
              .cast<String, Object?>()),
          s);
    });
  });
}
