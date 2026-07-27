import 'package:meta/meta.dart';

import 'handle.dart';
import 'list_equality.dart';

enum DiagnosticSeverity {
  /// Informational; nothing was changed or dropped.
  info,

  /// Something was unexpected but fully representable.
  warning,

  /// Data could not be represented and was approximated or dropped. Every
  /// exporter enumerates these: loss is declared, never discovered.
  loss,

  /// The operation failed.
  error,
}

/// A structured report from the engine or from a format adapter.
///
/// Lives in the core package because the engine raises diagnostics itself —
/// cycle detection, degraded fills — and every adapter reuses the type rather
/// than inventing its own.
@immutable
class Diagnostic {
  final DiagnosticSeverity severity;

  /// Stable and machine-matchable, so tests and callers can assert on a
  /// specific condition without matching prose.
  final String code;

  final String message;

  /// What the diagnostic concerns. May be empty.
  final List<Handle> handles;

  /// Adapter-defined position within the source, such as a line or byte
  /// offset. The engine never interprets it.
  final String? sourceLocation;

  const Diagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.handles = const [],
    this.sourceLocation,
  });

  Map<String, Object?> toJson() => {
        'severity': severity.name,
        'code': code,
        'message': message,
        if (handles.isNotEmpty)
          'handles': [for (final h in handles) h.toJson()],
        if (sourceLocation != null) 'sourceLocation': sourceLocation,
      };

  @override
  bool operator ==(Object other) =>
      other is Diagnostic &&
      other.severity == severity &&
      other.code == code &&
      other.message == message &&
      other.sourceLocation == sourceLocation &&
      listEquals(other.handles, handles);

  @override
  int get hashCode => Object.hash(
        severity,
        code,
        message,
        sourceLocation,
        Object.hashAll(handles),
      );

  @override
  String toString() => '[${severity.name}] $code: $message';
}
