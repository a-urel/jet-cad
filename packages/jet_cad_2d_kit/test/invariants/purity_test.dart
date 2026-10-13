// Spec K1: the authoring library and every model file are pure Dart. The
// walker is tested on its own fixtures first, so a walker that reads
// nothing cannot pass P1 vacuously.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/import_walker.dart';

/// A throw-away package tree: path → text.
String tree(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('kit_purity_').path;
  for (final MapEntry(key: path, value: text) in files.entries) {
    File('$root/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  addTearDown(() => Directory(root).deleteSync(recursive: true));
  return root;
}

void main() {
  test(
      'P1 lib/authoring.dart and every file under lib/src/model reach no '
      'Flutter, dart:ui or dart:io, and reach every authoring file', () {
    final model = dartFilesUnder('lib/src/model');
    final walk =
        walkImports('.', 'jet_cad_2d_kit', ['lib/authoring.dart', ...model]);
    expect(walk.violations, isEmpty);
    expect(walk.visited, contains('lib/authoring.dart'));
    for (final f in [...model, ...dartFilesUnder('lib/src/authoring')]) {
      expect(walk.visited, contains(f), reason: '$f is not reached');
    }
  });

  test('P2 a Flutter import two hops away is found', () {
    final root = tree({
      'lib/authoring.dart': "export 'src/model/a.dart';\n",
      'lib/src/model/a.dart': "import 'b.dart';\n",
      'lib/src/model/b.dart': "import 'package:flutter/foundation.dart';\n",
    });
    final walk = walkImports(root, 'kit', ['lib/authoring.dart']);
    expect(walk.violations,
        ['lib/src/model/b.dart: package:flutter/foundation.dart']);
    expect(walk.visited, {
      'lib/authoring.dart',
      'lib/src/model/a.dart',
      'lib/src/model/b.dart',
    });
  });

  test('P3 dart:io, dart:ui and an own-package import of an impure file', () {
    final root = tree({
      'lib/a.dart': "import 'dart:io';\nimport 'package:kit/src/b.dart';\n",
      'lib/src/b.dart': "import 'dart:ui' as ui;\n",
    });
    expect(walkImports(root, 'kit', ['lib/a.dart']).violations,
        ['lib/a.dart: dart:io', 'lib/src/b.dart: dart:ui']);
  });

  test('P4 the allowed libraries and packages pass', () {
    final root = tree({
      'lib/a.dart': "import 'dart:convert';\nimport 'dart:math' as math;\n"
          "import 'package:jet_cad_2d/jet_cad_2d.dart';\n"
          "import 'package:meta/meta.dart';\n"
          "import 'package:vector_math/vector_math_64.dart' show Vector2;\n"
          "import '../lib/b.dart';\n",
      'lib/b.dart': "import 'dart:typed_data';\n",
    });
    final walk = walkImports(root, 'kit', ['lib/a.dart']);
    expect(walk.violations, isEmpty);
    expect(walk.visited, {'lib/a.dart', 'lib/b.dart'});
  });

  test('P6 a comment between the keyword and the URI hides nothing', () {
    // The PR #11 review: the directives are parsed, not matched. M-P6: the
    // former regex (`import\\s+` does not reach past a comment) reads none.
    final root = tree({
      'lib/a.dart': "import/*c*/'package:flutter/widgets.dart';\n"
          "export // c\n  'dart:io';\n",
    });
    expect(walkImports(root, 'kit', ['lib/a.dart']).violations, [
      'lib/a.dart: package:flutter/widgets.dart',
      'lib/a.dart: dart:io',
    ]);
  });

  test('P7 a commented-out directive and a directive-shaped string are none',
      () {
    // M-P7: the former regex reports both lines (each starts a line).
    final root = tree({
      'lib/a.dart': "import 'dart:math';\n"
          "/*\nimport 'package:flutter/widgets.dart';\n*/\n"
          "const text = '''\nexport 'dart:io';\n''';\n",
    });
    expect(walkImports(root, 'kit', ['lib/a.dart']).violations, isEmpty);
  });

  test('P8 a part is followed', () {
    // M-P8: drop the part directive (b.dart is not visited).
    final root = tree({
      'lib/a.dart': "part 'src/b.dart';\n",
      'lib/src/b.dart': "part of '../a.dart';\n",
    });
    final walk = walkImports(root, 'kit', ['lib/a.dart']);
    expect(walk.visited, {'lib/a.dart', 'lib/src/b.dart'});
    expect(walk.violations, isEmpty);
  });

  test("P5 a conditional import's second URI is read", () {
    // M-P5: drop the configurations (only the first URI is read).
    final root = tree({
      'lib/a.dart': "import 'b.dart'\n"
          "    if (dart.library.io) 'package:flutter/widgets.dart';\n",
      'lib/b.dart': '',
    });
    expect(walkImports(root, 'kit', ['lib/a.dart']).violations,
        ['lib/a.dart: package:flutter/widgets.dart']);
  });
}
