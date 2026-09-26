import 'dart:async' show StreamSubscription, unawaited;
import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room.dart';
import 'room_inputs.dart';
import 'room_trace.dart';

/// What the Room tool makes of a point (spec 10 D19).
enum _Verdict {
  /// A seed in a wall, or in an unbounded face: no room.
  none,

  /// A face with no live room's seed in it: a room.
  room,

  /// A face that already holds a live room's seed (decision 26): no room.
  occupied,
}

/// A name the Room tool gives (spec 10 D19): `Room N`, `N` a positive
/// integer written without a leading zero.
final RegExp _roomN = RegExp(r'^Room ([1-9][0-9]*)$');

/// Spec 10 D19: the Room tool (M). A `PlacementTool` whose **one click
/// commits** one room; it stays active, and Escape (with nothing pending,
/// ever) returns to the select tool.
///
/// - **The seed is the raw pointer**, unsnapped (R-18; 08's Ruling 08-14):
///   a snap would pull it onto a wall's vertex or face, where the room
///   dissolves at once. The snap marker is drawn there too ([markerPoint]).
/// - **The verdict for a point**, hover and click alike, the same code
///   ([_verdictAt]), over the shell's [RoomInputs] (Ruling 10-11):
///   - outside `inputs.bounds`, the **bounding box** of every place box
///     (T-1: not their union, which leaves out every room's interior when
///     its walls are axis-aligned), `Unbounded` without a trace (S-5);
///   - inside the band of the last `SeedInWall` verdict's wall: reused;
///   - inside the cached face (its outer ring, in none of its holes; an
///     allocation-free point-in-ring test): reused;
///   - otherwise `traceRoomAmong(p, inputs)`, the trace `generate` makes
///     (`RI1`, `LZ1`), and cached. An `Unbounded` point inside the box (a
///     courtyard open to the outside) is re-traced per move (T-8).
///
///   Every cache is dropped when the inputs' [RoomInputs.generation]
///   moves: on each document change, and on each [RoomInputs.invalidate].
/// - **Occupied** (decision 26, R-19): the face holds a live room's world
///   seed. No room, no preview, and the click does nothing; [notice] names
///   the lowest-handle such room.
/// - **The commit**: one [CompoundCommand], the room's group at the
///   identity and its [RoomParams] (the raw seed, the next free `Room N`,
///   the label auto), needing structure, components and geometry: one undo
///   step, in which the room regenerates. Its handle is allocated inside
///   the build, never predicted. A refused commit places nothing.
/// - **The preview**: the would-be face's outer ring and holes, in world,
///   as open polylines (each ring's first point repeated), built once per
///   new face and painted from the cached payloads, so the frame path gains
///   no allocation.
///
/// The inputs are invalidated at every click, before its verdict (as 08's
/// opening tools rebuild their band scan, Ruling 08-13): the document's
/// change stream delivers after the current task, and a click must never
/// trace among inputs the document no longer has. They are invalidated
/// again right after the commit, so the next query in the same handler
/// sees the new room.
///
/// While it shows a preview or a notice, a document change (an undo, an
/// edit elsewhere) re-reads the verdict at the pointer's last point, so
/// neither outlives the face it describes until the next pointer move.
class RoomTool extends PlacementTool {
  RoomTool(this.inputs) {
    _changes = inputs.document.changes.listen((_) => _onDocumentChange());
  }

  /// The shell's document adapter, shared with the Separator tool and the
  /// separator grips (Ruling 10-11). The tool never disposes it.
  final RoomInputs inputs;

  /// The raw world point of the last press (R-18): `accept` is handed the
  /// resolved point only.
  final Vector2 _raw = Vector2.zero();

  /// The raw world point of the last pointer event: where the snap marker
  /// sits, since that is where the seed goes.
  final Vector2 _pointer = Vector2.zero();

  final ValueNotifier<String?> _notice = ValueNotifier<String?>(null);
  bool _disposed = false;
  StreamSubscription<DocChange>? _changes;

  // The caches, valid while [_generation] is the inputs' generation.
  int _generation = -1;
  Traced? _face;
  _Verdict _faceVerdict = _Verdict.none;
  String? _occupant;
  List<GeometryPayload> _facePreview = const [];
  List<Vector2>? _band;

  /// What is painted: the cached face's preview while the pointer is in an
  /// unoccupied face, empty otherwise.
  List<GeometryPayload> _preview = const [];

  /// How many hover previews were built (Ruling 10-18): once per new face.
  @visibleForTesting
  int debugPreviewBuilds = 0;

  /// How many times the tool traced (`traceRoomAmong`): a trace that ends
  /// in `SeedInWall` takes in no segment, so `debugTracedSegments` alone
  /// cannot see a band's verdict reused.
  @visibleForTesting
  int debugTraces = 0;

  /// The preview, in world: the outer ring, then each hole, each an open
  /// polyline whose last point repeats its first.
  @visibleForTesting
  List<GeometryPayload> get debugPreview => _preview;

  /// `Already a room: <name>` while the hovered face already holds a room,
  /// and after a click there (decision 26, R-29); null otherwise, and
  /// cleared when the tool deactivates. The shell's status line appends it.
  ValueListenable<String?> get notice => _notice;

  @override
  String get name => 'Room';

  @override
  Vector2 get markerPoint => _pointer;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (e.buttons & kPrimaryButton != 0) {
      _raw.setFrom(e.world);
      _pointer.setFrom(e.world);
    }
    super.onPointerDown(e, ctx);
  }

  /// Runs after every hover's resolution; the room reads [raw] only.
  @override
  void hovered(Vector2 raw) {
    _pointer.setFrom(raw);
    _show(_verdictAt(raw));
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    inputs.invalidate();
    final verdict = _verdictAt(_raw);
    _show(verdict);
    if (verdict != _Verdict.room) return;
    final seed = _raw.clone();
    try {
      commit(ctx, () {
        final doc = ctx.document;
        final name = _nextName(doc);
        final h = doc.handleSeed.next();
        return CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<RoomParams>(h, RoomParams(seed.x, seed.y, name)),
        ], label: 'Add room');
      }, needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      });
    } on ArgumentError {
      // Refused: nothing is placed.
    } on StateError {
      // Likewise.
    }
    // The pointer still hovers the face, which now holds the new room.
    inputs.invalidate();
    _show(_verdictAt(_raw));
  }

  /// The preview and the notice for [verdict].
  void _show(_Verdict verdict) {
    _preview = verdict == _Verdict.room ? _facePreview : const [];
    if (!_disposed) {
      _notice.value =
          verdict == _Verdict.occupied ? 'Already a room: $_occupant' : null;
    }
  }

  /// Spec 10 D19's verdict for [p], hover and click alike.
  _Verdict _verdictAt(Vector2 p) {
    if (inputs.generation != _generation) {
      _generation = inputs.generation;
      _face = null;
      _faceVerdict = _Verdict.none;
      _occupant = null;
      _facePreview = const [];
      _band = null;
    }
    final u = inputs.bounds;
    if (u == null || !u.containsPoint(p)) return _Verdict.none;
    final band = _band;
    if (band != null && pointInRing(p, band)) return _Verdict.none;
    final face = _face;
    if (face != null && _inFace(p, face)) return _faceVerdict;
    debugTraces++;
    switch (traceRoomAmong(p, inputs)) {
      case final Traced f:
        _cacheFace(f);
        return _faceVerdict;
      case SeedInWall(:final source):
        final input = inputs.inputOf(source);
        if (input != null && input.closed) _band = input.points;
        return _Verdict.none;
      case Unbounded():
        return _Verdict.none;
    }
  }

  /// Caches [f], whether a live room's seed lies in it (the lowest handle
  /// names it), and, when none does, its preview.
  void _cacheFace(Traced f) {
    _face = f;
    _occupant = null;
    final doc = inputs.document;
    for (final h in liveObjectsOf<RoomParams>(doc)) {
      final r = doc.components.get<RoomParams>(h)!;
      final s = doc.tree.accumulatedTransform(h).transformPoint(r.seed);
      if (s.x.isFinite && s.y.isFinite && _inFace(s, f)) {
        _occupant = r.name;
        break;
      }
    }
    if (_occupant != null) {
      _faceVerdict = _Verdict.occupied;
      _facePreview = const [];
      return;
    }
    _faceVerdict = _Verdict.room;
    debugPreviewBuilds++;
    _facePreview = [
      polylinePayload(f.ring, closed: true),
      for (final h in f.holes) polylinePayload(h, closed: true),
    ];
  }

  /// Whether [p] lies in [f]: inside its outer ring and inside none of its
  /// holes. Allocates nothing.
  static bool _inFace(Vector2 p, Traced f) {
    if (!pointInRing(p, f.ring)) return false;
    final holes = f.holes;
    for (var i = 0; i < holes.length; i++) {
      if (pointInRing(p, holes[i])) return false;
    }
    return true;
  }

  /// `Room N`, `N` the lowest positive integer such that no live room of
  /// [doc] is named exactly `Room N` (spec 10 D19).
  static String _nextName(DraftDocument doc) {
    final used = <int>{};
    for (final h in liveObjectsOf<RoomParams>(doc)) {
      final m = _roomN.firstMatch(doc.components.get<RoomParams>(h)!.name);
      if (m == null) continue;
      if (int.tryParse(m[1]!) case final n?) used.add(n);
    }
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return 'Room $n';
  }

  /// A document change while a preview or a notice shows: the verdict at
  /// the pointer again, among inputs rebuilt whatever order the change's
  /// listeners run in.
  void _onDocumentChange() {
    if (_disposed || (_preview.isEmpty && _notice.value == null)) return;
    inputs.invalidate();
    _show(_verdictAt(_pointer));
    notifyListeners();
  }

  /// Every cancel path (Escape with a shape pending never happens here; a
  /// switch to another tool, the layer's deactivate and dispose) clears the
  /// notice and the preview (R-29).
  @override
  void cancel(ToolContext ctx) {
    _preview = const [];
    if (!_disposed) _notice.value = null;
    super.cancel(ctx);
  }

  @override
  void dispose() {
    _disposed = true;
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _changes = null;
    _notice.dispose();
    super.dispose();
  }

  /// The would-be face's rings, from the payloads the last pointer move
  /// chose; nothing is computed here.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    final preview = _preview;
    if (!hoverVisible || preview.isEmpty) return;
    final ox = origin.x, oy = origin.y;
    band.reset();
    // Indexed: no iterator per frame.
    for (var i = 0; i < preview.length; i++) {
      final c = preview[i].coords;
      band.moveTo(c[0] - ox, c[1] - oy);
      for (var j = 2; j + 1 < c.length; j += 2) {
        band.lineTo(c[j] - ox, c[j + 1] - oy);
      }
    }
    canvas.drawPath(band, bandPaint);
  }
}
