import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/document/operation.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('MakeBoxOp round-trips through JSON', () {
    final op = MakeBoxOp(
      id: const OpId(1),
      size: const Vec3(10, 20, 30),
      outputs: const [BodyId('b1')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(op.toJson()) as MakeBoxOp;
    expect(restored.id, const OpId(1));
    expect(restored.size, const Vec3(10, 20, 30));
    expect(restored.outputs, const [BodyId('b1')]);
    expect(restored.inputs, isEmpty);
  });

  test('BooleanCombineOp round-trips with remap', () {
    final op = BooleanCombineOp(
      id: const OpId(2),
      a: const BodyId('b1'),
      b: const BodyId('b2'),
      op: BoolOp.cut,
      outputs: const [BodyId('b3')],
      remap: const IdRemap({
        EntityId('b1'): [EntityId('b3')],
        EntityId('f1'): <EntityId>[],
      }),
    );
    final restored = Operation.fromJson(op.toJson()) as BooleanCombineOp;
    expect(restored.op, BoolOp.cut);
    expect(restored.inputs, const [BodyId('b1'), BodyId('b2')]);
    expect(restored.remap.mapping[const EntityId('f1')], isEmpty);
  });

  test('TransformOp preserves the matrix', () {
    final m = Matrix4.identity()..translateByVector3(Vector3(5.0, 0.0, 0.0));
    final op = TransformOp(
      id: const OpId(3),
      bodies: const [BodyId('b1')],
      matrix: m,
      outputs: const [BodyId('b1')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(op.toJson()) as TransformOp;
    expect(restored.matrix.storage, m.storage);
  });

  test('ImportStepOp keeps bytes for replay fallback', () {
    final bytes = Uint8List.fromList(utf8.encode('ISO-10303-21;'));
    final op = ImportStepOp(
      id: const OpId(4),
      stepBytes: bytes,
      outputs: const [BodyId('b1')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(op.toJson()) as ImportStepOp;
    expect(restored.stepBytes, bytes);
  });

  test('ExtrudeOp round-trips through encoded JSON string', () {
    final op = ExtrudeOp(
      id: const OpId(5),
      face: const FaceId('f9'),
      depth: 12.5,
      outputs: const [BodyId('b2')],
      remap: IdRemap.empty,
    );
    final restored = Operation.fromJson(
      (jsonDecode(jsonEncode(op.toJson())) as Map).cast<String, Object?>(),
    ) as ExtrudeOp;
    expect(restored.face, const FaceId('f9'));
    expect(restored.depth, 12.5);
    expect(restored.inputs, const [FaceId('f9')]);
    expect(restored.outputs, const [BodyId('b2')]);
  });

  test('FilletOp round-trips through encoded JSON string', () {
    final op = FilletOp(
      id: const OpId(6),
      edges: const [EdgeId('e1'), EdgeId('e2')],
      radius: 0.5,
      outputs: const [BodyId('b1')],
      remap: const IdRemap({
        EntityId('e1'): [EntityId('f7')],
      }),
    );
    final restored = Operation.fromJson(
      (jsonDecode(jsonEncode(op.toJson())) as Map).cast<String, Object?>(),
    ) as FilletOp;
    expect(restored.edges, const [EdgeId('e1'), EdgeId('e2')]);
    expect(restored.radius, 0.5);
    expect(restored.inputs, const [EdgeId('e1'), EdgeId('e2')]);
    expect(
      restored.remap.mapping[const EntityId('e1')],
      const [EntityId('f7')],
    );
  });

  test('unknown operation type throws FormatException', () {
    expect(
      () => Operation.fromJson({'type': 'loft'}),
      throwsFormatException,
    );
  });
}
