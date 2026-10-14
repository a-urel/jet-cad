// A kit's tool (spec 2a P1): a palette entry whose `create` makes the
// Flutter layer's Tool over a plan's services, with optional settings the
// property panel edits while the tool is active (spec 2a P3).
import 'package:flutter/widgets.dart' show IconData;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show Tool;
import 'package:meta/meta.dart';

import 'plan_services.dart';
import 'properties.dart';

/// A tool's settings: one value of `S` per tool and controller, starting at
/// [initial], edited through [specs], read by the tool through
/// `PlanServices.settingsOf`.
@immutable
final class PlanToolSettings<S extends Object> {
  const PlanToolSettings({required this.initial, required this.specs});

  final S initial;
  final List<PropertySpec<S>> specs;

  /// The fields of [value], an `S`, each under
  /// `property:<toolId>.<spec id>`; a field's commit hands the changed
  /// settings to [store] and returns them. Binding throws [ArgumentError]
  /// when [value] is not an `S`.
  List<PropertyField> fieldsOf(Object value, void Function(Object) store,
          {required String toolId}) =>
      [
        for (final spec in specs)
          spec.bind(value,
              wordId: 'property:$toolId.${spec.id}', onCommit: store),
      ];
}

@immutable
final class PlanTool {
  const PlanTool({
    required this.id,
    required this.icon,
    this.letter,
    this.needs = const {},
    this.settings,
    required this.create,
  });

  /// `<kit id>.<tool>`; its word is `tool:<id>`.
  final String id;

  final IconData icon;

  /// A suggested shortcut letter; the plan library gives it unless an
  /// earlier tool took it (spec 2a P2, the keyboard).
  final String? letter;

  /// What the tool's commits need; empty for a tool that only reads. The
  /// palette disables a tool whose needs the document's permissions deny.
  final Set<Capability> needs;

  final PlanToolSettings<Object>? settings;

  /// Made once per document (spec 2a P1, lifetimes).
  final Tool Function(PlanServices) create;

  @override
  String toString() => 'PlanTool($id)';
}
