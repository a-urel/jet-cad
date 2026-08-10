import 'dart:typed_data';

import '../geometry/aabb2.dart';

/// A static R-tree, bulk-loaded by sort-tile-recursive packing into typed
/// arrays.
///
/// Static by design. Insertion into a packed tree is not supported at all:
/// recent edits live in a separate dirty list and the tree is rebuilt when
/// that list grows past a threshold. That trade matches the real usage
/// profile — long reads punctuated by short edit bursts — and avoids dynamic
/// R*-tree rebalancing entirely.
///
/// Layout: [_boxes] holds four doubles per node. Items occupy nodes
/// `[0, itemCount)` in packed order; each subsequent level follows, ending at
/// the single root. [_levelEnd] holds the exclusive end node index of each
/// level, so level `L` spans `[_levelEnd[L - 1], _levelEnd[L])` with level 0
/// starting at 0.
class PackedRTree {
  static const int kNodeCapacity = 16;

  /// Depth is bounded by log_16 of the item count, so a fixed depth of 16 is
  /// far beyond any reachable tree: 16^16 items is not representable.
  ///
  /// A node pushes up to [kNodeCapacity] children onto the traversal stack at
  /// once, so the stack must be sized by depth *times* breadth, not depth
  /// alone — see [_stackLevel] and [_stackIndex].
  static const int _kSearchStackDepth = 16;

  PackedRTree._(this._boxes, this._payloads, this._levelEnd, this.itemCount,
      this._payloadToItem)
      : _dead = Uint32List((itemCount + 31) >> 5),
        _stackLevel = Int32List(_kSearchStackDepth * kNodeCapacity),
        _stackIndex = Int32List(_kSearchStackDepth * kNodeCapacity);

  factory PackedRTree.empty() => PackedRTree._(
        Float64List(0),
        Uint32List(0),
        Int32List(0),
        0,
        <int, int>{},
      );

  /// Builds a tree over [itemCount] boxes.
  ///
  /// [itemBoxes] holds `minX, minY, maxX, maxY` per item; [itemPayloads] one
  /// integer per item. Both are copied, so the caller may reuse its buffers.
  ///
  /// Payloads must be unique. [markDead] and [isDead] resolve a payload to
  /// an item through a map that is last-write-wins, so a duplicate payload
  /// leaves its earlier occurrence permanently un-killable — [isDead]
  /// reports the later item's state for both. Checked with an assert, not a
  /// thrown error, since the cost of verifying it is proportional to
  /// [itemCount] and callers (unique entity slots and handles) already
  /// guarantee it.
  ///
  /// [itemPayloads] is stored in a [Uint32List]; a payload above
  /// `0xFFFFFFFF` truncates silently to its low 32 bits rather than being
  /// rejected.
  factory PackedRTree.build(
      int itemCount, Float64List itemBoxes, Uint32List itemPayloads) {
    if (itemCount == 0) return PackedRTree.empty();

    // Sort item indices by centre X, slice into vertical strips, then sort
    // each strip by centre Y. This is the STR packing; it gives strips of
    // roughly square aspect, which is what keeps query overlap low.
    final order = List<int>.generate(itemCount, (i) => i);
    double centreX(int i) => (itemBoxes[i * 4] + itemBoxes[i * 4 + 2]) / 2;
    double centreY(int i) => (itemBoxes[i * 4 + 1] + itemBoxes[i * 4 + 3]) / 2;

    order.sort((p, q) => centreX(p).compareTo(centreX(q)));

    final leafCount = (itemCount + kNodeCapacity - 1) ~/ kNodeCapacity;
    final stripCount = _isqrt(leafCount).clamp(1, leafCount);
    // Rounded up to a whole number of leaves. Leaves are fixed
    // kNodeCapacity-item chunks of `order`; if perStrip weren't a multiple
    // of kNodeCapacity, one leaf at every strip boundary would straddle two
    // strips, mixing the max-Y items of one strip with the min-Y items of
    // the next. That leaf's box balloons into a near-full-height sliver
    // that almost every query at that X has to open — the same items are
    // still found, but far more nodes are visited to find them.
    final rawPerStrip = (itemCount + stripCount - 1) ~/ stripCount;
    final perStrip =
        ((rawPerStrip + kNodeCapacity - 1) ~/ kNodeCapacity) * kNodeCapacity;

    for (var start = 0; start < itemCount; start += perStrip) {
      final end = (start + perStrip).clamp(0, itemCount);
      final strip = order.sublist(start, end)
        ..sort((p, q) => centreY(p).compareTo(centreY(q)));
      order.setRange(start, end, strip);
    }

    // Level sizes, bottom-up.
    final levelSizes = <int>[itemCount];
    var n = itemCount;
    while (n > 1) {
      n = (n + kNodeCapacity - 1) ~/ kNodeCapacity;
      levelSizes.add(n);
    }

    var totalNodes = 0;
    for (final size in levelSizes) {
      totalNodes += size;
    }

    final boxes = Float64List(totalNodes * 4);
    final payloads = Uint32List(itemCount);
    final levelEnd = Int32List(levelSizes.length);
    final payloadToItem = <int, int>{};

    // Level 0: the items themselves, in packed order.
    for (var i = 0; i < itemCount; i++) {
      final src = order[i];
      boxes[i * 4] = itemBoxes[src * 4];
      boxes[i * 4 + 1] = itemBoxes[src * 4 + 1];
      boxes[i * 4 + 2] = itemBoxes[src * 4 + 2];
      boxes[i * 4 + 3] = itemBoxes[src * 4 + 3];
      payloads[i] = itemPayloads[src];
      payloadToItem[itemPayloads[src]] = i;
    }
    assert(
        payloadToItem.length == itemCount,
        'PackedRTree.build requires unique payloads: got $itemCount items '
        'but only ${payloadToItem.length} distinct payload(s).');
    levelEnd[0] = itemCount;

    // Each higher level unions groups of kNodeCapacity children.
    var childStart = 0;
    var writeAt = itemCount;
    for (var level = 1; level < levelSizes.length; level++) {
      final childEnd = levelEnd[level - 1];
      var child = childStart;
      while (child < childEnd) {
        var minX = double.infinity, minY = double.infinity;
        var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
        final groupEnd = (child + kNodeCapacity).clamp(0, childEnd);
        for (var k = child; k < groupEnd; k++) {
          if (boxes[k * 4] < minX) minX = boxes[k * 4];
          if (boxes[k * 4 + 1] < minY) minY = boxes[k * 4 + 1];
          if (boxes[k * 4 + 2] > maxX) maxX = boxes[k * 4 + 2];
          if (boxes[k * 4 + 3] > maxY) maxY = boxes[k * 4 + 3];
        }
        boxes[writeAt * 4] = minX;
        boxes[writeAt * 4 + 1] = minY;
        boxes[writeAt * 4 + 2] = maxX;
        boxes[writeAt * 4 + 3] = maxY;
        writeAt++;
        child = groupEnd;
      }
      childStart = childEnd;
      levelEnd[level] = writeAt;
    }

    return PackedRTree._(boxes, payloads, levelEnd, itemCount, payloadToItem);
  }

  final Float64List _boxes;
  final Uint32List _payloads;
  final Int32List _levelEnd;
  final Map<int, int> _payloadToItem;

  /// One bit per item, in **32-bit** words.
  ///
  /// Not `Uint64List`: it does not exist on the web, and a 64-bit word would be
  /// wrong there even if it did — JavaScript's bitwise operators are 32-bit, so
  /// `1 << 40` is not the bit anyone meant. This is the only 64-bit typed list
  /// the engine had, and it took the whole render path down on web.
  final Uint32List _dead;

  /// Preallocated so [search] allocates nothing. Two parallel stacks — level
  /// and node index — rather than one packed value, since a node can push up
  /// to [kNodeCapacity] children in a single step: sizing must account for
  /// breadth as well as depth, or a wide push at shallow depth overflows a
  /// stack that was only sized for the deepest possible chain of single
  /// pushes.
  final Int32List _stackLevel;
  final Int32List _stackIndex;

  final int itemCount;

  /// The union of every item box, dead ones included.
  Aabb2 get bounds {
    if (itemCount == 0) return Aabb2.empty();
    final rootIndex = _levelEnd[_levelEnd.length - 1] - 1;
    return Aabb2.raw(
      _boxes[rootIndex * 4],
      _boxes[rootIndex * 4 + 1],
      _boxes[rootIndex * 4 + 2],
      _boxes[rootIndex * 4 + 3],
    );
  }

  /// Visits the payload of every live item whose box overlaps the query.
  ///
  /// Overlap is inclusive: a box touching the query edge is reported. The
  /// narrow phase is the caller's job — this is a broad phase and returns
  /// false positives by design.
  ///
  /// Not reentrant: the traversal stack is owned by this tree, so calling
  /// [search] from inside [visit] corrupts the walk.
  void search(double minX, double minY, double maxX, double maxY,
      void Function(int payload) visit) {
    if (itemCount == 0) return;

    var depth = 0;
    // Root is the single node of the top level.
    _stackLevel[depth] = _levelEnd.length - 1;
    _stackIndex[depth] = _levelEnd[_levelEnd.length - 1] - 1;
    depth++;

    while (depth > 0) {
      depth--;
      final level = _stackLevel[depth];
      final node = _stackIndex[depth];

      if (!_overlaps(node, minX, minY, maxX, maxY)) continue;

      if (level == 0) {
        if (!_isDeadItem(node)) visit(_payloads[node]);
        continue;
      }

      final childLevel = level - 1;
      final childBase = childLevel == 0 ? 0 : _levelEnd[childLevel - 1];
      final childEnd = _levelEnd[childLevel];
      // This node is the k-th of its level; its children are the k-th group.
      final selfBase = _levelEnd[level - 1];
      final k = node - selfBase;
      final first = childBase + k * kNodeCapacity;
      final last = (first + kNodeCapacity).clamp(0, childEnd);

      for (var child = first; child < last; child++) {
        _stackLevel[depth] = childLevel;
        _stackIndex[depth] = child;
        depth++;
      }
    }
  }

  void markDead(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return;
    _dead[item >> 5] |= 1 << (item & 31);
  }

  bool isDead(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return false;
    return _isDeadItem(item);
  }

  /// The stored box of [payload], or null when this tree has no such item —
  /// or holds one that is dead.
  ///
  /// A dead item is one the document no longer agrees with, so reporting its
  /// stale box to a caller asking "what is indexed for this payload?" would be
  /// answering a different question.
  Aabb2? boxOfPayload(int payload) {
    final item = _payloadToItem[payload];
    if (item == null || _isDeadItem(item)) return null;
    return Aabb2.raw(_boxes[item * 4], _boxes[item * 4 + 1],
        _boxes[item * 4 + 2], _boxes[item * 4 + 3]);
  }

  /// Enlarges [payload]'s stored box to also contain the given rectangle,
  /// carrying the growth up to every ancestor node. Returns whether anything
  /// actually changed.
  ///
  /// **The one mutation a packed tree can accept.** Insertion is not
  /// supported and never will be (see this class's own doc comment), but
  /// growing an existing box needs no rebalancing and cannot break the
  /// search: every node's box is an upper bound on its subtree's, so
  /// enlarging one only ever makes [search] open more nodes. The result stays
  /// a correct broad phase — it can report more false positives, never fewer
  /// true ones. Shrinking would be the unsafe direction and is deliberately
  /// not offered.
  ///
  /// O(depth), not O(items): the packed layout puts the parent of the k-th
  /// node of a level at index `k ~/ kNodeCapacity` of the next one, so the
  /// walk up is arithmetic, and it stops the moment a node already contains
  /// the rectangle — at which point every node above it does too.
  ///
  /// Callers: `ContainerIndex.growInstanceBox`, for the instance box of a
  /// definition whose contents have grown since the box was derived.
  bool growBox(
      int payload, double minX, double minY, double maxX, double maxY) {
    final item = _payloadToItem[payload];
    if (item == null) return false;

    var changed = false;
    if (minX < _boxes[item * 4]) {
      _boxes[item * 4] = minX;
      changed = true;
    }
    if (minY < _boxes[item * 4 + 1]) {
      _boxes[item * 4 + 1] = minY;
      changed = true;
    }
    if (maxX > _boxes[item * 4 + 2]) {
      _boxes[item * 4 + 2] = maxX;
      changed = true;
    }
    if (maxY > _boxes[item * 4 + 3]) {
      _boxes[item * 4 + 3] = maxY;
      changed = true;
    }
    // Unchanged item box means every ancestor already contains the rectangle,
    // since each is an upper bound on this one.
    if (!changed) return false;
    _growAncestors(item, minX, minY, maxX, maxY);
    return true;
  }

  /// Replaces [payload]'s stored box outright — **shrinking it if the new box
  /// is smaller** — and grows its ancestors to cover it.
  ///
  /// [growBox]'s doc comment says shrinking is the unsafe direction, and for
  /// an *interior* node it is: a node's box has to remain an upper bound on
  /// its whole subtree, and tightening one would need a scan of every sibling
  /// under it. An **item** has no subtree, so narrowing an item box cannot
  /// break that invariant — every ancestor is left exactly as wide as it was,
  /// still an upper bound, merely no longer a tight one. [search] stays
  /// correct: it opens ancestors it need not have opened and then rejects the
  /// item, which costs a few node tests and reports nothing false.
  ///
  /// This is what gives an instance box a way *back*. Growth alone is
  /// monotone, so a definition dragged outwards and back again would leave
  /// every box that places it permanently enlarged and every query descending
  /// into instances that no longer reach it. See
  /// `SpatialIndex._retightenPlacementsOf`.
  /// Returns whether any side moved *inwards*, which is the caller's cue that
  /// a bound derived from this box may no longer be tight. Reported from
  /// here rather than by having the caller read the old box first, because
  /// [boxOfPayload] builds an [Aabb2] and this runs once per placement of a
  /// definition — at three thousand placements that is three thousand
  /// allocations on an edit path a drag walks every frame.
  bool setBox(int payload, double minX, double minY, double maxX, double maxY) {
    final item = _payloadToItem[payload];
    if (item == null) return false;
    final narrowed = minX > _boxes[item * 4] ||
        minY > _boxes[item * 4 + 1] ||
        maxX < _boxes[item * 4 + 2] ||
        maxY < _boxes[item * 4 + 3];
    _boxes[item * 4] = minX;
    _boxes[item * 4 + 1] = minY;
    _boxes[item * 4 + 2] = maxX;
    _boxes[item * 4 + 3] = maxY;
    _growAncestors(item, minX, minY, maxX, maxY);
    return narrowed;
  }

  /// The union of every **live** item box, dead ones excluded.
  ///
  /// The difference from [bounds] is the whole point: [bounds] reads the root
  /// node, which was computed at build time and still covers items that have
  /// since been marked dead or widened in place. This scans level 0, so it is
  /// O(items) rather than O(1) — the price of an answer that reflects what
  /// the tree currently holds rather than what it once held.
  ///
  /// Used by `ContainerIndex.recomputeBounds`, which is how a container's
  /// bound gets *smaller* again after the geometry that pushed it out has
  /// moved back.
  Aabb2 liveItemBounds() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    var any = false;
    for (var item = 0; item < itemCount; item++) {
      if (_isDeadItem(item)) continue;
      any = true;
      if (_boxes[item * 4] < minX) minX = _boxes[item * 4];
      if (_boxes[item * 4 + 1] < minY) minY = _boxes[item * 4 + 1];
      if (_boxes[item * 4 + 2] > maxX) maxX = _boxes[item * 4 + 2];
      if (_boxes[item * 4 + 3] > maxY) maxY = _boxes[item * 4 + 3];
    }
    return any ? Aabb2.raw(minX, minY, maxX, maxY) : Aabb2.empty();
  }

  /// Widens every node above [item] until one already contains the rectangle.
  void _growAncestors(
      int item, double minX, double minY, double maxX, double maxY) {
    if (_levelEnd.length <= 1) return; // the item is the root
    var level = 0;
    var node = item;
    while (level < _levelEnd.length - 1) {
      final selfBase = level == 0 ? 0 : _levelEnd[level - 1];
      node = _levelEnd[level] + (node - selfBase) ~/ kNodeCapacity;
      level++;

      var changed = false;
      if (minX < _boxes[node * 4]) {
        _boxes[node * 4] = minX;
        changed = true;
      }
      if (minY < _boxes[node * 4 + 1]) {
        _boxes[node * 4 + 1] = minY;
        changed = true;
      }
      if (maxX > _boxes[node * 4 + 2]) {
        _boxes[node * 4 + 2] = maxX;
        changed = true;
      }
      if (maxY > _boxes[node * 4 + 3]) {
        _boxes[node * 4 + 3] = maxY;
        changed = true;
      }
      if (!changed) return;
    }
  }

  void markAlive(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return;
    _dead[item >> 5] &= ~(1 << (item & 31));
  }

  /// Whether this tree holds an entry for [payload] at all, alive or dead.
  bool holdsPayload(int payload) => _payloadToItem.containsKey(payload);

  /// The stored box even for a dead item, for the one caller that needs to
  /// ask whether a revived entity is going back exactly where it was.
  Aabb2? boxIgnoringDead(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return null;
    return Aabb2.raw(_boxes[item * 4], _boxes[item * 4 + 1],
        _boxes[item * 4 + 2], _boxes[item * 4 + 3]);
  }

  void clearDead() {
    for (var i = 0; i < _dead.length; i++) {
      _dead[i] = 0;
    }
  }

  bool _isDeadItem(int item) => (_dead[item >> 5] >> (item & 31)) & 1 == 1;

  bool _overlaps(
          int node, double minX, double minY, double maxX, double maxY) =>
      _boxes[node * 4] <= maxX &&
      _boxes[node * 4 + 1] <= maxY &&
      _boxes[node * 4 + 2] >= minX &&
      _boxes[node * 4 + 3] >= minY;

  static int _isqrt(int value) {
    var r = 0;
    while ((r + 1) * (r + 1) <= value) {
      r++;
    }
    return r;
  }
}
