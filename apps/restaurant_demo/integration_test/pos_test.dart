// POS1, the restaurant demo on the real macOS binary (sub-project 4a, Task 9):
// the Salon opened, the Service, statuses on three tables, two tables merged,
// a POS id linked, the service layout kept, a table moved and the layout put
// back, a PNG exported through the demo's own bar into a temporary directory,
// and the screen captured through a `RepaintBoundary`.
//
// Run: cd apps/restaurant_demo &&
//   flutter test integration_test/pos_test.dart -d macos \
//     --dart-define=POS_OUT=<dir>
// The screenshot goes to the directory named by `POS_OUT` when given, else
// the temporary directory (the macOS sandbox lets the app write only inside
// its container; the path is printed as `POS_PNG`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/main.dart';

import '../test/support/demo_rig.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'POS1 Salon, Service, statuses, a merge, a POS id, the layout kept and '
      'put back, a PNG export and a screenshot', (tester) async {
    await ensurePlanFonts();
    registerFontLicences();
    final dir = Directory.systemTemp.createTempSync('restaurant_demo_pos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final shot = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(RepaintBoundary(key: shot, child: const RestaurantDemo()));
    await tester.pumpAndSettle();
    final demo = tester.state<DemoHomeState>(find.byType(DemoHome));
    final c = demo.area.controller;

    // The Salon, opened clean with its 11 tables.
    expect(demo.area.name, 'Salon');
    expect(c.units.map((u) => u.label), [for (var n = 1; n <= 11; n++) '$n']);
    expect(c.dirty.value, isFalse);

    // A POS id linked in the design: "Link tables" writes <area>-<number>.
    await press(tester, 'link-tables');
    expect({
      for (final d in c.unitDetails) d.unit.label: d.data['id'],
    }, {
      for (var n = 1; n <= 11; n++) '$n': 'salon-$n',
    });

    // Service: statuses on three tables.
    await press(tester, 'mode-service');
    expect(c.mode.value, PlanMode.service);
    for (final (n, key, caption) in [
      ('1', 'status-eating', 'Eating'),
      ('2', 'status-bill', 'Bill'),
      ('3', 'status-ordered', 'Ordered'),
    ]) {
      c.select({n});
      await tester.pump();
      await press(tester, key);
      expect(c.unitStatuses.value[n], DemoHomeState.kStatuses[caption]);
    }
    expect(c.unitStatuses.value.keys.toSet(), {'1', '2', '3'});

    // Two tables merged.
    c.select({'4', '5'});
    await tester.pump();
    await press(tester, 'service-merge');
    expect(c.unitGroups.value.map((id, g) => MapEntry(id, g.members)), {
      'G1': {'4', '5'},
    });
    expect(demo.log.first, 'Salon: Merged {4, 5} as G1');

    // The layout saved after one move, the table moved again, the layout
    // put back.
    final home = placementOf(c, '8');
    serviceMove(c, '8');
    await tester.pump();
    final kept = placementOf(c, '8');
    expect(kept.e, isNot(home.e), reason: 'premise: the stool moved');
    final saved = c.serviceJson()!;
    serviceMove(c, '8', dx: -900, dy: 700);
    await tester.pump();
    expect(placementOf(c, '8').e, isNot(kept.e), reason: 'premise: moved on');
    final restored = c.restoreService(saved);
    await tester.pump();
    expect(restored.droppedMoves, isEmpty);
    expect(restored.appliedGroups, ['G1']);
    expect(placementOf(c, '8').e, kept.e, reason: 'the saved layout is back');
    expect(placementOf(c, '8').f, kept.f);
    expect(c.unitStatuses.value.keys.toSet(), {'1', '2', '3'});

    // A PNG exported through the own bar, written to a temp directory.
    await pressInPanel(tester, 'own-bar');
    await press(tester, 'own-export');
    await tester.tap(byKey('export-format-plan.png'));
    await tester.pump();
    await tester.tap(byKey('export-dpi-96'));
    await tester.pump();
    await tester.tap(byKey('export-ok'));
    await tester.pump();
    await waitFor(tester, () => demo.lastExport != null);
    final export = demo.lastExport!;
    expect(export.name, 'salon.png');
    final file = File('${dir.path}/${export.name}')
      ..writeAsBytesSync(export.bytes);
    final head = file.readAsBytesSync().sublist(0, 8);
    expect(head, [137, 80, 78, 71, 13, 10, 26, 10], reason: 'a PNG');
    expect(file.lengthSync(), greaterThan(1000));

    // The screen, captured through the repaint boundary.
    await tester.pumpAndSettle();
    final boundary =
        shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    expect(png, isNotNull);
    expect(png!.length, greaterThan(10000), reason: 'a drawn screen');
    const out = String.fromEnvironment('POS_OUT');
    final target = File('${out.isEmpty ? Directory.systemTemp.path : out}'
        '/2026-10-16-restaurant-kit-pos.png');
    target.writeAsBytesSync(png);
    // ignore: avoid_print
    print('POS_PNG ${target.path} ${png.length} bytes; '
        'export ${export.bytes.length} bytes');
    binding.reportData = {'png': target.path, 'export': export.bytes.length};
  });
}
