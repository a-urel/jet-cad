# Brief: plan colours Slice 1, Task 4

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

### Task 4: The `recolor` capability, the Colour picker and its words (PC-8, PC-9 rooms, PC-10)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/host/editor_capabilities.dart` (constructor `:139-162`, `readOnly` `:189-203`, the fields `:229-236`, `copyWith` `:241-286`, `_flags` `:289-310`, the class doc `:110-135`)
- Create: `packages/jet_cad_floor_plan/lib/src/colors/color_picker.dart`
- Modify: `packages/jet_cad_floor_plan/lib/src/selection_panel.dart` (constructor `:85-127`; `build` `:1238-1420`)
- Modify: `packages/jet_cad_floor_plan/lib/src/planner_shell.dart` (`SelectionPanel(` at `:1522-1532`)
- Modify: `packages/jet_cad_floor_plan/lib/src/l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart`
- Modify (named exceptions): `test/l10n/recording_strings.dart`, `test/host/editor_capabilities_test.dart:273-277`, `test/invariants/theme_colours_test.dart:44-51`
- Create: `packages/jet_cad_floor_plan/test/colors/color_picker_test.dart`

**Interfaces:**
- Consumes: `FloorPlanColor`, `floorPlanColorNamed`,
  `RoomParams.copyWith(color:)` (Task 3).
- Produces (Slice 2 extends these to tables):

```dart
// lib/src/colors/color_picker.dart
/// The colour of each key's object, as the picker reads it: a room's
/// stored name (null for none); keys that are no room are not listed.
List<String?> pickedColors(DraftDocument doc, Iterable<SelectionKey> keys);

/// The one command that sets [color] (null: none) on every room among
/// [keys], labelled 'Colour'; null when none would change.
DraftCommand? recolorCommand(
    DraftDocument doc, Iterable<SelectionKey> keys, FloorPlanColor? color);

/// Why the picker is read-only for [keys], or null when it acts:
/// `strings.readOnlyDocument` when the permissions refuse `components` or
/// `RoomType().editCapability` for a room among [keys]; the strings'
/// `colorRefused` when [capabilities].recolor is false.
String? colorPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys,
    FloorPlanEditorCapabilities capabilities, FloorPlanStrings strings);

class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.document,
      required this.selection, required this.capabilities,
      this.darkCanvasPaper});
}

/// The swatch colour of [rgb] (PC-9): as the canvas shows it, re-toned on a
/// dark canvas. The one place the planner turns a palette hue into a Color.
Color swatchColor(int rgb, int? darkCanvasPaper);
```

  Strings: `String get color;` (the row's title), `String get colorNone;`,
  `String get colorRefused;` (the read-only tooltip when `recolor` is
  refused), `String colorName(FloorPlanColor color);`.
  `FloorPlanEditorCapabilities.recolor` (`bool`, default true).

- [ ] **Step 1: The capability's failing tests**, appended to
  `test/host/editor_capabilities_test.dart` as a new test:

```dart
  test('PC8 recolor: on in full and tablesOnly, off in readOnly; copyWith, '
      '== and hashCode carry it', () {
    expect(Caps.full.recolor, isTrue);
    expect(Caps.tablesOnly.recolor, isTrue);
    expect(Caps.readOnly.recolor, isFalse);
    final off = Caps.full.copyWith(recolor: false);
    expect(off.recolor, isFalse);
    expect(off == Caps.full, isFalse);
    expect(off.copyWith(recolor: true), Caps.full);
    expect(off.copyWith(recolor: true).hashCode, Caps.full.hashCode);
    expect(off.toString(), 'FloorPlanEditorCapabilities(recolor: false)');
  });
```

  and re-pin the `readOnly` `toString` (`:273-277`) to end
  `'changeLayer: false, recolor: false, undo: false)'`.

- [ ] **Step 2: Add `recolor`**: a constructor parameter `this.recolor =
  true` after `changeLayer`; the field in the `final bool move, ...`
  line after `changeLayer`; `copyWith`'s `bool? recolor` and
  `recolor: recolor ?? this.recolor`; `_flags`' `('recolor', recolor)`
  after `changeLayer`; `readOnly` gains `recolor: false`. The class doc's
  bullet for the selection's edits gains "[recolor]: the Colour picker
  (plan colours spec PC-8); refused, it shows read-only". Run the
  capabilities tests: PASS.

- [ ] **Step 3: The strings.** In `strings.dart`, near `layer` (`:345`):

```dart
  /// The Colour picker's title (plan colours spec PC-9).
  String get color;

  /// The picker's swatch for no colour.
  String get colorNone;

  /// The picker's tooltip when the host refuses `recolor`.
  String get colorRefused;

  /// [color]'s name, for its swatch's tooltip and semantics label.
  String colorName(FloorPlanColor color);
```

  `strings_en.dart`: `color => 'Colour'`, `colorNone => 'None'`,
  `colorRefused => 'Colours are not editable here'`, and

```dart
  @override
  String colorName(FloorPlanColor color) => switch (color) {
        FloorPlanColor.red => 'Red',
        FloorPlanColor.orange => 'Orange',
        FloorPlanColor.yellow => 'Yellow',
        FloorPlanColor.green => 'Green',
        FloorPlanColor.teal => 'Teal',
        FloorPlanColor.blue => 'Blue',
        FloorPlanColor.purple => 'Purple',
        FloorPlanColor.grey => 'Grey',
      };
```

  `strings_de.dart`: `'Farbe'`, `'Keine'`, `'Farben sind hier nicht
  änderbar'`, and Rot, Orange, Gelb, Grün, Petrol, Blau, Lila, Grau.
  `strings_tr.dart`: `'Renk'`, `'Yok'`, `'Renkler burada
  değiştirilemez'`, and Kırmızı, Turuncu, Sarı, Yeşil, Turkuaz, Mavi,
  Mor, Gri. `recording_strings.dart` (the named exception): the three
  getters as `record(inner.X)` and
  `String colorName(FloorPlanColor color) => record(inner.colorName(color));`,
  its import of `plan_color.dart`. Run `flutter test test/l10n`: PASS
  (the l10n suite checks every language answers every member).

- [ ] **Step 4: The picker's failing tests** in
  `test/colors/color_picker_test.dart`. Fixture: `roomsPlan()`'s shape
  (copy the builder from `room_panel_test.dart:105-118`, and its
  `pumpShell`, `select`), with the shell pumped over it. Helpers:

```dart
Finder swatch(String name) => find.byKey(Key('color-swatch-$name'));
Finder get picker => find.byKey(const Key('color-picker'));

/// The marked swatch's name, or null for none.
String? marked(WidgetTester tester) {
  for (final n in ['none', for (final c in FloorPlanColor.values) c.name]) {
    final s = tester.widget<Semantics>(find.descendant(
        of: swatch(n), matching: find.byType(Semantics)).first);
    if (s.properties.selected ?? false) return n;
  }
  return null;
}
```

  The tests:
  - **CP1** visibility and marking: hidden with nothing selected, with
    a wall alone, with a separator alone, and while the Wall tool's
    settings show; shown for room A, for A and B, for A and a wall;
    marks `none` for uncoloured rooms; after A is `teal` (by a
    `recolor` command as in Task 3's tests) marks `teal` for A, nothing
    for A and B (mixed); for A carrying `"magenta"`, marks nothing
    (Review Focus 5).
  - **CP2** a tap on `teal` with A, B and a wall selected (**M-C12**,
    Review Focus 4): one undo step (`undoDepth + 1`) whose label is
    `Colour` (`doc.commands.undoLabel` or the history's top entry — read
    `undo.dart` for the accessor); both rooms' `color == 'teal'`; the
    wall's component and its children's records unchanged (compared
    whole); both rooms' tints `TrueColor(0x00897B)`; then
    `Ctrl+Z` (`tester.sendKeyDownEvent(LogicalKeyboardKey.control)`, Z, as
    `room_panel_test.dart` drives a chord — read it) and **one** `pump`:
    both tints back to ACI 7, and the canvas repainted (the
    `DraftCanvas`'s painter `shouldRepaint` or the document's revision —
    use what `room_panel_test`'s undo tests assert) (Review Focus 3).
  - **CP3** a second tap on `teal` (Review Focus 2): no new undo step;
    with A teal and B purple, a tap on `teal` changes B only (one
    `SetComponentCommand` inside the compound: count them).
  - **CP4** read-only (**M-C13**): the shell pumped with
    `capabilities: FloorPlanEditorCapabilities.full.copyWith(recolor:
    false)` (pass it as `room_panel_test`'s capability tests do, or
    through `PlannerShell`'s capabilities parameter — read its
    constructor): the picker shows, `teal` is marked for a teal room, a
    tap changes nothing (`canon` before and after), the tooltip is
    `colorRefused`; then under `DraftPermissions.runtime` (set as
    `room_panel_test`'s read-only test sets it) the same, its tooltip
    `readOnlyDocument`.
  - **CP5** words: under the Turkish strings (pump the shell inside
    `Localizations` as `test/l10n/panel_words_test.dart` does) the
    title reads `Renk`, the `teal` swatch's tooltip and semantics label
    `Turkuaz`, None's `Yok`.
  - **CP6** the dark canvas: `swatchColor(0x00897B, null)` is
    `Color(0xFF00897B)` (compare `toARGB32()` with `0xFF00897B`);
    `swatchColor(0x00897B, kDarkCanvasPaper)` is
    `0xFF000000 | darkCanvasTone(0x00897B, kDarkCanvasPaper)`.

- [ ] **Step 5: Run and see them fail.** `flutter test test/colors/color_picker_test.dart`:
  compile errors (`color_picker.dart` missing).

- [ ] **Step 6: Implement `color_picker.dart`:**

```dart
// The Selection panel's Colour row (plan colours spec PC-9): nine
// swatches, None and the palette's eight hues, setting the colour of every
// selected room in one undo step (Slice 2 adds tables). It keeps no state:
// the panel rebuilds it on every selection and document change, as it does
// the Layer picker.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../host/editor_capabilities.dart';
import '../l10n/strings.dart';
import '../parametric/live_objects.dart';
import '../parametric/room.dart';
import 'plan_color.dart';

/// The rooms among [keys], in key order, each once.
List<Handle> _rooms(DraftDocument doc, Iterable<SelectionKey> keys) => [
      for (final h in {for (final k in keys) k.target})
        if (isLiveObject<RoomParams>(doc, h)) h,
    ];

List<String?> pickedColors(DraftDocument doc, Iterable<SelectionKey> keys) => [
      for (final h in _rooms(doc, keys))
        doc.components.get<RoomParams>(h)!.color,
    ];

DraftCommand? recolorCommand(
    DraftDocument doc, Iterable<SelectionKey> keys, FloorPlanColor? color) {
  final name = color?.name;
  final edits = <DraftCommand>[
    for (final h in _rooms(doc, keys))
      if (doc.components.get<RoomParams>(h)! case final p
          when p.color != name)
        SetComponentCommand<RoomParams>(h, p.copyWith(color: name)),
  ];
  return edits.isEmpty ? null : CompoundCommand(edits, label: 'Colour');
}

String? colorPickerBlocked(DraftDocument doc, Iterable<SelectionKey> keys,
    FloorPlanEditorCapabilities capabilities, FloorPlanStrings strings) {
  final permissions = doc.commands.permissions;
  if (!permissions.allows(Capability.components) ||
      (_rooms(doc, keys).isNotEmpty &&
          !permissions.allows(const RoomType().editCapability))) {
    return strings.readOnlyDocument;
  }
  if (!capabilities.recolor) return strings.colorRefused;
  return null;
}

Color swatchColor(int rgb, int? darkCanvasPaper) => Color(0xFF000000 |
    (darkCanvasPaper == null
        ? rgb
        : darkCanvasTone(rgb, darkCanvasPaper & 0xFFFFFF)));

class ColorPicker extends StatelessWidget {
  const ColorPicker(
      {super.key,
      required this.document,
      required this.selection,
      required this.capabilities,
      this.darkCanvasPaper});

  final DraftDocument document;
  final SelectionController selection;
  final FloorPlanEditorCapabilities capabilities;

  /// The dark canvas's paper, ARGB, while the canvas re-tones; null on a
  /// light canvas.
  final int? darkCanvasPaper;

  void _choose(FloorPlanColor? color, FloorPlanStrings strings) {
    final keys = selection.keys;
    if (colorPickerBlocked(document, keys, capabilities, strings) != null) {
      return;
    }
    final command = recolorCommand(document, keys, color);
    if (command == null) return;
    try {
      document.commands.execute(command);
    } on ArgumentError {
      // Refused: the dispatcher rolled it back.
    } on StateError {
      // Refused: the dispatcher rolled it back.
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = FloorPlanStrings.of(context);
    final keys = selection.keys;
    final blocked = colorPickerBlocked(document, keys, capabilities, strings);
    final colors = pickedColors(document, keys);
    final common = colors.toSet().length == 1 ? colors.first : '\u0000';
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(String key, String label, Color? fill, bool marked,
            VoidCallback onTap) =>
        Tooltip(
          message: blocked ?? label,
          child: Semantics(
            button: true,
            selected: marked,
            enabled: blocked == null,
            label: label,
            child: InkWell(
              key: Key('color-swatch-$key'),
              onTap: blocked == null ? onTap : null,
              customBorder: const CircleBorder(),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: marked ? scheme.primary : scheme.outline,
                      width: marked ? 3 : 1),
                ),
                child: fill == null
                    ? Icon(Icons.block, size: 14, color: scheme.outline)
                    : null,
              ),
            ),
          ),
        );
    return Column(
      key: const Key('color-picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(strings.color),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          swatch('none', strings.colorNone, null, common == null,
              () => _choose(null, strings)),
          for (final c in FloorPlanColor.values)
            swatch(c.name, strings.colorName(c),
                swatchColor(c.rgb, darkCanvasPaper), common == c.name,
                () => _choose(c, strings)),
        ]),
      ],
    );
  }
}
```

  The `'\u0000'` sentinel stands for "mixed" (no swatch marked); a
  stored unknown name (`"magenta"`) is common to no swatch, so nothing
  is marked. If `isLiveObject` lives elsewhere, import it from where
  `layer_picker.dart` does.

- [ ] **Step 7: Mount it.** `SelectionPanel` gains
  `this.darkCanvasPaper` (`final int? darkCanvasPaper;`, documented as
  `ColorPicker`'s). In `build`, after the `picker` flag:

```dart
    // Plan colours spec PC-9: the Colour row, for a selection holding a
    // room (Slice 2: or a table), whenever no tool-settings section shows.
    final colors = !_toolMode &&
        _openingToolMode == null &&
        pickedColors(widget.document, widget.selection.keys).isNotEmpty;
```

  include `colors` in the early return (`if (!sections && !picker &&
  !colors) return ...`), and before the Layer picker's block:

```dart
            if (colors) ...[
              if (sections) const SizedBox(height: 12),
              ColorPicker(
                  document: widget.document,
                  selection: widget.selection,
                  capabilities: widget.capabilities,
                  darkCanvasPaper: widget.darkCanvasPaper),
            ],
```

  and the Layer picker's spacer becomes `if (sections || colors)`. In
  `planner_shell.dart` pass `darkCanvasPaper: _darkCanvas ? _paperArgb()
  : null` to `SelectionPanel(`. The panel's class doc gains a
  **Colour** bullet before **Layer**.

- [ ] **Step 8: The colour-literal invariant.** `swatchColor`'s
  `Color(0xFF000000 |` is the one new literal: add
  `('lib/src/colors/color_picker.dart', 'Color(0xFF000000 |'),` to
  `kAllowedLiterals` in `test/invariants/theme_colours_test.dart`
  (`:44-51`), with a one-line comment "PC-9's swatch: a palette hue made a
  Color, in one function".

- [ ] **Step 9: Run** `flutter test test/colors test/host/editor_capabilities_test.dart test/l10n test/invariants test/room_panel_test.dart test/selection_panel_test.dart`:
  PASS. Then the whole planner (`--enable-vmservice`), analyze, format;
  `apps/floor_planner`, `apps/restaurant_demo`: green.

- [ ] **Step 10: The mutants:**
  - **M-C12** — the command sets the first room only (`_rooms(...).take(1)`).
    Killer: CP2.
  - **M-C13** — a refused `recolor` still applies a tap (the
    `capabilities.recolor` line removed). Killer: CP4.
  - **M-PC9-a** — rooms already at the colour not skipped (`when true`).
    Killer: CP3 (an undo step from a no-op tap).
  - **M-PC9-b** — the permissions ignored (the first `if` removed).
    Killer: CP4's runtime leg.
  - **M-PC8** — `readOnly` keeps `recolor` true. Killer: PC8.
  - **M-PC9-c** — the dark canvas ignored (`swatchColor` returns `rgb`
    always). Killer: CP6.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_floor_plan
git status --short | grep analysis_options && echo "STOP: analysis_options staged"
git commit -m "feat(floor-plan): the Colour picker and the recolor capability

Plan colours spec PC-8, PC-9, PC-10: the Selection panel's Colour row
sets None or one of eight hues on every selected room in one undo step
labelled Colour; read-only when the host refuses recolor (off in
readOnly) or the document's permissions do. The swatches show the hue as
the canvas does. Its words in English, German and Turkish.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
