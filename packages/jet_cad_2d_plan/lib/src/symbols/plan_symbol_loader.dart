// Spec P2 "Symbol libraries" (Task 13): reads, decodes and caches the
// kits' symbol libraries. One loader may serve several controllers (today's
// §4: the app's loader, never disposed by a view); a controller never
// disposes a loader it was given.
import 'dart:async';

import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';
import 'plan_symbol.dart';
import 'plan_symbols_state.dart';

/// One assembly of a kit set's libraries: the symbols in load order, the
/// problems met, and the state they leave.
final class PlanSymbolLoad {
  PlanSymbolLoad._(
      List<PlanSymbol> symbols, List<KitDiagnostic> diagnostics, this.state)
      : symbols = List.unmodifiable(symbols),
        diagnostics = List.unmodifiable(diagnostics);

  final List<PlanSymbol> symbols;
  final List<KitDiagnostic> diagnostics;
  final PlanSymbolsState state;
}

/// The kits' symbol libraries, read once per source.
///
/// [library] reads and decodes one source and keeps the result; a failed
/// read or decode is not kept, so a later call reads again. [load] asks
/// for every source of a kit set at once and assembles them in kit order,
/// then each kit's source order, then library order:
/// - a library that cannot be read or decoded is skipped
///   (`libraryUnreadable`);
/// - a library whose kit is not its kit's is refused
///   (`libraryKitMismatch`);
/// - a `key@N` already given earlier in that order is dropped
///   (`symbolDuplicate`).
/// The state is `failed` only when there was a source and every one
/// failed; else `ready`.
class PlanSymbolLoader {
  PlanSymbolLoader();

  final Map<SymbolLibrarySource, Future<SymbolLibrary>> _reads =
      Map<SymbolLibrarySource, Future<SymbolLibrary>>.identity();
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// [source]'s decoded library, read on the first call.
  Future<SymbolLibrary> library(SymbolLibrarySource source) {
    if (_disposed) throw StateError('PlanSymbolLoader used after dispose');
    final kept = _reads[source];
    if (kept != null) return kept;
    final read = Future.sync(source.read).then(SymbolLibrary.decode);
    _reads[source] = read;
    read.then<void>((_) {}, onError: (Object _) {
      if (identical(_reads[source], read)) _reads.remove(source);
    });
    return read;
  }

  Future<PlanSymbolLoad> load(KitSet kits) async {
    if (_disposed) throw StateError('PlanSymbolLoader used after dispose');
    final reads = [
      for (final kit in kits.kits)
        for (final source in kit.symbols) (kit, source, library(source)),
    ];
    final symbols = <PlanSymbol>[];
    final diagnostics = <KitDiagnostic>[];
    final given = <String, String>{};
    var failed = 0;
    for (final (kit, source, read) in reads) {
      final SymbolLibrary lib;
      try {
        lib = await read;
      } catch (e) {
        failed++;
        diagnostics.add(KitDiagnostic(
            kitId: kit.id,
            subject: source.label,
            code: KitDiagnosticCode.libraryUnreadable,
            message: 'the library "${source.label}" could not be read: $e',
            error: e));
        continue;
      }
      if (lib.kits.length != 1 || lib.kits.single != kit.id) {
        failed++;
        diagnostics.add(KitDiagnostic(
            kitId: kit.id,
            subject: source.label,
            code: KitDiagnosticCode.libraryKitMismatch,
            message: 'the library "${source.label}" holds the kit '
                '${lib.kits.join('+')}, not "${kit.id}"'));
        continue;
      }
      for (final entry in lib.entries) {
        final earlier = given[entry.id];
        if (earlier != null) {
          diagnostics.add(KitDiagnostic(
              kitId: kit.id,
              subject: entry.id,
              code: KitDiagnosticCode.symbolDuplicate,
              message: '${entry.id} of "${source.label}" is already given '
                  'by the kit "$earlier"; dropped'));
          continue;
        }
        given[entry.id] = kit.id;
        symbols.add(PlanSymbol(kitId: kit.id, names: kit.names, entry: entry));
      }
    }
    final state = reads.isNotEmpty && failed == reads.length
        ? PlanSymbolsState.failed
        : PlanSymbolsState.ready;
    return PlanSymbolLoad._(symbols, diagnostics, state);
  }

  /// Drops every kept read. A load still running completes; the loader
  /// cannot be used afterwards.
  void dispose() {
    _disposed = true;
    _reads.clear();
  }
}
