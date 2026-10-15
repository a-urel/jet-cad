// Spec P2 "Symbol libraries" (Task 13): the loader reads every kit's
// sources, decodes, refuses a library under another kit, drops a repeated
// key@N, skips an unreadable library, and caches each source's read. Every
// problem is a KitDiagnostic, and the load goes on with the rest.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/symbol_fixtures.dart';

PlanSymbolLoader loader() {
  final l = PlanSymbolLoader();
  addTearDown(l.dispose);
  return l;
}

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanSymbolLoad load) => [
      for (final d in load.diagnostics) (d.kitId, d.subject, d.code),
    ];

void main() {
  test(
      'S-1 every kit\'s libraries in kit order, then source order, then '
      'library order; each symbol knows its kit and words', () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'a1', read: () async => itemsBytes('alpha', ['one', 'two'])),
      SymbolLibrarySource(
          label: 'a2', read: () async => itemsBytes('alpha', ['three'])),
    ]);
    final beta = symbolKit(
        'beta',
        [
          SymbolLibrarySource(
              label: 'b1', read: () async => itemsBytes('beta', ['four'])),
        ],
        names: const KitNames({
          'tr': {'symbol:beta.item.four': 'Dört'},
        }));
    final load = await loader().load(validateKitSet([beta, alpha]));
    expect(idsOf(load.symbols), [
      'beta.item.four@1',
      'alpha.item.one@1',
      'alpha.item.two@1',
      'alpha.item.three@1',
    ]);
    expect([for (final s in load.symbols) s.kitId],
        ['beta', 'alpha', 'alpha', 'alpha']);
    expect(load.symbols.first.names, same(beta.names));
    expect(load.symbols.first.component.key, 'beta.item.four');
    expect(load.diagnostics, isEmpty);
    expect(load.state, SymbolsState.ready);
    expect(() => load.symbols.add(load.symbols.first), throwsUnsupportedError);
  });

  test(
      'S-2 a key@N given again by a later source is dropped from it, one '
      'symbolDuplicate naming it; the rest of that library stays', () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'a1', read: () async => itemsBytes('alpha', ['one', 'two'])),
      SymbolLibrarySource(
          label: 'a2', read: () async => itemsBytes('alpha', ['two', 'three'])),
    ]);
    final load = await loader().load(validateKitSet([alpha]));
    // M-S2: the `given` check dropped.
    expect(idsOf(load.symbols),
        ['alpha.item.one@1', 'alpha.item.two@1', 'alpha.item.three@1']);
    expect(problemsOf(load),
        [('alpha', 'alpha.item.two@1', KitDiagnosticCode.symbolDuplicate)]);
    expect(load.symbols[1].entry.definition.basePoint.x, 400.5,
        reason: 'the first source\'s two, not the second\'s (at 300.5)');
    expect(load.state, SymbolsState.ready);
  });

  test('S-3 the same key at another version is a different symbol (LS4)',
      () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'a1', read: () async => itemsBytes('alpha', ['one'])),
      SymbolLibrarySource(
          label: 'a2',
          read: () async => itemsBytes('alpha', ['one'], version: 2)),
    ]);
    final load = await loader().load(validateKitSet([alpha]));
    expect(idsOf(load.symbols), ['alpha.item.one@1', 'alpha.item.one@2']);
    expect(load.diagnostics, isEmpty);
  });

  test(
      'S-4 a library under another kit is refused whole, one '
      'libraryKitMismatch; the kit\'s other library loads', () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'wrong', read: () async => itemsBytes('beta', ['four'])),
      SymbolLibrarySource(
          label: 'right', read: () async => itemsBytes('alpha', ['one'])),
    ]);
    final load = await loader().load(validateKitSet([alpha]));
    // M-S4: the kit check dropped.
    expect(idsOf(load.symbols), ['alpha.item.one@1']);
    expect(problemsOf(load),
        [('alpha', 'wrong', KitDiagnosticCode.libraryKitMismatch)]);
    expect(load.state, SymbolsState.ready);
  });

  test(
      'S-5 an unreadable library (a throwing read, bytes that do not '
      'decode) is skipped, one libraryUnreadable each, its error kept',
      () async {
    final boom = StateError('no asset here');
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(label: 'throws', read: () async => throw boom),
      SymbolLibrarySource(
          label: 'garbage',
          read: () async => Uint8List.fromList([0x7b, 0x7b, 0x7b])),
      SymbolLibrarySource(
          label: 'good', read: () async => itemsBytes('alpha', ['one'])),
    ]);
    // M-S5: the read's catch rethrows (the load throws).
    final load = await loader().load(validateKitSet([alpha]));
    expect(idsOf(load.symbols), ['alpha.item.one@1']);
    expect(problemsOf(load), [
      ('alpha', 'throws', KitDiagnosticCode.libraryUnreadable),
      ('alpha', 'garbage', KitDiagnosticCode.libraryUnreadable),
    ]);
    expect(load.diagnostics.first.error, same(boom));
    expect(load.diagnostics.last.error, isA<SymbolLibraryError>());
  });

  test(
      'S-6 the state: no source is ready and empty; every source failed is '
      'failed; one loaded is ready', () async {
    final none = await loader().load(validateKitSet([symbolKit('alpha', [])]));
    expect(none.state, SymbolsState.ready);
    expect(none.symbols, isEmpty);
    final bad = SymbolLibrarySource(
        label: 'bad', read: () async => throw StateError('gone'));
    final all = await loader().load(validateKitSet([
      symbolKit('alpha', [bad]),
      symbolKit('beta', [
        SymbolLibrarySource(
            label: 'mismatch', read: () async => itemsBytes('alpha', ['x'])),
      ]),
    ]));
    expect(all.state, SymbolsState.failed);
    // M-S6: `failed == total` written `failed > 0`.
    final one = await loader().load(validateKitSet([
      symbolKit('alpha', [
        bad,
        SymbolLibrarySource(
            label: 'ok', read: () async => itemsBytes('alpha', ['one'])),
      ]),
    ]));
    expect(one.state, SymbolsState.ready);
  });

  test(
      'S-7 a source is read once across loads and kit sets; a failed read '
      'is not kept, so the next load reads it again', () async {
    final good = CountingSource('good', () async => itemsBytes('alpha', ['a']));
    var fail = true;
    final flaky = CountingSource('flaky', () async {
      if (fail) throw StateError('not yet');
      return itemsBytes('beta', ['b']);
    });
    final l = loader();
    final kits = validateKitSet([
      symbolKit('alpha', [good.source]),
      symbolKit('beta', [flaky.source]),
    ]);
    final first = await l.load(kits);
    expect(idsOf(first.symbols), ['alpha.item.a@1']);
    // Another kit set over the same sources.
    final again = await l.load(validateKitSet([
      symbolKit('beta', [flaky.source]),
      symbolKit('alpha', [good.source]),
    ]));
    await settle();
    // M-S7a: the cache dropped (good is read again).
    expect(good.reads, 1);
    expect(idsOf(again.symbols), ['alpha.item.a@1']);
    fail = false;
    final third = await l.load(kits);
    // M-S7b: the eviction of a failed read dropped (flaky stays failed).
    expect(idsOf(third.symbols), ['alpha.item.a@1', 'beta.item.b@1']);
    expect(flaky.reads, 3);
  });

  test('S-8 a disposed loader refuses to load', () async {
    final l = PlanSymbolLoader();
    expect(l.isDisposed, isFalse);
    l.dispose();
    expect(l.isDisposed, isTrue);
    expect(() => l.load(validateKitSet([symbolKit('alpha', [])])),
        throwsStateError);
  });
}
