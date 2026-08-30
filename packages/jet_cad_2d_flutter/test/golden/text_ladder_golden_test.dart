@Tags(['golden'])
library;

// Five rungs, each isolating one axis of the text transform, because that
// transform is a product of five factors and a product tells you nothing
// about its terms. Every op-level test in this suite compares a matrix
// against another matrix; the whole class of defect where the matrix is right
// and the *screen* is wrong — Plan 3c's y-flip, which drew every string
// mirrored about its own baseline while every box in the document stayed
// correct — is invisible to all of them and visible here.
//
// The document is built with a `FlutterTextMeasurer` rather than the model
// measurer on purpose. The painter scales by `kNominalTextPixels / ascent`
// read from `document.textMeasurer`, and the sink lays the paragraph out at
// `kNominalTextPixels` through its own; the two are separate objects and the
// glyphs only land inside the box the document thinks they occupy while they
// agree. A golden built on a model measurer would pin a drawing nothing in
// production ever produces.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import '../support/triangle_rasterizer.dart';

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('golden-canvas');

/// The world box every rung is framed to, at the viewport's own aspect ratio
/// so `fit` adds no letterbox and the same world distance is the same number
/// of pixels in all five PNGs.
final Aabb2 kWorld = Aabb2(Vector2(0, 0), Vector2(200, 150));

/// The vendored font, loaded under the family the Standard text style names.
///
/// Without this every string renders in **Ahem**, one solid box per glyph.
/// Ahem is enough to see justification, rotation and shear, and it cannot show
/// rung 5 at all: a mirrored box is a box. See `fonts/README.md` for why the
/// file is vendored rather than read out of the SDK.
Future<void> _loadRoboto() async {
  const path = 'test/golden/fonts/Roboto-Regular.ttf';
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('$path is missing — run from the package root, and see '
        'test/golden/fonts/README.md');
  }
  final bytes = file.readAsBytesSync();
  await (FontLoader('Roboto')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes))))
      .load();
}

DraftDocument _doc() => DraftDocument.empty(measurer: FlutterTextMeasurer());

/// Adds one text entity, with every attribute passed as a per-entity override.
///
/// Both override bits are set unconditionally rather than only when the value
/// differs from the style's: the ladder's job is to vary width factor and
/// oblique angle, and a clear bit means the payload scalar is never read at
/// all, which would quietly collapse rung 4 into one cell drawn six times.
void _text(
  DraftDocument doc,
  String text, {
  required double x,
  required double y,
  Handle? owner,
  double height = 12.0,
  double rotation = 0.0,
  double widthFactor = 1.0,
  double oblique = 0.0,
  int rgb = 0x000000,
  TextJustifyH h = TextJustifyH.left,
  TextJustifyV v = TextJustifyV.baseline,
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: owner ?? doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(rgb),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(
          h: h, v: v, overrideWidthFactor: true, overrideOblique: true),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      scalars: Float64List.fromList([height, rotation, widthFactor, oblique]),
    ),
  ));
}

/// A hairline polyline, used to draw the anchor as something the eye can see.
///
/// A justification ladder without a visible datum is four strings in slightly
/// different places; with one it is four strings measurably left of, centred
/// on, right of and straddling a line.
void _rule(DraftDocument doc, List<double> coords) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0xC00000),
      lineweight: 9,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(const [])),
  ));
}

/// A small cross marking an anchor point, for the rungs whose datum is a
/// point rather than an axis.
void _cross(DraftDocument doc, double x, double y) {
  _rule(doc, [x - 4, y, x + 4, y]);
  _rule(doc, [x, y - 4, x, y + 4]);
}

/// Rung 1 — horizontal justification against one anchor x, in four colours.
///
/// The four rows share the anchor's *x*, which is the axis the codes act on;
/// they are spread in y only so four strings are four strings rather than one
/// smear.
///
/// One string, not four self-describing labels, for the same reason rung 2
/// uses one: four different advance widths make four different offsets a
/// comparison you have to do arithmetic for, and an identical box makes it
/// one you can see. Rows, top to bottom: **left, centre, right, middle**.
/// `middle` is the one that is not a synonym of anything else — it centres on
/// the cap box rather than the baseline box, so it differs from `centre`
/// vertically, not horizontally, and the bottom row sits lower than the row
/// pitch alone would put it.
///
/// **The colours are load-bearing, and only because the string repeats.**
/// `Canvas.drawParagraph` takes no `Paint`; a `ui.Paragraph` bakes its colour
/// in at build time, so `FlutterTextMeasurer` carries an ARGB value in its
/// cache key. Dropping it from the key collapses these four rows onto one
/// cached paragraph and paints all four in whichever colour was built first.
/// On four *different* strings that mutation is invisible — four distinct
/// keys either way — which is what this rung's earlier, self-describing
/// version could not catch.
DraftDocument _rung1() {
  final doc = _doc();
  _rule(doc, [100, 8, 100, 142]);
  const rows = <(TextJustifyH, double, int)>[
    (TextJustifyH.left, 118.0, 0x000000),
    (TextJustifyH.centre, 86.0, 0x1B5E20),
    (TextJustifyH.right, 54.0, 0x0D47A1),
    (TextJustifyH.middle, 22.0, 0xB71C1C),
  ];
  for (final (h, y, rgb) in rows) {
    _text(doc, 'JUSTIFY', x: 100, y: y, h: h, rgb: rgb);
  }
  return doc;
}

/// Rung 2 — vertical justification against one anchor y.
///
/// One string in all four columns, not four different words: the ladder is
/// read by comparing where an *identical* glyph box sits relative to the
/// rule, and four different widths and heights would make that comparison a
/// guess. `Apy` carries an ascender and two descenders, which is what
/// separates `baseline` from `bottom` — on a string of x-height letters the
/// two codes draw in the same place.
///
/// Columns, left to right: baseline, bottom, middle, top.
DraftDocument _rung2() {
  final doc = _doc();
  _rule(doc, [8, 75, 192, 75]);
  const columns = <(TextJustifyV, double)>[
    (TextJustifyV.baseline, 14.0),
    (TextJustifyV.bottom, 60.0),
    (TextJustifyV.middle, 106.0),
    (TextJustifyV.top, 152.0),
  ];
  for (final (v, x) in columns) {
    _text(doc, 'Apy', x: x, y: 75, height: 16, v: v);
  }
  return doc;
}

/// Rung 3 — rotation about the anchor.
///
/// Left/baseline justified so the anchor is the string's own start point and
/// the rotation has one unambiguous pivot; the cross makes that pivot
/// visible, which is what turns "the string is tilted" into "the string is
/// tilted about the right point". The negative angle is not decorative: a
/// sign error is invisible on a symmetric set.
DraftDocument _rung3() {
  final doc = _doc();
  // The anchors are staggered rather than laid on a grid: a rotated string
  // sweeps out of its cell in the direction it points, and the first
  // generated golden clipped the -0.9 cell's last glyph off the bottom edge.
  const cells = <(double, double, double)>[
    (0.0, 25.0, 118.0),
    (0.4, 115.0, 100.0),
    (1.2, 30.0, 20.0),
    (-0.9, 120.0, 72.0),
  ];
  for (final (rotation, x, y) in cells) {
    _cross(doc, x, y);
    _text(doc, 'ROTATE', x: x, y: y, height: 11, rotation: rotation);
  }
  return doc;
}

/// Rung 4 — width factor crossed with oblique angle.
///
/// Crossed rather than laddered separately, because either alone commutes: a
/// scale in x and a shear in x are both lower-triangular, so `scale . shear`
/// and `shear . scale` agree on every cell where one of the two is the
/// identity. They disagree everywhere else, and this rung is those cells.
///
/// **Read it by row, and expect the slope to change.** `composeTransform`
/// shears first and scales x afterwards — `w * (x + k*y)`, which is the DXF
/// reading and is pinned by `text_geometry_test.dart` — so the stem slope is
/// `widthFactor * tan(oblique)` and the wide cell is *more* slanted, not
/// equally slanted. The swapped order would give `w*x + k*y`, one slope
/// across the whole row; that is the drawing this golden exists to reject.
///
/// (Plan 3c Task 11 Step 2 states the opposite as the thing to check. Its
/// sentence is backwards against the engine's own composition order and the
/// test that pins it — see Ruling 34.)
DraftDocument _rung4() {
  final doc = _doc();
  const columns = <(double, double)>[(0.5, 20.0), (1.0, 80.0), (2.0, 140.0)];
  const rows = <(double, double)>[(0.0, 100.0), (0.3, 35.0)];
  for (final (oblique, y) in rows) {
    _rule(doc, [10, y, 190, y]);
    for (final (widthFactor, x) in columns) {
      _text(doc, 'HI',
          x: x, y: y, height: 22, widthFactor: widthFactor, oblique: oblique);
    }
  }
  return doc;
}

/// Rung 5 — the same label inside a mirrored instance and an unmirrored one.
///
/// The mirrored string must read backwards. Text is geometry here, not an
/// annotation: nothing in the pipeline corrects handedness for text, and a
/// painter that did would be *hiding* the instance transform rather than
/// applying it. This is also the only rung that can catch a flip which is
/// right in the matrix and wrong on the canvas, since a mirrored box and an
/// unmirrored box are the same box.
DraftDocument _rung5() {
  final doc = _doc();
  const definition = Handle(500);
  doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'label',
      basePoint: Vector2.zero(),
      children: const []));
  _text(doc, 'STAIR', x: 0, y: 0, owner: definition, height: 18);
  for (final (dx, sx) in const [(20.0, 1.0), (185.0, -1.0)]) {
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      transform:
          Transform2.translation(dx, 70).multiply(Transform2.scale(sx, 1.0)),
      definition: definition,
      layer: ReservedHandles.layerZero,
      color: const TrueColor(0x000000),
    )));
  }
  _rule(doc, [20, 60, 20, 110]);
  _rule(doc, [185, 60, 185, 110]);
  return doc;
}

Widget _framed(DraftDocument doc) => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            key: kCanvasKey,
            width: kGoldenViewport.width,
            height: kGoldenViewport.height,
            child: DraftCanvas(
              // See the note in `dash_ladder_golden_test.dart`: these are the
              // canvas backend's goldens, pinned rather than left to the
              // platform default.
              backend: RenderBackend.canvas,
              document: doc,
              index: SpatialIndex(doc),
              resolver: DocumentStyleResolver(doc),
              camera: CameraController(
                  ViewportTransform.fit(kWorld, kGoldenViewport)),
            ),
          ),
        ),
      ),
    );

/// Renders one rung on one backend and compares it to that backend's PNG.
///
/// The canvas backend goes through [_framed] unchanged, so these five PNGs
/// stay pixel-identical to what they were before this backend loop existed.
/// The vertices backend cannot go through `matchesGoldenFile` on the widget:
/// software Skia does not finish a `drawVertices` of this size, so its
/// triangles are scan-converted by `TriangleRasterizer` and the *image* is
/// matched instead.
///
/// The two sets are framed differently, and this does not try to reconcile
/// it: [_framed] matches on `find.byKey(kCanvasKey)`, which sits on the outer
/// `SizedBox`, and `matchesGoldenFile` walks up from there to the nearest
/// `RepaintBoundary` -- not necessarily the one `DraftCanvas` owns
/// internally. The vertices path below rasterizes exactly `DraftCanvas`'s
/// own surface. The two PNGs are not pixel-registered captures of the same
/// boundary; each is the right instrument for its own backend.
///
/// The vertices golden of this ladder carries the rung's anchor rule or
/// crosses and none of its glyphs: text goes to `CanvasDrawSink` as a
/// paragraph and never reaches the triangle buffer. What it pins is that the
/// strokes around the text are right and that the flush before each text op
/// happened; the glyphs are pinned by the canvas golden beside it.
///
/// Verified by decoding every generated PNG and counting non-transparent
/// pixels rather than by eye: every rung's full set of anchor geometry is
/// present (rung 3's four crosses; rung 4's and rung 5's two rules each), not
/// just some of it. That was not always true — see `TriangleRasterizer`'s
/// construction below for why a thin, near-pixel-grid-aligned line could
/// once vanish entirely from this golden while drawing correctly.
Future<void> _rung(WidgetTester tester, DraftDocument doc, String name,
    RenderBackend backend) async {
  if (backend == RenderBackend.canvas) {
    await tester.pumpWidget(_framed(doc));
    await expectLater(
        find.byKey(kCanvasKey), matchesGoldenFile('text_ladder_$name.png'));
    return;
  }

  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera =
      CameraController(ViewportTransform.fit(kWorld, kGoldenViewport));
  addTearDown(camera.dispose);

  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: kGoldenViewport.width,
          height: kGoldenViewport.height,
          child: DraftCanvas(
              key: key,
              document: doc,
              index: index,
              resolver: DocumentStyleResolver(doc),
              camera: camera,
              backend: backend),
        ),
      ),
    ),
  ));

  // `VerticesDrawSink`'s width floor (`kMinStrokeDevicePixels`) and the
  // colour fade below it are *device*-pixel quantities, but the buffer's
  // positions — what `TriangleRasterizer` scan-converts — are logical
  // pixels. A rasterizer built at logical resolution asks the wrong
  // question: at this widget's own device pixel ratio a stroke can be a
  // full device pixel wide (inked by Impeller) while covering under half a
  // *logical* pixel, which a logical-resolution, no-AA, pixel-centre sampler
  // can miss along its whole length. So the rasterizer is built at the
  // device resolution Impeller would rasterize at.
  //
  // The ratio is the **binding's**, and the sink is asserted against it
  // rather than read back from it. Reading it back made the rasterization
  // resolution follow any mutation of `devicePixelRatio`: deleting
  // `DraftCanvas`'s per-frame rebind (`draft_canvas.dart`, `vertices
  // ?.devicePixelRatio = MediaQuery.devicePixelRatioOf(context)`) leaves the
  // sink at its constructor default of 1.0, and every vertices golden then
  // failed only on *image size* — which one `flutter test
  // --update-goldens` absorbs, writing the wrong stroke widths into the PNGs
  // and locking the break in green forever. A named assertion is the one
  // thing `--update-goldens` cannot absorb.
  final dpr = tester.view.devicePixelRatio;
  expect(key.currentState!.vertices!.devicePixelRatio, dpr,
      reason: 'the sink must be at the binding\'s device pixel ratio: '
          'DraftCanvas rebinds it per frame from MediaQuery, and a sink left '
          'at its constructor default draws stroke widths for the wrong '
          'device. Do NOT regenerate the goldens to make this pass.');
  final rasterizer = TriangleRasterizer((kGoldenViewport.width * dpr).round(),
      (kGoldenViewport.height * dpr).round());
  // Attached after the first pump, and the widget pumped again: the state —
  // and the vertices sink it owns — does not exist until the first build.
  // The observer scales every position by `dpr` before handing it to the
  // device-resolution rasterizer above.
  key.currentState!.vertices!.observer = (positions, colors) {
    final scaled = Float32List(positions.length);
    for (var i = 0; i < positions.length; i++) {
      scaled[i] = positions[i] * dpr;
    }
    rasterizer.observe(scaled, colors);
  };
  // The first pump already painted once — the picture this golden pins —
  // but without an observer attached. Nothing about the document or the
  // camera changes for the second pump, `_DraftCustomPainter.shouldRepaint`
  // is unconditionally false, and the painter's own `repaint` listenable
  // never fires on its own, so a bare `tester.pump()` here finds nothing
  // dirty and skips the repaint entirely — confirmed by a probe that pumped
  // this exact sequence and read the observer back having seen zero
  // triangles. `markNeedsPaint` forces the same picture to paint again, this
  // time through the now-attached observer.
  tester
      .renderObject<RenderObject>(find.descendant(
          of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)))
      .markNeedsPaint();
  await tester.pump();

  // `rasterizer.toImage()` completes through `decodeImageFromPixels`, a real
  // engine callback. Confirmed by a minimal repro: once this test binding has
  // actually pumped a widget, the fake-async test zone never delivers that
  // callback and the await hangs forever; before any pump it resolves
  // immediately. `runAsync` steps outside the fake zone for the one call that
  // needs it.
  final image = (await tester.runAsync(rasterizer.toImage))!;
  addTearDown(image.dispose);

  // A golden that never inks a pixel passes forever and pins nothing --
  // confirmed by a `polyline` no-op mutation that left logical-resolution
  // versions of these goldens green with zero geometry drawn. Every rung
  // draws at least one rule or cross, so this must always ink something.
  expect(rasterizer.pixels.any((p) => p != 0), isTrue,
      reason: 'rung $name drew nothing: its anchor rule or crosses are '
          'always present, so a blank surface means the picture never '
          'reached the rasterizer');
  await expectLater(image, matchesGoldenFile('vertices/text_ladder_$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRoboto);

  for (final (name, fixture) in <(String, DraftDocument Function())>[
    ('1', _rung1),
    ('2', _rung2),
    ('3', _rung3),
    ('4', _rung4),
    ('5', _rung5),
  ]) {
    for (final backend in RenderBackend.values) {
      // Skip the GPU-resident backend: Plan A does not wire a resident-GPU
      // sink into the widget paint path — that is Plan F's job. No sink exists
      // for this backend in the widget rendering, so the golden harness cannot
      // test it.
      if (backend == RenderBackend.residentGpu) continue;
      testWidgets('text ladder rung $name ($backend)', (tester) async {
        await _rung(tester, fixture(), name, backend);
      });
    }
  }
}
