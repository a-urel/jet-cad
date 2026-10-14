// Colour targets (spec 2a P3, umbrella A3): how a type's component carries
// its colour, so the panel's colour row recolours a multiple selection of
// any kits' objects in one command.
//
// Free of Flutter: a swatch is a name from the plan's palette, not a Color.
import 'package:meta/meta.dart';

/// A type's colour: [read] gives its swatch (null: no colour of its own),
/// [write] a copy carrying another (null clears it). The plan library uses
/// it only through `PlanType.colourOf` and `PlanType.recolour`.
@immutable
final class ColourTarget<T> {
  const ColourTarget({required this.read, required this.write});

  final String? Function(T) read;
  final T Function(T, String?) write;
}
