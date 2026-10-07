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
  final inline =
      lines[start].substring('packages:'.length).split('#').first.trim();
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
    final key = RegExp(r'''^(?:"([^"]*)"|'([^']*)'|([^\s:#'"][^:]*?))\s*:''')
        .firstMatch(content);
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
