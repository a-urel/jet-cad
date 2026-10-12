# Plan colours, Slice 1: the palette, schema 10 and rooms — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A room takes a colour from an eight-hue palette, chosen in the
editor's Colour picker, saved at schema 10, its tint regenerated in that
hue within the same undo step.

**Architecture:** The engine (`jet_cad_2d`) gains a command that sets an
entity's colour and transparency, and the parametric planner stamps both
onto a matched child when they differ (exact `==`), as it stamps the
layer (spec 12b D2). The schema moves to 10 (an empty migration). The
floor planner gains `FloorPlanColor`, `RoomParams.color`, a `recolor`
capability and a Colour picker on the Layer picker's pattern.

**Tech stack:** Dart 3 / Flutter (`flutter` and `dart` on `PATH`,
`/opt/homebrew/bin`), `package:test`, `flutter_test`.

**Spec:** [2026-10-12-plan-colors-design.md](../specs/2026-10-12-plan-colors-design.md),
revision 2, approved by the human on 2026-10-12 (`b77f491`): **Slice 1**
= PC-1, PC-2, PC-3, PC-3a, PC-8, PC-9 (rooms only), PC-10, PC-12's
Slice 1 part; facts F-1 to F-17; mutants M-C1 (rooms), M-C3, M-C4,
M-C10, M-C12, M-C13, M-C16, M-C17, M-C22.

**Started** on the human's *"evet, devam et"* (2026-10-12) after the
spec's approval. **Branch:** `spec/plan-colors` (worktree
`.claude/worktrees/plan-colors`), from `main` at `1414680`; the spec's
three commits, then this plan's. **Ledger:**
`.superpowers/sdd/2026-10-12-plan-colors/` (git-ignored, in the
worktree): `s1-task-<n>-report.md`, `s1-task-<n>-review.md`; archived
to `docs/superpowers/ledgers/2026-10-12-plan-colors-slice-1/` as the
branch's last commit before the merge.

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

## File structure

| File | Responsibility | Task |
|---|---|---|
| `packages/jet_cad_2d/lib/src/document/layer_commands.dart` | `SetEntityStyleCommand` beside `SetEntityLayerCommand` | 1 |
| `packages/jet_cad_2d/lib/src/parametric/regeneration.dart` | `_stampStyle` beside `_stampLayer`, called where it is | 1 |
| `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` | `Generated`'s contract text (F-13 amended) | 1 |
| `packages/jet_cad_2d/test/parametric/support/clients.dart` | the `Dye` test client | 1 |
| `packages/jet_cad_2d/test/parametric/style_stamp_test.dart` | ST1–ST4 | 1 |
| `packages/jet_cad_2d/lib/src/codec/schema_version.dart` | `kSchemaVersion = 10` and its history | 2 |
| `packages/jet_cad_2d/test/codec/support/schema_fixture.dart` | the schema tests' fixture (moved) | 2 |
| `packages/jet_cad_2d/test/codec/schema_10_test.dart` | S10-1, S10-2 | 2 |
| `packages/jet_cad_floor_plan/lib/src/colors/plan_color.dart` | `FloorPlanColor`, `floorPlanColorNamed` | 3 |
| `packages/jet_cad_floor_plan/lib/src/parametric/room.dart` | `RoomParams.color`, the coloured tint | 3 |
| `packages/jet_cad_floor_plan/test/room_color_test.dart` | RC1–RC7 | 3 |
| `packages/jet_cad_floor_plan/lib/src/host/editor_capabilities.dart` | `recolor` | 4 |
| `packages/jet_cad_floor_plan/lib/src/colors/color_picker.dart` | `recolorCommand`, `colorPickerBlocked`, `ColorPicker` | 4 |
| `packages/jet_cad_floor_plan/lib/src/selection_panel.dart` | mounts the picker; `darkCanvasPaper` | 4 |
| `packages/jet_cad_floor_plan/lib/src/planner_shell.dart` | passes `darkCanvasPaper` | 4 |
| `packages/jet_cad_floor_plan/lib/src/l10n/strings*.dart` | `color`, `colorNone`, `colorName` | 4 |
| `packages/jet_cad_floor_plan/test/colors/color_picker_test.dart` | CP1–CP6 | 4 |
| `CHANGELOG.md`, `docs/host-guide.md`, `STATUS.md` | Slice 1's part of PC-12 | 5 |

---

### Task 1: The engine stamps colour and transparency on a matched child (PC-3a)

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/layer_commands.dart` (after `SetEntityLayerCommand`, `:432-466`)
- Modify: `packages/jet_cad_2d/lib/src/parametric/regeneration.dart` (`_stampLayer` at `:470-480`; its two call sites in `_plan` at `:578-579` and `:610`; `_plan`'s doc at `:520-532`)
- Modify: `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` (`Generated`'s doc, `:198-217`, and its constructor's doc `:225-226`)
- Modify: `packages/jet_cad_2d/test/parametric/support/clients.dart` (add `Dye`, `DyeType`; register in the catalogue the tests use)
- Modify: `packages/jet_cad_2d/test/parametric/attributes_test.dart` (AT1, the named exception)
- Create: `packages/jet_cad_2d/test/parametric/style_stamp_test.dart`

**Interfaces:**
- Produces: `class SetEntityStyleCommand extends DraftCommand` with
  `SetEntityStyleCommand.restore(Handle entity, DraftColor color, int transparency)`;
  fields `entity`, `color`, `transparency`; `capability` =
  `Capability.geometry`; `capabilities` = `{Capability.components}`;
  `label` = `'Style'`; inverse = `.restore` of the old values. Exported
  through `package:jet_cad_2d/jet_cad_2d.dart` (`layer_commands.dart` is
  already exported; check with `grep -n layer_commands lib/jet_cad_2d.dart`).
- Produces (behaviour): a regeneration plans one
  `SetEntityStyleCommand.restore` per matched child whose stored colour
  (`entities.colorAt(slot)`, encoded) or transparency
  (`entities.transparencyAt(slot)`) differs from the `Generated`'s
  (`encodeColor(g.color)`, `g.transparency`), for a region's fill and
  boundary each; nothing otherwise.

- [ ] **Step 1: Add the `Dye` test client.** In
  `test/parametric/support/clients.dart`, after `SwatchType`:

```dart
/// A client whose colour and transparency are parameters (plan colours
/// spec PC-3a): one region (its fill and boundary) and one LINE, both in
/// [color] (an encoded `DraftColor`) at [alpha]. [x] moves both, so an
/// edit can match every child without a style change.
final class Dye implements Component {
  const Dye(this.x, this.color, this.alpha);
  static const String id = 'test.dye';
  final double x;

  /// `encodeColor` of the children's colour.
  final int color;
  final int alpha;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'x': x, 'color': color, 'alpha': alpha};
  static Dye fromJson(Map<String, Object?> j) => Dye(
      (j['x']! as num).toDouble(), j['color']! as int, j['alpha']! as int);
  @override
  bool operator ==(Object o) =>
      o is Dye && o.x == x && o.color == color && o.alpha == alpha;
  @override
  int get hashCode => Object.hash(x, color, alpha);
}

GeometryPayload dyeLoop(Dye p) => polylinePayload([
      Vector2(p.x, 10.5),
      Vector2(p.x + 300.25, 10.5),
      Vector2(p.x + 300.25, 210.75),
      Vector2(p.x, 210.75),
    ], closed: true);

GeometryPayload dyeLine(Dye p) =>
    linePayload(Vector2(p.x, 10.5), Vector2(p.x + 300.25, 210.75));

final class DyeType extends ParametricType<Dye> {
  const DyeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Dye params, Transform2 toWorld) => Aabb2.fromPoints([
        for (final (dx, dy) in const [
          (0.0, 10.5),
          (300.25, 10.5),
          (300.25, 210.75),
          (0.0, 210.75)
        ])
          toWorld.transformPoint(Vector2(params.x + dx, dy)),
      ]);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    _counted(self);
    final p = view.paramsOf<Dye>(self)!;
    final c = decodeColor(p.color);
    return [
      Generated.region(dyeLoop(p),
          color: c, transparency: p.alpha,
          boundaryFlags: EntityFlags.invisible),
      Generated(EntityKind.line, dyeLine(p), color: c, transparency: p.alpha),
    ];
  }
}
```

  Register it wherever `SwatchType` is registered (`grep -n "SwatchType()" test/parametric/support/*.dart`), with
  `Dye.id, Dye.fromJson, const DyeType()`.

- [ ] **Step 2: Write the failing tests** in
  `test/parametric/style_stamp_test.dart`:

```dart
// Plan colours spec PC-3a: colour and transparency are the planner's
// columns, as the layer is (12b D2): a matched child whose stored colour or
// transparency differs from what its object generates (exact ==) is
// restamped in the same edit; one that does not plans nothing.
//
// Fixture: a Dye in a group turned 0.4 rad, 4,000.5 mm off the origin.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

final Transform2 at = Transform2.translation(4000.5, -2500.25)
    .multiply(Transform2.rotation(0.4));

// Teal and purple, as the floor plan's palette has them; a hand literal.
const int teal = 0x01000000 | 0x00897B; // encodeColor(TrueColor(0x00897B))
const int purple = 0x01000000 | 0x8E24AA;

EntityRecord rec(DraftDocument d, Handle h) =>
    d.entities.read(d.entities.slotOf(h)!);

/// Every style command inside [c], compounds and replays opened.
Iterable<SetEntityStyleCommand> styleCommands(DraftCommand c) sync* {
  if (c is SetEntityStyleCommand) yield c;
  if (c is CompoundCommand) {
    for (final k in c.children) {
      yield* styleCommands(k);
    }
  } else if (c is ParametricReplay) {
    yield* styleCommands(c.replay);
  }
}

/// The style commands [command] plans on [doc]'s copy: a `ParametricEdit`
/// builds its plan in `apply`, so it is applied on a reload outside the
/// dispatcher and its inverse read (a `SetEntityStyleCommand`'s inverse is
/// one too), as `object_layer_test.dart`'s `planOnCopy` does.
List<SetEntityStyleCommand> plannedStyles(
    DraftDocument doc, DraftCommand Function(DraftDocument copy) command) {
  final copy = reload(enc(doc));
  final edit = copy.commands.expander!(command(copy)) as ParametricEdit;
  final inverse = edit.apply(copy).inverse as ParametricReplay;
  return styleCommands(inverse.replay).toList();
}

void main() {
  setUp(generateCalls.clear);

  test('ST0 premise: the hand literals are encodeColor of the true colours',
      () {
    expect(encodeColor(const TrueColor(0x00897B)), teal);
    expect(encodeColor(const TrueColor(0x8E24AA)), purple);
  });

  test(
      'ST1 a recolour restamps the matched fill, boundary and LINE in place: '
      'same handles, same payloads; undo and redo restore each record',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, at, const Dye(-120.5, teal, 204)));
    final children = kids(doc, hA);
    expect(children, hasLength(3), reason: 'fill, boundary, LINE');
    final before = {for (final k in children) k: rec(doc, k)};
    final bytes = canon(doc);

    doc.commands.execute(
        SetComponentCommand<Dye>(hA, const Dye(-120.5, purple, 153)));
    expect(kids(doc, hA), children, reason: 'every child matched');
    for (final k in children) {
      expect(rec(doc, k),
          before[k]!.copyWith(color: const TrueColor(0x8E24AA), transparency: 153),
          reason: '${k.toHex()}: colour and transparency only');
    }

    doc.commands.undo();
    expect(canon(doc), bytes);
    doc.commands.redo();
    for (final k in children) {
      expect(rec(doc, k).color, const TrueColor(0x8E24AA));
      expect(rec(doc, k).transparency, 153);
    }
  });

  test(
      'ST2 the guard: an edit that leaves the style alone plans no style '
      'command (a move of the Dye; an edit of another object)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, at, const Dye(-120.5, teal, 204)));
    doc.commands.execute(create(doc, hB, atB, const ClipRect(400, 900)));
    expect(
        plannedStyles(doc,
            (_) => SetComponentCommand<Dye>(hA, const Dye(75.25, teal, 204))),
        isEmpty,
        reason: 'a move plans none');
    expect(
        plannedStyles(doc,
            (_) => SetComponentCommand<ClipRect>(hB, const ClipRect(410.5, 900))),
        isEmpty,
        reason: 'another object plans none');
    expect(
        plannedStyles(doc,
            (_) => SetComponentCommand<Dye>(hA, const Dye(-120.5, purple, 204))),
        hasLength(3),
        reason: 'premise: a recolour plans one per child');
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
  });

  test('ST3 a transparency change alone is stamped; so is a colour alone',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, at, const Dye(-120.5, teal, 204)));
    doc.commands.execute(
        SetComponentCommand<Dye>(hA, const Dye(-120.5, teal, 51)));
    for (final k in kids(doc, hA)) {
      expect(rec(doc, k).transparency, 51);
      expect(rec(doc, k).color, const TrueColor(0x00897B));
    }
    doc.commands.execute(
        SetComponentCommand<Dye>(hA, const Dye(-120.5, purple, 51)));
    for (final k in kids(doc, hA)) {
      expect(rec(doc, k).transparency, 51);
      expect(rec(doc, k).color, const TrueColor(0x8E24AA));
    }
  });

  test(
      'ST4 SetEntityStyleCommand: sets both, its inverse restores both, its '
      'capabilities are a property edit, a missing entity throws', () {
    final doc = DraftDocument.empty();
    final h = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: draftRecord(h, doc.rootHandle, EntityKind.line,
            layer: ReservedHandles.layerZero),
        payload: linePayload(Vector2(0.5, 0.5), Vector2(10.5, 3.25))));
    final cmd = SetEntityStyleCommand.restore(h, const TrueColor(0x00897B), 204);
    expect(cmd.capability, Capability.geometry);
    expect(cmd.capabilities, {Capability.components});
    doc.commands.execute(cmd);
    expect(rec(doc, h).color, const TrueColor(0x00897B));
    expect(rec(doc, h).transparency, 204);
    doc.commands.undo();
    expect(rec(doc, h).color, const ByLayerColor());
    expect(rec(doc, h).transparency, kByLayer);
    expect(
        () => doc.commands.execute(SetEntityStyleCommand.restore(
            const Handle(0xFFFF), const ByLayerColor(), kByLayer)),
        throwsStateError);
  });
}
```

  `create` (returns the creating command), `hA`, `hB`, `atB`, `kids`,
  `canon`, `enc`, `reload`, `paramDoc`, `catalog` and `ClipRect` come
  from `support/fixture.dart` and `support/clients.dart`; read them
  first. `reload` must install the parametric system (it does for
  `object_layer_test.dart`'s `planOnCopy`, which `plannedStyles`
  copies).

- [ ] **Step 3: Run them and see them fail.**
  Run (in `packages/jet_cad_2d`): `dart test test/parametric/style_stamp_test.dart`
  Expected: compile error, `SetEntityStyleCommand` undefined.

- [ ] **Step 4: Add `SetEntityStyleCommand`** after `SetEntityLayerCommand`
  in `lib/src/document/layer_commands.dart`:

```dart
/// Sets one entity's colour and transparency (plan colours spec PC-3a):
/// the parametric planner's stamp on a matched child whose stored style
/// differs from what its object generates. Its inverse restores the old
/// values exactly. The capability split is [SetEntityLayerCommand]'s: a
/// property edit (`{components}`) that changes pixels (`geometry`).
///
/// Only the restore form exists: no user edit sets an entity's style
/// through it.
class SetEntityStyleCommand extends DraftCommand {
  final Handle entity;
  final DraftColor color;
  final int transparency;

  SetEntityStyleCommand.restore(this.entity, this.color, this.transparency);

  @override
  Capability get capability => Capability.geometry;

  @override
  Set<Capability> get capabilities => const {Capability.components};

  @override
  String get label => 'Style';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(entity);
    if (slot == null) {
      throw StateError('no entity with handle ${entity.toHex()}');
    }
    final record = target.entities.read(slot);
    target.entities.replace(
        slot, record.copyWith(color: color, transparency: transparency));
    target.invalidateDerived();
    return CommandResult(
      inverse: SetEntityStyleCommand.restore(
          entity, record.color, record.transparency),
      touched: {entity},
    );
  }
}
```

  Check `EntityRecord.copyWith` takes `color` and `transparency`
  (`lib/src/store/entity_store.dart`); `attributes_test.dart` already
  calls `copyWith(text: ...)`.

- [ ] **Step 5: Add the stamp** in `lib/src/parametric/regeneration.dart`,
  after `_stampLayer`:

```dart
/// Plan colours spec PC-3a: the stamp on one **matched** child [c] of its
/// generated colour and transparency, [g]'s: one
/// `SetEntityStyleCommand.restore` when the stored colour or transparency
/// differs (exact `==` on the stored encodings), nothing otherwise. The
/// guard is load-bearing, as [_stampLayer]'s (12b R-15): an object whose
/// style did not change plans no command.
void _stampStyle(CommandTarget t, List<DraftCommand> out, Handle c, Generated g) {
  final slot = t.entities.slotOf(c)!;
  if (t.entities.colorAt(slot) != encodeColor(g.color) ||
      t.entities.transparencyAt(slot) != g.transparency) {
    out.add(SetEntityStyleCommand.restore(c, g.color, g.transparency));
  }
}
```

  and call it right after each `_stampLayer` in `_plan`: after
  `_stampLayer(t, out, fills[i], layer);` add
  `_stampStyle(t, out, fills[i], g);`, after the boundary's
  `_stampStyle(t, out, boundary, g);`, and after the plain child's
  `_stampStyle(t, out, existing[i], g);`. Update `_plan`'s doc
  (`:526-529`): "then its layer ... ([_stampLayer], spec 12b D2) and its
  colour and transparency ([_stampStyle], plan colours spec PC-3a), a
  matched region's fill and boundary each." Update the comment at
  `:603-606` ("every other attribute is fixed at creation, like the
  colour") to "every other attribute but the colour and the
  transparency (PC-3a) is fixed at creation".

- [ ] **Step 6: Amend `Generated`'s contract** in
  `parametric_system.dart:198-217`: the attributes written on add only
  become "flags, boundary flags, linetype, lineweight, text attributes";
  the paragraph "**One column is the planner's ...: the layer**" becomes
  "**Three columns are the planner's, not the client's: the layer**
  (spec 12b D2) **and the colour and transparency** (plan colours spec
  PC-3a)": every matched child whose stored colour or transparency
  differs from the `Generated`'s (exact `==`) is restamped by a
  `SetEntityStyleCommand.restore` in the plan, a region's fill and
  boundary each; a child already in its style plans nothing. The
  constructor's doc (`:225-226`) drops `transparency` from "written on
  add only".

- [ ] **Step 7: Re-pin AT1** (`test/parametric/attributes_test.dart`,
  the named exception): its header comment (`:1-2`) says "written into
  each record when the child is added; on a match only the colour and the
  transparency are rewritten (plan colours spec PC-3a), never the rest";
  its name says "... and on a match only the colour and transparency
  move"; after `const s1 = Swatch(-210.75, 95.5, 100, 50);` the loop
  becomes:

```dart
    for (final k in created) {
      // PC-3a: transparency is the planner's column now; the region's two
      // records and the LINE take s1's alpha. The TEXTs carry no alpha.
      final r = records[k]!;
      final alpha = r.transparency == 229 ? 100 : r.transparency;
      expect(recordOf(doc, k), r.copyWith(transparency: alpha),
          reason: '${k.toHex()}: only the transparency moves');
    }
    expect(recordOf(doc, line).lineweight, 35,
        reason: 'lineweight is still written on add only');
```

  Read AT1 whole first: if the TEXT records' transparency is also 229
  (it is `kByLayer` unless `Swatch` sets it), keep the rule as written —
  the expected value is what `Swatch`'s generate now produces for each
  record, derived from its code, never read back from the result.

- [ ] **Step 8: Run the engine's suite through the comparison.**
  Run (repo root):
  `(cd packages/jet_cad_2d && dart test --file-reporter json:/tmp/pc-s1-t1.json); dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d /tmp/pc-s1-t1.json`
  Expected: `expect_failures` exits 0 (the two standing fingerprints, exactly). Then `dart analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed .` in `packages/jet_cad_2d`: clean.

- [ ] **Step 9: Run the dependants.** `jet_cad_2d_flutter` and
  `jet_cad_2d_gpu` through the comparison; `jet_cad_floor_plan`
  (`flutter test --enable-vmservice`), `apps/floor_planner`,
  `apps/restaurant_demo`, `jet_cad_restaurant_symbols`: green. **No
  floor-plan object changes a colour today**, so no planner test may
  change; one that does is a finding (a stored file whose children's
  style differs from what its object generates now: name the file).

- [ ] **Step 10: The mutants** (apply, see red, revert; record the
  killer):
  - **M-C17** — `_stampStyle` unguarded (always adds the command).
    Killer: ST2.
  - **M-PC3a-1** — the boundary not stamped (its `_stampStyle` call
    removed). Killer: ST1 (the boundary's record).
  - **M-PC3a-2** — transparency dropped from the guard and the command
    (`copyWith(color: color)` only). Killer: ST3 (alpha alone), ST1.
  - **M-PC3a-3** — the inverse restores the new values
    (`.restore(entity, color, transparency)`). Killer: ST1's undo, ST4.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d
git commit -m "feat(2d): the planner stamps colour and transparency on a matched child

Plan colours spec PC-3a: SetEntityStyleCommand sets an entity's colour
and transparency; a regeneration restamps a matched child whose stored
style differs from what its object generates (exact ==), a region's fill
and boundary each, as it stamps the layer (12b D2). An untouched object
plans nothing. Generated's contract and AT1 say so.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

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

---

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-C17, M-PC3a-1, M-PC3a-2, M-PC3a-3 | 4 |
| 2 | M-C10, M-C10b | 2 |
| 3 | M-C1 (rooms), M-C3, M-C4, M-C16, M-C22, M-PC3-a, M-PC3-b | 7 |
| 4 | M-C12, M-C13, M-PC9-a, M-PC9-b, M-PC9-c, M-PC8 | 6 |
| 5 | — (the guide's probe is unchanged) | 0 |

The spec's M-C2, M-C5 to M-C9, M-C11, M-C14, M-C15, M-C18 to M-C21 and
M-C23 to M-C25 are Slice 2's (tables).

## Exit gate

- Task 5's step 5 green: every gate, the standing sets exact, the host
  probe and the three old-host probes, locally; CI green on the pushed
  branch when the human pushes it.
- Every named mutant above seen red and recorded in its task's report.
- A whole-branch independent review, its fixes applied.
- The ledger archived to
  `docs/superpowers/ledgers/2026-10-12-plan-colors-slice-1/` as the
  branch's last commit.
- **Owed to the human:** the German and Turkish read of the Colour
  row's words; a look at a coloured room on the light and the dark
  canvas; the macOS re-baseline of the engine's two fingerprints (owed
  since schema 7, shifted again at 10).
- **The merge into `main` happens on the human's word.** No release
  until Slice 2 (0.6.0).
