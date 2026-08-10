import 'dart:typed_data';

import '../store/entity_store.dart';

/// A reusable result buffer for one query.
///
/// Ordering requires buffering, so a query that promises ascending handle
/// order cannot stream straight to its visitor. This is that buffer, owned by
/// the index and reused, so a query allocates nothing in steady state.
///
/// [reset] deliberately does not shrink: capacity is the whole point, and a
/// scratch that shrank would regrow on every query, which is exactly the
/// allocation this exists to avoid. That is also why the allocation harness
/// warms a query before asserting.
class QueryScratch {
  /// Clamped to at least 1: a capacity of 0 would construct without error but
  /// then throw a `RangeError` on the very first [add], since doubling zero
  /// stays zero. There is no legitimate reason to want a zero-capacity
  /// scratch, so this corrects it silently rather than adding a precondition
  /// every caller would have to satisfy for no benefit.
  QueryScratch([int initialCapacity = 1024])
      : _slots = Uint32List(initialCapacity < 1 ? 1 : initialCapacity);

  Uint32List _slots;
  int _length = 0;

  int get length => _length;
  int get capacity => _slots.length;

  /// Bounds-checked against the live length, not the backing array's
  /// capacity: `_slots` keeps whatever a previous, longer query left behind
  /// past `_length`, since [reset] only rewinds the cursor. Indexing that
  /// stale tail would silently hand back a slot from an earlier query instead
  /// of failing — this class is publicly exported, so an off-by-one in a
  /// caller must throw, not visit the wrong entity.
  int operator [](int i) {
    if (i < 0 || i >= _length) {
      throw RangeError.index(i, this, 'index', null, _length);
    }
    return _slots[i];
  }

  void reset() => _length = 0;

  void add(int slot) {
    if (_length == _slots.length) {
      final grown = Uint32List(_slots.length * 2);
      grown.setRange(0, _length, _slots);
      _slots = grown;
    }
    _slots[_length++] = slot;
  }

  /// Sorts the live prefix by entity handle, ascending.
  ///
  /// Hand-written rather than `List.sort`, which would need a sublist view of
  /// the live prefix — and that view allocates, once per query, on the frame
  /// path.
  ///
  /// Insertion sort below a threshold, heapsort above it. Heapsort rather than
  /// quicksort because it is in-place with no recursion and no worst case that
  /// a crafted document could trigger.
  void sortByHandle(EntityStore entities) {
    if (_length < 2) return;
    if (_length <= 32) {
      for (var i = 1; i < _length; i++) {
        final value = _slots[i];
        final key = entities.handleAt(value).value;
        var j = i - 1;
        while (j >= 0 && entities.handleAt(_slots[j]).value > key) {
          _slots[j + 1] = _slots[j];
          j--;
        }
        _slots[j + 1] = value;
      }
      return;
    }

    for (var start = (_length >> 1) - 1; start >= 0; start--) {
      _siftDown(entities, start, _length);
    }
    for (var end = _length - 1; end > 0; end--) {
      final tmp = _slots[0];
      _slots[0] = _slots[end];
      _slots[end] = tmp;
      _siftDown(entities, 0, end);
    }
  }

  void _siftDown(EntityStore entities, int root, int end) {
    var parent = root;
    while (true) {
      final left = parent * 2 + 1;
      if (left >= end) return;
      var swap = parent;
      if (entities.handleAt(_slots[swap]).value <
          entities.handleAt(_slots[left]).value) {
        swap = left;
      }
      final right = left + 1;
      if (right < end &&
          entities.handleAt(_slots[swap]).value <
              entities.handleAt(_slots[right]).value) {
        swap = right;
      }
      if (swap == parent) return;
      final tmp = _slots[parent];
      _slots[parent] = _slots[swap];
      _slots[swap] = tmp;
      parent = swap;
    }
  }

  /// Sorts the live prefix ascending by the stored value itself, not by an
  /// indirect entity-handle lookup.
  ///
  /// For a buffer whose stored ints already *are* the sort key — an instance
  /// [Handle.value], not an entity slot — [sortByHandle] would be the wrong
  /// tool: it looks the key up through [EntityStore.handleAt], which a slot
  /// value from a different domain cannot satisfy. Same two algorithms,
  /// same threshold, same in-place, non-recursive shape; only the key
  /// extraction differs, which is why this is a second method rather than a
  /// parameter — a key-extractor callback would itself be a closure
  /// allocated on the query path, the exact cost this class exists to avoid.
  void sortByValue() {
    if (_length < 2) return;
    if (_length <= 32) {
      for (var i = 1; i < _length; i++) {
        final value = _slots[i];
        var j = i - 1;
        while (j >= 0 && _slots[j] > value) {
          _slots[j + 1] = _slots[j];
          j--;
        }
        _slots[j + 1] = value;
      }
      return;
    }

    for (var start = (_length >> 1) - 1; start >= 0; start--) {
      _siftDownValue(start, _length);
    }
    for (var end = _length - 1; end > 0; end--) {
      final tmp = _slots[0];
      _slots[0] = _slots[end];
      _slots[end] = tmp;
      _siftDownValue(0, end);
    }
  }

  void _siftDownValue(int root, int end) {
    var parent = root;
    while (true) {
      final left = parent * 2 + 1;
      if (left >= end) return;
      var swap = parent;
      if (_slots[swap] < _slots[left]) swap = left;
      final right = left + 1;
      if (right < end && _slots[swap] < _slots[right]) swap = right;
      if (swap == parent) return;
      final tmp = _slots[parent];
      _slots[parent] = _slots[swap];
      _slots[swap] = tmp;
      parent = swap;
    }
  }
}
