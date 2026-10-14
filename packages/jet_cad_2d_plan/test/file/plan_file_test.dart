// Spec 2a P4 "The plan file", P5 "Imported text without a manifest": a
// load refuses by code and changes nothing; a save writes the manifest and
// is byte-stable; a component this build cannot read is kept raw; an
// import gets an empty manifest.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

/// The fixture: a turned slab off the origin, a disc, a line.
String fixture() => planText([testKit(), discKit()], (d) {
      addObject<SlabComponent>(
          d,
          SlabComponent(
              width: 1800,
              height: 900,
              angle: 0.4,
              finish: 'tiled',
              swatch: 'red'),
          at: Vector2(2350, -1180));
      addObject<DiscComponent>(d, DiscComponent(radius: 650),
          at: Vector2(-3100, 2240));
      addLine(d, Vector2(-500, 700), Vector2(1800, 2400));
    });

DraftDocument decode(String text,
    {List<PlanKit>? kits, List<Diagnostic>? diagnostics}) {
  final catalog = catalogOf(kits ?? [testKit(), discKit()]);
  return decodePlan(text,
      register: (r) => registerPlanComponents(r, catalog),
      diagnostics: diagnostics ?? <Diagnostic>[]);
}

Map<String, Object?> jsonOf(String text) =>
    (jsonDecode(text) as Map<String, Object?>);

Map<String, Object?> componentsOf(Map<String, Object?> json) =>
    json['components']! as Map<String, Object?>;

String rootKey(Map<String, Object?> json) => '${json['root']}';

Matcher refusedWith(PlanFormatCode code) => throwsA(allOf(
    isA<FormatException>(),
    isA<PlanFormatException>().having((e) => e.code, 'code', code)));

void main() {
  test('PF-1 each refusal has its code, and is a FormatException', () {
    final good = jsonOf(fixture());
    String withManifest(Object? manifest) {
      final json = jsonOf(fixture());
      final byHandle =
          componentsOf(json)['jetcad.manifest']! as Map<String, Object?>;
      byHandle[rootKey(json)] = manifest;
      return jsonEncode(json);
    }

    final noManifest = jsonOf(fixture());
    componentsOf(noManifest).remove('jetcad.manifest');
    final cases = <String, PlanFormatCode>{
      'not json': PlanFormatCode.notJson,
      '[1, 2]': PlanFormatCode.notJson,
      '{}': PlanFormatCode.noManifest,
      jsonEncode(noManifest): PlanFormatCode.noManifest,
      withManifest({'format': 2, 'kits': <String, Object?>{}}):
          PlanFormatCode.formatTooNew,
      withManifest({'format': '1', 'kits': <String, Object?>{}}):
          PlanFormatCode.schema,
      withManifest({
        'format': 1,
        'kits': {'Bad': '1.0.0'},
      }): PlanFormatCode.schema,
      jsonEncode({...good, 'schemaVersion': 9999}): PlanFormatCode.schema,
      jsonEncode({...good, 'entities': 7}): PlanFormatCode.schema,
    };
    // M-PF-1a: no manifest check. M-PF-1b: `format > kPlanFormat + 1`.
    // M-PF-1c: the engine's errors rethrown as they are, not as schema.
    for (final MapEntry(key: text, value: code) in cases.entries) {
      expect(() => decode(text), refusedWith(code), reason: text);
    }
    expect('${const PlanFormatException(PlanFormatCode.noManifest, 'none')}',
        'PlanFormatException(noManifest): none');
  });

  test(
      'PF-unreadable a component whose factory throws is kept raw: the plan '
      'opens, the diagnostic names it, and a save writes it byte for byte', () {
    final json = jsonOf(fixture());
    final slabs = componentsOf(json)[slabTypeId]! as Map<String, Object?>;
    final key = slabs.keys.single;
    (slabs[key]! as Map<String, Object?>)['width'] = 'wide';
    final broken = jsonEncode(json);
    final diagnostics = <Diagnostic>[];
    // M-PF-unreadable: `keepUnreadableComponents: true` removed from
    // decodePlan's codec call: the load is refused as schema.
    final d = decode(broken, diagnostics: diagnostics);
    final h = Handle.checked(int.parse(key));
    expect(d.components.get<SlabComponent>(h), isNull);
    expect(d.components.unknownOf(h), hasLength(1));
    expect(
        diagnostics
            .where((x) => x.code == 'component.unreadable')
            .single
            .handles,
        [h]);
    final saved = componentsOf(
        jsonOf(encodePlan(d, validateKitSet([testKit(), discKit()]))));
    expect(jsonEncode(saved[slabTypeId]), jsonEncode(slabs));
  });

  test('PF-6 a save is byte-stable: encode(decode(x)) == x, twice', () {
    final x = planText([testKit(), discKit()], (d) {
      addObject<SlabComponent>(
          d, SlabComponent(width: 1800, height: 900, angle: 0.4),
          at: Vector2(2350, -1180));
      addObject<DiscComponent>(d, DiscComponent(radius: 650),
          at: Vector2(-3100, 2240));
      d.components
          .attachUnknown(d.rootHandle, {'typeId': 'gone.widget', 'size': 3});
    });
    final loaded = validateKitSet([testKit(), discKit()]);
    final types = componentsOf(jsonOf(x)).keys.toList();
    // M-PF-6: the components map not re-sorted after the manifest is put in.
    expect(types, [...types]..sort(), reason: 'premise: the canonical order');
    final y = encodePlan(decode(x), loaded);
    expect(y, x);
    expect(encodePlan(decode(y), loaded), x);
  });

  test("PF-9 a missing kit's entry and objects round-trip through a save", () {
    final json = jsonOf(fixture());
    componentsOf(json)['gone.widget'] = {
      rootKey(json): {'b': 2, 'a': 1},
    };
    final manifest =
        componentsOf(json)['jetcad.manifest']! as Map<String, Object?>;
    manifest[rootKey(json)] = {
      'format': 1,
      'kits': {'disc': '0.4.0', 'gone': '3.1.0', 'test': '9.0.0'},
    };
    final saved = jsonOf(encodePlan(decode(jsonEncode(json)),
        validateKitSet([testKit(version: '1.2.0'), discKit()])));
    expect(
        (componentsOf(saved)['jetcad.manifest']!
            as Map<String, Object?>)[rootKey(saved)],
        {
          'format': 1,
          'kits': {'disc': '0.4.0', 'gone': '3.1.0', 'test': '1.2.0'},
        });
    expect(
        jsonEncode(componentsOf(saved)['gone.widget']),
        jsonEncode({
          rootKey(json): {'b': 2, 'a': 1}
        }));
  });

  test(
      'PF-10 an import without a manifest gets an empty one and opens as '
      'plain geometry; one with a manifest is returned as it is', () {
    final kits = [testKit()];
    final drawing = planDocument(kits);
    final line = addLine(drawing, Vector2(-500, 700), Vector2(1800, 2400));
    final imported = DraftDocumentCodec.encodeToString(drawing);
    expect(() => decode(imported), refusedWith(PlanFormatCode.noManifest),
        reason: 'premise: without the manifest the load refuses');
    // M-PF-10a: ensureManifest returns its text unchanged.
    final d = decode(ensureManifest(imported), kits: kits);
    expect(manifestOf(d), const PlanManifest());
    expect(usedKits(d), isEmpty);
    expect(d.entities.containsHandle(line), isTrue);

    final plan = fixture();
    // M-PF-10b: ensureManifest always re-encodes.
    expect(ensureManifest(plan), same(plan));
    expect(
        () => ensureManifest('not json'), refusedWith(PlanFormatCode.notJson));
  });
}
