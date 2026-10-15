// Spec P2 "Permissions" (Task 12): PlanPermissions, read field by field
// against the spec's list, written out here and never read from the code
// under test. Modelled on jet_cad_floor_plan's editor_capabilities_test
// EC2-EC5; the type is new (P7 moves the panels, the gallery and the
// drafting aids to the widgets' options, and the tables-only fields to 2b).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftPermissions;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanGate;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

typedef P = PlanPermissions;

/// Every flag, in declaration order.
const List<String> kFlagNames = [
  'move',
  'rotate',
  'mirror',
  'reshape',
  'delete',
  'changeLayer',
  'recolor',
  'editLayers',
  'editPage',
  'relabel',
  'undo',
  'export',
  'print',
  'selectUnitsOnly',
  'serviceMove',
  'serviceMerge',
];

Map<String, bool> flagsOf(P p) => {
      'move': p.move,
      'rotate': p.rotate,
      'mirror': p.mirror,
      'reshape': p.reshape,
      'delete': p.delete,
      'changeLayer': p.changeLayer,
      'recolor': p.recolor,
      'editLayers': p.editLayers,
      'editPage': p.editPage,
      'relabel': p.relabel,
      'undo': p.undo,
      'export': p.export,
      'print': p.print,
      'selectUnitsOnly': p.selectUnitsOnly,
      'serviceMove': p.serviceMove,
      'serviceMerge': p.serviceMerge,
    };

P copyFlag(P p, String name, bool v) => switch (name) {
      'move' => p.copyWith(move: v),
      'rotate' => p.copyWith(rotate: v),
      'mirror' => p.copyWith(mirror: v),
      'reshape' => p.copyWith(reshape: v),
      'delete' => p.copyWith(delete: v),
      'changeLayer' => p.copyWith(changeLayer: v),
      'recolor' => p.copyWith(recolor: v),
      'editLayers' => p.copyWith(editLayers: v),
      'editPage' => p.copyWith(editPage: v),
      'relabel' => p.copyWith(relabel: v),
      'undo' => p.copyWith(undo: v),
      'export' => p.copyWith(export: v),
      'print' => p.copyWith(print: v),
      'selectUnitsOnly' => p.copyWith(selectUnitsOnly: v),
      'serviceMove' => p.copyWith(serviceMove: v),
      'serviceMerge' => p.copyWith(serviceMerge: v),
      _ => throw ArgumentError(name),
    };

/// The flag each gate reads (spec P3: a gate names a PlanPermissions flag).
const Map<PlanGate, String> kGateFlag = {
  PlanGate.move: 'move',
  PlanGate.rotate: 'rotate',
  PlanGate.mirror: 'mirror',
  PlanGate.reshape: 'reshape',
  PlanGate.delete: 'delete',
  PlanGate.changeLayer: 'changeLayer',
  PlanGate.recolor: 'recolor',
  PlanGate.editLayers: 'editLayers',
  PlanGate.editPage: 'editPage',
  PlanGate.relabel: 'relabel',
};

/// readOnly's flags, as spec P2 and today's S-12 list them (relabel is
/// today's renumber, off in readOnly).
const Map<String, bool> kReadOnly = {
  'move': false,
  'rotate': false,
  'mirror': false,
  'reshape': false,
  'delete': false,
  'changeLayer': false,
  'recolor': false,
  'editLayers': false,
  'editPage': false,
  'relabel': false,
  'undo': false,
  'export': true,
  'print': true,
  'selectUnitsOnly': false,
  'serviceMove': true,
  'serviceMerge': true,
};

/// unitsOnly's flags (today's tablesOnly, editor_capabilities.dart:175-190,
/// restricted to PlanPermissions' fields; spec S4).
const Map<String, bool> kUnitsOnly = {
  'move': true,
  'rotate': true,
  'mirror': false,
  'reshape': false,
  'delete': true,
  'changeLayer': false,
  'recolor': true,
  'editLayers': false,
  'editPage': false,
  'relabel': true,
  'undo': true,
  'export': true,
  'print': true,
  'selectUnitsOnly': true,
  'serviceMove': true,
  'serviceMerge': true,
};

void main() {
  test('PM-1 full and readOnly, field by field', () {
    expect(P.full.tools, isNull, reason: 'every tool');
    expect(flagsOf(P.full),
        {for (final n in kFlagNames) n: n != 'selectUnitsOnly'});
    expect(const P(), P.full);
    // M-PM1: readOnly's `undo: false` dropped.
    expect(P.readOnly.tools, {'plan.select'});
    expect(flagsOf(P.readOnly), kReadOnly);
    // EC2's tablesOnly half (editor_capabilities_test.dart:137-160), on
    // PlanPermissions' fields.
    expect(P.unitsOnly.tools, {'plan.select', 'plan.symbol'});
    // M-PM1b: unitsOnly's `selectUnitsOnly: true` dropped.
    expect(flagsOf(P.unitsOnly), kUnitsOnly);
  });

  test('PM-2 copyWith replaces exactly the field it names; null keeps', () {
    for (final name in kFlagNames) {
      for (final base in [P.full, P.readOnly, P.unitsOnly]) {
        final before = flagsOf(base);
        final after = flagsOf(copyFlag(base, name, !before[name]!));
        // M-PM2: `move: move ?? this.move` written `move: this.move`.
        expect(after, {...before, name: !before[name]!},
            reason: '$name on $base');
        expect(copyFlag(base, name, before[name]!), base, reason: name);
      }
    }
    final some = P.full.copyWith(tools: {'plan.select', 'plan.line'});
    expect(some.tools, {'plan.select', 'plan.line'});
    expect(flagsOf(some), flagsOf(P.full));
    // A null argument keeps (Flutter's convention): start from full to
    // allow every tool again.
    expect(P.readOnly.copyWith().tools, {'plan.select'});
    expect(P.readOnly.copyWith(tools: null).tools, {'plan.select'});
    // The set given is copied, unmodifiable.
    final given = {'plan.select', 'plan.arc'};
    final copied = P.full.copyWith(tools: given);
    given.add('plan.text');
    expect(copied.tools, {'plan.select', 'plan.arc'});
    expect(() => copied.tools!.add('plan.circle'), throwsUnsupportedError);
  });

  test('PM-3 == and hashCode over every field; the tools as a set', () {
    final a = P.full.copyWith(tools: {'plan.line', 'plan.select', 'acme.x'});
    final b = P.full.copyWith(tools: {'acme.x', 'plan.select', 'plan.line'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    // M-PM3: `setEquals(other.tools, tools) &&` dropped from ==.
    expect(a == P.full.copyWith(tools: {'plan.select', 'plan.line'}), isFalse);
    expect(a == P.full, isFalse, reason: 'a set is not "every tool"');
    for (final name in kFlagNames) {
      // Each flag turned from full's value (selectUnitsOnly is off there).
      final changed = copyFlag(P.full, name, !flagsOf(P.full)[name]!);
      expect(changed == P.full, isFalse, reason: name);
      expect(P.full == changed, isFalse, reason: name);
    }
    expect(P.full == P.readOnly, isFalse);
    expect(identical(P.readOnly, P.readOnly), isTrue);
    expect(P.unitsOnly == P.readOnly, isFalse);
    expect(identical(P.unitsOnly, P.unitsOnly), isTrue);
    expect(P.unitsOnly, P.unitsOnly.copyWith());
  });

  test('PM-4 allowsTool: select always; null allows every id; a set its own',
      () {
    for (final id in ['plan.select', 'plan.line', 'acme.wall', 'x.y']) {
      expect(P.full.allowsTool(id), isTrue, reason: id);
    }
    // M-PM4: `id == PlanToolIds.select ||` dropped.
    final none = P.full.copyWith(tools: const <String>{});
    expect(none.allowsTool('plan.select'), isTrue);
    expect(none.allowsTool('plan.line'), isFalse);
    expect(P.readOnly.allowsTool('plan.select'), isTrue);
    expect(P.readOnly.allowsTool('plan.symbol'), isFalse);
    final some = P.full.copyWith(tools: {'acme.wall'});
    expect(some.allowsTool('acme.wall'), isTrue);
    expect(some.allowsTool('acme.door'), isFalse);
    expect(some.allowsTool('plan.select'), isTrue);
  });

  test("PM-5 allows(gate) reads that gate's own flag, and only it", () {
    for (final MapEntry(key: gate, value: flag) in kGateFlag.entries) {
      final off = copyFlag(P.full, flag, false);
      for (final other in PlanGate.values) {
        // M-PM5: the `move` and `rotate` arms of `allows` swapped.
        expect(off.allows(other), other != gate,
            reason: '$flag off, asking $other');
      }
    }
    expect(kGateFlag.keys.toSet(), PlanGate.values.toSet(),
        reason: 'premise: every gate is listed');
  });

  test(
      'PM-6 draft: no edit flag and no tool but select is the engine\'s '
      'readOnly; any edit flag or any other tool opens every group', () {
    // M-PM6a: `draft` always DraftPermissions.all.
    expect(P.readOnly.draft, same(DraftPermissions.readOnly));
    expect(P.readOnly.edits, isFalse);
    expect(P.full.draft, same(DraftPermissions.all));
    for (final name in kFlagNames.take(10)) {
      // move .. relabel: each alone is an edit.
      final one = copyFlag(P.readOnly, name, true);
      expect(one.edits, isTrue, reason: name);
      expect(one.draft, same(DraftPermissions.all), reason: name);
    }
    for (final name in [
      'undo',
      'export',
      'print',
      'selectUnitsOnly',
      'serviceMove',
      'serviceMerge'
    ]) {
      final one = copyFlag(P.readOnly, name, !kReadOnly[name]!);
      expect(one.draft, same(DraftPermissions.readOnly),
          reason: '$name is not an edit');
    }
    // M-PM6b: the tools term dropped from `edits`.
    final drawing = P.readOnly.copyWith(tools: {'plan.select', 'plan.line'});
    expect(drawing.draft, same(DraftPermissions.all));
    final everyTool = const P(
        move: false,
        rotate: false,
        mirror: false,
        reshape: false,
        delete: false,
        changeLayer: false,
        recolor: false,
        editLayers: false,
        editPage: false,
        relabel: false);
    expect(everyTool.tools, isNull);
    expect(everyTool.draft, same(DraftPermissions.all),
        reason: 'null tools allows the drawing tools');
  });

  test('PM-7 toString names the fields that differ from full', () {
    expect(P.full.toString(), 'PlanPermissions()');
    expect(P.full.copyWith(reshape: false).toString(),
        'PlanPermissions(reshape: false)');
    expect(P.full.copyWith(undo: false, move: false).toString(),
        'PlanPermissions(move: false, undo: false)');
    expect(
        P.readOnly.toString(),
        'PlanPermissions(tools: {plan.select}, move: false, rotate: false, '
        'mirror: false, reshape: false, delete: false, changeLayer: false, '
        'recolor: false, editLayers: false, editPage: false, relabel: false, '
        'undo: false)');
    // The tools sorted, so the text is stable whatever the set's order.
    expect(P.full.copyWith(tools: {'plan.text', 'acme.x'}).toString(),
        'PlanPermissions(tools: {acme.x, plan.text})');
    // EC5's tablesOnly text (editor_capabilities_test.dart:266-271), on
    // PlanPermissions' fields: a restriction prints when on.
    // M-PM7b: toString printing only the flags that are false.
    expect(
        P.unitsOnly.toString(),
        'PlanPermissions(tools: {plan.select, plan.symbol}, mirror: false, '
        'reshape: false, changeLayer: false, editLayers: false, '
        'editPage: false, selectUnitsOnly: true)');
  });

  // EC3b (editor_capabilities_test.dart:386-435): two bases whose flags
  // alternate, so a field copied from its neighbour is seen.
  test(
      'EC3b copyWith on two bases whose flags alternate: no argument keeps '
      'every field, each flag replaces that field alone', () {
    P alternating(bool first) {
      final v = [for (var i = 0; i < kFlagNames.length; i++) i.isEven == first];
      return P(
        tools: const {'plan.select', 'plan.line', 'plan.symbol'},
        move: v[0],
        rotate: v[1],
        mirror: v[2],
        reshape: v[3],
        delete: v[4],
        changeLayer: v[5],
        recolor: v[6],
        editLayers: v[7],
        editPage: v[8],
        relabel: v[9],
        undo: v[10],
        export: v[11],
        print: v[12],
        selectUnitsOnly: v[13],
        serviceMove: v[14],
        serviceMerge: v[15],
      );
    }

    for (final first in [true, false]) {
      final base = alternating(first);
      final flags = flagsOf(base);
      for (final (i, name) in kFlagNames.indexed) {
        expect(flags[name], i.isEven == first, reason: name);
      }
      expect(base.relabel, isNot(base.editPage));
      final kept = base.copyWith();
      expect(flagsOf(kept), flags, reason: 'copyWith() on $base');
      expect(kept.tools, {'plan.select', 'plan.line', 'plan.symbol'});
      for (final name in kFlagNames) {
        // M-PM2b: `serviceMerge: serviceMerge ?? this.serviceMove`.
        expect(flagsOf(copyFlag(base, name, !flags[name]!)),
            {...flags, name: !flags[name]!},
            reason: '$name on $base');
      }
    }
  });
}
