// The kit set (spec 2a P4, umbrella A3): the kits a controller loads,
// validated together. Every problem is found before one ArgumentError
// lists them all; a set that passes is held in load order.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

/// The kit ids no kit may take (spec P1): the plan library's own tools are
/// `plan.*`, and the contract's components are `jetcad.*`.
const Set<String> reservedKitIds = {'plan', 'jetcad'};

/// The kits a controller loads, validated by [validateKitSet], in load
/// order.
@immutable
final class KitSet {
  KitSet._(List<PlanKit> kits)
      : kits = List.unmodifiable(kits),
        types = List.unmodifiable([for (final k in kits) ...k.types]),
        tools = List.unmodifiable([for (final k in kits) ...k.tools]),
        _byId = {for (final k in kits) k.id: k},
        _types = {
          for (final k in kits)
            for (final t in k.types) t.id: t,
        };

  /// The kits, in load order.
  final List<PlanKit> kits;

  /// Every kit's types, kit by kit in load order.
  final List<PlanType<Component>> types;

  /// Every kit's tools, kit by kit in load order.
  final List<PlanTool> tools;

  final Map<String, PlanKit> _byId;
  final Map<String, PlanType<Component>> _types;

  /// The kit [id], or null when it is not loaded.
  PlanKit? kitOf(String id) => _byId[id];

  /// The type [typeId] of a loaded kit, or null.
  PlanType<Component>? typeOf(String typeId) => _types[typeId];
}

/// A refused kit set (spec P4): one [ArgumentError] naming every problem,
/// one line each, `  <code>: <message>`.
final class KitSetError extends ArgumentError {
  KitSetError(List<KitProblem> problems)
      : problems = List.unmodifiable(problems),
        super(_describe(problems), 'kits');

  final List<KitProblem> problems;

  static String _describe(List<KitProblem> problems) => [
        'the kit set has ${problems.length} problem(s):',
        for (final p in problems) '  $p',
      ].join('\n');
}

/// [kits] validated together (spec P4), or a [KitSetError] listing, kit by
/// kit in load order: a reserved id; a kit id an earlier kit has; the
/// kit's own `validate()` problems, each prefixed by its id; a type id an
/// earlier kit gave, and a type that both contributes and reads places;
/// a tool id an earlier kit gave. A duplicate inside one kit is that kit's
/// `validate()`'s to report. Symbol keys are not checked here: the symbol
/// loader drops a later kit's duplicate key (spec P2).
KitSet validateKitSet(List<PlanKit> kits) {
  final problems = <KitProblem>[];
  final kitIds = <String>{};
  final typeKits = <String, String>{};
  final toolKits = <String, String>{};
  for (final kit in kits) {
    if (reservedKitIds.contains(kit.id)) {
      problems.add(KitProblem(KitProblemCode.reservedKitId,
          'the kit id "${kit.id}" is reserved for the plan library'));
    }
    if (!kitIds.add(kit.id)) {
      problems.add(KitProblem(
          KitProblemCode.duplicateKit, 'two kits have the id "${kit.id}"'));
    }
    for (final p in kit.validate()) {
      problems.add(KitProblem(p.code, '${kit.id}: ${p.message}'));
    }
    for (final type in kit.types) {
      final first = typeKits.putIfAbsent(type.id, () => kit.id);
      if (first != kit.id) {
        problems.add(KitProblem(
            KitProblemCode.duplicateType,
            'the type "${type.id}" of the kit "${kit.id}" is already the '
            'kit "$first"\'s'));
      }
      final parametric = type.parametric;
      if (parametric.contributesPlace && parametric.readsPlaces) {
        problems.add(KitProblem(
            KitProblemCode.typePlaceConflict,
            '${kit.id}: the type "${type.id}" both contributes places and '
            'reads them, which the engine refuses'));
      }
    }
    for (final tool in kit.tools) {
      final first = toolKits.putIfAbsent(tool.id, () => kit.id);
      if (first != kit.id) {
        problems.add(KitProblem(
            KitProblemCode.duplicateTool,
            'the tool "${tool.id}" of the kit "${kit.id}" is already the '
            'kit "$first"\'s'));
      }
    }
  }
  if (problems.isNotEmpty) throw KitSetError(problems);
  return KitSet._(kits);
}
