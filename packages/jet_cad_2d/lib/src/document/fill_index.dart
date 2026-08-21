import 'dart:typed_data';

import '../core/handle.dart';

/// Derived state for fills: one triangulation per boundary, and the reverse
/// map from a boundary to the fills that name it.
///
/// **Keyed by `Handle`, never by `geomIndex`.** `DraftDocument.purge()`
/// renumbers every `geomIndex` from a remap table, so a slot-keyed cache does
/// not go stale across a purge -- it goes *permuted*, every surviving entry
/// attached to the wrong entity at once. Handles are never reissued
/// (`HandleSeed.next` only increments) and `RemoveEntityCommand`'s inverse
/// restores the same handle, so a stale entry here can only ever be an entry
/// nobody reads. The failure mode is a leak, not a lie.
///
/// **Never populated on the frame path.** Commands and the codec fill it; the
/// painter only reads. [trianglesFor] returns the stored list itself rather
/// than a copy, because the alternative allocates once per fill per frame.
///
/// Both halves live in one object because the same three commands write both
/// and the same moments invalidate both.
class FillIndex {
  final Map<Handle, Int32List> _triangles = {};
  final Map<Handle, Handle> _boundaryOfFill = {};

  Int32List? trianglesFor(Handle boundary) => _triangles[boundary];

  void putTriangles(Handle boundary, Int32List triangles) {
    _triangles[boundary] = triangles;
  }

  void link(Handle fill, Handle boundary) {
    _boundaryOfFill[fill] = boundary;
  }

  void unlink(Handle fill) {
    _boundaryOfFill.remove(fill);
  }

  /// Every fill naming [boundary], in ascending handle order.
  ///
  /// Ordered because callers put these into a command's `touched` set and into
  /// removal cascades, and this project's determinism rests on stable orders.
  List<Handle> fillsOf(Handle boundary) {
    final out = <Handle>[
      for (final e in _boundaryOfFill.entries)
        if (e.value == boundary) e.key,
    ];
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  /// Triangles only; links stay. Callers that only invalidate a boundary's
  /// geometry (not its removal) must not sever fills from it.
  void dropTriangles(Handle boundary) {
    _triangles.remove(boundary);
  }

  void dropBoundary(Handle boundary) {
    _triangles.remove(boundary);
    _boundaryOfFill.removeWhere((_, b) => b == boundary);
  }

  void clear() {
    _triangles.clear();
    _boundaryOfFill.clear();
  }

  int get entryCount => _triangles.length;
  int get linkCount => _boundaryOfFill.length;
}
