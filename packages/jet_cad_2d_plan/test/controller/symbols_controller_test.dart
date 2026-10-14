// Spec P2 "Symbol libraries" at the controller (Task 13): the load starts
// with the controller and never blocks editing; its problems reach the
// diagnostics; a shared loader and thumbnail cache are never disposed by a
// controller, its own are; retry; arming. Review Focus 5: S-late-fail.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';
import '../support/tool_events.dart';

final class SpyThumbnails extends SymbolThumbnails {
  int disposals = 0;

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

PlanController make(List<PlanKit> kits,
    {PlanSymbolLoader? symbols, SymbolThumbnails? thumbnails}) {
  final c =
      PlanController(kits: kits, symbols: symbols, thumbnails: thumbnails);
  addTearDown(c.dispose);
  return c;
}

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanController c) => [
      for (final d in c.diagnostics.value) (d.kitId, d.subject, d.code),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'S-9 the load starts with the controller: loading, then ready with the '
      'symbols; its diagnostics reach the controller', () async {
    final c = make([
      demoKit(),
      symbolKit('beta', [
        SymbolLibrarySource(
            label: 'broken', read: () async => throw StateError('no file')),
      ]),
    ]);
    expect(c.symbolsState.value, PlanSymbolsState.loading);
    expect(c.symbols, isEmpty);
    await settle();
    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(idsOf(c.symbols), [for (final s in demoCatalog.symbols) s.id],
        reason: 'retired symbols load; the gallery hides them');
    // M-S9: the load's diagnostics not added to the controller's log.
    expect(problemsOf(c),
        [('beta', 'broken', KitDiagnosticCode.libraryUnreadable)]);
    expect(c.symbolById('demo.sofa.two@1')!.component.name, 'Two-seat sofa');
    expect(c.symbolById('demo.sofa.two@9'), isNull);
  });

  test(
      'S-10 S-late-fail: libraries that finish after drawing began, one '
      'failing: the drawing goes on, the rest fills in, one diagnostic, no '
      'symbol of the failed library (Review Focus 5)', () async {
    final alphaRead = Completer<Uint8List>();
    final betaRead = Completer<Uint8List>();
    final c = make([
      symbolKit('alpha',
          [SymbolLibrarySource(label: 'alpha', read: () => alphaRead.future)]),
      symbolKit('beta',
          [SymbolLibrarySource(label: 'beta', read: () => betaRead.future)]),
    ]);
    useTestCamera(c);
    expect(c.symbolsState.value, PlanSymbolsState.loading);
    final line =
        drawLine(c, Vector2(4120.5, -1415.25), Vector2(4730.75, -1102.5));
    final state = c.document.commands.stateId;
    final depth = c.document.commands.undoDepth;
    expect(depth, greaterThan(0), reason: 'premise: drawn while loading');

    alphaRead.complete(itemsBytes('alpha', ['one', 'two']));
    await settle();
    expect(c.symbolsState.value, PlanSymbolsState.loading,
        reason: 'beta has not settled');
    betaRead.completeError(StateError('beta asset missing'));
    await settle();

    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(idsOf(c.symbols), ['alpha.item.one@1', 'alpha.item.two@1']);
    expect(c.symbols.where((s) => s.kitId == 'beta'), isEmpty);
    expect(
        problemsOf(c), [('beta', 'beta', KitDiagnosticCode.libraryUnreadable)]);
    expect(linesOf(c.document), contains(line));
    expect(c.document.commands.stateId, state);
    expect(c.document.commands.undoDepth, depth);
    expect(c.activeTool.value, 'plan.select');
    // The drawing goes on.
    final next =
        drawLine(c, Vector2(5010.25, -990.5), Vector2(5600.75, -1250.25));
    expect(linesOf(c.document), containsAll([line, next]));
  });

  test(
      'S-11 a shared loader and cache are not disposed by the controller; '
      'its own are', () async {
    final shared = PlanSymbolLoader();
    addTearDown(shared.dispose);
    final thumbs = SpyThumbnails();
    addTearDown(thumbs.dispose);
    final read = CountingSource('demo', () async => demoBytes());
    final one = PlanController(
        kits: [demoKit(source: read.source)],
        symbols: shared,
        thumbnails: thumbs);
    await settle();
    one.dispose();
    // M-S11: the controller disposes the loader it was given.
    expect(shared.isDisposed, isFalse);
    expect(thumbs.disposals, 0);
    // A second controller over the same loader reads nothing again.
    final two = make([demoKit(source: read.source)],
        symbols: shared, thumbnails: thumbs);
    await settle();
    expect(two.symbolsState.value, PlanSymbolsState.ready);
    expect(read.reads, 1);

    final own = PlanController(kits: [demoKit()]);
    final ownThumbs = own.thumbnails;
    await settle();
    own.dispose();
    expect(
        () => ownThumbs.imageFor(
            key: 'k',
            document: DraftDocument.empty,
            logicalSize: const Size(8, 6),
            devicePixelRatio: 1,
            foreground: 0),
        throwsStateError,
        reason: 'its own cache is disposed');
  });

  test(
      'S-12 every library failed is failed; retrySymbols reads again and '
      'reaches ready; from ready it does nothing', () async {
    var fail = true;
    final read = CountingSource('demo', () async {
      if (fail) throw StateError('offline');
      return demoBytes();
    });
    final c = make([demoKit(source: read.source)]);
    await settle();
    expect(c.symbolsState.value, PlanSymbolsState.failed);
    fail = false;
    final retry = c.retrySymbols();
    expect(c.symbolsState.value, PlanSymbolsState.loading);
    await retry;
    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(read.reads, 2);
    await c.retrySymbols();
    // M-S12: retrySymbols acts in every state.
    expect(read.reads, 2);
  });

  test('S-13 a controller disposed mid-load ignores the late result', () async {
    // The controller is made inside the zone, so the load's continuation
    // runs there too and any error it throws lands in [errors].
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final pending = Completer<Uint8List>();
      final c = PlanController(kits: [
        demoKit(
            source:
                SymbolLibrarySource(label: 'demo', read: () => pending.future)),
      ]);
      c.dispose();
      pending.complete(demoBytes());
      await settle();
    }, (error, _) => errors.add(error));
    // M-S13: the `_disposed` check dropped: a disposed notifier is used
    // (a debug assertion, caught here).
    expect(errors, isEmpty, reason: 'the late result touches nothing');
  });

  test('S-14 armSymbol arms the symbol, whatever plan.symbol answers',
      () async {
    final c = make([demoKit()]);
    await settle();
    final sofa = c.symbolById('demo.sofa.three@1')!;
    expect(c.armedSymbol.value, isNull);
    c.armSymbol(sofa);
    // M-S14: armSymbol drops the `_armed.value = symbol`.
    expect(c.armedSymbol.value, same(sofa));
  });
}
