// Spec 3a C1.9: a plan a host builds in code.
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;

import 'plan_services.dart' show KitWords;

/// Fills a new plan in code (spec 3a C1.9), given to
/// `PlanController(build:)` or `newPlan(build:)`. [document] is the plan
/// library's: set up, prepared by every loaded kit (`PlanKit.prepare`), its
/// parametric system installed. The build adds objects by command; the plan
/// library then clears the history and takes the save point, so the built
/// plan opens clean, with nothing to undo. [words] are every loaded kit's,
/// the host's first, in the controller's locale. A build that throws leaves
/// the empty plan and is reported.
typedef PlanBuild = void Function(DraftDocument document, KitWords words);
