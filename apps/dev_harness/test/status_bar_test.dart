import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:jet_cad_dev_harness/status_bar.dart';

void main() {
  Widget host(Widget child) => ShadApp(
        theme: ShadThemeData(
          colorScheme: const ShadZincColorScheme.dark(),
          brightness: Brightness.dark,
        ),
        home: child,
      );

  testWidgets('shows status and empty-selection placeholder', (tester) async {
    await tester
        .pumpWidget(host(const StatusBar(status: 'ready', selection: [])));
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
    expect(find.textContaining('—'), findsOneWidget);
  });

  testWidgets('joins selection ids', (tester) async {
    await tester.pumpWidget(
        host(const StatusBar(status: 'ready', selection: ['12', '13'])));
    await tester.pumpAndSettle();
    expect(find.textContaining('12, 13'), findsOneWidget);
  });
}
