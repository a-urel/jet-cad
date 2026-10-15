// "Is this a live T", as the kit asks it (spec 3a C1.5): of the plan's
// services, never of a catalog of the kit's own, so a frozen object (spec 2a
// E2) is absent from the kit's caches exactly as it is from generate. Today
// (jet_cad_floor_plan/lib/src/parametric/live_objects.dart) the app asked
// its global parametricCatalog.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanServices;

/// The type id of [handle]'s live object, or null: a frozen object, one of
/// a missing kit, and anything that is not a live object answer null.
typedef LiveTypeOf = String? Function(Handle handle);

/// The plan's answer: `PlanServices.liveTypeIdOf`.
LiveTypeOf liveTypesOf(PlanServices services) => services.liveTypeIdOf;

/// Whether [handle] is a live object of [typeId].
bool isLiveOf(LiveTypeOf live, Handle handle, String typeId) =>
    live(handle) == typeId;

/// Every live object of [typeId] carrying a `T` in [document], ascending by
/// handle value (`ComponentRegistry.withComponent` is ascending; the filter
/// keeps it): today's `liveObjectsOf<T>(doc)`. A fresh list.
///
/// Cost: O(k) calls of [live] for k holders of a `T`.
List<Handle> liveObjectsOf<T extends Component>(
        DraftDocument document, LiveTypeOf live, String typeId) =>
    [
      for (final h in document.components.withComponent<T>())
        if (live(h) == typeId) h,
    ];
