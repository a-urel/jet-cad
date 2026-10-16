// Sub-project 4a Task 1: the committed asset and snapshot equal what the
// catalog builds, the library decodes with 69 symbols in six categories, and
// the definitions the build-time map yields are the loader's.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_kit_restaurant/src/catalog/restaurant_catalog.dart';

Uint8List assetBytes() =>
    File('assets/library/restaurant.jetlib').readAsBytesSync();

void main() {
  group('the asset', () {
    test('the committed bytes equal the built library', () {
      expect(encodeLibrary(restaurantCatalog), orderedEquals(assetBytes()),
          reason: 'run `dart run tool/generate_restaurant_library.dart`');
    });

    test('building twice gives identical bytes', () {
      expect(encodeLibrary(restaurantCatalog),
          orderedEquals(encodeLibrary(restaurantCatalog)));
    });

    test('is declared in the pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
          RegExp(
                  r'^\s*assets:\s*\n(\s*-\s+.*\n)*?\s*-\s+assets/library/'
                  r'restaurant\.jetlib\s*$',
                  multiLine: true)
              .hasMatch(pubspec),
          isTrue);
    });

    test('the committed snapshot holds every key@1 at its built geometry', () {
      final committed = parseSnapshot(
          File('assets/library/restaurant.snapshot.json').readAsStringSync());
      expect(committed, geometrySnapshot(restaurantCatalog),
          reason: 'run `dart run tool/generate_restaurant_library.dart`');
      expect(committed.length, 69);
    });

    test('ships 69 symbols in six categories, in palette order', () {
      final lib = SymbolLibrary.decode(assetBytes());
      expect(lib.entries.length, 69);
      expect(lib.categories, [
        'Restaurant Tables',
        'Booths and Lounge',
        'Bar',
        'Service',
        'Commercial Kitchen',
        'Outdoor and Decor',
      ]);
      expect(lib.categories, restaurantCategories);
    });

    test('leaf handles ascend across the whole library', () {
      final handles = [
        for (final e in SymbolLibrary.decode(assetBytes()).entries)
          for (final l in e.leaves) l.record.handle.value,
      ];
      expect([...handles]..sort(), handles);
    });
  });

  group('RestaurantSymbols', () {
    test('names every catalog key once, in catalog order', () {
      // Written from the catalog, one name per symbol; a constant that is
      // missing or misspelt breaks the count or the equality.
      final keys = SymbolLibrary.decode(assetBytes())
          .entries
          .map((e) => e.symbol.key)
          .toList();
      expect(keys.length, 69);
      expect(keys.toSet().length, 69);
      expect(keys, [
        RestaurantSymbols.tableSquareTwo,
        RestaurantSymbols.tableSquareFour,
        RestaurantSymbols.tableRectFour,
        RestaurantSymbols.tableRectSix,
        RestaurantSymbols.tableRectEight,
        RestaurantSymbols.tableRectTen,
        RestaurantSymbols.tableRectTwelve,
        RestaurantSymbols.tableRoundTwo,
        RestaurantSymbols.tableRoundFour,
        RestaurantSymbols.tableRoundSix,
        RestaurantSymbols.tableRoundEight,
        RestaurantSymbols.tableRoundTen,
        RestaurantSymbols.boothTwo,
        RestaurantSymbols.boothFour,
        RestaurantSymbols.boothSix,
        RestaurantSymbols.boothCorner,
        RestaurantSymbols.boothRound,
        RestaurantSymbols.banquetteTwo,
        RestaurantSymbols.banquetteFour,
        RestaurantSymbols.loungeFour,
        RestaurantSymbols.loungeTwo,
        RestaurantSymbols.barStool,
        RestaurantSymbols.barTableHighTwo,
        RestaurantSymbols.barTableHighFour,
        RestaurantSymbols.barTableLedge,
        RestaurantSymbols.barCounter,
        RestaurantSymbols.barCounterCorner,
        RestaurantSymbols.barCounterU,
        RestaurantSymbols.barBack,
        RestaurantSymbols.barTaps,
        RestaurantSymbols.cashierDesk,
        RestaurantSymbols.hostStand,
        RestaurantSymbols.posTerminal,
        RestaurantSymbols.serviceStation,
        RestaurantSymbols.buffetCounter,
        RestaurantSymbols.saladBar,
        RestaurantSymbols.dessertDisplay,
        RestaurantSymbols.drinksFridge,
        RestaurantSymbols.coffeeStation,
        RestaurantSymbols.serviceCart,
        RestaurantSymbols.trayStand,
        RestaurantSymbols.highchairChild,
        RestaurantSymbols.waitingBench,
        RestaurantSymbols.coatRack,
        RestaurantSymbols.kitchenPass,
        RestaurantSymbols.kitchenPrepTable,
        RestaurantSymbols.kitchenRangeFour,
        RestaurantSymbols.kitchenRangeSix,
        RestaurantSymbols.kitchenFryer,
        RestaurantSymbols.kitchenGriddle,
        RestaurantSymbols.kitchenOvenConvection,
        RestaurantSymbols.kitchenOvenPizza,
        RestaurantSymbols.kitchenDishwasher,
        RestaurantSymbols.kitchenSinkThree,
        RestaurantSymbols.kitchenSinkHand,
        RestaurantSymbols.kitchenFridgeReachin,
        RestaurantSymbols.kitchenFreezer,
        RestaurantSymbols.kitchenWalkin,
        RestaurantSymbols.kitchenShelving,
        RestaurantSymbols.kitchenIceMachine,
        RestaurantSymbols.kitchenBin,
        RestaurantSymbols.parasolRound,
        RestaurantSymbols.heaterPatio,
        RestaurantSymbols.planterRound,
        RestaurantSymbols.planterLong,
        RestaurantSymbols.partitionScreen,
        RestaurantSymbols.stagePlatform,
        RestaurantSymbols.djBooth,
        RestaurantSymbols.pianoGrand,
      ]);
    });
  });

  group('restaurantSymbolDefinitions', () {
    test('holds every key@1, each equal to the loader\'s decode of the asset',
        () {
      final defs = restaurantSymbolDefinitions();
      final decoded = SymbolLibrary.decode(assetBytes());
      expect(defs.keys.toList(), [for (final e in decoded.entries) e.id]);
      expect(defs.length, 69);
      for (final e in decoded.entries) {
        final d = defs[e.id]!;
        expect(d.name, e.definition.name, reason: e.id);
        expect(d.handle, e.definition.handle, reason: e.id);
        expect(d.basePoint, e.definition.basePoint, reason: e.id);
        expect(d.children, e.definition.children, reason: e.id);
      }
    });

    test('is cached and unmodifiable', () {
      expect(
          identical(
              restaurantSymbolDefinitions(), restaurantSymbolDefinitions()),
          isTrue);
      expect(
          () => restaurantSymbolDefinitions().clear(), throwsUnsupportedError);
    });
  });
}
