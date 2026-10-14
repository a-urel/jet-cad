// Ported from jet_cad_floor_plan's test/host/controller_test.dart (2b Task
// 12, spec S3 "Service state"): the units' statuses (C15) and the focus
// (zone spec Z10: CF1, CF2, CF5), by label; the new SS-dup-label-status
// pins a status on a label two units share and none on an unlabelled
// unit (spec S2 "Unlabelled, duplicate and bad labels"). The plan is
// `servicePlanText`: tables turned and mirrored off the origin; the focus
// tests stand under a camera off the identity.
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/harness.dart' show controllerFor;
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit;

/// Today's `zoned`: the plan under a camera off the identity, as
/// `zoneCamera()` was.
PlanController zoned(WidgetTester tester) {
  final c = controllerFor(kits: [testKit()], json: servicePlanText());
  c.camera.value = ViewportTransform(
      worldToScreenMatrix:
          const Transform2(0.0375, 0, 0, -0.0375, 612.5, 431.25));
  return c;
}

void main() {
  testWidgets(
      'SS-C15 statuses are not plan state: no revision, dirty, history or '
      'json change; labels trimmed; kept across a switch and a load (M-14d)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    final json = c.save();
    final revision = c.revision.value;
    var heard = 0;
    c.unitStatuses.addListener(() => heard++);
    c.setUnitStatus({' 1 ': UnitStatus(color: const Color(0xFFE53935))});
    await tester.pump();
    expect(heard, 1);
    expect(c.unitStatuses.value.keys, ['1']);
    expect(c.revision.value, revision);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.save(), json);
    c.setMode(PlanMode.service);
    c.load(servicePlanText());
    expect(c.unitStatuses.value.keys, ['1']);
    await tester.pump();
  });

  // Zone spec Z10: the focus.

  testWidgets(
      'SS-CF1 setUnitFocus trims, drops blanks and copies into an '
      'unmodifiable set; {} and {\'\'} are a focus with no unit, not none; '
      'every call notifies, an equal set or a second null included (M-Z34, '
      'M-Z26)', (tester) async {
    final c = zoned(tester);
    expect(c.unitFocus.value, isNull, reason: 'no focus at first');
    var heard = 0;
    c.unitFocus.addListener(() => heard++);
    c.setUnitFocus({' 7 ', '', '  ', '3'});
    expect(c.unitFocus.value, {'7', '3'});
    expect(() => c.unitFocus.value!.add('2'), throwsUnsupportedError);
    c.setUnitFocus({'3', '7'});
    expect(heard, 2, reason: 'an equal set notifies');
    for (final none in [
      <String>{},
      {''},
      {' ', ''}
    ]) {
      c.setUnitFocus(none);
      expect(c.unitFocus.value, isNotNull, reason: '$none is a focus');
      expect(c.unitFocus.value, isEmpty, reason: '$none');
    }
    c.setUnitFocus(null);
    c.setUnitFocus(null);
    expect(c.unitFocus.value, isNull);
    expect(heard, 7, reason: 'every call');
  });

  testWidgets(
      'SS-CF2 the host\'s set is copied: changing it after the call changes '
      'nothing (M-Z35)', (tester) async {
    final c = zoned(tester);
    final mine = {'7', '3'};
    c.setUnitFocus(mine);
    mine
      ..remove('7')
      ..add('A1');
    expect(c.unitFocus.value, {'7', '3'});
  });

  testWidgets('SS-CF5 the focus is disposed with the controller',
      (tester) async {
    final c = PlanController(kits: [testKit()], json: servicePlanText());
    final focus = c.unitFocus as ChangeNotifier;
    c.dispose();
    expect(() => focus.addListener(() {}), throwsFlutterError);
  });

  testWidgets(
      'SS-dup-label-status a label two units share: a status on each, the '
      'group\'s over it, none for an unlabelled unit; a group lists the '
      'label once and select takes both', (tester) async {
    final c = controllerFor(
        kits: [testKit()],
        json: servicePlanText(duplicate: true, unlabelled: true));
    final red = UnitStatus(color: const Color(0xFFE53935), caption: 'Bill');
    final blue = UnitStatus(color: const Color(0x801E88E5));
    c.setUnitStatus({'2': red, '': blue});
    c.setMode(PlanMode.service);
    final twos = [
      for (final u in c.unitIndex.units)
        if (u.text == '2') u
    ];
    expect(twos, hasLength(2), reason: 'premise: a label two units share');
    for (final u in twos) {
      expect(c.statusOf(u), red);
    }
    final bare = c.unitIndex.units.singleWhere((u) => u.text == null);
    // M-SS3: `statusOfUnit` reads an unlabelled unit as ''.
    expect(c.statusOf(bare), isNull);
    c.setUnitGroups({
      'g': UnitGroup(members: {'2', '1'})
    });
    c.setGroupStatus({'g': blue});
    // M-SS4: the unit's own status wins over its group's.
    for (final u in twos) {
      expect(c.statusOf(u), blue);
    }
    expect(c.selectableMembers('g'), {'1', '2'},
        reason: 'a shared label listed once');
    c.select({'2'});
    expect(c.activeSelection.keys, hasLength(3), reason: '1 and both 2s');
    expect(c.selectedUnits.value, {'1', '2'});
    await tester.pump();
  });
}
