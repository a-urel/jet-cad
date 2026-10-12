# Brief: plan colours Slice 1, Task 1

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
