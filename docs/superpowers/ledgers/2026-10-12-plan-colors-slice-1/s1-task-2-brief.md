# Brief: plan colours Slice 1, Task 2

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

### Task 2: Schema 10 (PC-2)

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/codec/schema_version.dart:1-48`
- Create: `packages/jet_cad_2d/test/codec/support/schema_fixture.dart` (moved from `schema_9_test.dart`)
- Modify: `packages/jet_cad_2d/test/codec/schema_9_test.dart`
- Create: `packages/jet_cad_2d/test/codec/schema_10_test.dart`
- Modify (re-pins, the named exceptions): the engine tests and planner/demo tests listed under Global Constraints
- Regenerate: `packages/jet_cad_floor_plan/assets/library/furniture.jetlib`, `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib`, `apps/restaurant_demo/assets/plans/salon.json`, `teras.json`

**Interfaces:**
- Produces: `kSchemaVersion == 10`; a 9 (or older) document reads
  unchanged; an 11 is refused with `SchemaVersionError(11)` whose
  message names 11 and 10.

**Verified** (at `b77f491`): the codec writes `kSchemaVersion` first
(`json_codec.dart:38`) and refuses a version not an int, below 1 or
above it (`:106-107`); **there is no migration function**: an older
document is read by the same code, each field defaulting when absent,
so the empty 9 → 10 migration is the constant alone (as 9's was). The
committed v9 encodings are the four files above (`git grep -lE
'"schemaVersion": ?9' -- ':!docs'`). `apps/floor_planner/test/document_open_test.dart`
and `controller_test.dart:224` follow the constant. The engine's two
standing fingerprints hash the whole encoding, which starts with the
version: their true values move again, they keep failing on Linux, and
the standing set is unchanged (the macOS re-baseline stays owed).

- [ ] **Step 1: Move the fixture.** Cut `fixture`, `withVersion`,
  `tableDataType`, `unknownKey` and their imports out of
  `test/codec/schema_9_test.dart` into
  `test/codec/support/schema_fixture.dart` unchanged (public names, no
  leading underscore change needed if they are already public); import it
  from `schema_9_test.dart`. Run `dart test test/codec/schema_9_test.dart`:
  PASS (a pure move).

- [ ] **Step 2: Write the failing tests** in `test/codec/schema_10_test.dart`:

```dart
// Schema 10 (plan colours spec PC-2): this build writes 10 and reads a 9
// document unchanged (the 9 -> 10 migration is empty). The 9 document is
// derived from this build's own encoding of the schema fixture (the version
// set, then through bytes), never hand-written.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/schema_fixture.dart';

void main() {
  test('S10-1 this build writes schema 10, first', () {
    expect(kSchemaVersion, 10);
    final json = jsonDecode(DraftDocumentCodec.encodeToString(
        fixture(MetricModelMeasurer()))) as Map<String, Object?>;
    expect(json['schemaVersion'], 10);
    expect(json.keys.first, 'schemaVersion');
  });

  test(
      'S10-2 a 9 document reads unchanged and saves as this build\'s 10 '
      'file, byte for byte', () {
    final ten =
        DraftDocumentCodec.encodeToString(fixture(MetricModelMeasurer()));
    final nine = withVersion(ten, 9);
    final loaded = DraftDocumentCodec.decodeString(nine,
        measurer: MetricModelMeasurer(),
        registerComponents: PageComponent.register);
    expect(DraftDocumentCodec.encodeToString(loaded), ten);
  });
}
```

  Use the exact `decodeString` arguments `schema_9_test.dart`'s S9-2
  uses (read it); they are the ones the fixture needs.

- [ ] **Step 3: Run and see them fail.** `dart test test/codec/schema_10_test.dart`
  Expected: S10-1 FAIL (`Expected: <10> Actual: <9>`). S10-2 passes
  before the bump (this build still writes 9, so `nine` equals `ten`):
  it is the migration's guard, red only under M-C10b (Step 8).

- [ ] **Step 4: Bump.** `schema_version.dart`: `const int kSchemaVersion = 10;`
  and a history entry after 9's, in its style:

```dart
/// 10: no new field the engine reads, and nothing to default; the v9->v10
/// migration is empty, so a v9 (or older) document is read unchanged. The
/// bump exists for the reader, as 6's to 8's did: the floor planner's room
/// gains a `color` key (plan colours spec PC-3) and its tables a
/// `jetcad.table_color` component (PC-4). A v9 build would read a room's
/// colour as nothing and drop it on its next save, and keep a table's
/// colour as preserve-unknown data that a delete orphans. With the bump,
/// that build refuses the file and says why.
```

- [ ] **Step 5: Re-pin the forced tests** (the named exceptions, wording
  kept but for the number): `json_codec_test.dart:518, :590-591` → 10;
  `instance_style_codec_test.dart:83` → 10;
  `page_component_roundtrip_test.dart:83-88` ("Q0-C1 this build writes
  schema 10") → 10; `layer_header_test.dart:98-107` ("writes schema 10,
  reads 7, and refuses the next one"; its comment "Plan colours Slice 1
  Task 2: writes 10 (PC-2)") → 10 and its refused next → 11;
  `schema_9_test.dart`: header comment ("Schema 9 ... this build reads an
  8 document unchanged; since schema 10 (PC-2) it writes 10"), S9-1 →
  "this build writes schema 10 ..." pins 10, S9-3 → an **11** document
  refused, the error naming 11 and 10; S9-2's "saved again, it is the 9
  file" → "the 10 file this build writes" if it compares with this
  build's encoding (read it: its expected bytes are this build's own
  encoding, so only the comment moves). `generate_document_test.dart`:
  comments only at `:66-68` and `:255-257` ("kSchemaVersion 8 to 9 to
  10; owed on macOS"). Planner: `controller_test.dart`'s `schema 9
  (E-9)` group → its writes-pin 10, its refusal test an 11 plan whose
  message contains `unsupported schemaVersion 11` and `this build writes
  10` (the group's name gains ", 10 since plan colours"); 
  `table_data_test.dart:118` → 10. Demo: `events_test.dart` DE3 → "declares
  schema 10", `['schemaVersion'], 10`.

- [ ] **Step 6: Re-encode the four committed encodings** with their own
  generators, then show each diff is the version only:

```bash
(cd packages/jet_cad_floor_plan && dart run tool/generate_furniture_library.dart)
(cd packages/jet_cad_restaurant_symbols && dart run tool/generate_restaurant_library.dart)
(cd apps/restaurant_demo && UPDATE_SAMPLES=1 flutter test test/sample_plans_test.dart)
for f in packages/jet_cad_floor_plan/assets/library/furniture.jetlib packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib apps/restaurant_demo/assets/plans/salon.json apps/restaurant_demo/assets/plans/teras.json; do git diff --stat -- "$f"; git show HEAD:"$f" | sed -E 's/"schemaVersion": ?9/"schemaVersion":10/' | cmp - "$f" || echo "DIFFERS BEYOND THE VERSION: $f"; done
```

  If a generator writes `"schemaVersion": 10` with a space, adjust the
  `sed` replacement to the file's own spelling (look at `git diff`); the
  check is that nothing but the version line moved. The two
  `furniture_pre_09c.jetlib` fixtures declare 7 and stay v7 reads.

- [ ] **Step 7: Run everything** the bump reads: the engine through the
  comparison (exit 0, the standing pair exactly), analyze, format;
  `jet_cad_2d_flutter` and `jet_cad_2d_gpu` through the comparison;
  `jet_cad_floor_plan` (`--enable-vmservice`), `jet_cad_restaurant_symbols`,
  `apps/restaurant_demo`, `apps/floor_planner`: green, analyze, format.

- [ ] **Step 8: The mutants:**
  - **M-C10** — the codec still writes 9 (`kSchemaVersion` left at 9
    with the tests re-pinned). Killers: S10-1, the re-pinned engine
    tests, the four encodings' byte pins, DE3.
  - **M-C10b** — a 9 document refused (the guard tightened to `version
    != kSchemaVersion`). Killers: S10-2; the literal-7 reads
    (`layer_header_test`, Q0-C3) go red too.

- [ ] **Step 9: Commit.**

```bash
git add packages apps
git status --short | grep analysis_options && echo "STOP: analysis_options staged"
git commit -m "feat(2d): schema 10 for plan colours

Plan colours spec PC-2: kSchemaVersion 10, an empty migration from 9.
The bump exists for the reader: a 9 build would drop a room's colour on
save and orphan a table's on delete. The forced pins move to 10; the four
committed encodings are re-encoded by their generators, the version line
only.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
