// The kit's cache of the wall faces a symbol stands against and of the
// symbols already against them (spec 09c D3, D4, S-8; 3a C2 "Shared
// caches", C5), ported from jet_cad_floor_plan/lib/src/symbols/
// wall_attach.dart:409-550 by 3a Task 24. One per kit and document
// (`PlanServices.shared`); besides the bands' generation it keeps the
// document's command state (D-06).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        PlanServices,
        SymbolBox,
        SymbolComponent,
        boxOfDefinition,
        isOrthonormal;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../live.dart';
import '../opening/opening_tool.dart' show isUsableHost;
import '../wall/wall.dart';
import '../wall/wall_bands.dart';
import 'wall_attach.dart';

/// The cache of the face runs and their neighbours (spec 09c D3, D4, S-8),
/// shared by every query of the wall-face provider for one document.
///
/// Built from [bands]' live walls (`WallBands.liveWalls`, which keeps
/// [WallBands.generation] current), the kit's reader [live], the host
/// predicate [accept] (the kit passes `isUsableHost`: a hidden or locked
/// wall hosts nothing) and the document. The runs, the neighbours and the
/// boxes of the document's definitions are rebuilt only when the document,
/// the bands' generation or the document's command state (`stateId`, D-06)
/// changes. A read over a cached set first runs the bands' O(walls)
/// liveness check (a wall frozen with no document change, spec C1.5); a
/// query ([attach]) is then O(runs) and allocates O(1).
final class WallFaces {
  WallFaces(this.bands, this.live,
      {bool Function(DraftDocument, Handle)? accept})
      : _accept = accept;

  /// The kit's bands, shared with the Wall and Opening tools.
  final WallBands bands;

  /// Which objects are live walls (spec C1.5): a frozen wall has no face.
  final LiveTypeOf live;
  final bool Function(DraftDocument, Handle)? _accept;

  DraftDocument? _document;
  int _generation = 0;
  int _state = -1;
  List<FaceRun> _runs = const [];
  List<List<FaceNeighbour>> _neighbours = const [];
  final Map<Handle, SymbolBox?> _boxes = <Handle, SymbolBox?>{};
  int _builds = 0;

  /// How many times the runs and neighbours were rebuilt: once per
  /// document, bands generation and command state, never per query.
  int get builds => _builds;

  /// The face runs of [doc]'s accepted live walls, ascending by wall handle
  /// (each wall's left face's runs, then its right face's).
  List<FaceRun> runsOf(DraftDocument doc) {
    _refresh(doc);
    return _runs;
  }

  /// Parallel to [runsOf]: the neighbours (spec D4) standing against each
  /// run.
  List<List<FaceNeighbour>> neighboursOf(DraftDocument doc) {
    _refresh(doc);
    return _neighbours;
  }

  /// The local box of [doc]'s definition [definition], memoised until the
  /// next rebuild (spec D2: per definition handle, cleared on a document
  /// change); null when it does not attach.
  SymbolBox? boxOf(DraftDocument doc, Handle definition) {
    _refresh(doc);
    return _box(doc, definition);
  }

  /// [attachToWall] over [doc]'s cached runs and neighbours, [exclude]
  /// (the instance a move carries, D8) not a neighbour, keeping [keep]'s
  /// linear part when given (F-7).
  WallAttachment? attach(
    DraftDocument doc,
    SymbolBox box,
    Vector2 p,
    double captureWorld, {
    required bool mirrored,
    required double edgeCaptureWorld,
    Handle? exclude,
    Transform2? keep,
  }) {
    _refresh(doc);
    return attachToWall(_runs, box, p, captureWorld,
        mirrored: mirrored,
        neighbours: _neighbours,
        edgeCaptureWorld: edgeCaptureWorld,
        exclude: exclude,
        keep: keep);
  }

  SymbolBox? _box(DraftDocument doc, Handle definition) {
    if (_boxes.containsKey(definition)) return _boxes[definition];
    return _boxes[definition] = boxOfDefinition(doc, definition);
  }

  void _refresh(DraftDocument doc) {
    final state = doc.commands.stateId;
    // D-06: a command since the last build (a placement by plan.symbol, a
    // move by plan.select: plan tools, which cannot invalidate the bands as
    // today's placement tool did, symbol_place_tool.dart:500) makes the
    // walls, the neighbours and the boxes stale before the document's
    // changes stream reports it. Invalidate the bands as that tool did.
    if (identical(doc, _document) && state != _state) bands.invalidate();
    // Read the bands before comparing their generation: their read finds a
    // wall frozen with no document change (spec C1.5) and moves the
    // generation, so this read rebuilds although nothing was delivered.
    final walls = bands.liveWalls(doc);
    if (identical(doc, _document) && bands.generation == _generation) return;
    _document = doc;
    _generation = bands.generation;
    _state = state;
    _builds++;
    _boxes.clear();
    final runs = <FaceRun>[
      for (final h in walls) ...faceRunsOf(doc, h, live, accept: _accept),
    ];
    _runs = List.unmodifiable(runs);
    _neighbours = _neighboursAlong(doc, runs);
  }

  /// Spec D4's neighbours of each of [runs]: the root-level instances on a
  /// visible, unlocked layer (the picking rule, [QueryFilter.picking])
  /// whose definition carries a [SymbolComponent] and has a box, whose
  /// transform is orthonormal, whose transformed back edge has both ends on
  /// the run's line (within `wallJoin.linear`) with the front on the room
  /// side, and whose interval along `t` overlaps `[0, L]`.
  List<List<FaceNeighbour>> _neighboursAlong(
      DraftDocument doc, List<FaceRun> runs) {
    final placed = <(Handle, Vector2, Vector2, Vector2)>[];
    final root = doc.tree[doc.tree.root];
    if (root is GroupNode) {
      final filter = FilterEvaluator(doc);
      for (final h in doc.tree.childNodesOf(root.children)) {
        final node = doc.tree[h];
        if (node is! InstanceNode) continue;
        if (doc.components.get<SymbolComponent>(node.definition) == null) {
          continue;
        }
        if (!filter.acceptsNode(h, const QueryFilter.picking())) continue;
        final box = _box(doc, node.definition);
        if (box == null) continue;
        final g = doc.tree.accumulatedTransform(h);
        if (!isOrthonormal(g)) continue;
        placed.add((
          h,
          g.transformPoint(Vector2(box.left, box.back)),
          g.transformPoint(Vector2(box.right, box.back)),
          g.transformPoint(Vector2((box.left + box.right) / 2, box.front)),
        ));
      }
    }
    final tol = wallJoin.linear;
    return List.unmodifiable([
      for (final r in runs)
        List<FaceNeighbour>.unmodifiable([
          for (final (h, e1, e2, front) in placed)
            if (((e1 - r.a).dot(r.m)).abs() <= tol &&
                ((e2 - r.a).dot(r.m)).abs() <= tol &&
                (front - r.a).dot(r.m) > 0)
              if (_interval((e1 - r.a).dot(r.t), (e2 - r.a).dot(r.t), h)
                  case final n when n.hi >= 0 && n.lo <= r.length)
                n,
        ]),
    ]);
  }

  static FaceNeighbour _interval(double u1, double u2, Handle h) =>
      u1 <= u2 ? (lo: u1, hi: u2, instance: h) : (lo: u2, hi: u1, instance: h);
}

/// The kit's one [WallFaces] for [s]'s document (spec C2 "Shared caches"):
/// over the shared bands, the kit's live walls and today's host rule.
WallFaces wallFacesOf(PlanServices s) => s.shared<WallFaces>(
    (s) => WallFaces(wallBandsOf(s), liveTypesOf(s), accept: isUsableHost));
