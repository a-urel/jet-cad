### Task 8: The READMEs, funding and the screenshots field (D1–D3, D6)

**Files:**
- Modify: `packages/jet_cad_2d/README.md`, `packages/jet_cad_2d_flutter/README.md`, `packages/jet_cad_floor_plan/README.md`, `README.md`
- Create: `.github/FUNDING.yml`
- Modify: the three published pubspecs (`funding:`; `screenshots:` for the renderer and the planner)
- Modify: `tool/readme_probe/lib/*.dart` only if a README's code changes

- [ ] **Step 1: The packages table** (spec D1, verbatim table and sentence) replaces "Where it comes from" in each package README; each gains the host guide link (`https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md`). The engine's README gains no image.

- [ ] **Step 2: Support**, before "License" in the three package READMEs and the root:

```markdown
## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).
```

- [ ] **Step 3: The root README** per spec D2: the two sentences, the table, "Embedding the floor planner in an app: [docs/host-guide.md](docs/host-guide.md).", Support, then the existing licence text with the OCCT paragraph introduced by "The dormant `packages/jet_cad` line depends on Open CASCADE Technology (OCCT), …".

- [ ] **Step 4: Funding.** In each published pubspec, after `issue_tracker:`:

```yaml
funding:
  - https://github.com/sponsors/a-urel
  - https://buymeacoffee.com/yazemo
```

`.github/FUNDING.yml`:

```yaml
github: a-urel
buy_me_a_coffee: yazemo
```

- [ ] **Step 5: The screenshots field**, after `funding:`. Renderer:

```yaml
screenshots:
  - description: 'A drawing on its sheet, with rulers, drawn by DraftCanvas on a light canvas.'
    path: doc/screenshots/canvas_light.png
  - description: 'The same drawing on the dark canvas, its colours re-toned for a dark theme.'
    path: doc/screenshots/canvas_dark.png
  - description: 'A selection with its grips, and an entity under the mouse highlighted.'
    path: doc/screenshots/selection_grips.png
  - description: 'A crossing selection band, dragged right to left.'
    path: doc/screenshots/selection_band.png
  - description: 'SymbolGallery: a furniture library in collapsible categories of thumbnails.'
    path: doc/screenshots/symbol_gallery.png
```

Planner:

```yaml
screenshots:
  - description: 'FloorPlanView in design mode: tools, symbols, layers and the page, light theme.'
    path: doc/screenshots/design_light.png
  - description: 'Table statuses with captions and a group of tables in the service view.'
    path: doc/screenshots/service_status.png
  - description: 'The editor in a dark theme.'
    path: doc/screenshots/design_dark.png
  - description: 'The service view in a dark POS theme, one zone of tables in focus.'
    path: doc/screenshots/service_dark_focus.png
  - description: 'Rubber-band selection of tables (floorDrag: band).'
    path: doc/screenshots/service_band.png
  - description: 'Tables in plan colours.'
    path: doc/screenshots/service_colors.png
```

(The planner's restaurant tables come from the repository's restaurant symbols, which a host copies per the host guide; say so in the README's Screenshots section, not in the 160 characters.)

- [ ] **Step 6: The images in the READMEs.** Renderer: R1 under the first paragraph; a `## Screenshots` section before "The API" with R2–R5, each with a one-line caption. Planner: P1 under the first paragraph, P3 after "Embedding it"'s first paragraph; `## Screenshots` with P2, P4, P5, P6 and the restaurant symbols sentence. Every URL `https://raw.githubusercontent.com/a-urel/jet-cad/<package>-v0.7.2/packages/<package>/doc/screenshots/<file>`, alt text naming the scene.

- [ ] **Step 7: The checks.** `dart run tool/ci/check_screenshots.dart`: "screenshots: every rule holds". `dart run tool/ci/check_readmes.dart` and `cd tool/readme_probe && flutter analyze`: green. `cd tool/ci && dart test`: green. Mutation M-T8: copy the planner README aside, change one URL's tag to `main`, run `check_screenshots`: red naming it; restore, `cmp`.

- [ ] **Step 8: Commit** README, pubspecs and FUNDING.yml: `git commit -m "docs: the packages' READMEs, screenshots and funding links"`.

- [ ] **Step 9: Dry runs.** From each package directory `dart pub publish --dry-run`: "Package has 0 warnings."; record each "Total compressed archive size". For the renderer and the planner, grep the dry run's file listing for every PNG of `screenshots:` (all present) and for `test/` (absent).

---


## Controller amendments

- **Ruling R2 (Task 6):** the renderer README already says its example uses both packages (`dart pub add jet_cad_2d jet_cad_2d_flutter`); keep that sentence (you may write `flutter pub add` instead — it is a Flutter package; keep the probe in step if the code block changes).
- **Ruling R6 (Task 3b):** the renderer's rulers now follow the ambient font; no README claim is needed, but do not write "no code change" anywhere.
- **Task 5's check flags every `https` image not on the release tag**, so the two Flutter READMEs carry no badges or other external images.
- **Task 3's scenes name Roboto in the app theme** for the status captions and group chips; the README's Screenshots section and the pubspec descriptions must not imply a host gets Roboto captions without asking for them.
- The probe files (`tool/readme_probe/lib/*.dart`) must still hold every README `dart` block verbatim after your edits: run `dart run tool/ci/check_readmes.dart` and `cd tool/readme_probe && flutter analyze`.
