import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'export_fixture.dart';

/// Pins the export fixture's non-degeneracy (plan 13, P-3): a later edit
/// that puts something at the origin, at the identity or at a default goes
/// red here before it can make an export test vacuous.
void main() {
  final f = exportFixture();
  final doc = f.document;
  final entities = doc.entities;

  int slot(Handle h) => entities.slotOf(h)!;

  test('the page: A4 landscape 1:50, off the origin, dark', () {
    expect(f.page.orientation, PageOrientation.landscape);
    expect(f.page.widthMm, 210);
    expect(f.page.heightMm, 297);
    expect(f.page.scaleDenominator, 50);
    expect(f.page.originX, 3000);
    expect(f.page.originY, -1500);
    expect(f.page.background, 0xFF303030);
    expect(doc.components.get<PageComponent>(doc.rootHandle), f.page);
  });

  test('a page at another scale keeps the origin', () {
    final g = exportFixture(scaleDenominator: 100);
    expect(g.page.scaleDenominator, 100);
    expect(g.page.originX, 3000);
    expect(g.page.originY, -1500);
  });

  test('the instance: rotated 30 degrees, scaled (1.5, -0.75), overrides', () {
    final node = doc.tree[f.instance]! as InstanceNode;
    final t = node.transform;
    expect(t.isIdentity, isFalse);
    expect(t.e, 7000);
    expect(t.f, 5600);
    // Columns of the linear part: R(30) * diag(1.5, -0.75).
    const c = 0.8660254037844387, s = 0.5;
    const tol = 1e-12;
    expect(t.a, closeTo(1.5 * c, tol));
    expect(t.b, closeTo(1.5 * s, tol));
    expect(t.c, closeTo(0.75 * s, tol));
    expect(t.d, closeTo(-0.75 * c, tol));
    expect(math.atan2(t.b, t.a), closeTo(math.pi / 6, tol));
    expect(node.color, const TrueColor(0xFF0000));
    expect(node.color, isNot(const ByBlockColor()));
    expect(node.lineweight, 70);
    expect(node.lineweight, isNot(kByBlock));
    final def = doc.tree.definition(node.definition)!;
    expect(def.basePoint, isNot(Vector2.zero()));
    for (final leaf in [
      f.instanceLine,
      f.instancePolyline,
      f.pointInInstance,
    ]) {
      expect(entities.ownerAt(slot(leaf)), f.definition);
      // BYBLOCK, so the overrides are what the leaves draw with.
      expect(entities.colorAt(slot(leaf)), kByBlock);
      expect(entities.lineweightAt(slot(leaf)), kByBlock);
    }
    expect(entities.kindAt(slot(f.pointInInstance)), EntityKind.point);
  });

  test('root leaves carry their own colour and lineweight', () {
    for (final leaf in [
      f.line,
      f.closedPolyline,
      f.dashed,
      f.arc,
      f.circle,
      f.fill,
      f.labelBig,
      f.labelWc,
      f.aci7Line,
      f.outsideLine,
    ]) {
      final i = slot(leaf);
      expect(entities.ownerAt(i), doc.rootHandle);
      expect(entities.colorAt(i), isNot(anyOf(kByLayer, kByBlock)));
      expect(
        entities.lineweightAt(i),
        isNot(anyOf(kByLayer, kByBlock, kLineweightDefault)),
      );
    }
    expect(
      entities.colorAt(slot(f.aci7Line)),
      encodeColor(const IndexedColor(7)),
    );
    expect(entities.transparencyAt(slot(f.fill)), 127);
    expect(entities.kindAt(slot(f.fill)), EntityKind.fill);
    expect(entities.textAt(slot(f.labelBig)), 'Yatak Odası');
    expect(entities.textAt(slot(f.labelWc)), 'WC');
    final wcStyle = entities.textStyleAt(slot(f.labelWc));
    expect(wcStyle, f.labelWcStyle);
    expect(wcStyle, isNot(ReservedHandles.standardTextStyle));
    final wcRecord = doc.textStyleOf(wcStyle);
    expect([wcRecord.handle, wcRecord.name, wcRecord.fontFamily],
        [f.labelWcStyle, 'Label', 'Arial']);
    expect(entities.linetypeAt(slot(f.dashed)), ReservedHandles.dashedLinetype);
    final dashed = doc.tables.linetypes[ReservedHandles.dashedLinetype]!;
    expect(dashed.name, 'DASHED');
    expect(dashed.pattern.dashes, [200, -100]);
  });

  test('the outer group: its own line, its own instance, a nested group', () {
    final outer = doc.tree[f.outerGroup]! as GroupNode;
    expect(outer.transform.isIdentity, isFalse);
    expect(outer.parent, doc.rootHandle);
    expect(entities.ownerAt(slot(f.outerGroupLine)), f.outerGroup);
    final inst = doc.tree[f.outerGroupInstance]! as InstanceNode;
    expect(inst.parent, f.outerGroup);
    expect(inst.transform.isIdentity, isFalse);
    expect(entities.ownerAt(slot(f.outerInstanceLeaf)), f.outerDefinition);
    final nested = doc.tree[f.nestedGroup]! as GroupNode;
    expect(nested.parent, f.outerGroup);
    expect(nested.transform.isIdentity, isFalse);
    expect(entities.ownerAt(slot(f.nestedLine)), f.nestedGroup);
    expect(outer.children, containsAll([f.outerGroupInstance, f.nestedGroup]));
  });

  test('the separator: a childless group with one dashed polyline', () {
    final group = doc.tree[f.separatorGroup]! as GroupNode;
    expect(group.children, isEmpty);
    expect(group.transform.isIdentity, isFalse);
    final leaves = doc.leavesByOwner()[f.separatorGroup]!;
    expect(leaves, [slot(f.separatorLine)]);
    expect(entities.kindAt(leaves.single), EntityKind.polyline);
    expect(entities.linetypeAt(leaves.single), ReservedHandles.dashedLinetype);
  });

  test('everything but the outside line lies inside the sheet', () {
    final sheet = sheetWorldRect(f.page);
    final all = doc.extents;
    expect(all.minX, lessThan(sheet.minX));
    final g = exportFixture();
    g.document.commands.execute(RemoveEntityCommand(g.outsideLine));
    final inside = g.document.extents;
    expect(inside.minX, greaterThan(sheet.minX));
    expect(inside.minY, greaterThan(sheet.minY));
    expect(inside.maxX, lessThan(sheet.maxX));
    expect(inside.maxY, lessThan(sheet.maxY));
    // And nothing reaches the world origin's neighbourhood.
    expect(inside.minX, greaterThan(0));
  });

  test('the outside line is wholly outside the sheet at 1:50 and 1:100', () {
    for (final denominator in [50.0, 100.0]) {
      final g = exportFixture(scaleDenominator: denominator);
      final sheet = sheetWorldRect(g.page);
      final s = g.document.entities.slotOf(g.outsideLine)!;
      final coords =
          g.document.geometry.peek(g.document.entities.geomIndexAt(s)).coords;
      final box = Aabb2.raw(
        math.min(coords[0], coords[2]),
        math.min(coords[1], coords[3]),
        math.max(coords[0], coords[2]),
        math.max(coords[1], coords[3]),
      );
      expect(box.intersects(sheet), isFalse, reason: '1:$denominator');
      // Clear of the sheet by a metre, so no culling slack reaches it.
      final clear = box.maxX < sheet.minX - 1000 ||
          box.minX > sheet.maxX + 1000 ||
          box.maxY < sheet.minY - 1000 ||
          box.minY > sheet.maxY + 1000;
      expect(clear, isTrue, reason: '1:$denominator');
    }
  });
}
