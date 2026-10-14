// Spec K8: the Dart code docs/kits.md and the README show is analysed
// example code. Every ```dart block of either document must stand verbatim
// in one file under example/, so a change to one without the other is red.
//
// The rule, exactly: a block is the lines between a line that is exactly
// "```dart" and the next line that is exactly "```". Each of its lines,
// followed by a newline, must appear as one contiguous run of whole lines
// (starting at the file's start or right after a newline) in one
// example/*.dart file. Nothing is ignored or normalised inside the run:
// lines of the file before or after it (such as an example file's leading
// comment, which the documents omit) are simply outside the run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ```dart blocks of [markdown], each as its lines joined by newlines,
/// with a final newline.
List<String> dartBlocks(String markdown) {
  final blocks = <String>[];
  List<String>? open;
  for (final line in markdown.split('\n')) {
    if (open == null) {
      if (line == '```dart') open = [];
    } else if (line == '```') {
      blocks.add(open.map((l) => '$l\n').join());
      open = null;
    } else {
      open.add(line);
    }
  }
  expect(open, isNull, reason: 'a ```dart block is never closed');
  return blocks;
}

/// Whether [block] is a run of whole lines of [file].
bool holdsRun(String file, String block) {
  for (var at = file.indexOf(block);
      at >= 0;
      at = file.indexOf(block, at + 1)) {
    if (at == 0 || file[at - 1] == '\n') return true;
  }
  return false;
}

void main() {
  final examples = {
    for (final f in Directory('example')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')))
      f.path: f.readAsStringSync(),
  };

  // The number of blocks pins the parser to the documents: a parser that
  // finds no block would pass every check below vacuously.
  for (final (doc, count) in [('../../docs/kits.md', 6), ('README.md', 1)]) {
    test('DOC1 every ```dart block of $doc is verbatim in example/', () {
      final blocks = dartBlocks(File(doc).readAsStringSync());
      expect(blocks, hasLength(count));
      for (final block in blocks) {
        // M-DOC1: change one character of a block in the document; M-DOC1e:
        // change one character of the example file the block stands in.
        expect(examples.values.any((file) => holdsRun(file, block)), isTrue,
            reason: 'not in any of ${examples.keys}:\n$block');
      }
    });
  }

  test('DOC2 the run rule: whole lines, contiguous, verbatim', () {
    // A premise check of holdsRun, exempt from the mutation rule.
    const file = '// header\nfinal a = 1;\nfinal b = 2;\n';
    expect(holdsRun(file, 'final a = 1;\nfinal b = 2;\n'), isTrue);
    expect(holdsRun(file, '// header\nfinal a = 1;\n'), isTrue);
    expect(holdsRun(file, 'a = 1;\n'), isFalse); // not a whole line
    expect(holdsRun(file, 'final a = 1;\nfinal b = 3;\n'), isFalse);
    expect(holdsRun(file, 'final a = 1;\n\nfinal b = 2;\n'), isFalse);
  });
}
