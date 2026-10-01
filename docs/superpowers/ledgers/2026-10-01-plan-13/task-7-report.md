# Task 7 report — App: the font (spec D7, T-12)

Commit: `f625d80` feat(app): bundle Roboto for the screen and the PDF (on d538aa2). Not pushed.

## Files
- `apps/floor_planner/assets/fonts/Roboto-Regular.ttf`, `Roboto_LICENSE.txt` (cp from `packages/jet_cad_2d_flutter/test/golden/fonts/`), `README.md` (source, SHA-256, Apache 2.0, "Copied unmodified, 2026-10-01, plan 13 Task 7").
- `apps/floor_planner/pubspec.yaml`: `assets:` + `assets/fonts/Roboto_LICENSE.txt` (furniture.jetlib kept); `fonts:` family Roboto -> `assets/fonts/Roboto-Regular.ttf`. No `sdk:`/`flutter:` bound touched.
- `apps/floor_planner/lib/export/export_font.dart` (new): `kExportFontAsset`, `kExportFontLicenceAsset`, `Future<Uint8List> loadExportFont([AssetBundle? bundle])`, `void registerFontLicences([AssetBundle? bundle])`, `class ExportFontCache` (lazy, memoised `Future<Uint8List> get bytes`; a failed read is not held; `load:` test seam).
- `apps/floor_planner/lib/main.dart`: `main()` = `registerFontLicences(); runApp(const FloorPlannerApp());` (otherwise unchanged). `FloorPlannerApp` gains an optional `exportFont` test seam; its state holds `late final ExportFontCache _exportFont = widget.exportFont ?? ExportFontCache();` and passes it to `DocumentHost(exportFont: ...)`.
- `apps/floor_planner/lib/document_host.dart`: optional `final ExportFontCache? exportFont;` field + import. Nothing reads it yet.
- `apps/floor_planner/lib/symbols/symbol_library_loader.dart`: header comment only ("the only file that touches rootBundle" was going stale; now names export_font.dart too).
- `apps/floor_planner/test/export/export_font_test.dart` (new, 10 tests EF1-EF10).

**How Task 9 reaches the bytes:** in `DocumentHostState`, `await widget.exportFont!.bytes` (or pass `widget.exportFont` on to the flow). It is non-null whenever the host is built by `FloorPlannerApp`; tests that build a bare `DocumentHost` get null, so Task 9 should either fall back (`widget.exportFont ?? ExportFontCache()` held in host state) or make the field required — Task 9's call. The cache reads nothing until `bytes` is first awaited, so app start-up cost is unchanged.

## Copy check (real output)
```
cmp1=0
cmp2=0
79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95  apps/floor_planner/assets/fonts/Roboto-Regular.ttf
171676 apps/floor_planner/assets/fonts/Roboto-Regular.ttf
 11358 apps/floor_planner/assets/fonts/Roboto_LICENSE.txt
```
`package:crypto` is not a direct dependency of the app (`grep crypto pubspec.yaml` exit 1), so the test compares bytes with the vendored file and asserts the README carries the digest; the digest itself is the `sha256sum` line above.

## Gates (real tails)
App `CI=true flutter test`:
```
03:05 +895: All tests passed!
```
(885 before + 10 new.) `CI=true flutter analyze` (after removing two unnecessary imports in the new test, then re-run): `No issues found! (ran in 1.5s)`. `dart format --output=none --set-exit-if-changed .`: `Formatted 155 files (0 changed)`, exit 0.
`CI=true flutter build web --release`:
```
Compiling lib/main.dart for the Web...                             50.0s
✓ Built build/web
```
build/web carries `assets/assets/fonts/Roboto-Regular.ttf` (171676 B) and `Roboto_LICENSE.txt`; FontManifest.json has `"family":"Roboto","fonts":[{"asset":"assets/fonts/Roboto-Regular.ttf"}`. The build also prints "Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons)" — an icon tree-shake note about CupertinoIcons, unrelated to this task (not checked whether it predates it; nothing here references Cupertino icons).

Engine and render unchanged: `git diff --stat d538aa2 HEAD -- packages/` is empty. The allocation invariant tests are untouched. `packages/jet_cad/analysis_options.yaml` (pub get rewrite) not staged.

## Mutants (all fired against `test/export/export_font_test.dart`, foreground, cp backup/restore, `diff` exit 0 after each)
| id | file:line | mutation | red | real line |
|---|---|---|---|---|
| A | export_font.dart:24 | registration removed (`if (false) LicenseRegistry.addLicense(...)`) | EF6 | `00:00 +5 -1: the licence EF6 registerFontLicences lists the Apache text under Roboto [E]` |
| B | export_font.dart:16 | wrong asset path (`kExportFontLicenceAsset`) | EF4, EF5, EF10 | `00:00 +3 -1: loadExportFont EF4 reads the bundled font through rootBundle [E]` |
| C | export_font.dart:16 | given bundle ignored (`rootBundle` always) | EF5 | `00:00 +4 -1: loadExportFont EF5 reads from the bundle it is given [E]` |
| D | export_font.dart:47 | cache never stores (`_bytes = next` removed) | EF7 | `00:00 +6 -1: ExportFontCache EF7 reads once and returns the same future after [E]` |
| E | export_font.dart:49 | failed read held | EF8 | `00:00 +7 -1: ExportFontCache EF8 a failed read is not held: the next call reads again [E]` |
| G | export_font.dart:27 | package name `Roboto Regular` | EF6 | `00:00 +5 -1: the licence EF6 registerFontLicences lists the Apache text under Roboto [E]` |
| F | main.dart:112 | app ignores the given cache | EF9 | `00:01 +8 -1: ExportFontCache EF9 the app hands its cache to the host, and keeps it across a document swap [E]` |
| I | pubspec.yaml:39 | licence asset line removed | EF6 | `00:00 +5 -1: the licence EF6 registerFontLicences lists the Apache text under Roboto [E]` |
| J | pubspec.yaml:43 | font family points at furniture.jetlib | EF4, EF10 | `00:00 +3 -1: loadExportFont EF4 reads the bundled font through rootBundle [E]` |
| H | main.dart:42 | `registerFontLicences();` call removed from `main()` | **survives** | `00:01 +10: All tests passed!` |

H is the expected survivor: `main()` calls `runApp` and is not run by any test; the brief's route (factor into `registerFontLicences()`, test that) leaves the one-line call in `main()` covered by review only. Killing it would need `main()` to be testable (e.g. a `bootstrap()` that takes the runApp) — not done, to keep `main()` otherwise unchanged as the brief asks.

## Spec / plan notes
- Plan/spec say "cached per app by FloorPlannerApp" but no consumer exists until Task 9; a private field read by nothing trips `unused_field`, so the cache is plumbed one step further to `DocumentHost.exportFont` (optional). Small, and it is where Task 9's flow lives.
- `ExportFontCache` does not hold a failed read (so a transient asset failure does not poison every later export). Not in the spec; a decision.
- The T-12 test also tests the licence text arrives (EF6 asserts "Apache License" / "Version 2.0" in the registered entry), beyond "registered".
- `LicenseRegistry.reset()` (visibleForTesting) is used in setUp/tearDown of EF6 for a clean registry premise.
