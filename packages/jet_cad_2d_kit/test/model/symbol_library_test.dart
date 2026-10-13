// Spec K3: the library validator. Every rule has one-fault cases, each a
// single edit of a valid library's codec JSON (so a case can only go red
// through its own rule), and positive controls proving no rule is
// over-strict. Each refusal pins its rule number.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/library_fixtures.dart';

/// Stands for a non-finite number: JSON has none, but `jsonDecode` reads
/// `1e999` as infinity, so the sentinel is replaced in the text.
const double kSentinel = 7777.125;
const Map<String, String> kInfinity = {'7777.125': '1e999'};
const Map<String, String> kNegInfinity = {'7777.125': '-1e999'};

String hex(int handle) => Handle(handle).toHex();

/// Decoding [bytes] throws a [SymbolLibraryError] of [rule] whose message
/// holds every one of [parts].
void expectRefused(Uint8List bytes, int rule, List<String> parts) {
  try {
    SymbolLibrary.decode(bytes);
  } on SymbolLibraryError catch (e) {
    expect(e.rule, rule, reason: 'message: ${e.message}');
    for (final p in parts) {
      expect(e.message, contains(p), reason: 'message: ${e.message}');
    }
    return;
  }
  fail('the library was accepted; expected rule $rule naming $parts');
}

int ownerOf(Object? entity) =>
    ((entity! as Map)['record']! as Map)['owner']! as int;

int handleOf(Object? entity) =>
    ((entity! as Map)['record']! as Map)['handle']! as int;

void main() {
  group('a valid library', () {
    test('V0a every entry equals what was built, in definition order', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(lib.kits, ['sample']);
      // M-V0a: sort the entries by key instead of definition order. (Entries
      // in component order would survive: withComponent ascends by handle,
      // the same order as the definitions.)
      expect([
        for (final e in lib.entries) e.id
      ], [
        'sample.sofa.three@3',
        'sample.table.high-top@2',
        'sample.chair.arm@1',
      ]);
      final built = buildValidLibrary();
      addTearDown(built.dispose);
      final want = {
        sofaDef: (sofaSymbol(), null, 900.0, 400.0),
        tableDef: (tableSymbol(), tableUnit(), 1250.0, 860.0),
        armchairDef: (armchairSymbol(), null, 510.0, 35.0),
      };
      for (final e in lib.entries) {
        final (symbol, unit, bx, by) = want[e.definition.handle]!;
        expect(e.symbol, symbol);
        // M-V0a2: an entry without its unit.
        expect(e.unit, unit);
        expect(e.definition.name, symbol.id);
        expect(e.definition.basePoint.x, bx);
        expect(e.definition.basePoint.y, by);
        expect(e.definition, built.tree.definition(e.definition.handle));
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
      expect([for (final e in lib.entries) e.leaves.length], [4, 2, 2]);
    });

    test('V0b leaves ascend by handle although the file order does not', () {
      final fileOrder = [
        for (final e in validLibraryJson()['entities']! as List)
          if (ownerOf(e) == sofaDef.value) handleOf(e),
      ];
      expect(fileOrder, [sofaCircle, sofaLine, sofaArc, sofaPolyline],
          reason: 'premise: the file order is not the handle order');
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      // M-V0b: drop the sort of each entry's leaves.
      expect([for (final l in lib.entries.first.leaves) l.record.handle.value],
          [sofaLine, sofaPolyline, sofaArc, sofaCircle]);
    });

    test('V0c categories in first-appearance order, each once', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(lib.categories, ['Living Room', 'Bar']);
    });

    test('V0d the lists are unmodifiable', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      expect(() => lib.entries.removeLast(), throwsUnsupportedError);
      expect(() => lib.kits.add('x'), throwsUnsupportedError);
      expect(() => lib.entries.first.leaves.clear(), throwsUnsupportedError);
    });

    test('V0f a coordinate at the bound and a small radius are allowed', () {
      final j = validLibraryJson();
      (geometryJson(j, sofaLine)['coords']! as List)
        ..[0] = 1e6
        ..[1] = -1e6;
      (geometryJson(j, sofaCircle)['scalars']! as List)[0] = 1e-3;
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });

    test('V0g a unit whose first leaf is a circle is valid', () {
      // The unit moves from the table (a closed polyline first) to the
      // armchair (a circle first). M-V11: accept only polylines as closed.
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['${armchairDef.value}'] = units.remove('${tableDef.value}');
      final lib = SymbolLibrary.decode(bytesOfJson(j));
      expect(lib.entries.last.unit, tableUnit());
      expect(lib.entries[1].unit, isNull);
    });
  });

  group('rule 1: not a readable document', () {
    test('V1a bytes the codec cannot read are refused, not thrown through', () {
      expectRefused(Uint8List.fromList([0xff, 0xfe, 0x00]), 1,
          ['not a readable library']);
      expectRefused(Uint8List.fromList(utf8.encode('{"schemaVersion":1}')), 1,
          ['not a readable library']);
      expectRefused(Uint8List.fromList(utf8.encode('[1, 2]')), 1,
          ['not a readable library']);
    });

    test('V1b a definition cycle the codec repaired is refused', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add(instanceNodeJson(
          handle: 5000, parent: sofaDef.value, definition: sofaDef.value));
      definitionJson(j, sofaDef.value)['children'] = [5000];
      // M-V1b: skip the diagnostics check.
      expectRefused(bytesOfJson(j), 1, ['codec repaired']);
    });

    test('V1c a symbol version of 0', () {
      final j = validLibraryJson();
      componentJson(
          j, SymbolComponent.componentTypeId, sofaDef.value)['version'] = 0;
      expectRefused(bytesOfJson(j), 1, ['jetcad.symbol', 'sample.sofa.three']);
    });

    test('V1d a unit capacity of 0 (ported SE6)', () {
      final j = validLibraryJson();
      componentJson(
          j, UnitComponent.componentTypeId, tableDef.value)['capacity'] = 0;
      expectRefused(bytesOfJson(j), 1, ['jetcad.unit', 'capacity']);
    });

    test('V1e an unknown labelling', () {
      final j = validLibraryJson();
      componentJson(
              j, UnitComponent.componentTypeId, tableDef.value)['labelling'] =
          'random';
      expectRefused(bytesOfJson(j), 1, ['jetcad.unit', 'random']);
    });

    test('V1f a symbol component without its family field', () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
          .remove('family');
      expectRefused(bytesOfJson(j), 1, ['"family"']);
    });

    test('V1g structurally broken documents are rule 1, never a TypeError', () {
      // Review Focus 1. M-V1g: catch only FormatException around the codec.
      final noEntities = validLibraryJson()..remove('entities');
      expectRefused(bytesOfJson(noEntities), 1, ['not a readable library']);
      final listComponents = validLibraryJson()..['components'] = [1, 2];
      expectRefused(bytesOfJson(listComponents), 1, ['not a readable']);
      final j = validLibraryJson();
      componentsJson(j, SymbolComponent.componentTypeId)['${sofaDef.value}'] =
          'not a map';
      expectRefused(bytesOfJson(j), 1, ['not a readable']);
    });
  });

  group('rule 2: the library component and the units', () {
    test('V2a a root without the library component', () {
      final j = validLibraryJson();
      (j['components']! as Map).remove(LibraryComponent.componentTypeId);
      expectRefused(bytesOfJson(j), 2, ['no library component']);
    });

    test('V2b a format other than 1', () {
      final j = validLibraryJson();
      componentJson(
          j, LibraryComponent.componentTypeId, j['root']! as int)['format'] = 2;
      // M-V2b: check `format >= 1` only.
      expectRefused(bytesOfJson(j), 2, ['format 2']);
    });

    test('V2c a library kit that is not a kit id', () {
      final j = validLibraryJson();
      componentJson(
              j, LibraryComponent.componentTypeId, j['root']! as int)['kit'] =
          'Sample';
      expectRefused(bytesOfJson(j), 2, ['jetcad.library', 'Sample']);
    });

    test('V2d units other than millimetres', () {
      final j = validLibraryJson();
      (j['header']! as Map)['units'] = 'inches';
      expectRefused(bytesOfJson(j), 2, ['inches']);
    });

    test('V2e a library component on a definition as well', () {
      final j = validLibraryJson();
      componentsJson(j, LibraryComponent.componentTypeId)['${sofaDef.value}'] =
          {'format': 1, 'kit': 'sample'};
      expectRefused(bytesOfJson(j), 2, [hex(sofaDef.value), 'not the root']);
    });

    test('V2f a library component with a mistyped field', () {
      // fromJson's FormatException, not a constructor's ArgumentError.
      // M-V2f: map every FormatException to rule 1.
      final j = validLibraryJson();
      componentJson(j, LibraryComponent.componentTypeId, j['root']! as int)[
          'format'] = '1';
      expectRefused(bytesOfJson(j), 2, ['jetcad.library', '"format"']);
    });
  });

  group('rule 3: nodes', () {
    test('V3a an instance (ported R06)', () {
      final j = validLibraryJson();
      (j['nodes']! as List).add(instanceNodeJson(
          handle: 5000, parent: j['root']! as int, definition: sofaDef.value));
      expectRefused(bytesOfJson(j), 3, ['instance ${hex(5000)}']);
    });

    test('V3b a group (ported R07)', () {
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
      expectRefused(bytesOfJson(j), 3, ['group ${hex(5001)}']);
    });
  });

  group('rule 4: definitions', () {
    test('V4a a definition without a symbol component (ported R01)', () {
      final j = validLibraryJson();
      componentsJson(j, SymbolComponent.componentTypeId)
          .remove('${armchairDef.value}');
      expectRefused(
          bytesOfJson(j), 4, [hex(armchairDef.value), 'no symbol component']);
    });

    test('V4b a leaf handle in children (ported R04)', () {
      final j = validLibraryJson();
      definitionJson(j, sofaDef.value)['children'] = [sofaLine];
      expectRefused(bytesOfJson(j), 4,
          ['sample.sofa.three@3', 'lists children', hex(sofaLine)]);
    });

    test('V4c an external reference', () {
      final j = validLibraryJson();
      definitionJson(j, sofaDef.value)['isXref'] = true;
      expectRefused(bytesOfJson(j), 4, ['sample.sofa.three@3', 'external']);
    });

    test('V4d a definition with no leaf', () {
      final j = validLibraryJson();
      (j['entities']! as List)
          .removeWhere((e) => ownerOf(e) == armchairDef.value);
      // M-V4d: drop the empty-leaves check.
      expectRefused(bytesOfJson(j), 4, ['sample.chair.arm@1', 'no leaf']);
    });

    test('V4e a symbol component on the root', () {
      final j = validLibraryJson();
      final symbols = componentsJson(j, SymbolComponent.componentTypeId);
      symbols['${j['root']}'] = symbols['${sofaDef.value}'];
      expectRefused(bytesOfJson(j), 4, ['not a definition']);
    });
  });

  group('rule 5: the key', () {
    test("V5a a key under another kit than the library's", () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, sofaDef.value)['key'] =
          'other.sofa.three';
      // M-V5a: drop the kit check (rule 7 would then refuse it instead).
      expectRefused(bytesOfJson(j), 5, ['other.sofa.three', '"sample"']);
    });

    for (final (name, key) in [
      ('V5b an upper-case key (ported R03)', 'sample.Sofa.three'),
      ('V5c a key with white space (ported R03b)', 'sample.sofa three.x'),
      ('V5d a key of two segments', 'sample.sofa'),
      ('V5e a key with a double hyphen', 'sample.sofa--x.three'),
    ]) {
      test(name, () {
        final j = validLibraryJson();
        componentJson(
            j, SymbolComponent.componentTypeId, sofaDef.value)['key'] = key;
        // M-V5b: map the constructor's "key" refusal to rule 1.
        expectRefused(bytesOfJson(j), 5, [key]);
      });
    }
  });

  group('rule 6: a repeated key@version', () {
    test('V6a the same key and version twice (ported R02)', () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
        ..['key'] = 'sample.sofa.three'
        ..['version'] = 3;
      expectRefused(bytesOfJson(j), 6, [
        hex(tableDef.value),
        'sample.sofa.three@3',
        'repeats',
      ]);
    });

    test('V6b the same key at another version is another symbol (ported R02b)',
        () {
      final j = validLibraryJson();
      componentJson(j, SymbolComponent.componentTypeId, tableDef.value)
        ..['key'] = 'sample.sofa.three'
        ..['version'] = 4;
      definitionJson(j, tableDef.value)['name'] = 'sample.sofa.three@4';
      expect(SymbolLibrary.decode(bytesOfJson(j)).entries, hasLength(3));
    });
  });

  group('rule 7: the definition name', () {
    for (final (name, value) in [
      ('V7a another version in the name', 'sample.sofa.three@2'),
      ('V7b a name without its version', 'sample.sofa.three'),
    ]) {
      test(name, () {
        final j = validLibraryJson();
        definitionJson(j, sofaDef.value)['name'] = value;
        // M-V7: drop the name check.
        expectRefused(bytesOfJson(j), 7, ['"$value"', 'sample.sofa.three@3']);
      });
    }
  });

  group('rule 8: tags, target kinds, families, unit kinds', () {
    void symbolCase(String name, String field, Object value, String part) {
      test(name, () {
        final j = validLibraryJson();
        componentJson(
            j, SymbolComponent.componentTypeId, sofaDef.value)[field] = value;
        // M-V8: map "tags", "attachTo" or "family" to rule 1.
        expectRefused(bytesOfJson(j), 8, ['sample.sofa.three', part]);
      });
    }

    symbolCase('V8a an upper-case tag (ported R03c)', 'tags',
        ['sofa', 'Seating', 'couch'], 'Seating');
    symbolCase(
        'V8b a repeated tag', 'tags', ['sofa', 'couch', 'sofa'], 'repeated');
    symbolCase('V8c an empty tag', 'tags', ['sofa', ''], 'tags');
    symbolCase('V8d an upper-case target kind', 'attachTo', ['Wall-Face'],
        'Wall-Face');
    symbolCase('V8e a repeated target kind', 'attachTo',
        ['wall-face', 'wall-face'], 'repeated');
    symbolCase('V8f a family with a space', 'family', 'sofa long', 'sofa long');

    test('V8g a unit kind off the pattern', () {
      final j = validLibraryJson();
      componentJson(j, UnitComponent.componentTypeId, tableDef.value)['kind'] =
          'Table';
      expectRefused(bytesOfJson(j), 8, ['jetcad.unit', 'Table']);
    });
  });

  group('rule 9: a unit in a family', () {
    test('V9a a unit whose symbol names a family', () {
      final j = validLibraryJson();
      componentJson(
              j, SymbolComponent.componentTypeId, tableDef.value)['family'] =
          'table-high';
      // M-V9: drop the check; the sofa's own family (V0a) shows a family is
      // fine on a symbol that is not a unit.
      expectRefused(
          bytesOfJson(j), 9, ['sample.table.high-top@2', 'table-high']);
    });
  });

  group('rule 10: a unit component off a symbol definition', () {
    test('V10a on the root (ported SE7)', () {
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['${j['root']}'] = units['${tableDef.value}'];
      expectRefused(bytesOfJson(j), 10, ['not a symbol']);
    });

    test('V10b on a leaf', () {
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['$sofaLine'] = units['${tableDef.value}'];
      // M-V10: drop the check.
      expectRefused(bytesOfJson(j), 10, [hex(sofaLine)]);
    });
  });

  group('rule 11: a unit outline', () {
    test('V11a a unit whose first leaf is an open polyline', () {
      final j = validLibraryJson();
      final coords = geometryJson(j, tableTop)['coords']! as List;
      coords[coords.length - 1] = 1170.0;
      // M-V11a: drop the check.
      expectRefused(bytesOfJson(j), 11,
          ['sample.table.high-top@2', hex(tableTop), 'not a closed']);
    });

    test('V11b a unit whose first leaf is a line', () {
      final j = validLibraryJson();
      final units = componentsJson(j, UnitComponent.componentTypeId);
      units['${sofaDef.value}'] = units.remove('${tableDef.value}');
      componentJson(
          j, SymbolComponent.componentTypeId, sofaDef.value)['family'] = null;
      // Two edits: the sofa's family would be rule 9. M-V11b: take the last
      // leaf instead of the first.
      expectRefused(bytesOfJson(j), 11, ['sample.sofa.three@3', hex(sofaLine)]);
    });

    // Amended by the final review: an outline must enclose more than
    // Tolerance.standard.linear squared, either winding.
    void outline(String name, List<double> coords, List<String> parts) {
      test(name, () {
        final j = validLibraryJson();
        geometryJson(j, tableTop)['coords'] = coords;
        expectRefused(bytesOfJson(j), 11,
            ['sample.table.high-top@2', hex(tableTop), ...parts]);
      });
    }

    // M-V11c: drop the area check.
    outline(
        'V11c a closed outline on one diagonal, off the origin',
        [950.0, 560.0, 1250.0, 860.0, 1550.0, 1160.0, 950.0, 560.0],
        ['encloses no area (0.0)']);
    // Area 5e-19, under linear² (1e-18), and not zero: near the origin, the
    // only place a double can hold so thin a triangle. M-V11d: `area == 0`.
    outline(
        'V11d an outline of area linear² / 2',
        [1e-3, 2e-3, 2e-3, 2e-3, 1e-3, 2e-3 + 1e-15, 1e-3, 2e-3],
        ['encloses no area']);
    test('V11e an outline of area 2 * linear² loads', () {
      // Positive control. M-V11e: `area <= linear` (not squared).
      final j = validLibraryJson();
      geometryJson(j, tableTop)['coords'] = [
        1e-3, 2e-3, 2e-3, 2e-3, 1e-3, 2e-3 + 4e-15, 1e-3, 2e-3, //
      ];
      final lib = SymbolLibrary.decode(bytesOfJson(j));
      expect(lib.entries[1].leaves.first.payload.coords[5], 2e-3 + 4e-15);
    });
    test('V11f a clockwise outline loads', () {
      // The table's top, its winding reversed. M-V11f: drop `.abs()`.
      final j = validLibraryJson();
      geometryJson(j, tableTop)['coords'] = [
        950.0, 560.0, 950.0, 1160.0, 1550.0, 1160.0, 1550.0, 560.0, //
        950.0, 560.0,
      ];
      final lib = SymbolLibrary.decode(bytesOfJson(j));
      expect(lib.entries[1].leaves.first.payload.coords[3], 1160.0);
    });
  });

  group('rule 12: the base point', () {
    test('V12a a non-finite base point (ported R05)', () {
      final j = validLibraryJson();
      definitionJson(j, tableDef.value)['basePoint'] = [kSentinel, 860.0];
      expectRefused(bytesOfJson(j, text: kInfinity), 12,
          ['sample.table.high-top@2', 'non-finite base point']);
    });

    test('V12b a base point whose y is non-finite', () {
      // M-V12b: check `base.x` only.
      final j = validLibraryJson();
      definitionJson(j, tableDef.value)['basePoint'] = [1250.0, kSentinel];
      expectRefused(bytesOfJson(j, text: kInfinity), 12,
          ['sample.table.high-top@2', 'non-finite base point']);
    });
  });

  group('rule 13: leaves', () {
    test('V13a owned by the root (ported R09)', () {
      final j = validLibraryJson();
      recordJson(j, sofaLine)['owner'] = j['root'];
      expectRefused(bytesOfJson(j), 13, [hex(sofaLine), 'not a definition']);
    });

    test('V13b owned by a handle that names nothing', () {
      final j = validLibraryJson();
      recordJson(j, sofaLine)['owner'] = 9999;
      expectRefused(bytesOfJson(j), 13, [hex(sofaLine), hex(9999)]);
    });

    for (final kind in ['text', 'fill', 'attrib', 'point']) {
      test('V13c a leaf of kind $kind (ported R10, R11)', () {
        final j = validLibraryJson();
        recordJson(j, sofaCircle)['kind'] = kind;
        // M-V13c: let `point` through as the old allow-list did not.
        expectRefused(bytesOfJson(j), 13, [hex(sofaCircle), 'is a $kind']);
      });
    }
  });

  group('rule 14: leaf style (ported R12-R19, L5 inverted)', () {
    void style(String name, String field, Object? value, List<String> parts,
        {Map<String, String>? text}) {
      test(name, () {
        final j = validLibraryJson();
        recordJson(j, sofaLine)[field] = value;
        // M-V14: drop the check the case names.
        expectRefused(
            bytesOfJson(j, text: text), 14, [hex(sofaLine), ...parts]);
      });
    }

    style('V14a layer', 'layer', 20, ['not layer 0']);
    style('V14b linetype BYLAYER (allowed before, L5)', 'linetype',
        ReservedHandles.byLayerLinetype.value, ['not BYBLOCK']);
    style('V14c linetype CONTINUOUS (allowed before, L5)', 'linetype',
        ReservedHandles.continuousLinetype.value, ['not BYBLOCK']);
    style('V14d linetype DASHED', 'linetype',
        ReservedHandles.dashedLinetype.value, ['linetype ${hex(6)}']);
    style('V14e linetype scale 2', 'linetypeScale', 2.0, ['scale 2.0']);
    style('V14f linetype scale non-finite', 'linetypeScale', kSentinel,
        ['scale Infinity'],
        text: kInfinity);
    style('V14g a concrete colour', 'color', 1, ['colour']);
    style('V14h colour BYLAYER (allowed before, L5)', 'color',
        encodeColor(const ByLayerColor()), ['colour']);
    style('V14i lineweight 25', 'lineweight', 25, ['lineweight 25']);
    style('V14j lineweight BYLAYER (allowed before, L5)', 'lineweight',
        kByLayer, ['lineweight $kByLayer']);
    style('V14k transparency 50', 'transparency', 50, ['transparency 50']);
    style('V14l transparency BYLAYER (allowed before, L5)', 'transparency',
        kByLayer, ['transparency $kByLayer']);
    style('V14m flag invisible', 'flags', EntityFlags.invisible, ['flags 1']);
    style('V14n flag unpickable', 'flags', EntityFlags.unpickable, ['flags 2']);
    style('V14o text style', 'textStyle', 20, ['not STANDARD']);
    style('V14p text', 'text', 'x', ['text']);
    style('V14q tag', 'tag', 'x', ['tag']);
    style('V14r text attributes', 'textAttrs', 1, ['text attributes 1']);
  });

  group('rule 15: leaf geometry (ported R20-R27e)', () {
    void geometry(String name, int leaf,
        void Function(Map<String, Object?> g) edit, List<String> parts,
        {Map<String, String>? text}) {
      test(name, () {
        final j = validLibraryJson();
        edit(geometryJson(j, leaf));
        expectRefused(bytesOfJson(j, text: text), 15, [hex(leaf), ...parts]);
      });
    }

    geometry(
        'V15a a line with six coordinates',
        sofaLine,
        (g) => g['coords'] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        ['malformed line']);
    geometry('V15b a polyline with an odd coordinate count', sofaPolyline,
        (g) => g['coords'] = [1.0, 2.0, 3.0, 4.0, 5.0], ['malformed polyline']);
    geometry('V15c a polyline with a scalar', sofaPolyline,
        (g) => g['scalars'] = [0.5], ['malformed polyline']);
    geometry('V15d a circle with no radius', sofaCircle,
        (g) => g['scalars'] = <double>[], ['malformed circle']);
    geometry('V15e a non-finite coordinate', sofaPolyline,
        (g) => (g['coords']! as List)[4] = kSentinel, ['not finite'],
        text: kInfinity);
    geometry('V15f a negative infinite coordinate', sofaPolyline,
        (g) => (g['coords']! as List)[4] = kSentinel, ['not finite'],
        text: kNegInfinity);
    geometry('V15g a coordinate beyond 1e6', sofaPolyline,
        (g) => (g['coords']! as List)[5] = 1000000.5, ['beyond']);
    geometry('V15h a coordinate below -1e6', sofaPolyline,
        (g) => (g['coords']! as List)[0] = -1000000.5, ['beyond']);
    geometry('V15i a non-finite scalar', sofaArc,
        (g) => (g['scalars']! as List)[1] = kSentinel, ['non-finite scalar'],
        text: kInfinity);
    geometry('V15j a zero-length line', sofaLine,
        (g) => g['coords'] = [100.0, 100.0, 100.0, 100.0], ['zero-length']);
    geometry('V15k a polyline of one vertex', sofaPolyline,
        (g) => g['coords'] = [120.0, 340.0], ['polyline of 1 vertices']);
    geometry('V15l a circle of radius 0', sofaCircle,
        (g) => g['scalars'] = [0.0], ['radius 0.0']);
    geometry('V15m a circle of negative radius', sofaCircle,
        (g) => g['scalars'] = [-5.0], ['radius -5.0']);
    geometry('V15n an arc of radius 0', sofaArc,
        (g) => g['scalars'] = [0.0, 0.5, 1.75], ['radius 0.0']);
    geometry('V15o an arc of zero sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, 0.0], ['zero sweep']);
    // The decision is Tolerance.standard.angular (1e-9), not `== 0`: a sweep
    // the tolerance cannot tell from zero is refused, either sign, and the
    // bound itself. M-V15: `sweep == 0` turns V15p-V15r green-to-red.
    final below = Tolerance.standard.angular / 2;
    geometry('V15p a tiny positive sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, below], ['zero sweep']);
    geometry('V15q a tiny negative sweep', sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, -below], ['zero sweep']);
    geometry(
        'V15r a sweep at the tolerance',
        sofaArc,
        (g) => g['scalars'] = [250.0, 0.5, Tolerance.standard.angular],
        ['zero sweep']);
    for (final sweep in [2 * Tolerance.standard.angular, -2e-9]) {
      test('V15s a sweep of $sweep, just above the tolerance, loads', () {
        final j = validLibraryJson();
        geometryJson(j, sofaArc)['scalars'] = [250.0, 0.5, sweep];
        final lib = SymbolLibrary.decode(bytesOfJson(j));
        final arc = lib.entries.first.leaves
            .firstWhere((l) => l.record.kind == EntityKind.arc);
        expect(arc.payload.scalars[2], sweep);
      });
    }

    // The radius decision is Tolerance.standard.linear (1e-9), "at or
    // under". M-V15t: `radius <= 0` turns V15t and V15u red; M-V15u:
    // `radius < Tolerance.standard.linear` turns V15v and V15w red.
    final linear = Tolerance.standard.linear;
    geometry('V15t a circle of radius linear/2', sofaCircle,
        (g) => g['scalars'] = [linear / 2], ['radius ${linear / 2}']);
    geometry(
        'V15u an arc of radius linear/2',
        sofaArc,
        (g) => g['scalars'] = [linear / 2, 0.5, 1.75],
        ['radius ${linear / 2}']);
    geometry('V15v a circle of radius exactly linear', sofaCircle,
        (g) => g['scalars'] = [linear], ['radius $linear']);
    geometry('V15w an arc of radius exactly linear', sofaArc,
        (g) => g['scalars'] = [linear, 0.5, 1.75], ['radius $linear']);
    test('V15x a radius just above linear loads, circle and arc', () {
      // Positive control: the radius rule is not over-strict.
      final j = validLibraryJson();
      geometryJson(j, sofaCircle)['scalars'] = [2 * linear];
      geometryJson(j, sofaArc)['scalars'] = [2 * linear, 0.5, 1.75];
      final sofa = SymbolLibrary.decode(bytesOfJson(j)).entries.first;
      double radiusOf(EntityKind kind) => sofa.leaves
          .firstWhere((l) => l.record.kind == kind)
          .payload
          .scalars[0];
      expect(radiusOf(EntityKind.circle), 2 * linear);
      expect(radiusOf(EntityKind.arc), 2 * linear);
    });

    // The zero-length decision is isDegenerateSegment (distance at or under
    // Tolerance.standard.linear), off the origin. M-V15y: `from == to`
    // (exact equality) turns V15y red.
    geometry(
        'V15y a line linear/2 long',
        sofaLine,
        (g) => g['coords'] = [120.0, 340.0, 120.0 + linear / 2, 340.0],
        ['zero-length']);
    // Amended by the final review: a polyline whose points all lie within
    // Tolerance.standard.linear of each other is a zero-length polyline.
    // M-V15aa: drop the check (V15aa, V15ab red); exact equality of the
    // points (V15aa red).
    geometry(
        'V15aa a polyline of three points within linear of each other',
        sofaPolyline,
        (g) => g['coords'] = [
              120.0, 340.0, 120.0 + linear / 2, 340.0, //
              120.0, 340.0 + linear / 2,
            ],
        ['zero-length polyline']);
    geometry('V15ab a closed polyline of one point', sofaPolyline,
        (g) => g['coords'] = [120.0, 340.0, 120.0, 340.0], ['zero-length']);
    test('V15ac points within linear of the first, not of each other, load',
        () {
      // Positive control, "of each other": the outer two are 1.8e-9 apart.
      // M-V15ac: compare every point with the first only.
      final j = validLibraryJson();
      geometryJson(j, sofaPolyline)['coords'] = [
        120.0, 340.0, 120.0 - 0.9 * linear, 340.0, //
        120.0 + 0.9 * linear, 340.0,
      ];
      final sofa = SymbolLibrary.decode(bytesOfJson(j)).entries.first;
      expect(
          sofa.leaves
              .firstWhere((l) => l.record.kind == EntityKind.polyline)
              .payload
              .pointCount,
          3);
    });
    test('V15ad a polyline whose first two points coincide loads', () {
      // Positive control. M-V15ad: test the first two points only.
      final j = validLibraryJson();
      geometryJson(j, sofaPolyline)['coords'] = [
        120.0, 340.0, 120.0, 340.0, 400.0, 950.0, //
      ];
      final sofa = SymbolLibrary.decode(bytesOfJson(j)).entries.first;
      expect(
          sofa.leaves
              .firstWhere((l) => l.record.kind == EntityKind.polyline)
              .payload
              .coords[4],
          400.0);
    });
    test('V15z a line 2 * linear long loads', () {
      // Positive control: the line rule is not over-strict.
      final j = validLibraryJson();
      geometryJson(j, sofaLine)['coords'] = [
        120.0,
        340.0,
        120.0,
        340.0 + 2 * linear
      ];
      final sofa = SymbolLibrary.decode(bytesOfJson(j)).entries.first;
      final line =
          sofa.leaves.firstWhere((l) => l.record.kind == EntityKind.line);
      expect(line.payload.coords[3], 340.0 + 2 * linear);
    });
  });
}
