// A plan the library refuses to open or save (spec 2a P4): a
// FormatException, as today's load throws (floor_plan_controller.dart:
// 1192-1203), with a code a host can test.

/// Why a plan was refused.
enum PlanFormatCode {
  /// The plan carries no `jetcad.manifest` on its root.
  noManifest,

  /// The manifest's format is above the one this library writes.
  formatTooNew,

  /// The engine's schema check refused it, or its manifest does not read.
  schema,

  /// The text is not a JSON object.
  notJson,

  /// A damaged plan whose encoding does not decode again (Task 11).
  damagedUnsavable,
}

/// A refused plan. A [FormatException], so a host that catches today's
/// keeps working.
final class PlanFormatException implements FormatException {
  const PlanFormatException(this.code, this.message);

  final PlanFormatCode code;

  @override
  final String message;

  /// Not kept: a plan's text can be megabytes.
  @override
  Object? get source => null;

  @override
  int? get offset => null;

  @override
  String toString() => 'PlanFormatException(${code.name}): $message';
}
