# Task 7 review — App: the font (spec D7, T-12)

Reviewer: independent, on commit `f625d80` (range `d538aa2..f625d80`), in the
detached worktree `.claude/worktrees/plan-13-review`. Every line below was run
by the reviewer; nothing is copied from the report.

## 1. Licence compliance

```
cmp1=0
cmp2=0
79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95  apps/floor_planner/assets/fonts/Roboto-Regular.ttf
79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95  packages/jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf
cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30  apps/floor_planner/assets/fonts/Roboto_LICENSE.txt
cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30  packages/jet_cad_2d_flutter/test/golden/fonts/Roboto_LICENSE.txt
171676 apps/floor_planner/assets/fonts/Roboto-Regular.ttf
 11358 apps/floor_planner/assets/fonts/Roboto_LICENSE.txt
```

- Both files byte-identical to the vendored ones; the digest is the recorded
  one (decision 3, F-11). The licence starts `Apache License / Version 2.0,
  January 2004`.
- `assets/fonts/README.md` states the source (the vendored file, from Flutter
  3.27.3's `material_fonts`), the SHA-256, Apache 2.0 with the licence beside
  it, LicenseRegistry registration, and "Copied unmodified, 2026-10-01, plan
  13 Task 7". Complete.
- Apache 2.0 s.4(a) (give recipients a copy of the licence): the licence is
  under `flutter: assets:`, so it ships in every build. Web verified (below):
  `build/web/assets/assets/fonts/Roboto_LICENSE.txt`, 11358 B, sha256
  `cfc7749b…3d30` = the source. macOS not built here (Linux host); the same
  `assets:` list lands in `flutter_assets` on every platform, so nothing
  platform-specific is missing. The font is unmodified, so s.4(b) does not
  apply; Roboto carries no NOTICE file, so s.4(d) does not apply.
- `LicenseRegistry`: registered under package `Roboto` with the asset text
  (EF6 asserts it). The build's `NOTICES` holds no Roboto (`grep -c Roboto
  NOTICES` = 0) — expected, the entry is added at run time. Note: the app has
  no `showLicensePage` / `AboutDialog` today (`grep` over `lib/` empty), so
  the registered entry has no viewer yet; the shipped text file alone meets
  s.4(a). Not a defect.

## 2. pubspec

Diff is five added lines: `assets/fonts/Roboto_LICENSE.txt` under `assets:`
(furniture.jetlib kept) and `fonts: - family: Roboto / fonts: - asset:
assets/fonts/Roboto-Regular.ttf`. No `sdk:` / `flutter:` bound line in the
diff (`sdk: ^3.5.0`, `flutter: ">=3.38.0"` unchanged); no dependency change;
no lock file in the diff.

## 3. `export_font.dart`, `main()`, wiring

- `loadExportFont([AssetBundle?])`: `rootBundle` default, view honours
  `offsetInBytes`/`lengthInBytes`. Correct.
- `registerFontLicences([AssetBundle?])`: lazy `async*` collector reading
  the licence through the bundle when the licences are collected; correct.
  Idempotence: a second call in the same isolate would add a second `Roboto`
  entry; hot restart re-initialises statics (LicenseRegistry's collector list
  included) before re-running `main()`, and hot reload does not re-run
  `main()`, so no duplicate in practice. Acceptable.
- `ExportFontCache`: memoises the future; on error `_bytes` is cleared only
  if it is still the same future (`identical`), so a later successful read is
  never clobbered. The `then(..., onError:)` listener also means the stored
  future's error is never reported as unhandled when only the cache holds it;
  the caller's own `await` still sees the error (EF8). A synchronous throw in
  `_load` escapes before `_bytes` is set, so it is not held either. Sound.
- `main()` calls `registerFontLicences()` then `runApp(...)`; otherwise
  unchanged. `_FloorPlannerAppState` holds `late final _exportFont =
  widget.exportFont ?? ExportFontCache()` above the host and passes it to
  `DocumentHost(exportFont:)` (nullable, read by nothing yet — R-13-20).
  EF9 shows the same instance survives a document swap.
- `symbol_library_loader.dart`: header comment only (2 lines). No behaviour
  change elsewhere.

## 4. Effect on existing tests (R-7, revision 2 W-19)

Probe (a throwaway test file, run and deleted; `git status` afterwards shows
only the pub-get `analysis_options.yaml`), at `f625d80` with Roboto declared:

```
PROBE Roboto width=300.0 height=20.0
PROBE null width=300.0 height=20.0
PROBE Ahem width=299.99981689453125 height=20.0
PROBE material size=Size(800.0, 600.0) family=Roboto
```

15 glyphs x 20 px = 300: `fontFamily: 'Roboto'` still measures as Ahem squares
under `flutter test`, so the declared family does not reach widget tests'
metrics. Confirms the spec reviewer's experiment.

App suite: `03:52 +895: All tests passed!` (885 + 10).

## 5. Mutants (re-fired by the reviewer; cp backup → mutate → run
`test/export/export_font_test.dart` in the foreground → cp back → `diff`
exit 0 after each)

| id | file:line | mutation | result (real line) |
|---|---|---|---|
| A | export_font.dart:24 | `if (false) LicenseRegistry.addLicense(` | red: `00:00 +5 -1: the licence EF6 registerFontLicences lists the Apache text under Roboto [E]` |
| B | export_font.dart:16 | `load(kExportFontLicenceAsset)` | red: EF4, EF5, EF10 (`00:02 +7 -3: Some tests failed.`) |
| D | export_font.dart:47 | `// _bytes = next;` | red: `00:00 +6 -1: ExportFontCache EF7 reads once and returns the same future after [E]` |
| E | export_font.dart:49 | `if (false) _bytes = null;` | red: `00:00 +7 -1: ExportFontCache EF8 a failed read is not held: the next call reads again [E]` |
| J | pubspec.yaml:43 | font asset → `assets/library/furniture.jetlib` | red: EF4, EF10 (`00:02 +8 -2: Some tests failed.`) |
| H | main.dart:42 | `// registerFontLicences();` | **survives**: `00:01 +10: All tests passed!` |

All restores `restore=0`; the worktree ends clean.

H: the report is right that no test runs `main()`. It is the one line that
makes the licence actually appear in the running app, and it is cheap to pin
with the repo's own precedent (`packages/jet_cad_2d_flutter/test/export/
export_sources_test.dart`, T-11, reads source text): see finding 1.

## 6. Gates

- `CI=true flutter test` (app): `03:52 +895: All tests passed!`
- `CI=true flutter analyze`: `No issues found! (ran in 3.9s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 155 files
  (0 changed)`, exit 0
- `CI=true flutter build web --release` (after `rm -rf build/web`):
  `✓ Built build/web`. `FontManifest.json`:
  `[{"family":"MaterialIcons",...},{"family":"Roboto","fonts":[{"asset":"assets/fonts/Roboto-Regular.ttf"}]}]`;
  `assets/assets/fonts/Roboto-Regular.ttf` 171676 B, sha256 `79e85140…16d95`;
  `assets/assets/fonts/Roboto_LICENSE.txt` 11358 B. The "Expected to find
  fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons)" line
  is not from this commit (nothing in the diff or in `apps/floor_planner/lib`
  / `packages/*/lib` names Cupertino icons).
- Engine and render unchanged: `git diff --stat d538aa2 f625d80 --
  packages/` is empty (0 lines).

## Verdict: Approved with notes

## Findings

1. **Low — `apps/floor_planner/lib/main.dart:42`, mutant H survives.** The
   `registerFontLicences()` call in `main()` is pinned by review only.
   Fix (cheap, kills H): in `test/export/export_font_test.dart`, a test that
   reads `File('lib/main.dart').readAsStringSync()`, takes the body of
   `void main() {` up to its closing brace, and asserts it contains
   `registerFontLicences();` at an index before `runApp(` — the T-11 source
   test is the precedent. Acceptable to defer, since R-13-20 records it; but
   it is the only line that delivers the licence obligation at run time.
2. **Info — spec F-11 (line ~146) / R-7 (line ~685) are inexact for the web.**
   They say `fontFamily: 'Roboto'` fell back to a platform font on web. The
   CanvasKit and skwasm engines download Roboto Regular from
   `fonts.gstatic.com` whenever the FontManifest has no `Roboto` family
   (`flutter_web_sdk/lib/_engine/engine/canvaskit/fonts.dart:118-133`,
   `skwasm_impl/font_collection.dart:80-82`). So on web the text was already
   Roboto (a newer Roboto v32 woff2); the change there is the version (2.137
   now) and that start-up no longer fetches a font from Google — an offline
   gain. On macOS native the Material chrome's typography is the system font,
   so only drawing text changes, as L-1 says. No code change; worth a line
   when the spec's facts are next revised, and L-1 on web should expect
   near-identical text rather than a font switch.
3. **Info — `apps/floor_planner/lib/export/export_font.dart:23`.**
   `registerFontLicences()` is not idempotent within one isolate (a second
   call lists Roboto twice). Only `main()` calls it and hot restart resets
   the registry, so no change needed; mention in its doc comment if a second
   caller ever appears.
4. **Info — no licence viewer in the app.** The registry entry has no
   `LicensePage` to show it yet; the shipped `Roboto_LICENSE.txt` asset
   satisfies Apache 2.0 s.4(a) on its own. If an About / Licences entry is
   added later, Roboto appears there automatically.
