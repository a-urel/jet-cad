// The service layout (spec 14d S1, S2, revision 2): the tables the service
// copy has moved away from the design, as a small JSON a host stores, and
// the strict match that decides which of a stored layout's entries still
// apply to the design.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../tables/table_index.dart';

/// The layout's `format` value.
const String kServiceLayoutFormat = 'jet_cad.service_layout';

/// The layout's `version` value.
const int kServiceLayoutVersion = 1;

/// One moved table (S1): its instance, its number when it had one, its
/// transform in the design ([from]) and in the copy ([to]).
final class ServiceLayoutEntry {
  const ServiceLayoutEntry(
      {required this.handle,
      required this.number,
      required this.from,
      required this.to});

  final Handle handle;
  final String? number;
  final Transform2 from;
  final Transform2 to;

  @override
  String toString() => 'ServiceLayoutEntry(${handle.toHex()}, $number)';
}

/// Whether [a] and [b] are the same stored value (I-5): `Transform2` has no
/// `==` on purpose, and a layout compares stored transforms exactly.
bool sameTransform(Transform2 a, Transform2 b) =>
    a.a == b.a &&
    a.b == b.b &&
    a.c == b.c &&
    a.d == b.d &&
    a.e == b.e &&
    a.f == b.f;

/// The tables of [copy] whose transform differs from the same instance's
/// in [design], ascending by handle (S1).
List<ServiceLayoutEntry> serviceLayoutOf(
    DraftDocument design, DraftDocument copy) {
  final out = <ServiceLayoutEntry>[];
  for (final t in TableSurvey.of(copy).tables) {
    final moved = copy.tree[t.instance];
    final designed = design.tree[t.instance];
    if (moved is! InstanceNode || designed is! InstanceNode) continue;
    if (sameTransform(moved.transform, designed.transform)) continue;
    out.add(ServiceLayoutEntry(
        handle: t.instance,
        number: t.number,
        from: designed.transform,
        to: moved.transform));
  }
  return out;
}

/// [entries] as S1's JSON, in the given order.
String encodeServiceLayout(List<ServiceLayoutEntry> entries) => jsonEncode({
      'format': kServiceLayoutFormat,
      'version': kServiceLayoutVersion,
      'tables': [
        for (final e in entries)
          {
            'handle': e.handle.toHex(),
            'number': e.number,
            'from': e.from.toJson(),
            'to': e.to.toJson(),
          }
      ],
    });

/// The entries of a layout [text] (S1, S2 as amended). Throws a
/// [FormatException] unless it is a version-1 layout whose every entry has
/// a hexadecimal handle, a string or null number, and six numbers in each
/// of `from` and `to`, no handle twice. Values are not checked for
/// finiteness here: [matchServiceLayout] drops such an entry.
List<ServiceLayoutEntry> decodeServiceLayout(String text) {
  Never bad(String why) => throw FormatException('Not a service layout: $why');
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    bad(e.message);
  }
  if (json is! Map<String, Object?>) bad('not an object');
  if (json['format'] != kServiceLayoutFormat) bad('format');
  if (json['version'] != kServiceLayoutVersion) bad('version');
  final tables = json['tables'];
  if (tables is! List<Object?>) bad('tables');
  Transform2 transform(Object? v, String name) {
    if (v is! List<Object?> || v.length != 6 || v.any((x) => x is! num)) {
      bad(name);
    }
    // The web writes `1` where the VM writes `1.0` (V-21).
    final d = [for (final x in v) (x! as num).toDouble()];
    return Transform2(d[0], d[1], d[2], d[3], d[4], d[5]);
  }

  final seen = <Handle>{};
  final out = <ServiceLayoutEntry>[];
  for (final t in tables) {
    if (t is! Map<String, Object?>) bad('an entry');
    final hex = t['handle'];
    if (hex is! String) bad('a handle');
    final Handle handle;
    try {
      handle = Handle.parseHex(hex);
    } on HandleRangeError {
      bad('a handle');
    }
    if (!seen.add(handle)) bad('handle $hex twice');
    final number = t['number'];
    if (number != null && number is! String) bad('a number');
    out.add(ServiceLayoutEntry(
        handle: handle,
        number: number as String?,
        from: transform(t['from'], 'from'),
        to: transform(t['to'], 'to')));
  }
  return out;
}

/// The entries of a layout that apply to a design, and those dropped.
typedef ServiceLayoutMatch = ({
  List<ServiceLayoutEntry> applied,
  List<ServiceLayoutEntry> dropped,
});

/// Splits [entries] by S2's strict match against [design]: an entry
/// applies iff its handle is a table of the design (a live root instance
/// of a servable symbol) on a visible, unlocked layer, carrying the same
/// number, at exactly [ServiceLayoutEntry.from], and [ServiceLayoutEntry.to]
/// only translates it (the same linear part) with every value finite.
ServiceLayoutMatch matchServiceLayout(
    DraftDocument design, List<ServiceLayoutEntry> entries) {
  final tables = {
    for (final t in TableSurvey.of(design).tables) t.instance: t,
  };
  final applied = <ServiceLayoutEntry>[];
  final dropped = <ServiceLayoutEntry>[];
  for (final e in entries) {
    final table = tables[e.handle];
    final node = design.tree[e.handle];
    final layer =
        node is InstanceNode ? design.tables.layers[node.layer] : null;
    final ok = table != null &&
        node is InstanceNode &&
        (layer == null || (layer.visible && !layer.locked)) &&
        table.number == e.number &&
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
