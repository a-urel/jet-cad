import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A placement whose four style fields are all non-default.
///
/// Every value is chosen to differ from the field's own default, from
/// `StyleContext.documentRoot`'s value, and from every other field's value —
/// so a round-trip that transposes two keys, or drops one to its default,
/// lands on a number no assertion here expects. `linetypeScale` is 4.0 and
/// not 1.0: this plan's anti-degenerate rule forbids the identity, because
/// the identity is what hid the severed channel for fifty-four fixtures.
InstanceNode styledInstance() => InstanceNode(
      handle: const Handle(300),
      parent: const Handle(1),
      transform: Transform2.translation(17, 23),
      definition: const Handle(200),
      layer: const Handle(100),
      color: const IndexedColor(3),
      lineweight: 211,
      transparency: 137,
      linetype: const Handle(42),
      linetypeScale: 4.0,
    );

void main() {
  test('an instance round-trips all four style fields at non-default values',
      () {
    final node = styledInstance();
    final back = InstanceNode.fromJson(node.toJson());

    expect(back.lineweight, 211);
    expect(back.transparency, 137);
    expect(back.linetype, const Handle(42));
    // A stored value, so the comparison is exact. `Tolerance` is for
    // geometric decisions, never for a number read back off disk.
    expect(back.linetypeScale, 4.0);
    expect(back, node);
  });

  test('the four fields are absent-tolerant and default to the no-op values',
      () {
    // A v5 document's instance node, verbatim: the four keys do not exist.
    final v5 = <String, Object?>{
      'type': 'instance',
      'handle': const Handle(300).toJson(),
      'parent': const Handle(1).toJson(),
      'transform': Transform2.identity().toJson(),
      'visible': true,
      'definition': const Handle(200).toJson(),
      'layer': const Handle(100).toJson(),
      'color': encodeColor(const IndexedColor(3)),
    };
    final back = InstanceNode.fromJson(v5);

    // BYBLOCK, BYBLOCK, BYBLOCK-linetype and the multiplicative identity: the
    // four values that make `contextFor` reproduce its pre-3f.1 behaviour
    // exactly. Any other default silently changes how every existing document
    // renders.
    expect(back.lineweight, kByBlock);
    expect(back.transparency, kByBlock);
    expect(back.linetype, ReservedHandles.byBlockLinetype);
    expect(back.linetypeScale, 1.0);
  });

  test('two instances differing only in linetypeScale are not equal', () {
    // `==` and `hashCode` are the picture cache key's foundation in Plan 3g.
    // A field left out of either makes two different placements collide.
    final a = styledInstance();
    final b = a.copyWith(linetypeScale: 8.0);
    expect(a == b, isFalse);
    expect(a.hashCode == b.hashCode, isFalse);
  });

  test('the schema this build writes is 6', () {
    expect(kSchemaVersion, 6);
  });
}
