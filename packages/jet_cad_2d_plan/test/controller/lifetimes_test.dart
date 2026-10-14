// Spec 2a P1 "PlanServices" and its lifetimes, Review Focus 4: a kit's
// factories run once per document; a swap cancels the tool, settles the
// pending input into the old plan, disposes the old products and runs the
// factories again; `shared` is per document and per kit; the services read
// the current document, the settings, the words and the snap live; the
// grip cache asks each object's own type.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

final class _Probe {}

final class _Loop {}

void main() {
  testWidgets(
      'C-life1 the factories run once per document; after a swap every '
      'product of the previous document is disposed and new ones are made',
      (tester) async {
    final log = KitLog();
    final c = controllerFor(kits: [testKit(log: log)]);
    expect(log.events, ['cache+1', 'tool+1', 'grips+1']);
    final tool = c.toolFor('test.slab')! as SlabTool;
    expect(
        c
            .servicesOf('test')
            .shared<SlabCache>((_) => throw StateError('made twice')),
        same(tool.cache),
        reason: 'the tool and the grips share one cache per document');
    expect(c.selectTool('test.slab'), isTrue);
    expect(c.selectTool('plan.select'), isTrue);
    expect(c.selectTool('test.slab'), isTrue);
    expect(log.events, hasLength(3),
        reason: 'once per document, not per arming');
    // M-C-life1: the kit products not disposed at a swap.
    c.newPlan();
    expect(log.events.skip(3),
        ['tool-1', 'grips-1', 'cache-1', 'cache+2', 'tool+2', 'grips+2']);
    expect(tool.cache.disposed, isTrue);
    expect(c.toolFor('test.slab'), isNot(same(tool)));
    expect(c.activeTool.value, 'plan.select',
        reason: 'a tool armed before the swap is gone');
    await tester.pump();
  });

  testWidgets(
      "C-life2 shared is keyed by kit and type: two kits asking for one type "
      'get two values; a value that asks for itself is refused',
      (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final a = c.servicesOf('test').shared<_Probe>((_) => _Probe());
    // M-C-life2a: the cache keyed by type alone.
    expect(
        c.servicesOf('disc').shared<_Probe>((_) => _Probe()), isNot(same(a)));
    expect(c.servicesOf('test').shared<_Probe>((_) => _Probe()), same(a));
    // M-C-life2b: no guard against a create that asks for itself.
    expect(
        () => c
            .servicesOf('disc')
            .shared<_Loop>((s) => s.shared<_Loop>((_) => _Loop())),
        throwsStateError);
    c.newPlan();
    expect(c.servicesOf('test').shared<_Probe>((_) => _Probe()), isNot(same(a)),
        reason: 'per document');
    await tester.pump();
  });

  testWidgets(
      "C-svc the services: a kit's own tool settings, the controller's across "
      'plans; the words at the current locale with English the fallback; '
      'the effective snap; the current document, index and camera',
      (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final s = c.servicesOf('test');
    expect(s.settingsOf<SlabSettings>('test.slab'),
        const SlabSettings(width: 1200, height: 600));
    c.toolSettings
        .store('test.slab', const SlabSettings(width: 2400, height: 750));
    expect(s.settingsOf<SlabSettings>('test.slab').width, 2400);
    expect(() => s.settingsOf<DiscComponent>('test.slab'), throwsArgumentError);
    // M-C-svc-a: another kit's tool settings readable.
    expect(() => c.servicesOf('disc').settingsOf<SlabSettings>('test.slab'),
        throwsArgumentError);
    c.newPlan();
    expect(s.settingsOf<SlabSettings>('test.slab').width, 2400,
        reason: 'the controller holds one value per tool, across plans');
    // The new plan's slab tool reads them through its services as it
    // commits.
    expect(c.selectTool('test.slab'), isTrue);
    final tool = c.toolFor('test.slab')!;
    tool.onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    tool.onPointerDown(pointerAt(Vector2(3400, 260)), c.toolContext);
    final placed =
        c.document.components.get<SlabComponent>(slabsOf(c.document).single)!;
    expect((placed.width, placed.height), (2400.0, 750.0));
    expect(s.words.word('type:test.slab'), 'Slab');
    // M-C-svc-c: the words read a locale fixed at creation.
    c.reportLocale(const Locale('tr'));
    expect(s.words.word('type:test.slab'), 'Döşeme');
    c.reportLocale(const Locale('de'));
    expect(s.words.word('type:test.slab'), 'Slab',
        reason: 'no German: English');
    expect(s.objectSnap, isTrue);
    c.snap.toggleObjectSnap();
    expect(s.objectSnap, isFalse);
    c.snap.toggleObjectSnap();
    // M-C-svc-d: the canvas's snapping option ignored.
    c.snappingAllowed = false;
    expect(s.objectSnap, isFalse);
    expect(s.document, same(c.document));
    expect(s.index, same(c.index));
    expect(s.camera, same(c.camera));
    expect(s.attachments.kinds, isEmpty, reason: 'the registry is Task 14');
    await tester.pump();
  });

  testWidgets(
      "C-grips the grip cache asks each object's own type: a slab gives its "
      'grip and drags it, a disc and a plain group none; a swap lets the old '
      "plan's providers go", (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final d = c.document;
    final slab = addObject<SlabComponent>(
        d, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    final disc = addObject<DiscComponent>(d, DiscComponent(radius: 650),
        at: Vector2(-3100, 2240));
    final plain = d.handleSeed.next();
    d.commands.execute(AddNodeCommand(GroupNode(
        handle: plain,
        parent: d.rootHandle,
        transform: Transform2.translation(-800, -2600),
        children: const [])));
    final objects = c.grips.objects!;
    // M-C-grips-a: the dispatch finds no provider.
    final grips = objects.gripsOf(d, slab);
    expect(grips.single.x, closeTo(2350 + 900 * math.cos(0.4), 1e-9));
    expect(grips.single.y, closeTo(-1180 + 900 * math.sin(0.4), 1e-9));
    expect(objects.gripsOf(d, disc), isEmpty);
    expect(objects.gripsOf(d, plain), isEmpty);
    expect(objects.movable(d, plain), isTrue);
    final drop =
        Vector2(2350 + 1300 * math.cos(0.4), -1180 + 1300 * math.sin(0.4));
    // M-C-grips-c: the dispatch previews nothing.
    final [(kind, payload)] = objects.preview(d, slab, grips.single, drop);
    expect(kind, EntityKind.polyline);
    final corners =
        slabCorners(SlabComponent(width: 2600, height: 900, angle: 0.4));
    expect(payload.pointCount, 5);
    for (var i = 0; i < 4; i++) {
      expect(payload.coords[2 * i], closeTo(2350 + corners[i].x, 1e-9));
      expect(payload.coords[2 * i + 1], closeTo(-1180 + corners[i].y, 1e-9));
    }
    d.commands.execute(objects.drag(d, slab, grips.single, drop)!);
    expect(d.components.get<SlabComponent>(slab)!.width, closeTo(2600, 1e-9));
    // M-C-grips-b: the old dispatch not closed at a swap.
    c.newPlan();
    expect(objects.gripsOf(d, slab), isEmpty,
        reason: "the old plan's providers are let go");
    await tester.pump();
  });

  testWidgets(
      'C-swap-mid-shape (Review Focus 4) load while the slab tool is '
      'part-way through a shape and a field holds a value: no exception, '
      'the tool cancelled, the value settled into the old plan and not into '
      'the new one', (tester) async {
    final log = KitLog();
    final c = controllerFor(kits: [testKit(log: log)], json: slabPlanText());
    final old = c.document;
    final slab = slabsOf(old).first;
    var pending = true;
    // What a panel field holding 2750 for the slab's width does on settle:
    // it commits into the plan it was typed for.
    c.registerSettle(() {
      if (!pending) return;
      pending = false;
      setSlabWidth(c, slab, 2750);
    });
    expect(c.selectTool('test.slab'), isTrue);
    final tool = c.toolFor('test.slab')! as SlabTool;
    tool.onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    expect(tool.isMidShape, isTrue, reason: 'premise');

    c.load(slabPlanText());

    // M-C-swap-a: load does not settle. M-C-swap-b: it settles after the
    // swap, into the new plan.
    expect(old.components.get<SlabComponent>(slab)!.width, 2750);
    expect(c.document.components.get<SlabComponent>(slab)!.width, 1800);
    // M-C-swap-c: the swap does not cancel the active tool.
    expect(tool.isMidShape, isFalse);
    expect(c.activeTool.value, 'plan.select');
    expect(log.events, contains('tool-1'));
    expect(c.toolFor('test.slab'), isNot(same(tool)));
    await tester.pump();
  });
}
