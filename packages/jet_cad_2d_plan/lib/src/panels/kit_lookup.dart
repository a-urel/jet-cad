// A kit's type, tool and word by id, over the controller's kit set (load
// order). Not memoised: a kit set holds a handful of kits, and the panel
// asks once per field per build.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../controller/plan_controller.dart';

PlanType<Component>? planTypeOf(PlanController controller, String typeId) {
  for (final kit in controller.kits.kits) {
    for (final t in kit.types) {
      if (t.id == typeId) return t;
    }
  }
  return null;
}

PlanTool? planToolOf(PlanController controller, String toolId) {
  for (final kit in controller.kits.kits) {
    for (final t in kit.tools) {
      if (t.id == toolId) return t;
    }
  }
  return null;
}

/// [wordId] of kit [kitId] in the controller's locale, else English, else
/// null (`KitNames.word`), the host's words first (spec 2b S4).
String? planWordOf(PlanController controller, String kitId, String wordId) =>
    controller
        .namesOf(kitId)
        ?.word(controller.locale.value.languageCode, wordId);
