import 'package:floor_planner/parametric/box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/box_rig.dart';

/// World coordinates of a box's local point (the box's own transform is a
/// pure translation -- spec 06 D13's Box tool is world-axis aligned, never
/// rotated).
Vector2 _worldOf(DraftDocument doc, Handle box, Vector2 local) =>
    doc.tree.accumulatedTransform(box).transformPoint(local);

/// A generated child's world midpoint, from its (local) line payload.
Vector2 _childMidpoint(DraftDocument doc, Handle box, Handle child) {
  final slot = doc.entities.slotOf(child)!;
  final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
  final mid = (payload.pointAt(0) + payload.pointAt(1)) * 0.5;
  return _worldOf(doc, box, mid);
}

/// Strictly inside the world-axis-aligned rectangle `(minX,minY)-(maxX,maxY)`
/// spanned by [box]'s own `BoxParams` (Tolerance is not needed: the sampled
/// midpoints below never sit on a boundary).
bool _strictlyInside(DraftDocument doc, Handle box, Vector2 p) {
  final params = doc.components.get<BoxParams>(box)!;
  final origin = _worldOf(doc, box, Vector2.zero());
  return p.x > origin.x &&
      p.x < origin.x + params.width &&
      p.y > origin.y &&
      p.y < origin.y + params.height;
}

void main() {
  testWidgets('BX1 B and the palette entry activate the Box tool',
      (tester) async {
    await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester.tap(find.byKey(const Key('tool-box')));
    await tester.pump();
    expect(status(tester), 'Box');
  });

  testWidgets('BX2 two clicks: one box, four lines, one undo step',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.pump();
    final b = boxes(doc).single;
    expect(doc.components.get<BoxParams>(b)!.width, closeTo(120, 1e-6));
    expect(doc.components.get<BoxParams>(b)!.height, closeTo(70, 1e-6));
    expect(boxKids(doc, b), hasLength(4));
    expect(doc.commands.undoDepth, 1);
    doc.commands.undo();
    await tester.pump();
    expect(boxes(doc), isEmpty);
    expect(doc.entities.liveSlots, isEmpty);
  });

  testWidgets('BX3 Fill does not apply to a box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyF);
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.pump();
    for (final s in view.document.entities.liveSlots) {
      expect(view.document.entities.kindAt(s), EntityKind.line);
    }
  });

  testWidgets('BX4 two overlapping boxes read as one outline', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.tapAt(globalOf(tester, view, 7100, 3060));
    await tester.tapAt(globalOf(tester, view, 7190, 3120));
    await tester.pump();
    final bs = boxes(doc);
    expect(bs, hasLength(2));
    // Box A: (7010,3020)-(7130,3090); Box B: (7100,3060)-(7190,3120). They
    // overlap in the corner rectangle (7100,3060)-(7130,3090): A's east and
    // north edges each lose the segment running through that corner, and
    // B's west and south edges each lose the same. Each box keeps its two
    // untouched edges whole and its two touched edges as one shortened
    // piece apiece: four children each.
    expect(boxKids(doc, bs[0]), hasLength(4));
    expect(boxKids(doc, bs[1]), hasLength(4));
    expect(ParametricSystem(doc, boxCatalog).drift(), isEmpty);
    // Every child midpoint lies outside the other box's interior.
    for (final child in boxKids(doc, bs[0])) {
      final mid = _childMidpoint(doc, bs[0], child);
      expect(_strictlyInside(doc, bs[1], mid), isFalse,
          reason: 'box A child $child at $mid lies inside box B');
    }
    for (final child in boxKids(doc, bs[1])) {
      final mid = _childMidpoint(doc, bs[1], child);
      expect(_strictlyInside(doc, bs[0], mid), isFalse,
          reason: 'box B child $child at $mid lies inside box A');
    }
  });

  testWidgets(
      'BX5 click a box, Delete: gone with its component; cmd+Z '
      'brings both back (Review Focus 2)', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.tapAt(globalOf(tester, view, 7100, 3060));
    await tester.tapAt(globalOf(tester, view, 7190, 3120));
    await press(tester, LogicalKeyboardKey.keyV);
    final first = boxes(doc).first;
    // The first box's bottom edge, away from the second box.
    await tester.tapAt(globalOf(tester, view, 7040, 3020));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.delete);
    expect(doc.tree[first], isNull);
    expect(doc.components.get<BoxParams>(first), isNull);
    expect(boxKids(doc, boxes(doc).single), hasLength(4));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await press(tester, LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    expect(doc.components.get<BoxParams>(first), isNotNull);
    expect(boxes(doc), hasLength(2));
  });

  testWidgets('BX6 typing B in the page panel field does not switch tools',
      (tester) async {
    await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final field = find.descendant(
        of: find.byKey(const Key('chrome-right')),
        matching: find.byType(EditableText));
    await tester.tap(field.first);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });
}
