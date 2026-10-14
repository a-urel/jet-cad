// The symbol libraries' state (spec 2b S2), moved from jet_cad_2d_plan
// (2a's PlanSymbolsState): a kit's tool reads it through
// PlanServices.symbolsState to tell a key no loaded library has from
// libraries still loading or failed.
//
// Pure Dart: no Flutter, no dart:io.

/// Whether a plan's symbol libraries are loading, ready or failed.
enum SymbolsState {
  /// A library has not settled yet.
  loading,

  /// Every library settled and one at least was read, or there is none.
  ready,

  /// There was a library and every one failed.
  failed,
}
