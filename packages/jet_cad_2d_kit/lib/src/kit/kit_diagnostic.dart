// A kit's runtime diagnostic (spec 2a P4): what the plan library reports
// when a kit's code fails, a kit is missing or newer, a letter is taken or a
// symbol library cannot be used. Unlike a KitProblem, never a refusal: the
// plan goes on.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

enum KitDiagnosticCode {
  /// A kit's hook threw: a type's, a tool's, a grip provider's, an
  /// attachment provider's or a section's.
  hookFailed,

  /// A rolled-back edit could not be rolled back; the plan is damaged.
  rollbackFailed,

  /// A damaged plan does not encode and decode; it cannot be saved.
  damagedUnsavable,

  /// A component's `fromJson` threw on load; it is kept raw and its object
  /// is locked.
  componentUnreadable,

  /// A tool's letter is already taken, or is F; the tool has none.
  letterTaken,

  /// A symbol attaches to a kind no loaded kit's provider offers.
  attachmentKindUnoffered,

  /// A symbol library cannot be read or decoded; it is skipped.
  libraryUnreadable,

  /// A symbol library holds another kit's id; it is refused.
  libraryKitMismatch,

  /// A `key@N` an earlier kit already gave; the later one is dropped.
  symbolDuplicate,

  /// The plan names a kit the host did not load; its objects are locked.
  kitMissing,

  /// The plan was saved by a newer version of a loaded kit.
  kitNewer,
}

/// One diagnostic: the kit it concerns, the type, tool, library or object it
/// names ([subject], null for the kit itself), its [code], a message a
/// person can act on, and the [error] caught, if any.
///
/// Equal by kit, subject, code and message; the error is not compared.
@immutable
final class KitDiagnostic {
  const KitDiagnostic({
    required this.kitId,
    this.subject,
    required this.code,
    required this.message,
    this.error,
  });

  final String kitId;
  final String? subject;
  final KitDiagnosticCode code;
  final String message;
  final Object? error;

  @override
  bool operator ==(Object other) =>
      other is KitDiagnostic &&
      other.kitId == kitId &&
      other.subject == subject &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kitId, subject, code, message);

  @override
  String toString() =>
      '${code.name} [$kitId${subject == null ? '' : ' $subject'}]: $message';
}
