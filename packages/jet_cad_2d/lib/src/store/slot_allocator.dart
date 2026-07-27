class SlotStateError implements Exception {
  final int slot;
  final String message;
  const SlotStateError(this.slot, this.message);

  @override
  String toString() => 'SlotStateError(slot $slot): $message';
}

/// Allocates and recycles slots for a columnar store, and owns the slot
/// lifetime rules that both stores share.
///
/// 1. Slot values are opaque and change **only** inside a command that also
///    rewrites every reference to them. There is no ambient compaction: not on
///    delete, not on load, not on idle. Without this rule the id-remapping
///    problem rejected for the 3D document reappears one layer down.
/// 2. Deletion returns the slot to a free list. An inverse command carries the
///    **payload**, never the slot, so undo may legitimately land in a different
///    slot and update the referencing record.
/// 3. [compact] exists only to serve an explicit `purge()` maintenance
///    operation, which rewrites all references and clears the undo stack. It is
///    not a command and is not undoable.
class SlotAllocator {
  final List<bool> _live = [];
  final List<int> _free = [];

  /// One past the highest slot ever allocated — the length the columns must
  /// have, including dead slots.
  int get capacity => _live.length;

  int get liveCount => _live.length - _free.length;

  bool isLive(int slot) =>
      slot >= 0 && slot < _live.length && _live[slot];

  /// Live slots in ascending order. Ascending rather than insertion or hash
  /// order because every query built on a store must be stably ordered.
  Iterable<int> get liveSlots sync* {
    for (var i = 0; i < _live.length; i++) {
      if (_live[i]) yield i;
    }
  }

  int allocate() {
    if (_free.isNotEmpty) {
      final slot = _free.removeLast();
      _live[slot] = true;
      return slot;
    }
    _live.add(true);
    return _live.length - 1;
  }

  void free(int slot) {
    if (slot < 0 || slot >= _live.length) {
      throw SlotStateError(slot, 'outside 0..${_live.length - 1}');
    }
    if (!_live[slot]) throw SlotStateError(slot, 'already free');
    _live[slot] = false;
    _free.add(slot);
  }

  /// Collapses live slots into a dense range and returns the remap.
  ///
  /// The result is indexed by old slot; the value is the new slot, or -1 if the
  /// slot was dead. Relative order is preserved so that any ordering a caller
  /// derived from slot numbers survives. The caller is responsible for moving
  /// its columns and rewriting every reference — this class only decides the
  /// mapping.
  List<int> compact() {
    final remap = List<int>.filled(_live.length, -1);
    var next = 0;
    for (var i = 0; i < _live.length; i++) {
      if (_live[i]) remap[i] = next++;
    }
    _live
      ..clear()
      ..addAll(List<bool>.filled(next, true));
    _free.clear();
    return remap;
  }

  void clear() {
    _live.clear();
    _free.clear();
  }
}
