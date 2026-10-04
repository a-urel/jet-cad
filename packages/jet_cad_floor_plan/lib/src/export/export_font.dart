// The font the PDF export embeds (spec 13 D7): the bundled Roboto, the same
// bytes the screen draws its text in. Read once per app (ExportFontCache,
// owned by FloorPlannerApp); its Apache 2.0 licence is registered at
// start-up (registerFontLicences, called from main()).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// The bundled font's asset key: the package's `lib/fonts/` file, declared
/// under `assets:` in its `pubspec.yaml`, so every host has it. It lives
/// under `lib/` so a host can also declare the bare family `Roboto` from it
/// (`packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf`), as
/// `apps/floor_planner` does (spec 14 V-11, review F-1); either way
/// `ensureFloorPlanFonts` registers `Roboto` from these bytes.
const String kExportFontAsset =
    'packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf';

/// The font's licence text (declared under `assets:` in the package's
/// `pubspec.yaml`).
const String kExportFontLicenceAsset =
    'packages/jet_cad_floor_plan/assets/fonts/Roboto_LICENSE.txt';

/// Reads the bundled font's bytes from [bundle] ([rootBundle] when null).
Future<Uint8List> loadExportFont([AssetBundle? bundle]) async {
  final data = await (bundle ?? rootBundle).load(kExportFontAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Registers the font's licence with [LicenseRegistry] under the package
/// name `Roboto`, its text read from [bundle] ([rootBundle] when null) when
/// the licences are collected.
void registerFontLicences([AssetBundle? bundle]) {
  LicenseRegistry.addLicense(() async* {
    final text =
        await (bundle ?? rootBundle).loadString(kExportFontLicenceAsset);
    yield LicenseEntryWithLineBreaks(const <String>['Roboto'], text);
  });
}

/// The font's bytes, read on first use and then held for the app's
/// lifetime (spec 13 D7: "once per app"). A failed read is not held: the
/// next [bytes] reads again.
class ExportFontCache {
  /// [load] is the test seam; the default is [loadExportFont].
  ExportFontCache({Future<Uint8List> Function()? load})
      : _load = load ?? loadExportFont;

  final Future<Uint8List> Function() _load;
  Future<Uint8List>? _bytes;

  /// The font's bytes; every call after the first returns the same future.
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
