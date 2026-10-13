// The host lock's guard (GPU split spec S8): a host that depends on the
// planner must not resolve the GPU renderer, nor anything that brings its
// build hook. Read from the host probe's pubspec.lock, by key.

/// The packages no host's graph may hold: the GPU renderer's own package,
/// `flutter_scene` (whose build hook compiles shaders with the engine's
/// `impellerc`) and what `flutter_scene` brings with it.
const List<String> forbiddenHostPackages = [
  'flutter_scene',
  'flutter_gpu',
  'flutter_gpu_shaders',
  'scene',
  'jet_cad_2d_gpu',
];

/// The keys of the top-level `packages:` map of the pubspec.lock [lock],
/// in the lock's order: exact keys, not text. Throws a [FormatException]
/// when [lock] has no top-level `packages:` key, or lays it out as pub
/// never does (a flow map, a key indented less than the first), so a file
/// that is not a lock cannot pass for a clean one.
List<String> lockPackages(String lock) {
  final lines = lock.split('\n');
  final start = lines.indexWhere((l) => RegExp(r'^packages:').hasMatch(l));
  if (start == -1) {
    throw const FormatException('no top-level "packages:" key');
  }
  // Pub writes the map as a block, or `{}` when it is empty. A flow map's
  // keys would sit on this line, unread: refuse it rather than pass it.
  final inline = lines[start]
      .substring('packages:'.length)
      .split('#')
      .first
      .trim();
  if (inline == '{}') return const [];
  if (inline.isNotEmpty) {
    throw FormatException('a flow map under "packages:": ${lines[start]}');
  }
  final keys = <String>[];
  int? indent;
  for (final line in lines.skip(start + 1)) {
    final content = line.trimLeft();
    if (content.isEmpty || content.startsWith('#')) continue;
    final depth = line.length - content.length;
    if (depth == 0) break; // The next top-level key: the map has ended.
    indent ??= depth;
    if (depth < indent) {
      // Read as a field it would be skipped, and a package with it.
      throw FormatException('a key indented less than the first: $line');
    }
    if (depth != indent) continue; // A package's own fields.
    final key = RegExp(
      r'''^(?:"([^"]*)"|'([^']*)'|([^\s:#'"][^:]*?))\s*:''',
    ).firstMatch(content);
    if (key == null) {
      throw FormatException('not a key under "packages:": $line');
    }
    keys.add(key[1] ?? key[2] ?? key[3]!);
  }
  return keys;
}

/// The [forbiddenHostPackages] that are keys under [lock]'s `packages:`,
/// in the lock's order.
List<String> forbiddenInLock(String lock) => [
  for (final name in lockPackages(lock))
    if (forbiddenHostPackages.contains(name)) name,
];

/// The packages the host probe must take from the commit under test, by
/// its `dependency_overrides` (publishing spec D6): once they are on
/// pub.dev, a dropped override would resolve silently from there.
const List<String> probedFromCommit = [
  'jet_cad_2d',
  'jet_cad_2d_flutter',
  'jet_cad_floor_plan',
  'jet_cad_restaurant_symbols',
];

/// The `source` and the description's `resolved-ref` of the package
/// [name]'s entry in [lock] (keys `source` and `resolved-ref`, each only
/// when present); empty when [lock] has no such package. Throws a
/// [FormatException] as [lockPackages] does.
Map<String, String> lockEntryFields(String lock, String name) {
  if (!lockPackages(lock).contains(name)) return const {};
  final lines = lock.split('\n');
  final start = lines.indexWhere((l) => RegExp('^ +$name:\\s*\$').hasMatch(l));
  final indent = lines[start].length - lines[start].trimLeft().length;
  final fields = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    final content = line.trimLeft();
    if (content.isEmpty) continue;
    final depth = line.length - content.length;
    if (depth <= indent) break; // The next package: the entry has ended.
    final m = RegExp(
      r'^(source|resolved-ref):\s*"?([^"\s]+)"?',
    ).firstMatch(content);
    if (m != null) fields[m[1]!] = m[2]!;
  }
  return fields;
}

/// One message per package of [probedFromCommit] that [lock] does not
/// resolve from git at [ref]: missing, another source, or another
/// resolved ref.
List<String> notFromCommit(String lock, String ref) => [
  for (final name in probedFromCommit)
    if (lockEntryFields(lock, name) case final f
        when f['source'] != 'git' || f['resolved-ref'] != ref)
      f.isEmpty
          ? '$name: not in the lock'
          : '$name: ${f['source']} at ${f['resolved-ref'] ?? 'no ref'}, '
                'not git at $ref',
];
