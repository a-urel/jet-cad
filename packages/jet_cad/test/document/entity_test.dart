import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';

void main() {
  test('typed ids are assignable to EntityId and compare by value', () {
    const EntityId id = BodyId('b1');
    expect(id, const BodyId('b1'));
    expect(id.value, 'b1');
  });

  test('Entity JSON round-trips', () {
    const face = Entity(
      id: FaceId('f1'),
      kind: EntityKind.face,
      name: 'Face',
      parent: BodyId('b1'),
    );
    expect(Entity.fromJson(face.toJson()), face);
  });

  test('IdRemap JSON round-trips including deletions', () {
    const remap = IdRemap({
      EntityId('b1'): [EntityId('b3')],
      EntityId('f2'): <EntityId>[],
    });
    final restored = IdRemap.fromJson(remap.toJson());
    expect(restored.mapping[const EntityId('b1')], [const EntityId('b3')]);
    expect(restored.mapping[const EntityId('f2')], isEmpty);
  });
}
