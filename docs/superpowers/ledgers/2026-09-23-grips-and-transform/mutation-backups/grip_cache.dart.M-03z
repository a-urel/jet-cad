import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';

/// Past this many grips in the selection, no leaf grip is shown (spec D6).
/// Body move and rotate still work.
const int kMaxGrips = 400;

/// A press or hover within this many screen pixels of a grip's centre hits
/// it (spec D2).
const double kGripHitPixels = 7.0;

/// One grip of one selected root leaf. For a root leaf, owner space is
/// world, so [grip]'s coordinates are world.
final class GripRef {
  const GripRef(this.key, this.grip, this.ordinal);

  final SelectionKey key;
  final Grip grip;

  /// The grip's position in `leafGrips`' list — D2's tie-break "grip index"
  /// (Ruling 03-2).
  final int ordinal;
}

/// Where the rotation grip sits (spec D6): the centre of the screen-space
/// bounding box of [box]'s four projected corners, [kRotationGripOffset]
/// pixels up. Under a rotated camera, "up" means screen-up. [anchor] is the
/// top-centre the grip hangs from.
({Offset anchor, Offset centre}) rotationGripOf(
    Aabb2 box, Transform2 worldToScreen) {
  final m = worldToScreen;
  var minX = double.infinity, maxX = double.negativeInfinity;
  var minY = double.infinity;
  for (var i = 0; i < 4; i++) {
    final x = i.isEven ? box.minX : box.maxX;
    final y = i < 2 ? box.minY : box.maxY;
    final sx = m.a * x + m.c * y + m.e;
    final sy = m.b * x + m.d * y + m.f;
    minX = math.min(minX, sx);
    maxX = math.max(maxX, sx);
    minY = math.min(minY, sy);
  }
  final cx = (minX + maxX) / 2;
  return (
    anchor: Offset(cx, minY),
    centre: Offset(cx, minY - kRotationGripOffset),
  );
}

/// The selection's grips and box, in world doubles (spec D6).
///
/// Rebuilt at selection-change and document-change rate, never per frame.
/// It listens to the selection controller and to the [OutlineCache], never
/// to `document.changes` (Ruling 03-19). The box is derived from the
/// outline cache's world records, so it must rebuild after them. The shell
/// constructs this after the outline cache, so on a selection change the
/// cache's listener has already run.
class GripCache extends ChangeNotifier {
  GripCache(this.document, this.selection, this.outlines) {
    selection.addListener(_onSelection);
    outlines.addListener(_rebuild);
    _rebuild();
  }

  final DraftDocument document;
  final SelectionController selection;
  final OutlineCache outlines;

  final List<GripRef> _grips = <GripRef>[];

  /// Every shown grip, in ascending handle order, then by ordinal. The same
  /// view object on every call, so a painter reading it per frame
  /// allocates nothing.
  late final List<GripRef> grips = UnmodifiableListView<GripRef>(_grips);

  Set<SelectionKey> _built = const {};
  int _moveCount = 0;
  Aabb2? _box;

  /// How many of [grips] are move (centre) grips.
  int get moveCount => _moveCount;

  /// How many are stretch or radius grips.
  int get stretchCount => _grips.length - _moveCount;

  /// The union of `worldBoundsOf` over the selection; null when nothing
  /// selected has an outline.
  Aabb2? get box => _box;

  /// A rotation grip is drawn and hit (spec D6). A fill has no outline of
  /// its own, so a non-null box already means a non-fill key
  /// (Ruling 03-15).
  bool get rotatable => _box != null;

  /// Index into [grips] of the hovered or grabbed grip, or -1.
  ///
  /// Written by the select tool, which notifies for the repaint itself.
  /// Reset on every rebuild.
  int hot = -1;

  /// Leaf grips need `geometry` (spec D2). Read live, never cached: a
  /// permission change is not notified (Ruling 03-5).
  bool get leafGripsLive =>
      document.commands.permissions.allows(Capability.geometry);

  /// The grip under [screen] within [kGripHitPixels], or -1.
  ///
  /// The nearest wins, then the greater handle (coincident grips of two
  /// objects: the later-drawn one moves), then the lower ordinal. Nothing
  /// hits while leaf grips are not live.
  int hitTest(Offset screen, Transform2 worldToScreen) {
    if (!leafGripsLive) return -1;
    final m = worldToScreen;
    var best = -1;
    var bestDistance = double.infinity;
    var bestHandle = -1;
    var bestOrdinal = 0;
    for (var i = 0; i < _grips.length; i++) {
      final ref = _grips[i];
      final g = ref.grip;
      final dx = m.a * g.x + m.c * g.y + m.e - screen.dx;
      final dy = m.b * g.x + m.d * g.y + m.f - screen.dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > kGripHitPixels) continue;
      final h = ref.key.target.value;
      final better = best < 0 ||
          d < bestDistance ||
          (d == bestDistance &&
              (h > bestHandle ||
                  (h == bestHandle && ref.ordinal < bestOrdinal)));
      if (!better) continue;
      best = i;
      bestDistance = d;
      bestHandle = h;
      bestOrdinal = ref.ordinal;
    }
    return best;
  }

  /// Whether [screen] is within [kGripHitPixels] of the rotation grip.
  bool hitsRotationGrip(Offset screen, Transform2 worldToScreen) {
    final b = _box;
    if (b == null) return false;
    return (rotationGripOf(b, worldToScreen).centre - screen).distance <=
        kGripHitPixels;
  }

  /// A hover change notifies the selection controller with the same keys.
  /// Rebuilding for it would reset [hot] under the pointer, so it is skipped
  /// (Ruling 03-19).
  void _onSelection() {
    if (setEquals(_built, selection.keys.toSet())) return;
    _rebuild();
  }

  void _rebuild() {
    _grips.clear();
    _moveCount = 0;
    hot = -1;
    var box = Aabb2.empty();
    final keys = selection.keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    for (final key in keys) {
      final bounds = outlines.worldBoundsOf(key);
      if (bounds != null) box = box.union(bounds);
      final slot = document.entities.slotOf(key.target);
      if (slot == null) continue; // a group or an instance: no grips (D3)
      if (document.entities.ownerAt(slot) != document.rootHandle) continue;
      final list = leafGrips(document.entities.kindAt(slot),
          document.geometry.peek(document.entities.geomIndexAt(slot)));
      for (var i = 0; i < list.length; i++) {
        _grips.add(GripRef(key, list[i], i));
        if (list[i].role == GripRole.move) _moveCount++;
      }
    }
    if (_grips.length > kMaxGrips) {
      _grips.clear();
      _moveCount = 0;
    }
    _box = box.isEmpty ? null : box;
    _built = selection.keys.toSet();
    notifyListeners();
  }

  @override
  void dispose() {
    selection.removeListener(_onSelection);
    outlines.removeListener(_rebuild);
    super.dispose();
  }
}
