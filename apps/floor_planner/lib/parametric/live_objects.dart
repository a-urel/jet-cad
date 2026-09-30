// The app's one "is this a live `T`" (fix/live-object-rule): thin wrappers
// over the engine's own object rule (spec 06 D5, as amended), asked of the
// floor planner's catalog. Nothing else in the app decides what a handle is.
// No Flutter import: this file is Dart over `package:jet_cad_2d` only, and
// imports only pure files (the dimensions plan's Ruling 11-2), so the pure
// geometry files may import it.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'catalog.dart';

/// Whether [h] is a live `T` of [doc]: a live parametric object whose
/// naming registration is exactly `T`'s, as the engine's survey reads it
/// (`ParametricCatalog.names` on [parametricCatalog]). A root-level group
/// carrying two registered types (only a file makes one) is the later
/// registration's object, and the earlier type's nowhere; a component on a
/// nested group, an instance, a leaf or a handle with no node is no
/// object's. `T` is matched exactly: a supertype names nothing.
///
/// Cost: O(registered types). Called on edits, tool events, grip-cache
/// rebuilds and the band cache's rebuild, never per frame.
bool isLiveObject<T extends Component>(DraftDocument doc, Handle h) =>
    parametricCatalog.names<T>(doc, h);

/// Every live `T` of [doc] ([isLiveObject]), ascending by handle value
/// (`ParametricCatalog.objectsOf` on [parametricCatalog]). A fresh list.
///
/// Cost: O(k · registered types) for k holders of a `T`.
List<Handle> liveObjectsOf<T extends Component>(DraftDocument doc) =>
    parametricCatalog.objectsOf<T>(doc);
