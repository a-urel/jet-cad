import 'package:jet_cad_2d/jet_cad_2d.dart';

/// Definition (or group, or root) → the slots of the leaves it owns, ascending.
///
/// **Re-derive and compare, not a typed change kind.** `DocChange` carries only
/// a label and a `touched` set — `SetComponentCommand` touches an entity handle
/// exactly as a geometry edit does — so this cannot be told what changed. It
/// looks each touched handle up and re-derives that one slot's bucket, which is
/// the same doctrine `SpatialIndex`'s own invalidation follows and for the same
/// reason.
///
/// Fed by the caller rather than by a subscription: `onAfterMutate` is the
/// document's only synchronous change channel and `SpatialIndex` owns that
/// single slot, while the asynchronous `changes` stream is soon enough for
/// something the painter reads once a frame.
class LeafOwnerMap {
  LeafOwnerMap(this.document) {
    rebuild();
  }

  final DraftDocument document;

  final Map<Handle, List<int>> _byOwner = <Handle, List<int>>{};

  /// The slot each handle occupied when it was last reconciled.
  ///
  /// Removal is why this exists: once an entity is gone, `slotOf` cannot say
  /// which slot it had, and the alternative — scanning every bucket for slots
  /// that are no longer live — is a full pass per removal. A drag is spelled
  /// as remove-then-add per pointer sample, so that pass would run at pointer
  /// rate.
  final Map<Handle, int> _slotOfHandle = <Handle, int>{};

  /// Which bucket a slot currently sits in, so dropping it is a lookup and a
  /// binary search rather than a scan of every owner's bucket.
  final Map<int, Handle> _ownerOfSlot = <int, Handle>{};

  int rebuildCount = 0;

  /// The leaves [owner] holds directly, ascending by slot. Never null: an
  /// owner with nothing in it and an owner that does not exist are the same
  /// answer to a painter.
  List<int> slotsOf(Handle owner) => _byOwner[owner] ?? const <int>[];

  void rebuild() {
    rebuildCount++;
    _byOwner
      ..clear()
      ..addAll(document.leavesByOwner());
    _slotOfHandle.clear();
    _ownerOfSlot.clear();
    for (final entry in _byOwner.entries) {
      entry.value.sort();
      for (final slot in entry.value) {
        _slotOfHandle[document.entities.handleAt(slot)] = slot;
        _ownerOfSlot[slot] = entry.key;
      }
    }
  }

  void applyChange(DocChange change) {
    switch (change) {
      // Slots are renumbered by a purge and wholly replaced by a load, so
      // every slot-keyed structure is invalid and there is no incremental path
      // back — the same answer SpatialIndex gives.
      case DocumentLoaded():
      case DocumentPurged():
        rebuild();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        // `DocChange` documents an empty set as "the whole document changed",
        // and a change that names nothing cannot be reconciled handle by
        // handle.
        if (touched.isEmpty) {
          rebuild();
          return;
        }
        for (final handle in touched) {
          _reconcile(handle);
        }
    }
  }

  void _reconcile(Handle handle) {
    final slot = document.entities.slotOf(handle);
    if (slot == null) {
      _forget(handle);
      return;
    }
    final owner = document.entities.ownerAt(slot);
    final previousSlot = _slotOfHandle[handle];
    if (previousSlot == slot && _ownerOfSlot[slot] == owner) return;
    if (previousSlot != null) _dropSlot(previousSlot);
    // A slot comes off a free list, so the one this entity was just given may
    // still be filed under whoever vacated it.
    _dropSlot(slot);

    final bucket = _byOwner[owner] ??= <int>[];
    // Buckets stay ascending. The painter sorts by handle before drawing, but
    // an unsorted bucket would make its own dedupe pass — which only compares
    // neighbours — order-dependent.
    bucket.insert(_lowerBound(bucket, slot), slot);
    _slotOfHandle[handle] = slot;
    _ownerOfSlot[slot] = owner;
  }

  /// A handle with no live slot: either a node or a definition, which owns
  /// leaves but is not one and so changes no bucket, or an entity that has
  /// just been removed.
  void _forget(Handle handle) {
    final slot = _slotOfHandle.remove(handle);
    if (slot != null) _dropSlot(slot);
  }

  void _dropSlot(int slot) {
    final owner = _ownerOfSlot.remove(slot);
    if (owner == null) return;
    final bucket = _byOwner[owner];
    if (bucket == null) return;
    final at = _lowerBound(bucket, slot);
    if (at < bucket.length && bucket[at] == slot) bucket.removeAt(at);
  }

  static int _lowerBound(List<int> sorted, int value) {
    var low = 0;
    var high = sorted.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (sorted[mid] < value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
