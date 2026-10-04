// The planner's font (spec 14 V-11, R-9): documents name the family
// `Roboto` (`draft_document.dart`) and the measurer uses that name
// verbatim, but a font a package declares registers as
// `packages/jet_cad_floor_plan/Roboto`. So the package registers the bare
// family itself, from its own bytes, before the first document is measured:
// the screen then lays text out in the same face the PDF embeds, on every
// platform, whatever the host's default font.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetBundle, FontLoader, rootBundle;

import 'export/export_font.dart';

/// The family documents name and the planner registers.
const String kFloorPlanFontFamily = 'Roboto';

Future<void>? _registered;

/// Forgets the registration, so the next [ensureFloorPlanFonts] registers
/// again: a test seam (the registration is process-wide, and a test must
/// not inherit another's pending future). The engine keeps any face already
/// loaded.
@visibleForTesting
void resetFloorPlanFontsForTest() => _registered = null;

/// Registers family [kFloorPlanFontFamily] from the package's bundled Roboto
/// (read from [bundle], [rootBundle] when null). Once per process: every
/// call after the first returns the first call's future, unless that one
/// failed, in which case the next call tries again. A host awaits it before
/// `runApp` (after `WidgetsFlutterBinding.ensureInitialized()`).
Future<void> ensureFloorPlanFonts([AssetBundle? bundle]) {
  final pending = _registered;
  if (pending != null) return pending;
  final loader = FontLoader(kFloorPlanFontFamily)
    ..addFont((bundle ?? rootBundle).load(kExportFontAsset));
  final next = loader.load();
  _registered = next;
  next.then<void>((_) {}, onError: (Object _) {
    if (identical(_registered, next)) _registered = null;
  });
  return next;
}
