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
///
/// **Two things are recorded per slot, not one:** the entity's box, and — for
/// an arc or a circle — the *snap centre* it offers as a `SnapKind.center`
/// candidate. The centre is not derivable from the box (an arc's box bounds
/// its drawn sweep and need not contain its own centre at all), and
/// `ContainerIndex` indexes centres in a tree of their own, so the overlay
/// that stands in front of that tree has to carry the same second fact. Both
/// live in this one structure rather than in a parallel second list
/// deliberately: one [put], one [remove], one swap-with-last, so a slot can
/// never end up dirty for its box and stale for its centre.
class DirtyList {
  /// The centre value meaning "this entry offers no `SnapKind.center`
  /// candidate" — every kind but arc and circle.
  ///
  /// NaN rather than a parallel `bool` array or a sentinel coordinate: every
  /// comparison against NaN is false, so [searchCentres]' ordinary
  /// containment test rejects such an entry by arithmetic, exactly the way
  /// [put] normalises an empty box so [search] rejects it by arithmetic.
  static const double noCentre = double.nan;

  final Map<int, int> _positionOf = <int, int>{};
  Int32List _slots = Int32List(16);
  Float64List _boxes = Float64List(16 * 4);
  Float64List _centres = Float64List(16 * 2);
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool contains(int slot) => _positionOf.containsKey(slot);

  /// Records [box] and the snap centre ([centreX], [centreY]) for [slot],
  /// replacing anything already recorded for it.
  ///
  /// Pass [noCentre] for both coordinates when the entity offers no
  /// `SnapKind.center` candidate. The two are required rather than
  /// defaulted: a caller that forgets them would leave a dirty arc's centre
  /// unsnappable with nothing to say so.
  void put(int slot, Aabb2 box, double centreX, double centreY) {
    // Normalise anything the geometry layer calls empty to the canonical
    // inverted-infinity form, so `search`'s ordinary overlap test rejects it
    // by arithmetic rather than by convention. `Aabb2.isEmpty` is
    // `minX > maxX || minY > maxY`, which a single-axis inversion with
    // *finite* bounds also satisfies — that shape's inverted axis wouldn't
    // fail either overlap clause on its own, so without this normalisation
    // it would match every query whose range covers it.
    final stored = box.isEmpty ? Aabb2.empty() : box;

    final existing = _positionOf[slot];
    final at = existing ?? _length;
    if (existing == null) {
      if (_length == _slots.length) _grow();
      _slots[at] = slot;
      _positionOf[slot] = at;
      _length++;
    }
    _boxes[at * 4] = stored.minX;
    _boxes[at * 4 + 1] = stored.minY;
    _boxes[at * 4 + 2] = stored.maxX;
    _boxes[at * 4 + 3] = stored.maxY;
    _centres[at * 2] = centreX;
    _centres[at * 2 + 1] = centreY;
  }

  /// The box recorded for [slot], or null when this list holds no entry for
  /// it. Empty for an entry [put] normalised to nothing.
  Aabb2? boxOf(int slot) {
    final at = _positionOf[slot];
    if (at == null) return null;
    return Aabb2.raw(_boxes[at * 4], _boxes[at * 4 + 1], _boxes[at * 4 + 2],
        _boxes[at * 4 + 3]);
  }

  /// The union of every recorded box, skipping the empty ones [put]
  /// normalises.
  ///
  /// The overlay half of `ContainerIndex.recomputeBounds`: a leaf that has
  /// moved is dead in the packed tree and live only here, so a bound derived
  /// from the tree alone would miss exactly the entities that just changed.
  Aabb2 entryBounds() {
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    var any = false;
    for (var at = 0; at < _length; at++) {
      // `put` stores `Aabb2.empty()` as inverted infinities, so this rejects
      // an entry that bounds nothing by the same arithmetic `search` uses,
      // rather than by a separate convention.
      if (_boxes[at * 4] > _boxes[at * 4 + 2]) continue;
      any = true;
      if (_boxes[at * 4] < minX) minX = _boxes[at * 4];
      if (_boxes[at * 4 + 1] < minY) minY = _boxes[at * 4 + 1];
      if (_boxes[at * 4 + 2] > maxX) maxX = _boxes[at * 4 + 2];
      if (_boxes[at * 4 + 3] > maxY) maxY = _boxes[at * 4 + 3];
    }
    return any ? Aabb2.raw(minX, minY, maxX, maxY) : Aabb2.empty();
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
      _centres[at * 2] = _centres[last * 2];
      _centres[at * 2 + 1] = _centres[last * 2 + 1];
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

  /// Visits the slot of every entry whose recorded snap centre falls inside
  /// the query, in the same allocation-free index loop [search] uses.
  ///
  /// An entry recorded with [noCentre] is never visited: NaN fails every one
  /// of the four comparisons below, so no flag has to be consulted.
  void searchCentres(double minX, double minY, double maxX, double maxY,
      void Function(int slot) visit) {
    for (var i = 0; i < _length; i++) {
      final cx = _centres[i * 2];
      final cy = _centres[i * 2 + 1];
      if (cx >= minX && cx <= maxX && cy >= minY && cy <= maxY) {
        visit(_slots[i]);
      }
    }
  }

  /// [search] and [searchCentres] over the same query, in **one** pass.
  ///
  /// Not a convenience wrapper: this list is scanned linearly, so a snap that
  /// wants both answers pays for the whole list twice if it asks twice. At
  /// the rebuild threshold — 5% of a large document, ~25,000 entries at
  /// 500,000 entities — that second pass was measured as most of the gap
  /// between a snap on a fresh index and one at the threshold. Each entry's
  /// box and centre are tested while they are in hand.
  void searchBoxesAndCentres(
    double minX,
    double minY,
    double maxX,
    double maxY,
    void Function(int slot) visitBox,
    void Function(int slot) visitCentre,
  ) {
    for (var i = 0; i < _length; i++) {
      if (_boxes[i * 4] <= maxX &&
          _boxes[i * 4 + 1] <= maxY &&
          _boxes[i * 4 + 2] >= minX &&
          _boxes[i * 4 + 3] >= minY) {
        visitBox(_slots[i]);
      }
      final cx = _centres[i * 2];
      final cy = _centres[i * 2 + 1];
      if (cx >= minX && cx <= maxX && cy >= minY && cy <= maxY) {
        visitCentre(_slots[i]);
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
    final centres = Float64List(_centres.length * 2);
    centres.setRange(0, _length * 2, _centres);
    _centres = centres;
  }
}
