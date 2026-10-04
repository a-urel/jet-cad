// Spec 14 V-4, plan Task 5: the loader reads several libraries and merges
// them in order; any failing source fails the load, Retry reads every
// source again, and a key and version in two sources is refused.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/symbol_sources.dart';
import 'package:jet_cad_floor_plan/symbols.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart'
    show SymbolLibraryLoader;
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart';

/// A one-circle symbol [key] in [category], off the origin.
FurnitureSymbol symbol(String key, String category, {int version = 1}) =>
    FurnitureSymbol(
      key: key,
      name: key,
      category: category,
      tags: const ['test', 'symbol'],
      version: version,
      baseX: 300,
      baseY: 200,
      shapes: const [CircleShape(300, 200, 150)],
    );

Uint8List bytesOf(List<FurnitureSymbol> catalog) => Uint8List.fromList(utf8
    .encode(DraftDocumentCodec.encodeToString(buildSymbolLibrary(catalog))));

/// A source that counts its reads and fails while [failing] is set.
class Counted {
  Counted(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
  int reads = 0;
  bool failing = false;

  SymbolLibrarySource get source => SymbolLibrarySource(
      name: name,
      read: () async {
        reads++;
        if (failing) throw StateError('$name is unreadable');
        return bytes;
      });
}

List<String> idsOf(SymbolLibrary lib) =>
    [for (final e in lib.entries) '${e.key}@${e.version}'];

void main() {
  test('LS1 two sources merge in order; categories keep first appearance',
      () async {
    final a =
        Counted('first', bytesOf([symbol('a.one', 'X'), symbol('a.two', 'Y')]));
    final b = Counted(
        'second', bytesOf([symbol('b.one', 'Y'), symbol('b.two', 'Z')]));
    final loader = SymbolLibraryLoader(sources: [a.source, b.source]);
    addTearDown(loader.dispose);
    await loader.load();
    final lib = (loader.state as SymbolLibraryReady).library;
    expect(idsOf(lib), ['a.one@1', 'a.two@1', 'b.one@1', 'b.two@1']);
    expect(lib.categories, ['X', 'Y', 'Z']);
    expect((a.reads, b.reads), (1, 1));
  });

  test('LS2 one failing source fails the load; Retry reads every source',
      () async {
    final a = Counted('first', bytesOf([symbol('a.one', 'X')]));
    final b = Counted('second', bytesOf([symbol('b.one', 'Y')]))
      ..failing = true;
    final loader = SymbolLibraryLoader(sources: [a.source, b.source]);
    addTearDown(loader.dispose);
    await loader.load();
    expect(loader.state, isA<SymbolLibraryFailed>());
    expect((a.reads, b.reads), (1, 1));

    b.failing = false;
    await loader.retry();
    final lib = (loader.state as SymbolLibraryReady).library;
    expect(idsOf(lib), ['a.one@1', 'b.one@1']);
    expect((a.reads, b.reads), (2, 2), reason: 'Retry reads every source');
  });

  test('LS3 a key and version in two sources is refused, naming both',
      () async {
    final a = Counted('furniture', bytesOf([symbol('shared.table', 'X')]));
    final b = Counted('restaurant',
        bytesOf([symbol('other.piece', 'Y'), symbol('shared.table', 'Y')]));
    final loader = SymbolLibraryLoader(sources: [a.source, b.source]);
    addTearDown(loader.dispose);
    await loader.load();
    final failed = loader.state as SymbolLibraryFailed;
    expect(failed.error, isA<SymbolLibraryError>());
    final message = (failed.error as SymbolLibraryError).message;
    expect(message, contains('shared.table@1'));
    expect(message, contains('"furniture"'));
    expect(message, contains('"restaurant"'));
  });

  test('LS4 the same key at another version in another source is kept',
      () async {
    final a = Counted('first', bytesOf([symbol('k.table', 'X')]));
    final b = Counted('second', bytesOf([symbol('k.table', 'X', version: 2)]));
    final loader = SymbolLibraryLoader(sources: [a.source, b.source]);
    addTearDown(loader.dispose);
    await loader.load();
    expect(idsOf((loader.state as SymbolLibraryReady).library),
        ['k.table@1', 'k.table@2']);
  });

  test('LS5 the default is the furniture library alone; bad arguments throw',
      () {
    final loader = SymbolLibraryLoader();
    addTearDown(loader.dispose);
    expect(loader.sources, [furnitureSymbolSource]);
    expect(furnitureSymbolSource.name, 'furniture');
    final seam = SymbolLibraryLoader(read: () async => Uint8List(0));
    addTearDown(seam.dispose);
    expect(seam.sources.single.name, 'library');
    expect(
        () => SymbolLibraryLoader(
            read: () async => Uint8List(0), sources: [furnitureSymbolSource]),
        throwsArgumentError);
    expect(() => SymbolLibraryLoader(sources: const []), throwsArgumentError);
  });
}
