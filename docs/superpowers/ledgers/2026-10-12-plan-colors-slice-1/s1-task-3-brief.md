# Brief: plan colours Slice 1, Task 3

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

### Task 3: The palette and the room's colour (PC-1, PC-3)

**Files:**
- Create: `packages/jet_cad_floor_plan/lib/src/colors/plan_color.dart`
- Modify: `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart` (export `FloorPlanColor`)
- Modify: `packages/jet_cad_floor_plan/lib/src/parametric/room.dart` (`RoomParams` `:21-99`; constants after `:109`; `generate`'s return `:301-310`)
- Modify: `packages/jet_cad_floor_plan/test/room_object_test.dart` (RP1, the named exception)
- Modify: `packages/jet_cad_floor_plan/test/host/barrel_test.dart` (B1 gains `FloorPlanColor`)
- Create: `packages/jet_cad_floor_plan/test/room_color_test.dart`

**Interfaces:**
- Consumes: Task 1's stamp (a recoloured room's existing tint changes);
  Task 2's schema 10.
- Produces:

```dart
// lib/src/colors/plan_color.dart — no Flutter import.
enum FloorPlanColor {
  red(0xE53935), orange(0xFB8C00), yellow(0xFDD835), green(0x43A047),
  teal(0x00897B), blue(0x1E88E5), purple(0x8E24AA), grey(0x757575);
  const FloorPlanColor(this.rgb);
  final int rgb;
}

/// The palette entry named [name], or null for null and for a name this
/// release does not know (PC-1: kept, drawn as no colour).
FloorPlanColor? floorPlanColorNamed(String? name);
```

  `RoomParams(double seedX, double seedY, String name, {(double, double)? label, String? color})`;
  `RoomParams.color` (`String?`), `RoomParams.colorValue`
  (`FloorPlanColor?`), `copyWith({..., Object? color = _keep})`;
  `const int kRoomColorTransparency = 204;`.

- [ ] **Step 1: Write the palette** (`lib/src/colors/plan_color.dart`):

```dart
// The plan's colours (plan colours spec PC-1): eight fixed hues a room's
// tint and a table's fill take. The file stores a colour by its name, never
// its index, so reordering or extending the palette breaks no file; a name
// this release does not know is kept as read and drawn as no colour.
//
// No Flutter import: the room (pure Dart over `package:jet_cad_2d`) reads it.

/// A plan colour (plan colours spec PC-1): one of eight fixed hues.
///
/// [rgb] is the document's colour, `0xRRGGBB`: what white paper, the export
/// and the print show. A dark canvas shows it re-toned, as it shows every
/// colour (`darkCanvasTone`). A later release may add hues: a host's
/// exhaustive `switch` over this enum then needs a new case.
enum FloorPlanColor {
  red(0xE53935),
  orange(0xFB8C00),
  yellow(0xFDD835),
  green(0x43A047),
  teal(0x00897B),
  blue(0x1E88E5),
  purple(0x8E24AA),
  grey(0x757575);

  const FloorPlanColor(this.rgb);

  /// The hue, `0xRRGGBB`.
  final int rgb;
}

/// The palette entry named [name] (its `name`), or null for null and for a
/// name this release does not know.
FloorPlanColor? floorPlanColorNamed(String? name) {
  if (name == null) return null;
  for (final c in FloorPlanColor.values) {
    if (c.name == name) return c;
  }
  return null;
}
```

  Export it from `lib/jet_cad_floor_plan.dart`:
  `export 'src/colors/plan_color.dart' show FloorPlanColor;` (in the
  file's alphabetical place) and add `'FloorPlanColor'` to B1's set.

- [ ] **Step 2: Write the failing tests** in `test/room_color_test.dart`.
  Fixture: `buildPlan(twoRoomWalls, place: corpusGroups, measurer:
  FlutterTextMeasurer())`, `attachPage(plan.doc, PageComponent())`,
  room A in a group turned 0.61 rad (as `room_panel_test.dart`'s
  `roomsPlan` builds it, `:105-118` — copy that builder, do not import a
  test file), room B at the identity; `plan.system` kept installed.

```dart
/// [room]'s tint records: its fill and the boundary the fill names (D9
/// steps 1 and 2), or its closed POLYLINE (step 3).
List<EntityRecord> tintRecords(DraftDocument doc, Handle room) {
  final all = kids(doc, room);
  final fills = [for (final k in all) if (kindOf(doc, k) == EntityKind.fill) k];
  if (fills.isNotEmpty) {
    final boundary = Handle(payloadOf(doc, fills.single).scalars[0].toInt());
    return [recordOf(doc, fills.single), recordOf(doc, boundary)];
  }
  return [
    for (final k in all)
      if (kindOf(doc, k) == EntityKind.polyline) recordOf(doc, k),
  ];
}

DraftCommand recolor(DraftDocument doc, Handle room, String? color) =>
    SetComponentCommand<RoomParams>(room,
        doc.components.get<RoomParams>(room)!.copyWith(color: color));
```

  The tests (each a `test`, names as below):
  - **RC1** `RoomParams` JSON: `const RoomParams(1234.5, -987.25, 'Room 1', color: 'teal')`
    encodes to exactly
    `{"seed":[1234.5,-987.25],"name":"Room 1","label":null,"color":"teal"}`
    and back (`==`, `hashCode`); with no colour, `"color":null` last;
    a three-key map (a v9 room) reads `color == null`; `"color":"magenta"`
    reads `color == 'magenta'`, `colorValue == null`, and re-encodes
    `"magenta"`; `"color": 7` throws (`TypeError`, as a wrong type does
    for `name`); `copyWith(color: null)` clears, `copyWith()` keeps,
    `copyWith(name: 'X')` keeps the colour (**M-C22**).
  - **RC2** recolour an **existing** room A (created uncoloured) to
    `teal`: one undo step (`undoDepth + 1`); both tint records carry
    `TrueColor(0x00897B)` and transparency 204; the room's children are
    the same handles as before (D18); the two labels' records unchanged;
    undo: both tint records back to `IndexedColor(7)` and 229 and
    `canon(doc)` equals the bytes before; redo: teal again (**M-C3**).
  - **RC3** `purple` then None (`copyWith(color: null)`): the tint back
    to `IndexedColor(7)` / 229 exactly; room B untouched throughout (its
    records compared whole).
  - **RC4** an unknown name: set `RoomParams.color = 'magenta'` on room A
    (a `SetComponentCommand` with `copyWith(color: 'magenta')`): the tint
    is today's (ACI 7, 229); the encoding carries `"color":"magenta"`;
    `driftOf(doc)` empty (**M-C1** for rooms).
  - **RC5** `colorValue` of each palette name is that entry; the eight
    `rgb` values are the spec's literals, written out (`0xE53935`, ...,
    `0x757575`), in palette order.
  - **RC6** a 0.5.1 plan (**M-C16**, Review Focus 1): encode the fixture
    with both rooms uncoloured; derive the v9 file from it by bytes —
    `schemaVersion` set to 9 and each room component's `"color":null`
    removed (decode the JSON, edit the maps, re-encode); load it
    (`DraftDocumentCodec.decodeString` with the planner's registrations,
    as `room_object_test.dart` loads a plan — read it) and install the
    parametric system; rename room A (an edit that regenerates it) and
    move wall 0 by 0.5 mm (`moveWall`, an edit that regenerates both
    rooms): every tint record is still `IndexedColor(7)` / 229 (compared
    whole, before and after), and `driftOf(doc)` is empty.
  - **RC7** step 3: a room whose tint is the step-3 outline (use the
    pinched plan `room_diagnostics_test.dart` builds for its
    `room.tint` case: `grep -n "room.tint" test/room_diagnostics_test.dart`)
    recoloured `teal`: the outline POLYLINE carries `TrueColor(0x00897B)`
    and stays invisible; its transparency is unchanged (the step-3
    outline carries none).

- [ ] **Step 3: Run and see them fail.**
  `flutter test test/room_color_test.dart` (in `packages/jet_cad_floor_plan`)
  Expected: compile errors (`color` is not a parameter of `RoomParams`).

- [ ] **Step 4: Implement `RoomParams.color`** in `room.dart`:

```dart
  const RoomParams(this.seedX, this.seedY, this.name, {this.label, this.color});
  // ...
  /// The room's colour (plan colours spec PC-3): a palette name, or null
  /// for none. Kept as read, known or not; [colorValue] is the entry.
  final String? color;

  /// The palette entry [color] names, or null for none and for a name this
  /// release does not know (drawn as no colour, PC-1).
  FloorPlanColor? get colorValue => floorPlanColorNamed(color);

  /// The keys `seed`, `name`, `label`, `color`, in that order, **all four
  /// always written** (08 D6's one-shape rule): `label` and `color` are
  /// `null` when unset.
  @override
  Map<String, Object?> toJson() => {
        'seed': [seedX, seedY],
        'name': name,
        'label': switch (label) {
          (final dx, final dy) => [dx, dy],
          null => null,
        },
        'color': color,
      };

  /// Throws on a missing seed or name, or a value of the wrong type; a
  /// missing `color` (a schema 9 room) reads as null.
  static RoomParams fromJson(Map<String, Object?> json) {
    final s = json['seed']! as List;
    final l = json['label'] as List?;
    return RoomParams(
      (s[0] as num).toDouble(),
      (s[1] as num).toDouble(),
      json['name']! as String,
      label: l == null
          ? null
          : ((l[0] as num).toDouble(), (l[1] as num).toDouble()),
      color: json['color'] as String?,
    );
  }

  /// [label] takes a `(double, double)` or `null` (auto), [color] a name or
  /// `null` (none); left out, each is kept.
  RoomParams copyWith(
          {double? seedX,
          double? seedY,
          String? name,
          Object? label = _keep,
          Object? color = _keep}) =>
      RoomParams(seedX ?? this.seedX, seedY ?? this.seedY, name ?? this.name,
          label: identical(label, _keep)
              ? this.label
              : label as (double, double)?,
          color: identical(color, _keep) ? this.color : color as String?);
```

  `==` gains `other.color == color`, `hashCode`
  `Object.hash(seedX, seedY, name, label, color)`, `toString`
  `'RoomParams(($seedX, $seedY), $name, $label, $color)'`. Import
  `'../colors/plan_color.dart'`.

- [ ] **Step 5: The coloured tint.** After `kRoomTintTransparency`:

```dart
/// A coloured room's tint transparency (plan colours spec PC-3): 204 of
/// 255, alpha 51, 20 %.
const int kRoomColorTransparency = 204;
```

  In `generate`, before the `return`:
  `final hue = p.colorValue;`
  `final DraftColor tintColor = hue == null ? kRoomTintColor : TrueColor(hue.rgb);`
  `final tintAlpha = hue == null ? kRoomTintTransparency : kRoomColorTransparency;`
  and use `tintColor` for both the step-3 `Generated` and the region,
  `tintAlpha` for the region's `transparency`. Update `generate`'s doc
  (step 1: "[kRoomTintColor] ... or, for a room with a colour
  ([RoomParams.colorValue]), `TrueColor` of its hue at
  [kRoomColorTransparency] (plan colours spec PC-3)"). With no colour the
  `Generated`s are exactly today's.

- [ ] **Step 6: Re-pin RP1** (`test/room_object_test.dart:99-120`, the
  named exception): its name "... key order seed, name, label, color;
  label and color null are written ..."; `keys` →
  `['seed', 'name', 'label', 'color']`; both pinned encodings end
  `,"color":null}`; the `==` loop gains
  `const RoomParams(1234.5, -987.25, 'Room 1', color: 'teal')`.

- [ ] **Step 7: Run** `flutter test test/room_color_test.dart test/room_object_test.dart test/host/barrel_test.dart`:
  PASS. Then the whole planner (`flutter test --enable-vmservice`),
  analyze, format; `apps/floor_planner` and `apps/restaurant_demo`:
  green.

- [ ] **Step 8: The mutants:**
  - **M-C1** (rooms) — `fromJson` throws on an unknown name (`color:
    floorPlanColorNamed(json['color'] as String?)!.name`). Killer: RC1,
    RC4.
  - **M-C3** — the tint ignores the colour (`tintColor` always
    `kRoomTintColor`). Killer: RC2.
  - **M-C4** — `toJson` omits a null `color` (`if (color != null)
    'color': color`). Killer: RC1, RP1.
  - **M-C16** — an uncoloured room's tint changes
    (`tintAlpha = kRoomColorTransparency` always). Killer: RC6, RC3.
  - **M-C22** — `copyWith` drops `color` (`color: null` in its body when
    left out). Killer: RC1's rename, RC2 (a rename after the recolour,
    add it as RC2's last leg).
  - **M-PC3-a** — `fromJson` ignores the key (`color: null`). Killer:
    RC1.
  - **M-PC3-b** — step 3 keeps ACI 7. Killer: RC7.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_floor_plan
git commit -m "feat(floor-plan): FloorPlanColor and a room's colour

Plan colours spec PC-1, PC-3: an eight-hue palette, stored by name; a
room's colour is a fourth RoomParams key (null when none), and a coloured
room's tint is its hue at 20 %. A recolour regenerates the existing tint
in the same undo step (the engine's stamp); an unknown name is kept and
drawn as today's tint.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
