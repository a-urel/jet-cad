// The symbol library's load state (spec 09b D2): loading, ready with the
// library, or failed with the error that ended the load.
//
// No Flutter import: this file is Dart over the library's types only.
import 'symbol_library.dart';

/// Where the app's one load of the bundled symbol library stands.
sealed class SymbolLibraryState {
  const SymbolLibraryState();
}

/// The bytes are being read or decoded (also the state before the first
/// load and during a retry).
final class SymbolLibraryLoading extends SymbolLibraryState {
  const SymbolLibraryLoading();

  @override
  String toString() => 'SymbolLibraryLoading()';
}

/// The library was read and validated.
final class SymbolLibraryReady extends SymbolLibraryState {
  const SymbolLibraryReady(this.library);

  final SymbolLibrary library;

  @override
  String toString() => 'SymbolLibraryReady(${library.entries.length} symbols)';
}

/// The load ended in [error]: a missing asset, bytes the codec cannot read,
/// a [SymbolLibraryError], or any other throw.
final class SymbolLibraryFailed extends SymbolLibraryState {
  const SymbolLibraryFailed(this.error);

  final Object error;

  @override
  String toString() => 'SymbolLibraryFailed($error)';
}
