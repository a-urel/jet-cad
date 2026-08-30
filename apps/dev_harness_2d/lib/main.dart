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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'measurement_rig.dart';
import 'widget_arm_rig.dart';
import 'seam_corpus.dart';

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

/// Which document the harness builds.
enum HarnessCorpus {
  /// [harnessDocument]: 50,000 entities of generated clutter. What every
  /// measurement in `docs/superpowers/notes/` was taken against.
  measure,

  /// [seamCorpus]: about sixty entities, built to be looked at. Reaches gap
  /// G1 -- the antialiased seam no widget test in this repository can produce.
  simple,
}

/// **A `String.fromEnvironment`, and it stays one**, for the reason stated at
/// [kBackend] and [kTiles]: Plan 3c lost a full device run to
/// `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as false.
/// An unrecognised value throws rather than falling back to the default, so a
/// typo cannot silently measure the wrong corpus.
HarnessCorpus parseCorpus(String raw) => switch (raw) {
      'measure' => HarnessCorpus.measure,
      'simple' => HarnessCorpus.simple,
      final other =>
        throw StateError('CORPUS must be measure or simple; got "$other"'),
    };

final HarnessCorpus kCorpus = parseCorpus(
    const String.fromEnvironment('CORPUS', defaultValue: 'measure'));

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

/// How many times `RUN_R2` repeats the `tile zoom` phase
/// ([runTileZoomPhase]) after `runR2Rig` finishes, each run starting fresh
/// from R2's own fitted camera. Zero means the phase never runs at all.
///
/// **An `int.fromEnvironment` would be wrong here for [_intDefine]'s
/// standing reason**: it silently reads anything it cannot parse as the
/// default, and `ZOOM_ARMS=4` mistyped as `ZOOM_ARMS=4x` would run zero arms
/// while looking like a run that asked for four.
///
/// Inert at its default of zero: an ordinary `RUN_R2` session is unaffected,
/// and this is additive to `runR2Rig`'s own pan and zoom phases, not a
/// replacement for either.
final int kZoomArms = _intDefine(
    'ZOOM_ARMS', const String.fromEnvironment('ZOOM_ARMS'), 0,
    minimum: 0);

/// What [kZoomArms] repeats of the zoom phase are *for*.
///
/// - `plain` -- one configuration, repeated. Criterion 2's p95 and nothing
///   else. **No flag is flipped**, so these are not criterion 4's or
///   criterion 8's arms, and the transcript says so on every line.
/// - `criterion4` -- the rest bake against `debugRestBakeDisabled`,
///   interleaved.
/// - `criterion8` -- the narrowed band query against `debugFullViewportQuery`
///   (Plan **3h**'s M4), interleaved.
///
/// **A `String.fromEnvironment` with an explicit throw**, the rule [kBackend]
/// and [kTilePx] already follow and that Plan 3c lost a full device run to by
/// not following: a define that silently falls back to its default writes one
/// run into the table under a heading the command line claimed and the run did
/// not use. `ZOOM_MODE=criterion_4` must stop the session, not quietly measure
/// nine repetitions of one arm.
enum ZoomMode { plain, criterion4, criterion8 }

ZoomMode parseZoomMode(String raw) => switch (raw) {
      'plain' => ZoomMode.plain,
      'criterion4' => ZoomMode.criterion4,
      'criterion8' => ZoomMode.criterion8,
      final other => throw StateError(
          'ZOOM_MODE must be plain, criterion4 or criterion8; got "$other"'),
    };

final ZoomMode kZoomMode = parseZoomMode(
    const String.fromEnvironment('ZOOM_MODE', defaultValue: 'plain'));

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
/// The name of the window-size request, and it is the same name on **both**
/// sides of the language boundary.
///
/// `--dart-define` reaches Dart only, and `macos/Runner/MainFlutterWindow.swift`
/// is what actually sizes the window, so the two sides are configured
/// separately and must be given the same value:
///
/// ```sh
/// export JC_WINDOW=800x600
/// flutter run -d macos --profile --dart-define=JC_WINDOW=$JC_WINDOW ...
/// ```
///
/// The Swift side reads it from `ProcessInfo.processInfo.environment`, which
/// `flutter run` forwards because it starts the app with the parent
/// environment inherited. [reportR2Window] is what catches the two sides
/// disagreeing: it prints the window the app really got and warns when that
/// is not [kMeasurementViewport].
const String kWindowRequestName = 'JC_WINDOW';

/// What a run that asks for nothing gets, on both sides: the size Ruling 20
/// chose. Criteria 2 and 4 are already measured here and must stay
/// reproducible, so this default does not move.
const String kDefaultWindowRequest = '1400x900';

/// The smallest and largest side a window request may name, in logical
/// pixels.
///
/// A size out of range is not a typo an operator catches in the transcript:
/// AppKit places what it can and clamps the rest, so `4x4` and `100000x900`
/// would both quietly become some other window and the run would measure
/// that one. Refusing is the only outcome that cannot be mistaken for a
/// measurement.
const int kMinWindowSide = 100;
const int kMaxWindowSide = 10000;

/// Parses a `WIDTHxHEIGHT` window request into a viewport, or throws.
///
/// **A `String.fromEnvironment` with an explicit throw**, the rule
/// [parseZoomMode] and [kTilePx] already follow and that Plan 3c lost a full
/// device run to by not following: a define that silently falls back to its
/// default writes one run into the table under a heading the command line
/// claimed and the run did not use. Here it is worse than for `ZOOM_MODE`,
/// because Swift reads its own copy of the same request: a fallback on one
/// side of the language boundary and not the other is a run whose camera fit
/// and whose window disagree, which is the failure this whole area exists to
/// prevent.
///
/// Whole logical pixels and a lower-case `x`, so `800X600` and `800.0x600.0`
/// are refusals and not near-misses.
Size parseMeasurementViewport(String raw) {
  final parts = raw.split('x');
  if (parts.length == 2) {
    final width = int.tryParse(parts[0]);
    final height = int.tryParse(parts[1]);
    if (width != null &&
        height != null &&
        width >= kMinWindowSide &&
        width <= kMaxWindowSide &&
        height >= kMinWindowSide &&
        height <= kMaxWindowSide) {
      return Size(width.toDouble(), height.toDouble());
    }
  }
  throw StateError('$kWindowRequestName must be WIDTHxHEIGHT in whole logical '
      'pixels, each side between $kMinWindowSide and $kMaxWindowSide; '
      'got "$raw"');
}

/// The viewport every measurement in this harness is taken at:
/// [kDefaultWindowRequest], **1400x900 logical**, unless a run asks for
/// another size through [kWindowRequestName] -- which
/// `macos/Runner/MainFlutterWindow.swift` reads too, and pins the window to.
///
/// **This is not the size the design spec priced.** Plan 3i's design spec §5
/// pins the measurement viewport at **1600x1200 logical at
/// `devicePixelRatio` 2** and prices every one of its memory predictions
/// against the 3200x2400 device rectangle that implies, saying in as many
/// words that it is *not* the 800x600 test viewport the 2026-08-26 frame
/// counts were taken at.
///
/// **This machine cannot provide 1600x1200.** The logical desktop is
/// 1496x967 and the panel is 3456x2234, so at `devicePixelRatio` 2 even the
/// widest scaling mode gives 1728x1117 -- the height never reaches 1200 in
/// any mode. 1600x1200 logical is unreachable on this display.
///
/// **Ruling 20 chose the default**: the human was shown the trade -- an
/// external display, the 800x600 nib default, or the largest window that
/// fits -- and chose the largest that fits. So:
///
/// > **Every number taken at 1400x900 is NOT comparable to the design
/// > spec's priced predictions**, and is not comparable to any earlier figure
/// > from this harness either, because those were taken at the nib default of
/// > 800x600. A figure from a run at this viewport must be published with the
/// > viewport beside it, and §5's memory predictions remain untested.
///
/// **And that is why the size is selectable rather than pinned to one
/// literal.** Criterion 9 re-measures Plan 3h's `tile pan` and `tile hold`
/// phases against **3h's own recorded figures**, and 3h ran at the nib
/// default of 800x600, because nothing in this harness set a window size
/// until 2026-08-28. A larger viewport means more tiles, more bakes and more
/// work per pan frame, so scoring 3h's numbers against a 1400x900 run
/// measures the viewport change and reports it as a regression -- the first
/// 500,000-entity run read `tile pan` p95 = 23.16 ms against 3h's 19.86 /
/// 15.99 / 13.43 ms for exactly that reason. The confound is removable by one
/// run at `JC_WINDOW=800x600`, and removing it is the only reason this is a
/// request and not a constant.
///
/// A reader who finds a number from this harness and follows it back here has
/// to be able to learn all of that, which is why the comment is this long.
/// [reportR2Window] prints the *real* window on every run and warns when it is
/// not this size, so a figure can never be taken at a viewport nobody
/// recorded -- and it is the only check on the two sides of the language
/// boundary agreeing.
final Size kMeasurementViewport = parseMeasurementViewport(
    const String.fromEnvironment(kWindowRequestName,
        defaultValue: kDefaultWindowRequest));

const bool kRunR2 = bool.fromEnvironment('RUN_R2');

/// **Throwaway spike, branch `spike/widget-per-entity`.** Prices one render
/// object per entity against the single `CustomPainter` walk. Takes over the
/// app entirely: `RUN_WIDGET_SPIKE=true` builds [WidgetSpikeApp], not
/// [HarnessApp].
const bool kRunWidgetSpike = bool.fromEnvironment('RUN_WIDGET_SPIKE');

/// **The GPU-resident arm, Plan A (`2026-08-29-gpu-backend-plan-a-seam-and-
/// strokes`).** Prices `jet_cad_2d_flutter`'s real GPU-resident backend --
/// `GeometryCollector`, `ResidentGeometry.create`, `GpuDrawBackend` -- against
/// the painter walk and against Plan 3i's tile blit. No longer the throwaway
/// spike this define's name remembers: `gpu_arm.dart` and `gpu_arm_rig.dart`
/// (branch `spike/flutter-gpu-backend`) hand-rolled their own collector and
/// their own `flutter_gpu` plumbing to answer the question this backend now
/// answers for real, and Task 9 deleted both in favour of the package's own
/// pieces -- only the harness-side widget and phase rig below remain, and
/// they call straight into the package. The define name and the app class
/// name stay `*GpuSpike*` because the device command below still passes
/// `RUN_GPU_SPIKE=true`, not because this is still a spike.
/// Takes over the app entirely: `RUN_GPU_SPIKE=true` builds [GpuSpikeApp],
/// not [HarnessApp].
const bool kRunGpuSpike = bool.fromEnvironment('RUN_GPU_SPIKE');

/// **Spike corpus knobs.** [harnessDocument] places 20,000 instances, and at
/// `ENTITIES=2000` that made the painter emit **399,000** primitives -- two
/// orders of magnitude past the floor-plan scale this spike exists to measure.
/// The scale that matters here is the number of *drawn primitives*, since that
/// is what both a painter walk and a render-object-per-entity tree pay for, so
/// the instance and definition counts are knobs rather than constants and the
/// run prints the primitive count it actually got.
final int kSpikeDefs = _intDefine(
    'SPIKE_DEFS', const String.fromEnvironment('SPIKE_DEFS'), 20,
    minimum: 1);
final int kSpikeInstances = _intDefine(
    'SPIKE_INSTANCES', const String.fromEnvironment('SPIKE_INSTANCES'), 200,
    minimum: 0);

/// The document the widget spike measures. Deliberately not [harnessDocument]:
/// see [kSpikeDefs].
DraftDocument spikeDocument() => generateDocument(
      kEntities,
      definitionCount: kSpikeDefs,
      instanceCount: kSpikeInstances,
      nestingDepth: 1,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: kDashedFraction,
      labelFraction: 0,
      attributedInstanceFraction: 0,
      measurer: harnessMeasurer,
    );

/// Frames measured per phase, per arm, per repeat.
final int kSpikeFrames = _intDefine(
    'SPIKE_FRAMES', const String.fromEnvironment('SPIKE_FRAMES'), 60,
    minimum: 8);

/// How many times the three arms are cycled. Interleaving is what makes the
/// ratios readable; one repeat is a single sample and says little.
final int kSpikeRepeats = _intDefine(
    'SPIKE_REPEATS', const String.fromEnvironment('SPIKE_REPEATS'), 3,
    minimum: 1);

void main() {
  final doc = switch (kCorpus) {
    HarnessCorpus.measure => harnessDocument(),
    HarnessCorpus.simple => seamCorpus(measurer: harnessMeasurer),
  };
  if (kRunWidgetSpike) {
    runApp(WidgetSpikeApp(
      document: spikeDocument(),
      viewport: kMeasurementViewport,
      lineweightScale: kLineweightScale,
      onReady: (state) => unawaited(runWidgetSpike(
        state,
        entities: kEntities,
        frames: kSpikeFrames,
        repeats: kSpikeRepeats,
        viewport: kMeasurementViewport,
      )),
    ));
    return;
  }
  if (kRunGpuSpike) {
    runApp(GpuSpikeApp(
      document: spikeDocument(),
      viewport: kMeasurementViewport,
      lineweightScale: kLineweightScale,
      // **The error is caught and printed, not left unhandled.** On the web a
      // dart2js profile build reports an unhandled async error as a bare
      // minified `Error` with no message, which says nothing about what
      // failed. Catching it is the difference between a diagnosable run and a
      // stack trace of `main.dart.js` line numbers.
      onReady: (state) => unawaited(runGpuSpike(
        state,
        entities: kEntities,
        frames: kSpikeFrames,
        repeats: kSpikeRepeats,
        viewport: kMeasurementViewport,
      ).then<void>((_) {}, onError: (Object error, StackTrace stack) {
        print('GSPIKE RUN FAILED: $error');
        print(stack);
      })),
      onFailed: (error, stack) {
        // Printed rather than thrown: a failure to reach flutter_gpu at all is
        // this spike's most likely outcome and its most useful finding.
        print('GSPIKE FAILED to build resident geometry: $error');
        print(stack);
      },
    ));
    return;
  }
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

  // Every `RUN_R2` run, not only the ones that run a zoom arm: the window
  // line and the mismatch warning against [kMeasurementViewport] come out
  // together. R2's own pan and zoom phases are as viewport-dependent as the
  // tile phase is.
  reportR2Window(viewport, kMeasurementViewport,
      devicePixelRatio: view.devicePixelRatio);

  // R2's fitted camera, held so the `tile zoom` phase below can restart from
  // it — [runR2Rig] moves `camera` through its own 240-frame script, and by
  // the time it returns the fitted state above is long gone.
  final fittedCamera = camera.value;

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
    // The real window, not [kMeasurementViewport]: R2's zoom step anchors at
    // the centre of the viewport it is actually running in. Handing it the
    // pinned size would reintroduce the hardcoded anchor by another name.
    viewport: viewport,
  );

  // The `tile zoom` phase (Plan 3i, Task 11): `ZOOM_ARMS` repeats of the
  // pinned script, each starting fresh from the same fitted camera `runR2Rig`
  // itself started from, so this arm and Plan 3h's tile-pan arm inside
  // `runR2Rig` describe the same starting state. Off by default -- see
  // [kZoomArms]. What the repeats are *for* is [kZoomMode].
  if (tileCache != null && kZoomArms > 0) {
    // The pinned measurement viewport, not `viewport` above -- see
    // `runTileZoomPhase`'s doc comment for what a differently sized real
    // window means for these numbers, and [kMeasurementViewport] for why the
    // pinned size is 1400x900 and not the design spec's 1600x1200. The
    // mismatch warning is not repeated here: `reportR2Window` above fires it
    // on every run, arm or no arm.
    final zoomViewport = kMeasurementViewport;

    // One criterion-8 arm: back to the fitted camera, then warm, hold and pan
    // — Ruling 21. Criterion 8 re-measures Plan **3h**'s criterion 3 at n=7–9
    // interleaved, and 3h measured that criterion on the `tile pan` phase.
    // `debugFullViewportQuery` modifies the live fallback's query extent and
    // nothing else, and the zoom phase never runs the fallback: every one of
    // its frames is a moving frame, which blits the carry-over composite and
    // returns. Wiring these arms around `runTileZoomPhase` produced a clean
    // n=9 run at 500,000 entities with `gestureLiveDraws=0` in all eighteen
    // arms and two indistinguishable columns of p95.
    //
    // The camera reset is here rather than inside the phase for the same
    // reason it is here for the zoom arm: the arms of a ratio must start from
    // the same camera, and the phase does not own it. What follows it is the
    // arm's own warm loop, which rebuilds the generation *at that camera*, so
    // no arm begins its pan on a generation an earlier arm's pan left
    // somewhere else.
    Future<PanArmReport> runPanArm() async {
      camera.value = fittedCamera;
      await _pumpFrame();
      return runTilePanArm(
        camera: camera,
        cache: tileCache,
        pumpFrame: _pumpFrame,
        // The same step `runTilePhases` pans R2's own block with, from the
        // same function: an arm and the block criterion 9 reads must not be
        // two different measurements printed under one name.
        panStep: tilePanStep(kPanStep),
      );
    }

    // One arm: back to the fitted camera, then the whole pinned script. The
    // camera reset is here rather than inside the phase because the arms of a
    // ratio must start from the same camera, and the phase does not own it.
    //
    // **This pump's `FrameTiming` lands inside the phase, not before it.**
    // `_pumpFrame` completes at `SchedulerBinding.endOfFrame`, before the
    // frame rasterises, so the timing arrives after `runTileZoomPhase` has
    // armed its log. The phase drains it — see
    // `FrameTimingLog.establishBaseline` — rather than this call site trying
    // to order itself against a report that has not happened yet.
    Future<ZoomReport> runArm() async {
      camera.value = fittedCamera;
      await _pumpFrame();
      return runTileZoomPhase(
        camera: camera,
        cache: tileCache,
        pumpFrame: _pumpFrame,
        viewport: zoomViewport,
      );
    }

    // Ruling 18 accepts that a shifted timing stream throws and aborts the
    // arm rather than publishing a wrong number -- but `_driveR2` is launched
    // with `unawaited` and had no `catch` of its own, so that throw used to
    // reach the operator as a bare `StateError` with none of this
    // transcript's own prefixes: no `R2 tile zoom:` line naming which mode
    // aborted, no `R2 app-run: done` closing it out. This label is
    // cosmetic -- it changes nothing about which arms ran or which are
    // lost -- and exists only so the abort reads like the rest of the
    // transcript before it rethrows.
    try {
      switch (kZoomMode) {
        // **Relabelled rather than refused.** Repeats of one configuration are
        // a real capability -- criterion 2 is a p95 over gesture frames and
        // wants repeats, not arms -- so refusing here would remove a
        // measurement to prevent a mislabelling. What made the old output
        // dangerous was that it printed `arm 0..8` with no flag flipped and
        // nothing naming which arm was which: the exact shape and labelling
        // of the n=9 interleaved transcript criteria 4 and 8 call for, with
        // every ratio reading 1.00. The word "arm" is gone, every line says
        // which flag state it ran at, and the heading below says what this
        // mode is not.
        case ZoomMode.plain:
          print('R2 tile zoom: ZOOM_MODE=plain -- $kZoomArms repeats of the '
              'pinned script in ONE configuration (no measurement flag '
              'flipped). This is criterion 2 only. It is NOT criterion 4 or '
              'criterion 8: those need two arms interleaved, and are '
              'ZOOM_MODE=criterion4 and ZOOM_MODE=criterion8.');
          for (var repeat = 0; repeat < kZoomArms; repeat++) {
            printZoomReport(
                zoomPlainLabel(
                    repeat: repeat, repeats: kZoomArms, entities: kEntities),
                await runArm());
          }
        case ZoomMode.criterion4:
          print('R2 tile zoom: ZOOM_MODE=criterion4 -- $kZoomArms repeats of '
              "arm A then arm B, interleaved, in one session. Criterion 4's "
              'ratio is settleWallMs(arm B) / settleWallMs(arm A), per arm.');
          await runZoomCriterionArms(
            criterion: ZoomCriterion.four,
            repeats: kZoomArms,
            entities: kEntities,
            cache: tileCache,
            runArm: runArm,
          );
        // **The `tile pan` phase, not the `tile zoom` phase** -- Ruling 21,
        // and the heading says so because the previous heading did not and
        // eighteen arms of nothing were published under it. See `runPanArm`
        // above for the whole of the reason.
        case ZoomMode.criterion8:
          print('R2 tile pan: ZOOM_MODE=criterion8 -- $kZoomArms repeats of '
              'arm A then arm B, interleaved, in one session, around the '
              '**tile pan** phase and NOT the zoom phase. Criterion 8 '
              "re-measures Plan 3h's criterion 3, which 3h measured on "
              '`tile pan`: that is where the live fallback runs and where '
              "Plan 3h's M4 bites. The statistic is `tile pan` p95, per arm, "
              'and `tile hold` beside it is the control M4 cannot touch. '
              "Arm B is Plan 3h's M4 as a runtime flag, not this plan's M4.");
          await runCriterionArms<PanArmReport>(
            criterion: ZoomCriterion.eight,
            repeats: kZoomArms,
            entities: kEntities,
            cache: tileCache,
            phase: 'tile pan',
            runArm: runPanArm,
            emit: printPanArmReport,
          );
      }
    } catch (e) {
      print('!!! ARM ABORTED: $e');
      rethrow;
    }
  }
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
      ViewportTransform.fit(widget.document.extents, kMeasurementViewport));
  final GlobalKey<DraftCanvasState> _canvasKey = GlobalKey<DraftCanvasState>();

  /// The zoom factor already applied from the trackpad gesture in progress.
  ///
  /// `pan` and `scale` on a `PointerPanZoomUpdateEvent` are **cumulative since
  /// the gesture began**, not per-event deltas. Applying the reported value
  /// directly on every update compounds it -- three updates of a steady pinch
  /// to 1.5 would zoom by 1.5^3 -- so each update applies only the ratio it
  /// adds over this.
  ///
  /// Reset when a gesture starts rather than when one ends: a start event is
  /// guaranteed to precede every update, an end event is not guaranteed to
  /// arrive at all.
  double _gestureZoom = 1.0;

  /// Where the trackpad gesture began, in this widget's coordinates.
  ///
  /// The anchor is held still for the whole gesture instead of tracking the
  /// drifting pointer, which is what `ScaleGestureRecognizer.focalPoint` does
  /// once trackpad scrolling causes scale. A moving anchor makes a two-finger
  /// scroll translate the view as a side effect of zooming it.
  Offset _gestureAnchor = Offset.zero;

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
              //
              // This is the **mouse wheel** path and only that. A macOS
              // trackpad sends no pointer signal at all: two-finger scroll and
              // pinch both arrive as the pan/zoom events handled below.
              camera.zoomAt(event.localPosition,
                  event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            },
            onPointerPanZoomStart: (event) {
              _gestureZoom = 1.0;
              _gestureAnchor = event.localPosition;
            },
            onPointerPanZoomUpdate: (event) {
              // Pinch reports `scale`; two-finger scroll reports `pan` and
              // leaves `scale` at 1. One expression covers both, and covers a
              // pinch that drifts and reports the two together.
              //
              // The pan conversion is Flutter's own, from
              // `kDefaultTrackpadScrollToScaleFactor`: exp(pan.dy / -200),
              // whose sign carries the convention that scrolling up zooms in.
              final factor = event.scale * math.exp(event.localPan.dy / -200.0);
              // `zoomAt` ignores a non-positive or non-finite factor, but the
              // running value must not be poisoned by one either.
              if (!factor.isFinite || factor <= 0) return;
              camera.zoomAt(_gestureAnchor, factor / _gestureZoom);
              _gestureZoom = factor;
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

// --- The GPU arm: painter vs. tiles vs. jet_cad_2d_flutter's resident-GPU
// backend, interleaved. -----------------------------------------------
//
// Formerly `gpu_arm.dart` and `gpu_arm_rig.dart` (branch
// `spike/flutter-gpu-backend`), which hand-rolled a collector and their own
// `flutter_gpu` plumbing to answer one question: can a pan or a zoom cost a
// uniform write instead of a document walk, and still draw sharp? Plan A
// (`docs/superpowers/plans/2026-08-29-gpu-backend-plan-a-seam-and-strokes.md`)
// answered it by building the collector, the upload and the frame path as
// real package code -- `GeometryCollector`, `ResidentGeometry.create`,
// `GpuDrawBackend`, all from `package:jet_cad_2d_flutter` -- and Task 9
// deleted the spike's two files in the same commit that pointed this arm at
// them. What remains here is harness-side glue only: the widget that hosts
// the backend and turns its output into a `ui.Image` on the canvas, and the
// three-arm phase rig `runGpuSpike` drives -- unchanged in shape from the
// spike, because interleaving three arms over a hold, a pan and a zoom is
// measurement methodology, not backend-specific.
//
// **What arm C (the resident backend) does not draw, and why that is not a
// bug in this harness.** `GeometryCollector` implements only
// `DrawSink.polyline` -- `point`, `circle`, `arc`, `fillPolygon` and
// `fillCircle` all fall through to its `skippedOps` counter. Plan A's own
// self-review says so: joins, caps and `point()` are Plan B's job; dashed
// *arcs* are Plan C's (a dashed *polyline*'s spans already reach the sink as
// ordinary `polyline` calls, so straight dashed strokes draw today); fills
// are Plan D's; text is Plan E's. A corpus with circles, arcs, fills or text
// will show visibly less on arm C than on arm A or B -- `skippedOps` in the
// `GSPIKE collect+upload` line says how much, so a thin picture reads as a
// number instead of as a silent gap.
//
// **The buffer is collected once, at the arm's starting camera, and never
// re-walked.** A dash pattern's spans are split at that camera's scale and
// then baked into the resident buffer, so they stretch under zoom exactly
// the way the spike's did -- not a cheat here, but the direct consequence of
// "walked once" being the whole point of this backend.

/// The three arms.
enum GpuSpikeArm {
  /// Today's untiled path: the whole document walked per frame into one
  /// `drawVertices`.
  painter,

  /// Today's *gesture* path, and the one that matters: Plan 3i's tile cache,
  /// which answers a moving frame by blitting the previous generation's
  /// composite, magnified. Cheap and blurry.
  tiled,

  /// `jet_cad_2d_flutter`'s resident-GPU backend: the geometry uploaded once,
  /// the camera a per-frame uniform, one instanced draw call. Sharp, and the
  /// question is what it costs -- and, on a device for the first time here,
  /// whether it draws the right picture at all.
  gpu;

  String get label => switch (this) {
        GpuSpikeArm.painter => 'A painter (untiled)',
        GpuSpikeArm.tiled => 'B tiles (blit)',
        GpuSpikeArm.gpu => 'C residentGpu (jet_cad_2d_flutter)',
      };
}

/// One phase's timings, in milliseconds.
class GpuPhaseReport {
  GpuPhaseReport(this.arm, this.phase, this.build, this.raster, this.submits,
      {this.unalignedExcess = 0});

  final GpuSpikeArm arm;
  final String phase;
  final List<double> build;
  final List<double> raster;

  /// GPU frames arm C submitted during the phase. Zero on a hold is the arm
  /// working: nothing changed, so nothing was re-rendered.
  final int submits;

  /// Web only: how far the reported-frame count ran ahead of the pumped count.
  /// Zero means the stream never shifted and the figures are aligned after
  /// all. Anything else is the size of the ordinal ambiguity.
  final int unalignedExcess;
}

/// Every line the rig prints, kept so the run can also *show* them.
///
/// **This exists because `print` is not readable on the web.** A dart2js
/// profile build sends `print` to the browser console, which `flutter run`
/// does not forward to its stdout, so a web run posts its numbers where no
/// terminal can see them. Rendering the report into the widget tree makes one
/// screenshot the readable artefact on every platform, which is also what the
/// native runs already had for free. Not this task's platform -- Plan G owns
/// web -- but harmless to keep, and it doubles as the on-screen readout a
/// macOS run's screenshot can show alongside the picture.
final ValueNotifier<List<String>> gpuReportLines =
    ValueNotifier<List<String>>(const <String>[]);

void gpuReport(String line) {
  print(line);
  gpuReportLines.value = <String>[...gpuReportLines.value, line];
}

String gpuStats(List<double> ms) {
  if (ms.isEmpty) return 'NO FRAMES';
  final sorted = [...ms]..sort();
  var sum = 0.0;
  for (final v in sorted) {
    sum += v;
  }
  return 'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)} '
      'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)} '
      'max=${sorted.last.toStringAsFixed(2)} '
      'mean=${(sum / sorted.length).toStringAsFixed(2)} (ms, n=${ms.length})';
}

/// Draws a [GpuDrawBackend] into the widget tree, once per frame, through the
/// image its `render` returns.
///
/// **The render happens in `paint`, not in a callback that schedules another
/// frame.** A two-frame arrangement would put the GPU submit in one frame's
/// numbers and the composite in the next, and neither figure would be the
/// cost of a gesture frame. Here `FrameTiming.buildDuration` covers the
/// uniform write and the submit, and `rasterDuration` covers the composite --
/// the same split every other arm in this harness is read with.
class GpuArmPainter extends CustomPainter {
  GpuArmPainter({
    required this.backend,
    required this.camera,
    required this.devicePixelRatio,
  }) : super(repaint: camera);

  final GpuDrawBackend backend;
  final CameraController camera;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // **Ownership of `image`, spelled out.** `backend.render` returns a
    // fresh `ui.Image` wrapper on every call, over the *same* GPU texture
    // (`GpuDrawBackend._target`, reused across frames and only recreated on
    // resize) -- so this is a new Dart-side handle each frame, not a new
    // texture. `drawImageRect` below records that handle into the `Picture`
    // this `paint` call builds; the picture is what needs the image to stay
    // alive, for as long as the raster thread takes to consume it, which
    // outlives this function returning. This method deliberately does not
    // call `image.dispose()` -- doing so here, before the picture rasterises,
    // would race the very thing that still needs it. Not disposing leaves
    // the handle to the same lifetime the engine already manages for any
    // image recorded into a picture: it is reclaimed once Dart's GC collects
    // this `ui.Image` wrapper, no earlier than the frame that recorded it has
    // rasterised. Over this harness's measured run that is up to 270
    // short-lived per-frame handles (one per `render` call with a camera
    // change); that is a real, accepted GC-pressure cost of a measurement
    // widget creating one `ui.Image` per frame, not a leak, and not a claim
    // about the package's own frame-path allocation budget (CLAUDE.md's
    // non-negotiable governs `jet_cad_2d_flutter`'s frame path, which this
    // ad hoc harness `CustomPainter` is not part of).
    final image = backend.render(camera.value, size, devicePixelRatio);
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(GpuArmPainter oldDelegate) =>
      oldDelegate.backend != backend ||
      oldDelegate.camera != camera ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

/// The GPU arm as a widget: one `CustomPaint` over a repaint boundary.
class GpuArmView extends StatelessWidget {
  const GpuArmView({
    super.key,
    required this.backend,
    required this.camera,
  });

  final GpuDrawBackend backend;
  final CameraController camera;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: GpuArmPainter(
            backend: backend,
            camera: camera,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      );
}

/// The GPU arm's root. Holds every arm and swaps between them on [arm].
class GpuSpikeApp extends StatefulWidget {
  const GpuSpikeApp({
    super.key,
    required this.document,
    required this.viewport,
    required this.lineweightScale,
    required this.onReady,
    required this.onFailed,
  });

  final DraftDocument document;
  final Size viewport;
  final double lineweightScale;
  final void Function(GpuSpikeState state) onReady;
  final void Function(Object error, StackTrace stack) onFailed;

  @override
  State<GpuSpikeApp> createState() => GpuSpikeState();
}

class GpuSpikeState extends State<GpuSpikeApp> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents, widget.viewport));

  final ValueNotifier<GpuSpikeArm> arm = ValueNotifier(GpuSpikeArm.painter);

  /// Null until [_buildResidentGeometry] finishes, and possibly still null
  /// after that -- see the doc comment there. Arm C draws through this, when
  /// it is not null.
  GpuDrawBackend? backend;
  int instanceCount = 0;
  int skippedOps = 0;

  /// Wall-clock cost of the one-time collection and upload, in milliseconds.
  double uploadMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _buildResidentGeometry();
        widget.onReady(this);
      } catch (error, stack) {
        widget.onFailed(error, stack);
      }
    });
  }

  /// Walks the document once, through `GeometryCollector`, and uploads the
  /// result through `ResidentGeometry.create` -- and never walks it again.
  ///
  /// **`ResidentGeometry.create` does not throw.** It returns `null` for two
  /// different reasons -- no GPU on this platform, or a real upload failure,
  /// the latter already reported through `FlutterError.reportError` by the
  /// package itself (`resident_geometry.dart`'s own doc comment) -- so this
  /// method does not need to distinguish them to stay safe; it only needs to
  /// leave [backend] null and say so, which is exactly what makes
  /// `runGpuSpike`'s "arm C submitted no GPU frame" guard fire instead of the
  /// run silently measuring an empty screen.
  Future<void> _buildResidentGeometry() async {
    final stopwatch = Stopwatch()..start();
    final painter = DraftPainter(
      document: widget.document,
      index: index,
      resolver: DocumentStyleResolver(widget.document),
      // Text is not drawn by this arm -- `GeometryCollector.text()` only
      // counts it -- but `drawText: true` still asks the painter to *emit*
      // text ops rather than suppress them. Suppressing them here would
      // make the collector's `skippedOps` undercount: it can only count an
      // op it is actually handed, so what keeps the count honest about what
      // a later plan's backend would still owe is the painter emitting
      // every op and the collector being the one that drops it.
      drawText: true,
    );
    final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      lineweightScale: widget.lineweightScale,
    );
    // **Collected under the fit camera, not an identity one.** `DraftPainter`
    // folds the camera into the residuals it hands a sink, and its
    // level-of-detail decisions read the camera's scale. Collecting under an
    // identity camera would give world coordinates and the *wrong* level of
    // detail. Collecting under the fit camera gives the level of detail a
    // fitted view would draw, and the buffer's space is then that camera's
    // screen space -- which is also the space `collectionCamera` below tells
    // `GpuDrawBackend` to map back out of every frame.
    final collectionCamera = camera.value;
    painter.paint(collector, collectionCamera, widget.viewport);
    final walkMs = stopwatch.elapsedMicroseconds / 1000.0;

    final geometry =
        await ResidentGeometry.create(collector.data, collector.instanceCount);
    stopwatch.stop();

    setState(() {
      instanceCount = collector.instanceCount;
      skippedOps = collector.skippedOps;
      backend =
          geometry == null ? null : GpuDrawBackend(geometry, collectionCamera);
      uploadMs = stopwatch.elapsedMicroseconds / 1000.0;
    });

    if (geometry == null) {
      gpuReport(
          'GSPIKE collect+upload: walk ${walkMs.toStringAsFixed(1)} ms -- '
          'ResidentGeometry.create returned null (no GPU on this platform, or '
          'the upload failed -- check for a FlutterError above this line if '
          'so). instances=$instanceCount, skippedOps=$skippedOps. Arm C will '
          'submit no GPU frames and the rig aborts when it switches to it.');
      return;
    }
    gpuReport('GSPIKE collect+upload: walk ${walkMs.toStringAsFixed(1)} ms, '
        'total ${uploadMs.toStringAsFixed(1)} ms, '
        'instances=$instanceCount, '
        'buffer=${(geometry.byteLength / (1024 * 1024)).toStringAsFixed(2)} MB, '
        'skippedOps=$skippedOps');
  }

  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    arm.dispose();
    backend?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          // `SizedBox.expand` for the reason the widget spike's rig records:
          // a `Stack` sizes itself to its non-positioned children, and an
          // `Offstage` arm is zero-sized exactly when another arm is live.
          body: SizedBox.expand(
            child: ValueListenableBuilder<GpuSpikeArm>(
              valueListenable: arm,
              builder: (context, a, _) {
                final built = backend;
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Offstage(
                      offstage: a != GpuSpikeArm.painter,
                      child: DraftCanvas(
                        document: widget.document,
                        index: index,
                        camera: camera,
                        lineweightScale: widget.lineweightScale,
                        tiles: false,
                      ),
                    ),
                    Offstage(
                      offstage: a != GpuSpikeArm.tiled,
                      child: DraftCanvas(
                        document: widget.document,
                        index: index,
                        camera: camera,
                        lineweightScale: widget.lineweightScale,
                        tiles: true,
                      ),
                    ),
                    if (a == GpuSpikeArm.gpu && built != null)
                      Positioned.fill(
                        child: GpuArmView(backend: built, camera: camera),
                      ),
                    // **Only after the last phase, and that is not cosmetic.**
                    // An overlay in the tree while a phase is running would be
                    // laid out and painted inside the frames being measured.
                    // It appears when the run is over and the numbers are
                    // already taken.
                    Positioned.fill(
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: gpuReportLines,
                        builder: (context, lines, _) {
                          if (lines.isEmpty ||
                              !lines.last.contains('GSPIKE done')) {
                            return const SizedBox.shrink();
                          }
                          return ColoredBox(
                            color: const Color(0xF2FFFFFF),
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  lines.join('\n'),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    height: 1.25,
                                    color: Color(0xFF000000),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}

/// Runs every arm over every phase, interleaved, [repeats] times.
///
/// **Interleaved and not blocked**, for the reason Plan 3i recorded: blocked
/// arms let session drift land entirely on one of them.
Future<void> runGpuSpike(
  GpuSpikeState state, {
  required int entities,
  required int frames,
  required int repeats,
  required Size viewport,
}) async {
  refuseDebugMode();

  final baseCamera = state.camera.value;
  final centre = Offset(viewport.width / 2, viewport.height / 2);

  gpuReport('GSPIKE run: entities=$entities instances=${state.instanceCount} '
      'viewport=${viewport.width.toStringAsFixed(0)}x'
      '${viewport.height.toStringAsFixed(0)} '
      'frames=$frames repeats=$repeats');
  gpuReport('GSPIKE note: arm C (residentGpu) draws only strokes -- '
      '${state.skippedOps} op(s) this walk did not draw (points, circles, '
      'arcs, fills, text: later plans\' job, see the section comment above '
      'this rig). No joins, no caps, no antialiasing. Dash spans are baked at '
      'the collection camera and never re-split under zoom, a consequence of '
      'walking the document exactly once. Every one of those favours arm C '
      'on a timing comparison, which is why the picture matters as much as '
      'the numbers here.');

  final reports = <GpuPhaseReport>[];

  Future<void> setArm(GpuSpikeArm a) async {
    final before = state.backend?.frames ?? 0;
    state.arm.value = a;
    await _pumpFrame();
    await _pumpFrame();
    // **The `painted=0` check belongs here, not in a phase.** Arm C renders
    // only when the camera changes, so a hold legitimately submits nothing --
    // that is the arm working, and the first smoke run's guard called it a
    // defect. What would be a real defect is the arm never painting at all,
    // and switching to it is exactly when that shows. It also fires when
    // [GpuSpikeState.backend] never got built (`ResidentGeometry.create`
    // returned null): `state.backend?.frames` reads `null ?? 0` on every
    // frame, so `before` and the post-switch count are equal either way.
    if (a == GpuSpikeArm.gpu && (state.backend?.frames ?? 0) == before) {
      throw StateError('GSPIKE ${a.label}: switching to this arm submitted no '
          'GPU frame, so it is not in the paint path at all. Every number it '
          'would post is the cost of an empty screen.');
    }
  }

  Future<GpuPhaseReport> phase(
    GpuSpikeArm a,
    String name,
    void Function(int i) step,
  ) async {
    state.camera.value = baseCamera;
    await _pumpFrame();

    final framesAtStart = state.backend?.frames ?? 0;
    var unalignedExcess = 0;
    final log = FrameTimingLog()..arm();
    try {
      await log.establishBaseline(_pumpFrame);
      for (var i = 0; i < frames; i++) {
        step(i);
        await log.pump(_pumpFrame);
      }
      await log.drain(_pumpFrame, upTo: frames);
      // **The refusal stands on native and is relaxed on web, deliberately
      // and only there.** On the web the latch fires on arm A -- the plain
      // painter, no GPU code anywhere near it -- so it is not reporting a
      // defect in what is being measured. It is reporting that ordinal
      // alignment does not hold on that platform. See
      // `FrameTimingLog.debugTimingsUnaligned` for what is given up: these
      // become a distribution over the phase window rather than a statement
      // about the i-th pumped frame, and the excess is printed beside them.
      // Not this task's platform -- Plan G owns web -- kept because it is
      // cheap and this rig outlives the spike it was written for.
      if (!kIsWeb && log.sawBacklog) {
        throw StateError('GSPIKE ${a.label}/$name: the timing stream ran a '
            'backlog after the baseline, so every ordinal is off by an '
            'unknown amount. No figure from this phase is reportable.');
      }
      final timings = kIsWeb ? log.debugTimingsUnaligned : log.debugTimings;
      final build = <double>[];
      final raster = <double>[];
      for (final t in timings) {
        build.add(t.buildDuration.inMicroseconds / 1000.0);
        raster.add(t.rasterDuration.inMicroseconds / 1000.0);
      }
      if (kIsWeb) unalignedExcess = log.debugWorstExcess;
      return GpuPhaseReport(
          a, name, build, raster, (state.backend?.frames ?? 0) - framesAtStart,
          unalignedExcess: unalignedExcess);
    } finally {
      log.disarm();
    }
  }

  for (var r = 0; r < repeats; r++) {
    for (final a in GpuSpikeArm.values) {
      await setArm(a);
      reports.add(await phase(a, 'hold', (i) {}));
      reports.add(
          await phase(a, 'pan', (i) => state.camera.panBy(const Offset(4, 0))));
      reports.add(
          await phase(a, 'zoom', (i) => state.camera.zoomAt(centre, 1.02)));
    }
    gpuReport('GSPIKE --- repeat ${r + 1} of $repeats ---');
    for (final rep
        in reports.skip(reports.length - GpuSpikeArm.values.length * 3)) {
      gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | build  '
          '${gpuStats(rep.build)}');
      gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | raster '
          '${gpuStats(rep.raster)}');
      if (kIsWeb) {
        gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | UNALIGNED '
            '(distribution over the phase window, not per pumped frame); '
            'worst excess=${rep.unalignedExcess} frame(s)');
      }
      if (rep.arm == GpuSpikeArm.gpu) {
        gpuReport('GSPIKE ${rep.arm.label} | ${rep.phase} | '
            'gpu submits=${rep.submits} of $frames frames');
      }
    }
  }

  gpuReport('GSPIKE done: ${reports.length} phase reports above.');
}
