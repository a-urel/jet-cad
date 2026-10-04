// Spec 09c revision 5, R5-2, R5-3 and V-6, over the two shipped libraries:
// no servable entry has a size family (so the Size menu, hidden for a
// table, never has one to hide); every against-wall entry's base point is
// on its box's centre x (D4, D8, as V-6 scopes them); and the real corner
// booth, whose base point is off its box's centre x, turned to 37 degrees
// and mirrored through the Symbol section's commands keeps its footprint
// and its number upright, one undo each.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

SymbolLibrary restaurant() =>
    SymbolLibrary.decode(File('assets/restaurant.jetlib').readAsBytesSync());

SymbolLibrary furniture() => SymbolLibrary.decode(
    File('../jet_cad_floor_plan/assets/library/furniture.jetlib')
        .readAsBytesSync());

/// The world corners of [h]'s box, rounded to 1e-6 and sorted.
List<(double, double)> footprint(DraftDocument doc, Handle h) {
  final node = doc.tree[h]! as InstanceNode;
  final b = boxOfDefinition(doc, node.definition)!;
  final t = node.transform;
  double r(double v) => (v * 1e6).roundToDouble() / 1e6;
  return [
    for (final (x, y) in [
      (b.left, b.front),
      (b.right, b.front),
      (b.right, b.back),
      (b.left, b.back),
    ])
      (() {
        final p = t.transformPoint(Vector2(x, y));
        return (r(p.x), r(p.y));
      })(),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
}

void main() {
  test('SC1 no servable entry of either library has a size family (R5-3)', () {
    var servable = 0;
    for (final library in [furniture(), restaurant()]) {
      for (final e in library.entries) {
        if (e.seats == null) continue;
        servable++;
        expect(familyTagOf(e), isNull, reason: e.key);
      }
    }
    // 14s: the restaurant library's 25 and the furniture library's five
    // dining tables.
    expect(servable, 30, reason: 'premise: every servable symbol');
  });

  test(
      'SC2 every against-wall entry of either library has its base point on '
      'its box\'s centre x (V-6)', () {
    var count = 0;
    for (final library in [furniture(), restaurant()]) {
      for (final e in library.entries) {
        if (!e.tags.contains(againstWallTag)) continue;
        count++;
        final box = boxOfEntry(e)!;
        expect(e.definition.basePoint.x, (box.left + box.right) / 2,
            reason: e.key);
      }
    }
    expect(count, greaterThan(20), reason: 'premise: 09c-1\'s set');
  });

  test(
      'SC3 the corner booth turned to 37 then mirrored: its footprint stays, '
      'its number stays upright; one undo each (R5-2, V-6)', () {
    final e = restaurant()
        .entries
        .singleWhere((x) => x.key == 'restaurant.booth.corner');
    final box = boxOfEntry(e)!;
    expect(e.definition.basePoint.x, isNot((box.left + box.right) / 2),
        reason: 'premise: the base point is off the box\'s centre x');

    final doc = prepareDocument(const InsertionPointMeasurer());
    final parametric = installParametric(doc);
    final tables = TableLabelSystem(doc)..install();
    addTearDown(() {
      tables.dispose();
      parametric.dispose();
    });
    final at = Vector2(41234.5, -38765.25);
    doc.commands.execute(placeSymbol(doc, e, at: at, quarterTurns: 1));
    final booth = doc.tree.nodes.whereType<InstanceNode>().single.handle;
    Transform2 transform() => (doc.tree[booth]! as InstanceNode).transform;

    void expectUpright(String why) {
      final info =
          TableSurvey.of(doc).tables.singleWhere((t) => t.instance == booth);
      final slot = doc.entities.slotOf(info.label!)!;
      final scalars = doc.geometry.read(doc.entities.geomIndexAt(slot)).scalars;
      final want = tableLabelStamp(transform());
      expect(scalars[1], closeTo(want.rotation, 1e-12), reason: why);
      expect(scalars[2], want.widthFactor, reason: why);
    }

    expectUpright('placed');
    final depth = doc.commands.undoDepth;
    final placed = footprint(doc, booth);

    doc.commands.execute(rotateSymbolCommand(doc, booth, 37)!);
    expect(rotationDegreesOf(transform()), closeTo(37, 1e-9));
    expectUpright('turned');
    final turned = footprint(doc, booth);

    doc.commands.execute(mirrorSymbolCommand(doc, booth)!);
    expect(transform().determinant, closeTo(-1, 1e-12), reason: 'mirrored');
    expect(footprint(doc, booth), turned, reason: 'the footprint stays');
    expectUpright('mirrored');
    expect(doc.commands.undoDepth, depth + 2, reason: 'one step each');

    doc.commands.undo();
    expect(footprint(doc, booth), turned);
    expect(transform().determinant, closeTo(1, 1e-12));
    expectUpright('one undo');
    doc.commands.undo();
    expect(footprint(doc, booth), placed);
    expectUpright('two undos');
  });
}
