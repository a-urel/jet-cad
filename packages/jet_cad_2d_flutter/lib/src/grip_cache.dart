import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'outline_cache.dart';
import 'selection.dart';
import 'selection_style.dart';

/// Past this many grips in the selection, no leaf grip is shown (spec D6).
/// Body move and rotate still work.
const int kMaxGrips = 400;

/// A press or hover within this many screen pixels of a grip's centre hits
/// it (spec D2).
const double kGripHitPixels = 7.0;

/// Grips for a selected **root-level group** that an application object
/// type owns — a parametric object, whose own leaves are generated and
/// carry none (spec 07 D11). `GripCache` consults it; `GripDrag` builds a
/// reshape's command through it.
///
/// Every coordinate is world. A `stretch` or `radius` grip it returns is
/// reshaped through [drag] and needs `components` and `geometry`; a `move`
/// grip moves the whole selection, as a leaf's centre grip does.
abstract interface class ObjectGripProvider {
  /// [group]'s grips, in world; empty when [group] is not one of this
  /// provider's objects. The list order is each grip's ordinal.
  List<Grip> gripsOf(DraftDocument d, Handle group);

  /// The one command that moves [grip] of [group] to [world], or null when
  /// that drag is refused (a degenerate result, say). [world] is only read
  /// during the call.
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world);

  /// What [drag] would draw, in world: the pieces a reshape preview paints,
  /// computed once per pointer move, never per frame. Empty when there is
  /// nothing to show. [world] is only read during the call.
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world);
}

/// One grip of one selected root leaf, or — with [object] — one grip an
/// [ObjectGripProvider] gives a selected root-level group. For a root leaf,
/// owner space is world, so [grip]'s coordinates are world; a provider's
/// grips are world too.
final class GripRef {
  const GripRef(this.key, this.grip, this.ordinal, {this.object = false});

  final SelectionKey key;
  final Grip grip;

  /// The grip's position in `leafGrips`' list (or the provider's) — D2's
  /// tie-break "grip index" (Ruling 03-2).
  final int ordinal;

  /// The grip came from [GripCache.objects], and [key] names a group.
  final bool object;
}

/// Where the rotation grip sits (spec D6). [box] is in [frame]'s
/// coordinates; [frame] maps them to world and defaults to the identity.
///
/// - While [frame]'s linear part is exactly the identity (no rotation
///   carried, Amended after the look), D6 stands: the centre of the
///   screen-space bounding box of [box]'s four projected corners,
///   [kRotationGripOffset] pixels up. Under a rotated camera, "up" means
///   screen-up.
/// - Otherwise the grip rides the frame: it hangs from the middle of the
///   frame's top edge, [kRotationGripOffset] pixels along the frame's up
///   direction on screen. "Top" is the local `maxY` edge under a
///   reflecting (y-flipped) camera and `minY` otherwise, so an unrotated
///   frame under an unrotated camera lands where D6 puts it.
///
/// [after], when given, is applied after [frame] — a move's or rotate's
/// preview `T` — and is composed inline, so a drag's frames allocate no
/// `Transform2` (spec D7).
///
/// [anchor] is the point the grip hangs from, [centre] the disc's centre
/// and [stem] the end of the 1 px line from [anchor], on the disc's rim.
({Offset anchor, Offset centre, Offset stem}) rotationGripOf(
    Aabb2 box, Transform2 worldToScreen,
    [Transform2? frame, Transform2? after]) {
  final m = worldToScreen;
  final f0 = frame ?? const Transform2(1, 0, 0, 1, 0, 0);
  // after ∘ frame, then worldToScreen ∘ that, inline: this runs per frame.
  var fa = f0.a, fb = f0.b, fc = f0.c, fd = f0.d, fe = f0.e, ff = f0.f;
  if (after != null) {
    final t = after;
    fa = t.a * f0.a + t.c * f0.b;
    fb = t.b * f0.a + t.d * f0.b;
    fc = t.a * f0.c + t.c * f0.d;
    fd = t.b * f0.c + t.d * f0.d;
    fe = t.a * f0.e + t.c * f0.f + t.e;
    ff = t.b * f0.e + t.d * f0.f + t.f;
  }
  final ma = m.a * fa + m.c * fb;
  final mb = m.b * fa + m.d * fb;
  final mc = m.a * fc + m.c * fd;
  final md = m.b * fc + m.d * fd;
  final me = m.a * fe + m.c * ff + m.e;
  final mf = m.b * fe + m.d * ff + m.f;
  const r = kRotationGripPixels / 2;
  if (fa == 1 && fb == 0 && fc == 0 && fd == 1) {
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity;
    for (var i = 0; i < 4; i++) {
      final x = i.isEven ? box.minX : box.maxX;
      final y = i < 2 ? box.minY : box.maxY;
      final sx = ma * x + mc * y + me;
      final sy = mb * x + md * y + mf;
      minX = math.min(minX, sx);
      maxX = math.max(maxX, sx);
      minY = math.min(minY, sy);
    }
    final cx = (minX + maxX) / 2;
    final cy = minY - kRotationGripOffset;
    return (
      anchor: Offset(cx, minY),
      centre: Offset(cx, cy),
      stem: Offset(cx, cy + r),
    );
  }
  final up = m.a * m.d - m.b * m.c < 0 ? 1.0 : -1.0;
  final lx = (box.minX + box.maxX) / 2;
  final ly = up > 0 ? box.maxY : box.minY;
  final ax = ma * lx + mc * ly + me;
  final ay = mb * lx + md * ly + mf;
  var dx = mc * up, dy = md * up;
  final len = math.sqrt(dx * dx + dy * dy);
  dx /= len;
  dy /= len;
  final cx = ax + dx * kRotationGripOffset;
  final cy = ay + dy * kRotationGripOffset;
  return (
    anchor: Offset(ax, ay),
    centre: Offset(cx, cy),
    stem: Offset(cx - dx * r, cy - dy * r),
  );
}

/// The selection's grips and box, in world doubles (spec D6).
///
/// Amended after the look: the box is **oriented**. It is [box] in
/// [frame]'s coordinates. A move or rotate the select tool commits hands
/// its `T` to [carry] first, and the rebuild that change causes moves the
/// frame with it (`T · frame`) instead of re-wrapping the geometry in a
/// world AABB: a rigid `T` keeps a tight box tight. So the rotation grip
/// stays where the user left it and the next rotate turns about the same
/// [pivot]. Any other rebuild — a selection change, undo, redo, a reshape,
/// any other edit — resets the frame to the world AABB.
///
/// Rebuilt at selection-change and document-change rate, never per frame.
/// It listens to the selection controller and to the [OutlineCache], never
/// to `document.changes` (Ruling 03-19). The box is derived from the
/// outline cache's world records, so it must rebuild after them. The shell
/// constructs this after the outline cache, so on a selection change the
/// cache's listener has already run.
///
/// With [objects], a selected root-level group also shows the grips that
/// provider gives it (spec 07 D11). Without one, a group has no grips, as
/// before.
class GripCache extends ChangeNotifier {
  GripCache(this.document, this.selection, this.outlines, {this.objects}) {
    selection.addListener(_onSelection);
    outlines.addListener(_rebuild);
    _rebuild();
  }

  final DraftDocument document;
  final SelectionController selection;
  final OutlineCache outlines;

  /// The object grip seam (spec 07 D11); null: groups have no grips.
  final ObjectGripProvider? objects;

  final List<GripRef> _grips = <GripRef>[];

  /// Every shown grip, in ascending handle order, then by ordinal. The same
  /// view object on every call, so a painter reading it per frame
  /// allocates nothing.
  late final List<GripRef> grips = UnmodifiableListView<GripRef>(_grips);

  Set<SelectionKey> _built = const {};
  int _moveCount = 0;
  Aabb2? _box;
  Transform2 _frame = const Transform2(1, 0, 0, 1, 0, 0);
  Vector2? _pivot;
  Transform2? _carry;

  /// How many of [grips] are move (centre) grips.
  int get moveCount => _moveCount;

  /// How many are stretch or radius grips.
  int get stretchCount => _grips.length - _moveCount;

  /// The selection box in [frame]'s coordinates; null when nothing
  /// selected has an outline. With an identity [frame] it is the union of
  /// `worldBoundsOf` over the selection.
  Aabb2? get box => _box;

  /// Maps [box]'s coordinates to world: rigid, and the identity unless a
  /// committed rotation is being carried.
  Transform2 get frame => _frame;

  /// The world centre of the box, a rotate's pivot (spec D1); null with
  /// [box].
  Vector2? get pivot => _pivot;

  /// The select tool calls this with a move's or rotate's `T` just before
  /// it executes the command. The next rebuild — the one that command's
  /// `DocChange` causes — consumes it. A frame whose linear part comes out
  /// as exactly the identity is folded back into the world AABB.
  void carry(Transform2 t) => _carry = t;

  /// Withdraws a [carry] whose command never landed: `execute` threw, so no
  /// `DocChange` will consume it, and the next unrelated one must not.
  void dropCarry() => _carry = null;

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
    return (rotationGripOf(b, worldToScreen, _frame).centre - screen)
            .distance <=
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
      if (slot == null) {
        // A group or an instance: no leaf grips (D3). A root-level group's
        // grips are its provider's, when there is one (07 D11).
        final provider = objects;
        final node = document.tree[key.target];
        if (provider == null ||
            node is! GroupNode ||
            node.parent != document.rootHandle) {
          continue;
        }
        final list = provider.gripsOf(document, key.target);
        for (var i = 0; i < list.length; i++) {
          _grips.add(GripRef(key, list[i], i, object: true));
          if (list[i].role == GripRole.move) _moveCount++;
        }
        continue;
      }
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
    final t = _carry;
    _carry = null;
    final built = selection.keys.toSet();
    final carried =
        t == null || !setEquals(_built, built) ? null : t.multiply(_frame);
    if (carried != null &&
        !(carried.a == 1 &&
            carried.b == 0 &&
            carried.c == 0 &&
            carried.d == 1)) {
      _frame = carried; // the box stays: it is in the frame's coordinates
    } else {
      _frame = const Transform2(1, 0, 0, 1, 0, 0);
      _box = box.isEmpty ? null : box;
    }
    final b = _box;
    _pivot = b == null
        ? null
        : _frame.transformPoint(
            Vector2((b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2));
    _built = built;
    notifyListeners();
  }

  @override
  void dispose() {
    selection.removeListener(_onSelection);
    outlines.removeListener(_rebuild);
    super.dispose();
  }
}
