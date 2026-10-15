// One problem of a kit (spec K5's PlanKit.validate, K7's conformance, 2a's
// kit set): a code tests can assert and a message a person can act on.
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
  // The code side and the kit set (spec 2a P4, contract R4): PlanKit.validate
  // and conformance report the type and tool ones, the plan library's
  // kit-set validation the others.
  duplicateKit,
  duplicateType,
  duplicateTool,
  reservedKitId,
  typeOutsideKit,
  toolOutsideKit,
  typePlaceConflict,

  // Spec 2b S4: conformance, a unit kind the contract does not name with no
  // English `unit:<kit>/<kind>` word.
  unitKindWord,

  // Spec 3a C1.1: PlanKit.validate, a tool's settings holding a spec that
  // reads an object (a TextDisplay, a LengthProperty with a range).
  settingsNeedObject,
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
