// Spec 09 D5, plan 09a Task 3: the loader that validates. Every rule has its
// own case, built by editing the codec's JSON of a valid library one fault at
// a time (so a case can only go red through its own rule), and a positive
// control proving the rule is not over-strict.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../support/symbol_fixtures.dart';

/// Stands for a non-finite number: JSON has none, but Dart's `jsonDecode`
/// reads `1e999` as infinity, so the sentinel is replaced by text.
const double kSentinel = 7777.125;
const Map<String, String> kInfinity = {'7777.125': '1e999'};
const Map<String, String> kNegInfinity = {'7777.125': '-1e999'};

String hex(int handle) => Handle(handle).toHex();

/// Decoding [bytes] throws a [SymbolLibraryError] whose message holds every
/// one of [parts].
void expectRejected(Uint8List bytes, List<String> parts) {
  try {
    SymbolLibrary.decode(bytes);
  } on SymbolLibraryError catch (e) {
    for (final p in parts) {
      expect(e.message, contains(p), reason: 'message: ${e.message}');
    }
    return;
  }
  fail('the library was accepted; expected a rejection naming $parts');
}

void main() {
  group('a valid library', () {
    test('L1 lists every entry with every field equal to what was built', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(lib.entries.map((e) => e.key).toList(),
          ['sofa.three', 'nightstand.single', 'armchair.single']);
      final built = buildValidLibrary();
      final want = {
        sofaDef: (sofaSymbol(), 'sofa.three@3', 900.0, 400.0),
        nightstandDef: (nightstandSymbol(), 'nightstand.single@2', 250.0, 60.0),
        armchairDef: (armchairSymbol(), 'armchair.single@1', 510.0, 0.0),
      };
      for (final e in lib.entries) {
        final (c, name, bx, by) = want[e.definition.handle]!;
        expect(e.key, c.key);
        expect(e.name, c.name);
        expect(e.category, c.category);
        expect(e.tags, c.tags);
        expect(e.version, c.version);
        expect(e.definition.name, name);
        expect(e.definition.basePoint.x, bx);
        expect(e.definition.basePoint.y, by);
        expect(e.definition, built.tree.definition(e.definition.handle));
        // The leaves, field for field against the fixture.
        final expected = fixtureLeaves()
            .where((l) => l.record.owner == e.definition.handle)
            .toList()
          ..sort(
              (a, b) => a.record.handle.value.compareTo(b.record.handle.value));
        expect(e.leaves.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          expect(e.leaves[i].record.copyWith(geomIndex: 0),
              expected[i].record.copyWith(geomIndex: 0));
          expect(e.leaves[i].payload.coords, expected[i].payload.coords);
          expect(e.leaves[i].payload.scalars, expected[i].payload.scalars);
        }
      }
      expect(lib.entries.map((e) => e.leaves.length).toList(), [4, 2, 2]);
    });

    test('L2 leaves are ascending by handle although the file order is not',
        () {
      // The fixture is not degenerate: the file lists the sofa's leaves out
      // of handle order.
      final fileOrder = [
        for (final e in validLibraryJson()['entities']! as List)
          if ((e as Map)['record']['owner'] == sofaDef.value)
            e['record']['handle'] as int,
      ];
      expect(fileOrder, [sofaCircle, sofaLine, sofaArc, sofaPolyline]);
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(
          lib.entries
              .firstWhere((e) => e.key == 'sofa.three')
              .leaves
              .map((l) => l.record.handle.value)
              .toList(),
          [sofaLine, sofaPolyline, sofaArc, sofaCircle]);
    });

    test('L3 categories are in first-appearance order, each once', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      // Sofa (Living Room), nightstand (Bed Room), armchair (Living Room).
      expect(lib.categories, ['Living Room', 'Bed Room']);
    });

    test('L4 the lists are unmodifiable', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(() => lib.entries.removeLast(), throwsUnsupportedError);
      expect(() => lib.entries.first.tags.add('x'), throwsUnsupportedError);
      expect(() => lib.entries.first.leaves.clear(), throwsUnsupportedError);
    });

    test('L5 the allow-list accepts every allowed value', () {
      final j = validLibraryJson();
      recordJson(j, sofaLine)['linetype'] =
          ReservedHandles.byLayerLinetype.value;
      recordJson(j, sofaPolyline)['linetype'] =
          ReservedHandles.continuousLinetype.value;
      recordJson(j, sofaArc)['color'] = encodeColor(const ByLayerColor());
      recordJson(j, sofaArc)['lineweight'] = kByLayer;
      recordJson(j, sofaArc)['transparency'] = kByLayer;
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });

    test('L6 a coordinate exactly at the bound and a tiny radius are allowed',
        () {
      final j = validLibraryJson();
      (geometryJson(j, sofaLine)['coords']! as List)
        ..[0] = 1e6
        ..[1] = -1e6;
      (geometryJson(j, sofaCircle)['scalars']! as List)[0] = 1e-3;
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });
  });

  group('the document', () {
    test('R00 bytes the codec cannot read are refused, not thrown through', () {
      expectRejected(
          Uint8List.fromList([0xff, 0xfe, 0x00]), ['not a readable']);
      expectRejected(Uint8List.fromList(utf8.encode('{"schemaVersion":1}')),
          ['not a readable']);
    });

    test('R08 a definition cycle the codec repaired is refused', () {
      // The codec drops the instance that closes the cycle and unlists it,
      // so nothing else in the loaded document shows it.
      final j = validLibraryJson();
      (j['nodes']! as List).add(instanceNodeJson(
          handle: 5000, parent: sofaDef.value, definition: sofaDef.value));
      definitionJson(j, sofaDef.value)['children'] = [5000];
      expectRejected(bytesOfJson(j), ['codec repaired']);
    });

    test('R06 an instance in the library is refused', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add(instanceNodeJson(
          handle: 5000, parent: j['root']! as int, definition: sofaDef.value));
      expectRejected(bytesOfJson(j), ['instance ${hex(5000)}']);
    });

    test('R07 a group in the library is refused', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add({
        'type': 'group',
        'handle': 5001,
        'parent': j['root'],
        'transform': [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
        'visible': true,
        'children': <int>[],
        'exportAsDxfGroup': false,
      });
      expectRejected(bytesOfJson(j), ['group ${hex(5001)}']);
    });
  });

  group('a definition', () {
    test('R01 without a symbol component is refused', () {
      final j = validLibraryJson();
      ((j['components']! as Map)['jetcad.symbol']! as Map).remove('4300');
      expectRejected(bytesOfJson(j),
          [hex(nightstandDef.value), 'has no symbol component']);
    });

    test('R02 a repeated key and version is refused', () {
      final j = validLibraryJson();
      symbolComponentJson(j, nightstandDef.value)
        ..['key'] = 'sofa.three'
        ..['version'] = 3;
      expectRejected(bytesOfJson(j), [
        hex(nightstandDef.value),
        'sofa.three@3',
        'repeats the key and version',
      ]);
    });

    test('R02b the same key at another version is a different symbol', () {
      final j = validLibraryJson();
      symbolComponentJson(j, nightstandDef.value)
        ..['key'] = 'sofa.three'
        ..['version'] = 4;
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });

    test('R03 a key that is not lower-case is refused', () {
      final j = validLibraryJson();
      symbolComponentJson(j, sofaDef.value)['key'] = 'Sofa.Three';
      expectRejected(bytesOfJson(j), ['Sofa.Three', 'lower-case']);
    });

    test('R03b a key with white space is refused', () {
      final j = validLibraryJson();
      symbolComponentJson(j, sofaDef.value)['key'] = 'sofa three';
      expectRejected(bytesOfJson(j), ['sofa three', 'white space']);
    });

    test('R03c a tag that is not lower-case is refused', () {
      final j = validLibraryJson();
      symbolComponentJson(j, sofaDef.value)['tags'] = ['sofa', 'Seating', 'x'];
      expectRejected(bytesOfJson(j), ['sofa.three@3', '"Seating"']);
    });

    test('R03d a symbol with two family tags is refused (spec 09c D2)', () {
      // The nightstand, not the first definition: the rule is checked per
      // definition, and the message names this one's key and both tags.
      final j = validLibraryJson();
      symbolComponentJson(j, nightstandDef.value)['tags'] = [
        'family:bed-side',
        'nightstand',
        'against-wall',
        'family:table-low',
      ];
      expectRejected(bytesOfJson(j), [
        'nightstand.single@2',
        '"family:bed-side"',
        '"family:table-low"',
      ]);
      // The same family tag twice is two family tags, not one: "at most one
      // per symbol" counts tags, so a set of distinct families is not enough.
      symbolComponentJson(j, nightstandDef.value)['tags'] = [
        'nightstand',
        'family:x',
        'against-wall',
        'family:x',
      ];
      expectRejected(bytesOfJson(j), [
        'nightstand.single@2',
        '2 family tags ("family:x", "family:x")',
      ]);
    });

    test(
        'R03d one family tag loads; a tag that only mentions a family is no '
        'family tag', () {
      final j = validLibraryJson();
      symbolComponentJson(j, nightstandDef.value)['tags'] = [
        'family',
        'families:x',
        'family:bed-side',
        'against-wall',
        'my-family:y',
      ];
      final lib = SymbolLibrary.decode(bytesOfJson(j));
      expect(lib.entries[1].key, 'nightstand.single');
      expect(lib.entries[1].tags, [
        'family',
        'families:x',
        'family:bed-side',
        'against-wall',
        'my-family:y',
      ]);
    });

    test('R04 a leaf handle in children is refused', () {
      // Hand-built: the codec never writes a leaf handle there (spec V-9).
      final j = validLibraryJson();
      definitionJson(j, sofaDef.value)['children'] = [sofaLine];
      expectRejected(
          bytesOfJson(j), ['sofa.three@3', 'lists children', hex(sofaLine)]);
    });

    test('R05 a non-finite base point is refused', () {
      final j = validLibraryJson();
      definitionJson(j, nightstandDef.value)['basePoint'] = [kSentinel, 60.0];
      expectRejected(bytesOfJson(j, text: kInfinity),
          ['nightstand.single@2', 'non-finite base point']);
    });
  });

  group('a leaf', () {
    test('R09 owned by something that is not a definition is refused', () {
      final j = validLibraryJson();
      recordJson(j, sofaLine)['owner'] = j['root'];
      expectRejected(bytesOfJson(j), [hex(sofaLine), 'not a definition']);
    });

    for (final kind in ['text', 'fill', 'attrib']) {
      test('R10 of kind $kind is refused', () {
        final j = validLibraryJson();
        recordJson(j, sofaLine)['kind'] = kind;
        expectRejected(
            bytesOfJson(j), [hex(sofaLine), 'is a $kind', 'holds no text']);
      });
    }

    test('R11 of kind point is refused', () {
      final j = validLibraryJson();
      recordJson(j, sofaCircle)['kind'] = 'point';
      expectRejected(bytesOfJson(j), [hex(sofaCircle), 'is a point']);
    });
  });

  group('a leaf style off the allow-list', () {
    void style(String name, void Function(Map<String, Object?> r) edit,
        List<String> parts,
        {Map<String, String>? text}) {
      test(name, () {
        final j = validLibraryJson();
        edit(recordJson(j, sofaLine));
        expectRejected(bytesOfJson(j, text: text), [hex(sofaLine), ...parts]);
      });
    }

    style('R12 layer', (r) => r['layer'] = 20, ['not layer 0']);
    style(
        'R13 linetype DASHED (6)',
        (r) => r['linetype'] = ReservedHandles.dashedLinetype.value,
        ['linetype ${hex(6)}', 'not BYLAYER']);
    style('R14 text style', (r) => r['textStyle'] = 20, ['not STANDARD']);
    style('R15 colour', (r) => r['color'] = 1, ['concrete colour']);
    style('R16 lineweight', (r) => r['lineweight'] = 25, ['lineweight 25']);
    style(
        'R17 transparency', (r) => r['transparency'] = 50, ['transparency 50']);
    style('R18 flag invisible', (r) => r['flags'] = EntityFlags.invisible,
        ['flags 1']);
    style('R18b flag unpickable', (r) => r['flags'] = EntityFlags.unpickable,
        ['flags 2']);
    style('R19 linetype scale non-finite',
        (r) => r['linetypeScale'] = kSentinel, ['non-finite linetype scale'],
        text: kInfinity);
  });

  group('leaf geometry', () {
    void geometry(String name, int leaf,
        void Function(Map<String, Object?> g) edit, List<String> parts,
        {Map<String, String>? text}) {
      test(name, () {
        final j = validLibraryJson();
        edit(geometryJson(j, leaf));
        expectRejected(bytesOfJson(j, text: text), [hex(leaf), ...parts]);
      });
    }

    geometry(
        'R20 a line with six coordinates',
        sofaLine,
        (g) => g['coords'] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        ['malformed line payload']);
    geometry(
        'R20b a polyline with an odd coordinate count',
        sofaPolyline,
        (g) => g['coords'] = [1.0, 2.0, 3.0, 4.0, 5.0],
        ['malformed polyline payload']);
    geometry(
        'R20c a polyline with a scalar (a bulge the format does not have)',
        sofaPolyline,
        (g) => g['scalars'] = [0.5],
        ['malformed polyline payload']);
    geometry('R21 a non-finite coordinate', sofaPolyline,
        (g) => (g['coords']! as List)[4] = kSentinel, ['not finite'],
        text: kInfinity);
    geometry('R21b a negative infinite coordinate', sofaPolyline,
        (g) => (g['coords']! as List)[4] = kSentinel, ['not finite'],
        text: kNegInfinity);
    geometry('R21c a coordinate beyond 1e6', sofaPolyline,
        (g) => (g['coords']! as List)[5] = 1000000.5, ['beyond']);
    geometry('R21d a coordinate below -1e6', sofaPolyline,
        (g) => (g['coords']! as List)[0] = -1000000.5, ['beyond']);
    geometry('R22 a non-finite scalar', sofaArc,
        (g) => (g['scalars']! as List)[1] = kSentinel, ['non-finite scalar'],
        text: kInfinity);
    geometry('R23 a zero-length line', sofaLine,
        (g) => g['coords'] = [100.0, 100.0, 100.0, 100.0], ['zero-length']);
    geometry('R24 a polyline of one vertex', sofaPolyline,
        (g) => g['coords'] = [120.0, 340.0], ['polyline of 1 vertices']);
    geometry('R25 a circle of radius 0', sofaCircle,
        (g) => g['scalars'] = [0.0], ['radius 0.0']);
    geometry('R25b a circle of negative radius', sofaCircle,
        (g) => g['scalars'] = [-5.0], ['radius -5.0']);
    geometry('R26 an arc of radius 0', sofaArc,
        (g) => g['scalars'] = [0.0, 0.5, 1.75], ['radius 0.0']);
    geometry('R27 an arc of zero sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, 0.0], ['zero sweep']);
    // The decision is Tolerance.standard.angular (1e-9), not exact == 0: a
    // sweep the tolerance cannot tell from zero is refused, either sign, and
    // the boundary itself; one just above it is a real arc.
    final below = Tolerance.standard.angular / 2;
    geometry('R27b an arc of tiny positive sweep below the tolerance', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, below], ['zero sweep']);
    geometry('R27c an arc of tiny negative sweep below the tolerance', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, -below], ['zero sweep']);
    geometry(
        'R27d an arc of sweep exactly at the tolerance',
        sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, Tolerance.standard.angular],
        ['zero sweep']);
    for (final sweep in [2 * Tolerance.standard.angular, -2e-9]) {
      test('R27e an arc of sweep $sweep, just above the tolerance, loads', () {
        final j = validLibraryJson();
        geometryJson(j, sofaArc)['scalars'] = [250.0, 0.5, sweep];
        final lib = SymbolLibrary.decode(bytesOfJson(j));
        final arc = lib.entries
            .firstWhere((e) => e.key == 'sofa.three')
            .leaves
            .firstWhere((l) => l.record.kind == EntityKind.arc);
        expect(arc.payload.scalars[2], sweep);
      });
    }
  });
}
