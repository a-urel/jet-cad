import 'package:meta/meta.dart';

import '../core/handle.dart';
import 'style.dart';

/// Everything a definition's BYBLOCK / layer-0 contents resolve against.
///
/// Value equality and a stable hashCode are required: Plan 3b keys the
/// definition picture cache on this, and a context that compares by identity
/// would give every instance its own cache entry.
@immutable
final class StyleContext {
  const StyleContext({
    required this.color,
    required this.linetype,
    required this.linetypeScale,
    required this.lineweight,
    required this.transparency,
    required this.layer,
  });

  /// Encoded and **concrete** — never [kByLayer] or [kByBlock].
  final int color;
  final Handle linetype;
  final double linetypeScale;

  /// 1/100 mm, concrete.
  final int lineweight;

  /// 0..255, concrete.
  final int transparency;

  /// The layer a layer-0 entity inherits.
  final Handle layer;

  static const StyleContext documentRoot = StyleContext(
    color: 7, // ACI 7: the DXF default foreground
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0,
    lineweight: 25, // 0.25 mm
    transparency: 0,
    layer: ReservedHandles.layerZero,
  );

  StyleContext copyWith({
    int? color,
    Handle? linetype,
    double? linetypeScale,
    int? lineweight,
    int? transparency,
    Handle? layer,
  }) =>
      StyleContext(
        color: color ?? this.color,
        linetype: linetype ?? this.linetype,
        linetypeScale: linetypeScale ?? this.linetypeScale,
        lineweight: lineweight ?? this.lineweight,
        transparency: transparency ?? this.transparency,
        layer: layer ?? this.layer,
      );

  @override
  bool operator ==(Object other) =>
      other is StyleContext &&
      other.color == color &&
      other.linetype == linetype &&
      other.linetypeScale == linetypeScale &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.layer == layer;

  @override
  int get hashCode => Object.hash(
      color, linetype, linetypeScale, lineweight, transparency, layer);
}
