// The symbol identity (spec K2): what a definition is, in a library and,
// once copied, in a plan. On a definition's handle. Ported from
// jet_cad_floor_plan's SymbolComponent, with K2's patterns, the attachment
// kinds and the size family as fields (umbrella A5).
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

import 'json_fields.dart';
import 'kit_ids.dart';

/// A symbol's identity and display data, on a definition's handle.
///
/// Immutable and value-equal, [tags] and [attachTo] compared in order;
/// [toJson] keys are alphabetical. Every bad value is an [ArgumentError]
/// from the constructor, named by its field.
@immutable
final class SymbolComponent implements Component {
  /// Throws [ArgumentError] (never an assert: a release build refuses too)
  /// when a field breaks spec K2.
  SymbolComponent({
    required this.key,
    required this.version,
    required this.name,
    required this.category,
    required List<String> tags,
    List<String> attachTo = const [],
    this.family,
  })  : tags = List.unmodifiable(tags),
        attachTo = List.unmodifiable(attachTo) {
    if (!isSymbolKey(key)) {
      throw ArgumentError.value(
          key,
          'key',
          'must be a kit id, then two or more dot-separated segments of '
              'lower-case letters and digits joined by single hyphens');
    }
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'must be at least 1');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'must not be empty');
    }
    final seenTags = <String>{};
    for (final tag in this.tags) {
      if (tag.isEmpty || tag.trim() != tag || tag != tag.toLowerCase()) {
        throw ArgumentError.value(tag, 'tags',
            'must be lower case, not empty, without outer white space');
      }
      if (!seenTags.add(tag)) {
        throw ArgumentError.value(tag, 'tags', 'is repeated');
      }
    }
    final seenKinds = <String>{};
    for (final kind in this.attachTo) {
      if (!isKind(kind)) {
        throw ArgumentError.value(kind, 'attachTo',
            'must be lower-case letters and digits joined by single hyphens');
      }
      if (!seenKinds.add(kind)) {
        throw ArgumentError.value(kind, 'attachTo', 'is repeated');
      }
    }
    final f = family;
    if (f != null && !isKind(f)) {
      throw ArgumentError.value(f, 'family',
          'must be lower-case letters and digits joined by single hyphens');
    }
  }

  static const String componentTypeId = 'jetcad.symbol';

  /// The kit id, then two or more segments: `restaurant.table.rect.four`.
  final String key;

  /// At least 1. A published `key@version` never changes its geometry or
  /// its unit (umbrella A16).
  final int version;

  /// English; a kit's words translate it (K4).
  final String name;

  /// English; a kit's words translate it (K4).
  final String category;

  /// Search words only, lower case, no duplicates. They carry no behaviour.
  final List<String> tags;

  /// The attachment target kinds this symbol attaches to (umbrella A5);
  /// empty for none.
  final List<String> attachTo;

  /// The size family this symbol belongs to, or null.
  final String? family;

  /// `key@version`, the definition's name in a library.
  String get id => '$key@$version';

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'attachTo': attachTo,
        'category': category,
        'family': family,
        'key': key,
        'name': name,
        'tags': tags,
        'version': version,
      };

  /// Throws [FormatException] for a missing or mistyped field, and the
  /// constructor's [ArgumentError] for a value K2 refuses. A field this
  /// build does not know is ignored.
  static SymbolComponent fromJson(Map<String, Object?> json) {
    const t = 'SymbolComponent';
    return SymbolComponent(
      key: field<String>(json, 'key', t),
      version: field<int>(json, 'version', t),
      name: field<String>(json, 'name', t),
      category: field<String>(json, 'category', t),
      tags: stringList(json, 'tags', t),
      attachTo: stringList(json, 'attachTo', t),
      family: field<String?>(json, 'family', t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SymbolComponent &&
      other.key == key &&
      other.version == version &&
      other.name == name &&
      other.category == category &&
      listEquals(other.tags, tags) &&
      listEquals(other.attachTo, attachTo) &&
      other.family == family;

  @override
  int get hashCode => Object.hash(key, version, name, category,
      Object.hashAll(tags), Object.hashAll(attachTo), family);

  @override
  String toString() => 'SymbolComponent($id, $name, $category)';
}
