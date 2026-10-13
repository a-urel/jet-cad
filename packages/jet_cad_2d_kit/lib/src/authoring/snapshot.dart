// The geometry snapshot (spec K7): per key@version, a canonical JSON text of
// its base point, shapes and unit. A kit commits it; the conformance test
// holds every published key@N to it, and the generator only ever adds to it.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:collection';
import 'dart:convert';

import 'catalog.dart';

/// Each symbol of [catalog] by `key@version`, sorted, as a canonical JSON
/// text: keys sorted, numbers in Dart's shortest round-trip form, -0 as 0.
SplayTreeMap<String, String> geometrySnapshot(Catalog catalog) =>
    SplayTreeMap.of({
      for (final s in catalog.symbols) s.id: jsonEncode(_entry(s)),
    });

Map<String, Object?> _entry(CatalogSymbol s) => {
      'base': _point(s.base),
      'shapes': [for (final shape in s.shapes) _shape(shape)],
      'unit': switch (s.unit) {
        null => null,
        final CatalogUnit u => {
            'capacity': u.capacity,
            'kind': u.kind,
            'labelling': u.labelling.name,
          },
      },
    };

Map<String, Object?> _shape(CatalogShape shape) => switch (shape) {
      CatalogLine(:final from, :final to) => {
          'from': _point(from),
          'kind': 'line',
          'to': _point(to),
        },
      CatalogPolyline(:final points, :final closed) => {
          'closed': closed,
          'kind': 'polyline',
          'points': [for (final p in points) _point(p)],
        },
      CatalogCircle(:final center, :final radius) => {
          'center': _point(center),
          'kind': 'circle',
          'radius': _number(radius),
        },
      CatalogArc(:final center, :final radius, :final start, :final sweep) => {
          'center': _point(center),
          'kind': 'arc',
          'radius': _number(radius),
          'start': _number(start),
          'sweep': _number(sweep),
        },
    };

List<double> _point(CatalogPoint p) => [_number(p.$1), _number(p.$2)];

/// -0.0 is the same geometry as 0.0, and is written so.
double _number(double v) => v == 0 ? 0.0 : v;

/// A committed snapshot's text, each entry re-encoded canonically. Throws
/// [FormatException] when [text] is not a JSON object of objects.
SplayTreeMap<String, String> parseSnapshot(String text) {
  final Object? json = jsonDecode(text);
  if (json is! Map<String, Object?>) {
    throw const FormatException('a geometry snapshot is a JSON object');
  }
  final snapshot = SplayTreeMap<String, String>();
  for (final MapEntry(:key, :value) in json.entries) {
    if (value is! Map) {
      throw FormatException('the snapshot entry "$key" is not an object');
    }
    snapshot[key] = jsonEncode(value);
  }
  return snapshot;
}

/// [snapshot] as its file: one entry per line, sorted by key.
String encodeSnapshot(Map<String, String> snapshot) {
  final keys = snapshot.keys.toList()..sort();
  if (keys.isEmpty) return '{}\n';
  final lines = [for (final k in keys) '  ${jsonEncode(k)}: ${snapshot[k]}'];
  return '{\n${lines.join(',\n')}\n}\n';
}

/// The generator's merge: every entry of [committed] as it is, plus the
/// entries of [current] it lacks. Never rewrites an existing entry, so a
/// changed geometry shows as a failing conformance test, never as a quietly
/// regenerated file.
SplayTreeMap<String, String> updateSnapshot(
        Map<String, String> committed, Map<String, String> current) =>
    SplayTreeMap.of({...current, ...committed});
