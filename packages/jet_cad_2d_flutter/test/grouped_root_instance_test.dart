import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/differential.dart';
import 'support/export_fixture.dart';
import 'support/fixtures.dart' show kViewport, paintToRecording;

/// A root-level instance inside a group is placed by the group's transform
/// as well as its own.
///
/// Groups are flattened into the root index, so such an instance arrives on
/// the painter's root instance stream; `_drawInstance` used to descend with
/// `node.transform` alone, dropping every group above it. The differential
/// fixture has no instance under a root-level group, so nothing caught it;
/// spec 13's T-2 (an instance under an omitted group must draw) did.
void main() {
  final f = exportFixture();
  final doc = f.document;
  final camera = ViewportTransform.fit(doc.extents, kViewport);

  /// The ops the painter emitted under [leaf]'s residual, flattened.
  List<DrawnItem> drawnFor(List<DrawOp> ops, Handle leaf) {
    final mine = <DrawOp>[];
    var inside = false;
    for (final op in ops) {
      if (op is BeginResidualOp) inside = op.debugHandle == leaf;
      if (inside) mine.add(op);
      if (op is EndResidualOp) inside = false;
    }
    return flatten(mine);
  }

  test('the outer group\'s instance\'s leaf lands where the tree puts it', () {
    final group = doc.tree[f.outerGroup]! as GroupNode;
    final instance = doc.tree[f.outerGroupInstance]! as InstanceNode;
    expect(instance.parent, f.outerGroup);
    expect(group.transform.isIdentity, isFalse);
    // Composed from the tree here, by neither route under test.
    final placement = group.transform.multiply(instance.transform);
    final slot = doc.entities.slotOf(f.outerInstanceLeaf)!;
    final coords = doc.geometry.peek(doc.entities.geomIndexAt(slot)).coords;
    final expected = [
      for (var i = 0; i < coords.length; i += 2)
        camera.worldToScreen(
          placement.transformPoint(Vector2(coords[i], coords[i + 1])),
        ),
    ];

    final drawn = drawnFor(paintToRecording(doc, camera), f.outerInstanceLeaf);
    expect(drawn, hasLength(1));
    expect(drawn.single.points, hasLength(expected.length));
    for (var i = 0; i < expected.length; i++) {
      expect(
        (drawn.single.points[i] - expected[i]).length,
        lessThan(kScreenTolerance),
        reason: 'vertex $i: ${drawn.single.points[i]} != ${expected[i]}',
      );
    }
  });
}
