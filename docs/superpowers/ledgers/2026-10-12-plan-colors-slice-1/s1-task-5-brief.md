# Brief: plan colours Slice 1, Task 5

Plan: docs/superpowers/plans/2026-10-12-plan-colors-slice-1.md
Spec: docs/superpowers/specs/2026-10-12-plan-colors-design.md

## Global Constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`), every painter's
  counter test **and every image golden stay untouched**.
- **The engine (`jet_cad_2d`) is edited in Task 1** (the style command
  and the stamp) **and Task 2** (`kSchemaVersion` and the pins it
  forces). `jet_cad_2d_flutter` is not edited in this slice.
- **No existing signature, `==`, `hashCode` or `toString` changes**,
  except `RoomParams`' (Task 3) and `FloorPlanEditorCapabilities`'
  (Task 4), which gain one field each. Every new parameter is named and
  optional with today's behaviour as its default. **Existing tests pass
  unedited**, with exactly these named exceptions:
  - **Task 1:** `packages/jet_cad_2d/test/parametric/attributes_test.dart`
    AT1 (its name, its header comment and the asserts after
    `Swatch(-210.75, 95.5, 100, 50)`): transparency is now the planner's
    column, so the matched records take the new alpha (100); lineweight,
    flags, linetype and text attributes still do not move.
  - **Task 2, what schema 10 forces**, re-pinned with the wording kept
    but for the number: `jet_cad_2d/test/codec/json_codec_test.dart:518,
    :590-591`; `instance_style_codec_test.dart:83`;
    `page_component_roundtrip_test.dart:83-88` (Q0-C1);
    `test/document/layer_header_test.dart:98-107`;
    `test/codec/schema_9_test.dart` S9-1 (writes 10) and S9-3 (refuses
    11, naming 11 and 10), its header comment, and its fixture moved to
    `test/codec/support/schema_fixture.dart` (a pure move);
    `test/testing/generate_document_test.dart` **comments only** (the
    fingerprints' expected values are not touched);
    `jet_cad_floor_plan/test/host/controller_test.dart`'s `schema 9
    (E-9)` group (`:959-1020`: writes 10, refuses 11);
    `test/host/table_data_test.dart:118`;
    `apps/restaurant_demo/test/events_test.dart` DE3 (`:198-205`); the
    four committed v9 encodings, re-encoded by their own generators.
  - **Task 3:** `jet_cad_floor_plan/test/room_object_test.dart` RP1
    (`:99-120`): four keys, `color` last, `"color":null` in both pinned
    encodings, and a fifth `==` case.
  - **Task 4:** `test/host/editor_capabilities_test.dart`'s
    `Caps.readOnly.toString()` pin (`:273-277`) gains `recolor: false`;
    `test/l10n/recording_strings.dart` gains the new members;
    `test/host/barrel_test.dart` B1 gains `FloorPlanColor`;
    `test/invariants/theme_colours_test.dart`'s allow-list gains one
    entry.

  Any other test that has to change is a finding for the task's report.
- **The standing sets stay exactly as they are**
  (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared the
  way CI does, from the repo root:
  `dart run tool/ci/expect_failures.dart --package packages/<pkg> --root packages/<pkg> <run.json>`,
  the run made with `--file-reporter json:<run.json>`. On macOS the
  render package's `text_lod_ladder` rungs 1–2 pass: the recorded
  standing difference, not a finding. The engine's `dart test` exits 1
  for its two standing fingerprints; `expect_failures` exits 0.
- **Every task ends green** in every package it touches and every
  package whose tests read what it changed: `jet_cad_2d` (`dart test`
  through the comparison, `dart analyze --fatal-infos`, `dart format
  --output=none --set-exit-if-changed .`); `jet_cad_floor_plan`,
  `apps/restaurant_demo`, `apps/floor_planner`,
  `jet_cad_restaurant_symbols` (`flutter test`, `flutter analyze`,
  format); `jet_cad_2d_flutter` and `jet_cad_2d_gpu` through the
  comparison after Tasks 1 and 2. The planner's suite runs with
  `--enable-vmservice` (its allocation tests need it).
- **Fixtures** (CLAUDE.md's testing bar; the spec's): rooms sit in the
  room fixture's `corpusGroups` placement (far from the origin, turned
  23°) and in a group of their own turned 0.61 rad; a test of the
  engine stamp uses a client whose region **and** plain child carry the
  colour and the transparency, in a turned group off the origin. A hue
  under test is never the first of the palette alone: tests use `teal`
  and `purple`, and one an unknown name (`"magenta"`).
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report. Every mutant belongs to exactly one task.
- **Never `git checkout` a file to revert it**; copy it aside or
  `git show HEAD:path > path`. **Never commit an
  `analysis_options.yaml`**: check `git status` before each commit.
- **Never synthesize test output.** A report quotes what a command
  printed.
- Code, comments and commit messages in English; commit messages end
  with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- New public names enter `lib/jet_cad_floor_plan.dart` and
  `test/host/barrel_test.dart` in the task that adds them. No component
  type crosses the host barrel (`RoomParams` stays internal).


## Review Focus

The inputs the spec implies that a person meets and no task's own
assertions would otherwise reach, each pinned by a test in the task
named:

1. **A plan saved by 0.5.1 with rooms**, opened, then any edit that
   regenerates its rooms: the tints stay ACI 7 at 229, byte for byte,
   and `drift()` stays empty (PC-3a must plan nothing for them). Task 3,
   RC6.
2. **A colour chosen twice** (the same swatch tapped again, or a
   selection already all teal): no undo step, `canUndo` unchanged.
   Task 4, CP3.
3. **Undo straight after a recolour** in the shell, by Ctrl+Z: the tint
   returns to grey on screen in the same frame (the document change
   reaches the canvas). Task 4, CP2's undo leg.
4. **A room selected with a wall and a separator**: the picker shows,
   colours the room, and the wall and separator are untouched (their
   bytes). Task 4, CP2.
5. **A file whose room carries a colour this build does not know**
   (`"magenta"`, a later release's hue): it opens, draws today's grey
   tint, the picker marks no swatch, and it saves back `"magenta"`.
   Task 3, RC4; Task 4, CP1.

---


---

### Task 5: The CHANGELOG, the guide, STATUS and the exit (PC-12, Slice 1)

**Files:**
- Modify: `CHANGELOG.md` (`## Unreleased`, `:9-11`)
- Modify: `docs/host-guide.md` (the capabilities table and field list `:1442-1500`; §11 `:1979-2030`)
- Modify: `STATUS.md` (In flight)
- Modify: `.github/workflows/ci.yml` (`:168-170`: add `v0.5.1`)

- [ ] **Step 1: The CHANGELOG.** `## Unreleased` becomes:

```markdown
## Unreleased

Plan colours, Slice 1 (of two; released together as 0.6.0).

- **Plans are now saved at schema 10.** A 0.5.1 (or older) build refuses
  a plan this release saves (`load` throws a `FormatException` naming
  `unsupported schemaVersion 10`); this release opens a 0.5.1 plan
  unchanged. Terminals that share plans must move together.
- **A room can take a colour**, one of eight hues
  (`FloorPlanColor`: red, orange, yellow, green, teal, blue, purple,
  grey), chosen in the Selection panel's new **Colour** row; its tint
  is drawn in that hue at 20 %, on screen, in the export and in the
  print. An uncoloured room is drawn exactly as before.
- **`FloorPlanEditorCapabilities.recolor`** (default true; false in
  `readOnly`) allows the Colour row; refused, it shows read only.
  `tablesOnly` keeps it on.
```

- [ ] **Step 2: The guide.** In the capabilities table add a row
  `| \`recolor\` | yes | yes | no |` after the `mirror, reshape,
  changeLayer` row; in "Field by field", after the
  `move, rotate, ...` bullet:

```markdown
- `recolor` (*since 0.6.0*): the Selection panel's Colour row, which
  gives the selected rooms one of the eight `FloorPlanColor` hues or
  none. Refused, the row shows the colour, read only.
```

  In §11, the schema bullet that says "is at schema 9" gains the 0.6.0
  sentence, in the section's style: "A plan saved by 0.6.0 is at
  **schema 10**, which 0.5.1 and every older release refuse; a schema 9,
  8 or 7 plan opens here unchanged." Run `dart run tool/ci/check_guide.dart`
  (repo root): it passes (no code block was added).

- [ ] **Step 3: CI's old host.** In `.github/workflows/ci.yml`, after
  the `v0.4.0` step (`:169-170`), the same step for `v0.5.1`. Locally,
  from the repo root:

```bash
tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"
tool/ci/old_host_probe.sh v0.3.0
tool/ci/old_host_probe.sh v0.4.0
tool/ci/old_host_probe.sh v0.5.1
```

  Expected: each ends with its "analyses against" line, exit 0. (The tag
  `v0.5.1` exists locally: `git tag -l v0.5.1`.)

- [ ] **Step 4: STATUS.** "In flight" says Slice 1 is done on
  `spec/plan-colors` and Slice 2 (tables) is next; "Owed to the human"
  gains: a native German and Turkish read of the Colour row's words
  (PC-10's table); a look at a coloured room on the light and dark
  canvas.

- [ ] **Step 5: The exit gate, whole.** Every package and app through
  its gate (the comparison for the engine, render and GPU; `flutter
  test`, analyze and format for the rest, the planner with
  `--enable-vmservice`), `tool/ci` (`dart test`, analyze, format,
  `check_guide`), the host probe and the three old-host probes. Paste
  each command's last lines into the report.

- [ ] **Step 6: Commit.**

```bash
git add CHANGELOG.md docs/host-guide.md STATUS.md .github/workflows/ci.yml
git commit -m "docs: plan colours Slice 1 in the CHANGELOG, the guide and STATUS

Schema 10, a room's colour and the recolor capability; CI's old-host
probe also builds 0.5.1's host.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
