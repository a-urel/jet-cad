// The plan library's API boundary: no shadcn_ui or lucide_icons_flutter type
// is reachable from its barrel. Each fixture is a package of its own in a
// temp directory, resolved against the workspace's package config.
import 'dart:convert';
import 'dart:io';

import 'package:jet_cad_ci/api_boundary.dart';
import 'package:test/test.dart';

/// The workspace's package config, found from the working directory.
File workspaceConfig() {
  for (var d = Directory.current.absolute; ; d = d.parent) {
    final f = File('${d.path}/.dart_tool/package_config.json');
    if (f.existsSync()) return f;
    if (d.parent.path == d.path) throw StateError('no package_config.json');
  }
}

/// A package `fixture` whose barrel is [source], resolved with the
/// workspace's packages (Flutter, shadcn_ui) plus itself.
Future<List<String>> problemsOf(String source) async {
  final dir = Directory.systemTemp.createTempSync('api_boundary_');
  try {
    File('${dir.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/fixture.dart').writeAsStringSync(source);
    final config = workspaceConfig();
    final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    final packages = <Object?>[
      for (final p in json['packages']! as List<Object?>)
        {
          ...(p! as Map<String, Object?>),
          'rootUri': config.uri
              .resolve((p as Map)['rootUri']! as String)
              .toString(),
        },
      {
        'name': 'fixture',
        'rootUri': dir.uri.toString(),
        'packageUri': 'lib/',
        'languageVersion': '3.11',
      },
    ];
    Directory('${dir.path}/.dart_tool').createSync();
    File(
      '${dir.path}/.dart_tool/package_config.json',
    ).writeAsStringSync(jsonEncode({...json, 'packages': packages}));
    final barrel = await resolveBarrel(
      dir.resolveSymbolicLinksSync(),
      'package:fixture/fixture.dart',
    );
    return apiBoundaryProblems(barrel);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

const _imports = '''
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
''';

void main() {
  test('AB1 a clean barrel has no problems', () async {
    expect(
      await problemsOf('''
$_imports
class Clean extends StatelessWidget {
  const Clean({super.key, this.icon, this.build});
  final IconData? icon;
  final Widget Function(BuildContext, List<Widget>)? build;
  Widget helper(Color c) => const SizedBox();
  @override
  Widget build2(BuildContext context) => const SizedBox();
  @override
  Widget build(BuildContext context) => const SizedBox();
}
'''),
      isEmpty,
    );
  });

  test('AB2 a Shad-typed public field is a problem', () async {
    final problems = await problemsOf('''
$_imports
class Holder {
  late ShadThemeData theme;
}
''');
    expect(problems, hasLength(1), reason: '$problems');
    expect(
      problems.single,
      allOf(contains('Holder.theme'), contains('ShadThemeData')),
    );
  });

  test('AB3 a Shad supertype is a problem', () async {
    final problems = await problemsOf('''
$_imports
abstract class Mine extends ShadDecorator {
  Mine();
}
''');
    expect(problems, isNotEmpty, reason: 'premise: ShadDecorator is a class');
    expect(
      problems,
      contains(allOf(startsWith('Mine'), contains('supertype ShadDecorator'))),
    );
  });

  test('AB4 a Shad type argument in a return type is a problem', () async {
    final problems = await problemsOf('''
$_imports
List<ShadOption<int>> f() => [];
''');
    expect(problems, hasLength(1), reason: '$problems');
    expect(
      problems.single,
      allOf(contains('f'), contains('return type'), contains('ShadOption')),
    );
  });

  test('AB5 a private member is not', () async {
    expect(
      await problemsOf('''
$_imports
class Holder {
  // ignore: unused_field
  final ShadThemeData _theme = ShadThemeData();
  ShadThemeData? _make() => null;
  Holder._internal(ShadThemeData t);
  Holder();
}
'''),
      isEmpty,
    );
  });

  test('AB6 the real jet_cad_2d_plan barrel is clean', () async {
    final barrel = await resolveBarrel(
      Directory(
        '../../packages/jet_cad_2d_plan',
      ).absolute.resolveSymbolicLinksSync(),
      'package:jet_cad_2d_plan/jet_cad_2d_plan.dart',
    );
    expect(
      barrel.exportNamespace.definedNames2.length,
      greaterThan(50),
      reason: 'premise: the barrel resolved and exports the library',
    );
    expect(apiBoundaryProblems(barrel), isEmpty);
  });
}
