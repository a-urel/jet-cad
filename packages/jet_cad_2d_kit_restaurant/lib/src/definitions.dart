// The restaurant library's definitions by `key@1`, synchronously, for a
// `PlanBuild` that places tables: a build gets no symbol services, and the
// asset is read asynchronously.
//
// The library is built from the catalog and decoded by the loader's own
// decoder (`SymbolLibrary.decode`), so each definition is the one the loader
// yields from the committed asset: a test holds the built bytes equal to the
// asset's.
import 'package:jet_cad_2d/jet_cad_2d.dart' show Definition;
import 'package:jet_cad_2d_kit/authoring.dart' show encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show SymbolEntry, SymbolLibrary;

import 'catalog/restaurant_catalog.dart';

Map<String, SymbolEntry>? _entries;
Map<String, Definition>? _definitions;

/// The restaurant library's entries, `key@1` to the entry as the loader
/// yields it: the symbol and unit components a placement stamps on its copy
/// (a seated symbol's capacity), the definition and the leaves. Decoded
/// once, then cached; the map is unmodifiable.
Map<String, SymbolEntry> restaurantSymbolEntries() =>
    _entries ??= Map.unmodifiable({
      for (final e
          in SymbolLibrary.decode(encodeLibrary(restaurantCatalog)).entries)
        e.id: e,
    });

/// The restaurant library's definitions, `key@1` to the definition as the
/// loader yields it. Decoded once, then cached; the map is unmodifiable.
Map<String, Definition> restaurantSymbolDefinitions() =>
    _definitions ??= Map.unmodifiable({
      for (final e in restaurantSymbolEntries().values) e.id: e.definition,
    });
