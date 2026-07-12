import 'cad_document.dart';

/// JSON document format. The header carries schemaVersion plus the kernel
/// and OCCT versions that produced the file (spec: recorded from day 1).
class CadDocumentCodec {
  static const int schemaVersion = 1;

  static Map<String, Object?> encode(CadDocument doc) => {
        'schemaVersion': schemaVersion,
        'kernelVersion': doc.kernelVersions.kernelVersion,
        'occtVersion': doc.kernelVersions.occtVersion,
        'head': doc.head,
        'ops': [for (final op in doc.operations) op.toJson()],
        'entities': [for (final e in doc.entities.values) e.toJson()],
      };
}
