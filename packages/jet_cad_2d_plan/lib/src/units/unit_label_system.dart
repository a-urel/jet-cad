// The unit label system (spec 2b S2 "The label system"): keeps every placed
// unit's label upright, inside the edit that turns or mirrors the unit, as
// one undo step. Ported from jet_cad_floor_plan's
// tables/table_label_system.dart (TableLabelSystem, TableLabelEdit) and
// table_label.dart (restampedTableLabel): the servable check is the
// definition's UnitComponent, the root rule is kept. A generated unit's
// label is its type's, restamped by its regeneration (spec S1). A deleted
// unit's data and colour are not this file's: the delete takes them
// (`RemoveNodeCommand`, node-components D-1).
//
// No Flutter import: Dart over package:jet_cad_2d and the kit's model.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show UnitComponent, kUnitLabelMaxHeight, unitLabelStamp;

import 'unit_label.dart' show unitLabelOf;

/// [payload] re-stamped for [placement]: anchor and height kept, rotation
/// and width factor replaced. Null when they already match by exact `==`
/// (stored values), so a translation writes nothing.
GeometryPayload? restampedUnitLabel(
    GeometryPayload payload, Transform2 placement) {
  final s = unitLabelStamp(placement);
  final scalars = payload.scalars;
  if (scalars.length >= 3 &&
      scalars[1] == s.rotation &&
      scalars[2] == s.widthFactor) {
    return null;
  }
  return GeometryPayload(
    coords: Float64List.fromList(payload.coords),
    scalars: Float64List.fromList([
      scalars.isEmpty ? kUnitLabelMaxHeight : scalars[0],
      s.rotation,
      s.widthFactor,
    ]),
  );
}

/// Stacks on the dispatcher's one expander slot (spec 06 D2, 14a F-1):
/// [install] keeps the expander it found (the parametric system's, or none)
/// and wraps what that one returns; [dispose] puts it back.
///
/// **Last in, first out.** The session installs this after the parametric
/// system and before the lock expander (parametric system → this → lock
/// expander) and disposes in reverse; out of order, this would put a
/// disposed system's tear-off back in the slot, so [dispose] asserts that
/// the slot still holds its own.
final class UnitLabelSystem {
  UnitLabelSystem(this.document);

  final DraftDocument document;
  DraftCommand Function(DraftCommand command)? _previous;
  bool _installed = false;

  void install() {
    if (_installed) {
      throw StateError('the unit label system is installed already');
    }
    _previous = document.commands.expander;
    document.commands.expander = _expand;
    _installed = true;
  }

  /// Puts the expander [install] found back, only if the slot still holds
  /// this system's own tear-off.
  void dispose() {
    if (!_installed) return;
    _installed = false;
    final mine = document.commands.expander == _expand;
    if (mine) document.commands.expander = _previous;
    _previous = null;
    assert(mine, 'UnitLabelSystem disposed out of order (spec 2b S2)');
  }

  DraftCommand _expand(DraftCommand command) {
    final inner = _previous?.call(command) ?? command;
    // The cheap path: a plan with no unit definition has no placed unit.
    if (document.components.withComponent<UnitComponent>().isEmpty) {
      return inner;
    }
    return UnitLabelEdit._(inner);
  }
}

/// An edit and the derived commands it makes necessary: [inner] applies,
/// then, per touched handle in `touched`'s order, a placed unit whose label
/// no longer matches [unitLabelStamp] for its transform is re-stamped, by
/// exact `==` on the stored values. All or nothing; undo restores the
/// stamps and the edit. Created only by [UnitLabelSystem], once per
/// `execute`.
final class UnitLabelEdit extends DraftCommand {
  UnitLabelEdit._(this.inner);

  final DraftCommand inner;
  bool _stamped = false;

  @override
  String get label => inner.label;

  /// [inner]'s own: a stamp is derived data inside the edit that causes it
  /// and adds no authority (T12, F-2). A translation never stamps.
  @override
  Set<Capability> get capabilities => inner.capabilities;

  /// Raised to `geometry` when a label was written, so the index does not
  /// skip it (F-2's rule).
  @override
  Capability get capability =>
      _stamped && inner.capability.index < Capability.geometry.index
          ? Capability.geometry
          : inner.capability;

  @override
  CommandResult apply(CommandTarget target) {
    final r = inner.apply(target);
    final inverses = <DraftCommand>[];
    final written = <Handle>{};
    var stamps = 0;
    try {
      for (final h in r.touched) {
        final DraftCommand derived;
        if (_stampFor(target, h) case final stamp?) {
          derived = stamp;
          stamps++;
        } else {
          continue;
        }
        final result = derived.apply(target);
        inverses.add(result.inverse);
        written.addAll(result.touched);
      }
    } catch (_) {
      // All or nothing: the stamps written so far, then the edit itself.
      for (final inverse in inverses.reversed) {
        inverse.apply(target);
      }
      r.inverse.apply(target);
      rethrow;
    }
    _stamped = stamps > 0;
    if (inverses.isEmpty) return r;
    // A replay with the edit's own authority: undo and redo need exactly
    // what the edit needed, not the stamps' `geometry` (review R-5).
    return CommandResult(
      inverse: ParametricReplay(
          CompoundCommand([...inverses.reversed, r.inverse], label: label),
          inner.capabilities),
      touched: {...r.touched, ...written},
    );
  }

  /// The stamp [h] needs, or null: [h] is a placed unit (a live, root-level
  /// instance of a definition carrying `jetcad.unit`) with a `UNIT` label
  /// whose rotation or width factor differs from its transform's stamp.
  static DraftCommand? _stampFor(CommandTarget target, Handle h) {
    final node = target.tree[h];
    if (node is! InstanceNode || node.parent != target.tree.root) return null;
    if (target.components.get<UnitComponent>(node.definition) == null) {
      return null;
    }
    final label = unitLabelOf(target, h);
    if (label == null) return null;
    final payload = target.geometry
        .read(target.entities.geomIndexAt(target.entities.slotOf(label)!));
    final next = restampedUnitLabel(payload, node.transform);
    return next == null ? null : SetEntityGeometryCommand(label, next);
  }
}
