import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:jet_cad_dev_harness/status_bar.dart';
import 'package:jet_cad_dev_harness/ribbon/ribbon_model.dart';

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

  testWidgets('renders nav tools and taps fire their callbacks',
      (tester) async {
    var zoomTaps = 0;
    await tester.pumpWidget(host(StatusBar(
      status: 'ready',
      selection: const [],
      navTools: [
        RibbonTool('Zoom in', LucideIcons.zoomIn, onPressed: () => zoomTaps++),
        const RibbonTool('Pan left', LucideIcons.arrowLeft),
      ],
    )));
    await tester.pumpAndSettle();

    // Icon-only buttons: find by the concrete IconData rather than text.
    final zoomIcon = find
        .byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.zoomIn);
    expect(zoomIcon, findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is Icon && w.icon == LucideIcons.arrowLeft),
        findsOneWidget);

    await tester.tap(zoomIcon);
    await tester.pump();
    expect(zoomTaps, 1);
  });
}
