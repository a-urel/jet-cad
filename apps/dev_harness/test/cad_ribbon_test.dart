import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:jet_cad_dev_harness/ribbon/ribbon_model.dart';
import 'package:jet_cad_dev_harness/ribbon/cad_ribbon.dart';

void main() {
  Widget host(Widget child) => ShadApp(
        theme: ShadThemeData(
          colorScheme: const ShadZincColorScheme.dark(),
          brightness: Brightness.dark,
        ),
        home: child,
      );

  testWidgets('renders tab titles and quick actions', (tester) async {
    await tester.pumpWidget(host(const CadRibbon(
      tabs: [
        RibbonTab('Model', [
          RibbonGroup('Primitives', [RibbonTool('Box', LucideIcons.box)]),
        ]),
        RibbonTab('View', []),
      ],
      quickActions: [RibbonTool('Undo', LucideIcons.undo2)],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Model'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Primitives'), findsOneWidget);
    expect(find.text('Box'), findsWidgets); // label in the tool button
  });

  testWidgets('tapping a live tool fires its callback', (tester) async {
    var boxTaps = 0;
    await tester.pumpWidget(host(CadRibbon(
      tabs: [
        RibbonTab('Model', [
          RibbonGroup('Primitives', [
            RibbonTool('Box', LucideIcons.box, onPressed: () => boxTaps++),
          ]),
        ]),
      ],
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Box'));
    await tester.pump();
    expect(boxTaps, 1);
  });

  testWidgets('tapping a decorative tool routes to onDecorative',
      (tester) async {
    String? decorative;
    await tester.pumpWidget(host(CadRibbon(
      tabs: [
        RibbonTab('Model', [
          RibbonGroup(
              'Features', [const RibbonTool('Extrude', LucideIcons.layers)]),
        ]),
      ],
      onDecorative: (label) => decorative = label,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extrude'));
    await tester.pump();
    expect(decorative, 'Extrude');
  });
}
