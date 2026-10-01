// The symbol library's component (spec 09 D3): what a definition is, in the
// library and, once copied, in a plan. Attached to a definition's handle.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// A symbol's identity and display data, attached to a **definition's
/// handle** (spec 09 D3, R-2): a stable [key] (lower-case dotted, e.g.
/// `bed.double`), the display [name], a [category], [tags] and an integer
/// [version]. The same key and version is reused by a placement, a different
/// version is copied beside it (decision 8).
///
/// Immutable and value-equal, [tags] compared **in order**; [toJson] keys
/// are in a fixed (alphabetical) order. Not a parametric type: it is not in
/// `parametricCatalog`, so the live-object rule and regeneration never see
/// it (spec D1).
///
/// Lower-case [key] and [tags] are the library loader's duty, not enforced
/// here.
class SymbolComponent implements Component {
  static const String componentTypeId = 'jetcad.symbol';

  /// Registers the type. **Once per registry**: `register` replaces the
  /// store for the type, so a second call drops every live symbol
  /// component.
  static void register(ComponentRegistry registry) =>
      registry.register<SymbolComponent>(componentTypeId, fromJson);

  final String key;
  final String name;
  final String category;
  final List<String> tags;
  final int version;

  /// Throws [ArgumentError] (not an `assert`: a release build must refuse
  /// too) when [key] is empty or [version] is below 1. [tags] is copied into
  /// an unmodifiable list.
  SymbolComponent({
    required this.key,
    required this.name,
    required this.category,
    required List<String> tags,
    required this.version,
  }) : tags = List.unmodifiable(tags) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'must be at least 1');
    }
  }

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'category': category,
        'key': key,
        'name': name,
        'tags': tags,
        'version': version,
      };

  static SymbolComponent fromJson(Map<String, Object?> json) => SymbolComponent(
        key: _required(json, 'key') as String,
        name: _required(json, 'name') as String,
        category: _required(json, 'category') as String,
        tags: [for (final t in _required(json, 'tags') as List) t as String],
        version: _required(json, 'version') as int,
      );

  static Object _required(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) throw FormatException('SymbolComponent: missing "$key"');
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is SymbolComponent &&
      other.key == key &&
      other.name == name &&
      other.category == category &&
      other.version == version &&
      _sameTags(other.tags, tags);

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(key, name, category, version, Object.hashAll(tags));

  @override
  String toString() => 'SymbolComponent($key@$version, $name, $category, '
      '${tags.join('/')})';
}
