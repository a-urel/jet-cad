// Host embedding API spec G-1 to G-7 in the demo: the Salon's badges, one
// per table through `tableOverlayBuilder`, behind the "Badges" switch, a dot
// below the detail breakpoint, faded outside the zone focus; and the button
// that centres the view on table 7 through `centerOn`. Every expectation is
// computed here from the public API (`tableDetails`, `camera`,
// `canvasRect`, `worldToGlobal`) on the Salon sample, whose fitted camera
// is neither the identity nor at the origin; the badges' figures are worked
// by hand.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:restaurant_demo/main.dart';

Finder byKey(String k) => find.byKey(Key(k));

/// The demo on the sample plans, at 1600 x 1000.
Future<DemoHomeState> pumpSamples(WidgetTester tester) async {
  final plans = (await tester.runAsync(() => loadSamplePlans(rootBundle)))!;
  await tester.binding.setSurfaceSize(const Size(1600, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RestaurantDemo(plans: plans));
  await tester.pump();
  await tester.pump();
  return tester.state<DemoHomeState>(find.byType(DemoHome));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Scrolls the side panel until [key] is in view.
Future<void> reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(byKey(key), 100,
      scrollable: find
          .descendant(
              of: byKey('side-panel'), matching: find.byType(Scrollable))
          .first);
  await tester.pump();
}

/// The Salon in the service, its badges switched on.
Future<DemoHomeState> badgesOn(WidgetTester tester) async {
  final demo = await pumpSamples(tester);
  await tester.tap(byKey('mode-service'));
  await settle(tester);
  await reveal(tester, 'badges');
  await tester.tap(byKey('badges'));
  await settle(tester);
  return demo;
}

/// The numbers of the full badges built (keys `badge-<n>`), or of the
/// dots (`badge-dot-<n>`).
List<String> shown(WidgetTester tester, {bool dots = false}) {
  final pattern = RegExp(dots ? r'^badge-dot-(.+)$' : r'^badge-(\d+)$');
  return [
    for (final e
        in find.byWidgetPredicate((w) => w.key is ValueKey<String>).evaluate())
      if (pattern.firstMatch((e.widget.key! as ValueKey<String>).value)
          case final m?)
        m[1]!,
  ]..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
}

/// The numbers of the tables that get a badge: numbered, with geometry.
List<String> badged(FloorPlanController c) => [
      for (final d in c.tableDetails)
        if (d.table.number != null && d.center != null) d.table.number!,
    ]..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

/// Table [number]'s bounding box on the screen, in global coordinates,
/// from its world corners through the public `worldToGlobal`.
Rect screenBox(FloorPlanController c, String number) {
  final d = c.tableDetails.singleWhere((d) => d.table.number == number);
  final points = [for (final p in d.corners) c.worldToGlobal(p)!];
  var box = Rect.fromPoints(points[0], points[1]);
  for (final p in points.skip(2)) {
    box = box.expandToInclude(Rect.fromPoints(p, p));
  }
  return box;
}

void expectNear(Offset actual, Offset expected, String reason) {
  expect(actual.dx, closeTo(expected.dx, 1e-6), reason: '$reason: x');
  expect(actual.dy, closeTo(expected.dy, 1e-6), reason: '$reason: y');
}

void main() {
  testWidgets(
      'DB1 the Badges switch: off by default, then one badge per numbered '
      'table, worked figures by status, a minute tick without a build, and '
      'none again when off', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await settle(tester);
    await reveal(tester, 'badges');
    expect(demo.area.badges, isFalse);
    expect(shown(tester), isEmpty, reason: 'off by default');
    expect(demo.badgeBuilds, 0);

    // Statuses through the demo's own buttons: 7 Eating, 2 Bill, 10 Ordered.
    for (final (n, status) in [
      ('7', 'eating'),
      ('2', 'bill'),
      ('10', 'ordered'),
    ]) {
      c.select({n});
      await tester.pump();
      await reveal(tester, 'status-$status');
      await tester.tap(byKey('status-$status'));
      await tester.pump();
    }
    c.select(const {});
    await reveal(tester, 'badges');
    await tester.tap(byKey('badges'));
    await settle(tester);

    final want = badged(c);
    expect(want, ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'],
        reason: 'premise: the Salon sample');
    expect(shown(tester), want);
    expect(demo.badgeBuilds, want.length, reason: 'one build per table');
    String text(String key) => tester.widget<Text>(byKey(key)).data!;
    // By hand: 7 (4 seats) Eating: 1 + 7 % 4 = 4 guests, 20 + 21 % 25 = 41
    // min; 2 (4) Bill: 1 + 2 % 4 = 3, 45 + 14 % 30 = 59; 10 (1) Ordered:
    // 1 + 10 % 1 = 1, 5 + 10 % 10 = 5; 5 (6) free: 0 guests, no minutes.
    expect(text('badge-guests-7'), '4/4');
    expect(text('badge-minutes-7'), '41 min');
    expect(text('badge-guests-2'), '3/4');
    expect(text('badge-minutes-2'), '59 min');
    expect(text('badge-guests-10'), '1/1');
    expect(text('badge-minutes-10'), '5 min');
    expect(text('badge-guests-5'), '0/6');
    expect(byKey('badge-minutes-5'), findsNothing);

    // The minutes are the host's live data: a tick rebuilds the counters,
    // not the overlays.
    final builds = demo.badgeBuilds;
    await tester.pump(const Duration(minutes: 1));
    expect(text('badge-minutes-7'), '42 min');
    expect(text('badge-minutes-10'), '6 min');
    expect(demo.badgeBuilds, builds, reason: 'a tick builds no overlay');

    // A status change rebuilds that table's badge: 5 Eating, 1 + 5 % 6 = 6
    // guests, 20 + 15 % 25 = 35 min, one minute on.
    c.select({'5'});
    await tester.pump();
    await reveal(tester, 'status-eating');
    await tester.tap(byKey('status-eating'));
    await settle(tester);
    expect(text('badge-guests-5'), '6/6');
    expect(text('badge-minutes-5'), '36 min');

    await reveal(tester, 'badges');
    await tester.tap(byKey('badges'));
    await settle(tester);
    expect(shown(tester), isEmpty, reason: 'switched off');
    expect(shown(tester, dots: true), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'DB2 the badges ride with their tables across a pan and a zoom, '
      'built none; a dot below the breakpoint; a tap on a badge still '
      'selects its table', (tester) async {
    final demo = await badgesOn(tester);
    final c = demo.area.controller;
    final first = c.camera.value;
    expect(first.scale, greaterThan(kBadgeDetailScale),
        reason: 'premise: the fit shows full badges');

    void pinned(String step) {
      for (final n in ['1', '4', '7', '11']) {
        final badge = tester.getRect(byKey('badge-$n'));
        final box = screenBox(c, n);
        expectNear(badge.bottomCenter, box.bottomCenter, '$step: $n');
      }
    }

    pinned('fitted');
    final before = tester.getRect(byKey('badge-7'));
    final builds = demo.badgeBuilds;

    c.panBy(const Offset(-120, 75));
    expect(c.zoomBy(1.6, focus: const Offset(300, 200)), isTrue);
    await settle(tester);
    expect(c.camera.value, isNot(first), reason: 'premise: the camera moved');
    expect(tester.getRect(byKey('badge-7')).bottomCenter,
        isNot(before.bottomCenter),
        reason: 'premise: the badge moved');
    pinned('panned and zoomed');
    expect(demo.badgeBuilds, builds, reason: 'pan and zoom build nothing');

    // Below the breakpoint: a dot per table, each built once; above it
    // again: the full badges.
    expect(c.zoomBy(0.25), isTrue);
    await settle(tester);
    expect(c.camera.value.scale, lessThan(kBadgeDetailScale),
        reason: 'premise');
    expect(shown(tester), isEmpty);
    expect(shown(tester, dots: true), badged(c));
    expect(demo.badgeBuilds, builds + badged(c).length);
    for (final n in ['1', '7']) {
      final dot = tester.getRect(byKey('badge-dot-$n'));
      expectNear(dot.bottomCenter, screenBox(c, n).bottomCenter, 'dot $n');
    }
    expect(c.zoomBy(4), isTrue);
    await settle(tester);
    expect(shown(tester), badged(c));
    expect(shown(tester, dots: true), isEmpty);

    // Not interactive: the tap is the table's.
    c.fitToView();
    await settle(tester);
    expect(c.selectedTables.value, isEmpty, reason: 'premise');
    await tester.tapAt(tester.getCenter(byKey('badge-2')));
    await settle(tester);
    expect(c.selectedTables.value, {'2'});
    expect(demo.log.take(2), ['Salon: tapped 2', 'Salon: selected {2}']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'DB3 a zone focus fades the other tables\' badges; their selection '
      'outlines them', (tester) async {
    final demo = await badgesOn(tester);
    final c = demo.area.controller;
    double opacity(String n) => tester
        .widget<Opacity>(find
            .ancestor(of: byKey('badge-$n'), matching: find.byType(Opacity))
            .first)
        .opacity;
    expect(opacity('1'), 1);
    expect(opacity('7'), 1);
    await reveal(tester, 'fade-others');
    await tester.tap(byKey('fade-others'));
    await tester.pump();
    await tester.tap(byKey('zone-B'));
    await settle(tester);
    expect(c.tableFocus.value, {'6', '7'}, reason: 'premise');
    expect(opacity('7'), 1);
    expect(opacity('6'), 1);
    expect(opacity('1'), 0.35);
    expect(opacity('11'), 0.35);

    final border = (tester.widget<Container>(byKey('badge-7')).decoration!
            as BoxDecoration)
        .border! as Border;
    expect(border.top.width, 1);
    c.select({'7'});
    await settle(tester);
    final selected = (tester.widget<Container>(byKey('badge-7')).decoration!
            as BoxDecoration)
        .border! as Border;
    expect(selected.top.width, 2);
  });

  testWidgets(
      'DB4 Centre on table 7: the canvas\'s centre shows table 7\'s centre, '
      'the zoom kept', (tester) async {
    final demo = await pumpSamples(tester);
    final c = demo.area.controller;
    await tester.tap(byKey('mode-service'));
    await settle(tester);
    expect(c.zoomBy(1.7, focus: const Offset(100, 640)), isTrue);
    await settle(tester);
    final scale = c.camera.value.scale;
    final seven = c.tableDetails.singleWhere((d) => d.table.number == '7');
    final world = seven.center!;
    final canvas = c.canvasRect.value!;
    final middle = canvas.size.center(Offset.zero);
    expect((c.camera.value.worldToCanvas(world) - middle).distance,
        greaterThan(100),
        reason: 'premise: 7 is away from the middle');

    await reveal(tester, 'center-7');
    await tester.tap(byKey('center-7'));
    await settle(tester);
    final camera = c.camera.value;
    expectNear(camera.worldToCanvas(world), middle, 'on the canvas');
    expect(camera.scale, closeTo(scale, scale * 1e-12), reason: 'zoom kept');
    final back = c.globalToWorld(canvas.center)!;
    expect(back.dx, closeTo(world.dx, world.dx.abs() * 1e-9 + 1e-9));
    expect(back.dy, closeTo(world.dy, world.dy.abs() * 1e-9 + 1e-9));
    expect(c.tableAt(middle), '7');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'DB5 the Teras and the design offer no badges; the switch is kept per '
      'area', (tester) async {
    final demo = await badgesOn(tester);
    expect(shown(tester), isNotEmpty, reason: 'premise');
    await tester.tap(byKey('mode-design'));
    await settle(tester);
    expect(shown(tester), isEmpty, reason: 'the design mode shows none');
    expect(byKey('badges'), findsNothing);
    await tester.tap(byKey('area-1'));
    await settle(tester);
    await tester.tap(byKey('mode-service'));
    await settle(tester);
    await tester.drag(byKey('side-panel'), const Offset(0, -5000));
    await tester.pump();
    expect(find.text('Log'), findsOneWidget, reason: 'premise: the end');
    expect(byKey('badges'), findsNothing);
    expect(byKey('center-7'), findsNothing);
    expect(shown(tester), isEmpty);
    await tester.tap(byKey('area-0'));
    await settle(tester);
    await tester.tap(byKey('mode-service'));
    await settle(tester);
    expect(demo.area.badges, isTrue);
    expect(shown(tester), badged(demo.area.controller));
  });

  testWidgets('DB6 the badges\' strings in German and Turkish', (tester) async {
    final demo = await badgesOn(tester);
    final c = demo.area.controller;
    c.select({'7'});
    await tester.pump();
    await reveal(tester, 'status-eating');
    await tester.tap(byKey('status-eating'));
    await settle(tester);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Centre on table 7'), findsOneWidget);
    expect(find.text('41 min'), findsOneWidget);
    for (final (lang, badges, centre, minutes) in [
      ('de', 'Tischanzeigen', 'Auf Tisch 7 zentrieren', '41 Min.'),
      ('tr', 'Rozetler', 'Ortala: masa 7', '41 dk'),
    ]) {
      await tester.tap(byKey('lang-$lang'));
      await settle(tester);
      await reveal(tester, 'center-7');
      expect(find.text(badges), findsOneWidget, reason: lang);
      expect(find.text(centre), findsOneWidget, reason: lang);
      expect(find.text(minutes), findsOneWidget, reason: lang);
    }
  });

  test('DB7 the figures: free tables seat nobody; each status its minutes', () {
    expect(DemoHomeState.badgeFigures('3', 4, null), isNull);
    expect(DemoHomeState.badgeFigures('3', 4, 'Free'), isNull);
    expect(DemoHomeState.badgeFigures('3', 4, 'status'), isNull);
    expect(
        DemoHomeState.badgeFigures('3', 4, 'Ordered'), (guests: 4, minutes: 8));
    expect(
        DemoHomeState.badgeFigures('12', 6, 'Bill'), (guests: 1, minutes: 69));
    // A number that is not digits counts its length.
    expect(
        DemoHomeState.badgeFigures('A', 2, 'Eating'), (guests: 2, minutes: 23));
  });
}
