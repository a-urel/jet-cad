import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  test('CreateResult JSON round-trips', () {
    const result = CreateResult(
      body: BodyId('b1'),
      faces: [FaceId('f2'), FaceId('f3')],
      edges: [EdgeId('e4')],
      vertices: [VertexId('v5')],
      remap: IdRemap({
        EntityId('b0'): [EntityId('b1')],
        EntityId('f0'): <EntityId>[],
      }),
    );
    final restored = CreateResult.fromJson(result.toJson());
    expect(restored.body, const BodyId('b1'));
    expect(restored.faces, const [FaceId('f2'), FaceId('f3')]);
    expect(restored.edges, const [EdgeId('e4')]);
    expect(restored.vertices, const [VertexId('v5')]);
    expect(
        restored.remap.mapping[const EntityId('b0')], const [EntityId('b1')]);
    expect(restored.remap.mapping[const EntityId('f0')], isEmpty);
  });

  test('CreateResult.fromJson tolerates missing remap', () {
    final restored = CreateResult.fromJson({
      'body': 'b1',
      'faces': <Object?>[],
      'edges': <Object?>[],
      'vertices': <Object?>[],
    });
    expect(restored.remap.mapping, isEmpty);
  });

  test('PickResult JSON round-trips and equates', () {
    const result = PickResult(entity: EntityId('f3'), body: BodyId('b1'));
    final restored = PickResult.fromJson(result.toJson());
    expect(restored, result);
    expect(restored.hashCode, result.hashCode);
    expect(restored.entity, const EntityId('f3'));
    expect(restored.body, const BodyId('b1'));
  });

  test('TextureTarget is a RenderTarget', () {
    expect(const TextureTarget(), isA<RenderTarget>());
  });
}
