// The published example (2a spec P7, decision 5): PlanEditor over an empty
// plan with no kit; and the README's code is the example's.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/main.dart';

void main() {
  testWidgets(
      'ED-8 the example shows the editor over an empty plan with no kit '
      '(a positive control)', (tester) async {
    await tester.pumpWidget(const PlanExampleApp());
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlanEditor), findsOneWidget);
    final state =
        tester.state<PlanExampleAppState>(find.byType(PlanExampleApp));
    expect(state.controller.document.entities.liveCount, 0);
    expect(state.controller.missingKits, isEmpty);
    expect(find.byType(PlanSymbolGallery), findsNothing,
        reason: 'no kit, no symbols');
  });

  test('ED-README the README\'s Dart block is the example, whole', () {
    final readme = File('README.md').readAsStringSync();
    final example = File('example/main.dart').readAsStringSync().trim();
    // M-ED-README: the example changed and the README not.
    expect(readme, contains('```dart\n$example\n```'));
  });
}
