// Spec P2 "Symbol libraries" (Task 13): one symbol the plan offers, with
// the kit that gave it and that kit's words.
import 'package:meta/meta.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitNames, SymbolComponent, SymbolEntry;

@immutable
final class PlanSymbol {
  const PlanSymbol(
      {required this.kitId, required this.names, required this.entry});

  /// The kit whose library gave it.
  final String kitId;

  /// That kit's words (its `symbol:` and `category:` words).
  final KitNames names;

  /// The library's entry: identity, unit, definition, leaves.
  final SymbolEntry entry;

  /// `key@version`, the gallery's and the loader's identity.
  String get id => entry.id;

  SymbolComponent get component => entry.symbol;

  @override
  String toString() => 'PlanSymbol($kitId: $id)';
}
