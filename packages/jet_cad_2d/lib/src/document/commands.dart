import '../core/handle.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'command.dart';
import 'component.dart';
import 'node.dart';

/// Adds one leaf entity together with its geometry.
///
/// The record's `geomIndex` is ignored on the way in: the geometry slot is
/// whatever the store hands back, and the stored record is rewritten to match.
/// Passing a stale index through would silently bind an entity to the wrong
/// geometry.
///
/// The duplicate-handle check runs **before** the geometry slot is allocated,
/// and that order is the whole point of it. [EntityStore.add] rejects a handle
/// it already holds, so allocating first meant a rejected add left a live,
/// unreferenced geometry slot behind — which `purge()` then keeps forever,
/// because a live slot is by definition not garbage. Repeating the rejected
/// call leaked one slot per attempt. It also broke [DraftCommand.apply]'s
/// contract that a command "must either complete fully or leave the target
/// unmutated", which [CommandDispatcher.undo] cites as its justification for
/// restoring a history entry whose replay threw.
class AddEntityCommand extends DraftCommand {
  final EntityRecord record;
  final GeometryPayload payload;

  AddEntityCommand({required this.record, required this.payload});

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Add ${record.kind.name}';

  @override
  CommandResult apply(CommandTarget target) {
    if (target.entities.containsHandle(record.handle)) {
      throw DuplicateHandleError(record.handle);
    }
    final geomIndex = target.geometry.add(payload);
    target.entities.add(record.copyWith(geomIndex: geomIndex));
    target.handleSeed.raiseTo(record.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: RemoveEntityCommand(record.handle),
      touched: {record.handle},
    );
  }
}

/// Removes one leaf entity and its geometry.
///
/// The inverse carries the record and the geometry **payload**, never the
/// slots: undo may legitimately land in different slots, and the restored
/// record is rewritten to point at whichever geometry slot it gets. Both
/// reads happen before either store is mutated, so a live record and its
/// geometry are always what gets captured into the inverse.
///
/// That ordering is also what makes this apply all-or-nothing: every way it
/// can fail — an unknown handle, a dead geometry slot — fails during the
/// reads. `geometry.remove` afterwards cannot throw, because the `read`
/// above already proved that slot live.
class RemoveEntityCommand extends DraftCommand {
  final Handle handle;

  RemoveEntityCommand(this.handle);

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Remove entity';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) {
      throw StateError('no entity with handle ${handle.toHex()}');
    }
    final record = target.entities.read(slot);
    final payload = target.geometry.read(record.geomIndex);
    target.entities.remove(slot);
    target.geometry.remove(record.geomIndex);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddEntityCommand(record: record, payload: payload),
      touched: {handle},
    );
  }
}

/// Replaces a container's transform.
///
/// Distinct from editing geometry, which is what makes the `transform` and
/// `geometry` capabilities separable at all: leaf entities carry no transform
/// of their own, so moving an instance and editing coordinates are already
/// distinct operations. That separation is what lets a point-of-sale runtime
/// move a table but not draw a wall.
///
/// All-or-nothing: the missing-node check runs before anything is written, and
/// [DocumentTree.replaceNode] runs its own cycle guard before it touches
/// `_nodes`.
class TransformNodeCommand extends DraftCommand {
  final Handle handle;
  final Transform2 transform;

  TransformNodeCommand(this.handle, this.transform);

  @override
  Capability get capability => Capability.transform;

  @override
  String get label => 'Move';

  @override
  CommandResult apply(CommandTarget target) {
    final node = target.tree[handle];
    if (node == null) {
      throw StateError('no node with handle ${handle.toHex()}');
    }
    final previous = node.transform;
    target.tree.replaceNode(switch (node) {
      GroupNode() => node.copyWith(transform: transform),
      InstanceNode() => node.copyWith(transform: transform),
    });
    target.invalidateDerived();
    return CommandResult(
      inverse: TransformNodeCommand(handle, previous),
      touched: {handle},
    );
  }
}

/// Adds a node to the scene tree.
///
/// Relies on [DocumentTree.addNode] rejecting anything that would close a
/// definition cycle *before* mutating: a second check here would be
/// redundant, and duplicating the guard is exactly how the two copies drift
/// apart later. A rejected `addNode` call throws before this command returns
/// its inverse, so the dispatcher never pushes history for it — a rejected
/// command leaves no history.
class AddNodeCommand extends DraftCommand {
  final Node node;

  AddNodeCommand(this.node);

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Add node';

  @override
  CommandResult apply(CommandTarget target) {
    target.tree.addNode(node);
    target.handleSeed.raiseTo(node.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: RemoveNodeCommand(node.handle),
      touched: {node.handle},
    );
  }
}

/// Removes a node from the scene tree.
///
/// The inverse carries the node value itself, so undo re-adds through
/// [AddNodeCommand] — including its cycle guard — rather than re-inserting
/// unchecked.
class RemoveNodeCommand extends DraftCommand {
  final Handle handle;

  RemoveNodeCommand(this.handle);

  @override
  Capability get capability => Capability.structure;

  @override
  String get label => 'Remove node';

  @override
  CommandResult apply(CommandTarget target) {
    final node = target.tree[handle];
    if (node == null) {
      throw StateError('no node with handle ${handle.toHex()}');
    }
    target.tree.removeNode(handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddNodeCommand(node),
      touched: {handle},
    );
  }
}

/// Attaches, replaces, or (with a null value) detaches one component.
///
/// Editing component data is what a runtime is allowed to do without being
/// allowed to touch geometry — a table's number and capacity change; the
/// walls do not. `apply` captures the previous value (which may itself be
/// `null`, when nothing was attached) before mutating, and returns an inverse
/// carrying that value — so attach, detach, and replace all reverse
/// correctly, including detaching something that was never there, which
/// simply round-trips null-to-null.
///
/// All-or-nothing: the one failure mode, an unregistered component type,
/// throws out of [ComponentRegistry.attach]'s own lookup before any store is
/// written, and `detach` on an unregistered type is a no-op rather than a
/// partial write.
class SetComponentCommand<T extends Component> extends DraftCommand {
  final Handle handle;
  final T? value;

  SetComponentCommand(this.handle, this.value);

  @override
  Capability get capability => Capability.components;

  @override
  String get label => value == null ? 'Clear component' : 'Set component';

  @override
  CommandResult apply(CommandTarget target) {
    final previous = target.components.get<T>(handle);
    // `value` is a public field, so Dart's field-promotion rules (which apply
    // only to private final fields) do not narrow it to `T` inside this
    // branch even after the null check — hence the explicit cast.
    if (value == null) {
      target.components.detach<T>(handle);
    } else {
      target.components.attach<T>(handle, value as T);
    }
    target.invalidateDerived();
    return CommandResult(
      inverse: SetComponentCommand<T>(handle, previous),
      touched: {handle},
    );
  }
}
