import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/draw/arc_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/circle_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/line_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/placement_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/polyline_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/rectangle_tool.dart';
import 'package:jet_cad_2d_flutter/src/draw/text_tool.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';

import '../support/draw_fixture.dart';
import '../support/grip_fixture.dart' show pointerAt, screenOf, snapshot;

/// One placement tool of this package, and how its shape ends: after
/// [clicksToFinish] clicks, or (when null) on Enter after two clicks.
final class _Shape {
  const _Shape(this.name, this.make, {this.clicksToFinish});
  final String name;
  final PlacementTool Function() make;
  final int? clicksToFinish;
}

final _shapes = <_Shape>[
  // The Line tool chains: a second click commits a segment and starts the
  // next from its end, so only Enter (or Escape) ends the shape.
  _Shape('Line', LineTool.new),
  _Shape('Polyline', PolylineTool.new),
  _Shape('Rectangle', RectangleTool.new, clicksToFinish: 2),
  _Shape('Circle', CircleTool.new, clicksToFinish: 2),
  _Shape('Arc', ArcTool.new, clicksToFinish: 3),
];

/// Off the origin, off every lattice, clear of the anchor line's endpoints
/// and of each other, and not collinear: every shape they make is
/// non-degenerate.
const _clicks = <(double, double)>[
  (7020.5, 3030.25),
  (7090.75, 3075.5),
  (7040.125, 3110.375),
];

Offset _at(DrawRig rig, int i) =>
    screenOf(rig.camera, _clicks[i].$1, _clicks[i].$2);

/// What [ToolController] reports at each of its notifications: the value a
/// shell listening to it would read.
List<bool> _record(ToolController tools) {
  final seen = <bool>[];
  tools.addListener(() => seen.add(tools.active.isMidShape));
  return seen;
}

void main() {
  // `PlacementTool.onKey` reads HardwareKeyboard.instance for F3 and F
  // (Ruling F-2), which needs a bound ServicesBinding.
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final flipY in const [true, false]) {
    group('flipY $flipY', () {
      for (final shape in _shapes) {
        test(
            'MS1 ${shape.name}: not mid-shape fresh, mid-shape after the '
            'first click, not after Escape; the controller notifies each '
            'change', () {
          final s = drawScene();
          final tool = shape.make();
          addTearDown(tool.dispose);
          final rig =
              drawRig(s.document, tool, flipY: flipY, objectSnap: false);
          final seen = _record(rig.tools);
          final before = snapshot(s.document);

          expect(tool.isMidShape, isFalse);
          expect(rig.tools.active.isMidShape, isFalse);

          clickAt(rig, _at(rig, 0));
          expect(tool.points, hasLength(1), reason: 'one point placed');
          expect(tool.isMidShape, isTrue);
          expect(rig.tools.active.isMidShape, isTrue);
          expect(seen, isNotEmpty);
          expect(seen.last, isTrue,
              reason: 'the click notified with the tool mid-shape');

          final notified = seen.length;
          expect(
              keyDown(
                  rig, LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
              KeyEventResult.handled);
          expect(tool.isMidShape, isFalse);
          expect(rig.tools.active.isMidShape, isFalse);
          expect(seen.length, greaterThan(notified), reason: 'Escape notified');
          expect(seen.last, isFalse);
          expect(snapshot(s.document), before,
              reason: 'Escape dropped the shape and touched nothing');
        });

        test(
            'MS2 ${shape.name}: mid-shape between clicks, not once the shape '
            'is finished and committed', () {
          final s = drawScene();
          final tool = shape.make();
          addTearDown(tool.dispose);
          final rig =
              drawRig(s.document, tool, flipY: flipY, objectSnap: false);
          final seen = _record(rig.tools);
          final depth = s.document.commands.undoDepth;

          final finishAt = shape.clicksToFinish;
          if (finishAt != null) {
            for (var i = 0; i < finishAt - 1; i++) {
              clickAt(rig, _at(rig, i));
              expect(tool.isMidShape, isTrue, reason: 'after click ${i + 1}');
              expect(seen.last, isTrue);
            }
            clickAt(rig, _at(rig, finishAt - 1));
          } else {
            for (var i = 0; i < 2; i++) {
              clickAt(rig, _at(rig, i));
              expect(tool.isMidShape, isTrue, reason: 'after click ${i + 1}');
              expect(seen.last, isTrue);
            }
            expect(
                keyDown(
                    rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
                KeyEventResult.handled);
          }
          expect(s.document.commands.undoDepth, greaterThan(depth),
              reason: 'the shape was committed, not cancelled');
          expect(tool.isMidShape, isFalse);
          expect(rig.tools.active.isMidShape, isFalse);
          expect(seen.last, isFalse,
              reason: 'finishing the shape notified with it no longer '
                  'mid-shape');
        });

        test(
            'MS3 ${shape.name}: switching tools ends the shape; the '
            'controller notifies with the new tool idle', () {
          final s = drawScene();
          final tool = shape.make();
          addTearDown(tool.dispose);
          final rig =
              drawRig(s.document, tool, flipY: flipY, objectSnap: false);
          final select = SelectTool();
          addTearDown(select.dispose);
          final seen = _record(rig.tools);

          clickAt(rig, _at(rig, 0));
          expect(rig.tools.active.isMidShape, isTrue);
          final notified = seen.length;
          rig.tools.activate(select);
          expect(tool.isMidShape, isFalse);
          expect(rig.tools.active.isMidShape, isFalse);
          expect(seen.length, notified + 1);
          expect(seen.last, isFalse);
        });
      }

      test(
          'MS4 Text: an open entry is pending but never mid-shape (spec 12a '
          'D6, U-1); committing it leaves it so', () {
        final s = drawScene();
        final tool = TextTool();
        addTearDown(tool.dispose);
        final rig = drawRig(s.document, tool, flipY: flipY, objectSnap: false);
        final seen = _record(rig.tools);
        final depth = s.document.commands.undoDepth;

        expect(tool.isMidShape, isFalse);
        clickAt(rig, _at(rig, 0));
        expect(tool.pending.value, isNotNull, reason: 'the entry is open');
        expect(tool.isPending, isTrue);
        expect(tool.isMidShape, isFalse);
        expect(rig.tools.active.isMidShape, isFalse);

        tool.controller.text = 'Kitchen';
        expect(tool.isMidShape, isFalse,
            reason: 'typed text does not make the entry mid-shape');
        expect(rig.tools.active.isMidShape, isFalse);
        expect(
            keyDown(rig, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
            KeyEventResult.handled);
        expect(s.document.commands.undoDepth, depth + 1,
            reason: 'Enter committed the text');
        expect(tool.isPending, isFalse);
        expect(tool.isMidShape, isFalse);
        expect(seen, isNotEmpty);
        expect(seen, everyElement(isFalse));
      });

      test(
          'MS5 Select: never mid-shape, through a press, a move drag, a '
          'release, a band drag and Escape', () {
        final s = drawScene();
        final line = LineTool();
        addTearDown(line.dispose);
        final rig = drawRig(s.document, line, flipY: flipY);
        final select = SelectTool();
        addTearDown(select.dispose);
        final tools = ToolController(initial: select, context: rig.context);
        addTearDown(tools.dispose);
        final seen = _record(tools);
        final phases = <ToolPhase>{};

        void down(Offset p) {
          select.onPointerDown(pointerAt(rig.camera, p), rig.context);
          phases.add(select.phase);
          expect(select.isMidShape, isFalse);
        }

        void move(Offset p) {
          select.onPointerMove(pointerAt(rig.camera, p), rig.context);
          phases.add(select.phase);
          expect(select.isMidShape, isFalse);
        }

        void up(Offset p) {
          select.onPointerUp(pointerAt(rig.camera, p, buttons: 0), rig.context);
          phases.add(select.phase);
          expect(select.isMidShape, isFalse);
        }

        expect(select.isMidShape, isFalse);
        // On the anchor line, off its endpoints: a press on an entity, then
        // a move well past the slop.
        final onLine = screenOf(
            rig.camera, (kAnchorX + 7300.9) / 2, (kAnchorY + 3190.1) / 2);
        down(onLine);
        move(onLine + const Offset(40, 30));
        up(onLine + const Offset(40, 30));
        expect(s.document.commands.undoDepth, 1,
            reason: 'the drag moved the line');

        // A band from empty page.
        final empty = _at(rig, 0);
        down(empty);
        move(empty + const Offset(60, 45));
        expect(select.isMidShape, isFalse);
        select.onKey(
            const KeyDownEvent(
                physicalKey: PhysicalKeyboardKey.escape,
                logicalKey: LogicalKeyboardKey.escape,
                timeStamp: Duration.zero),
            rig.context);
        expect(select.isMidShape, isFalse);
        up(empty + const Offset(60, 45));

        expect(phases, containsAll(ToolPhase.values),
            reason: 'the fixture went through every phase');
        expect(seen, isNotEmpty);
        expect(seen, everyElement(isFalse));
      });
    });
  }
}
