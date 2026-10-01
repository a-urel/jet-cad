import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/differential.dart';
import '../support/export_fixture.dart';

/// Spec 13 T-2: `omitOwners`, the painter against the reference walk at the
/// page camera. Mutants M-13q (the painter ignores the set), M-13r (the
/// leaf's own handle tested, not its owner) and M-13aa (the walk skips the
/// omitted node's subtree) go red here.
///
/// The painter records into `RecordingDrawSink(shadesDashes: true)`: the
/// fixture has a dashed polyline, which a non-shading sink receives as cut
/// spans while the walk emits it whole. Shading keeps it one polyline
/// bracketed by dash ops, which `flatten` passes over, so the comparison is
/// about what is drawn, not about where the dasher cuts.
void main() {
  final f = exportFixture();
  final doc = f.document;
  final page = pageCamera(f.page, 72 / 25.4);
  final camera = page.camera;
  final viewport = page.size;
  final omitted = {f.separatorGroup, f.outerGroup};

  List<DrawOp> painted(Set<Handle> omitOwners) {
    final index = SpatialIndex(doc);
    final sink = RecordingDrawSink(shadesDashes: true);
    try {
      DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0,
        omitOwners: omitOwners,
      ).paint(sink, camera, viewport);
    } finally {
      index.dispose();
    }
    return sink.ops;
  }

  List<DrawOp> walked(Set<Handle> omitOwners) {
    final sink = RecordingDrawSink();
    referenceWalk(
      doc,
      sink,
      camera,
      viewport,
      DocumentStyleResolver(doc),
      minTextCapPixels: 0,
      omitOwners: omitOwners,
    );
    return sink.ops;
  }

  /// The leaves a recording drew, by the handle each leaf's residual names.
  Set<Handle> drawnLeaves(List<DrawOp> ops) => {
        for (final op in ops)
          if (op is BeginResidualOp && op.debugHandle != Handle.none)
            op.debugHandle,
      };

  /// [leaf]'s points in page pixels, composed from the tree independently of
  /// both routes under test.
  List<Vector2> pagePoints(Handle leaf) {
    final slot = doc.entities.slotOf(leaf)!;
    var placement = Transform2.identity();
    for (var owner = doc.entities.ownerAt(slot);
        owner != doc.rootHandle;
        owner = doc.tree[owner]!.parent) {
      placement = doc.tree[owner]!.transform.multiply(placement);
    }
    final coords = doc.geometry.peek(doc.entities.geomIndexAt(slot)).coords;
    return [
      for (var i = 0; i < coords.length; i += 2)
        camera.worldToScreen(
          placement.transformPoint(Vector2(coords[i], coords[i + 1])),
        ),
    ];
  }

  /// Whether any drawn item has a vertex within a thousandth of a pixel of
  /// one of [points].
  bool drawsAt(List<DrawOp> ops, List<Vector2> points) {
    for (final item in flatten(ops)) {
      for (final p in item.points) {
        for (final q in points) {
          if ((p - q).length < 1e-3) return true;
        }
      }
    }
    return false;
  }

  void expectSameDrawing(List<DrawOp> painter, List<DrawOp> reference) {
    expectPainterSupersetOfReference(painter, reference, viewport);
    // Superset and nothing extra on the page: the page camera's view holds
    // the whole sheet, and the two must draw the same items.
    expect(
      flatten(painter).length,
      flatten(reference).length,
      reason: 'the painter drew ${flatten(painter).length} items and the '
          'reference ${flatten(reference).length}',
    );
  }

  final kept = <String, Handle>{
    'the instance line': f.instanceLine,
    'the instance polyline': f.instancePolyline,
    'the point in the instance': f.pointInInstance,
    '"Yatak Odası"': f.labelBig,
    '"WC"': f.labelWc,
    'the nested group\'s line': f.nestedLine,
    'the outer group\'s instance\'s leaf': f.outerInstanceLeaf,
    'the line': f.line,
    'the closed polyline': f.closedPolyline,
    'the dashed polyline': f.dashed,
    'the arc': f.arc,
    'the circle': f.circle,
    'the fill': f.fill,
    'the fill boundary': f.fillBoundary,
    'the ACI 7 line': f.aci7Line,
  };

  group('with {separator, outer group} omitted', () {
    final painter = painted(omitted);
    final reference = walked(omitted);

    test('the painter and the reference draw the same drawing', () {
      expectSameDrawing(painter, reference);
    });

    for (final (name, ops) in [
      ('the painter', painter),
      ('the reference', reference),
    ]) {
      test('$name draws every leaf not owned by an omitted node', () {
        final drawn = drawnLeaves(ops);
        for (final MapEntry(key: what, value: leaf) in kept.entries) {
          expect(drawn, contains(leaf), reason: '$name lost $what');
        }
      });

      test(
          '$name draws nothing of the separator, the outer group\'s own '
          'line or the outside line', () {
        final drawn = drawnLeaves(ops);
        expect(drawn, isNot(contains(f.separatorLine)));
        expect(drawn, isNot(contains(f.outerGroupLine)));
        expect(drawn, isNot(contains(f.outsideLine)));
        // By position too, so a leaf drawn under another handle is caught.
        expect(drawsAt(ops, pagePoints(f.separatorLine)), isFalse,
            reason: 'at the separator\'s points');
        expect(drawsAt(ops, pagePoints(f.outerGroupLine)), isFalse,
            reason: 'at the outer group line\'s points');
        expect(drawsAt(ops, pagePoints(f.outsideLine)), isFalse,
            reason: 'at the outside line\'s points');
      });
    }
  });

  group('with the default (empty) set', () {
    final painter = painted(const {});
    final reference = walked(const {});

    test('the painter and the reference draw the same drawing', () {
      expectSameDrawing(painter, reference);
    });

    for (final (name, ops) in [
      ('the painter', painter),
      ('the reference', reference),
    ]) {
      test('$name draws the separator and the outer group\'s line', () {
        final drawn = drawnLeaves(ops);
        expect(drawn, containsAll([f.separatorLine, f.outerGroupLine]));
        expect(drawsAt(ops, pagePoints(f.separatorLine)), isTrue);
        expect(drawsAt(ops, pagePoints(f.outerGroupLine)), isTrue);
        // The outside line is off the page whatever the set.
        expect(drawn, isNot(contains(f.outsideLine)));
      });
    }

    test('omitting draws exactly the omitted leaves fewer', () {
      expect(
        drawnLeaves(painter).difference(drawnLeaves(painted(omitted))),
        {f.separatorLine, f.outerGroupLine},
      );
    });
  });

  test('the page viewport is the whole sheet, not a screen', () {
    // Guards the camera this file depends on: A4 landscape at 72/25.4.
    expect(viewport, isA<Size>());
    expect(viewport.width, closeTo(297 * 72 / 25.4, 1e-9));
    expect(viewport.height, closeTo(210 * 72 / 25.4, 1e-9));
  });
}
