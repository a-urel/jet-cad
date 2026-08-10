import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../core/handle.dart';
import '../core/list_equality.dart';
import '../core/tolerance.dart';
import '../geometry/transform2.dart';
import 'style.dart';

/// A container in the scene tree.
///
/// Only containers carry a transform. Leaf entities live in the entity store,
/// express their coordinates in their owner's space, and have no transform of
/// their own — DXF-correct, and what keeps a million-entity document free of
/// per-entity matrices.
///
/// Nodes are immutable: a command replaces a node wholesale, which is what lets
/// undo be a plain value diff with no snapshots.
@immutable
sealed class Node {
  final Handle handle;

  /// [Handle.none] at the document root.
  final Handle parent;

  final Transform2 transform;
  final bool visible;

  const Node({
    required this.handle,
    required this.parent,
    required this.transform,
    required this.visible,
  });

  Map<String, Object?> toJson();

  static Node fromJson(Object? json) {
    if (json is! Map) throw FormatException('Node expects an object: $json');
    final map = json.cast<String, Object?>();
    return switch (map['type']) {
      'group' => GroupNode.fromJson(map),
      'instance' => InstanceNode.fromJson(map),
      final other => throw FormatException('unknown node type: $other'),
    };
  }
}

/// A one-off arrangement that owns its children.
///
/// Exports as an anonymous block rather than a DXF GROUP, because GROUP is a
/// flat handle list that can represent neither nesting nor a transform. A GROUP
/// read on import sets [exportAsDxfGroup] so a file that arrived with GROUPs
/// leaves with GROUPs.
final class GroupNode extends Node {
  /// Child **nodes** only — never leaf entities.
  ///
  /// Which container holds a leaf is said once, by [EntityRecord.owner], and
  /// that is the authoritative answer. Listing a leaf here too would be a
  /// second copy of the same fact with nothing keeping the two in step:
  /// [AddEntityCommand] sets `owner` and does not link, [RemoveEntityCommand]
  /// removes the record and does not unlist, and the codec used to write
  /// whichever version the file happened to carry.
  ///
  /// Older files do name leaf handles here and are tolerated — a handle that
  /// is not a node is skipped wherever this list is walked — but nothing
  /// writes one, and a save does not emit one.
  ///
  /// Order is draw order, and it is the file's order when there is one.
  final List<Handle> children;

  final bool exportAsDxfGroup;

  /// Wraps [children] with [List.unmodifiable]: the caller's growable list is
  /// mutable in the same way [Vector2] is, so without a defensive copy a
  /// caller that keeps a reference to the list it passed could mutate a
  /// supposedly-immutable node afterward, silently corrupting the tree.
  GroupNode({
    required super.handle,
    required super.parent,
    required super.transform,
    required List<Handle> children,
    super.visible = true,
    this.exportAsDxfGroup = false,
  }) : children = List.unmodifiable(children);

  GroupNode copyWith({
    Handle? handle,
    Handle? parent,
    Transform2? transform,
    bool? visible,
    List<Handle>? children,
    bool? exportAsDxfGroup,
  }) =>
      GroupNode(
        handle: handle ?? this.handle,
        parent: parent ?? this.parent,
        transform: transform ?? this.transform,
        visible: visible ?? this.visible,
        children: children ?? this.children,
        exportAsDxfGroup: exportAsDxfGroup ?? this.exportAsDxfGroup,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'group',
        'handle': handle.toJson(),
        'parent': parent.toJson(),
        'transform': transform.toJson(),
        'visible': visible,
        'children': [for (final c in children) c.toJson()],
        'exportAsDxfGroup': exportAsDxfGroup,
      };

  static GroupNode fromJson(Map<String, Object?> json) => GroupNode(
        handle: Handle.fromJson(json['handle']),
        parent: Handle.fromJson(json['parent']),
        transform: Transform2.fromJson(json['transform']),
        visible: json['visible']! as bool,
        children: [
          for (final c in json['children']! as List) Handle.fromJson(c),
        ],
        exportAsDxfGroup: json['exportAsDxfGroup']! as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is GroupNode &&
      other.handle == handle &&
      other.parent == parent &&
      other.transform
          .equals(transform, const Tolerance(linear: 0, angular: 0)) &&
      other.visible == visible &&
      other.exportAsDxfGroup == exportAsDxfGroup &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
      handle, parent, visible, exportAsDxfGroup, Object.hashAll(children));

  @override
  String toString() =>
      'GroupNode(${handle.toHex()}, ${children.length} children)';
}

/// A placement of a shared [Definition].
///
/// The same concept as DXF's INSERT and as IFC's occurrence. Attribute text is
/// not a field here: ATTRIBs are entities owned by this node, because a DXF
/// ATTRIB is a full text entity with its own placement, style and flags, and a
/// string map could not reconstruct one. That ownership also places attribute
/// text in the per-instance draw pass, where it belongs.
final class InstanceNode extends Node {
  final Handle definition;
  final Handle layer;

  /// This instance's own colour, imposed on its definition's BYBLOCK contents.
  ///
  /// `ByBlockColor` — the default — means "inherit from whatever places me",
  /// which for a root-level instance is the document context. This field is how
  /// 500 tables share one geometry and render in 500 colours, and it
  /// round-trips to DXF losslessly.
  final DraftColor color;

  const InstanceNode({
    required super.handle,
    required super.parent,
    required super.transform,
    required this.definition,
    required this.layer,
    this.color = const ByBlockColor(),
    super.visible = true,
  });

  InstanceNode copyWith({
    Handle? handle,
    Handle? parent,
    Transform2? transform,
    bool? visible,
    Handle? definition,
    Handle? layer,
    DraftColor? color,
  }) =>
      InstanceNode(
        handle: handle ?? this.handle,
        parent: parent ?? this.parent,
        transform: transform ?? this.transform,
        visible: visible ?? this.visible,
        definition: definition ?? this.definition,
        layer: layer ?? this.layer,
        color: color ?? this.color,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'instance',
        'handle': handle.toJson(),
        'parent': parent.toJson(),
        'transform': transform.toJson(),
        'visible': visible,
        'definition': definition.toJson(),
        'layer': layer.toJson(),
        'color': encodeColor(color),
      };

  static InstanceNode fromJson(Map<String, Object?> json) => InstanceNode(
        handle: Handle.fromJson(json['handle']),
        parent: Handle.fromJson(json['parent']),
        transform: Transform2.fromJson(json['transform']),
        visible: json['visible']! as bool,
        definition: Handle.fromJson(json['definition']),
        layer: Handle.fromJson(json['layer']),
        // Absent in files written before this field existed: BYBLOCK is the
        // correct default because it is a no-op — it reproduces the old
        // behaviour, where a placed instance imposed nothing on its
        // definition's colour, exactly.
        color: json['color'] == null
            ? const ByBlockColor()
            : decodeColor(json['color']! as int),
      );

  @override
  bool operator ==(Object other) =>
      other is InstanceNode &&
      other.handle == handle &&
      other.parent == parent &&
      other.transform
          .equals(transform, const Tolerance(linear: 0, angular: 0)) &&
      other.visible == visible &&
      other.definition == definition &&
      other.layer == layer &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(handle, parent, visible, definition, layer, color);

  @override
  String toString() =>
      'InstanceNode(${handle.toHex()} of ${definition.toHex()})';
}

/// A reusable prototype subtree — DXF BLOCK, IFC type object.
///
/// Not a [Node]: a prototype is not placed, so it has no parent and no
/// transform. [basePoint] is DXF's block base point; insertion alignment is
/// wrong without it.
///
/// `final`, not just `class`: [operator ==] tests `other is Definition`, and
/// without `final` a subclass carrying extra state could compare equal to a
/// base instance holding different data — a Liskov violation of exactly the
/// value-equality guarantee this type exists to provide.
@immutable
final class Definition {
  final Handle handle;
  final String name;
  final Vector2 basePoint;

  /// Child **nodes** only — never leaf entities; see [GroupNode.children],
  /// which carries the same contract for the same reason. A DXF BLOCK lists
  /// its entities, and a definition read from one therefore arrives with leaf
  /// handles in here; they are tolerated on the way in and are not written
  /// back out.
  final List<Handle> children;

  /// True when this block names an external drawing. Xref resolution is a
  /// non-goal: the record and its inserts are preserved so the reference
  /// survives a round-trip, and nothing tries to load the file.
  final bool isXref;
  final String xrefPath;

  /// Clones [basePoint] and wraps [children] with [List.unmodifiable]: both
  /// [Vector2] and a growable [List] are mutable, so without a defensive copy
  /// a caller that keeps a reference to what it passed could mutate a
  /// supposedly-immutable definition afterward, silently corrupting the tree.
  Definition({
    required this.handle,
    required this.name,
    required Vector2 basePoint,
    required List<Handle> children,
    this.isXref = false,
    this.xrefPath = '',
  })  : basePoint = basePoint.clone(),
        children = List.unmodifiable(children);

  Definition copyWith({
    Handle? handle,
    String? name,
    Vector2? basePoint,
    List<Handle>? children,
    bool? isXref,
    String? xrefPath,
  }) =>
      Definition(
        handle: handle ?? this.handle,
        name: name ?? this.name,
        basePoint: basePoint ?? this.basePoint,
        children: children ?? this.children,
        isXref: isXref ?? this.isXref,
        xrefPath: xrefPath ?? this.xrefPath,
      );

  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'basePoint': [basePoint.x, basePoint.y],
        'children': [for (final c in children) c.toJson()],
        'isXref': isXref,
        'xrefPath': xrefPath,
      };

  static Definition fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('Definition expects an object: $json');
    }
    final base = json['basePoint']! as List;
    return Definition(
      handle: Handle.fromJson(json['handle']),
      name: json['name']! as String,
      basePoint:
          Vector2((base[0] as num).toDouble(), (base[1] as num).toDouble()),
      children: [for (final c in json['children']! as List) Handle.fromJson(c)],
      isXref: json['isXref']! as bool,
      xrefPath: json['xrefPath']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Definition &&
      other.handle == handle &&
      other.name == name &&
      other.basePoint == basePoint &&
      other.isXref == isXref &&
      other.xrefPath == xrefPath &&
      listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(handle, name, basePoint.x, basePoint.y,
      isXref, xrefPath, Object.hashAll(children));

  @override
  String toString() => 'Definition(${handle.toHex()} "$name")';
}
