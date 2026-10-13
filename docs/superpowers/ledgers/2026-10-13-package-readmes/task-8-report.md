# Task 8 report

Commit: 2927476e "docs: the packages' READMEs, screenshots and funding links".

## README structure
- Root: title + two sentences, "The jet-cad packages" is not a heading (table follows intro), D1 table + sentence, host-guide link, Support, License (OCCT paragraph now starts "The dormant `packages/jet_cad` line depends on ...").
- jet_cad_2d: unchanged sections, then "The jet-cad packages" (table, sentence, host guide link), Support, License. No image.
- jet_cad_2d_flutter: R1 under first paragraph; What it holds; Example; Screenshots (R2-R5 with captions); The API; The jet-cad packages (+host guide link); Support; License.
- jet_cad_floor_plan: P1 under first paragraph; Embedding it (P3 after first paragraph); The host guide; Screenshots (P2, P4, P5, P6 + restaurant-symbols sentence + Roboto-in-scene-theme sentence); A symbol library of your own; The API; The jet-cad packages; Support; License.
- R2 retained (`dart pub add ...` sentence kept). No code blocks changed.

## Fields
`funding:` (both URLs) after `issue_tracker:` in all three pubspecs; `screenshots:` (spec text verbatim) in renderer (R1-R5) and planner (P1,P3,P2,P4,P5,P6). `.github/FUNDING.yml` created.

## Checks
- check_screenshots: "screenshots: every rule holds"
- check_readmes: "package READMEs: all 6 code blocks are in the probes"; check_guide: "docs/host-guide.md: all 56 code blocks are in the host probe"
- tool/ci dart test: "All tests passed!" (+94); readme_probe flutter analyze: No issues found
- dart analyze / flutter analyze of the three packages: No issues found

## M-T8
Planner README copied aside, `service_band.png` URL tag changed to `jet_cad_floor_plan-main`: check_screenshots printed
"jet_cad_floor_plan: README: https://raw.githubusercontent.com/a-urel/jet-cad/jet_cad_floor_plan-main/packages/jet_cad_floor_plan/doc/screenshots/service_band.png is not on the tag jet_cad_floor_plan-v0.7.2" and "jet_cad_floor_plan: doc/screenshots/service_band.png: not in the README". Restored from copy, `cmp` silent ("restored"), check green again.

## Dry runs (after commit)
- jet_cad_2d: Total compressed archive size: 229 KB. Package has 0 warnings.
- jet_cad_2d_flutter: 814 KB, 0 warnings; all 5 PNGs listed (canvas_dark, canvas_light, selection_band, selection_grips, symbol_gallery); 0 matches for `test/`.
- jet_cad_floor_plan: 782 KB, 0 warnings; all 6 PNGs listed; 0 matches for `test/`.

## Files
README.md, packages/{jet_cad_2d,jet_cad_2d_flutter,jet_cad_floor_plan}/{README.md,pubspec.yaml}, .github/FUNDING.yml. analysis_options.yaml not staged.

## Self-review / concerns
- Captions written after viewing PNGs: R4 band is a crossing band over Living/Kitchen/Bath; R5 Bathroom open; P4 shows counter stools 8-11 bright, rest dimmed (caption says "one zone in focus"); P5 band crosses front row (tables 1-3).
- R3 caption says "one entity highlighted under the pointer" per spec text; the PNG's highlight is not obviously distinguishable (the long table outline in blue).
- Screenshots section notes the Roboto caption theme belongs to the scenes' app theme, per R-amendment.
- Images 404 on GitHub until tags are pushed (expected).
