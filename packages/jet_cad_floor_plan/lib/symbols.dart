// The symbol library's public surface (spec 14 V-3): the types a symbol
// catalog is written in, the library builder, and the library's loaded
// form. Pure Dart: a catalog's generator runs under plain `dart`. The
// Flutter side (reading a library from an asset bundle) is
// `symbol_sources.dart`.
library;

export 'src/symbols/build_library.dart';
export 'src/symbols/furniture_catalog.dart'
    show
        ArcShape,
        CircleShape,
        FurnitureShape,
        FurnitureSymbol,
        LineShape,
        PolylineShape,
        furnitureCatalog;
export 'src/symbols/seating_component.dart';
export 'src/symbols/symbol_component.dart';
export 'src/symbols/symbol_library.dart';
