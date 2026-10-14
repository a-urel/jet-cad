// A plan's text (spec 2a P4 "The plan file", P5): the engine's JSON with
// the manifest on its root. Loading refuses by code and changes nothing;
// saving writes the manifest without touching the document; an import
// without a manifest gets an empty one.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';
import 'manifest.dart';
import 'plan_format_exception.dart';

const String _manifestType = ManifestComponent.componentTypeId;

/// [text] as a plan document, or a [PlanFormatException] (spec P4): not
/// JSON (`notJson`); no manifest on the root (`noManifest`); a manifest
/// that does not read (`schema`) or whose format is above [kPlanFormat]
/// (`formatTooNew`); anything the engine's decode throws (`schema`).
/// [register] registers the plan's component types (the page, the
/// contract's, the kits'); [diagnostics] receives the engine's load
/// diagnostics, `component.unreadable` included: a component whose factory
/// throws is kept raw and the plan opens (E4, opt-in).
DraftDocument decodePlan(String text,
    {required void Function(ComponentRegistry registry) register,
    required List<Diagnostic> diagnostics,
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all}) {
  final json = _object(text);
  _checkManifest(json);
  try {
    return DraftDocumentCodec.decode(json,
        measurer: measurer,
        permissions: permissions,
        diagnostics: diagnostics,
        registerComponents: register,
        keepUnreadableComponents: true);
  } catch (e) {
    throw PlanFormatException(PlanFormatCode.schema, 'not a plan: $e');
  }
}

Map<String, Object?> _object(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    throw PlanFormatException(PlanFormatCode.notJson, 'not JSON: ${e.message}');
  }
  if (json is! Map<String, Object?>) {
    throw const PlanFormatException(
        PlanFormatCode.notJson, 'not a JSON object');
  }
  return json;
}

/// The root's manifest, read from the raw JSON before anything else.
void _checkManifest(Map<String, Object?> json) {
  final root = json['root'];
  final components = json['components'];
  final byHandle =
      components is Map<String, Object?> ? components[_manifestType] : null;
  final raw = root is int && byHandle is Map<String, Object?>
      ? byHandle['$root']
      : null;
  if (raw is! Map<String, Object?>) {
    throw const PlanFormatException(PlanFormatCode.noManifest,
        'the plan carries no $_manifestType on its root');
  }
  final ManifestComponent manifest;
  try {
    manifest = ManifestComponent.fromJson(raw);
  } catch (e) {
    throw PlanFormatException(
        PlanFormatCode.schema, 'its $_manifestType does not read: $e');
  }
  if (manifest.format > kPlanFormat) {
    throw PlanFormatException(PlanFormatCode.formatTooNew,
        'the plan format ${manifest.format} is newer than $kPlanFormat');
  }
}

/// [d]'s text with the manifest a save writes (spec P4, [manifestToWrite])
/// on its root. [d] is not changed: the manifest in memory stays the one
/// read. The components map is written in the order the engine writes it
/// (type ids sorted, handles ascending), so a plan read and saved again
/// is the same bytes.
String encodePlan(DraftDocument d, KitSet loaded) {
  final json = DraftDocumentCodec.encode(d);
  final components =
      Map<String, Object?>.of(json['components']! as Map<String, Object?>);
  final manifest =
      manifestToWrite(manifestOf(d), usedKitsIn(components), loaded);
  final byHandle = <String, Object?>{
    ...?(components[_manifestType] as Map<String, Object?>?),
    '${d.rootHandle.value}':
        ManifestComponent(format: manifest.format, kits: manifest.kits)
            .toJson(),
  };
  components[_manifestType] = {
    for (final h
        in byHandle.keys.toList()
          ..sort((a, b) => int.parse(a).compareTo(int.parse(b))))
      h: byHandle[h],
  };
  json['components'] = {
    for (final typeId in components.keys.toList()..sort())
      typeId: components[typeId],
  };
  return jsonEncode(json);
}

/// An imported plan's text, with an empty manifest on its root when it has
/// none (spec P5, A17.5), so it opens as plain geometry. [text] itself
/// when it already has one, or when it is JSON but no plan ([decodePlan]
/// then refuses it by its own code). Not JSON: `notJson`.
String ensureManifest(String text) {
  final json = _object(text);
  final root = json['root'];
  final components = json['components'];
  if (root is! int || components is! Map<String, Object?>) return text;
  final byHandle = components[_manifestType];
  if (byHandle is Map<String, Object?> && byHandle.containsKey('$root')) {
    return text;
  }
  components[_manifestType] = <String, Object?>{
    if (byHandle is Map<String, Object?>) ...byHandle,
    '$root': ManifestComponent(kits: const {}).toJson(),
  };
  return jsonEncode(json);
}
