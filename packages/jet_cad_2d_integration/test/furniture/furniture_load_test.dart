// 3a Tasks 23-24 (spec C4, C5, C6): the kit's furniture library loads in a
// plan from the package's asset key, named in the kit's words, and its
// wall-face kind is offered.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitDiagnosticCode, SymbolsState;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// Lets the library's load (a real asset read through the test binding,
/// then a decode) finish: polls [c]'s state, at most about half a second.
/// The plan library's own `settle` (twenty zero delays,
/// `test/support/symbol_fixtures.dart:248-252`) serves in-memory reads only.
Future<void> settle(PlanController c) async {
  for (var i = 0;
      i < 500 && c.symbolsState.value == SymbolsState.loading;
      i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'FU-load the furniture library loads from the kit\'s package key: 41 '
      'symbols of the kit, architecture.*@1 in catalog order, named in '
      'German and Turkish by the kit\'s words; no library diagnostic',
      () async {
    final c = architectureController();
    addTearDown(c.dispose);
    await settle(c);
    expect(c.symbolsState.value, SymbolsState.ready);
    final ids = [for (final s in c.symbols) s.id];
    expect(ids, hasLength(41));
    expect(ids.first, 'architecture.dining.table.square.two@1');
    expect(ids.last, 'architecture.office.bookshelf@1');
    expect(
        ids.every((id) => id.startsWith('architecture.') && id.endsWith('@1')),
        isTrue);
    expect({for (final s in c.symbols) s.kitId}, {'architecture'});
    final bed = c.symbolById('architecture.bed.double@1')!;
    expect(bed.names.symbolName('de', bed.component), 'Doppelbett');
    expect(bed.names.symbolName('tr', bed.component), 'Çift kişilik yatak');
    expect(bed.names.categoryName('de', 'architecture', bed.component.category),
        'Schlafzimmer');
    expect([
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.libraryUnreadable ||
            d.code == KitDiagnosticCode.libraryKitMismatch ||
            d.code == KitDiagnosticCode.symbolDuplicate)
          d.code,
    ], isEmpty);
  });

  test(
      'WF-offered every attachment kind the library names is offered: no '
      'attachmentKindUnoffered once the symbols load', () async {
    final c = architectureController();
    addTearDown(c.dispose);
    await settle(c);
    expect(c.symbolsState.value, SymbolsState.ready);
    expect(c.symbols.where((s) => s.component.attachTo.contains('wall-face')),
        hasLength(30),
        reason: 'premise: the library names wall-face');
    expect([
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.attachmentKindUnoffered) d.subject,
    ], isEmpty);
  });
}
