// The Room tool (spec 3a C3.5): ported from jet_cad_floor_plan's
// parametric/room_tool.dart. Its notice is a value the plan words when the
// status line is read (spec 3a C1.2: ToolNotice, a KitText); a new room's
// numbered name is the kit's `text:` word (spec 3a C1.6); which rooms,
// walls and separators are live is the plan's rule (spec 3a C1.5).
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:typed_data' show Float64List;
import 'dart:ui' show Canvas, Size;

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, immutable, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitText, KitWords, ToolNotice, fillText, numberedNameIndex;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import '../words/words.dart' show architectureNames;
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

/// A new room's name (spec 3a C1.6): `{n}` its number.
const String kRoomNameText = 'text:architecture.room-name';

/// The Room tool's notice (spec 3a C1.2): `{name}` the room the hovered
/// face already holds.
const String kRoomOccupiedText = 'text:architecture.room-occupied';

/// The Room tool's notice (spec 10 D19; spec 14d L5): the hovered face
/// already holds the room named [name].
@immutable
final class RoomOccupied {
  const RoomOccupied(this.name);

  final String name;

  /// This notice as the status line words it, when it reads it (spec 3a
  /// C1.2; spec 14d L5: `Already a room: <name>`).
  KitText get text => KitText(kRoomOccupiedText, {'name': name});

  @override
  bool operator ==(Object other) => other is RoomOccupied && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'RoomOccupied($name)';
}

/// Spec 10 D19: the Room tool (M). A `PlacementTool` whose **one click
/// commits** one room; it stays active, and Escape (with nothing pending,
/// ever) returns to the select tool.
///
/// - **The seed is the raw pointer**, unsnapped (R-18; 08's Ruling 08-14):
///   a snap would pull it onto a wall's vertex or face, where the room
///   dissolves at once. So no snap marker is drawn ([paintOverlay]): the
///   pointer is not snapped, as when nothing snaps.
/// - **The verdict for a point**, hover and click alike, the same code
///   ([_verdictAt]), over the kit's shared [RoomInputs] ([roomInputsOf];
///   Ruling 10-11):
///   - outside `inputs.bounds`, the **bounding box** of every place box
///     (T-1: not their union, which leaves out every room's interior when
///     its walls are axis-aligned), `Unbounded` without a trace (S-5);
///   - inside the band of the last `SeedInWall` verdict's wall: reused;
///   - inside the cached face (its outer ring, in none of its holes; an
///     allocation-free point-in-ring test): reused;
///   - inside no component's **outer contour** ([outerContours] of every
///     input, built once per generation on the first hover that reaches
///     this step): `Unbounded` without a trace (the re-review's T-8 cache,
///     adopted at execution). This is a point outside the building but
///     inside the box, between it and a garden wall or along a
///     non-rectangular footprint. The contours are the tracer's own
///     arrangement of the same inputs, tested with its own crossing number
///     ([pointInRingXY]), so a point they answer is `Unbounded` for the
///     tracer too, bar a point within rounding of `roomTrace.linear` of an
///     input, which the tracer calls `SeedInWall`: no room either way. A
///     point inside a contour, a courtyard included, is traced. **Hovers
///     only**: a click and the re-read after a document change skip this
///     step and trace (Task 15's review), since each runs among inputs just
///     invalidated and needs only the trace ([debugContourBuilds] is
///     unchanged across them);
///   - otherwise `traceRoomAmong(p, inputs)`, the trace `generate` makes
///     (`RI1`, `LZ1`), and cached.
///
///   Every cache is dropped when the inputs' [RoomInputs.generation]
///   moves: on each document change, on each [RoomInputs.invalidate], and
///   when a wall or separator the inputs hold freezes (reading the
///   generation re-checks them, spec 3a C1.5). A freeze changes no
///   document, so the room that occupies the cached face is re-checked too
///   at each reuse, and the face re-read without it once it is no longer
///   live.
/// - **Occupied** (decision 26, R-19): the face holds a live room's world
///   seed. No room, no preview, and the click does nothing; [occupied]
///   names the lowest-handle such room and [notice] says so.
/// - **The commit**: one [CompoundCommand], the room's group at the
///   identity and its [RoomParams] (the raw seed, the next free numbered
///   name (`kRoomNameText`), the label auto), needing structure, components
///   and geometry: one undo step, in which the room regenerates. Its handle
///   is allocated inside the build, never predicted. A refused commit
///   places nothing.
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
class RoomTool extends PlacementTool implements ToolNotice {
  RoomTool(this.inputs, {required this.words, required this.live}) {
    _changes = inputs.document.changes.listen((_) => _onDocumentChange());
  }

  /// The kit's document adapter ([roomInputsOf]), shared with the Separator
  /// tool and the separator grips (Ruling 10-11). The tool never disposes
  /// it.
  final RoomInputs inputs;

  /// The kit's words of the moment (the plan's locale, a host's words
  /// first), read when a room is named (spec 14d L7).
  final KitWords words;

  /// The plan's live rule (spec 3a C1.5): the rooms that occupy a face and
  /// whose names are taken.
  final LiveTypeOf live;

  /// The raw world point of the last press (R-18): `accept` is handed the
  /// resolved point only.
  final Vector2 _raw = Vector2.zero();

  /// The raw world point of the last pointer event: where a document
  /// change re-reads the verdict.
  final Vector2 _pointer = Vector2.zero();

  final ValueNotifier<RoomOccupied?> _occupiedNotice =
      ValueNotifier<RoomOccupied?>(null);
  final ValueNotifier<KitText?> _notice = ValueNotifier<KitText?>(null);
  bool _disposed = false;
  StreamSubscription<DocChange>? _changes;

  // The caches, valid while [_generation] is the inputs' generation.
  int _generation = -1;
  Traced? _face;
  _Verdict _faceVerdict = _Verdict.none;

  /// The cached face's notice, built once per face, or null.
  RoomOccupied? _occupied;

  /// The live room that occupies the cached face, or null: re-checked at
  /// each reuse of the face, since a freeze changes no document.
  Handle? _occupiedBy;
  List<GeometryPayload> _facePreview = const [];
  List<Vector2>? _band;

  /// Every component's outer contour, relative to [_contourOrigin], or
  /// null until a hover needs it.
  List<List<Vector2>>? _contours;

  /// Each contour's box, `minX, minY, maxX, maxY` in the same frame: a
  /// point outside it is outside the contour, so the crossing number is
  /// skipped.
  Float64List _contourBoxes = Float64List(0);
  final Vector2 _contourOrigin = Vector2.zero();

  /// How many times the outer contours were built: once per generation at
  /// most.
  @visibleForTesting
  int debugContourBuilds = 0;

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

  /// The room the hovered face already holds, and after a click there
  /// (decision 26, R-29); null otherwise, and cleared when the tool
  /// deactivates.
  ValueListenable<RoomOccupied?> get occupied => _occupiedNotice;

  /// [occupied] as the status line says it (spec 3a C1.2): a word id and
  /// the room's name, put into words when the line is read, so a language
  /// switch re-words it at once.
  @override
  ValueListenable<KitText?> get notice => _notice;

  @override
  String get name => 'Room';

  /// The plain, no-snap glyph, which is none (`drawSnapMarker` of no
  /// kind and no grid): the seed is the raw pointer (R-18), so a snapped
  /// kind's marker, wherever drawn, would claim a snap that does not
  /// happen.
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}

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
    final verdict = _verdictAt(_raw, contours: false);
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
          // Spec 12b D2: a new object takes the current layer.
          SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc))),
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
    _show(_verdictAt(_raw, contours: false));
  }

  /// The preview and the notice for [verdict].
  void _show(_Verdict verdict) {
    _preview = verdict == _Verdict.room ? _facePreview : const [];
    _setOccupied(verdict == _Verdict.occupied ? _occupied : null);
  }

  /// [occupied] and [notice], together; nothing once disposed.
  void _setOccupied(RoomOccupied? room) {
    if (_disposed) return;
    _occupiedNotice.value = room;
    _notice.value = room?.text;
  }

  /// Spec 10 D19's verdict for [p], hover and click alike.
  ///
  /// With [contours] false the outer-contour step is skipped and a point it
  /// would answer is traced instead, to the same verdict: a click, and the
  /// re-read after a document change, run once per event among inputs just
  /// invalidated, so building every contour for them (tens of milliseconds
  /// at 600 walls) would cost more than the one trace it could spare (Task
  /// 15's review). Hovers keep the step: they run per pointer move among
  /// the same inputs, where the contours pay for themselves.
  _Verdict _verdictAt(Vector2 p, {bool contours = true}) {
    if (inputs.generation != _generation) {
      _generation = inputs.generation;
      _face = null;
      _faceVerdict = _Verdict.none;
      _occupied = null;
      _occupiedBy = null;
      _facePreview = const [];
      _band = null;
      _contours = null;
    }
    final u = inputs.bounds;
    if (u == null || !u.containsPoint(p)) return _Verdict.none;
    final band = _band;
    if (band != null && pointInRing(p, band)) return _Verdict.none;
    final face = _face;
    if (face != null && _inFace(p, face)) {
      final by = _occupiedBy;
      if (by != null && live(by) != ArchitectureTypes.room) _cacheFace(face);
      return _faceVerdict;
    }
    if (contours && !_inAnyContour(p, u)) return _Verdict.none;
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
    _occupied = null;
    _occupiedBy = null;
    final doc = inputs.document;
    for (final h in _liveRooms(doc)) {
      final r = doc.components.get<RoomParams>(h)!;
      final s = doc.tree.accumulatedTransform(h).transformPoint(r.seed);
      if (s.x.isFinite && s.y.isFinite && _inFace(s, f)) {
        _occupied = RoomOccupied(r.name);
        _occupiedBy = h;
        break;
      }
    }
    if (_occupied != null) {
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

  /// Whether [p] lies inside some component's outer contour, the contours
  /// of every input built on first need, relative to the centre of [u]
  /// (the inputs' bounding box), so the arithmetic runs on numbers the
  /// size of a building. Allocates nothing once built.
  bool _inAnyContour(Vector2 p, Aabb2 u) {
    var contours = _contours;
    if (contours == null) {
      debugContourBuilds++;
      _contourOrigin.setValues(
          u.minX + (u.maxX - u.minX) / 2, u.minY + (u.maxY - u.minY) / 2);
      contours = _contours = outerContours([
        for (final h in inputs.placedIn(u))
          if (inputs.inputOf(h) case final input?) input,
      ], _contourOrigin);
      _contourBoxes = Float64List(4 * contours.length);
      for (var i = 0; i < contours.length; i++) {
        final b = Aabb2.fromPoints(contours[i]);
        _contourBoxes
          ..[4 * i] = b.minX
          ..[4 * i + 1] = b.minY
          ..[4 * i + 2] = b.maxX
          ..[4 * i + 3] = b.maxY;
      }
    }
    final x = p.x - _contourOrigin.x, y = p.y - _contourOrigin.y;
    final boxes = _contourBoxes;
    for (var i = 0; i < contours.length; i++) {
      if (x < boxes[4 * i] ||
          y < boxes[4 * i + 1] ||
          x > boxes[4 * i + 2] ||
          y > boxes[4 * i + 3]) {
        continue;
      }
      if (pointInRingXY(x, y, contours[i])) return true;
    }
    return false;
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

  /// A name the Room tool gives (spec 10 D19, spec 14d L7, spec 3a C1.6):
  /// the kit's numbered name ([kRoomNameText]) in the words of the moment,
  /// `n` the smallest positive integer no live room's name takes in those
  /// words or in any locale the kit ships (today's rule: the current
  /// language and every built-in one).
  String _nextName(DraftDocument doc) {
    final patterns = _namePatterns();
    final used = <int>{
      for (final h in _liveRooms(doc))
        if (numberedNameIndex(doc.components.get<RoomParams>(h)!.name, patterns)
            case final n?)
          n,
    };
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return words.text(kRoomNameText, {'n': n});
  }

  /// One numbered-name pattern per locale (spec 3a C1.6): the words of the
  /// moment first (a host's word for the current locale included), then
  /// each locale of the kit's own words.
  List<String Function(int n)> _namePatterns() => [
        (n) => words.text(kRoomNameText, {'n': n}),
        for (final locale in architectureNames.words.values)
          if (locale[kRoomNameText] case final template?)
            (n) => fillText(template, {'n': n}),
      ];

  /// Every live room of [doc], ascending by handle (today's
  /// `liveObjectsOf<RoomParams>`, asked of the plan's live rule).
  List<Handle> _liveRooms(DraftDocument doc) =>
      liveObjectsOf<RoomParams>(doc, live, ArchitectureTypes.room);

  /// A document change while a preview or a notice shows: the verdict at
  /// the pointer again, among inputs rebuilt whatever order the change's
  /// listeners run in.
  void _onDocumentChange() {
    if (_disposed || (_preview.isEmpty && _occupiedNotice.value == null)) {
      return;
    }
    inputs.invalidate();
    _show(_verdictAt(_pointer, contours: false));
    notifyListeners();
  }

  /// Every cancel path (Escape with a shape pending never happens here; a
  /// switch to another tool, the layer's deactivate and dispose) clears the
  /// notice and the preview (R-29).
  @override
  void cancel(ToolContext ctx) {
    _preview = const [];
    _setOccupied(null);
    super.cancel(ctx);
  }

  @override
  void dispose() {
    _disposed = true;
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _changes = null;
    _occupiedNotice.dispose();
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
