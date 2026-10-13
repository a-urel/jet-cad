// The published example (spec D3): it shows the planner over an empty
// plan with the furniture library loaded from the package's own asset.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';

void main() {
  testWidgets('the example shows the planner with its furniture library',
      (tester) async {
    await tester.pumpWidget(const FloorPlanExampleApp());
    await tester.pumpAndSettle();
    expect(find.byType(FloorPlanView), findsOneWidget);

    final state = tester
        .state<FloorPlanExampleAppState>(find.byType(FloorPlanExampleApp));
    // The asset read ends outside the test's fake-async zone.
    await tester.runAsync(state.symbols.load);
    await tester.pump();
    final library = state.symbols.state;
    expect(library, isA<SymbolLibraryReady>(),
        reason: 'the furniture library is read from the package asset');
    expect((library as SymbolLibraryReady).library.entries, isNotEmpty);
  });
}
