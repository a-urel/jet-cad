/// The plan library of jet_cad_2d: a `PlanController` over one plan and the
/// composable widgets of design mode, over the kits a host loads.
library;

export 'src/controller/camera_bounds.dart' show kPlanMaxScale, kPlanMinScale;
export 'src/controller/plan_change.dart'
    show
        PlanChange,
        PlanObjectAdded,
        PlanObjectChanged,
        PlanObjectRemoved,
        PlanReplaced;
export 'src/controller/plan_controller.dart';
export 'src/export/registries.dart';
export 'src/file/manifest.dart'
    show
        ManifestCheck,
        PlanManifest,
        checkManifest,
        kPlanFormat,
        manifestOf,
        manifestToWrite,
        usedKits;
export 'src/file/plan_file.dart';
export 'src/file/plan_format_exception.dart';
export 'src/kits/kit_set.dart';
export 'src/symbols/plan_symbols_state.dart';
