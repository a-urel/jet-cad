// Spec 09b D2, R-4, plan 09b Task 2: the symbol library's loader (loading,
// ready, failed, retry) and its wiring: the app owns one loader, loads it
// once, and the host hands it to every shell it builds.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_shell.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_library_loader.dart';
import 'package:floor_planner/symbols/symbol_library_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/document_rig.dart' show hostOf;
import '../support/fake_document_files.dart';
import '../support/symbol_fixtures.dart';

final Uint8List assetBytes =
    File('assets/library/furniture.jetlib').readAsBytesSync();

/// The keys of the real asset, decoded independently of the loader.
final List<String> assetKeys = [
  for (final e in SymbolLibrary.decode(assetBytes).entries)
    '${e.key}@${e.version}',
];

/// A loader over [read] that records every state it notifies.
({SymbolLibraryLoader loader, List<SymbolLibraryState> seen}) recording(
    Future<Uint8List> Function() read) {
  final loader = SymbolLibraryLoader(read: read);
  final seen = <SymbolLibraryState>[];
  loader.addListener(() => seen.add(loader.state));
  return (loader: loader, seen: seen);
}

List<String> keysOf(SymbolLibraryState state) => [
      for (final e in (state as SymbolLibraryReady).library.entries)
        '${e.key}@${e.version}',
    ];

void main() {
  test('premise: the real asset holds many symbols', () {
    expect(assetKeys.length, greaterThan(20));
  });

  group('the loader', () {
    test(
        'SL1 starts loading; load() reaches ready with the real asset, one '
        'notification, one read', () async {
      var reads = 0;
      final r = recording(() async {
        reads++;
        return assetBytes;
      });
      expect(r.loader.state, isA<SymbolLibraryLoading>());
      await r.loader.load();
      expect(keysOf(r.loader.state), assetKeys);
      expect(r.seen, hasLength(1));
      expect(r.seen.single, same(r.loader.state));
      expect(reads, 1);

      // A second load() reads nothing and notifies nothing.
      await r.loader.load();
      expect(reads, 1);
      expect(r.seen, hasLength(1));
      r.loader.dispose();
    });

    test('SL2 a missing asset (the read throws) fails with that error',
        () async {
      final r = recording(
          () => File('assets/library/no-such-library.jetlib').readAsBytes());
      await r.loader.load();
      final state = r.loader.state;
      expect(state, isA<SymbolLibraryFailed>());
      expect(
          (state as SymbolLibraryFailed).error, isA<PathNotFoundException>());
      expect(r.seen, hasLength(1));
      r.loader.dispose();
    });

    test(
        'SL3 corrupt bytes (the real asset cut in half) fail with a '
        'SymbolLibraryError', () async {
      final cut = Uint8List.sublistView(assetBytes, 0, assetBytes.length ~/ 2);
      final r = recording(() async => cut);
      await r.loader.load();
      final state = r.loader.state as SymbolLibraryFailed;
      expect(state.error, isA<SymbolLibraryError>());
      expect(r.seen, hasLength(1));
      r.loader.dispose();
    });

    test(
        'SL4 a readable library the decoder refuses (an upper-case tag) '
        'fails with its SymbolLibraryError', () async {
      // Positive control: the untouched fixture loads.
      final good = recording(() async => bytesOf(buildValidLibrary()));
      await good.loader.load();
      expect(keysOf(good.loader.state),
          ['sofa.three@3', 'nightstand.single@2', 'armchair.single@1']);
      good.loader.dispose();

      final lib = validLibraryJson();
      symbolComponentJson(lib, sofaDef.value)['tags'] = [
        'sofa',
        'Seating',
        'couch',
      ];
      final r = recording(() async => bytesOfJson(lib));
      await r.loader.load();
      final error = (r.loader.state as SymbolLibraryFailed).error;
      expect(error, isA<SymbolLibraryError>());
      expect((error as SymbolLibraryError).message, contains('Seating'));
      expect(r.seen, hasLength(1));
      r.loader.dispose();
    });

    test('SL5 any throw fails, an Error as well as an Exception', () async {
      final r = recording(() async => throw StateError('the bundle is gone'));
      await r.loader.load();
      expect((r.loader.state as SymbolLibraryFailed).error, isA<StateError>());
      r.loader.dispose();
    });

    test(
        'SL6 retry() after a failure reads again and reaches ready: '
        'failed, loading, ready, each notified (M-09b10)', () async {
      var reads = 0;
      final r = recording(() async {
        reads++;
        if (reads == 1) throw const FileSystemException('first read fails');
        return assetBytes;
      });
      await r.loader.load();
      expect(r.loader.state, isA<SymbolLibraryFailed>());

      final retried = r.loader.retry();
      expect(r.loader.state, isA<SymbolLibraryLoading>(),
          reason: 'loading while the retry runs');
      await retried;
      expect(keysOf(r.loader.state), assetKeys);
      expect(reads, 2);
      expect(r.seen.map((s) => s.runtimeType).toList(), [
        SymbolLibraryFailed,
        SymbolLibraryLoading,
        SymbolLibraryReady,
      ]);
      r.loader.dispose();
    });

    test('SL7 retry() from loading or from ready does nothing', () async {
      var reads = 0;
      final gate = Completer<Uint8List>();
      final r = recording(() {
        reads++;
        return gate.future;
      });
      final loading = r.loader.load();
      unawaited(r.loader.retry());
      expect(reads, 1, reason: 'no retry while the first load runs');
      expect(r.seen, isEmpty);
      gate.complete(assetBytes);
      await loading;
      expect(r.loader.state, isA<SymbolLibraryReady>());

      final ready = r.loader.state;
      await r.loader.retry();
      expect(reads, 1, reason: 'no retry from ready');
      expect(r.loader.state, same(ready));
      expect(r.seen, hasLength(1));
      r.loader.dispose();
    });

    test(
        'SL8 load() after dispose reads nothing; a load that ends after '
        'dispose neither notifies nor throws', () async {
      var reads = 0;
      final after = SymbolLibraryLoader(read: () async {
        reads++;
        return assetBytes;
      });
      after.dispose();
      await after.load();
      expect(reads, 0);
      expect(after.state, isA<SymbolLibraryLoading>());

      final gate = Completer<Uint8List>();
      final during = SymbolLibraryLoader(read: () => gate.future);
      final running = during.load();
      during.dispose();
      gate.complete(assetBytes);
      await running;
      expect(during.state, isA<SymbolLibraryLoading>());
    });
  });

  testWidgets(
      'SL9 the default read loads the declared asset through rootBundle: the '
      'same symbols as the file', (tester) async {
    final loader = SymbolLibraryLoader();
    addTearDown(loader.dispose);
    await loader.load();
    expect(keysOf(loader.state), assetKeys);
  });

  group('the wiring (spec 09b D2, R-4)', () {
    /// A loader over the real bytes that counts its reads.
    ({SymbolLibraryLoader loader, int Function() reads}) counted() {
      var reads = 0;
      final loader = SymbolLibraryLoader(read: () async {
        reads++;
        return assetBytes;
      });
      return (loader: loader, reads: () => reads);
    }

    testWidgets(
        'SL10 the app loads a given loader once and the host hands it to the '
        'shell, before and after a document swap; the app does not dispose '
        'it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = counted();
      await tester.pumpWidget(
          FloorPlannerApp(files: FakeDocumentFiles(), symbols: c.loader));
      await tester.pump();
      expect(c.reads(), 1, reason: 'load() called in initState');
      expect(c.loader.state, isA<SymbolLibraryReady>());
      final first = tester.widget<PlannerShell>(find.byType(PlannerShell));
      expect(first.symbols, same(c.loader));

      final document = first.document;
      await hostOf(tester).newFlow();
      await tester.pump();
      final second = tester.widget<PlannerShell>(find.byType(PlannerShell));
      expect(second.document, isNot(same(document)),
          reason: 'premise: a new shell over a new document');
      expect(second.symbols, same(c.loader));
      expect(c.reads(), 1, reason: 'a swap does not read the asset again');

      await tester.pumpWidget(const SizedBox());
      // Still alive: a disposed ChangeNotifier refuses a listener.
      void listener() {}
      c.loader.addListener(listener);
      c.loader.removeListener(listener);
      c.loader.dispose();
    });

    testWidgets(
        'SL11 without a loader the app makes one, hands it to the shell and '
        'disposes it with itself', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(FloorPlannerApp(files: FakeDocumentFiles()));
      await tester.pump();
      final own =
          tester.widget<PlannerShell>(find.byType(PlannerShell)).symbols;
      expect(own, isNotNull);
      expect(tester.widget<DocumentHost>(find.byType(DocumentHost)).symbols,
          same(own));
      // The production path: the app's own loader reads the declared asset
      // through rootBundle and reaches ready (m-T2-1).
      expect(own!.state, isA<SymbolLibraryReady>());
      expect(keysOf(own.state), assetKeys);

      await tester.pumpWidget(const SizedBox());
      expect(() => own.addListener(() {}), throwsFlutterError,
          reason: 'disposed by the app that made it');
    });

    testWidgets('SL12 a bare shell has no loader', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PlannerShell()));
      expect(tester.widget<PlannerShell>(find.byType(PlannerShell)).symbols,
          isNull);
    });
  });
}
