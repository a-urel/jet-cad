// Spec 12b D6 and Testing (render): a `DraftCanvas` repaints after a
// `SetLayerCommand` that hides a layer, and the painter it paints with hands
// its sink none of that layer's entities — through the canvas's own
// long-lived `SpatialIndex`, whose filter memo answered for the layer before
// the hide. M-12e: a layer write that bypasses `TableSection`'s `onMutated`
// leaves that memo stale, and this test goes red.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/layer_fixture.dart';

void main() {
  testWidgets(
      'hiding A by a command repaints the canvas and its sink receives none '
      'of A\'s entities; undo brings them back (M-12e)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final f = LayerFixture(measurer: measurer);
    final index = SpatialIndex(f.doc);
    addTearDown(index.dispose);
    final camera =
        CameraController(ViewportTransform.fit(f.doc.extents, kViewport));
    addTearDown(camera.dispose);

    var paints = 0;
    await tester.pumpWidget(Center(
      child: SizedBox(
        width: kViewport.width,
        height: kViewport.height,
        child: DraftCanvas(
          document: f.doc,
          index: index,
          camera: camera,
          minTextCapPixels: 0,
          onPaintForTest: () => paints++,
        ),
      ),
    ));
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    expect(state.tileCache, isNull, reason: 'tiles off: the live frame');
    // Every leaf the frame hands the sink, and every instance it descends.
    final visited = <Handle>{};
    state.painter.debugOnVisit = visited.add;
    addTearDown(() => state.painter.debugOnVisit = null);
    // The first frame (before the hook) primed the index's filter memo: A
    // is answered visible there.
    paintBox(tester).markNeedsPaint();
    await tester.pump();

    // Everything on A, directly or through the instance on A.
    final onA = {
      f.lineA, f.rootA, f.objectChild, f.instance, f.attrib, f.tableLine, //
      f.tableCircle, f.nested, f.legLine, f.regionFill, f.regionBoundary,
    };
    final elsewhere = {f.lineZero, f.lineB, f.rootZero};
    expect(visited, containsAll(onA), reason: 'not vacuous: A draws first');
    expect(visited, containsAll(elsewhere));
    expect(visited, isNot(contains(f.lineC)), reason: 'C is hidden as built');

    final paintsBefore = paints;
    f.doc.commands.execute(SetLayerCommand(f.withState(f.a, visible: false)));
    await tester.idle(); // the DocChange broadcast is asynchronous
    expect(paintBox(tester).debugNeedsPaint, isTrue,
        reason: 'a hide must owe a frame');
    visited.clear();
    await tester.pump();
    expect(paints, greaterThan(paintsBefore));
    for (final h in onA) {
      expect(visited, isNot(contains(h)), reason: 'hidden A: ${h.toHex()}');
    }
    expect(visited, containsAll(elsewhere));

    f.doc.commands.undo();
    await tester.idle();
    visited.clear();
    await tester.pump();
    expect(visited, containsAll(onA), reason: 'undo shows A again');
    expect(visited, containsAll(elsewhere));
  });
}

RenderCustomPaint paintBox(WidgetTester tester) =>
    tester.renderObject<RenderCustomPaint>(find.descendant(
        of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)));
