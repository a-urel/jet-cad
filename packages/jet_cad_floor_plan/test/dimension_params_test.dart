// Spec 11 D2, D3: a dimension's parameters. Its JSON (every key, in order,
// both end shapes), its exact value equality with the offset's sign bit as
// its side (R-2), a `-0.0` offset kept through save, load and save, and
// `references` deduplicated.
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dimension_fixture.dart';

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;

void main() {
  for (final place in [origin, corpusGroups]) {
    test(
        'DP1 DimensionParams round-trips with its keys in order and both '
        'end shapes; == is exact and tells -0.0 from +0.0, kept through save, '
        'load and save; references are deduplicated, at $place', () {
      // Two walls at the placement: A (0, 0) -> (4000, 0), B (4000, 0) ->
      // (4000, 3000), 200 each.
      final plan = buildPlan(
          const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
          place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [wa, wb] = plan.walls;

      // --- JSON: the key order and the two end shapes' exact maps. ---
      final p = DimensionParams(AttachedEnd(wb, 1, l),
          const FixedEnd(1234.5, -310.25), DimKind.vertical, -617.375);
      final json = p.toJson();
      expect(json.keys.toList(), ['a', 'b', 'kind', 'offset']);
      expect(json['a'], {'wall': wb.value, 'k': 1, 'side': 'left'});
      expect((json['a']! as Map).keys.toList(), ['wall', 'k', 'side']);
      expect(json['b'], {
        'point': [1234.5, -310.25],
      });
      expect(json['kind'], 'vertical');
      expect(json['offset'], -617.375);
      // Through the JSON text, as a file carries it: equal and the same
      // bytes again.
      final text = jsonEncode(json);
      final back =
          DimensionParams.fromJson(jsonDecode(text) as Map<String, Object?>);
      expect(back, p);
      expect(back.b, isA<FixedEnd>());
      expect((back.b as FixedEnd).x, 1234.5);
      expect((back.b as FixedEnd).y, -310.25);
      expect(back.offset, -617.375);
      expect(jsonEncode(back.toJson()), text);
      // The other end shapes the other way round, and every side and kind.
      for (final kind in DimKind.values) {
        for (final side in WallSide.values) {
          final q = DimensionParams(const FixedEnd(-0.5, 7.25),
              AttachedEnd(wa, 0, side), kind, 12.125);
          expect(
              DimensionParams.fromJson(
                  jsonDecode(jsonEncode(q.toJson())) as Map<String, Object?>),
              q);
        }
      }

      // An unknown kind or side throws; `k = 2` is accepted (R-3).
      Map<String, Object?> with_(String key, Object? value) =>
          jsonDecode(jsonEncode(json)) as Map<String, Object?>..[key] = value;
      expect(() => DimensionParams.fromJson(with_('kind', 'diagonal')),
          throwsArgumentError);
      expect(
          () => DimensionParams.fromJson(
              with_('a', {'wall': wb.value, 'k': 1, 'side': 'middle'})),
          throwsArgumentError);
      final k2 = DimensionParams.fromJson(
          with_('a', {'wall': wb.value, 'k': 2, 'side': 'right'}));
      expect(k2.a, AttachedEnd(wb, 2, r));

      // --- ==: exact, the offset by compareTo. ---
      // The premise: Dart's == does not tell the zeros apart.
      expect(-0.0 == 0.0, isTrue);
      final plus = p.copyWith(offset: 0.0), minus = p.copyWith(offset: -0.0);
      expect(minus.offset.isNegative, isTrue);
      expect(plus.offset.isNegative, isFalse);
      expect(plus == minus, isFalse);
      expect(minus == p.copyWith(offset: -0.0), isTrue);
      expect(minus.hashCode, p.copyWith(offset: -0.0).hashCode);
      // A NaN offset equals itself (only a command makes one).
      final nan = p.copyWith(offset: double.nan);
      expect(nan == p.copyWith(offset: double.nan), isTrue);
      expect(nan.hashCode, p.copyWith(offset: double.nan).hashCode);
      // Every field counts.
      expect(p == p.copyWith(offset: -617.375 + 1e-9), isFalse);
      expect(p == p.copyWith(kind: DimKind.horizontal), isFalse);
      expect(p == p.copyWith(a: AttachedEnd(wb, 1, r)), isFalse);
      expect(p == p.copyWith(a: AttachedEnd(wb, 0, l)), isFalse);
      expect(p == p.copyWith(a: AttachedEnd(wa, 1, l)), isFalse);
      expect(p == p.copyWith(b: const FixedEnd(1234.5, -310.5)), isFalse);
      expect(p == p.copyWith(b: const FixedEnd(1234.25, -310.25)), isFalse);

      // --- Save -> load -> save of a -0.0 dimension. ---
      final g = place.m;
      final dim = addDimension(
          doc, AttachedEnd(wa, 1, r), fixedAt(plan.at(1234.5, -310.25), g),
          kind: DimKind.horizontal, offset: -0.0, at: g);
      expect(
          doc.components.get<DimensionParams>(dim)!.offset.isNegative, isTrue);
      final saved = enc(doc);
      final loaded = reloadWithPage(saved);
      final lp = loaded.components.get<DimensionParams>(dim)!;
      expect(lp.offset.isNegative, isTrue);
      expect(lp, doc.components.get<DimensionParams>(dim));
      expect(enc(loaded), saved);
      expect(driftOf(loaded), isEmpty);

      // --- references: in a, b order, deduplicated. ---
      const type = DimensionType();
      // Both ends on one wall: one handle.
      expect(
          type
              .references(DimensionParams(AttachedEnd(wa, 0, l),
                  AttachedEnd(wa, 1, c), DimKind.aligned, 1.5))
              .toList(),
          [wa]);
      // Attached and fixed, either way round: one.
      expect(
          type
              .references(DimensionParams(const FixedEnd(1.5, 2.5),
                  AttachedEnd(wb, 1, r), DimKind.aligned, 1.5))
              .toList(),
          [wb]);
      expect(type.references(p).toList(), [wb]);
      // Two walls: two, in a, b order (B's handle is the higher, first).
      expect(
          type
              .references(DimensionParams(AttachedEnd(wb, 0, l),
                  AttachedEnd(wa, 0, r), DimKind.aligned, 1.5))
              .toList(),
          [wb, wa]);
      // Fixed and fixed: none.
      expect(
          type.references(DimensionParams(const FixedEnd(1.5, 2.5),
              const FixedEnd(3.5, 4.5), DimKind.aligned, 1.5)),
          isEmpty);
    });
  }
}
