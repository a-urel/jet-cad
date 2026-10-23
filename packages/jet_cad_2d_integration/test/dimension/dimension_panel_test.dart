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
// Ported to jet_cad_2d_integration (3a Task 21): PlanEditor's property
// panel over a PlanController with the architecture kit (spec C6, C7).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanLocked;
import 'package:jet_cad_2d_plan/src/chrome/select.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_plans.dart';

const l = WallSide.left, r = WallSide.right;

Finder get section => byKey('section-architecture.dimension');
Finder get value => byKey('property-value');
Finder get kindMenu => byKey('property-kind');
Finder get axes => byKey('property-axes');

String textAt(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

String valueText(WidgetTester tester) => textAt(tester, 'property-value');

PlanSelect<Object?> menuOf(WidgetTester tester) =>
    tester.widget<PlanSelect<Object?>>(kindMenu);

/// A choice of [kind] in the kind menu (DM-R3): open it, tap the item
/// (the menu's copy, the last). A read-only menu does not open: the
/// click lands on nothing, as a disabled segment's did.
Future<void> tapKind(WidgetTester tester, DimKind kind) async {
  final enabled = menuOf(tester).enabled;
  await tester.ensureVisible(kindMenu); // the plan panel's own tapKey
  await tester.tap(kindMenu);
  await tester.pumpAndSettle();
  if (!enabled) return;
  await tester.tap(byKey('property-kind-${kind.name}').last);
  await tester.pumpAndSettle();
}

DimensionParams paramsOf(DraftDocument doc, Handle h) =>
    doc.components.get<DimensionParams>(h)!;

/// The group a dimension sits in: the placement, turned [deg] further.
Transform2 turned(Placement place, double deg) =>
    place.m.multiply(Transform2.rotation(deg * math.pi / 180));

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
      late final Handle a, b, d, d2, broken;
      final c = planOf((doc) {
        setPage(doc, mmPage);
        final walls = buildPlanIn(doc, c2Walls, place: place).walls;
        a = walls[0];
        b = walls[1];
        // From A/0/left (0, 100) to a fixed point (3450.6, 100): aligned,
        // 3450.6 mm, which reads 3451 (half-up to the millimetre, 0.1 from
        // the tie at 3450.5).
        d = addDimension(
            doc, AttachedEnd(a, 0, l), fixedAt(place.at(3450.6, 100), place.m),
            kind: DimKind.aligned, offset: 400.25, at: place.m);
        d2 = addDimension(doc, fixedAt(place.at(500.25, 1500.5), place.m),
            fixedAt(place.at(2500.75, 2200.25), place.m),
            kind: DimKind.horizontal, offset: -250.5, at: place.m);
        // Broken (D15): an attached end with k = 2 generates nothing.
        broken = addDimension(
            doc, AttachedEnd(a, 2, l), fixedAt(place.at(3450.6, 100), place.m),
            kind: DimKind.aligned, offset: 400.25, at: place.m);
      });
      final doc = c.document;
      expect(kids(doc, broken), isEmpty, reason: 'premise: broken');
      expect(dimText(doc, d), '3451', reason: 'premise: the TEXT');
      await pumpPlan(tester, c);

      expect(section, findsNothing, reason: 'none');
      await select(tester, c, [d]);
      expect(section, findsOneWidget);
      expect(tester.widget<Text>(section).data, 'Dimension');
      expect(valueText(tester), '3451');
      expect(
          textAt(tester, 'property-end-1'),
          'Wall ${a.toHex()}, start, '
          'left face');
      expect(textAt(tester, 'property-end-2'), 'Fixed');

      await select(tester, c, [d, d2]);
      expect(section, findsNothing, reason: 'two dimensions');
      await select(tester, c, [d, a]);
      expect(section, findsNothing, reason: 'a dimension and a wall');
      await select(tester, c, [a]);
      expect(section, findsNothing, reason: 'a wall');
      expect(byKey('section-architecture.wall'), findsOneWidget);
      await select(tester, c, [b, d2]);
      expect(section, findsNothing, reason: 'a wall and a dimension');
      await select(tester, c, [broken]);
      expect(section, findsOneWidget, reason: 'a broken dimension');
      expect(valueText(tester), '—', reason: 'a broken dimension');

      // A wall edit rewrites the value in place: A moved 500.25 along the
      // plan's −x (its joint with B broken), so A/0/left is (−500.25, 100)
      // and the value 3450.6 + 500.25 = 3950.85, which reads 3951.
      await select(tester, c, [d]);
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
      late final Handle a, d, e;
      final c = planOf((doc) {
        setPage(doc, mmPage);
        final walls = buildPlanIn(doc, c2Walls, place: place).walls;
        a = walls[0];
        // The non-axis pair (0, 0)-(3000, 1200), aligned, offset −617.375.
        d = addDimension(doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
            kind: DimKind.aligned, offset: -617.375, at: place.m);
        // The inner corner (3900, 100) is both A/1/left and B/0/left; this
        // dimension stores A/1/left and a −0.0 offset (its side the right
        // normal's, R-2), which a switch must keep as they are (D10: a switch
        // re-decides no end).
        e = addDimension(doc, AttachedEnd(a, 1, l),
            fixedAt(place.at(1000.25, 1500.5), place.m),
            kind: DimKind.aligned, offset: -0.0, at: place.m);
      });
      await pumpPlan(tester, c);
      final doc = c.document;
      await select(tester, c, [d]);
      final p0 = paramsOf(doc, d);
      final first = childrenOf(doc, d);
      // Aligned: √(3000² + 1200²) = √10,440,000 = 3231.09.
      expect(valueText(tester), '3231');
      expect(menuOf(tester).value, DimKind.aligned);
      final focus = FocusManager.instance.primaryFocus;

      await tapKind(tester, DimKind.horizontal);
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
      expect(menuOf(tester).value, DimKind.horizontal);
      expect(FocusManager.instance.primaryFocus, focus,
          reason: 'the click leaves the focus where it was');

      await tapKind(tester, DimKind.aligned);
      expect(doc.commands.undoDepth, 2, reason: 'Aligned: one step');
      p = paramsOf(doc, d);
      expect(p, p0, reason: 'back to the stored parameters');
      expect(p.offset, -617.375);
      final back = childrenOf(doc, d);
      expect(back.$1, first.$1, reason: 'the same children');
      expect(back.$2, first.$2, reason: 'their payloads bit for bit');
      expect(back.$3, first.$3);
      expect(valueText(tester), '3231');

      // The current kind: a click issues nothing (the row is a
      // DropdownButton, and the panel issues nothing for a value equal to
      // the stored one), nor does the callback called directly (a click
      // that lands before a rebuild).
      await tapKind(tester, DimKind.aligned);
      expect(doc.commands.undoDepth, 2, reason: 'a click on Aligned');
      menuOf(tester).onChanged(DimKind.aligned);
      await tester.pump();
      await tester.pump();
      expect(doc.commands.undoDepth, 2, reason: 'the callback on Aligned');
      expect(paramsOf(doc, d), p0);

      // The corner end and the −0.0 offset through a switch and back.
      await select(tester, c, [e]);
      final q0 = paramsOf(doc, e);
      await tapKind(tester, DimKind.vertical);
      expect(doc.commands.undoDepth, 3);
      expect(paramsOf(doc, e).a, AttachedEnd(a, 1, l),
          reason: 'the corner end not re-decided');
      expect(paramsOf(doc, e).offset.isNegative, isTrue,
          reason: 'the −0.0 offset kept');
      expect(paramsOf(doc, e), q0.copyWith(kind: DimKind.vertical));
      await tapKind(tester, DimKind.aligned);
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
      // The group's world rotation is the placement's plus the turn: 0 + 30
      // and 0 − 30 at the origin, 23 + 30 = 53 and 23 − 30 = −7 at the
      // corpus placement.
      final (plus, minus) =
          place == origin ? ('30.0', '-30.0') : ('53.0', '-7.0');
      late final List<(String, Handle, String?)> cases;
      final c = planOf((doc) {
        setPage(doc, mmPage);
        buildPlanIn(doc, c2Walls, place: place);
        // A group at the placement's point with world rotation [deg]
        // exactly.
        final o = place.at(500.5, 800.25);
        Transform2 world(double deg) => Transform2.translation(o.x, o.y)
            .multiply(Transform2.rotation(deg * math.pi / 180));
        Handle dim(DimKind kind, Transform2 at) => addDimension(
            doc, const FixedEnd(0.25, 0.5), const FixedEnd(3000.75, 1200.25),
            kind: kind, offset: 300.5, at: at);
        cases = <(String, Handle, String?)>[
          ('horizontal +30', dim(DimKind.horizontal, turned(place, 30)), plus),
          ('vertical +30', dim(DimKind.vertical, turned(place, 30)), plus),
          (
            'horizontal −30',
            dim(DimKind.horizontal, turned(place, -30)),
            minus
          ),
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
      });
      await pumpPlan(tester, c);
      for (final (why, h, want) in cases) {
        await select(tester, c, [h]);
        expect(section, findsOneWidget, reason: why);
        if (want == null) {
          expect(axes, findsNothing, reason: why);
        } else {
          expect(textAt(tester, 'property-axes'), 'Axes turned $want°',
              reason: why);
        }
      }
      // The aligned one switched to horizontal: now linear and turned.
      await select(tester, c, [cases[3].$2]);
      await tapKind(tester, DimKind.horizontal);
      expect(textAt(tester, 'property-axes'), 'Axes turned $plus°');
      expect(menuOf(tester).value, DimKind.horizontal,
          reason: 'the switch still reads Horizontal');
    });

    testWidgets(
        'PN4 the end lines read Wall <hex>, start or end, left face, '
        'centreline or right face, or Fixed, at $place', (tester) async {
      late final Handle wc, d1, d2;
      final c = planOf((doc) {
        setPage(doc, mmPage);
        buildPlanIn(doc, c2Walls, place: place);
        // A third wall C with a handle whose hex has a letter: 0x3E.
        doc.handleSeed.raiseTo(const Handle(0x3D));
        wc = doc.handleSeed.next();
        doc.commands.execute(addWallLocal(
            doc,
            wc,
            const WallParams(
                0, 1500.5, 2500.25, 1500.5, 150, Justification.centre),
            place.m));
        d1 = addDimension(
            doc, AttachedEnd(wc, 1, r), AttachedEnd(wc, 0, WallSide.centre),
            kind: DimKind.aligned, offset: 200.5, at: place.m);
        d2 = addDimension(doc, AttachedEnd(wc, 0, l),
            fixedAt(place.at(2000.25, 2500.5), place.m),
            kind: DimKind.aligned, offset: 200.5, at: place.m);
      });
      expect(wc.value, 0x3E);
      await pumpPlan(tester, c);
      await select(tester, c, [d1]);
      expect(textAt(tester, 'property-end-1'), 'Wall 3E, end, right face');
      expect(textAt(tester, 'property-end-2'), 'Wall 3E, start, centreline');
      await select(tester, c, [d2]);
      expect(textAt(tester, 'property-end-1'), 'Wall 3E, start, left face');
      expect(textAt(tester, 'property-end-2'), 'Fixed');
    });

    testWidgets(
        'PN5 under runtime permissions the switch is read-only; a refused '
        'edit leaves the switch on the model\'s kind, at $place',
        (tester) async {
      late final Handle d, e;
      final c = planOf((doc) {
        setPage(doc, mmPage);
        final [a, _] = buildPlanIn(doc, c2Walls, place: place).walls;
        d = addDimension(doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
            kind: DimKind.aligned, offset: -617.375, at: place.m);
        e = addDimension(doc, AttachedEnd(a, 1, l),
            fixedAt(place.at(1000.25, 1500.5), place.m),
            kind: DimKind.aligned, offset: 250.5, at: place.m);
      });
      await pumpPlan(tester, c);
      final doc = c.document;
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
        await select(tester, c, [e]);
        await select(tester, c, [d]);
        expect(menuOf(tester).enabled, isFalse, reason: why);
        await tapKind(tester, DimKind.horizontal);
        expect(paramsOf(doc, d), p0, reason: why);
        expect(doc.commands.undoDepth, 0, reason: why);
        expect(menuOf(tester).value, DimKind.aligned, reason: why);
      }
      doc.commands.permissions = DraftPermissions.all;
      await select(tester, c, [e]);
      await select(tester, c, [d]);
      expect(menuOf(tester).enabled, isTrue,
          reason: 'the control: editable with every permission');

      // Runtime set with no rebuild: the switch still holds the callback it
      // was built with, and a click that lands before the rebuild calls it.
      // The edit is checked again when it runs: nothing is issued and
      // nothing throws (the document would refuse it with a
      // PermissionDeniedError, which the switch does not catch).
      final stale = menuOf(tester).onChanged;
      doc.commands.permissions = DraftPermissions.runtime;
      stale(DimKind.horizontal);
      expect(paramsOf(doc, d), p0, reason: 'stale callback under runtime');
      expect(doc.commands.undoDepth, 0, reason: 'stale callback under runtime');
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      // A permission change alone rebuilds nothing; a reselection does.
      await select(tester, c, [e]);
      await select(tester, c, [d]);
      expect(menuOf(tester).enabled, isFalse, reason: 'read-only once rebuilt');
      doc.commands.permissions = DraftPermissions.all;
      await select(tester, c, [e]);
      await select(tester, c, [d]);

      // The group removed under the panel, the click landing before the
      // panel rebuilds: nothing is issued -- no component on the dead
      // handle -- and nothing escapes.
      final click = menuOf(tester).onChanged;
      doc.commands.execute(deleteObject(doc, d));
      expect(doc.tree[d], isNull);
      click(DimKind.horizontal);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(doc.components.get<DimensionParams>(d), isNull,
          reason: 'no component on the dead handle');
      expect(doc.commands.undoDepth, 1, reason: 'the delete alone');
      expect(section, findsNothing);
    });
  }

  // PN5-open replaces today's "PN5 a refused edit" (the notes' Task 18
  // rule, as RN5-open). Decided: the old premise (an engine StateError
  // reaching a live dimension's kind switch) cannot exist under C1.10's
  // freeze at open: the plan opens a dimension whose regeneration the
  // engine refuses frozen, so its kind switch is the lock's refusal and it
  // shows no Dimension section. No live dimension's kind switch can be
  // refused by the type or the document (every kind is one of the menu's
  // values; a regeneration the engine refuses is frozen at open), so the
  // old intent's live half has no premise; the panel's catch of a refused
  // edit on a live dimension is PN5's stale callback under runtime.
  testWidgets(
      'PN5-open a loaded dimension whose group holds a fill naming a '
      'wall\'s outline opens frozen: its kind switch is locked, it shows no '
      'Dimension section', (tester) async {
    late final Handle a, d;
    final src = planOf((doc) {
      setPage(doc, mmPage);
      a = buildPlanIn(doc, c2Walls, place: corpusGroups).walls[0];
      d = addDimension(doc, const FixedEnd(0, 0), const FixedEnd(3000, 1200),
          kind: DimKind.aligned, offset: -617.375, at: corpusGroups.m);
    });
    final aFill = kids(src.document, a)
        .firstWhere((k) => kindOf(src.document, k) == EntityKind.fill);
    final aOutline = payloadOf(src.document, aFill).scalars[0];
    // A file no program regenerated: the dimension's group holds a region,
    // then the region's fill is repointed at A's outline (spec 07 D8: a
    // loaded file can name any handle), which the regeneration refuses.
    late Handle stray;
    final file = stalePlan(src.save(), (bare) {
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
    final c = architectureController(json: jsonEncode(j));
    addTearDown(c.dispose);
    await pumpPlan(tester, c);
    final doc = c.document;
    // ignore: invalid_use_of_internal_member
    expect(c.frozen, contains(d), reason: 'frozen at open');
    // ignore: invalid_use_of_internal_member
    expect(c.frozen, isNot(contains(a)));
    final p0 = paramsOf(doc, d);
    final before = canon(doc);
    // The premise: the plan refuses the switch (the lock, spec C1.10).
    expect(
        () => doc.commands.execute(SetComponentCommand<DimensionParams>(
            d, p0.copyWith(kind: DimKind.horizontal))),
        throwsA(isA<PlanLocked>()));
    expect(canon(doc), before);

    await select(tester, c, [d]);
    expect(tester.takeException(), isNull);
    expect(section, findsNothing, reason: 'a frozen dimension has no section');
    expect(paramsOf(doc, d), p0);
    expect(canon(doc), before);
    expect(doc.commands.undoDepth, 0);
  });
}
