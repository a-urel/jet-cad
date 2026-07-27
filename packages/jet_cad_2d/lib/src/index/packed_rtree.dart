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
      : _dead = Uint64List((itemCount + 63) >> 6),
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
  final Uint64List _dead;

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
    _dead[item >> 6] |= 1 << (item & 63);
  }

  bool isDead(int payload) {
    final item = _payloadToItem[payload];
    if (item == null) return false;
    return _isDeadItem(item);
  }

  void clearDead() {
    for (var i = 0; i < _dead.length; i++) {
      _dead[i] = 0;
    }
  }

  bool _isDeadItem(int item) => (_dead[item >> 6] >> (item & 63)) & 1 == 1;

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
