// The table system (spec 14a T12): keeps every table's number upright,
// inside the edit that turns or mirrors the table, as one undo step.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../symbols/seating_component.dart';
import 'table_label.dart';

/// Stacks on the dispatcher's one expander slot (spec 06 D2, 14a F-1):
/// [install] keeps the expander it found (the parametric system's, or none)
/// and wraps what that one returns; [dispose] puts it back.
///
/// **Last in, first out.** The shell installs this after the parametric
/// system and disposes it before; out of order, this would put a disposed
/// system's tear-off back in the slot, so [dispose] asserts that the slot
/// still holds its own.
class TableLabelSystem {
  TableLabelSystem(this.document);

  final DraftDocument document;
  DraftCommand Function(DraftCommand command)? _previous;
  bool _installed = false;

  void install() {
    if (_installed) throw StateError('the table system is installed already');
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
    assert(mine, 'TableLabelSystem disposed out of order (spec 14a T12)');
  }

  DraftCommand _expand(DraftCommand command) {
    final inner = _previous?.call(command) ?? command;
    // The cheap path: a plan with no servable definition has no table.
    if (document.components.withComponent<SeatingComponent>().isEmpty) {
      return inner;
    }
    return TableLabelEdit._(inner);
  }
}

/// An edit and the label stamps it makes necessary (T12): [inner] applies,
/// then every touched table whose label no longer matches
/// [tableLabelStamp] for its transform is re-stamped, by exact `==` on the
/// stored values. Created only by [TableLabelSystem], once per `execute`.
final class TableLabelEdit extends DraftCommand {
  TableLabelEdit._(this.inner);

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
    try {
      for (final h in r.touched) {
        final stamp = _stampFor(target, h);
        if (stamp == null) continue;
        final result = stamp.apply(target);
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
    _stamped = inverses.isNotEmpty;
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

  /// The stamp [h] needs, or null: [h] is a table (a live, root-level
  /// instance of a servable definition) with a `TABLE` label whose rotation
  /// or width factor differs from its transform's stamp.
  static DraftCommand? _stampFor(CommandTarget target, Handle h) {
    final node = target.tree[h];
    if (node is! InstanceNode || node.parent != target.tree.root) return null;
    if (target.components.get<SeatingComponent>(node.definition) == null) {
      return null;
    }
    final label = _labelOf(target, h);
    if (label == null) return null;
    final payload = target.geometry
        .read(target.entities.geomIndexAt(target.entities.slotOf(label)!));
    final next = restampedTableLabel(payload, node.transform);
    return next == null ? null : SetEntityGeometryCommand(label, next);
  }

  /// The lowest-handle `TABLE` ATTRIB [instance] owns (T2). O(entities),
  /// only for a touched table, at command rate.
  static Handle? _labelOf(CommandTarget target, Handle instance) {
    final e = target.entities;
    Handle? best;
    for (final slot in e.liveSlots) {
      if (e.ownerAt(slot) != instance ||
          e.kindAt(slot) != EntityKind.attrib ||
          e.tagAt(slot) != kTableLabelTag) {
        continue;
      }
      final h = e.handleAt(slot);
      if (best == null || h.value < best.value) best = h;
    }
    return best;
  }
}
