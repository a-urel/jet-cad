### Task 19: The room tool and its notice (spec C3.5, C1.2, C1.5, C1.6, C6, C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/room/room_tool.dart` (ported: `RoomOccupied`, `RoomTool`; new: `kRoomNameText`, `kRoomOccupiedText`, `RoomOccupied.text`, `RoomTool.occupied`, the `ToolNotice` side)
  - `test/room/room_tool_test.dart` (ported kit cases: TT1 (the tool), TT2, TT3, TT4, TT4b, TT5, TT6, TT8, TT9 — TT10 is moved to Task 20, which brings the dimension it needs; new: RT-notice, RT-words, RT-tool, RT-frozen-wall)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/src/room/room_plan.dart` (`roomPlanTool`), `lib/src/kit.dart` (`roomPlanTool` in `tools`, before `separatorPlanTool`)
- Create (`packages/jet_cad_2d_integration/`): `test/room/room_tool_test.dart` (ported: TT1 (the editor), TT7, SG1; new: RT-notice-locale)

**Interfaces:**
- Consumes:
  - Task 18: `RoomParams`, `roomPlanType`, `room_plan.dart`; the kit's `room_fixture.dart` with `addRoom`; the integration support `room_plans.dart` (`roomPlan`, `RoomPlan`, `R`, `W`, `S`, `O`, `Placement`, `corpusGroups`, `boxWalls`, `sampleWalls`, `sampleColumn`, `sampleSeparator`, `sampleOpenings`, `pumpEditor`, `globalAt`, `clickAt`, `press`, `undoKey`, `status`, `rooms`, `labelStrings`; the rig's re-exported, R-P14).
  - Task 16: `RoomInputs`, `roomInputsOf`, `room_trace.dart` (`Traced`, `SeedInWall`, `Unbounded`, `traceRoomAmong`, `outerContours`, `pointInRing`, `pointInRingXY`, `debugTracedSegments`); the kit's test support (`liveOf`, `testCatalog`, R-P6).
  - (Task 20 is not consumed: TT10, the one case that needs the dimension, is moved to Task 20, which appends it to this task's `test/room/room_tool_test.dart`.)
  - Task 9: `ArchitectureTools`, `ArchitectureTypes`, `liveTypesOf`, `LiveTypeOf`, `architectureNames` (`lib/src/words/words.dart`, the kit's own `KitNames`), `architectureKit`; the words `tool:architecture.room` ('Room', 'Raum', 'Oda'), `text:architecture.room-name` (`'Room {n}'`, `'Raum {n}'`, `'Oda {n}'`), `text:architecture.room-occupied` (`'Already a room: {name}'`, `'Bereits ein Raum: {name}'`, `'Zaten bir oda: {name}'`), today's `strings_{en,de,tr}.dart` `roomName`, `roomOccupied`, `toolRoom` (`:416, :61, :91` in English).
  - Task 3: `KitText` (`==` by value), `KitWords.text(id, [args])`, `fillText`, `numberedNameIndex(String name, Iterable<String Function(int n)> patterns, {String Function(String)? fold})`.
  - Task 4: `ToolNotice`; `PlanController.toolNotice`; `PlanEditor`'s status line `label — n selected — textOf(notice)`, worded at read time.
  - Task 6: `FakePlanServices` (`names`, `locale`, `frozen`, `scale`).
  - Today: `jet_cad_floor_plan/lib/src/parametric/room_tool.dart:1-443`; the shell's composition, `planner_shell.dart:989-1011`.
- Produces:

```dart
// lib/src/room/room_tool.dart — today's names kept:
const String kRoomNameText = 'text:architecture.room-name';          // {n}
const String kRoomOccupiedText = 'text:architecture.room-occupied';  // {name}
@immutable final class RoomOccupied {
  const RoomOccupied(this.name); final String name;                  // unchanged
  KitText get text;                                  // NEW: KitText(kRoomOccupiedText, {'name': name})
}
class RoomTool extends PlacementTool implements ToolNotice {
  RoomTool(RoomInputs inputs, {required KitWords words, required LiveTypeOf live});
  final RoomInputs inputs; final KitWords words; final LiveTypeOf live;
  ValueListenable<RoomOccupied?> get occupied;       // today's `notice`, renamed
  @override ValueListenable<KitText?> get notice;    // occupied's KitText (spec C1.2)
  /* debugContourBuilds, debugPreviewBuilds, debugTraces, debugPreview: unchanged */
}
// lib/src/room/room_plan.dart (Shared interfaces: "roomPlanTool (Task 19)")
final PlanTool roomPlanTool;   // ArchitectureTools.room, letter 'M'
```

**Appendix A rows closed:**
- D-19, the room's last file: `room_tool_test` (11 of 12 here: TT1 split in two, TT2-TT6, TT8, TT9 kit; TT1 (the editor), TT7, SG1 integration; TT10 moved to Task 20, which closes the file).
- D-27, the room's notice (the contract part is Task 4's; the dimension's is Task 22's): the Room tool's notice through `ToolNotice`, worded at read time (RT-notice, RT-notice-locale; today's composed `'Room — Already a room: Room 1'` kept in TT1 (the editor) and TT7).
- D-25, in part: the room's three words (`tool:`, `text:...room-name`, `text:...room-occupied`) used and pinned in three languages (TT4b, RT-notice-locale).

**Placement (spec C7), per case.**

| Case (`room_tool_test.dart`) | Where | Why |
|---|---|---|
| TT1, lines 225-260 (the tool driven directly) | kit: "TT1 ... (the tool)" | `RoomTool` over `FakePlanServices` |
| TT1, lines 262-288 (the shell) | integration: "TT1 ... (the editor)" | `PlannerShell`, keys and the status line |
| TT2, TT3, TT4, TT4b, TT5, TT6, TT8, TT9 | kit | the tool driven directly |
| TT10 | kit, **moved to Task 20** | needs the dimension (`DimensionParams`, its catalog line), which Task 20 creates |
| TT7 | integration | the status line over `PlannerShell` |
| SG1 | integration | the shell's text-entry guard |

  **TT1 splits by its own halves** (plan ruling, fixture change): one case today, a tool half and a shell half (its comment at `:262` starts "The shell:"); the halves share nothing but the name. Each half keeps every one of its assertions; the names gain ` (the tool)` and ` (the editor)`, as today's `room_grips_test` names its shell copies `GR1 (shell)`.
  No case has a twin in `packages/jet_cad_2d_plan/test/` (2a's `canvas/touch_tools_test.dart:6` leaves TD1, the Room tool, to sub-project 3: Task 26's).

**Plan decisions:**
- **The notice is a value worded at read time** (spec C1.2): the tool keeps today's `RoomOccupied` (its listenable renamed `occupied`, since `ToolNotice.notice` is a `ValueListenable<KitText?>`) and publishes `RoomOccupied.text`, `KitText('text:architecture.room-occupied', {'name': name})`, beside it; both change together. The plan words it when the status line is read (`PlanController.textOf`), so a language switch re-words it at once, today's (`planner_shell.dart:1007-1010`: `roomOccupied(occupied.name)` at read time). The ported cases that read `tool.notice.value` against `RoomOccupied(...)` read `tool.occupied.value` (a name change, assertions unchanged).
- **The numbered name** (spec C1.6): today counts `Room N` over the words of the moment and every built-in language (`jet_cad_floor_plan/lib/src/l10n/numbered_names.dart:14-33`; `room_tool.dart:379-393`). The kit passes `numberedNameIndex` one pattern for the words of the moment (`KitWords.text`: a host's word for the current locale first) and one per locale of its own words (`architectureNames`): today's rule exactly. `KitWords` exposes no other locale's host word, and today counted none (a host's language class was only ever the current one).
- **The tool reads the plan's live rule** for rooms (`_liveRooms`) and, through `roomInputsOf`, for walls and separators: a frozen wall is absent from the preview exactly as it is absent from the room's `generate` (spec C1.5, Review Focus 5). **RT-frozen-wall runs in the kit**, not the integration package: a frozen object is made by the plan's failure boundary only (`kits/guard.dart:616-619`, `@internal`), and the kit half of Review Focus 5 is the tool's rule, which `FakePlanServices(frozen:)` and a system with `isFrozen` pin exactly; the plan's half (`liveTypeIdOf` null for a frozen object) is Task 6's LS-frozen. This is also ruling R-P1's placement: the case needs kit internals (`RoomTool`'s `debugPreview`, `RoomInputs`) and no plan widget.
- **The palette:** the Room tool is M, needs structure, components and geometry (today's commit, `room_tool.dart:235-239`), and sits right before the Separator tool (today's palette order, `planner_shell.dart:580-594`). Its icon is `Icons.meeting_room_outlined` (today's palette has text rows only; 2a's palette needs an `IconData`).

- [ ] **Step 1: Precondition.** Task 18 is committed (`git log --oneline -1` names it). Run `cd packages/jet_cad_2d_kit_architecture && flutter analyze` and `cd packages/jet_cad_2d_integration && flutter analyze`: `No issues found!` each.

- [ ] **Step 2: The failing kit tests (ported).** Create `packages/jet_cad_2d_kit_architecture/test/room/room_tool_test.dart` from `packages/jet_cad_floor_plan/test/room_tool_test.dart`; **assertions unchanged**:
  - Lines 1-13 (header) unchanged, then `// Ported from jet_cad_floor_plan/test/room_tool_test.dart; assertions unchanged. TT1's shell half, TT7 and SG1 run in jet_cad_2d_integration (spec 3a C7).`
  - Imports (lines 14-35) become:

```dart
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_tool.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';
```

    (`RoomParams`, `WallParams`, `Justification`, `ArchitectureTools`, `architectureKit` come from the barrel; `unused_import` and `unnecessary_import` fail `flutter analyze`, so the analyzer is the check.)
  - Lines 38-164 (the tool's helpers) unchanged, except `roomRig` (`:43-67`, its doc comment included) and `rooms` (`:87-88`), which become:

```dart
/// A Room tool over [doc], made by the kit's own tool (roomPlanTool) over
/// a FakePlanServices: a camera at [scale] pixels per mm (1 gives a 10 mm
/// aperture), object snap on, no page (no grid), the kit's words in
/// [locale] (today's `strings`) with [names] first when given, and
/// [frozen] frozen. Its inputs are the kit's shared RoomInputs.
Rig roomRig(DraftDocument doc,
    {double scale = 1,
    Locale locale = const Locale('en'),
    KitNames? names,
    Set<Handle> frozen = const {}}) {
  final services = FakePlanServices(
      document: doc,
      catalog: testCatalog(),
      scale: scale,
      locale: locale,
      names: names == null
          ? architectureKit.names
          : names.merge(architectureKit.names),
      frozen: frozen);
  final selection = SelectionController(doc);
  final tool = roomPlanTool.create(services) as RoomTool;
  addTearDown(() {
    tool.dispose();
    selection.dispose();
    services.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc,
        index: services.index,
        camera: services.camera,
        selection: selection),
    inputs: roomInputsOf(services),
  );
}
```

```dart
/// Every live room, ascending (the engine's rule over the test catalog).
List<Handle> rooms(DraftDocument doc) =>
    testCatalog().objectsOf<RoomParams>(doc);
```

  - Lines 165-218 (the shell's helpers) are not copied.
  - The cases, in today's order: TT1 lines 221-260, as `test(...)` (not `testWidgets`), named `'TT1 M places one room with one click, one undo step, named Room 1, seeded at the raw point; the tool stays active and Esc returns to Select (the tool)'`, its callback `(tester) async {` (`:224`) becoming `() {` (the half awaits nothing), closing with `});` after `:260`; TT2 `:290-421`, TT3 `:422-477`, TT4 `:479-503`, TT4b `:505-526`, TT5 `:528-554`, TT6 `:556-735`, TT8 `:776-885`, TT9 `:887-927` (TT10, `:929-1008`, is Task 20's: it needs the dimension).
  - In those cases: `.notice.value` → `.occupied.value` at `:258`, `:454`, `:459`, `:475`, `:906`, `:910`, `:916`; `:519` `roomRig(doc, strings: const FloorPlanStringsDe())` → `roomRig(doc, locale: const Locale('de'))`; `:523` `strings: const FloorPlanStringsTr()` → `locale: const Locale('tr')`. (TT10's own lines `:982`, `:996`, `:1005` are adapted in Task 20.)
  - Non-ASCII literals (`'m²'`, the `—` of TT1's reason strings are not in the kit half): check `grep -c "m²"` against the source's kit cases.

- [ ] **Step 3: The failing kit tests (new).** Append to `main` of `test/room/room_tool_test.dart`:

```dart
  test(
      'RT-notice the Room tool says "already a room" as a word id and the '
      'room\'s name, never as words; off the face and on cancel it says '
      'nothing (spec 3a C1.2; M-RT-1, M-RT-2)', () {
    final plan = buildPlan(boxWalls, place: corpusGroups);
    final doc = plan.doc;
    addRoom(doc, plan.at(1500.25, 2000.5), 'Pantry');
    final rig = roomRig(doc, locale: const Locale('de'));
    expect(rig.tool, isA<ToolNotice>());
    expect(rig.tool.notice.value, isNull);
    final inFace = plan.at(6000.75, 1200.5);
    hoverTo(rig, inFace);
    expect(rig.tool.occupied.value, const RoomOccupied('Pantry'));
    expect(rig.tool.notice.value,
        const KitText(kRoomOccupiedText, {'name': 'Pantry'}),
        reason: 'a word id and its argument, whatever the language');
    expect(kRoomOccupiedText, 'text:architecture.room-occupied');
    hoverTo(rig, plan.at(-2000.5, 2000.25));
    expect(rig.tool.notice.value, isNull, reason: 'off the face');
    expect(rig.tool.occupied.value, isNull);
    hoverTo(rig, inFace);
    expect(rig.tool.notice.value, isNotNull, reason: 'premise');
    rig.tool.cancel(rig.ctx);
    expect(rig.tool.notice.value, isNull, reason: 'cancelled');
    expect(rig.tool.occupied.value, isNull);
  });

  test(
      'RT-words a new room is named in the words of the moment, a host\'s '
      'word included, its n counted over those words and every locale the '
      'kit ships (spec 3a C1.6; M-RT-4, M-RT-5)', () {
    final plan = samplePlan(corpusGroups);
    final doc = plan.doc;
    Vector2 at(String name) {
      final (x, y) = sampleSeeds[name]!;
      return plan.at(x, y);
    }

    // The host names rooms `Space n` in English; the kit's Turkish is
    // `Oda n`. Space 1 is taken in the host's words, Oda 2 in the kit's
    // Turkish: the next is Space 3.
    addRoom(doc, at('Hall'), 'Space 1');
    addRoom(doc, at('Bedroom 1'), 'Oda 2');
    const host = KitNames({
      'en': {kRoomNameText: 'Space {n}'},
    });
    expect(kRoomNameText, 'text:architecture.room-name');
    final before = rooms(doc);
    pressAt(roomRig(doc, names: host), at('Bath'));
    expect(doc.components.get<RoomParams>(addedRoom(doc, before))!.name,
        'Space 3');
  });

  test(
      'RT-tool the Room tool is M, needs structure, components and geometry, '
      'sits right before the Separator tool, and makes a RoomTool over the '
      'kit\'s shared inputs (M-RT-8, M-RT-9)', () {
    expect(roomPlanTool.id, ArchitectureTools.room);
    expect(roomPlanTool.letter, 'M');
    expect(roomPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(roomPlanTool.settings, isNull);
    final ids = [for (final t in architectureKit.tools) t.id];
    expect(ids.indexOf(ArchitectureTools.room),
        ids.indexOf(ArchitectureTools.separator) - 1);
    final plan = buildPlan(boxWalls);
    final services =
        FakePlanServices(document: plan.doc, catalog: testCatalog());
    addTearDown(services.dispose);
    final tool = roomPlanTool.create(services) as RoomTool;
    addTearDown(tool.dispose);
    expect(tool.inputs, same(roomInputsOf(services)));
  });

  test(
      'RT-frozen-wall beside a frozen wall the Room tool\'s preview and the '
      'room it makes agree: both ignore it (Review Focus 5; M-RT-6)', () {
    // The two-room box at the corpus far origin, every wall in its own
    // turned group, the partition frozen (spec 2a E2): in no survey, so no
    // room reads it, and no input to the tool. The seed's face is the whole
    // box: 7,800 × 3,800 = 29,640,000 ("29.64 m²", 0.005 from a tie).
    final plan = buildPlan(twoRoomWalls, place: corpusGroups);
    final doc = plan.doc;
    final frozen = {plan.walls[4]};
    plan.system.dispose();
    final system =
        ParametricSystem(doc, testCatalog(), isFrozen: frozen.contains)
          ..install();
    addTearDown(system.dispose);
    final rig = roomRig(doc, frozen: frozen);
    final seed = plan.at(1500.25, 2000.5);
    hoverTo(rig, seed);
    final preview = ringOf(rig.tool.debugPreview.single);
    expectRing(plan, preview,
        const [(100, 100), (7900, 100), (7900, 3900), (100, 3900)],
        'the preview: the whole box');
    pressAt(rig, seed);
    final room = rooms(doc).single;
    expect(labelStrings(doc, room), ['Room 1', '29.64 m²']);
    expectSameRing(worldTintOf(doc, room), preview,
        'the room\'s tint is the preview');

    // The control: nothing frozen, both see the partition: the left face,
    // 2,850 × 3,800 = 10,830,000 ("10.83 m²").
    final live = buildPlan(twoRoomWalls, place: corpusGroups);
    final lrig = roomRig(live.doc);
    final lseed = live.at(1500.25, 2000.5);
    hoverTo(lrig, lseed);
    final lpreview = ringOf(lrig.tool.debugPreview.single);
    expectRing(live, lpreview,
        const [(100, 100), (2950, 100), (2950, 3900), (100, 3900)],
        'the control\'s preview: the left face');
    pressAt(lrig, lseed);
    final lroom = rooms(live.doc).single;
    expect(labelStrings(live.doc, lroom), ['Room 1', '10.83 m²']);
    expectSameRing(worldTintOf(live.doc, lroom), lpreview, 'the control');
  });
```

- [ ] **Step 4: Run the kit's tests, expecting failure.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/room/room_tool_test.dart`. Expected: compile errors, `Target of URI doesn't exist: 'package:jet_cad_2d_kit_architecture/src/room/room_tool.dart'`, `Undefined name 'roomPlanTool'`. Quote them.

- [ ] **Step 5: The tool.** Create `lib/src/room/room_tool.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/room_tool.dart` lines 1-443**, with these adaptations (every other line unchanged):
  - A header before line 1:

```dart
// The Room tool (spec 3a C3.5): ported from jet_cad_floor_plan's
// parametric/room_tool.dart. Its notice is a value the plan words when the
// status line is read (spec 3a C1.2: ToolNotice, a KitText); a new room's
// numbered name is the kit's `text:` word (spec 3a C1.6); which rooms,
// walls and separators are live is the plan's rule (spec 3a C1.5).
```

  - Lines 5-18, the imports, become:

```dart
import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, immutable, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitText, KitWords, ToolNotice, fillText, numberedNameIndex;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import '../words/words.dart' show architectureNames;
import 'room.dart';
import 'room_inputs.dart';
import 'room_trace.dart';
```

  - After line 30 (`_Verdict`'s closing brace), add:

```dart
/// A new room's name (spec 3a C1.6): `{n}` its number.
const String kRoomNameText = 'text:architecture.room-name';

/// The Room tool's notice (spec 3a C1.2): `{name}` the room the hovered
/// face already holds.
const String kRoomOccupiedText = 'text:architecture.room-occupied';
```

  - Inside `RoomOccupied`, after `final String name;` (line 38):

```dart

  /// This notice as the status line words it, when it reads it (spec 3a
  /// C1.2; spec 14d L5: `Already a room: <name>`).
  KitText get text => KitText(kRoomOccupiedText, {'name': name});
```

  - Class doc, lines 58-59: `([_verdictAt]), over the shell's [RoomInputs] (Ruling 10-11):` → `([_verdictAt]), over the kit's shared [RoomInputs] ([roomInputsOf]; Ruling 10-11):`; lines 87-88: `seed. No room, no preview, and the click does nothing; [notice] names / the lowest-handle such room.` → `seed. No room, no preview, and the click does nothing; [occupied] names / the lowest-handle such room and [notice] says so.`; line 90: `the next free `Room N`,` → `the next free numbered name (`kRoomNameText`),`.
  - Lines 109-121 and 131-132 (the declaration, the constructor, `inputs`, `strings`, `_english`, `_notice`) become:

```dart
class RoomTool extends PlacementTool implements ToolNotice {
  RoomTool(this.inputs, {required this.words, required this.live}) {
    _changes = inputs.document.changes.listen((_) => _onDocumentChange());
  }

  /// The kit's document adapter ([roomInputsOf]), shared with the Separator
  /// tool and the separator grips (Ruling 10-11). The tool never disposes
  /// it.
  final RoomInputs inputs;

  /// The kit's words of the moment (the plan's locale, a host's words
  /// first), read when a room is named (spec 14d L7).
  final KitWords words;

  /// The plan's live rule (spec 3a C1.5): the rooms that occupy a face and
  /// whose names are taken.
  final LiveTypeOf live;
```

    and, where `_notice` was (lines 131-132):

```dart
  final ValueNotifier<RoomOccupied?> _occupiedNotice =
      ValueNotifier<RoomOccupied?>(null);
  final ValueNotifier<KitText?> _notice = ValueNotifier<KitText?>(null);
```

  - Lines 180-184 (`notice`) become:

```dart
  /// The room the hovered face already holds, and after a click there
  /// (decision 26, R-29); null otherwise, and cleared when the tool
  /// deactivates.
  ValueListenable<RoomOccupied?> get occupied => _occupiedNotice;

  /// [occupied] as the status line says it (spec 3a C1.2): a word id and
  /// the room's name, put into words when the line is read, so a language
  /// switch re-words it at once.
  @override
  ValueListenable<KitText?> get notice => _notice;
```

  - Lines 251-256 (`_show`) become:

```dart
  void _show(_Verdict verdict) {
    _preview = verdict == _Verdict.room ? _facePreview : const [];
    _setOccupied(verdict == _Verdict.occupied ? _occupied : null);
  }

  /// [occupied] and [notice], together; nothing once disposed.
  void _setOccupied(RoomOccupied? room) {
    if (_disposed) return;
    _occupiedNotice.value = room;
    _notice.value = room?.text;
  }
```

  - Line 304 (`_cacheFace`): `for (final h in liveObjectsOf<RoomParams>(doc)) {` → `for (final h in _liveRooms(doc)) {`.
  - Lines 374-393 (`_nextName`) become:

```dart
  /// A name the Room tool gives (spec 10 D19, spec 14d L7, spec 3a C1.6):
  /// the kit's numbered name ([kRoomNameText]) in the words of the moment,
  /// `n` the smallest positive integer no live room's name takes in those
  /// words or in any locale the kit ships (today's rule: the current
  /// language and every built-in one).
  String _nextName(DraftDocument doc) {
    final patterns = _namePatterns();
    final used = <int>{
      for (final h in _liveRooms(doc))
        if (numberedNameIndex(
                doc.components.get<RoomParams>(h)!.name, patterns)
            case final n?)
          n,
    };
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return words.text(kRoomNameText, {'n': n});
  }

  /// One numbered-name pattern per locale (spec 3a C1.6): the words of the
  /// moment first (a host's word for the current locale included), then
  /// each locale of the kit's own words.
  List<String Function(int n)> _namePatterns() => [
        (n) => words.text(kRoomNameText, {'n': n}),
        for (final locale in architectureNames.words.values)
          if (locale[kRoomNameText] case final template?)
            (n) => fillText(template, {'n': n}),
      ];

  /// Every live room of [doc], ascending by handle (today's
  /// `liveObjectsOf<RoomParams>`, asked of the plan's live rule).
  List<Handle> _liveRooms(DraftDocument doc) => [
        for (final h in doc.components.withComponent<RoomParams>())
          if (live(h) == ArchitectureTypes.room) h,
      ];
```

  - Line 399 (`_onDocumentChange`): `_notice.value == null` → `_occupiedNotice.value == null`.
  - Line 411 (`cancel`): `if (!_disposed) _notice.value = null;` → `_setOccupied(null);`.
  - Line 421 (`dispose`): `_notice.dispose();` → `_occupiedNotice.dispose();` and `_notice.dispose();`.

- [ ] **Step 6: The tool's declaration.** In `lib/src/room/room_plan.dart` add `import 'package:flutter/material.dart' show Icons;`, `import '../live.dart';`, `import 'room_inputs.dart';`, `import 'room_tool.dart';`, extend the header's last sentence ("Task 19 adds the Room tool.") to "The Room tool is [roomPlanTool].", and append:

```dart
/// The Room tool (spec 3a C3.5): M. One click inside a face commits one
/// room, named with the next free numbered name, in one undo step
/// (structure, components and geometry: today's commit); its notice is
/// "already a room" (spec 3a C1.2). Its inputs are the kit's shared
/// RoomInputs, its live rule the plan's.
final PlanTool roomPlanTool = PlanTool(
  id: ArchitectureTools.room,
  icon: Icons.meeting_room_outlined,
  letter: 'M',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) =>
      RoomTool(roomInputsOf(s), words: s.words, live: liveTypesOf(s)),
);
```

  In `lib/src/kit.dart`: `roomPlanTool` joins `tools` immediately before `separatorPlanTool` (today's palette order: ... gap, room, separator, dimension).

- [ ] **Step 7: Run the kit's tests.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` (TT6 prints its timing line: quote it, it is not asserted).

- [ ] **Step 8: The integration tests.** Create `packages/jet_cad_2d_integration/test/room/room_tool_test.dart`:

```dart
// Spec 3a C6, C1.2: the Room tool in the plan library's editor. TT1's
// shell half, TT7 and SG1 are ported from jet_cad_floor_plan/test/
// room_tool_test.dart (spec 10 D19, decision 26, R-29, X15-guardMS),
// assertions unchanged: the status line composes the tool's label and its
// notice as today ('Room — Already a room: Room 1'). RT-notice-locale is
// Review Focus 2: a language switch re-words a notice already shown, at
// once, the room's name kept.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_plans.dart';

/// Today's `shellSamplePlan` (room_tool_test.dart:213-218): the sample
/// plan's walls, column, separator and openings at the origin, with
/// [rooms].
RoomPlan sampleRoomPlan({List<R> rooms = const []}) =>
    roomPlan([...sampleWalls(), sampleColumn],
        seps: const [sampleSeparator],
        openings: sampleOpenings,
        rooms: rooms);

void main() {
  testWidgets(
      'TT1 M places one room with one click, one undo step, named Room 1, '
      'seeded at the raw point; the tool stays active and Esc returns to '
      'Select (the editor)', (tester) async {
    // The editor: M and the palette entry both activate the tool, a click
    // places a room, the tool stays active, and Esc returns to Select.
    final shell = sampleRoomPlan();
    await pumpEditor(tester, shell.c,
        centre: shell.at(20000, 10500), scale: 0.12);
    final sdoc = shell.doc;
    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('tool-architecture.room')));
    await tester.pump();
    expect(status(tester), 'Room');
    final sdepth = sdoc.commands.undoDepth;
    await clickAt(tester, shell.c, shell.at(18500.5, 9750.25));
    final kitchen = rooms(sdoc).single;
    expect(sdoc.commands.undoDepth, sdepth + 1);
    // The Kitchen: x 17,060-21,440, y 8,250-11,440: 4,380 × 3,190 =
    // 13,972,200 mm², 13.97 m² (0.0022 from a tie).
    expect(labelStrings(sdoc, kitchen), ['Room 1', '13.97 m²']);
    expect(status(tester), 'Room — Already a room: Room 1',
        reason: 'the tool stays active, over the face it just filled');
    await undoKey(tester);
    expect(rooms(sdoc), isEmpty);
    expect(status(tester), 'Room', reason: 'the face is free again');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'TT7 a click in an occupied face places nothing and the status line '
      'says so; hovering there shows it; it clears on leaving the face and '
      'on deactivation', (tester) async {
    final plan = sampleRoomPlan(rooms: const [
      (x: 19000, y: 10000, name: 'Kitchen', label: null, at: null),
    ]);
    await pumpEditor(tester, plan.c,
        centre: plan.at(20000, 10500), scale: 0.12);
    final doc = plan.doc;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    Future<void> hover(double x, double y) async {
      await mouse.moveTo(globalAt(tester, plan.c, plan.at(x, y)));
      await tester.pump();
    }

    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
    await hover(20500.5, 9000.25);
    expect(status(tester), 'Room — Already a room: Kitchen',
        reason: 'hovering the occupied face');
    final before = rooms(doc);
    final depth = doc.commands.undoDepth;
    await clickAt(tester, plan.c, plan.at(18200.5, 10800.25));
    expect(rooms(doc), before, reason: 'nothing placed');
    expect(doc.commands.undoDepth, depth);
    expect(status(tester), 'Room — Already a room: Kitchen',
        reason: 'after a click there');
    // The Bath: a face with no room.
    await hover(23500.5, 10000.25);
    expect(status(tester), 'Room', reason: 'cleared on leaving the face');
    await hover(19000.5, 10500.25);
    expect(status(tester), 'Room — Already a room: Kitchen');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select', reason: 'cleared on deactivation');
    expect(plan.c.toolNotice.value, isNull);
    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
  });

  testWidgets(
      'SG1 M and S typed into a text entry switch no tool (the shell\'s '
      'guard, X15-guardMS)', (tester) async {
    final plan = roomPlan(boxWalls);
    await pumpEditor(tester, plan.c);
    await press(tester, LogicalKeyboardKey.keyT);
    expect(status(tester), 'Text');
    await tester.tapAt(globalAt(tester, plan.c, Vector2(2000.5, 2000.25)));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    for (final k in [LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyS]) {
      await press(tester, k);
      expect(status(tester), 'Text', reason: '$k switched no tool');
      expect(find.byKey(const Key('text-entry')), findsOneWidget);
    }
  });

  testWidgets(
      'RT-notice-locale a language switch re-words the Room tool\'s notice '
      'at once, in the new language, the room\'s name kept (Review Focus 2; '
      'M-RT-3)', (tester) async {
    final plan = roomPlan(boxWalls, place: corpusGroups, rooms: const [
      (x: 1500.25, y: 2000.5, name: 'Kitchen', label: null, at: null),
    ]);
    await pumpEditor(tester, plan.c,
        centre: plan.at(4000, 2000), scale: 0.15);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await press(tester, LogicalKeyboardKey.keyM);
    await mouse.moveTo(globalAt(tester, plan.c, plan.at(6000.75, 1200.5)));
    await tester.pump();
    expect(status(tester), 'Room — Already a room: Kitchen');
    expect(plan.c.toolNotice.value?.id, 'text:architecture.room-occupied');
    expect(plan.c.toolNotice.value?.args, {'name': 'Kitchen'});
    // The language turns, the pointer stays: the line re-words at once.
    for (final (locale, line) in const [
      (Locale('de'), 'Raum — Bereits ein Raum: Kitchen'),
      (Locale('tr'), 'Oda — Zaten bir oda: Kitchen'),
      (Locale('en'), 'Room — Already a room: Kitchen'),
    ]) {
      await tester.pumpWidget(planEditorApp(plan.c, locale: locale));
      await tester.pump();
      expect(status(tester), line, reason: '$locale');
    }
  });
}
```

  `TT1 (the editor)` keeps today's lines 262-288 with the mapping of Task 18 Step 10 (`pumpPlan(tester, shell)` → `pumpEditor(tester, shell.c, centre: shell.at(20000, 10500), scale: 0.12)`: a fixture change, since a plan library's new plan carries the default page, A4 at 1:50 centred on the world origin (`new_plan.dart:13-18`), and the canvas fits that page on its first frame (`plan_canvas_view.dart:272-284`), which leaves the sample flat (x 12,000-26,000) off the screen, where today's shell had no page and fit the plan's extents; every click is by world point, so no assertion depends on the camera. TT7 takes the same camera, RT-notice-locale one on its own plan at the corpus far origin; SG1's box at the origin lies on the page and keeps the fit. `view.document` → `shell.doc`, `clickAt(tester, view, p)` → `clickAt(tester, shell.c, p)`) and `Key('tool-room')` → `Key('tool-architecture.room')` (the plan palette's row key, `plan_tool_palette.dart:108`; C7 class 3). `TT7` keeps lines 737-774: today's `shellSamplePlan()` plus `addRoom(plan.doc, plan.at(19000, 10000), 'Kitchen')` is `sampleRoomPlan(rooms: [...])`; `screenOf(tester, view, p)` → `globalAt(tester, plan.c, p)`; `shellRoomTool(tester).notice.value` (`:771`, the shell's Room tool found through its palette entry) → `plan.c.toolNotice.value` (the active tool's notice, Task 4: the closest public read; the tool's own clearing on cancel is RT-notice's). `SG1` keeps lines 1010-1027: `buildPlan(boxWalls, measurer: FlutterTextMeasurer())` and `pumpPlan` → `roomPlan(boxWalls)` and `pumpEditor`; the tap through `view.camera` and `InteractionLayer` → `globalAt(tester, plan.c, ...)`. Check the em dashes: `grep -c "—" packages/jet_cad_2d_integration/test/room/room_tool_test.dart` (9 here, one per line: 1 in the header comment, 4 in TT1/TT7's lines and 4 in RT-notice-locale's; the byte is U+2014 as in the source).

- [ ] **Step 9: Run the integration tests.** `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice test/room/room_tool_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 10: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `git status --short` — only this task's files.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/room/room_tool.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/test/room/room_tool_test.dart packages/jet_cad_2d_integration/test/room/room_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the Room tool and its notice

Ports the Room tool from jet_cad_floor_plan (spec 3a C3.5) as the kit's
M tool. Its "already a room" notice is a word id and the room's name,
which the plan words when the status line is read (spec 3a C1.2), so a
language switch re-words it at once; a new room's numbered name is the
kit's text: word, counted over the words of the moment and every locale
the kit ships (C1.6); and the tool reads the plan's live rule, so its
preview and the room it makes both ignore a frozen wall (C1.5). The
tool's tests come with it, assertions unchanged; its editor cases run in
the integration package.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit: `cd packages/jet_cad_2d_kit_architecture && flutter test test/room/room_tool_test.dart`; integration: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/room/room_tool_test.dart`. Quote each red line.
  - M-RT-1 `lib/src/room/room_tool.dart`: in `RoomOccupied.text`, `{'name': name}` → `{'n': name}` → RT-notice red; integration RT-notice-locale and TT7 red (the line shows `{name}`).
  - M-RT-2 `room_tool.dart`: delete `_notice.value = room?.text;` from `_setOccupied` → RT-notice red; integration TT1 (the editor) red.
  - M-RT-3 `room_tool.dart`: in `_setOccupied`, `_notice.value = room?.text;` → `_notice.value = room == null ? null : KitText(words.text(kRoomOccupiedText, {'name': room.name}));` (the words frozen when the notice is set) → integration RT-notice-locale red (the German line keeps the English words), and RT-notice red.
  - M-RT-4 `room_tool.dart`: delete the first element of `_namePatterns` (`(n) => words.text(kRoomNameText, {'n': n}),`) → RT-words red (`'Space 1'`).
  - M-RT-5 `room_tool.dart`: delete `_namePatterns`' `for` element → RT-words red (`'Space 2'`) and TT4b red.
  - M-RT-6 `lib/src/room/room_inputs.dart`: in `_refresh`, `_live<WallParams>(ArchitectureTypes.wall)` → `document.components.withComponent<WallParams>()` → RT-frozen-wall red (the preview is the left face, the room the whole box).
  - (M-RT-7, whose red test is TT10, runs in Task 20.)
  - M-RT-8 `room_plan.dart`: `letter: 'M'` → `letter: 'Q'` → RT-tool red; integration TT1 (the editor) red (M activates nothing).
  - M-RT-9 `lib/src/kit.dart`: move `roomPlanTool` after `separatorPlanTool` in `tools` → RT-tool red.
  - (M-RT-10, whose red test is TT10, runs in Task 20.)
  - M-RT-11 `room_tool.dart`: in `cancel`, `_setOccupied(null);` → delete → RT-notice red (cancelled) and integration TT7 red (`'Room — Already a room: Kitchen'` after M again).

#### Assumed from earlier tasks

- Task 3: `KitNamesWords.text` fills `{n}` with `'$n'` (`fillText`: `'{name}'` → `'${args['name']}'`), so `'Room {n}'` with `{'n': 3}` is today's `roomName(3)`, `'Room 3'`.
- Task 4: `PlanController.toolNotice` is the active tool's guarded notice (null for a tool that is not a `ToolNotice`, such as the select tool); `PlanEditor`'s status line is `label`, then ` — ` and the notice in the current language.
- Task 6: `FakePlanServices`' words are a `KitNamesWords` over `names` at `locale`.
- Task 9: `architectureNames.words` holds `en`, `de` and `tr`, each with `text:architecture.room-name` and `text:architecture.room-occupied` (today's `roomName`, `roomOccupied` in each language, with `{n}` and `{name}`); `planEditorApp(controller, locale:)` reports its locale to the controller (the editor's own `reportLocale`), so a re-pump in another locale re-words the line.
- Task 18: `room_plans.dart`'s `clickAt` taps at the default pointer kind (today's shell `clickAt`, `room_tool_test.dart:186-189`).

---

