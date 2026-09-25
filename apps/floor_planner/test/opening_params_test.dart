// Spec 08 D6: OpeningParams, its JSON shape and exact equality.
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

void main() {
  // Non-round, non-default values: a key-order or field swap cannot hide.
  const door = OpeningParams(Handle(0x2A3F), 1733.375, 912.5, OpeningKind.door,
      hinge: HingeEnd.end, swing: SwingSide.right);

  test(
      'OP1 key order and values; an exact round trip per kind; == differs '
      'on each field alone; an unknown kind throws; a position outside the '
      'wall and a width of 0 load', () {
    final j = door.toJson();
    expect(j.keys.toList(),
        ['host', 'position', 'width', 'kind', 'hinge', 'swing']);
    expect(j['host'], 0x2A3F);
    expect(j['host'], isA<int>());
    expect(j['position'], 1733.375);
    expect(j['width'], 912.5);
    expect(j['kind'], 'door');
    expect(j['hinge'], 'end');
    expect(j['swing'], 'right');
    expect(door.typeId, 'floor_planner.opening');
    expect(OpeningParams.componentTypeId, 'floor_planner.opening');
    // A window or a gap writes all six keys too, the tools' defaults.
    final w = const OpeningParams(Handle(77), 400.25, 1200, OpeningKind.window)
        .toJson();
    expect(w.keys.toList(),
        ['host', 'position', 'width', 'kind', 'hinge', 'swing']);
    expect([w['kind'], w['hinge'], w['swing']], ['window', 'start', 'left']);

    // 0.1 and 1/3 are not dyadic: a lossy codec shows.
    for (final kind in OpeningKind.values) {
      for (final hinge in HingeEnd.values) {
        for (final swing in SwingSide.values) {
          final o = OpeningParams(
              const Handle(0xFFFFFFFF), 4500000.1, 2700.0 / 3, kind,
              hinge: hinge, swing: swing);
          final back = OpeningParams.fromJson(o.toJson());
          expect(back, o);
          expect(back.host, o.host);
          expect(back.position, o.position);
          expect(back.width, o.width);
          expect(back.kind, kind);
          expect(back.hinge, hinge);
          expect(back.swing, swing);
        }
      }
    }
    // Integer JSON numbers decode as doubles.
    expect(
        OpeningParams.fromJson({
          'host': 9,
          'position': 1500,
          'width': 900,
          'kind': 'gap',
          'hinge': 'start',
          'swing': 'left',
        }),
        const OpeningParams(Handle(9), 1500, 900, OpeningKind.gap));

    const same = OpeningParams(
        Handle(0x2A3F), 1733.375, 912.5, OpeningKind.door,
        hinge: HingeEnd.end, swing: SwingSide.right);
    expect(same, door);
    expect(same.hashCode, door.hashCode);
    final differ = [
      const OpeningParams(Handle(0x2A40), 1733.375, 912.5, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
      const OpeningParams(
          Handle(0x2A3F), 1733.3750000000002, 912.5, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
      const OpeningParams(
          Handle(0x2A3F), 1733.375, 912.5000000000001, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
      const OpeningParams(Handle(0x2A3F), 1733.375, 912.5, OpeningKind.window,
          hinge: HingeEnd.end, swing: SwingSide.right),
      const OpeningParams(Handle(0x2A3F), 1733.375, 912.5, OpeningKind.door,
          hinge: HingeEnd.start, swing: SwingSide.right),
      const OpeningParams(Handle(0x2A3F), 1733.375, 912.5, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.left),
    ];
    for (final (i, o) in differ.indexed) {
      expect(o == door, isFalse, reason: 'field $i');
      expect(door == o, isFalse, reason: 'field $i');
    }
    expect(door.copyWith(), door);
    expect(
        door.copyWith(position: 250.5, hinge: HingeEnd.start),
        const OpeningParams(Handle(0x2A3F), 250.5, 912.5, OpeningKind.door,
            hinge: HingeEnd.start, swing: SwingSide.right));

    final bad = door.toJson()..['kind'] = 'skylight';
    expect(() => OpeningParams.fromJson(bad), throwsArgumentError);

    // Outside the wall (after a shortening, D13) and a degenerate width
    // (D6) are legal stored values.
    final odd = door.toJson()
      ..['position'] = -3250.75
      ..['width'] = 0;
    final loaded = OpeningParams.fromJson(odd);
    expect(loaded.position, -3250.75);
    expect(loaded.width, 0.0);
    final far = OpeningParams.fromJson(door.toJson()..['position'] = 1e7);
    expect(far.position, 1e7);

    // D6's validation range, the tools' and the panel's.
    expect(isOpeningWidth(OpeningKind.door, wallJoin.linear), isFalse);
    expect(isOpeningWidth(OpeningKind.door, 2 * wallJoin.linear), isTrue);
    expect(isOpeningWidth(OpeningKind.gap, 4 * wallJoin.linear), isFalse);
    expect(isOpeningWidth(OpeningKind.gap, 5 * wallJoin.linear), isTrue);
    for (final w in [0.0, -900.0, double.nan, double.infinity]) {
      expect(isOpeningWidth(OpeningKind.window, w), isFalse, reason: '$w');
    }
  });
}
