import '../core/handle.dart';
import '../store/entity_store.dart' show DuplicateHandleError;
import 'command.dart';
import 'node.dart';
import 'object_layer.dart';
import 'style.dart';
import 'tables.dart';

/// The longest layer name, in UTF-16 code units (`String.length`), that a
/// user may give (spec 12b D4). DXF's own limit.
const int kMaxLayerNameLength = 255;

/// The characters DXF forbids in a table name (spec 12b D4).
const String kForbiddenLayerNameCharacters = '<>/\\":;?*|=`';

/// Why [name] cannot be a layer's name in [target], or null when it can
/// (spec 12b D4).
///
/// A name is valid when it is non-empty, equal to itself trimmed, at most
/// [kMaxLayerNameLength] UTF-16 code units, free of
/// [kForbiddenLayerNameCharacters], and not another layer's name under
/// `toLowerCase()` — `TableSection`'s own folding, so a name this accepts is
/// one `TableSection.add` accepts. [self] is the layer being renamed: its own
/// current name is not a duplicate, so a case-only rename is valid.
///
/// The user forms of the layer commands and the panel both call this; a name
/// loaded from a file is a stored value and is never checked against it.
String? layerNameError(CommandTarget target, String name, {Handle? self}) {
  if (name.isEmpty) return 'A layer name cannot be empty.';
  if (name != name.trim()) {
    return 'A layer name cannot start or end with a space.';
  }
  if (name.length > kMaxLayerNameLength) {
    return 'A layer name can be at most $kMaxLayerNameLength characters.';
  }
  for (var i = 0; i < name.length; i++) {
    final c = name[i];
    if (kForbiddenLayerNameCharacters.contains(c)) {
      return 'A layer name cannot contain $c.';
    }
  }
  final existing = target.tables.layers.byName(name);
  if (existing != null && existing.handle != self) {
    return 'A layer named ${existing.name} already exists.';
  }
  return null;
}

/// The **effective** current layer: the layer new drawing goes to (spec 12b
/// D3).
///
/// The stored `header.currentLayer` when it names an existing, visible layer;
/// otherwise layer 0. Every decision that says "current" — the commands'
/// checks, a layer's emptiness, the tools, the panel — uses this, never the
/// stored value. The stored value is not rewritten when it becomes unusable,
/// so showing a hidden stored current layer makes it current again.
Handle drawingLayer(CommandTarget target) {
  final stored = target.header.currentLayer;
  final record = target.tables.layers[stored];
  return record != null && record.visible ? stored : ReservedHandles.layerZero;
}

/// The layer of the parametric object whose group is [group] (spec 12b D2).
///
/// The [ObjectLayer] component's layer when that layer exists in the table;
/// otherwise — no component, or one naming a missing layer — layer 0. Never
/// refuses: a component naming a missing layer is a stored value, kept as it
/// is and reported by `validate()` (`component.object_layer_missing`).
Handle objectLayer(CommandTarget target, Handle group) {
  final component = target.components.get<ObjectLayer>(group);
  if (component == null) return ReservedHandles.layerZero;
  return target.tables.layers.contains(component.layer)
      ? component.layer
      : ReservedHandles.layerZero;
}

/// Whether [layer] may be deleted (spec 12b D5).
///
/// A layer is empty when no entity record names it — root entities and
/// definition leaves alike, since both live in the entity store — no
/// [InstanceNode] names it, no [ObjectLayer] on a **live** node names it, and
/// it is neither [drawingLayer] nor layer 0. An [ObjectLayer] left on a dead
/// handle does not keep a layer alive.
///
/// One pass over the entity store, the tree and the [ObjectLayer] store:
/// O(n). Called on a delete and for the panel's one selected row, never per
/// rebuild of the whole list.
bool layerIsEmpty(CommandTarget target, Handle layer) {
  if (layer == ReservedHandles.layerZero) return false;
  if (layer == drawingLayer(target)) return false;
  final entities = target.entities;
  for (final slot in entities.liveSlots) {
    if (entities.layerAt(slot) == layer) return false;
  }
  for (final node in target.tree.nodes) {
    if (node is InstanceNode && node.layer == layer) return false;
  }
  for (final handle in target.components.withComponent<ObjectLayer>()) {
    if (target.tree[handle] == null) continue;
    if (target.components.get<ObjectLayer>(handle)!.layer == layer) {
      return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
// The layer commands (spec 12b D1, plan P-2).
//
// Each has two forms. The **user form** (the public unnamed constructor) is
// what the panel, the picker and the tools build: its `apply` checks the
// user rules — D4's names, layer 0's name, decision 7 against
// [drawingLayer], a missing target layer, D5's emptiness — before any
// mutation, and throws [ArgumentError] with the reason. The **restore form**
// (`.restore`) is what every inverse is built with: it checks only that the
// handle it needs exists ([StateError] otherwise) and writes the stored
// value exactly, whatever it is, so undo and redo never throw on a state a
// file can hold (a dangling or hidden current layer, a loaded name that
// fails D4, an entity on a missing layer).
//
// A missing entity or node is an integrity failure in both forms and throws
// [StateError], as every other command in `commands.dart` does.
//
// `touched` is never empty (spec S-3): an empty set makes `SpatialIndex`
// rebuild and `TileCache` drop everything.
// ---------------------------------------------------------------------------

LayerRecord _requireLayerForUser(CommandTarget target, Handle layer) {
  final record = target.tables.layers[layer];
  if (record == null) {
    throw ArgumentError.value(
        layer, 'layer', 'Layer ${layer.toHex()} does not exist.');
  }
  return record;
}

/// Adds a layer record (spec 12b D1). Its inverse removes it.
///
/// The user form refuses a name [layerNameError] rejects and a handle that
/// already names a layer, a node, a definition or an entity. Both forms
/// raise the handle seed past the record's handle, as [AddNodeCommand] does.
class AddLayerCommand extends DraftCommand {
  final LayerRecord record;
  final bool _restore;

  /// The user form.
  AddLayerCommand(this.record) : _restore = false;

  /// The restore form: adds [record] exactly, whatever its name.
  AddLayerCommand.restore(this.record) : _restore = true;

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Add layer';

  @override
  CommandResult apply(CommandTarget target) {
    final handle = record.handle;
    if (!_restore) {
      if (target.tables.layers.contains(handle) ||
          target.tree[handle] != null ||
          target.tree.definition(handle) != null ||
          target.entities.containsHandle(handle)) {
        throw DuplicateHandleError(handle);
      }
      final reason = layerNameError(target, record.name);
      if (reason != null) {
        throw ArgumentError.value(record.name, 'name', reason);
      }
    }
    // `TableSection.add` checks the handle and the folded name before it
    // writes anything, so a refusal here leaves the table untouched.
    target.tables.layers.add(record);
    target.handleSeed.raiseTo(handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: RemoveLayerCommand.restore(handle),
      touched: {handle},
    );
  }
}

/// Removes a layer record (spec 12b D1). Its inverse adds the old record
/// back exactly.
///
/// The user form refuses a missing layer, layer 0, the effective current
/// layer and a layer that is in use ([layerIsEmpty], spec 12b D5).
class RemoveLayerCommand extends DraftCommand {
  final Handle layer;
  final bool _restore;

  /// The user form.
  RemoveLayerCommand(this.layer) : _restore = false;

  /// The restore form: removes [layer] whatever uses it.
  RemoveLayerCommand.restore(this.layer) : _restore = true;

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Delete layer';

  @override
  CommandResult apply(CommandTarget target) {
    final LayerRecord record;
    if (_restore) {
      final found = target.tables.layers[layer];
      if (found == null) {
        throw StateError('no layer with handle ${layer.toHex()}');
      }
      record = found;
    } else {
      record = _requireLayerForUser(target, layer);
      if (layer == ReservedHandles.layerZero) {
        throw ArgumentError.value(layer, 'layer', 'Layer 0 cannot be deleted.');
      }
      if (layer == drawingLayer(target)) {
        throw ArgumentError.value(
            layer, 'layer', 'The current layer cannot be deleted.');
      }
      if (!layerIsEmpty(target, layer)) {
        throw ArgumentError.value(layer, 'layer',
            'Layer ${record.name} is in use and cannot be deleted.');
      }
    }
    target.tables.layers.remove(layer);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddLayerCommand.restore(record),
      touched: {layer},
    );
  }
}

/// Replaces the layer record with [record]'s handle by [record] (spec 12b
/// D1): a rename, a recolour, a hide or show, a lock or unlock. Its inverse
/// puts the old record back exactly.
///
/// Every check runs **before** the table's remove, so the remove-then-add
/// cannot lose the record: the user form checks the target exists, the name
/// ([layerNameError], the record itself excluded, so a case-only rename is
/// valid), that layer 0 keeps its name, and that the effective current layer
/// ([drawingLayer]) is not hidden (decision 7); the restore form checks the
/// target exists and that no *other* layer holds the new name under
/// `toLowerCase()` — the one thing `TableSection.add` would refuse after the
/// remove.
///
/// [label] names what changed ("Rename layer", "Hide layer", …); it is
/// known once [apply] has read the old record, which is when the dispatcher
/// reads it for the change event.
class SetLayerCommand extends DraftCommand {
  final LayerRecord record;
  final bool _restore;
  String _label = 'Edit layer';

  /// The user form.
  SetLayerCommand(this.record) : _restore = false;

  /// The restore form: writes [record] exactly, whatever its name or
  /// visibility.
  SetLayerCommand.restore(this.record) : _restore = true;

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => _label;

  @override
  CommandResult apply(CommandTarget target) {
    final handle = record.handle;
    final layers = target.tables.layers;
    final LayerRecord old;
    if (_restore) {
      final found = layers[handle];
      if (found == null) {
        throw StateError('no layer with handle ${handle.toHex()}');
      }
      old = found;
      final holder = layers.byName(record.name);
      if (holder != null && holder.handle != handle) {
        throw StateError('layer ${holder.handle.toHex()} already holds the '
            'name ${record.name}');
      }
    } else {
      old = _requireLayerForUser(target, handle);
      final reason = layerNameError(target, record.name, self: handle);
      if (reason != null) {
        throw ArgumentError.value(record.name, 'name', reason);
      }
      if (handle == ReservedHandles.layerZero && record.name != old.name) {
        throw ArgumentError.value(
            record.name, 'name', 'Layer 0 cannot be renamed.');
      }
      if (old.visible && !record.visible && handle == drawingLayer(target)) {
        throw ArgumentError.value(
            record, 'record', 'The current layer cannot be hidden.');
      }
    }
    _label = _describe(old, record);
    layers
      ..remove(handle)
      ..add(record);
    target.invalidateDerived();
    return CommandResult(
      inverse: SetLayerCommand.restore(old),
      touched: {handle},
    );
  }

  static String _describe(LayerRecord from, LayerRecord to) {
    final name = from.name != to.name;
    final color = from.color != to.color;
    final visible = from.visible != to.visible;
    final locked = from.locked != to.locked;
    final other = from.linetype != to.linetype ||
        from.lineweight != to.lineweight ||
        from.transparency != to.transparency;
    final count = [name, color, visible, locked, other].where((c) => c).length;
    if (count != 1) return 'Edit layer';
    if (name) return 'Rename layer';
    if (color) return 'Change layer colour';
    if (visible) return to.visible ? 'Show layer' : 'Hide layer';
    if (locked) return to.locked ? 'Lock layer' : 'Unlock layer';
    return 'Edit layer';
  }
}

/// Sets the stored current layer, `header.currentLayer` (spec 12b D1, D3).
/// Its inverse restores the old stored value exactly, dangling or hidden.
///
/// The user form refuses a missing layer and a hidden one (decision 7); a
/// locked layer may be current. `touched` is `{old, new}`.
class SetCurrentLayerCommand extends DraftCommand {
  final Handle layer;
  final bool _restore;

  /// The user form.
  SetCurrentLayerCommand(this.layer) : _restore = false;

  /// The restore form: writes [layer] exactly. Nothing to check: the stored
  /// value may name no layer at all.
  SetCurrentLayerCommand.restore(this.layer) : _restore = true;

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Set current layer';

  @override
  CommandResult apply(CommandTarget target) {
    if (!_restore) {
      final record = _requireLayerForUser(target, layer);
      if (!record.visible) {
        throw ArgumentError.value(layer, 'layer',
            'Layer ${record.name} is hidden and cannot be made current.');
      }
    }
    final old = target.header.currentLayer;
    target.header.currentLayer = layer;
    target.invalidateDerived();
    return CommandResult(
      inverse: SetCurrentLayerCommand.restore(old),
      touched: {old, layer},
    );
  }
}

/// Moves one entity to [layer] (spec 12b D1). Its inverse restores the old
/// layer exactly.
///
/// [capabilities] is `{components}` — a property edit, which the `runtime`
/// preset allows — while [capability], what a listener reads as "what
/// moved", is `geometry`: a layer move changes pixels, so it must not be
/// skipped by the listeners that skip a components-only change.
class SetEntityLayerCommand extends DraftCommand {
  final Handle entity;
  final Handle layer;
  final bool _restore;

  /// The user form: refuses a missing [layer].
  SetEntityLayerCommand(this.entity, this.layer) : _restore = false;

  /// The restore form: writes [layer] exactly, existing or not.
  SetEntityLayerCommand.restore(this.entity, this.layer) : _restore = true;

  @override
  Capability get capability => Capability.geometry;

  @override
  Set<Capability> get capabilities => const {Capability.components};

  @override
  String get label => 'Move to layer';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(entity);
    if (slot == null) {
      throw StateError('no entity with handle ${entity.toHex()}');
    }
    if (!_restore) _requireLayerForUser(target, layer);
    final record = target.entities.read(slot);
    target.entities.replace(slot, record.copyWith(layer: layer));
    target.invalidateDerived();
    return CommandResult(
      inverse: SetEntityLayerCommand.restore(entity, record.layer),
      touched: {entity},
    );
  }
}

/// Moves one [InstanceNode] to [layer] (spec 12b D1). Its inverse restores
/// the old layer exactly. The capability split is [SetEntityLayerCommand]'s.
class SetInstanceLayerCommand extends DraftCommand {
  final Handle node;
  final Handle layer;
  final bool _restore;

  /// The user form: refuses a missing [layer].
  SetInstanceLayerCommand(this.node, this.layer) : _restore = false;

  /// The restore form: writes [layer] exactly, existing or not.
  SetInstanceLayerCommand.restore(this.node, this.layer) : _restore = true;

  @override
  Capability get capability => Capability.geometry;

  @override
  Set<Capability> get capabilities => const {Capability.components};

  @override
  String get label => 'Move to layer';

  @override
  CommandResult apply(CommandTarget target) {
    final instance = target.tree[node];
    if (instance is! InstanceNode) {
      throw StateError('no instance node with handle ${node.toHex()}');
    }
    if (!_restore) _requireLayerForUser(target, layer);
    target.tree.replaceNode(instance.copyWith(layer: layer));
    target.invalidateDerived();
    return CommandResult(
      inverse: SetInstanceLayerCommand.restore(node, instance.layer),
      touched: {node},
    );
  }
}
