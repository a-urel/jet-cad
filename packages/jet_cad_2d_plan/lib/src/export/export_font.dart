// Ported from jet_cad_floor_plan/lib/src/export/export_font.dart: the font
// the PDF export embeds, read once per controller. The font, its asset key
// and its licence are the plan library's (lib/src/fonts/plan_fonts.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../fonts/plan_fonts.dart' show kPlanFontAsset;
import 'registries.dart';

/// Reads the bundled font's bytes from [bundle] ([rootBundle] when null).
Future<Uint8List> loadExportFont([AssetBundle? bundle]) async {
  final data = await (bundle ?? rootBundle).load(kPlanFontAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// The font's bytes, read on first use and then held for the app's
/// lifetime (spec 13 D7: "once per app"). A failed read is not held: the
/// next [bytes] reads again.
class ExportFontCache implements PlanExportFonts {
  /// [load] is the test seam; the default is [loadExportFont].
  ExportFontCache({Future<Uint8List> Function()? load})
      : _load = load ?? loadExportFont;

  final Future<Uint8List> Function() _load;
  Future<Uint8List>? _bytes;

  /// The font's bytes; every call after the first returns the same future.
  @override
  Future<Uint8List> get bytes {
    final pending = _bytes;
    if (pending != null) return pending;
    final next = _load();
    _bytes = next;
    next.then<void>((_) {}, onError: (Object _) {
      if (identical(_bytes, next)) _bytes = null;
    });
    return next;
  }
}
