// Spec 2a P3: the attachment value types. A query and an answer never change
// after they are made, and refuse what no provider can use.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final Transform2 turned =
    Transform2.translation(1520.5, -640.25).multiply(Transform2.rotation(0.6));

AttachmentQuery query({
  Vector2? pointer,
  double capture = 120.5,
  double edgeCapture = 40.25,
  Set<Handle> exclude = const {Handle(5100)},
  Attachment? keep,
}) =>
    AttachmentQuery(
      footprint: const Aabb2.raw(-450.5, -300.25, 450.5, 300.25),
      current: turned,
      pointer: pointer ?? Vector2(1610.75, -580.5),
      capture: capture,
      edgeCapture: edgeCapture,
      mirrored: true,
      mayRotate: false,
      exclude: exclude,
      keep: keep,
    );

Matcher refusedOn(String name) =>
    throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name));

void main() {
  test('PT20 a query copies its pointer and its exclusions', () {
    final pointer = Vector2(1610.75, -580.5);
    final exclude = {const Handle(5100)};
    final q = query(pointer: pointer, exclude: exclude);
    pointer.x = 0;
    exclude.add(const Handle(5200));
    // M-PT20a: keep the caller's vector. M-PT20b: keep the caller's set.
    expect(q.pointer, Vector2(1610.75, -580.5));
    expect(q.exclude, {const Handle(5100)});
    expect(() => q.exclude.add(const Handle(5300)), throwsUnsupportedError);
    expect(q.mirrored, isTrue);
    expect(q.mayRotate, isFalse);
    expect(q.keep, isNull);
    // M-PT20c (final review): `pointer` handing out the query's own vector:
    // a provider that moves the vector it read moves the query for the
    // next provider.
    q.pointer.x = -9999.5;
    expect(q.pointer, Vector2(1610.75, -580.5));
  });

  test('PT21 a query refuses a capture it cannot use', () {
    // M-PT21a: drop the capture check. M-PT21b: drop the pointer check.
    expect(() => query(capture: -0.5), refusedOn('capture'));
    expect(() => query(capture: double.nan), refusedOn('capture'));
    expect(() => query(edgeCapture: double.infinity), refusedOn('edgeCapture'));
    expect(() => query(pointer: Vector2(double.nan, 2)), refusedOn('pointer'));
    expect(query(capture: 0, edgeCapture: 0).capture, 0);
  });

  test('PT22 an answer copies its marker and refuses non-finite values', () {
    final marker = Vector2(1702.5, -515.25);
    final a = Attachment(transform: turned, marker: marker, token: 'run 3');
    marker.y = 0;
    // M-PT22a: keep the caller's vector.
    expect(a.marker, Vector2(1702.5, -515.25));
    expect(a.token, 'run 3');
    expect(query(keep: a).keep, same(a));
    // M-PT22b: drop the marker check. M-PT22c: drop the transform check.
    expect(
        () => Attachment(
            transform: turned, marker: Vector2(double.infinity, 1), token: 1),
        refusedOn('marker'));
    expect(
        () => Attachment(
            transform: Transform2(1, 0, 0, 1, double.nan, 0),
            marker: Vector2(1, 1),
            token: 1),
        refusedOn('transform'));
  });
}
