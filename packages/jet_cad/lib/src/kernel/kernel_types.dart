import 'dart:typed_data';

import '../document/entity.dart';

/// Immutable 3D vector for the public API (kernel-facing math only).
class Vec3 {
  final double x, y, z;

  const Vec3(this.x, this.y, this.z);

  List<double> toJson() => [x, y, z];

  factory Vec3.fromJson(List<Object?> json) => Vec3(
        (json[0]! as num).toDouble(),
        (json[1]! as num).toDouble(),
        (json[2]! as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

enum BoolOp { fuse, cut, common }

/// Opaque handle to a kernel session. One CadDocument owns exactly one.
extension type const SessionHandle(int value) {}

/// Where a session renders. Plan 1 is headless; Plan 3 adds texture targets.
sealed class RenderTarget {
  const RenderTarget();
}

final class HeadlessTarget extends RenderTarget {
  const HeadlessTarget();
}

/// Opaque whole-session geometry dump (BREP data + id map in the real shim).
class KernelSnapshot {
  final Uint8List bytes;

  const KernelSnapshot(this.bytes);
}

class KernelVersionInfo {
  final String kernelVersion;
  final String occtVersion;

  const KernelVersionInfo({
    required this.kernelVersion,
    required this.occtVersion,
  });
}

/// Kernel-side failure surfaced as a typed exception. Never a crash.
class KernelException implements Exception {
  final String message;

  const KernelException(this.message);

  @override
  String toString() => 'KernelException: $message';
}

/// Topology created or modified by one modeling command.
class CreateResult {
  final BodyId body;
  final List<FaceId> faces;
  final List<EdgeId> edges;
  final List<VertexId> vertices;
  final IdRemap remap;

  const CreateResult({
    required this.body,
    required this.faces,
    required this.edges,
    required this.vertices,
    this.remap = IdRemap.empty,
  });

  Map<String, Object?> toJson() => {
        'body': body.value,
        'faces': [for (final f in faces) f.value],
        'edges': [for (final e in edges) e.value],
        'vertices': [for (final v in vertices) v.value],
        'remap': remap.toJson(),
      };

  factory CreateResult.fromJson(Map<String, Object?> json) => CreateResult(
        body: BodyId(json['body']! as String),
        faces: [for (final f in json['faces']! as List) FaceId(f as String)],
        edges: [for (final e in json['edges']! as List) EdgeId(e as String)],
        vertices: [
          for (final v in json['vertices']! as List) VertexId(v as String),
        ],
        remap: json['remap'] == null
            ? IdRemap.empty
            : IdRemap.fromJson((json['remap']! as Map).cast<String, Object?>()),
      );
}
