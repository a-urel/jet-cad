import 'package:meta/meta.dart';

import '../core/handle.dart';

/// Inherit from the record's layer.
const int kByLayer = -1;

/// Inherit from the placing instance's own value.
const int kByBlock = -2;

/// Lineweight only: use the document default.
const int kLineweightDefault = -3;

/// Tags a true colour so it cannot be confused with an indexed one.
const int _kTrueColorTag = 0x01000000;

/// A tier-1 CAD colour: a native field, not a component.
///
/// Alpha is deliberately absent. DXF transparency is an independent field that
/// may itself be BYLAYER or BYBLOCK, so carrying alpha here would create a
/// second, conflicting source of truth for the same pixel.
@immutable
sealed class DraftColor {
  const DraftColor();
}

final class ByLayerColor extends DraftColor {
  const ByLayerColor();
  @override
  bool operator ==(Object other) => other is ByLayerColor;
  @override
  int get hashCode => kByLayer;
  @override
  String toString() => 'ByLayerColor()';
}

final class ByBlockColor extends DraftColor {
  const ByBlockColor();
  @override
  bool operator ==(Object other) => other is ByBlockColor;
  @override
  int get hashCode => kByBlock;
  @override
  String toString() => 'ByBlockColor()';
}

/// AutoCAD Color Index, 1..255.
final class IndexedColor extends DraftColor {
  final int aci;
  const IndexedColor(this.aci);
  @override
  bool operator ==(Object other) => other is IndexedColor && other.aci == aci;
  @override
  int get hashCode => Object.hash('aci', aci);
  @override
  String toString() => 'IndexedColor($aci)';
}

/// 24-bit RGB, `0xRRGGBB`.
final class TrueColor extends DraftColor {
  final int rgb;
  const TrueColor(this.rgb);
  @override
  bool operator ==(Object other) => other is TrueColor && other.rgb == rgb;
  @override
  int get hashCode => Object.hash('rgb', rgb);
  @override
  String toString() => 'TrueColor(0x${rgb.toRadixString(16).padLeft(6, '0')})';
}

/// Packs a colour into the single `Int32` an entity column holds.
///
/// True colours are tagged rather than stored raw, because an untagged 24-bit
/// value overlaps the 1..255 indexed range: `0x0000FF` and ACI 255 would be the
/// same integer.
int encodeColor(DraftColor color) => switch (color) {
      ByLayerColor() => kByLayer,
      ByBlockColor() => kByBlock,
      IndexedColor(:final aci) when aci >= 1 && aci <= 255 => aci,
      IndexedColor(:final aci) =>
        throw ArgumentError.value(aci, 'aci', 'must be 1..255'),
      TrueColor(:final rgb) when rgb >= 0 && rgb <= 0xFFFFFF =>
        _kTrueColorTag | rgb,
      TrueColor(:final rgb) =>
        throw ArgumentError.value(rgb, 'rgb', 'must be 0..0xFFFFFF'),
    };

DraftColor decodeColor(int encoded) {
  if (encoded == kByLayer) return const ByLayerColor();
  if (encoded == kByBlock) return const ByBlockColor();
  if (encoded >= 1 && encoded <= 255) return IndexedColor(encoded);
  if (encoded >= _kTrueColorTag && encoded <= (_kTrueColorTag | 0xFFFFFF)) {
    return TrueColor(encoded & 0xFFFFFF);
  }
  throw ArgumentError.value(encoded, 'encoded', 'not a colour encoding');
}

/// Handles the document reserves for records that must always exist.
///
/// DXF's BYLAYER and BYBLOCK linetypes are real table records rather than magic
/// values, and layer 0 carries the block-inheritance rule. Reserving their
/// handles means the linetype column needs no sentinels and style resolution
/// walks one uniform path.
abstract final class ReservedHandles {
  static const Handle layerZero = Handle(1);
  static const Handle byLayerLinetype = Handle(2);
  static const Handle byBlockLinetype = Handle(3);
  static const Handle continuousLinetype = Handle(4);
  static const Handle standardTextStyle = Handle(5);

  /// The document's handle seed is raised to at least this value, so no
  /// allocated handle can ever collide with a reserved one.
  static const Handle firstFree = Handle(16);
}

/// Bit flags in the entity `flags` column.
abstract final class EntityFlags {
  /// DXF group code 60: the entity exists but is not drawn.
  static const int invisible = 1 << 0;
}
