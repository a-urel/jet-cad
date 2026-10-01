// Spec 12b S-11: the Door, Window and Gap tools act on the wall under the
// pointer, which is selection-like, so only a wall whose object layer is
// visible and unlocked hosts a new opening. A click on the band of a wall
// on the hidden `C` or the locked `B` places nothing; on the visible,
// unlocked `A` it places one. Where two bands overlap, a wall that may not
// host is passed over, as if it had no band, and the next one hosts.
//
// P-6's fixture (the box on `A`, at the corpus far origin turned 23°, each
// wall in its own rotated group); each wall moved by the picker's command.
import 'package:floor_planner/parametric/live_objects.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_tool.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ToolPointerEvent;
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../support/layer_fixture.dart';

/// Every live opening of [doc].
List<Handle> openingsOf(DraftDocument doc) => liveObjectsOf<OpeningParams>(doc);

/// One click at plan point ([x], [y]) of [fx] with a Window tool: the
/// opening it placed (its host), or null when it placed none, with the undo
/// depth checked either way.
Handle? hostOfClick(LayerDoc fx, double x, double y) {
  final doc = fx.doc;
  final ctx = toolContextOf(doc);
  final settings =
      ValueNotifier(OpeningSettings.defaultFor(OpeningKind.window));
  final tool = OpeningTool(OpeningKind.window, settings);
  addTearDown(() {
    tool.dispose();
    settings.dispose();
  });
  final before = openingsOf(doc);
  final depth = doc.commands.undoDepth;
  clickWith(tool, ctx, fx.at(x, y));
  final added = openingsOf(doc).where((o) => !before.contains(o)).toList();
  if (added.isEmpty) {
    expect(doc.commands.undoDepth, depth, reason: 'nothing dispatched');
    return null;
  }
  expect(added, hasLength(1));
  expect(doc.commands.undoDepth, depth + 1);
  return doc.components.get<OpeningParams>(added.single)!.host;
}

void main() {
  // The top wall's band, 10.25 mm inside its centreline, off its middle.
  const (double, double) onTop = (5000.5, 4010.25);

  test('a wall on the visible, unlocked A hosts a new window (the control)',
      () {
    final fx = layerFixture();
    final top = fx.walls[2];
    expect(objectLayerOf(fx.doc, top), fx.a);
    expect(hostOfClick(fx, onTop.$1, onTop.$2), top);
  });

  test('a wall on the hidden C hosts nothing (M-LP-25)', () {
    final fx = layerFixture();
    final top = fx.walls[2];
    moveObject(fx.doc, top, fx.c);
    expect(fx.doc.tables.layers[fx.c]!.visible, isFalse, reason: 'premise');
    expect(hostOfClick(fx, onTop.$1, onTop.$2), isNull);
  });

  test('a wall on the locked B hosts nothing (M-LP-25)', () {
    final fx = layerFixture();
    final top = fx.walls[2];
    moveObject(fx.doc, top, fx.b);
    final b = fx.doc.tables.layers[fx.b]!;
    expect((b.visible, b.locked), (true, true), reason: 'premise');
    expect(hostOfClick(fx, onTop.$1, onTop.$2), isNull);
  });

  test(
      'a layer hidden after the tool has scanned the point is seen at the '
      'next hover of the same point, before the change stream delivers', () {
    final fx = layerFixture();
    final doc = fx.doc;
    final ctx = toolContextOf(doc);
    final settings =
        ValueNotifier(OpeningSettings.defaultFor(OpeningKind.window));
    final tool = OpeningTool(OpeningKind.window, settings);
    addTearDown(() {
      tool.dispose();
      settings.dispose();
    });
    final p = fx.at(onTop.$1, onTop.$2);
    final move = ToolPointerEvent(
        screen: Offset.zero,
        world: p,
        pointer: 1,
        buttons: 0,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);
    var builds = tool.debugPreviewBuilds;
    tool.onPointerMove(move, ctx);
    expect(tool.debugPreviewBuilds, builds + 1,
        reason: 'premise: the top wall hosts a preview');
    // Hide A, by the panel's command, in the same synchronous task: the
    // band cache's change stream has not delivered yet.
    final a = doc.tables.layers[fx.a]!;
    doc.commands.execute(SetLayerCommand(a.copyWith(visible: false)));
    builds = tool.debugPreviewBuilds;
    tool.onPointerMove(move, ctx);
    expect(tool.debugPreviewBuilds, builds,
        reason: 'the same point, re-scanned: the top wall is hidden now');
  });

  test(
      'where two bands overlap, a wall that may not host is passed over and '
      'the other hosts', () {
    // The box's south-east corner: the south wall (the lowest handle) and
    // the east wall's bands both contain the point.
    const (double, double) corner = (7960.25, 40.5);
    {
      final fx = layerFixture();
      expect(hostOfClick(fx, corner.$1, corner.$2), fx.walls[0],
          reason: 'premise: the lowest handle hosts');
    }
    for (final hidden in [true, false]) {
      final fx = layerFixture();
      moveObject(fx.doc, fx.walls[0], hidden ? fx.c : fx.b);
      expect(hostOfClick(fx, corner.$1, corner.$2), fx.walls[1],
          reason: 'the south wall on ${hidden ? 'hidden C' : 'locked B'}');
    }
  });

  test('isUsableHost reads the object layer, never the stored component', () {
    final fx = layerFixture();
    final doc = fx.doc;
    final top = fx.walls[2];
    expect(isUsableHost(doc, top), isTrue);
    // A component naming a missing layer: the object is on layer 0.
    doc.commands.execute(SetComponentCommand<ObjectLayer>(
        top, const ObjectLayer(Handle(0x7A7A))));
    expect(objectLayer(doc, top), ReservedHandles.layerZero);
    expect(isUsableHost(doc, top), isTrue);
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.commands.execute(SetLayerCommand(zero.copyWith(locked: true)));
    expect(isUsableHost(doc, top), isFalse, reason: 'layer 0 is locked');
  });
}
