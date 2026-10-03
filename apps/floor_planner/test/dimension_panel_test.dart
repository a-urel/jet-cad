// Spec 11 D14: the Selection panel's Dimension section. Shown for exactly
// one selected dimension (10 D21's rule): its value, read-only, as its TEXT
// child reads (decision 13), or `—` for a broken dimension; a switch
// Aligned | Horizontal | Vertical, each click one `SetComponentCommand`
// with only the kind changed (R-27); the axes line of a turned linear
// dimension (D11, R-18); the two end lines (R-28). Read-only unless
// `components` and `geometry` are allowed (07 WS8); a refused edit is
// caught.
//
// The plan is C2's L -- A (0, 0) -> (4000, 0), B (4000, 0) -> (4000, 3000),
// both 200 centred -- on a 1:50 page in millimetres, at the origin and at
// the corpus far origin turned 23° with every wall in its own rotated,
// translated group. Each dimension's group sits at the placement (and, in
// PN3, turned further), so a local hand value holds at both. Expected
// strings are hand arithmetic beside the assertion.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;

import 'package:floor_planner/planner_shell.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';
import 'support/wall_fixture.dart' show addWallLocal;

const l = WallSide.left, r = WallSide.right;

Finder get section => find.byKey(const Key('dimension-section'));
Finder get value => find.byKey(const Key('dimension-value'));
Finder get kindSwitch => find.byKey(const Key('dimension-kind'));
Finder get axes => find.byKey(const Key('dimension-axes'));

String textAt(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

String valueText(WidgetTester tester) => textAt(tester, 'dimension-value');

SegmentedButton<DimKind> switchOf(WidgetTester tester) =>
    tester.widget<SegmentedButton<DimKind>>(kindSwitch);

Future<void> select(
    WidgetTester tester, PlannerView view, List<Handle> hs) async {
  view.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

/// A click on the segment keyed [key]; two pumps, because the `DocChange`
/// arrives a microtask late (10's `RN2` finding, the plan's Ruling 11-8).
Future<void> tapKind(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

DimensionParams paramsOf(DraftDocument doc, Handle h) =>
    doc.components.get<DimensionParams>(h)!;

/// The group a dimension sits in: the placement, turned [deg] further.
Transform2 turned(Placement place, double deg) =>
    place.m.multiply(Transform2.rotation(deg * math.pi / 180));

/// C2's L at [place] on a 1:50 mm page, the floor planner's system live so
/// that what the test adds generates. [finish] then disposes that system
/// and clears the history: the shell installs its own over the finished
/// document.
Plan panelPlan(Placement place) {
  final plan =
      buildPlan(c2Walls, place: place, measurer: FlutterTextMeasurer());
  attachPage(plan.doc, mmPage);
  return plan;
}

void finish(Plan plan) {
  plan.system.dispose();
  plan.doc.commands.clearHistory();
}

/// Pumps the shell over [doc] (keyed by [key], so a second document gets a
/// state of its own).
Future<PlannerView> pumpShell(
    WidgetTester tester, DraftDocument doc, String key) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: PlannerShell(key: ValueKey(key), document: doc)));
  await tester.pump();
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

/// [h]'s children's payloads as bytes, ascending by handle, and its TEXT's
/// string: what a kind switch and the switch back must restore bit for
/// bit.
(List<Handle>, List<List<int>>, String) childrenOf(
        DraftDocument doc, Handle h) =>
    (
      kids(doc, h),
      [
        for (final k in kids(doc, h))
          [
            ...Float64List.fromList(payloadOf(doc, k).coords)
                .buffer
                .asUint8List(),
            ...Float64List.fromList(payloadOf(doc, k).scalars)
                .buffer
                .asUint8List(),
          ],
      ],
      dimText(doc, h),
    );

void main() {
  for (final place in const [origin, corpusGroups]) {
    testWidgets(
        'PN1 the Dimension section shows for exactly one dimension, its '
        'value as its text reads, at $place', (tester) async {
      final plan = panelPlan(place);
      final doc = plan.doc;
      final [a, b] = plan.walls;
      // Premise: A/0/left is A's free start on its left face, (0, 100):
      // A runs +x, its left normal is +y, and it is 200 centred.
      expect(bruteCandidates(doc, plan.at(0, 100)), [AttachedEnd(a, 0, l)],
          reason: 'premise: A/0/left');
      // From A/0/left (0, 100) to a fixed point (3450.6, 100): aligned,
      // 3450.6 mm, which reads 3451 (half-up to the millimetre, 0.1 from
      // the tie at 3450.5).
      final d = addDimension(
          doc, AttachedEnd(a, 0, l), fixedAt(plan.at(3450.6, 100), place.m),
          kind: DimKind.aligned, offset: 400.25, at: place.m);
      final d2 = addDimension(doc, fixedAt(plan.at(500.25, 1500.5), place.m),
          fixedAt(plan.at(2500.75, 2200.25), place.m),
          kind: DimKind.horizontal, offset: -250.5, at: place.m);
      // Broken (D15): an attached end with k = 2 generates nothing.
      final broken = addDimension(
          doc, AttachedEnd(a, 2, l), fixedAt(plan.at(3450.6, 100), place.m),
          kind: DimKind.aligned, offset: 400.25, at: place.m);
      expect(kids(doc, broken), isEmpty, reason: 'premise: broken');
      expect(dimText(doc, d), '3451', reason: 'premise: the TEXT');
      finish(plan);
      final view = await pumpShell(tester, doc, place.name);

      expect(section, findsNothing, reason: 'none');
      await select(tester, view, [d]);
      expect(section, findsOneWidget);
      expect(tester.widget<Text>(section).data, 'Dimension');
      expect(valueText(tester), '3451');
      expect(
          textAt(tester, 'dimension-end-1'),
          'Wall ${a.toHex()}, start, '
          'left face');
      expect(textAt(tester, 'dimension-end-2'), 'Fixed');

      await select(tester, view, [d, d2]);
      expect(section, findsNothing, reason: 'two dimensions');
      await select(tester, view, [d, a]);
      expect(section, findsNothing, reason: 'a dimension and a wall');
      await select(tester, view, [a]);
      expect(section, findsNothing, reason: 'a wall');
      expect(find.byKey(const Key('wall-section')), findsOneWidget);
      await select(tester, view, [b, d2]);
      expect(section, findsNothing, reason: 'a wall and a dimension');
      await select(tester, view, [broken]);
      expect(section, findsOneWidget, reason: 'a broken dimension');
      expect(valueText(tester), '—', reason: 'a broken dimension');

      // A wall edit rewrites the value in place: A moved 500.25 along the
      // plan's −x (its joint with B broken), so A/0/left is (−500.25, 100)
      // and the value 3450.6 + 500.25 = 3950.85, which reads 3951.
      await select(tester, view, [d]);
      expect(valueText(tester), '3451');
      final t = place.m.transformDirection(Vector2(-500.25, 0));
      doc.commands.execute(TransformNodeCommand(a,
          Transform2.translation(t.x, t.y).multiply(doc.tree[a]!.transform)));
      await tester.pump();
      await tester.pump();
      expect(dimText(doc, d), '3951', reason: 'premise: regenerated');
      expect(valueText(tester), '3951', reason: 'after the wall edit');
      expect(driftOf(doc), isEmpty);
    });

    testWidgets(
        'PN2 a kind click is one undo step that keeps the ends and the '
        'offset; switching back restores the children bit for bit; the '
        'current kind issues nothing, at $place', (tester) async {
      final plan = panelPlan(place);
      final doc = plan.doc;
      final [a, b] = plan.walls;
      // The non-axis pair (0, 0)-(3000, 1200), aligned, offset −617.375.
      final d = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
          kind: DimKind.aligned, offset: -617.375, at: place.m);
      // The inner corner (3900, 100) is both A/1/left and B/0/left; this
      // dimension stores A/1/left and a −0.0 offset (its side the right
      // normal's, R-2), which a switch must keep as they are (D10: a switch
      // re-decides no end).
      expect(bruteCandidates(doc, plan.at(3900, 100)),
          [AttachedEnd(a, 1, l), AttachedEnd(b, 0, l)],
          reason: 'premise: a shared corner');
      final e = addDimension(
          doc, AttachedEnd(a, 1, l), fixedAt(plan.at(1000.25, 1500.5), place.m),
          kind: DimKind.aligned, offset: -0.0, at: place.m);
      finish(plan);
      final view = await pumpShell(tester, doc, place.name);
      await select(tester, view, [d]);
      final p0 = paramsOf(doc, d);
      final first = childrenOf(doc, d);
      // Aligned: √(3000² + 1200²) = √10,440,000 = 3231.09.
      expect(valueText(tester), '3231');
      expect(switchOf(tester).selected, {DimKind.aligned});
      final focus = FocusManager.instance.primaryFocus;

      await tapKind(tester, 'dimension-horizontal');
      expect(doc.commands.undoDepth, 1, reason: 'Horizontal: one step');
      var p = paramsOf(doc, d);
      expect(p.kind, DimKind.horizontal);
      expect(p.a, p0.a, reason: 'Horizontal: a kept');
      expect(p.b, p0.b, reason: 'Horizontal: b kept');
      expect(p.offset, -617.375, reason: 'Horizontal: the offset kept');
      expect(p, p0.copyWith(kind: DimKind.horizontal));
      // Horizontal along the group's x: 3000.
      expect(dimText(doc, d), '3000');
      expect(valueText(tester), '3000');
      expect(switchOf(tester).selected, {DimKind.horizontal});
      expect(FocusManager.instance.primaryFocus, focus,
          reason: 'the click leaves the focus where it was');

      await tapKind(tester, 'dimension-aligned');
      expect(doc.commands.undoDepth, 2, reason: 'Aligned: one step');
      p = paramsOf(doc, d);
      expect(p, p0, reason: 'back to the stored parameters');
      expect(p.offset, -617.375);
      final back = childrenOf(doc, d);
      expect(back.$1, first.$1, reason: 'the same children');
      expect(back.$2, first.$2, reason: 'their payloads bit for bit');
      expect(back.$3, first.$3);
      expect(valueText(tester), '3231');

      // The current kind: a click issues nothing (the segmented button
      // does not call back for its selected segment), nor does the
      // callback itself (a click that lands before a rebuild).
      await tapKind(tester, 'dimension-aligned');
      expect(doc.commands.undoDepth, 2, reason: 'a click on Aligned');
      switchOf(tester).onSelectionChanged!({DimKind.aligned});
      await tester.pump();
      await tester.pump();
      expect(doc.commands.undoDepth, 2, reason: 'the callback on Aligned');
      expect(paramsOf(doc, d), p0);

      // The corner end and the −0.0 offset through a switch and back.
      await select(tester, view, [e]);
      final q0 = paramsOf(doc, e);
      await tapKind(tester, 'dimension-vertical');
      expect(doc.commands.undoDepth, 3);
      expect(paramsOf(doc, e).a, AttachedEnd(a, 1, l),
          reason: 'the corner end not re-decided');
      expect(paramsOf(doc, e).offset.isNegative, isTrue,
          reason: 'the −0.0 offset kept');
      expect(paramsOf(doc, e), q0.copyWith(kind: DimKind.vertical));
      await tapKind(tester, 'dimension-aligned');
      expect(paramsOf(doc, e), q0);

      doc.commands.undo();
      doc.commands.undo();
      doc.commands.undo();
      doc.commands.undo();
      await tester.pump();
      await tester.pump();
      expect(paramsOf(doc, d), p0);
      expect(paramsOf(doc, e), q0);
      expect(driftOf(doc), isEmpty);
    });

    testWidgets(
        'PN3 a linear dimension turned shows Axes turned by the rounded '
        'angle; aligned and unturned show none; 0.04° and −0.04° show none, '
        '0.06° shows 0.1°, at $place', (tester) async {
      final plan = panelPlan(place);
      final doc = plan.doc;
      // The group's world rotation is the placement's plus the turn: 0 + 30
      // and 0 − 30 at the origin, 23 + 30 = 53 and 23 − 30 = −7 at the
      // corpus placement.
      final (plus, minus) =
          place == origin ? ('30.0', '-30.0') : ('53.0', '-7.0');
      // A group at the placement's point with world rotation [deg] exactly.
      final o = plan.at(500.5, 800.25);
      Transform2 world(double deg) => Transform2.translation(o.x, o.y)
          .multiply(Transform2.rotation(deg * math.pi / 180));
      Handle dim(DimKind kind, Transform2 at) => addDimension(
          doc, const FixedEnd(0.25, 0.5), const FixedEnd(3000.75, 1200.25),
          kind: kind, offset: 300.5, at: at);
      final cases = <(String, Handle, String?)>[
        ('horizontal +30', dim(DimKind.horizontal, turned(place, 30)), plus),
        ('vertical +30', dim(DimKind.vertical, turned(place, 30)), plus),
        ('horizontal −30', dim(DimKind.horizontal, turned(place, -30)), minus),
        ('aligned +30', dim(DimKind.aligned, turned(place, 30)), null),
        ('horizontal at 0°', dim(DimKind.horizontal, world(0)), null),
        ('horizontal at 0.04°', dim(DimKind.horizontal, world(0.04)), null),
        // Prints -0.0: the number decides, not the string (S-8).
        ('horizontal at −0.04°', dim(DimKind.horizontal, world(-0.04)), null),
        ('vertical at 0.06°', dim(DimKind.vertical, world(0.06)), '0.1'),
        // Rounded to tenths, then normalised: −179.96° rounds to −180.0,
        // which is 180.0 in (−180°, 180°], as 179.96° reads.
        (
          'horizontal at −179.96°',
          dim(DimKind.horizontal, world(-179.96)),
          '180.0'
        ),
        (
          'horizontal at 179.96°',
          dim(DimKind.horizontal, world(179.96)),
          '180.0'
        ),
      ];
      finish(plan);
      final view = await pumpShell(tester, doc, place.name);
      for (final (why, h, want) in cases) {
        await select(tester, view, [h]);
        expect(section, findsOneWidget, reason: why);
        if (want == null) {
          expect(axes, findsNothing, reason: why);
        } else {
          expect(textAt(tester, 'dimension-axes'), 'Axes turned $want°',
              reason: why);
        }
      }
      // The aligned one switched to horizontal: now linear and turned.
      await select(tester, view, [cases[3].$2]);
      await tapKind(tester, 'dimension-horizontal');
      expect(textAt(tester, 'dimension-axes'), 'Axes turned $plus°');
      expect(switchOf(tester).selected, {DimKind.horizontal},
          reason: 'the switch still reads Horizontal');
    });

    testWidgets(
        'PN4 the end lines read Wall <hex>, start or end, left face, '
        'centreline or right face, or Fixed, at $place', (tester) async {
      final plan = panelPlan(place);
      final doc = plan.doc;
      // A third wall C with a handle whose hex has a letter: 0x3E.
      doc.handleSeed.raiseTo(const Handle(0x3D));
      final c = doc.handleSeed.next();
      expect(c.value, 0x3E);
      doc.commands.execute(addWallLocal(
          doc,
          c,
          const WallParams(
              0, 1500.5, 2500.25, 1500.5, 150, Justification.centre),
          place.m));
      final d1 = addDimension(
          doc, AttachedEnd(c, 1, r), AttachedEnd(c, 0, WallSide.centre),
          kind: DimKind.aligned, offset: 200.5, at: place.m);
      final d2 = addDimension(
          doc, AttachedEnd(c, 0, l), fixedAt(plan.at(2000.25, 2500.5), place.m),
          kind: DimKind.aligned, offset: 200.5, at: place.m);
      finish(plan);
      final view = await pumpShell(tester, doc, place.name);
      await select(tester, view, [d1]);
      expect(textAt(tester, 'dimension-end-1'), 'Wall 3E, end, right face');
      expect(textAt(tester, 'dimension-end-2'), 'Wall 3E, start, centreline');
      await select(tester, view, [d2]);
      expect(textAt(tester, 'dimension-end-1'), 'Wall 3E, start, left face');
      expect(textAt(tester, 'dimension-end-2'), 'Fixed');
    });

    testWidgets(
        'PN5 under runtime permissions the switch is read-only; a refused '
        'edit leaves the switch on the model\'s kind, at $place',
        (tester) async {
      final plan = panelPlan(place);
      final doc = plan.doc;
      final [a, _] = plan.walls;
      final d = addDimension(
          doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
          kind: DimKind.aligned, offset: -617.375, at: place.m);
      final e = addDimension(
          doc, AttachedEnd(a, 1, l), fixedAt(plan.at(1000.25, 1500.5), place.m),
          kind: DimKind.aligned, offset: 250.5, at: place.m);
      finish(plan);
      final view = await pumpShell(tester, doc, place.name);
      final p0 = paramsOf(doc, d);

      // Read-only unless both components and geometry are allowed.
      for (final (why, perms) in [
        ('runtime', DraftPermissions.runtime),
        (
          'components denied',
          const DraftPermissions(
              transform: true,
              components: false,
              geometry: true,
              structure: true)
        ),
        (
          'geometry denied',
          const DraftPermissions(
              transform: true,
              components: true,
              geometry: false,
              structure: true)
        ),
      ]) {
        doc.commands.permissions = perms;
        await select(tester, view, [e]);
        await select(tester, view, [d]);
        expect(switchOf(tester).onSelectionChanged, isNull, reason: why);
        await tapKind(tester, 'dimension-horizontal');
        expect(paramsOf(doc, d), p0, reason: why);
        expect(doc.commands.undoDepth, 0, reason: why);
        expect(switchOf(tester).selected, {DimKind.aligned}, reason: why);
      }
      doc.commands.permissions = DraftPermissions.all;
      await select(tester, view, [e]);
      await select(tester, view, [d]);
      expect(switchOf(tester).onSelectionChanged, isNotNull,
          reason: 'the control: editable with every permission');

      // Runtime set with no rebuild: the switch still holds the callback it
      // was built with, and a click that lands before the rebuild calls it.
      // The edit is checked again when it runs: nothing is issued and
      // nothing throws (the document would refuse it with a
      // PermissionDeniedError, which the switch does not catch).
      final stale = switchOf(tester).onSelectionChanged!;
      doc.commands.permissions = DraftPermissions.runtime;
      stale({DimKind.horizontal});
      expect(paramsOf(doc, d), p0, reason: 'stale callback under runtime');
      expect(doc.commands.undoDepth, 0, reason: 'stale callback under runtime');
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      // A permission change alone rebuilds nothing; a reselection does.
      await select(tester, view, [e]);
      await select(tester, view, [d]);
      expect(switchOf(tester).onSelectionChanged, isNull,
          reason: 'read-only once rebuilt');
      doc.commands.permissions = DraftPermissions.all;
      await select(tester, view, [e]);
      await select(tester, view, [d]);

      // The group removed under the panel, the click landing before the
      // panel rebuilds: nothing is issued -- no component on the dead
      // handle -- and nothing escapes.
      doc.commands.execute(deleteObject(doc, d));
      expect(doc.tree[d], isNull);
      await tester.tap(find.byKey(const Key('dimension-horizontal')));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(doc.components.get<DimensionParams>(d), isNull,
          reason: 'no component on the dead handle');
      expect(doc.commands.undoDepth, 1, reason: 'the delete alone');
      expect(section, findsNothing);
    });
  }

  testWidgets(
      'PN5 a refused edit (a loaded dimension whose group holds a fill naming '
      'a wall\'s outline) is caught, and the switch reads the stored kind',
      (tester) async {
    final src = panelPlan(corpusGroups);
    final [a, _] = src.walls;
    final d = addDimension(
        src.doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
        kind: DimKind.aligned, offset: -617.375, at: corpusGroups.m);
    final aFill = kids(src.doc, a)
        .firstWhere((k) => kindOf(src.doc, k) == EntityKind.fill);
    final aOutline = payloadOf(src.doc, aFill).scalars[0];
    // A file no program regenerated: the dimension's group holds a region,
    // then the region's fill is repointed at A's outline (spec 07 D8: a
    // loaded file can name any handle), which the regeneration refuses.
    late Handle stray;
    final file = staleFile(src.doc, (bare) {
      final region = AddRegionCommand.allocate(
          seed: bare.handleSeed,
          owner: d,
          boundaryKind: EntityKind.polyline,
          boundaryPayload: polylinePayload(
              [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)],
              closed: true),
          layer: ReservedHandles.layerZero,
          fillColor: const ByLayerColor(),
          boundaryColor: const ByLayerColor());
      stray = region.fill.handle;
      bare.commands.execute(region);
    });
    final j = jsonDecode(file) as Map<String, Object?>;
    var repointed = 0;
    for (final x in j['entities']! as List) {
      final entity = x as Map<String, Object?>;
      if ((entity['record']! as Map)['handle'] == stray.value) {
        (entity['geometry']! as Map)['scalars'] = [aOutline];
        repointed++;
      }
    }
    expect(repointed, 1);
    final doc = DraftDocumentCodec.decode(j, measurer: FlutterTextMeasurer(),
        registerComponents: (r) {
      PageComponent.register(r);
      parametricCatalog.registerComponents(r);
    });
    final view = await pumpShell(tester, doc, 'refused');
    final p0 = paramsOf(doc, d);
    final before = enc(doc);
    // The premise: the document itself refuses the switch.
    expect(
        () => doc.commands.execute(SetComponentCommand<DimensionParams>(
            d, p0.copyWith(kind: DimKind.horizontal))),
        throwsStateError);
    expect(enc(doc), before);

    await select(tester, view, [d]);
    expect(switchOf(tester).onSelectionChanged, isNotNull);
    await tapKind(tester, 'dimension-horizontal');
    expect(tester.takeException(), isNull);
    expect(switchOf(tester).selected, {DimKind.aligned},
        reason: 'the stored kind');
    expect(paramsOf(doc, d), p0);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 0);
  });
}
