// Tool settings (spec 2a P3 "Tool settings"): the controller holds one
// value of S per tool with settings, for its whole life; the panel edits it
// through the tool's specs, the tool reads it through
// PlanServices.settingsOf.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';

final class ToolSettingsStore extends ChangeNotifier {
  ToolSettingsStore(KitSet kits) {
    for (final tool in kits.tools) {
      final settings = tool.settings;
      if (settings == null) continue;
      _settings[tool.id] = settings;
      _values[tool.id] = settings.initial;
    }
  }

  final Map<String, PlanToolSettings<Object>> _settings = {};
  final Map<String, Object> _values = {};

  bool has(String toolId) => _values.containsKey(toolId);

  /// [toolId]'s settings now; an [ArgumentError] for a tool without any.
  Object valueOf(String toolId) =>
      _values[toolId] ??
      (throw ArgumentError.value(toolId, 'toolId', 'is no tool with settings'));

  void store(String toolId, Object value) {
    if (valueOf(toolId) == value) return;
    _values[toolId] = value;
    notifyListeners();
  }

  /// The panel's fields over [toolId]'s settings (Task 17); their words are
  /// `property:<tool id>.<id>`.
  List<PropertyField> fieldsOf(String toolId) {
    valueOf(toolId);
    return _settings[toolId]!.fieldsOf(
        _values[toolId]!, (value) => store(toolId, value),
        toolId: toolId);
  }
}
