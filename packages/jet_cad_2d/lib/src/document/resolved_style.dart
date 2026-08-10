import 'package:meta/meta.dart';

import '../core/handle.dart';

/// One entity's concrete paint under a [StyleContext].
@immutable
final class ResolvedStyle {
  const ResolvedStyle({
    required this.argb,
    required this.lineweightHundredths,
    required this.linetype,
    required this.linetypeScale,
  });

  /// 0xAARRGGBB. Alpha is `255 - transparency`.
  final int argb;

  /// Paper-space width in 1/100 mm. **Not** a world quantity.
  final int lineweightHundredths;

  final Handle linetype;
  final double linetypeScale;

  @override
  bool operator ==(Object other) =>
      other is ResolvedStyle &&
      other.argb == argb &&
      other.lineweightHundredths == lineweightHundredths &&
      other.linetype == linetype &&
      other.linetypeScale == linetypeScale;

  @override
  int get hashCode =>
      Object.hash(argb, lineweightHundredths, linetype, linetypeScale);
}

/// AutoCAD Color Index to RGB.
///
/// The first nine entries are the standard fixed colours and are exact. Beyond
/// them this is a **declared approximation** over the 240-colour cube; the full
/// table is a DXF-plan concern, where it can be checked against real files
/// rather than transcribed from memory. Callers that need exactness above 9
/// should use `TrueColor`.
int aciToRgb(int aci) {
  const fixed = <int>[
    0x000000, // 0 — ByBlock placeholder, never resolved to
    0xFF0000, // 1 red
    0xFFFF00, // 2 yellow
    0x00FF00, // 3 green
    0x00FFFF, // 4 cyan
    0x0000FF, // 5 blue
    0xFF00FF, // 6 magenta
    0xFFFFFF, // 7 white/black-on-light
    0x808080, // 8 dark grey
    0xC0C0C0, // 9 light grey
  ];
  if (aci >= 0 && aci < fixed.length) return fixed[aci];
  if (aci >= 250 && aci <= 255) {
    final v = 0x33 + (aci - 250) * 0x22;
    return (v << 16) | (v << 8) | v;
  }
  final i = (aci - 10) % 240;
  final r = 0x33 * (1 + (i ~/ 80));
  final g = 0x33 * (1 + ((i ~/ 16) % 5));
  final b = 0x33 * (1 + (i % 16) ~/ 3);
  return (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255);
}
