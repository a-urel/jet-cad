// Ported from jet_cad_floor_plan/test/tables/table_data_test.dart and test/host/table_color_test.dart; assertions unchanged.
//
// Spec 2b S2 "Per-unit data" (host embedding API spec E-6, plan colours
// spec PC-4): the host's data on a unit -- the component, its limits, its
// lenient read (spec point S-2) and its diagnostic (S-3) -- and the unit's
// colour. Units are placed off the origin, turned and mirrored; data is
// written with its keys out of order, a 64-character key, a 1024-unit
// value and non-ASCII text.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/units/unit_components.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:jet_cad_2d_plan/src/units/unit_problems.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart';

/// Data as a host writes it: keys out of order, a value with a space, a dot
/// and a non-ASCII letter.
Map<String, String> hostData() => {
      'zeta': 'Masa 4.ğ',
      'id': '7f3c-ä',
      'alpha': '',
    };

/// A key of exactly 64 characters of the allowed set.
final String key64 = 'k${'a_.-9' * 12}xyz';

/// A value of exactly 1024 UTF-16 units, non-ASCII included.
final String value1024 = '${'ş' * 1000}${'x' * 24}';

/// A value of exactly 1024 UTF-16 units that is only 512 characters: each
/// U+1F37D is a surrogate pair (E-6 counts units, review R-1).
final String astral1024 = '\u{1F37D}' * 512;

/// A value of 1025 UTF-16 units that is only 1024 characters.
final String astral1025 = '${'x' * 1023}\u{1F37D}';

/// The unit placed last in [doc].
UnitInfo placeTable(DraftDocument doc, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: at, quarterTurns: quarterTurns, mirrored: mirrored));
  return unitIndexOf(doc)
      .units
      .reduce((a, b) => a.instance.value > b.instance.value ? a : b);
}

UnitData? dataOf(DraftDocument doc, Handle h) =>
    doc.components.get<UnitData>(h);

const PlanSwatch teal = PlanSwatch.teal;
const PlanSwatch purple = PlanSwatch.purple;

void main() {
  group('the limits (E-6, S-6)', () {
    test(
        'TD1 accepted at the boundaries: 32 keys, a 64-character key, a '
        '1024-unit value, an empty value, non-ASCII text', () {
      expect(key64.length, 64);
      expect(value1024.length, 1024);
      final full = {
        for (var i = 0; i < 31; i++) 'k${i.toString().padLeft(2, '0')}': '$i',
        key64: value1024,
      };
      expect(full.length, 32);
      expect(unitDataProblem(full), isNull);
      expect(UnitData(full).data, full);
      expect(unitDataProblem(hostData()), isNull);
      expect(unitDataProblem(const {}), isNull,
          reason: 'empty is within the limits: it removes the data');
      expect(unitDataProblem({'a': ' ¡ é'}), isNull,
          reason: 'U+00A0 is past the C1 range');
      expect(unitDataProblem({'a': 'a~b'}), isNull,
          reason: 'U+007E is below the DEL and C1 range');
      expect(astral1024.length, 1024);
      expect(astral1024.runes.length, 512);
      expect(unitDataProblem({'a': astral1024}), isNull,
          reason: '1024 UTF-16 units, though 512 characters');
      expect(UnitData({'a': astral1024}).data, {'a': astral1024});
    });

    test(
        'TD2 refused one past each boundary: 33 keys, a 65-character key, a '
        '1025-unit value, each control character range, a bad key', () {
      final over = {for (var i = 0; i < 33; i++) 'k$i': 'v'};
      expect(astral1025.length, 1025);
      expect(astral1025.runes.length, 1024,
          reason: 'over in UTF-16 units, not in characters');
      final refused = <Map<String, String>>[
        over,
        {'${key64}q': 'v'},
        {'a': '${value1024}x'},
        {'a': astral1025},
        {'a': 'x\u0085y'},
        {'a': '\u0000'},
        {'a': 'line\nbreak'},
        {'a': '\u001f'},
        {'a': '\u007f'},
        {'a': '\u009f'},
        {'Bad': 'x'},
        {'bad key': 'x'},
        {'': 'x'},
        {'ı': 'x'},
      ];
      for (final data in refused) {
        expect(unitDataProblem(data), isNotNull, reason: '$data');
        expect(() => UnitData(data), throwsArgumentError, reason: '$data');
      }
      expect(() => UnitData(const {}), throwsArgumentError,
          reason: 'an empty map is no component');
    });
  });

  group('the component', () {
    test(
        'TD3 M-H24: keys inserted as zeta, id, alpha are written sorted; '
        'the data is unmodifiable and value-equal', () {
      final c = UnitData(hostData());
      expect(jsonEncode(c.toJson()),
          '{"data":{"alpha":"","id":"7f3c-ä","zeta":"Masa 4.ğ"}}');
      expect(c.data.keys, ['alpha', 'id', 'zeta']);
      expect(() => c.data['x'] = 'y', throwsUnsupportedError);
      expect(c.isKept, isFalse);
      expect(c.typeId, 'jetcad.unit_data');
      final same = UnitData({'alpha': '', 'zeta': 'Masa 4.ğ', 'id': '7f3c-ä'});
      expect(same, c);
      expect(same.hashCode, c.hashCode);
      expect(UnitData({...hostData(), 'id': '7f3c-a'}), isNot(c));
    });

    test(
        'TD4 M-H28: fromJson never throws; a payload of another shape or '
        'outside the limits is kept verbatim and reads as empty data', () {
      final payloads = <String>[
        jsonEncode({
          'data': {for (var i = 33; i > 0; i--) 'k$i': 'v$i'}
        }),
        '{"data":{"Bad Key":"x","alpha":"a"}}',
        jsonEncode({
          'data': {'a': '${value1024}x'}
        }),
        jsonEncode({
          'data': {'a': astral1025}
        }),
        '{"data":{"zeta":"z","n":4}}',
        '{"data":["1","2"]}',
        '{"data":{}}',
        '{}',
        '{"data":{"a":"b"},"extra":1}',
        jsonEncode({
          'data': {'a': 'x\u0085'}
        }),
        '{"data":{"a":{"b":[1,2.5,null,true,{"z":"y","c":"d"}]}},"x":-0.5}',
      ];
      for (final text in payloads) {
        final json = (jsonDecode(text) as Map).cast<String, Object?>();
        final c = UnitData.fromJson(json);
        expect(c.isKept, isTrue, reason: text);
        expect(c.data, isEmpty, reason: text);
        expect(jsonEncode(c.toJson()), text, reason: 'written back as read');
        expect(UnitData.fromJson(json), c, reason: 'value-equal');
      }
      final deep = UnitData.fromJson(
          (jsonDecode(payloads.last) as Map).cast<String, Object?>());
      expect(
          () => (deep.kept!['data']! as Map)['q'] = 1, throwsUnsupportedError,
          reason: 'kept unmodifiable all the way down');
      expect(
          deep,
          isNot(UnitData.fromJson(
              (jsonDecode(payloads.first) as Map).cast<String, Object?>())));
    });

    test(
        'TD5 a valid but unsorted stored payload is the data, re-sorted on '
        'write (S-6)', () {
      final c = UnitData.fromJson(
          (jsonDecode('{"data":{"zeta":"Masa 4.ğ","id":"7f3c-ä","alpha":""}}')
                  as Map)
              .cast<String, Object?>());
      expect(c.isKept, isFalse);
      expect(c, UnitData(hostData()));
      expect(jsonEncode(c.toJson()),
          '{"data":{"alpha":"","id":"7f3c-ä","zeta":"Masa 4.ğ"}}');
    });

    test(
        'TD6 registerPlanComponents registers it: a plan decodes it typed, '
        'and one outside the limits decodes too, with a diagnostic', () {
      final doc = plan();
      final a = placeTable(doc, Vector2(41200, -27300), quarterTurns: 1);
      final b = placeTable(doc, Vector2(-38900, 26100), mirrored: true);
      doc.commands.execute(
          SetComponentCommand<UnitData>(a.instance, UnitData(hostData())));
      final json = (jsonDecode(DraftDocumentCodec.encodeToString(doc)) as Map)
          .cast<String, Object?>();
      doc.dispose();
      ((json['components']! as Map)['jetcad.unit_data']
              as Map)['${b.instance.value}'] =
          jsonDecode('{"data":{"Bad Key":"x"}}');
      final text = jsonEncode(json);
      final back = DraftDocumentCodec.decodeString(text,
          registerComponents: (r) =>
              registerPlanComponents(r, ParametricCatalog()));
      addTearDown(back.dispose);
      expect(dataOf(back, a.instance), UnitData(hostData()));
      expect(dataOf(back, b.instance)!.isKept, isTrue);
      expect(DraftDocumentCodec.encodeToString(back), text,
          reason: 'byte for byte');
      final invalid = unitIndexOf(back)
          .diagnostics()
          .where((d) => d.code == UnitProblem.invalidData)
          .toList();
      expect(invalid.single.handles, [b.instance]);
      expect(invalid.single.severity, DiagnosticSeverity.warning);
      expect(UnitProblem.invalidData, 'unit.invalid_data');
    });
  });

  test(
      'TC1 M-C1 (tables) the component: teal encodes {"color":"teal"}; an '
      'unknown name is stored as read; any other shape is kept verbatim; '
      'nothing throws', () {
    final made = UnitColour(teal);
    expect(made.toJson(), {'color': 'teal'});
    expect(jsonEncode(made.toJson()), '{"color":"teal"}');
    expect(made.name, 'teal');
    expect(made.swatch, teal);
    expect(made.isKept, isFalse);
    expect(UnitColour.fromJson({'color': 'teal'}), made);
    expect(UnitColour.fromJson({'color': 'teal'}).hashCode, made.hashCode);
    expect(UnitColour.fromJson({'color': 'purple'}) == made, isFalse);
    expect(UnitColour(purple).swatch, purple);

    final unknown = UnitColour.fromJson({'color': 'magenta'});
    expect(unknown.name, 'magenta');
    expect(unknown.swatch, isNull);
    expect(unknown.isKept, isFalse);
    expect(unknown.toJson(), {'color': 'magenta'});
    expect(unknown == made, isFalse);

    for (final raw in <Map<String, Object?>>[
      {'color': 7},
      {'hue': 'teal'},
      {'color': 'teal', 'x': 1},
      {'color': null},
      {
        'color': <Object?>['teal']
      },
      <String, Object?>{},
    ]) {
      final kept = UnitColour.fromJson(raw);
      expect(kept.isKept, isTrue, reason: '$raw');
      expect(kept.name, isNull, reason: '$raw');
      expect(kept.swatch, isNull, reason: '$raw');
      expect(kept.toJson(), raw, reason: '$raw');
      expect(jsonEncode(kept.toJson()), jsonEncode(raw), reason: '$raw');
      expect(kept == made, isFalse, reason: '$raw');
      expect(UnitColour.fromJson(raw), kept, reason: '$raw');
    }
    final deep = UnitColour.fromJson({
      'color': {
        'a': [1, 2]
      }
    });
    expect(() => (deep.kept!['color'] as Map)['b'] = 1, throwsUnsupportedError,
        reason: 'unmodifiable all the way down');
  });
}
