// The screenshots' check (package READMEs spec D7): pub.dev's rules for a
// pubspec's `screenshots:` (pana's 10 entries and 160 characters, the
// upload's 10-character floor, a normalised path in the archive), the
// spec's budget (1 MB a file, 4 MB a package), and the README's images:
// absolute, pinned to the package's release tag, each one listed, each
// listed one shown. `dart pub publish --dry-run` checks none of this.
import 'package:yaml/yaml.dart';

const int maxEntries = 10;
const int maxFileBytes = 1024 * 1024;
const int maxTotalBytes = 4 * 1024 * 1024;
const Set<String> imageTypes = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

final RegExp _markdownImage = RegExp(r'!\[[^\]]*\]\(([^)\s]+)\)');
final RegExp _htmlImage = RegExp(r'<img\s[^>]*src="([^"]+)"');

/// Every image URL of [markdown], Markdown and HTML.
List<String> imageUrls(String markdown) => [
      for (final m in _markdownImage.allMatches(markdown)) m[1]!,
      for (final m in _htmlImage.allMatches(markdown)) m[1]!,
    ];

/// The engine's README must stay without images (spec Decision 6).
List<String> imagelessProblems(String readme) => [
      for (final url in imageUrls(readme))
        'an image in an imageless README: $url'
    ];

/// The directories a package's `.pubignore` leaves out: only root-anchored
/// directory patterns (`/test/`) are read; any other line is a problem, so
/// the check never guesses at a rule it does not implement.
({Set<String> dirs, List<String> problems}) _ignored(String pubignore) {
  final dirs = <String>{};
  final problems = <String>[];
  for (final raw in pubignore.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final m = RegExp(r'^/([\w.-]+)/$').firstMatch(line);
    if (m == null) {
      problems.add('.pubignore: a pattern this check does not read: $line');
    } else {
      dirs.add(m[1]!);
    }
  }
  return (dirs: dirs, problems: problems);
}

bool _normalised(String path) =>
    path.isNotEmpty &&
    !path.startsWith('/') &&
    !path.contains('\\') &&
    !path.contains(':') &&
    path.split('/').every((s) => s.isNotEmpty && s != '.' && s != '..');

List<String> screenshotProblems({
  required String package,
  required String pubspec,
  required String readme,
  required String pubignore,
  required int? Function(String path) sizeOf,
}) {
  final yaml = loadYaml(pubspec) as YamlMap;
  final version = yaml['version'] as String;
  final entries =
      (yaml['screenshots'] as YamlList?)?.cast<YamlMap>().toList() ??
          const <YamlMap>[];
  final problems = <String>[];
  if (entries.isEmpty) problems.add('no screenshots: entry');
  if (entries.length > maxEntries) {
    problems.add('${entries.length} screenshots: pub.dev shows $maxEntries');
  }
  final ignored = _ignored(pubignore);
  problems.addAll(ignored.problems);
  final paths = <String>[];
  var total = 0;
  for (final e in entries) {
    final path = e['path'] as String;
    final description = (e['description'] as String).trim();
    if (paths.contains(path)) problems.add('$path: listed twice');
    paths.add(path);
    if (description.length < 10 || description.length > 160) {
      problems.add('$path: description of ${description.length} characters '
          '(10 to 160)');
    }
    if (!_normalised(path)) {
      problems.add('$path: not a normalised relative path');
      continue;
    }
    final segments = path.split('/');
    if (segments.any((s) => s.startsWith('.'))) {
      problems.add('$path: under a dot directory, never in the archive');
    }
    if (ignored.dirs.contains(segments.first)) {
      problems.add('$path: left out by .pubignore');
    }
    if (!imageTypes.contains(path.split('.').last.toLowerCase())) {
      problems.add('$path: not an image type pub.dev takes');
    }
    final size = sizeOf(path);
    if (size == null) {
      problems.add('$path: missing');
    } else {
      total += size;
      if (size > maxFileBytes) problems.add('$path: $size bytes, over 1 MB');
    }
  }
  if (total > maxTotalBytes) problems.add('$total bytes in all, over 4 MB');

  final base = 'https://raw.githubusercontent.com/a-urel/jet-cad/'
      '$package-v$version/packages/$package/';
  final shown = <String>{};
  for (final url in imageUrls(readme)) {
    if (!url.startsWith('https://')) {
      problems.add('README: $url is not absolute');
    } else if (!url.startsWith(base)) {
      problems.add('README: $url is not on the tag $package-v$version');
    } else {
      final path = url.substring(base.length);
      shown.add(path);
      if (!paths.contains(path)) problems.add('README: $path not listed');
    }
  }
  for (final path in paths) {
    if (!shown.contains(path)) problems.add('$path: not in the README');
  }
  return problems;
}
