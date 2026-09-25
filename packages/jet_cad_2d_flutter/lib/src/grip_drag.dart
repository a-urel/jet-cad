import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'grip_cache.dart' show ObjectGripProvider;
import 'selection.dart';

/// What a `SelectTool` drag is doing (spec D5).
enum DragKind { band, move, rotate, reshape }

/// Shift's rotation step (spec D8): 15°.
const double kRotationStep = math.pi / 12;

/// What release will rewrite, read at press (spec D4).
sealed class _Capture {
  const _Capture(this.handle);
  final Handle handle;
}

final class _LeafCapture extends _Capture {
  const _LeafCapture(super.handle, this.entityKind, this.payload);
  final EntityKind entityKind;

  /// A `read` copy, never a `peek`: the store's own buffer changes under an
  /// edit.
  final GeometryPayload payload;
}

final class _NodeCapture extends _Capture {
  const _NodeCapture(super.handle, this.node);

  /// `GroupNode`/`InstanceNode ==` is exact component equality.
  final Node node;
}

/// A reshape of a root-level group through its [provider] (spec 07 D11):
/// the group's node and every leaf it owns, as they were at press.
final class _ObjectCapture extends _Capture {
  const _ObjectCapture(super.handle, this.node, this.provider, this.leaves);

  final GroupNode node;
  final ObjectGripProvider provider;

  /// The group's own leaves, each a `read` copy.
  final List<(Handle, EntityKind, GeometryPayload)> leaves;
}

/// One drag's state and its one command (spec D2, D4).
///
/// Nothing is dispatched while the drag lives. [command] builds a single
/// [CompoundCommand], even for one member, so the undo label says `Move`,
/// `Rotate` or `Stretch`; an object reshape's one member is its provider's
/// command (spec 07 D11). It returns null — dispatch nothing — when:
/// - a target is gone or changed since press (revalidation);
/// - a member's capability is refused (all or nothing);
/// - the drag changes nothing.
final class GripDrag {
  GripDrag._(this.document, this.kind, this._captures, [this.grip]);

  /// A move of every movable key in [keys]. A fill follows its boundary and
  /// an attrib is never root-level, so both are skipped (D4). Null when
  /// nothing is left.
  static GripDrag? move(DraftDocument document, Iterable<SelectionKey> keys) {
    final captures = _capture(document, keys);
    return captures.isEmpty
        ? null
        : GripDrag._(document, DragKind.move, captures);
  }

  /// A rotate of [keys] about [pivot], measured from the press at [press].
  static GripDrag? rotate(DraftDocument document, Iterable<SelectionKey> keys,
      Vector2 pivot, Vector2 press) {
    final captures = _capture(document, keys);
    if (captures.isEmpty) return null;
    final drag = GripDrag._(document, DragKind.rotate, captures);
    drag.base.setFrom(pivot);
    drag.target.setFrom(press);
    drag._pressAngle = math.atan2(press.y - pivot.y, press.x - pivot.x);
    return drag;
  }

  /// A reshape of [key]'s leaf by [grip]; its base is the grip, exactly.
  static GripDrag? reshape(
      DraftDocument document, SelectionKey key, Grip grip) {
    if (grip.role == GripRole.move) return null;
    final slot = document.entities.slotOf(key.target);
    if (slot == null) return null;
    final kind = document.entities.kindAt(slot);
    if (kind == EntityKind.fill || kind == EntityKind.attrib) return null;
    final capture = _LeafCapture(key.target, kind,
        document.geometry.read(document.entities.geomIndexAt(slot)));
    final drag = GripDrag._(document, DragKind.reshape, [capture], grip);
    drag.base.setValues(grip.x, grip.y);
    drag.target.setValues(grip.x, grip.y);
    return drag;
  }

  /// A reshape of the root-level group [key] by its [provider]'s [grip]
  /// (spec 07 D11); its base is the grip, exactly. Null for a `move` grip,
  /// which moves the selection instead, and for anything but a root-level
  /// group.
  ///
  /// Captures the group's node and a copy of every leaf it owns, so a
  /// document change to either before release cancels it, as a leaf
  /// reshape's does.
  static GripDrag? reshapeObject(DraftDocument document, SelectionKey key,
      Grip grip, ObjectGripProvider provider) {
    if (grip.role == GripRole.move) return null;
    final node = document.tree[key.target];
    // Defence in depth, unpinned by design (final review m5): `GripCache`
    // gives provider grips only to a selected root-level group, so no
    // caller reaches this with anything else, and no test can.
    if (node is! GroupNode || node.parent != document.rootHandle) return null;
    final capture =
        _ObjectCapture(key.target, node, provider, _leavesOf(document, node));
    final drag = GripDrag._(document, DragKind.reshape, [capture], grip);
    drag.base.setValues(grip.x, grip.y);
    drag.target.setValues(grip.x, grip.y);
    return drag;
  }

  /// Every leaf [group] owns directly, in slot order, each a `read` copy.
  static List<(Handle, EntityKind, GeometryPayload)> _leavesOf(
      DraftDocument document, GroupNode group) {
    final e = document.entities;
    return [
      for (final slot in e.liveSlots)
        if (e.ownerAt(slot) == group.handle)
          (
            e.handleAt(slot),
            e.kindAt(slot),
            document.geometry.read(e.geomIndexAt(slot)),
          ),
    ];
  }

  /// In ascending target handle order: that is the members' order (D4).
  static List<_Capture> _capture(
      DraftDocument document, Iterable<SelectionKey> keys) {
    final sorted = keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    final out = <_Capture>[];
    for (final key in sorted) {
      final node = document.tree[key.target];
      if (node != null) {
        out.add(_NodeCapture(key.target, node));
        continue;
      }
      final slot = document.entities.slotOf(key.target);
      if (slot == null) continue;
      final kind = document.entities.kindAt(slot);
      if (kind == EntityKind.fill || kind == EntityKind.attrib) continue;
      out.add(_LeafCapture(key.target, kind,
          document.geometry.read(document.entities.geomIndexAt(slot))));
    }
    return out;
  }

  final DraftDocument document;
  final DragKind kind;
  final List<_Capture> _captures;

  /// The grabbed grip; non-null only for a reshape.
  final Grip? grip;

  /// World. A move's or a reshape's base point; a rotate's pivot.
  final Vector2 base = Vector2.zero();

  /// World. The resolved target; for a rotate, the pointer.
  final Vector2 target = Vector2.zero();

  double _pressAngle = 0;
  double _theta = 0;
  Transform2? _transform;
  GeometryPayload? _preview;
  List<(EntityKind, GeometryPayload)>? _objectPreview;

  /// A rotate's angle, radians, in (−π, π] (Ruling 03-14).
  double get theta => _theta;

  /// A move's or a rotate's world `T`; cached per event, so a painter's
  /// per-frame read allocates nothing.
  Transform2? get transform => _transform;

  /// A reshape's payload at the current target; null when degenerate.
  GeometryPayload? get previewPayload => _preview;

  /// A leaf reshape's entity kind; null otherwise.
  EntityKind? get leafKind => kind == DragKind.reshape
      ? switch (_captures.single) {
          _LeafCapture(:final entityKind) => entityKind,
          _ => null,
        }
      : null;

  /// An object reshape's preview at the current target, in world: the
  /// provider's, computed at each [moveTo]. Null for any other drag.
  List<(EntityKind, GeometryPayload)>? get objectPreview => _objectPreview;

  /// A leaf needs `geometry`; a group or an instance needs `transform`
  /// (D2). An object reshape needs `components` and `geometry` (07 D11).
  Set<Capability> get capabilities => {
        for (final c in _captures)
          ...switch (c) {
            _NodeCapture() => const [Capability.transform],
            _LeafCapture() => const [Capability.geometry],
            _ObjectCapture() => const [
                Capability.components,
                Capability.geometry,
              ],
          },
      };

  bool permittedBy(DraftPermissions permissions) =>
      capabilities.every(permissions.allows);

  /// A move or a reshape follows [world].
  void moveTo(Vector2 world) {
    target.setFrom(world);
    switch (kind) {
      case DragKind.move:
        _transform =
            Transform2.translation(target.x - base.x, target.y - base.y);
      case DragKind.reshape:
        switch (_captures.single) {
          case final _LeafCapture c:
            _preview = reshapeLeaf(c.entityKind, c.payload, grip!, target);
          case final _ObjectCapture c:
            _objectPreview =
                c.provider.preview(document, c.handle, grip!, target.clone());
          case _NodeCapture():
            throw StateError('a node is never reshaped');
        }
      case DragKind.rotate:
      case DragKind.band:
        throw StateError('moveTo on a ${kind.name} drag');
    }
  }

  /// A rotate follows [pointer]. With [step], θ rounds to the nearest
  /// multiple of [kRotationStep] (D8).
  void rotateTo(Vector2 pointer, {required bool step}) {
    if (kind != DragKind.rotate) {
      throw StateError('rotateTo on a ${kind.name} drag');
    }
    target.setFrom(pointer);
    var theta =
        math.atan2(pointer.y - base.y, pointer.x - base.x) - _pressAngle;
    if (theta > math.pi) {
      theta -= 2 * math.pi;
    } else if (theta <= -math.pi) {
      theta += 2 * math.pi;
    }
    if (step) theta = (theta / kRotationStep).roundToDouble() * kRotationStep;
    _theta = theta;
    _transform = Transform2.translation(base.x, base.y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.translation(-base.x, -base.y));
  }

  /// The one command release dispatches, or null for none (spec D4).
  DraftCommand? command(DraftPermissions permissions) {
    // The backstop for any document change mid-drag, whatever its source.
    if (!_revalidate()) return null;
    final members = <DraftCommand>[];
    switch (kind) {
      case DragKind.reshape:
        switch (_captures.single) {
          case final _LeafCapture c:
            final next = _preview;
            if (next == null || next == c.payload) return null;
            members.add(SetEntityGeometryCommand(c.handle, next));
          case final _ObjectCapture c:
            // The grip's own needs first: the provider's command may name
            // fewer capabilities than the regeneration it causes (07 D11).
            if (!permittedBy(permissions)) return null;
            if (target.x == base.x && target.y == base.y) return null;
            final inner =
                c.provider.drag(document, c.handle, grip!, target.clone());
            if (inner == null) return null;
            members.add(inner);
          case _NodeCapture():
            throw StateError('a node is never reshaped');
        }
      case DragKind.move:
      case DragKind.rotate:
        final t = _transform;
        if (t == null) return null;
        if (kind == DragKind.move &&
            target.x - base.x == 0 &&
            target.y - base.y == 0) {
          return null;
        }
        if (kind == DragKind.rotate && _theta == 0) return null;
        for (final c in _captures) {
          switch (c) {
            case _LeafCapture(:final handle, :final entityKind, :final payload):
              members.add(SetEntityGeometryCommand(
                  handle, rigidTransformLeaf(entityKind, payload, t)));
            case _NodeCapture(:final handle, :final node):
              // After the node's own transform (D4); world is root space,
              // so there is no conjugation.
              members.add(
                  TransformNodeCommand(handle, t.multiply(node.transform)));
            case _ObjectCapture():
              throw StateError('an object capture is only ever reshaped');
          }
        }
      case DragKind.band:
        throw StateError('a band has no command');
    }
    // All or nothing: a move that leaves some objects behind breaks the
    // alignment the user was dragging for (D4).
    if (members.any((m) => !m.capabilities.every(permissions.allows))) {
      return null;
    }
    return CompoundCommand(members,
        label: switch (kind) {
          DragKind.move => 'Move',
          DragKind.rotate => 'Rotate',
          DragKind.reshape || DragKind.band => 'Stretch',
        });
  }

  bool _revalidate() {
    for (final c in _captures) {
      switch (c) {
        case _LeafCapture(:final handle, :final entityKind, :final payload):
          final slot = document.entities.slotOf(handle);
          if (slot == null || document.entities.kindAt(slot) != entityKind) {
            return false;
          }
          if (document.geometry.peek(document.entities.geomIndexAt(slot)) !=
              payload) {
            return false;
          }
        case _NodeCapture(:final handle, :final node):
          if (document.tree[handle] != node) return false;
        case _ObjectCapture(:final handle, :final node, :final leaves):
          if (document.tree[handle] != node) return false;
          final e = document.entities;
          var owned = 0;
          for (final slot in e.liveSlots) {
            if (e.ownerAt(slot) == handle) owned++;
          }
          if (owned != leaves.length) return false;
          for (final (h, entityKind, payload) in leaves) {
            final slot = e.slotOf(h);
            if (slot == null ||
                e.ownerAt(slot) != handle ||
                e.kindAt(slot) != entityKind ||
                document.geometry.peek(e.geomIndexAt(slot)) != payload) {
              return false;
            }
          }
      }
    }
    return true;
  }
}
