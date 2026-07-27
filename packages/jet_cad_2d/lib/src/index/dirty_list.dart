import 'dart:typed_data';

import '../geometry/aabb2.dart';

/// Entities edited since the last index rebuild, scanned linearly.
///
/// Keyed by slot with replace-in-place, never append. A drag emits one edit
/// per pointer-move; appending would put 200 entries in this list for one
/// entity, trip the rebuild threshold mid-drag, and rebuild during exactly the
/// burst this structure exists to avoid.
///
/// Removal is by swap with the last entry, which is O(1) and reorders the
/// list. Order here is irrelevant: [search] visits everything and callers sort
/// results by handle.
class DirtyList {
  final Map<int, int> _positionOf = <int, int>{};
  Int32List _slots = Int32List(16);
  Float64List _boxes = Float64List(16 * 4);
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool contains(int slot) => _positionOf.containsKey(slot);

  /// Records [box] for [slot], replacing any box already recorded for it.
  void put(int slot, Aabb2 box) {
    final existing = _positionOf[slot];
    final at = existing ?? _length;
    if (existing == null) {
      if (_length == _slots.length) _grow();
      _slots[at] = slot;
      _positionOf[slot] = at;
      _length++;
    }
    _boxes[at * 4] = box.minX;
    _boxes[at * 4 + 1] = box.minY;
    _boxes[at * 4 + 2] = box.maxX;
    _boxes[at * 4 + 3] = box.maxY;
  }

  /// Drops [slot]. Safe to call for a slot that is not present.
  void remove(int slot) {
    final at = _positionOf.remove(slot);
    if (at == null) return;
    final last = _length - 1;
    if (at != last) {
      // Swap the last entry into the hole, and — the part that is easy to
      // forget — repoint that entry's map entry at its new position.
      final movedSlot = _slots[last];
      _slots[at] = movedSlot;
      _boxes[at * 4] = _boxes[last * 4];
      _boxes[at * 4 + 1] = _boxes[last * 4 + 1];
      _boxes[at * 4 + 2] = _boxes[last * 4 + 2];
      _boxes[at * 4 + 3] = _boxes[last * 4 + 3];
      _positionOf[movedSlot] = at;
    }
    _length = last;
  }

  /// Visits the slot of every entry whose box overlaps the query.
  ///
  /// Allocates nothing: a plain index loop over typed arrays.
  void search(double minX, double minY, double maxX, double maxY,
      void Function(int slot) visit) {
    for (var i = 0; i < _length; i++) {
      if (_boxes[i * 4] <= maxX &&
          _boxes[i * 4 + 1] <= maxY &&
          _boxes[i * 4 + 2] >= minX &&
          _boxes[i * 4 + 3] >= minY) {
        visit(_slots[i]);
      }
    }
  }

  void clear() {
    _positionOf.clear();
    _length = 0;
  }

  void _grow() {
    final slots = Int32List(_slots.length * 2);
    slots.setRange(0, _length, _slots);
    _slots = slots;
    final boxes = Float64List(_boxes.length * 2);
    boxes.setRange(0, _length * 4, _boxes);
    _boxes = boxes;
  }
}
