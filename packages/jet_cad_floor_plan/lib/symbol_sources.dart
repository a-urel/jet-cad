// Where the planner's symbol libraries come from (spec 14 V-4): a source
// names a library and reads its bytes; the planner ships the furniture
// library's, and a host adds its own (the restaurant symbols package does).
// Flutter: a source usually reads an asset bundle.
library;

export 'src/symbols/symbol_library_loader.dart'
    show SymbolLibrarySource, furnitureSymbolSource, readBundledLibrary;
