import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Aabb2 box(double x, double y, double w, double h) =>
    Aabb2(Vector2(x, y), Vector2(x + w, y + h));

List<int> hits(DirtyList list, Aabb2 q) {
  final out = <int>[];
  list.search(q.minX, q.minY, q.maxX, q.maxY, out.add);
  out.sort();
  return out;
}

void main() {
  test('starts empty', () {
    final list = DirtyList();
    expect(list.length, 0);
    expect(list.isEmpty, isTrue);
    expect(hits(list, box(-1e9, -1e9, 2e9, 2e9)), isEmpty);
  });

  test('finds an entry whose box overlaps', () {
    final list = DirtyList()..put(7, box(0, 0, 1, 1));
    expect(hits(list, box(0.5, 0.5, 1, 1)), [7]);
    expect(hits(list, box(10, 10, 1, 1)), isEmpty);
  });

  test('repeated put on one slot replaces in place and does not grow', () {
    final list = DirtyList();
    for (var i = 0; i < 200; i++) {
      list.put(7, box(i.toDouble(), 0, 1, 1));
    }
    expect(list.length, 1,
        reason: 'a 200-move drag must leave one entry, not 200');

    // The surviving box is the last one written, not the first.
    expect(hits(list, box(199, 0, 1, 1)), [7]);
    expect(hits(list, box(0, 0, 0.5, 1)), isEmpty);
  });

  test('remove drops an entry and keeps the rest findable', () {
    final list = DirtyList()
      ..put(1, box(0, 0, 1, 1))
      ..put(2, box(2, 0, 1, 1))
      ..put(3, box(4, 0, 1, 1));

    list.remove(2);

    expect(list.length, 2);
    expect(list.contains(2), isFalse);
    expect(hits(list, box(-1, -1, 100, 100)), [1, 3]);
  });

  test('remove of the last entry, and of an absent slot, are both safe', () {
    final list = DirtyList()..put(1, box(0, 0, 1, 1));
    list.remove(99);
    expect(list.length, 1);
    list.remove(1);
    expect(list.isEmpty, isTrue);
    expect(hits(list, box(-1, -1, 100, 100)), isEmpty);
  });

  test('removal by swap keeps every remaining slot findable', () {
    // Swap-remove moves the last entry into the hole. If the slot->position
    // map is not updated for the moved entry, that entry becomes unfindable
    // and unremovable. This is the defect the test exists for.
    final list = DirtyList();
    for (var i = 0; i < 10; i++) {
      list.put(i, box(i.toDouble(), 0, 0.5, 1));
    }
    list.remove(0); // moves slot 9 into position 0

    expect(hits(list, box(9, 0, 0.5, 1)), [9]);
    list.remove(9);
    expect(list.contains(9), isFalse);
    expect(hits(list, box(-1, -1, 100, 100)), [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('clear empties everything', () {
    final list = DirtyList()
      ..put(1, box(0, 0, 1, 1))
      ..put(2, box(2, 0, 1, 1));
    list.clear();
    expect(list.isEmpty, isTrue);
    expect(list.contains(1), isFalse);
    expect(hits(list, box(-1, -1, 100, 100)), isEmpty);
  });

  test('an empty box is stored and never matches', () {
    final list = DirtyList()..put(5, Aabb2.empty());
    expect(list.length, 1);
    expect(hits(list, box(-1e9, -1e9, 2e9, 2e9)), isEmpty,
        reason: 'an empty box has minX > maxX and overlaps nothing');
  });

  test('every Aabb2.isEmpty shape is stored and never matches', () {
    // Aabb2.isEmpty is `minX > maxX || minY > maxY`. Three distinct shapes
    // satisfy that:
    //   - the canonical form, inverted-infinite on both axes;
    //   - a single axis inverted with infinite bounds;
    //   - a single axis inverted with *finite* bounds — the shape that
    //     originally slipped through, because its own overlap clause does
    //     not fail unconditionally the way the infinite forms' do.
    // put() must normalise all three to the canonical form so search's
    // ordinary overlap test rejects them by arithmetic, not convention.
    final canonical = Aabb2.empty();
    final infiniteAxisInverted =
        Aabb2.raw(double.infinity, 0, double.negativeInfinity, 10);
    final finiteAxisInverted = Aabb2.raw(5, 0, 3, 10);

    final list = DirtyList()
      ..put(1, canonical)
      ..put(2, infiniteAxisInverted)
      ..put(3, finiteAxisInverted);

    expect(list.length, 3);
    expect(list.contains(1), isTrue);
    expect(list.contains(2), isTrue);
    expect(list.contains(3), isTrue);
    expect(hits(list, box(-100, -100, 200, 200)), isEmpty,
        reason: 'every isEmpty shape must be rejected, not just the '
            'canonical inverted-infinity one');
  });
}
