// A measurement harness, not a product.
//
// Pointer pan and scroll zoom go straight to `CameraController`. There is no
// tool architecture and no selection, because tools are Plan 4 and every line
// here is a line the rigs have to keep working.

// ignore_for_file: avoid_print — the RUN_R2 diagnostics below print by
// design; see `measurement_rig.dart`.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'measurement_rig.dart';

/// Entity count, so one binary serves both corpus sizes.
const int kEntities = int.fromEnvironment('ENTITIES', defaultValue: 50000);

/// Multiplies every stroke's device-pixel width at the sink.
///
/// **Measurement-only**, added for Task 4c's fill-rate experiment (B):
/// geometry, draw-call count and the walk are unchanged across a run at 1x,
/// 2x or 4x — only the number of shaded pixels changes. There is no
/// `double.fromEnvironment` in Dart, so this parses the string define at
/// startup rather than being a compile-time constant. Inert at its default
/// of 1.0.
final double kLineweightScale = double.tryParse(
      const String.fromEnvironment('LINEWEIGHT_SCALE', defaultValue: '1.0'),
    ) ??
    1.0;

/// Whether the corpus carries text, and whether the painter draws it.
///
/// Two defines, not one, because they answer different questions.
/// `TEXT=1` changes the *document* — it turns `labelFraction` and
/// `attributedInstanceFraction` on, which changes the entity mix, the extents
/// and therefore the camera, so an R2 run with it on is **not** comparable to
/// Plan 3b's baselines and must be reported as its own row.
/// `DRAW_TEXT=0` changes one branch in the painter and nothing else, which is
/// what makes the text-on/text-off delta readable as the cost of text rather
/// than as the difference between two drawings.
///
/// Both are inert at their defaults: with `TEXT` unset the document is
/// byte-for-byte the one Plan 3b measured, and `DRAW_TEXT` has nothing to act
/// on.
/// The fraction of entities carrying the dashed linetype.
///
/// The dash/leaf separation experiment: `dashSpans` and `screenSpaceLeafCount`
/// move together in this corpus (x1.293 against x1.304 from 10,000 to 50,000
/// entities), so no run so far can tell "cost per drawn leaf" from "cost per
/// dash span" apart. This define holds the geometry still and moves only the
/// linetype, which is the one thing that separates them.
///
/// It is sound as a control because `_Styling.linetypeFor` is a quota counter,
/// not a draw from the corpus's random stream: changing this fraction cannot
/// perturb a single coordinate, so extents, camera and leaf count are
/// unchanged. The one thing it does change is that `generateDocument` seeds
/// the dashed `LinetypeRecord` only when the fraction is positive, so at 0
/// every later handle shifts down by one -- relative draw order, and therefore
/// what is drawn, is the same. That the control held is *measured*, not
/// assumed: the two runs must report the same `screenSpaceLeafCount`.
///
/// There is no `double.fromEnvironment`, so this parses a string define the
/// same way [kLineweightScale] does. Inert at its default of 0.35, which is
/// the value every run before this one used.
final double kDashedFraction = double.tryParse(
      const String.fromEnvironment('DASHED', defaultValue: '0.35'),
    ) ??
    0.35;

const bool kTextCorpus = bool.fromEnvironment('TEXT');
const bool kDrawText = bool.fromEnvironment('DRAW_TEXT', defaultValue: true);

/// Whether the painter culls text too small to read.
///
/// **A `String.fromEnvironment`, and it stays one.** `bool.fromEnvironment`
/// reads `--dart-define=LOD=1` as **false**, and Plan 3c lost a full device run
/// to exactly that with `TEXT=1`. An unrecognised value throws rather than
/// falling back to something that looks fine — **on first read**, not at
/// process startup: this is a lazy top-level `final`, not a `const`, so the
/// throw actually happens at `_HarnessAppState.build()`'s first evaluation of
/// [kMinTextCap], which for an ordinary `flutter run`/`flutter drive`
/// invocation is loud and immediate enough to be the same thing in practice,
/// but is not literally "at startup".
final double kMinTextCap =
    switch (const String.fromEnvironment('LOD', defaultValue: 'true')) {
  'true' => kMinTextCapPixels,
  'false' => 0.0,
  final other =>
    throw ArgumentError.value(other, 'LOD', 'expected "true" or "false"'),
};

/// Fraction of the closed polylines [_addFillRegions] adds that gain a region
/// partner (a fill), when [kFillsEnabled] is on. Named beside
/// [kDashedFraction] for the same reason: a quota, applied by an accumulator
/// exactly the way `_Styling.linetypeFor` and `.colorFor` apply theirs in
/// `generate_document.dart`, not a coin flip -- see that file's comment on
/// why a fraction has to land exactly rather than merely on average.
///
/// The rest of the closed polylines this adds are plain boundaries: stroked,
/// never filled, so the corpus exercises both the fillable-and-filled and the
/// fillable-but-not path.
const double kFillFraction = 0.4;

/// Whether the corpus carries filled regions, and the painter draws them.
///
/// Same shape as [kBackend], for the same reason: a `String.fromEnvironment`,
/// not `bool.fromEnvironment` -- Plan 3c lost a full device run to
/// `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as false
/// while printing entirely plausible numbers. An unrecognised value throws at
/// startup rather than silently defaulting to off.
///
/// Purely additive at its default of `false`: [harnessDocument] never calls
/// [_addFillRegions], so the document is exactly what [generateDocument]
/// returned, coordinate for coordinate -- fills-on and fills-off differ by
/// this one flag on one drawing, the same way `DRAW_TEXT` and `TEXT` are
/// inert at their defaults.
final bool kFillsEnabled =
    switch (const String.fromEnvironment('FILLS', defaultValue: 'false')) {
  'false' => false,
  'true' => true,
  final other => throw StateError('FILLS must be true or false; got "$other"'),
};

/// Which sink the harness draws through: `canvas`, `vertices`, or unset for
/// the platform's own choice.
///
/// **A `String.fromEnvironment`, and it stays one.** Plan 3c lost a full device
/// run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as
/// false while printing entirely plausible numbers; the only thing that caught
/// it was a line printing `corpus=on/off`. A string has no such hazard, and an
/// unrecognised value throws at startup rather than falling back to something
/// that looks fine.
final RenderBackend? kBackend =
    switch (const String.fromEnvironment('BACKEND', defaultValue: '')) {
  '' => null,
  'canvas' => RenderBackend.canvas,
  'vertices' => RenderBackend.vertices,
  final other =>
    throw StateError('BACKEND must be canvas, vertices or unset; got "$other"'),
};

/// Whether the canvas draws its frame from cached tiles.
///
/// **A `String.fromEnvironment`, and it stays one**, for [kBackend]'s reason
/// and one sharper than [kBackend]'s. Plan 3c lost a full device run to
/// `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as false while
/// printing entirely plausible numbers. Here the plausible numbers would be
/// *the control's*: a `TILES=1` that read as false would publish the untiled
/// baseline a second time and the sweep would call it a measurement of the
/// cache. An unrecognised value throws instead.
///
/// Inert at its default of `off`: the canvas builds no [TileCache] at all, and
/// every rig before this one measures exactly what it measured before.
final bool kTiles =
    switch (const String.fromEnvironment('TILES', defaultValue: 'off')) {
  'off' => false,
  'on' => true,
  final other => throw StateError('TILES must be on or off; got "$other"'),
};

/// A tile's side in device pixels, forwarded to [TileCache.tileDevicePixels].
///
/// **Not an `int.fromEnvironment`, and that is the same rule stated for an
/// integer.** `int.fromEnvironment` silently yields its default for anything
/// it cannot parse -- `TILE_PX=256px`, `TILE_PX=` -- so a mistyped sweep arm
/// would run at [kTileDevicePixels] and be written into the table under
/// whichever size the command line claimed. Two rows of the same run is the
/// exact failure the flag above is worded against.
final int kTilePx = _intDefine(
    'TILE_PX', const String.fromEnvironment('TILE_PX'), kTileDevicePixels,
    minimum: 1);

/// The device-pixel bake budget, forwarded to
/// [TileCache.bakeBudgetDevicePixels].
///
/// **Device pixels, not a tile count** -- the same unit [kTilePx] already
/// uses, and the field this forwards to since Task 11a re-expressed it: eight
/// tiles at the 128 px arm of Task 11's sweep was a modest strip, and eight
/// tiles at 512 px is roughly 100 ms of measured bake cost in one frame. A
/// sweep wanting "N tiles at this run's `TILE_PX`" passes
/// `TILE_BAKE=$((N * TILE_PX * TILE_PX))`.
///
/// `0` is a legitimate value -- it is the budget the zoom-path tests take away
/// to prove a frame blitted the carry-over composite rather than a tile -- so
/// the floor here is zero and not one.
final int kTileBake = _intDefine('TILE_BAKE',
    const String.fromEnvironment('TILE_BAKE'), kBakeBudgetDevicePixels,
    minimum: 0);

/// Parses an integer define, or throws. Never falls back on a malformed value:
/// see [kTilePx].
int _intDefine(String name, String raw, int fallback, {required int minimum}) {
  if (raw.isEmpty) return fallback;
  final value = int.tryParse(raw);
  if (value == null || value < minimum) {
    throw StateError('$name must be an integer >= $minimum; got "$raw"');
  }
  return value;
}

/// [_intDefine]'s sibling, for a define that is not an integer.
///
/// Same rule and the same reason: a silent default writes one run into the
/// table under a heading the command line claimed and the run did not use.
double _doubleDefine(String name, String raw, double fallback,
    {double? minimum}) {
  if (raw.isEmpty) return fallback;
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite) {
    throw ArgumentError.value(raw, name, 'not a finite number');
  }
  if (minimum != null && value < minimum) {
    throw ArgumentError.value(raw, name, 'below $minimum');
  }
  return value;
}

/// The tile-pan phase's speed, in logical pixels per frame.
///
/// **A magnitude along the rig's existing direction, and unset means no
/// scaling at all.** The historical step is `Offset(-7, -3)`, magnitude
/// `sqrt(58)` = 7.615773; `PAN_STEP=7.6` would scale it by 0.99793 and make
/// the arm incomparable with every row already recorded at it. `NaN` is the
/// sentinel for unset because zero is a legal magnitude to ask about.
///
/// It reaches the **tile phase only**. R2's own pan keeps `Offset(-7, -3)`
/// unconditionally, or every prior plan's R2 row becomes incomparable.
final double kPanStep = _doubleDefine(
    'PAN_STEP', const String.fromEnvironment('PAN_STEP'), double.nan,
    minimum: 0);

/// The one measurer the harness document is built with, reachable from
/// `_HarnessState.dispose` so the native paragraphs it holds are released.
///
/// A field rather than an inline argument because `DraftCanvas` no longer
/// disposes the cache: the document owns it and the application releases it.
final FlutterTextMeasurer harnessMeasurer = FlutterTextMeasurer();

/// The corpus the rigs measure on: the same shape as R1's, so the two sets of
/// numbers describe one drawing.
///
/// Always built on [harnessMeasurer], a real `FlutterTextMeasurer` —
/// `DraftDocument`'s own default is the zero-metrics `InsertionPointMeasurer`,
/// which collapses every glyph box to a point and every text transform to a
/// singular matrix, and `DraftCanvas` now refuses a document carrying one
/// unconditionally. This file used to branch on [kTextCorpus] instead — a
/// real measurer only when the corpus carried text, the zero-metric one
/// otherwise — which was a workaround at the one call site for what was, even
/// then, true of every document: what actually turns text off is
/// `labelFraction: 0` and `attributedInstanceFraction: 0` below, not the
/// choice of measurer.
DraftDocument harnessDocument([int? entityCount]) {
  final count = entityCount ?? kEntities;
  final doc = generateDocument(
    count,
    definitionCount: 200,
    instanceCount: 20000,
    nestingDepth: 2,
    mirroredFraction: 0.1,
    nonUniformFraction: 0.2,
    groupCount: 50,
    layerCount: 8,
    byBlockFraction: 0.3,
    dashedFraction: kDashedFraction,
    labelFraction: kTextCorpus ? 0.02 : 0,
    attributedInstanceFraction: kTextCorpus ? 0.2 : 0,
    // Always a real measurer — see the doc comment above.
    measurer: harnessMeasurer,
  );
  if (kFillsEnabled) _addFillRegions(doc, count);
  return doc;
}

/// Adds closed-polyline rooms behind [kFillsEnabled]. [kFillFraction] of
/// them are added as an [AddRegionCommand] pair (a fill under a boundary);
/// the rest are added as plain closed [EntityKind.polyline] boundaries with
/// no fill, exercising the fillable-but-not-filled path alongside the filled
/// one.
///
/// **Scattered over a corridor around the floor's centre, not the whole
/// [kFloorWidth] x [kFloorHeight] plan the way `generateDocument`'s own floor
/// entities are, and not a tight cluster at the centre either.** R2 fits the
/// camera to a fixed ~3000x2250 working-set window around `doc.extents`'
/// centre, then scripts 120 pan steps of `Offset(-7, -3)` followed by 120
/// oscillating zoom steps anchored off-centre -- and *that* is the state
/// `printInvariants` reports, not the initial fit. A uniform scatter over the
/// full floor put a visible room in the initial window with probability
/// ~0.3% (measured: `fills=0` at `FILLS=true`); a tight cluster at the
/// initial fit's centre fixed that window but missed the state R2 actually
/// measures -- the pan alone moves the window by roughly (+3200, -1350) world
/// units, confirmed empirically by replaying R2's own script against a fresh
/// camera and reading `visibleWorld` (see the task-16 report). This corridor
/// is the bounding box of the initial and post-pan-and-zoom windows, plus a
/// margin, so rooms stay visible through the whole scripted sequence, not
/// just at one end of it -- and a future change to the pan/zoom script would
/// show up as `fills=0` again rather than silently under-covering.
///
/// Its own [math.Random] stream, seeded independently of
/// [generateDocument]'s two -- this runs after that function has already
/// returned, so sharing either of its streams is not even available, and a
/// fresh one keeps this addition's own output reproducible on its own.
void _addFillRegions(DraftDocument doc, int entityCount) {
  final random = math.Random(0xFEEDFACE);
  final roomCount = math.max(200, entityCount ~/ 100);
  // The floor's own centre -- generateDocument's floor entities are
  // scattered uniformly over [kDefaultOriginX, kDefaultOriginX+kFloorWidth]
  // x [kOriginY, kOriginY+kFloorHeight], so this is a close proxy for
  // `doc.extents`' centre without needing the entities already added to
  // compute it -- close enough that the margin above absorbs the difference.
  final centerX = kDefaultOriginX + kFloorWidth / 2;
  final centerY = kOriginY + kFloorHeight / 2;
  var fillDue = 0.0;
  for (var i = 0; i < roomCount; i++) {
    final w = 30.0 + random.nextDouble() * 90.0;
    final h = 30.0 + random.nextDouble() * 70.0;
    // Corridor: centred (centerX + 1750, centerY - 750), half-extents
    // (3500, 2100) -- see the doc comment above for how these were derived.
    final x0 = centerX + 1750.0 + (random.nextDouble() - 0.5) * 7000.0 - w / 2;
    final y0 = centerY - 750.0 + (random.nextDouble() - 0.5) * 4200.0 - h / 2;
    final coords = Float64List.fromList([
      x0, y0, //
      x0 + w, y0, //
      x0 + w, y0 + h, //
      x0, y0 + h, //
      x0, y0, // closing duplicate: first == last, exactly, per
      // `triangulationFor`'s stored-value comparison.
    ]);
    final payload = GeometryPayload(coords: coords, scalars: Float64List(0));

    fillDue += kFillFraction;
    if (fillDue >= 1.0) {
      fillDue -= 1.0;
      doc.commands.execute(AddRegionCommand.allocate(
        seed: doc.handleSeed,
        owner: doc.rootHandle,
        boundaryKind: EntityKind.polyline,
        boundaryPayload: payload,
        layer: ReservedHandles.layerZero,
        fillColor: const TrueColor(0x3366CC),
        boundaryColor: const TrueColor(0x000000),
      ));
    } else {
      final handle = doc.handleSeed.next();
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: handle,
          owner: doc.rootHandle,
          kind: EntityKind.polyline,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: kByLayer,
          transparency: kByLayer,
          flags: 0,
        ),
        payload: payload,
      ));
    }
  }
}

/// Whether `main()` drives R2 itself on startup and prints its block,
/// instead of waiting to be driven by `integration_test`.
///
/// Task 13's web row needed `flutter drive -d chrome`, and that hangs in
/// this environment before it ever reaches chromedriver — see the Task 13
/// report. `flutter run -d chrome` forwards the app's own `print()` output
/// to the terminal once its debug service links, so this mode drives the
/// rig itself and gets the same block without any driver.
///
/// **Caveat found while measuring, not assumed**: in this environment,
/// `flutter run -d chrome --profile` never printed "Waiting for connection
/// from debug service on Chrome..." and never linked one, so this mode's own
/// `print()` output never reached the terminal in profile mode — only debug
/// mode linked reliably, and debug numbers are exactly what
/// `refuseDebugMode()` inside `runR2Rig` refuses to record. The Task 13
/// report used the Chrome DevTools Protocol directly (reading a value the
/// app wrote to `window.localStorage`, a temporary addition not part of this
/// commit) to get profile-mode numbers out despite that gap; that retrieval
/// path is not shipped here because it is investigation plumbing for one
/// environment's limitation, not shared measurement code. A future
/// environment where profile mode links normally would use this mode as
/// written, watching the terminal directly.
///
/// Same footgun as [kTextCorpus], same rule: a `bool.fromEnvironment` reads
/// anything other than exactly `"true"` as false, so `--dart-define=RUN_R2=1`
/// silently runs the ordinary interactive harness instead. Always pass
/// `=true`.
///
/// Inert at its default of `false`: an ordinary `flutter run`/`flutter
/// drive` harness invocation is unaffected.
const bool kRunR2 = bool.fromEnvironment('RUN_R2');

void main() {
  final doc = harnessDocument();
  if (!kRunR2) {
    runApp(HarnessApp(document: doc));
    return;
  }
  runApp(HarnessApp(
    document: doc,
    onReady:
        (camera, index, painter, sink, vertices, resolvedBackend, tileCache) {
      unawaited(_driveR2(
          doc, camera, painter, sink, vertices, resolvedBackend, tileCache));
    },
  ));
}

/// Fits the camera to the same working-set window `boot()` in
/// `integration_test/frame_timing_test.dart` uses — not the widget's own
/// full-extents fit, which would measure a frame nobody renders — then runs
/// [runR2Rig] the same way the widget test does, driven by real frames
/// instead of a synthetic test clock.
///
/// The viewport this fits *into* is whatever logical size the browser window
/// actually is when this runs, unlike the widget test's fixed synthetic
/// view. That size is printed so a reader can judge comparability against
/// the desktop rows rather than assume it.
Future<void> _driveR2(
  DraftDocument doc,
  CameraController camera,
  DraftPainter painter,
  CanvasDrawSink sink,
  VerticesDrawSink? vertices,
  RenderBackend resolvedBackend,
  TileCache? tileCache,
) async {
  print('R2 app-run: driving started');
  final e = doc.extents;
  final cx = (e.minX + e.maxX) / 2;
  final cy = (e.minY + e.maxY) / 2;
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final viewport = view.physicalSize / view.devicePixelRatio;
  camera.value = ViewportTransform.fit(
      Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125)),
      viewport);
  await _pumpFrame();

  print('R2 app-run: window=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} dpr=${view.devicePixelRatio}');

  await runR2Rig(
    entities: kEntities,
    lineweightScale: kLineweightScale,
    textCorpus: kTextCorpus,
    drawText: kDrawText,
    camera: camera,
    painter: painter,
    sink: sink,
    vertices: vertices,
    resolvedBackend: resolvedBackend,
    tileCache: tileCache,
    pumpFrame: _pumpFrame,
    settle: _settle,
    panStep: kPanStep,
  );
  print('R2 app-run: done');
}

/// Renders exactly one frame and completes after it.
///
/// This is called from inside `_HarnessAppState`'s own post-frame callback —
/// [SchedulerBinding.instance.schedulerPhase] is `postFrameCallbacks`, not
/// `idle`, at that point, and [SchedulerBinding.endOfFrame] only calls
/// [SchedulerBinding.scheduleFrame] for you when the phase is idle. Relying
/// on `camera.value = ...`'s listener chain to schedule the next frame as a
/// side effect worked on the first call by chance and hung on every one
/// after it, once the phase genuinely was idle and nothing else nearby
/// happened to call `scheduleFrame`. Calling it explicitly first removes the
/// dependency on that side effect entirely.
Future<void> _pumpFrame() {
  SchedulerBinding.instance.scheduleFrame();
  return SchedulerBinding.instance.endOfFrame;
}

/// A running app has no synthetic clock to advance, so there is no exact
/// equivalent of `tester.pumpAndSettle()`. This pumps frames while one is
/// still scheduled, bounded, which is the same loop `pumpAndSettle` runs
/// internally minus its own timeout — the closest honest approximation
/// available outside a test.
Future<void> _settle() async {
  const maxIdlePumps = 10;
  for (var i = 0; i < maxIdlePumps; i++) {
    if (!SchedulerBinding.instance.hasScheduledFrame) return;
    await _pumpFrame();
  }
}

class HarnessApp extends StatefulWidget {
  const HarnessApp({super.key, required this.document, this.onReady});

  final DraftDocument document;

  /// Handed the pieces a rig needs to drive: the camera it scripts, the
  /// index whose rebuild count it reports, and the painter and sink whose
  /// counters it reads.
  ///
  /// Fired after the first frame, not from `initState` — the painter and
  /// sink belong to `DraftCanvasState`, a descendant whose own `initState`
  /// has not run yet when this widget's has.
  ///
  /// [vertices] is non-null only when [resolvedBackend] is
  /// `RenderBackend.vertices`; a rig reads its batch and flush counters the
  /// same way it reads the painter's. [resolvedBackend] is what
  /// `DraftCanvasState` actually built, not what [kBackend] asked for.
  /// [tileCache] is non-null exactly when [kTiles] is on -- the cache
  /// `DraftCanvasState` actually built, not the flag that asked for one, for
  /// the reason [resolvedBackend] is the resolved backend and not [kBackend].
  final void Function(
      CameraController camera,
      SpatialIndex index,
      DraftPainter painter,
      CanvasDrawSink sink,
      VerticesDrawSink? vertices,
      RenderBackend resolvedBackend,
      TileCache? tileCache)? onReady;

  @override
  State<HarnessApp> createState() => _HarnessAppState();
}

class _HarnessAppState extends State<HarnessApp> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents, const Size(1600, 1200)));
  final GlobalKey<DraftCanvasState> _canvasKey = GlobalKey<DraftCanvasState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final canvasState = _canvasKey.currentState!;
      // `bakeBudgetDevicePixels` is a mutable field on the cache rather than
      // a `DraftCanvas` property, so the define is applied here -- after the
      // first frame, and before any frame a rig measures.
      canvasState.tileCache?.bakeBudgetDevicePixels = kTileBake;
      widget.onReady?.call(
          camera,
          index,
          canvasState.painter,
          canvasState.sink,
          canvasState.vertices,
          canvasState.resolvedBackend,
          canvasState.tileCache);
    });
  }

  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    // `DraftCanvas` stops disposing the cache under Plan 3f, because two
    // canvases over one document share it. The application owns it instead.
    harnessMeasurer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Listener(
            onPointerMove: (event) {
              if (event.buttons != 0) camera.panBy(event.delta);
            },
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent) return;
              // 1.1 per notch, in the direction the wheel turned. Scroll up is
              // negative dy on every platform Flutter reports.
              camera.zoomAt(event.localPosition,
                  event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            },
            child: DraftCanvas(
                key: _canvasKey,
                document: widget.document,
                index: index,
                camera: camera,
                lineweightScale: kLineweightScale,
                drawText: kDrawText,
                minTextCapPixels: kMinTextCap,
                backend: kBackend,
                tiles: kTiles,
                tileDevicePixels: kTilePx),
          ),
        ),
      );
}
