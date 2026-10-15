// A kit's descriptor (spec K5, grown by spec 2a P1): its symbols, its
// parametric types, its tools, its attachment providers and its words.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:meta/meta.dart';

import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';
import 'attachment.dart';
import 'plan_services.dart';
import 'plan_tool.dart';
import 'plan_type.dart';
import 'properties.dart';
import 'symbol_library_source.dart';

@immutable
final class PlanKit {
  const PlanKit({
    required this.id,
    required this.version,
    this.symbols = const [],
    this.types = const [],
    this.tools = const [],
    this.attachments = const [],
    this.names = KitNames.empty,
  });

  /// A kit id (K2): the first segment of the kit's keys, type and tool ids.
  final String id;

  /// The kit package's version, for the plan manifest.
  final String version;

  final List<SymbolLibrarySource> symbols;
  final List<PlanType<Component>> types;
  final List<PlanTool> tools;

  /// Made once per document (spec 2a P1, lifetimes).
  final List<AttachmentProvider Function(PlanServices)> attachments;

  final KitNames names;

  /// Every property word id of the kit without its `property:` prefix, in
  /// declaration order: `<type id>.<spec id>` for each type's specs,
  /// `<tool id>.<spec id>` for each tool's settings, and for a choice also
  /// `<owner id>.<spec id>.<value>` per value. Pass it to `conformance`.
  List<String> get propertyIds => [
        for (final type in types) ..._specIds(type.id, type.properties),
        for (final tool in tools)
          if (tool.settings case final settings?)
            ..._specIds(tool.id, settings.specs),
      ];

  /// The descriptor's problems: a bad id, an empty version, a word under
  /// another kit's id or in no known namespace (a `category:` or `unit:` word
  /// names the kit before its `/`); a type or tool id that is not
  /// `<this kit's id>.<name>` or is repeated; a word with no stored English
  /// missing from English, for every word a type, tool or property needs.
  /// A tool's setting that reads an object (spec 3a C1.1).
  /// Empty when sound. Problems across kits are the plan library's.
  List<KitProblem> validate() {
    final problems = <KitProblem>[];
    if (!isKitId(id)) {
      problems.add(KitProblem(
          KitProblemCode.badKitId,
          '"$id" is not a kit id: a lower-case letter, then lower-case '
          'letters and digits'));
    }
    if (version.trim().isEmpty) {
      problems.add(KitProblem(
          KitProblemCode.emptyVersion, 'the kit "$id" has no version'));
    }
    // Word ids under this kit that need an English word, in order.
    final needEnglish = <String>{};
    for (final MapEntry(key: locale, value: words) in names.words.entries) {
      for (final wordId in words.keys) {
        final colon = wordId.indexOf(':');
        final namespace = colon < 0 ? '' : wordId.substring(0, colon);
        final rest = wordId.substring(colon + 1);
        var foreign = false;
        switch (namespace) {
          case 'category' || 'unit':
            final slash = rest.indexOf('/');
            foreign = slash < 0 || rest.substring(0, slash) != id;
          case 'symbol' || 'tool' || 'type' || 'property':
            foreign = !rest.contains('.') || kitOfKey(rest) != id;
            if (!foreign && namespace != 'symbol') needEnglish.add(wordId);
          default:
            problems.add(KitProblem(KitProblemCode.unknownWordId,
                '$locale: "$wordId" is in no known namespace'));
        }
        if (foreign) {
          problems.add(KitProblem(KitProblemCode.foreignWordId,
              '$locale: "$wordId" is not under the kit "$id"'));
        }
      }
    }
    bool declared(String what, String declaredId, Set<String> seen,
        KitProblemCode outside, KitProblemCode twice) {
      if (!isCodeId(declaredId) || kitOfKey(declaredId) != id) {
        problems.add(KitProblem(outside,
            'the $what "$declaredId" is not "$id.<name>" (lower-case segments)'));
        return false;
      }
      if (!seen.add(declaredId)) {
        problems.add(KitProblem(twice, 'the $what "$declaredId" is repeated'));
        return false;
      }
      needEnglish.add('$what:$declaredId');
      return true;
    }

    final typeIds = <String>{};
    for (final type in types) {
      if (declared('type', type.id, typeIds, KitProblemCode.typeOutsideKit,
          KitProblemCode.duplicateType)) {
        for (final p in _specIds(type.id, type.properties)) {
          needEnglish.add('property:$p');
        }
      }
    }
    final toolIds = <String>{};
    for (final tool in tools) {
      if (declared('tool', tool.id, toolIds, KitProblemCode.toolOutsideKit,
              KitProblemCode.duplicateTool) &&
          tool.settings != null) {
        for (final p in _specIds(tool.id, tool.settings!.specs)) {
          needEnglish.add('property:$p');
        }
      }
      // Spec 3a C1.1: a tool's settings are bound with no object.
      for (final spec
          in tool.settings?.specs ?? const <PropertySpec<Object>>[]) {
        if (spec.needsObject) {
          problems.add(KitProblem(
              KitProblemCode.settingsNeedObject,
              'the tool "${tool.id}"\'s setting "${spec.id}" reads the object '
              'it is shown for (a TextDisplay or a range): a tool\'s '
              'settings have none'));
        }
      }
    }
    final english = names.words[KitNames.english] ?? const <String, String>{};
    for (final wordId in needEnglish) {
      if (!english.containsKey(wordId)) {
        problems.add(KitProblem(
            KitProblemCode.missingEnglish, '"$wordId" has no English word'));
      }
    }
    return problems;
  }
}

List<String> _specIds(String owner, List<PropertySpec<Object?>> specs) => [
      for (final spec in specs) ...[
        '$owner.${spec.id}',
        if (spec case ChoiceProperty(:final values))
          for (final v in values)
            '$owner.${spec.id}.${ChoiceProperty.segmentOf(v)}',
      ],
    ];
