// A table's colour (plan colours spec PC-4): one of the plan's eight hues,
// stored with the plan on the table's **instance** node as
// `jetcad.table_color` `{"color": "<name>"}`, the twin of the host's data
// (`FloorPlanTableData`). It follows the table through a move, a turn, a
// renumbering and a change of size, and leaves with it on a delete (the
// engine's `RemoveNodeCommand` drops every component of the node, and its
// undo restores them).
//
// Internal: no handle and no component type crosses the host barrel; a host
// reads it as `FloorPlanTableDetail.color` and writes it with
// `FloorPlanController.setTableColor`.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` and the
// colour names only.
import 'dart:convert' show jsonEncode;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../colors/plan_color.dart';

/// The colour of one table (PC-4): `{"color": name}`.
///
/// Immutable and value-equal. Made by the constructor from a palette entry;
/// or read by [fromJson], which **never throws**: a payload of another shape
/// than `{"color": String}` is [kept] verbatim and written back as read
/// (the engine's preserve-unknown store holds only unregistered types, and
/// a throwing factory would refuse the whole plan), and a name this release
/// does not know is stored as read in [name] and reads as no [colorValue].
/// `TableSurvey.diagnostics` reports both as `table.invalid_color`.
final class FloorPlanTableColor implements Component {
  static const String componentTypeId = 'jetcad.table_color';

  /// Registers the type. **Once per registry**: `register` replaces the
  /// store for the type, so a second call drops every live table's colour.
  static void register(ComponentRegistry registry) =>
      registry.register<FloorPlanTableColor>(componentTypeId, fromJson);

  /// The colour [color], stored by its name (never its index: a palette
  /// reordered or extended breaks no file).
  FloorPlanTableColor(FloorPlanColor color) : this._(color.name, null);

  FloorPlanTableColor._(this.name, this.kept)
      : _encoded = jsonEncode(kept ?? {'color': name});

  /// The stored name: a palette entry's, or a name this release does not
  /// know, as read. Null when the payload was [kept].
  final String? name;

  /// The payload as read, when it was not `{"color": String}`: written back
  /// exactly as read. Unmodifiable, all the way down. Null otherwise.
  final Map<String, Object?>? kept;

  /// The payload's encoding, its equality.
  final String _encoded;

  /// Whether the payload was kept verbatim (and reads as no colour).
  bool get isKept => kept != null;

  /// The palette entry named [name]; null when the payload was [kept] or
  /// the name is not one this release knows.
  FloorPlanColor? get colorValue => floorPlanColorNamed(name);

  @override
  String get typeId => componentTypeId;

  /// [kept] as read, or `{"color": name}`.
  @override
  Map<String, Object?> toJson() => kept ?? {'color': name};

  /// The payload's colour when it is exactly `{"color": String}`, whatever
  /// the string; otherwise the payload kept verbatim. Never throws.
  static FloorPlanTableColor fromJson(Map<String, Object?> json) {
    final raw = json['color'];
    if (json.length == 1 && raw is String) {
      return FloorPlanTableColor._(raw, null);
    }
    return FloorPlanTableColor._(null, _frozen(json) as Map<String, Object?>);
  }

  /// A deep, unmodifiable copy of a decoded JSON value, its maps' key
  /// order kept.
  static Object? _frozen(Object? value) => switch (value) {
        Map() => Map<String, Object?>.unmodifiable({
            for (final MapEntry(:key, :value) in value.entries)
              key as String: _frozen(value),
          }),
        List() =>
          List<Object?>.unmodifiable([for (final v in value) _frozen(v)]),
        _ => value,
      };

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTableColor && other._encoded == _encoded;

  @override
  int get hashCode => _encoded.hashCode;

  @override
  String toString() => 'FloorPlanTableColor($_encoded)';
}
