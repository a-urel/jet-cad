// Spec P2 "Permissions" (select gates: move, rotate, reshape, delete) and
// P4 "Locks" (the select gates refuse a locked object), Task 12. The gates
// read the permissions live, and the selection's lock state from a cache
// recomputed on a selection or a lock notification. Fixtures: lines off the
// origin; a nested key whose chain names a locked group.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/tools/plan_select_gates.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class Rig {
  Rig() {
    document = DraftDocument.empty();
    for (final (a, b) in [
      (Vector2(4100.5, -1250.25), Vector2(4700.75, -980.5)),
      (Vector2(5200.25, -1610.75), Vector2(5900.5, -1300.25)),
    ]) {
      final cmd = addDrafted(document, EntityKind.line, linePayload(a, b),
          layer: ReservedHandles.layerZero);
      document.commands.execute(cmd);
      lines.add(cmd.record.handle);
    }
    selection = SelectionController(document);
    gates = PlanSelectGates(
        permissions: () => permissions, selection: selection, locked: locked);
    addTearDown(() {
      gates.dispose();
      selection.dispose();
      locked.dispose();
    });
  }

  late final DraftDocument document;
  late final SelectionController selection;
  late final PlanSelectGates gates;
  final List<Handle> lines = [];
  final ValueNotifier<Set<Handle>> locked = ValueNotifier(const {});
  PlanPermissions permissions = PlanPermissions.full;

  Map<String, bool> get open => {
        'move': gates.move,
        'rotate': gates.rotate,
        'reshape': gates.reshape,
        'delete': gates.delete,
      };
}

const Map<String, bool> kAllOpen = {
  'move': true,
  'rotate': true,
  'reshape': true,
  'delete': true,
};
const Map<String, bool> kAllShut = {
  'move': false,
  'rotate': false,
  'reshape': false,
  'delete': false,
};

void main() {
  test('PM-8 each gate reads its own flag, live', () {
    final r = Rig();
    expect(r.open, kAllOpen);
    for (final name in kAllOpen.keys) {
      r.permissions = switch (name) {
        'move' => PlanPermissions.full.copyWith(move: false),
        'rotate' => PlanPermissions.full.copyWith(rotate: false),
        'reshape' => PlanPermissions.full.copyWith(reshape: false),
        _ => PlanPermissions.full.copyWith(delete: false),
      };
      // M-PM8: `PlanSelectGates.delete` drops `_permissions().delete &&`.
      expect(r.open, {...kAllOpen, name: false}, reason: name);
    }
    r.permissions = PlanPermissions.readOnly;
    expect(r.open, kAllShut);
    expect(r.gates.idleKeys, isTrue, reason: 'the keys are the shortcuts');
    r.gates.idleKeys = false;
    expect(r.gates.idleKeys, isFalse);
    // The pick and the band are the select tool's own.
    expect(r.gates.restrictsPick, isFalse);
  });

  test(
      'PM-9 a selection holding a locked object shuts every gate; a lock '
      'change or a selection change recomputes it', () {
    final r = Rig();
    r.selection.replace([SelectionKey.root(r.lines[0])]);
    expect(r.open, kAllOpen);
    // M-PM9a: `_locked.addListener(_recompute)` dropped: the lock arrives
    // after the selection.
    r.locked.value = {r.lines[0]};
    expect(r.gates.selectionLocked, isTrue);
    // M-PM9b: `&& super.move` (the lock) dropped from `move`.
    expect(r.open, kAllShut);
    // Another, unlocked object alone: open again.
    r.selection.replace([SelectionKey.root(r.lines[1])]);
    expect(r.open, kAllOpen);
    // Both: one locked object is enough.
    r.selection.replace(
        [SelectionKey.root(r.lines[1]), SelectionKey.root(r.lines[0])]);
    expect(r.open, kAllShut);
    r.locked.value = const {};
    expect(r.open, kAllOpen);
  });

  test('PM-10 a key inside a locked object (its chain) is locked too', () {
    final r = Rig();
    const group = Handle(0x7a31);
    r.locked.value = {group};
    final nested = SelectionKey(
        chain: Uint32List.fromList([group.value, 0x7a40]),
        chainLength: 2,
        target: r.lines[1]);
    r.selection.replace([nested]);
    // M-PM10: the chain loop of `_recompute` dropped.
    expect(r.gates.selectionLocked, isTrue);
    expect(r.open, kAllShut);
  });

  test('PM-11 dispose removes both listeners', () {
    final document = DraftDocument.empty();
    final selection = SelectionController(document);
    final locked = ValueNotifier<Set<Handle>>(const {});
    final gates = PlanSelectGates(
        permissions: () => PlanPermissions.full,
        selection: selection,
        locked: locked);
    gates.dispose();
    // A disposed gates object left as a listener would recompute here; the
    // notifiers report no listener instead.
    // ignore: invalid_use_of_protected_member
    expect(selection.hasListeners, isFalse);
    // ignore: invalid_use_of_protected_member
    expect(locked.hasListeners, isFalse);
    selection.dispose();
    locked.dispose();
  });
}
