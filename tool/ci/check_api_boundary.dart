// Fails when the plan library's barrel exports a type, or a public member
// of an exported type, that is declared in shadcn_ui or lucide_icons_flutter.
//
//   dart run tool/ci/check_api_boundary.dart
import 'dart:io';

import 'lib/api_boundary.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    stderr.writeln('usage: check_api_boundary.dart');
    exit(2);
  }
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  final barrel = await resolveBarrel(
    '$repo/packages/jet_cad_2d_plan',
    'package:jet_cad_2d_plan/jet_cad_2d_plan.dart',
  );
  final problems = apiBoundaryProblems(barrel);
  if (problems.isEmpty) {
    stdout.writeln(
      'jet_cad_2d_plan: no exported type mentions '
      '${defaultForbiddenPackages.join(' or ')}',
    );
    return;
  }
  for (final p in problems) {
    stderr.writeln('jet_cad_2d_plan: $p');
  }
  exit(1);
}
