// One problem of a kit (spec K5's PlanKit.validate, K7's conformance): a
// code tests can assert and a message a person can act on.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

enum KitProblemCode {
  // PlanKit.validate (K5).
  badKitId,
  emptyVersion,
  foreignWordId,
  unknownWordId,
  missingEnglish,
  // conformance (K7).
  catalogInvalid,
  notLowerCase,
  keyOutsideKit,
  builtDiffers,
  libraryInvalid,
  libraryKitMismatch,
  snapshotUnreadable,
  snapshotChanged,
  snapshotMissing,
  keyRemoved,
  wordMissing,
  wordUntranslated,
  wordOrphan,
  localeUndeclared,
}

@immutable
final class KitProblem {
  const KitProblem(this.code, this.message);

  final KitProblemCode code;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is KitProblem && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => '${code.name}: $message';
}
