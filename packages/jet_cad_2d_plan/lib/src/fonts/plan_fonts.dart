// The plan's font (spec P5 "Fonts", today's host guide §2, moved
// unchanged): documents name the family `Roboto`, and the measurer uses
// that name verbatim, but a font a package declares registers as
// `packages/jet_cad_2d_plan/Roboto`. So the package registers the bare
// family itself, from its own bytes, before the first document is
// measured: the screen then lays text out in the same face the PDF embeds,
// on every platform, whatever the host's default font. Its Apache 2.0
// licence is registered at start-up by [registerFontLicences]. Ported from
// jet_cad_floor_plan's fonts.dart and export_font.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, FontLoader, rootBundle;

/// The family documents name and the plan library registers.
const String kPlanFontFamily = 'Roboto';

/// The bundled font's asset key: the package's `lib/fonts/` file, declared
/// under `assets:` in its `pubspec.yaml`, so every host has it. It lives
/// under `lib/` so a host can also declare the bare family `Roboto` from it
/// (`packages/jet_cad_2d_plan/fonts/Roboto-Regular.ttf`); either way
/// [ensurePlanFonts] registers `Roboto` from these bytes.
const String kPlanFontAsset =
    'packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf';

/// The font's licence text (declared under `assets:` in the package's
/// `pubspec.yaml`).
const String kPlanFontLicenceAsset =
    'packages/jet_cad_2d_plan/assets/fonts/Roboto_LICENSE.txt';

Future<void>? _registered;

/// Forgets the registration, so the next [ensurePlanFonts] registers again:
/// a test seam (the registration is process-wide, and a test must not
/// inherit another's pending future). The engine keeps any face already
/// loaded.
@visibleForTesting
void resetPlanFontsForTest() => _registered = null;

/// Registers family [kPlanFontFamily] from the package's bundled Roboto
/// (read from [bundle], [rootBundle] when null). Once per process: every
/// call after the first returns the first call's future, unless that one
/// failed, in which case the next call tries again. A host awaits it before
/// `runApp` (after `WidgetsFlutterBinding.ensureInitialized()`).
Future<void> ensurePlanFonts([AssetBundle? bundle]) {
  final pending = _registered;
  if (pending != null) return pending;
  final loader = FontLoader(kPlanFontFamily)
    ..addFont((bundle ?? rootBundle).load(kPlanFontAsset));
  final next = loader.load();
  _registered = next;
  next.then<void>((_) {}, onError: (Object _) {
    if (identical(_registered, next)) _registered = null;
  });
  return next;
}

/// Registers the font's licence with [LicenseRegistry] under the package
/// name `Roboto`, its text read from [bundle] ([rootBundle] when null) when
/// the licences are collected.
void registerFontLicences([AssetBundle? bundle]) {
  LicenseRegistry.addLicense(() async* {
    final text = await (bundle ?? rootBundle).loadString(kPlanFontLicenceAsset);
    yield LicenseEntryWithLineBreaks(const <String>['Roboto'], text);
  });
}
