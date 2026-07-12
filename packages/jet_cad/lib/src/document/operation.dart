import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../kernel/kernel_types.dart';
import 'entity.dart';

/// One immutable step in a document's timeline. The applied state of a
/// document is always ops[0..head) — see the architecture spec.
sealed class Operation {
  final OpId id;
  final List<EntityId> inputs;
  final List<EntityId> outputs;
  final IdRemap remap;

  Operation({
    required this.id,
    required this.inputs,
    required this.outputs,
    required this.remap,
  });

  Map<String, Object?> toJson();

  Map<String, Object?> _baseJson(String type) => {
        'type': type,
        'id': id.value,
        'inputs': [for (final e in inputs) e.value],
        'outputs': [for (final e in outputs) e.value],
        'remap': remap.toJson(),
      };

  static OpId _id(Map<String, Object?> json) => OpId(json['id']! as int);

  static List<EntityId> _ids(Map<String, Object?> json, String key) =>
      [for (final v in json[key]! as List) EntityId(v as String)];

  static IdRemap _remap(Map<String, Object?> json) =>
      IdRemap.fromJson((json['remap']! as Map).cast<String, Object?>());

  static Operation fromJson(Map<String, Object?> json) {
    final type = json['type']! as String;
    return switch (type) {
      'makeBox' => MakeBoxOp(
          id: _id(json),
          size: Vec3.fromJson(json['size']! as List),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'extrude' => ExtrudeOp(
          id: _id(json),
          face: FaceId(json['face']! as String),
          depth: (json['depth']! as num).toDouble(),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'boolean' => BooleanCombineOp(
          id: _id(json),
          a: BodyId(json['a']! as String),
          b: BodyId(json['b']! as String),
          op: BoolOp.values.byName(json['op']! as String),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'fillet' => FilletOp(
          id: _id(json),
          edges: [for (final e in json['edges']! as List) EdgeId(e as String)],
          radius: (json['radius']! as num).toDouble(),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'transform' => TransformOp(
          id: _id(json),
          bodies: [
            for (final b in json['bodies']! as List) BodyId(b as String),
          ],
          matrix: Matrix4.fromList([
            for (final v in json['matrix']! as List) (v as num).toDouble(),
          ]),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      'importStep' => ImportStepOp(
          id: _id(json),
          stepBytes: base64Decode(json['stepBytes']! as String),
          outputs: _ids(json, 'outputs'),
          remap: _remap(json),
        ),
      _ => throw FormatException('unknown operation type: $type'),
    };
  }
}

final class MakeBoxOp extends Operation {
  final Vec3 size;

  MakeBoxOp({
    required super.id,
    required this.size,
    required super.outputs,
    required super.remap,
  }) : super(inputs: const []);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('makeBox'), 'size': size.toJson()};
}

final class ExtrudeOp extends Operation {
  final FaceId face;
  final double depth;

  ExtrudeOp({
    required super.id,
    required this.face,
    required this.depth,
    required super.outputs,
    required super.remap,
  }) : super(inputs: [face]);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('extrude'), 'face': face.value, 'depth': depth};
}

final class BooleanCombineOp extends Operation {
  final BodyId a;
  final BodyId b;
  final BoolOp op;

  BooleanCombineOp({
    required super.id,
    required this.a,
    required this.b,
    required this.op,
    required super.outputs,
    required super.remap,
  }) : super(inputs: [a, b]);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('boolean'), 'a': a.value, 'b': b.value, 'op': op.name};
}

final class FilletOp extends Operation {
  final List<EdgeId> edges;
  final double radius;

  FilletOp({
    required super.id,
    required this.edges,
    required this.radius,
    required super.outputs,
    required super.remap,
  }) : super(inputs: List<EntityId>.from(edges));

  @override
  Map<String, Object?> toJson() => {
        ..._baseJson('fillet'),
        'edges': [for (final e in edges) e.value],
        'radius': radius,
      };
}

final class TransformOp extends Operation {
  final List<BodyId> bodies;
  final Matrix4 matrix;

  TransformOp({
    required super.id,
    required this.bodies,
    required this.matrix,
    required super.outputs,
    required super.remap,
  }) : super(inputs: List<EntityId>.from(bodies));

  @override
  Map<String, Object?> toJson() => {
        ..._baseJson('transform'),
        'bodies': [for (final b in bodies) b.value],
        'matrix': matrix.storage.toList(),
      };
}

final class ImportStepOp extends Operation {
  final Uint8List stepBytes;

  ImportStepOp({
    required super.id,
    required this.stepBytes,
    required super.outputs,
    required super.remap,
  }) : super(inputs: const []);

  @override
  Map<String, Object?> toJson() =>
      {..._baseJson('importStep'), 'stepBytes': base64Encode(stepBytes)};
}
