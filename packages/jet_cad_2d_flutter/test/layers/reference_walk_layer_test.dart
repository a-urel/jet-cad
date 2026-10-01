// Spec 12b D6 (the oracle) and R-18: the differential walk agrees with the
// painter with a hidden layer, with a hidden instance layer and with
// non-ACI-7 layer colours, and — an absolute assertion, so two walks that
// share a mistake cannot agree on it — the hidden layer's handles are in
// neither sink.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/differential.dart';
import '../support/fixtures.dart';
import '../support/layer_fixture.dart';

/// Every handle a sink drew under, read from its residuals.
Set<Handle> drawnHandles(List<DrawOp> ops) => {
      for (final op in ops)
        if (op is BeginResidualOp && !op.debugHandle.isNone) op.debugHandle,
    };

/// Paints [f] with both walks, text never culled (the ATTRIB is small at
/// the fitted zoom), asserts the painter draws a superset of the reference,
/// and returns the handles each drew.
(Set<Handle>, Set<Handle>) compare(LayerFixture f) {
  final camera = ViewportTransform.fit(f.doc.extents, kViewport);
  final painter = paintToRecording(f.doc, camera, 0);
  final reference = referenceToRecording(f.doc, camera, 0);
  expectPainterSupersetOfReference(painter, reference, kViewport);
  return (drawnHandles(painter), drawnHandles(reference));
}

void main() {
  test(
      'the fixture is not degenerate: no ACI 7, no hidden layer 0, every '
      'drawn layer colour distinct', () {
    final f = LayerFixture();
    final colours = [
      for (final h in [ReservedHandles.layerZero, f.a, f.b, f.c])
        f.layer(h).color,
    ];
    expect(colours.skip(1), everyElement(isNot(const IndexedColor(7))));
    expect(colours.skip(1).toSet(), hasLength(3));
    expect(f.layer(ReservedHandles.layerZero).visible, isTrue);
    expect(f.layer(f.c).visible, isFalse);
    for (final h in [f.group, f.object, f.instance, f.nested]) {
      expect(f.doc.tree[h]!.transform.isIdentity, isFalse, reason: h.toHex());
    }
  });

  test(
      'a hidden layer: C\'s line is in neither sink, everything else on the '
      'visible layers is in both, and the walks agree', () {
    final f = LayerFixture();
    final (painted, referenced) = compare(f);
    final visible = {
      f.lineZero, f.lineA, f.lineB, f.rootZero, f.rootA, f.objectChild, //
      f.tableLine, f.tableCircle, f.legLine, f.attrib, f.regionFill,
      f.regionBoundary,
    };
    expect(referenced, containsAll(visible));
    expect(painted, containsAll(visible));
    expect(referenced, isNot(contains(f.lineC)));
    expect(painted, isNot(contains(f.lineC)));
  });

  test(
      'a hidden instance layer: hiding A takes the instance, its contents, '
      'its ATTRIB, the region, the object and A\'s lines out of both sinks',
      () {
    final f = LayerFixture();
    f.doc.commands.execute(SetLayerCommand(f.withState(f.a, visible: false)));
    final (painted, referenced) = compare(f);
    final hidden = {
      f.lineA, f.lineC, f.rootA, f.objectChild, f.tableLine, f.tableCircle, //
      f.legLine, f.attrib, f.regionFill, f.regionBoundary,
    };
    for (final h in hidden) {
      expect(referenced, isNot(contains(h)), reason: 'reference ${h.toHex()}');
      expect(painted, isNot(contains(h)), reason: 'painter ${h.toHex()}');
    }
    final visible = {f.lineZero, f.lineB, f.rootZero};
    expect(referenced, containsAll(visible));
    expect(painted, containsAll(visible));
  });

  test(
      'layer 0 hidden: the instance on A still draws whole, ATTRIB and '
      'nested instance included; layer 0\'s root lines are in neither sink',
      () {
    final f = LayerFixture();
    f.doc.commands
      ..execute(SetCurrentLayerCommand(f.b))
      ..execute(SetLayerCommand(
          f.withState(ReservedHandles.layerZero, visible: false)));
    final (painted, referenced) = compare(f);
    final drawn = {f.tableLine, f.tableCircle, f.legLine, f.attrib, f.rootA};
    expect(referenced, containsAll(drawn));
    expect(painted, containsAll(drawn));
    for (final h in [f.lineZero, f.rootZero, f.lineC]) {
      expect(referenced, isNot(contains(h)), reason: 'reference ${h.toHex()}');
      expect(painted, isNot(contains(h)), reason: 'painter ${h.toHex()}');
    }
  });

  test(
      'an instance moved to the hidden layer leaves both sinks with its '
      'ATTRIB; the region on A stays', () {
    final f = LayerFixture();
    f.doc.commands.execute(SetInstanceLayerCommand(f.instance, f.c));
    final (painted, referenced) = compare(f);
    for (final h in [f.tableLine, f.tableCircle, f.legLine, f.attrib]) {
      expect(referenced, isNot(contains(h)), reason: 'reference ${h.toHex()}');
      expect(painted, isNot(contains(h)), reason: 'painter ${h.toHex()}');
    }
    expect(referenced, containsAll({f.regionFill, f.rootA}));
    expect(painted, containsAll({f.regionFill, f.rootA}));
  });
}
