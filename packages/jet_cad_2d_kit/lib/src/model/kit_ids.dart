// The identifier patterns of the kit contract (spec K2, umbrella A7).
//
// Pure Dart: no Flutter, no dart:io.

final RegExp _kitId = RegExp(r'^[a-z][a-z0-9]*$');
final RegExp _kind = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final RegExp _key =
    RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*){2,}$');
final RegExp _codeId = RegExp(r'^[a-z][a-z0-9]*(\.[a-z0-9]+(-[a-z0-9]+)*)+$');

/// Whether [id] is a kit id: a lower-case letter, then lower-case letters
/// and digits. No dot and no hyphen: it is the first segment of every key,
/// type id and tool id.
bool isKitId(String id) => _kitId.hasMatch(id);

/// Whether [kind] is a target kind, a size family or a unit kind: lower-case
/// letters and digits joined by single hyphens.
bool isKind(String kind) => _kind.hasMatch(kind);

/// Whether [key] is a symbol key: a kit id, then two or more dot-separated
/// segments, each lower-case letters and digits joined by single hyphens.
bool isSymbolKey(String key) => _key.hasMatch(key) && isKitId(kitOfKey(key));

/// Whether [id] is a type id or a tool id (spec 2a P1): a kit id, then one
/// or more dot-separated segments of lower-case letters and digits joined by
/// single hyphens. `architecture.wall`, `restaurant.booth.corner`.
bool isCodeId(String id) => _codeId.hasMatch(id);

/// The first dot-separated segment of [id] (a key, a type id or a tool id):
/// its kit. [id] itself when it holds no dot.
String kitOfKey(String id) {
  final dot = id.indexOf('.');
  return dot < 0 ? id : id.substring(0, dot);
}
