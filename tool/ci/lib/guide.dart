// The host guide's check (spec 14d P2): every code block of
// docs/host-guide.md is in the host probe, so the guide's code is code CI
// resolves, analyses and builds from outside the workspace.

/// The fenced blocks of [markdown] whose info string is [language].
List<String> fencedBlocks(String markdown, String language) {
  final blocks = <String>[];
  final lines = markdown.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() != '```$language') continue;
    final body = <String>[];
    for (i++; i < lines.length && lines[i].trim() != '```'; i++) {
      body.add(lines[i]);
    }
    blocks.add(body.join('\n'));
  }
  return blocks;
}

/// [text] with every run of white space one space: indentation and line
/// breaks are the formatter's, not the guide's.
String collapse(String text) => text.trim().split(RegExp(r'\s+')).join(' ');

/// A pubspec's lines with the repository's URL and the commit left out:
/// the guide names the public URL and the tag's SHA, the probe CI's.
String _pubspecShape(String yaml) => yaml
    .replaceAll(RegExp(r'url: .*'), 'url: URL')
    .replaceAll(RegExp(r'ref: .*'), 'ref: REF');

/// The guide's blocks that are not in the probe: each Dart block must
/// occur in [dart] (the probe's `lib/main.dart`), each YAML block in
/// [yaml] (its `pubspec.yaml.in`), white space collapsed. Returns the
/// first line of each missing block.
List<String> missingBlocks(String guide,
    {required String dart, required String yaml}) {
  final dartText = collapse(dart);
  final yamlText = collapse(_pubspecShape(yaml));
  return [
    for (final block in fencedBlocks(guide, 'dart'))
      if (!dartText.contains(collapse(block)))
        'dart: ${block.trim().split('\n').first}',
    for (final block in fencedBlocks(guide, 'yaml'))
      if (!yamlText.contains(collapse(_pubspecShape(block))))
        'yaml: ${block.trim().split('\n').first}',
  ];
}
