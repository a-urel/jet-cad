// The service record (spec 2b S3 "The service record", decision 4): the
// moves the service copy made and the host's groups, as a small JSON a
// host stores apart from the design, and the strict match that decides
// which of a stored record's moves and groups still apply to the design.
// Ported from jet_cad_floor_plan's lib/src/host/service_layout.dart (the
// whole file), keyed by label, with groups added; today's
// `jet_cad.service_layout` text is refused (no compatibility, spec S5).
import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../units/unit_index.dart';
import 'service_state.dart';

/// The record's `format` value.
const String kServiceFormat = 'jet_cad.service';

/// The record's `version` value.
const int kServiceVersion = 1;

/// One moved unit: its instance, its label when it had one, its transform
/// in the design ([from]) and in the copy ([to]).
final class ServiceMove {
  const ServiceMove(
      {required this.handle,
      required this.label,
      required this.from,
      required this.to});

  final Handle handle;
  final String? label;
  final Transform2 from;
  final Transform2 to;

  @override
  String toString() => 'ServiceMove(${handle.toHex()}, $label)';
}

/// One group as a record holds it, before any check: its id, its members
/// and its label as written.
final class RecordGroup {
  const RecordGroup(
      {required this.id, required this.members, required this.label});

  final String id;
  final List<String> members;
  final String? label;
}

/// A decoded record.
final class ServiceRecord {
  const ServiceRecord({required this.moves, required this.groups});

  final List<ServiceMove> moves;
  final List<RecordGroup> groups;
}

/// Whether [a] and [b] are the same stored value: `Transform2` has no
/// `==` on purpose, and a record compares stored transforms exactly.
bool sameTransform(Transform2 a, Transform2 b) =>
    a.a == b.a &&
    a.b == b.b &&
    a.c == b.c &&
    a.d == b.d &&
    a.e == b.e &&
    a.f == b.f;

/// The placed units of [copy] (as [copyUnits] lists them) whose transform
/// differs from the same instance's in [design], ascending by handle.
/// Generated units never move alone, so none is listed.
List<ServiceMove> serviceMovesOf(
    DraftDocument design, DraftDocument copy, UnitIndex copyUnits) {
  final out = <ServiceMove>[];
  for (final u in copyUnits.units) {
    if (u.generated) continue;
    final moved = copy.tree[u.instance];
    final designed = design.tree[u.instance];
    if (moved is! InstanceNode || designed is! InstanceNode) continue;
    if (sameTransform(moved.transform, designed.transform)) continue;
    out.add(ServiceMove(
        handle: u.instance,
        label: u.text,
        from: designed.transform,
        to: moved.transform));
  }
  return out;
}

/// [moves] and [groups] as the record's JSON, in the given orders.
String encodeServiceRecord(
        List<ServiceMove> moves, Map<String, UnitGroup> groups) =>
    jsonEncode({
      'format': kServiceFormat,
      'version': kServiceVersion,
      'moves': [
        for (final m in moves)
          {
            'handle': m.handle.toHex(),
            'label': m.label,
            'from': m.from.toJson(),
            'to': m.to.toJson(),
          }
      ],
      'groups': [
        for (final MapEntry(key: id, value: g) in groups.entries)
          {
            'id': id,
            'members': [...g.members],
            'label': g.label,
          }
      ],
    });

/// The record [text]. Throws a [FormatException] unless it is a version-1
/// `jet_cad.service` record: its moves as today's layout entries (a
/// hexadecimal handle, a string or null label, six numbers in each of
/// `from` and `to`, no handle twice), its groups objects with a string
/// `id`, a list of string `members` and a string or null `label`. Values
/// are not checked for finiteness, nor groups against the validation:
/// [matchServiceMoves] and [matchServiceGroups] drop such entries.
ServiceRecord decodeServiceRecord(String text) {
  Never bad(String why) => throw FormatException('Not a service record: $why');
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    bad(e.message);
  }
  if (json is! Map<String, Object?>) bad('not an object');
  if (json['format'] != kServiceFormat) bad('format');
  if (json['version'] != kServiceVersion) bad('version');
  final moves = json['moves'];
  if (moves is! List<Object?>) bad('moves');
  final groups = json['groups'];
  if (groups is! List<Object?>) bad('groups');
  Transform2 transform(Object? v, String name) {
    if (v is! List<Object?> || v.length != 6 || v.any((x) => x is! num)) {
      bad(name);
    }
    // The web writes `1` where the VM writes `1.0` (V-21).
    final d = [for (final x in v) (x! as num).toDouble()];
    return Transform2(d[0], d[1], d[2], d[3], d[4], d[5]);
  }

  final seen = <Handle>{};
  final outMoves = <ServiceMove>[];
  for (final m in moves) {
    if (m is! Map<String, Object?>) bad('a move');
    final hex = m['handle'];
    if (hex is! String) bad('a handle');
    final Handle handle;
    try {
      handle = Handle.parseHex(hex);
    } on HandleRangeError {
      bad('a handle');
    }
    if (!seen.add(handle)) bad('handle $hex twice');
    final label = m['label'];
    if (label != null && label is! String) bad('a label');
    outMoves.add(ServiceMove(
        handle: handle,
        label: label as String?,
        from: transform(m['from'], 'from'),
        to: transform(m['to'], 'to')));
  }
  final outGroups = <RecordGroup>[];
  for (final g in groups) {
    if (g is! Map<String, Object?>) bad('a group');
    final id = g['id'];
    if (id is! String) bad('a group id');
    final members = g['members'];
    if (members is! List<Object?> || members.any((m) => m is! String)) {
      bad('a group\'s members');
    }
    final label = g['label'];
    if (label != null && label is! String) bad('a group label');
    outGroups.add(RecordGroup(
        id: id,
        members: List.unmodifiable(members.cast<String>()),
        label: label as String?));
  }
  return ServiceRecord(
      moves: List.unmodifiable(outMoves), groups: List.unmodifiable(outGroups));
}

/// The moves of a record that apply to a design, and those dropped.
typedef ServiceMoveMatch = ({
  List<ServiceMove> applied,
  List<ServiceMove> dropped,
});

/// Splits [moves] by the strict match against [design] (spec S3): a move
/// applies iff its handle is a placed unit of [designUnits] that no lock
/// covers (`isLockedUnit`), on a visible, unlocked layer (a missing layer
/// counts as visible), carrying the same label, at exactly
/// [ServiceMove.from], and [ServiceMove.to] only translates it (the same
/// linear part) with every value finite.
ServiceMoveMatch matchServiceMoves(
    DraftDocument design, UnitIndex designUnits, List<ServiceMove> moves) {
  final applied = <ServiceMove>[];
  final dropped = <ServiceMove>[];
  for (final e in moves) {
    final unit = designUnits[e.handle];
    final node = design.tree[e.handle];
    final layer =
        node is InstanceNode ? design.tables.layers[node.layer] : null;
    final ok = unit != null &&
        !unit.generated &&
        !unit.locked &&
        node is InstanceNode &&
        (layer == null || (layer.visible && !layer.locked)) &&
        unit.text == e.label &&
        sameTransform(node.transform, e.from) &&
        _finite(e.from) &&
        _finite(e.to) &&
        e.to.a == e.from.a &&
        e.to.b == e.from.b &&
        e.to.c == e.from.c &&
        e.to.d == e.from.d;
    (ok ? applied : dropped).add(e);
  }
  return (applied: applied, dropped: dropped);
}

bool _finite(Transform2 t) =>
    t.a.isFinite &&
    t.b.isFinite &&
    t.c.isFinite &&
    t.d.isFinite &&
    t.e.isFinite &&
    t.f.isFinite;

/// The groups of a record that apply, and the ids applied and dropped.
typedef ServiceGroupMatch = ({
  Map<String, UnitGroup> applied,
  List<String> appliedIds,
  List<String> droppedIds,
});

/// Applies [groups] in record order, each whole or not at all (spec S3):
/// a group is dropped when its trimmed id is blank or that of a group
/// applied before it, when it has no member after trimming, when a member
/// names no unit of [designUnits] (any unit carrying the label), or when a
/// member is in a group applied before it. The ids are trimmed.
ServiceGroupMatch matchServiceGroups(
    List<RecordGroup> groups, UnitIndex designUnits) {
  final applied = <String, UnitGroup>{};
  final owner = <String, String>{};
  final appliedIds = <String>[];
  final droppedIds = <String>[];
  for (final r in groups) {
    final id = r.id.trim();
    final group = UnitGroup(members: r.members.toSet(), label: r.label);
    final ok = id.isNotEmpty &&
        !applied.containsKey(id) &&
        group.members.isNotEmpty &&
        group.members.every((m) => designUnits.withLabel(m).isNotEmpty) &&
        group.members.every((m) => !owner.containsKey(m));
    if (!ok) {
      droppedIds.add(id);
      continue;
    }
    applied[id] = group;
    appliedIds.add(id);
    for (final m in group.members) {
      owner[m] = id;
    }
  }
  return (
    applied: Map.unmodifiable(applied),
    appliedIds: appliedIds,
    droppedIds: droppedIds,
  );
}

/// What `PlanController.restoreService` did (spec S3): the labels of the
/// moves it applied and dropped, in record order (an unlabelled unit's is
/// null, so a label may repeat and the lengths are the counts), and the
/// ids of the groups it applied and dropped, in record order.
@immutable
final class ServiceRestore {
  ServiceRestore(
      {required List<String?> appliedMoves,
      required List<String?> droppedMoves,
      required List<String> appliedGroups,
      required List<String> droppedGroups})
      : appliedMoves = List.unmodifiable(appliedMoves),
        droppedMoves = List.unmodifiable(droppedMoves),
        appliedGroups = List.unmodifiable(appliedGroups),
        droppedGroups = List.unmodifiable(droppedGroups);

  final List<String?> appliedMoves, droppedMoves;
  final List<String> appliedGroups, droppedGroups;

  @override
  String toString() => 'ServiceRestore(moves: $appliedMoves, dropped '
      '$droppedMoves; groups: $appliedGroups, dropped $droppedGroups)';
}
