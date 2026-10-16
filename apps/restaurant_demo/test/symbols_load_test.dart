// RL15 (restaurant-kit audit, SPLIT; old restaurant_library_test): both
// kits' libraries load together through the plan library's loader -- 41
// furniture symbols then 69 restaurant ones, six categories then six, in
// kit order, no diagnostic. Here and not in a kit: a kit may name neither
// the plan library nor another kit.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

List<String> categoriesOf(Iterable<PlanSymbol> symbols) {
  final seen = <String>[];
  for (final s in symbols) {
    if (!seen.contains(s.component.category)) seen.add(s.component.category);
  }
  return seen;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'RL15 the furniture and restaurant libraries load together without a '
      'clash', () async {
    final loader = PlanSymbolLoader();
    addTearDown(loader.dispose);
    final both =
        await loader.load(validateKitSet([architectureKit, restaurantKit]));
    expect(both.diagnostics, isEmpty);
    expect(both.state, SymbolsState.ready);

    final furniture = await loader.load(validateKitSet([architectureKit]));
    final restaurant = await loader.load(validateKitSet([restaurantKit]));
    expect(furniture.symbols, hasLength(41), reason: 'premise');
    expect(restaurant.symbols, hasLength(69), reason: 'premise');
    expect(both.symbols, hasLength(41 + 69));
    // Kit order, then each kit's own order.
    expect([
      for (final s in both.symbols) s.id
    ], [
      for (final s in [...furniture.symbols, ...restaurant.symbols]) s.id
    ]);
    expect([for (final s in both.symbols.take(41)) s.kitId],
        everyElement('architecture'));
    expect([for (final s in both.symbols.skip(41)) s.kitId],
        everyElement('restaurant'));
    // Six categories, then six more: no category is shared.
    final fc = categoriesOf(furniture.symbols);
    final rc = categoriesOf(restaurant.symbols);
    expect(fc, hasLength(6));
    expect(rc, hasLength(6));
    expect(categoriesOf(both.symbols), [...fc, ...rc]);
    expect(fc.toSet().intersection(rc.toSet()), isEmpty);
    // Every id is once.
    expect({for (final s in both.symbols) s.id}, hasLength(110));
  });
}
