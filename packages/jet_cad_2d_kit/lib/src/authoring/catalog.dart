// The catalog language (spec K6): a kit's symbols as plain data, in
// millimetres, each in its own frame. Geometry only: lines, polylines,
// circles and arcs. Replaces jet_cad_floor_plan's FurnitureSymbol and
// FurnitureShape.
//
// Pure Dart: no Flutter, no dart:io.
import '../model/unit_component.dart';

/// A point, (x, y) in millimetres.
typedef CatalogPoint = (double, double);

/// One drawn shape of a symbol.
sealed class CatalogShape {
  const CatalogShape();
}

final class CatalogLine extends CatalogShape {
  const CatalogLine(this.from, this.to);

  final CatalogPoint from;
  final CatalogPoint to;
}

/// A polyline through [points]; [closed] repeats the first point.
final class CatalogPolyline extends CatalogShape {
  const CatalogPolyline(this.points, {this.closed = false});

  final List<CatalogPoint> points;
  final bool closed;
}

final class CatalogCircle extends CatalogShape {
  const CatalogCircle(this.center, this.radius);

  final CatalogPoint center;
  final double radius;
}

/// An arc from the angle [start] through the signed [sweep], both in
/// radians: a positive sweep turns counter-clockwise from [start], a negative
/// one clockwise.
final class CatalogArc extends CatalogShape {
  const CatalogArc(this.center, this.radius, this.start, this.sweep);

  final CatalogPoint center;
  final double radius;
  final double start;
  final double sweep;
}

/// A symbol's service unit (umbrella A6).
final class CatalogUnit {
  const CatalogUnit({
    required this.kind,
    required this.capacity,
    this.labelling = UnitLabelling.numbered,
  });

  final String kind;
  final int capacity;
  final UnitLabelling labelling;
}

/// One symbol of a kit's library. A unit draws its outline first (K3 rule
/// 11): a closed polyline or a circle. A [retired] symbol stays in the
/// library and leaves the gallery (contract R2).
final class CatalogSymbol {
  const CatalogSymbol({
    required this.key,
    this.version = 1,
    required this.name,
    required this.category,
    this.tags = const [],
    this.attachTo = const [],
    this.family,
    this.unit,
    required this.base,
    required this.shapes,
    this.retired = false,
  });

  final String key;
  final int version;
  final String name;
  final String category;
  final List<String> tags;
  final List<String> attachTo;
  final String? family;
  final CatalogUnit? unit;
  final CatalogPoint base;
  final List<CatalogShape> shapes;
  final bool retired;

  /// `key@version`.
  String get id => '$key@$version';
}

/// A kit's symbols, in library order.
final class Catalog {
  const Catalog({required this.kit, required this.symbols});

  final String kit;
  final List<CatalogSymbol> symbols;
}
