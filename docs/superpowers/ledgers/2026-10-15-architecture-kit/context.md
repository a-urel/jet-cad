# 3a context every implementer and reviewer reads (from the plan)

## Global Constraints

- **Names.** Dart type names carry no `2d`. Every name in "Shared interfaces" below is binding; a task that cannot use one reports an interface problem instead of inventing another.
- **Versions.** `jet_cad_2d_kit_architecture` is created at `0.1.0`; `jet_cad_2d_integration` has `publish_to: none` and version `0.0.0`. No other package version changes (`jet_cad_2d_kit` `0.1.0`, `jet_cad_2d_plan` `0.8.0`, both unreleased). CHANGELOGs gain their 3a additions in their existing unreleased sections; the kit's starts with `## 0.1.0 (unreleased)`.
- **Dependencies.**
  - `jet_cad_2d_kit_architecture` depends on `flutter`, `jet_cad_2d: ^0.7.2`, `jet_cad_2d_flutter: ^0.7.2` and `jet_cad_2d_kit: ^0.1.0`, and on nothing else at runtime (the floors are the plan library's; sub-project 4 raises them all, spec C2). It never names `jet_cad_2d_plan` or another kit in its pubspec or any Dart file, `test/` included (`tool/ci/check_kit_deps.dart`).
  - `jet_cad_2d_integration` depends on `jet_cad_2d_plan` and `jet_cad_2d_kit_architecture` (and what they export), dev `flutter_test` and `vm_service: ^15.2.0`; it imports their **public libraries only** (no `package:<pkg>/src/...`: `implementation_imports`).
  - `jet_cad_2d_kit` never depends on `jet_cad_2d_plan` or a kit. `jet_cad_2d_plan` never depends on a kit, `jet_cad_floor_plan` or `jet_cad_restaurant_symbols`.
- **The old packages are untouched** (A12). No change under `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `packages/jet_cad_2d_gpu`, `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter` or `apps/`. Logic and tests from `jet_cad_floor_plan` and `apps/floor_planner` are **ported by copying and adapting**, never imported.
- **Ported tests keep their assertions** (A12). Fixtures, names, ids and imports may change. The spec's C7 lists the known classes of change (ids; tags to fields; widgets that changed form), the tests not ported (premise impossible) and the tests dropped on the human's word; any other assertion that must change is a finding: stop and report it.
- **Where a ported test runs** (spec C7): in the kit when every name it uses is the kit's, the contract's, the engine's or the Flutter layer's (with `FakePlanServices` for tools and grips); in `jet_cad_2d_integration` when it uses a plan-library name. A file may split by case; each split is listed in the task.
- **Today's code is the oracle** for every "today" in the spec (A12): `packages/jet_cad_floor_plan` and `apps/floor_planner`.
- **Non-negotiables (CLAUDE.md):** the frame path allocates nothing per entity in steady state; draw order is ascending handle value; geometric decisions use `Tolerance`, stored-value comparisons are exact `==`.
- **`analysis_options.yaml`.** Never stage an existing one: `flutter pub get` rewrites three of them in this workspace; restore a rewritten one with `git checkout -- <file>`. **Plan decision (the human left it to the controller, 2026-10-15: *"kararları sana bırakıyorum"*; the controller kept 2a's precedent):** each new package's `analysis_options.yaml` is created and committed **once**, in Task 9, by explicit path, copied from `packages/jet_cad_2d_plan/analysis_options.yaml`, as sub-project 1 and 2a did for theirs (the human's *"Bir kez commit edilsin"*).
- **Stage files by explicit path only.** Never `git add -A` or `git add .`. Run `git status --short` after every pub operation.
- **Never synthesize test output.** Quote what commands print; reviewers re-run every claim.
- **Mutations.** Run them on committed files only, and revert each with `git checkout -- <file>`; then `git diff --quiet -- <file>` must exit 0. **In every task, run the Commit step before the Mutation step.** Never restore from a `/tmp` copy, and never `git checkout --` a file with uncommitted work.
- **Language and commits.** Code, comments and commit messages are in English. Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Never run `dart pub publish` without `--dry-run`, and never push, tag or merge.** The human does all of these.
- **Every task ends green.** Run the gates of every package the task touched:
  - `cd packages/<pkg> && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`;
  - `jet_cad_2d_plan` and `jet_cad_2d_integration`: `flutter test --enable-vmservice` (their allocation tests need it);
  - plus `cd tool/ci && dart test` when `tool/ci` or `.github/` changed, and `dart run tool/ci/check_kit_deps.dart` (from the repository root) when a pubspec, `jet_cad_2d_kit` or the kit changed.

  The packages' language version is 3.6, so `dart format` uses the short style: run `dart format .` before the gate. **Run the format gate locally, every time.**
- **Known environmental failures.** The engine's local hash tests and the renderer's goldens fail on clean `main` on this machine as well. Compare against `tool/ci/standing_failures.txt`; never "fix" them.
- **Non-ASCII literals.** A ported test's non-ASCII string (`'—'`, `' '`, `'²'`, Turkish and German words) is compared byte for byte with its source; the file tool may turn an escape into a literal character, so check with `grep -n` after writing (2b's lesson).
- **Testing bar (CLAUDE.md).**
  - Every new behaviour or refusal test names the mutation that turns it red. Positive controls and fixture-sanity tests are exempt.
  - Each task has a Mutation step: apply each named mutation, run the named test, see it red, revert.
  - Fixtures are not degenerate: walls off the origin and not axis-aligned, a turned and mirrored group, a page not at 1:1. A test standing at the identity alone does not count.
- **Integration tests frame what they click** (pre-flight finding). A new plan opens fitted to its default page (A4 1:50 at the origin); a test that clicks world points of a fixture elsewhere passes `pumpEditor(..., centre:, scale:)` so every click lands on the canvas. A click off the canvas is a fixture defect: fix the frame (a fixture change, A12), never the assertion.
- **Session limit.** Worktree-guarded sessions refuse bash loops and `$VAR` pipelines: run commands one by one.

## Review Focus

1. **A file whose separators lack the DASHED record, opened and saved.**
   - Expected: it opens unchanged and saves back byte-identical; its separators draw continuous; a new plan holds the record at handle 6.
   - Pinned in Task 5 (PB3-prepare-load), Task 9 (SC-prepare) and Task 17 (SP-dashed-open).
2. **The UI language switched while the Room tool says "already a room".**
   - Expected: the status line re-words the notice at once, in the new language, with the room's name; no stale English.
   - Pinned in Task 4 (TN-relocale) and Task 19 (RT-notice-locale).
3. **A wall-end grip dragged so the wall would fall below the join tolerance.**
   - Expected (today's, `wall_grips.dart:60-63, 198`; `grip_drag.dart:303-313`): the preview shows nothing at the refused point (`wall_grips.dart:137-138`, `grip_drag.dart:262-263`) and nothing is reported; a drop at the refused point commits nothing; the grips stay usable, and a later drag to an accepted point commits in one undo step.
   - Pinned in Task 7 (GR-drag-refuse) and Task 12 (WG-refuse-short).
4. **An opening's position typed past its host wall's length, and an opening whose host is not a wall.**
   - Expected: the field shows the stored value; no command, no diagnostic; for the non-wall host every value is refused.
   - Pinned in Task 2 (PO-range) and Task 14 (OT-panel-range).
5. **A room traced next to a frozen wall.**
   - Expected: the Room tool's preview and the room it creates agree (both ignore the frozen wall), and the frozen wall cannot be edited while a frozen object references it.
   - Pinned in Task 6 (LS-frozen) and Task 19 (RT-frozen-wall).

---

## File structure

```
packages/jet_cad_2d_kit/
  lib/jet_cad_2d_kit.dart            exports grow (Tasks 1-6)
  lib/authoring.dart                 exports grow (Task 1, 3)
  lib/testing.dart                   NEW: FakePlanServices (Task 6)
  lib/src/model/symbol_box.dart      NEW: moved from the plan (Task 1)
  lib/src/model/numbered_names.dart  NEW (Task 3)
  lib/src/model/kit_text.dart        NEW: KitText, fillText, placeholdersOf (Task 3)
  lib/src/model/plan_words.dart      NEW: PlanWords (Tasks 2, 3)
  lib/src/kit/properties.dart        PlanObject, TextDisplay, range, visible (Task 2)
  lib/src/kit/plan_type.dart         fieldsOf/commitField/sectionFor, PlanSection (Task 2)
  lib/src/kit/plan_services.dart     KitWords.text/decimalSeparator (Task 3), liveTypeIdOf (Task 6)
  lib/src/kit/plan_tool.dart         ToolNotice (Task 4)
  lib/src/kit/plan_kit.dart          prepare; validate: text:, settings displays (Tasks 2, 3, 5)
  lib/src/kit/plan_build.dart        NEW: PlanBuild (Task 5)
  lib/src/kit/host_words.dart        text: accepted (Task 3)
  lib/src/authoring/conformance.dart placeholder check (Task 3)
  lib/src/testing/fake_plan_services.dart  NEW (Task 6)

packages/jet_cad_2d_plan/
  lib/src/symbols/symbol_box.dart, symbol_placer.dart   moved names removed (Task 1)
  lib/src/tools/move_resolver.dart, panels/symbol_section.dart  isOrthonormal copies removed (Task 1)
  lib/src/panels/plan_property_panel.dart   TextDisplay row, visible, object (Task 2)
  lib/src/l10n/numbered_names.dart          over the contract's (Task 3)
  lib/src/kits/guard.dart                   GuardedTool.notice (Task 4), grips (Task 7)
  lib/src/editor/plan_editor.dart           status line (Task 4)
  lib/src/controller/plan_controller.dart   toolNotice, textOf (Task 4); build, prepare (Task 5)
  lib/src/controller/new_plan.dart          prepare (Task 5)
  lib/src/controller/services.dart          liveTypeIdOf, words (Tasks 3, 6)
  lib/src/kits/locks.dart                   frozen references (Task 7)
  lib/src/tools/<plan.select>               drop through controller.execute (Task 7)

packages/jet_cad_2d_kit_architecture/       NEW (Task 9 on)
  pubspec.yaml, analysis_options.yaml, LICENSE, README.md, CHANGELOG.md
  lib/jet_cad_2d_kit_architecture.dart
  lib/src/kit.dart                   architectureKit (Task 9, grows each type task)
  lib/src/ids.dart                   ArchitectureTypes, ArchitectureTools (Task 9)
  lib/src/live.dart                  LiveTypeOf, isLiveOf (Task 9)
  lib/src/words/{en,de,tr}.dart, words.dart   architectureNames (Task 9)
  lib/src/separator_linetype.dart    kDashedLinetypeRecord, ensureDashedLinetype, prepare (Task 9)
  lib/src/box/       box.dart, box_tool.dart, box_plan.dart                       (Task 10)
  lib/src/wall/      wall.dart, wall_geometry.dart, wall_bands.dart               (Task 11)
                     wall_grips.dart, wall_tool.dart, wall_plan.dart              (Task 12)
  lib/src/opening/   opening.dart, opening_geometry.dart                          (Task 13)
                     opening_grips.dart, opening_plan.dart                        (Task 14)
                     opening_tool.dart                                            (Task 15)
  lib/src/separator/ separator.dart                                               (Task 16)
                     separator_grips.dart, separator_tool.dart, separator_plan.dart (Task 17)
  lib/src/room/      room_trace.dart, room_inputs.dart, room_label.dart           (Task 16)
                     room.dart, room_grips.dart, room_plan.dart                   (Task 18)
                     room_tool.dart                                               (Task 19)
  lib/src/dimension/ dimension.dart, dimension_geometry.dart, dimension_attach.dart (Task 20)
                     dimension_grips.dart, dimension_plan.dart                    (Task 21)
                     dimension_tool.dart                                          (Task 22)
  lib/src/furniture/ furniture_catalog.dart, furniture_names.dart, furniture_source.dart (Task 23)
  lib/src/attach/    wall_attach.dart, wall_faces.dart, wall_face_provider.dart   (Task 24)
  lib/src/sample/    sample_flat.dart                                             (Task 25)
  tool/generate_furniture_library.dart, assets/library/furniture.jetlib,
  assets/library/furniture.snapshot.json                                         (Task 23)
  example/main.dart (Task 9), test/... (per task)

packages/jet_cad_2d_integration/            NEW (Task 9 on)
  pubspec.yaml, analysis_options.yaml, README.md
  lib/jet_cad_2d_integration.dart    fixtures (Task 9, grows)
  test/<area>/...                    per task

tool/ci/      check_kit_deps covers the new kit (Task 9); CI jobs in .github/workflows/ci.yml (Task 9)
pubspec.yaml  workspace members (Task 9)
```

## Shared interfaces

Binding. A task's **Produces** block repeats the names it creates; a later task's **Consumes** block cites them. The spec section is given for each.

### The contract (`jet_cad_2d_kit`)

```dart
// lib/src/model/symbol_box.dart (Task 1; C1.4) — moved unchanged from
// jet_cad_2d_plan/lib/src/symbols/{symbol_box,symbol_placer}.dart, pure Dart,
// exported by jet_cad_2d_kit.dart and authoring.dart.
final class SymbolBox { /* unchanged */ }
bool isOrthonormal(Transform2 g);
SymbolBox? boxOfLeaves(Iterable<(EntityKind, GeometryPayload)> leaves);
SymbolBox? boxOfEntry(SymbolEntry entry);
Aabb2 servedTopOfEntry(SymbolEntry entry);
SymbolBox? boxOfDefinition(DraftDocument doc, Handle definition);
Aabb2 footprintOf(SymbolBox box);
Transform2 placementTransform(/* today's parameters, unchanged */);

// lib/src/kit/properties.dart (Task 2; C1.1, C1.7)
abstract interface class PlanObject {
  DraftDocument get document;
  Handle get handle;
  Transform2 get world; // document.tree.accumulatedTransform(handle)
  PlanWords get words;   // the owning kit's words at the plan's locale (R-P4, R-P7)
}
final class DocumentPlanObject implements PlanObject {
  DocumentPlanObject(this.document, this.handle, this.words); // world computed on first read
}
sealed class PropertySpec<T> {
  final bool Function(T)? visible;                // NEW, every kind's constructor takes it
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit, PlanObject? object});
}
final class LengthProperty<T> extends PropertySpec<T> {
  // NEW named parameter; null result refuses every value
  final (double, double)? Function(T value, PlanObject object)? range;
}
final class TextDisplay<T> extends PropertySpec<T> {
  TextDisplay({required String id, required String? Function(T value, PlanObject object) read,
      bool Function(T)? enabled, bool Function(T)? visible, PlanGate? gate});
  // bound field: value is the String (null omits the row: PropertyField.visible false); commit null
}
abstract interface class PropertyField {
  bool get visible;                               // NEW: spec.visible(owner), and false for a
                                                  // TextDisplay reading null
}

// lib/src/kit/plan_type.dart (Task 2; C1.1)
typedef PropertySectionBuilder<T> = Widget Function(BuildContext context, PlanSection<T> section);
@immutable final class PlanSection<T> {
  const PlanSection({required this.value, required this.commit, required this.words,
      required this.object, required this.services});
  final T value; final void Function(T next) commit; final KitWords words;
  final PlanObject object; final PlanServices services;
}
// PlanType: the document parameter narrows from CommandTarget to DraftDocument
List<PropertyField> fieldsOf(DraftDocument document, Handle group, PlanWords words);
DraftCommand commitField(DraftDocument document, Handle group, PropertyField field, Object? input,
    PlanWords words);
Widget? sectionFor(BuildContext context, DraftDocument document, Handle group,
    void Function(DraftCommand) execute, KitWords words, PlanServices services);

// lib/src/model/kit_problem.dart (Tasks 2, 3)
enum KitProblemCode { /* existing */ settingsNeedObject, placeholderMismatch }

// lib/src/model/kit_text.dart (Task 3; C1.6, C1.2)
@immutable final class KitText {
  const KitText(this.id, [this.args = const {}]);
  final String id;                                // 'text:<kit>.<id>'
  final Map<String, Object> args;                 // == and hashCode by value
}
String fillText(String template, Map<String, Object> args); // '{name}' → '${args['name']}'; missing left as written
Set<String> placeholdersOf(String template);

// lib/src/model/plan_words.dart (Task 2 creates it with word, maybe; Task 3 adds text and
// decimalSeparator; pure, exported by both barrels; R-P7)
abstract interface class PlanWords {
  String word(String wordId); String? maybe(String wordId);
  String text(String id, [Map<String, Object> args = const {}]); // fillText over word(id)
  String get decimalSeparator;                                     // the UI language's
}
// lib/src/kit/plan_services.dart
abstract interface class KitWords implements PlanWords { Locale get locale; }
final class KitNamesWords implements KitWords {
  KitNamesWords(KitNames names, Locale Function() locale,
      {String Function()? decimalSeparator}); // NEW named parameter, default '.'
}

// lib/src/model/numbered_names.dart (Task 3; C1.6)
int? numberedNameIndex(String name, Iterable<String Function(int n)> patterns,
    {String Function(String)? fold});

// lib/src/kit/plan_tool.dart (Task 4; C1.2)
abstract interface class ToolNotice { ValueListenable<KitText?> get notice; }

// lib/src/kit/plan_build.dart (Task 5; C1.9)
typedef PlanBuild = void Function(DraftDocument document, KitWords words);

// lib/src/kit/plan_kit.dart (Task 5; C1.3)
// PlanKit gains: final void Function(DraftDocument document)? prepare;

// lib/src/kit/plan_services.dart (Task 6; C1.5)
// PlanServices gains: String? liveTypeIdOf(Handle handle);

// lib/testing.dart → lib/src/testing/fake_plan_services.dart (Task 6; C1.11)
final class FakePlanServices implements PlanServices {
  FakePlanServices({required DraftDocument document, ParametricCatalog? catalog,
      Set<Handle> frozen = const {}, double scale = 1, bool objectSnap = true,
      KitNames names = KitNames.empty, Locale locale = const Locale('en'),
      String decimalSeparator = '.', Map<String, Object> settings = const {},
      AttachmentRegistry? attachments});
  // liveTypeIdOf: catalog?.typeIdOf(document, h) unless h is in frozen; shared: one per T,
  // disposed by dispose(); settingsOf: settings[toolId]; symbolDefinition: null.
  void dispose();
}
```

### The plan library (`jet_cad_2d_plan`)

```dart
// Task 3: the KitWords the plan builds carry decimalSeparator from the current PlanStrings.
// Task 4 (C1.2)
// GuardedTool gains: ValueListenable<KitText?>? get notice;   (guarded; a throw → hookFailed, then null)
// PlanController gains:
ValueListenable<KitText?> get toolNotice;       // the active tool's notice
String textOf(KitText text);                    // host words first, then the kit named by the id, current locale
// PlanEditor's status line: label, then ' — ' + selectedCount(n) with a selection,
// then ' — ' + textOf(notice) with a notice.
// Task 5 (C1.3, C1.9)
factory PlanController({/* existing */, PlanBuild? build}); // build ignored with json
void newPlan({String? decimalSeparator, PlanBuild? build});
// build's KitWords: every loaded kit's names, host words first, the controller's locale.
// Task 7 (C1.8, C1.10): no new public names; LockSet locks the live references of frozen objects.
```

### The kit (`jet_cad_2d_kit_architecture`)

```dart
// lib/jet_cad_2d_kit_architecture.dart exports exactly:
//   architectureKit, ArchitectureTypes, ArchitectureTools, buildSampleFlat,
//   BoxParams, WallParams, Justification, OpeningParams, OpeningKind, HingeEnd, SwingSide,
//   SeparatorParams, RoomParams, DimensionParams, DimKind, DimEnd, AttachedEnd, FixedEnd, WallSide
final PlanKit architectureKit;                                  // lib/src/kit.dart (Task 9; grows)
abstract final class ArchitectureTypes {                        // lib/src/ids.dart (Task 9)
  static const box = 'architecture.box', wall = 'architecture.wall',
      opening = 'architecture.opening', separator = 'architecture.separator',
      room = 'architecture.room', dimension = 'architecture.dimension';
}
abstract final class ArchitectureTools {
  static const box = 'architecture.box', wall = 'architecture.wall', door = 'architecture.door',
      window = 'architecture.window', gap = 'architecture.gap', room = 'architecture.room',
      separator = 'architecture.separator', dimension = 'architecture.dimension';
}
void buildSampleFlat(DraftDocument document, KitWords words);  // a PlanBuild (Task 25)

// Internal, shared across tasks (lib/src/...):
typedef LiveTypeOf = String? Function(Handle handle);           // live.dart (Task 9)
LiveTypeOf liveTypesOf(PlanServices services);                  // services.liveTypeIdOf
WallBands wallBandsOf(PlanServices s);    // s.shared(...) — wall/wall_bands.dart (Task 11)
RoomInputs roomInputsOf(PlanServices s);  // room/room_inputs.dart (Task 16)
WallFaces wallFacesOf(PlanServices s);    // attach/wall_faces.dart (Task 24)
// Each type task exports from its *_plan.dart one PlanType and its PlanTool(s):
//   boxPlanType, boxPlanTool (Task 10); wallPlanType, wallPlanTool (Task 12);
//   openingPlanType (Task 14); doorPlanTool, windowPlanTool, gapPlanTool (Task 15);
//   separatorPlanType, separatorPlanTool (Task 17); roomPlanType (Task 18); roomPlanTool (Task 19);
//   dimensionPlanType (Task 21); dimensionPlanTool (Task 22).
AttachmentProvider wallFaceProvider(PlanServices services);    // attach/wall_face_provider.dart (Task 24)
const String kFurnitureAsset = 'packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib';
final SymbolLibrarySource furnitureSource;                       // furniture/furniture_source.dart (Task 23)
void ensureDashedLinetype(DraftDocument doc);                    // separator_linetype.dart (Task 9)
```

Today's class and function names inside the moved files are kept (`WallParams`, `WallType`, `WallBands`, `WorldWall`, `OpeningGeometry`'s `hostFrameOf`, `traceRoom`, `RoomInputs`, `DimensionGrips`, `attachToWall`, `WallFaces`, ...); only their `floor_planner.` ids and their reads of the global catalog change.

**Word ids** (Task 9 writes all three locales; later tasks use them):

| Kind | Ids |
|---|---|
| Tools | `tool:architecture.{box,wall,door,window,gap,room,separator,dimension}` |
| Types | `type:architecture.{box,wall,opening,separator,room,dimension}` |
| Properties (types) | `property:architecture.box.{width,height}`; `property:architecture.wall.{thickness,justification}`, `...justification.{left,centre,right}`; `property:architecture.opening.{width,position,flip-hinge,flip-swing}`; `property:architecture.room.{name,area}`; `property:architecture.dimension.{value,kind,axes,end-1,end-2}`, `...kind.{aligned,horizontal,vertical}` |
| Properties (tool settings) | `property:architecture.wall.{thickness,justification}` (the tool shares the type's id); `property:architecture.{door,window,gap}.width` |
| Texts | `text:architecture.{room-name}` `{n}`; `room-occupied` `{name}`; `axes-turned` `{degrees}`; `end-on-wall` `{wall}` `{end}` `{side}`; `end-start`; `end-end`; `end-fixed`; `face-left`; `face-centre`; `face-right`; `dimension-value` `{value}`; `sample-hall`; `sample-kitchen`; `sample-bath`; `sample-living`; `sample-dining`; `sample-bedroom` `{n}` |

An opening's section title is `tool:architecture.{door,window,gap}` by kind (its `title` hook).

### The integration package (`jet_cad_2d_integration`)

```dart
// lib/jet_cad_2d_integration.dart (Task 9; grows in Tasks 10-28, each addition listed in its task)
PlanController architectureController({String? json, PlanPermissions permissions = PlanPermissions.full});
PlanController sampleFlatController();          // build: buildSampleFlat (Task 25 adds it)
Widget planEditorApp(PlanController controller, {Locale locale = const Locale('en')});
```


## Appendix: rulings made while planning (2026-10-15)

Nine writers drafted the tasks in parallel; one reconcile pass and five pre-flight passes checked them against the code and each other (scratch logs, not committed). The rulings below bind the tasks.

### The controller's rulings (R-P1 to R-P19)

- **R-P1 (public libraries only).** `jet_cad_2d_integration` imports only public libraries (`implementation_imports`). So C7's rule reads: a ported case runs **in the kit** when it uses kit internals, the contract, the engine or the Flutter layer — and a plan-library *internal* helper it needs (e.g. `placeSymbol`, `symbol_placer.dart:169`) is reproduced as a **test-local fixture in the kit** (`test/support/place_entry.dart`: `placeEntry(doc, entry, {at, quarterTurns, mirrored, transform})`, `copyOfEntry`; a fixture change, A12). A case runs **in the integration package** only when it needs the plan library's public widgets or controller (`PlanCanvas`, `PlanEditor`, `PlanPropertyPanel`, `PlanController`, the public tools) and no kit internal. A case needing both a plan widget and a kit internal is rewritten to reach the kit internal through public behaviour (a ruling in the task) or split.
- **R-P2.** `furnitureSource` joins `architectureKit.symbols` in Task 24 with the provider (else `attachmentKindUnoffered` fires).
- **R-P3.** Kit test support shared across tasks: `test/support/place_entry.dart` (Task 23 creates it), `test/support/wall_attach_fixture.dart` (Task 24). Kit-internal readers with today's signatures plus a `LiveTypeOf` parameter: `faceRunsOf(doc, wall, LiveTypeOf live, {accept})`, `WallFaces(bands, live, {accept})`.
- **R-P4.** `PlanObject` gains `KitWords get words`; `DocumentPlanObject(document, handle, words)`; `PlanType.fieldsOf(document, group, words)` and `commitField(document, group, field, input, words)`. (Writer 7: `TextDisplay.read` needs the decimal separator and `text:` words.)
- **R-P5.** Dimension cases on the sample flat (`dimension_paint_test` RR1-RR3, `dimension_shell_test` SL1, SL2, TL9) are Task 26's.
- **R-P6.** The kit's test catalog: `test/support/wall_fixture.dart` (Task 11) gives `testCatalog()` and `installParametric(doc)` registering the kit's raw types in today's order; each type task appends its line. `wallsInDocument` (Task 13) gains `{required LiveTypeOf live}`. The kit pubspec lists `vector_math`; the integration pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `vector_math` directly (Task 9).
- **R-P7.** A pure `PlanWords` (contract model: `word`, `maybe`, `text`, `decimalSeparator`); `KitWords implements PlanWords` adds `locale`. `PlanObject.words` is a `PlanWords`, so `properties.dart` stays pure (2a's P9 unchanged).
- **R-P8 (the wall/opening/room split).** Today's `wall.dart`/`wall_grips.dart` use `opening_geometry.dart` and `room_inputs.dart`. Split: Task 11's `WallType.generate` has **no opening cut** and **no place hooks** (`contributesPlace`/`placeBox`/`placeInput`); `wallsInView` and `wallsInDocument(doc, host, LiveTypeOf live, {moved})` live in `wall_geometry.dart` (Task 11). Task 12's `WallGrips({required LiveTypeOf live})` has no 08 D13 `_keptPut`/`_seated`. Task 13 adds the wall's cut; Task 14 adds `_keptPut` and `_seated`; Task 16 adds the wall's place hooks. Wall tests whose cases need openings or rooms move to the task that adds the code they need (say so in both tasks).
- **R-P9.** Integration test files that read `@internal` members of the plan library's public classes (`selection`, `grips`, `toolContext`, `servicesOf`, `toolFor`, `frozen`, `fill`) start with `// ignore_for_file: invalid_use_of_internal_member` (precedent: `apps/restaurant_demo/test`). A Global Constraint.
- **R-P10.** Sample-flat cases are Task 26's in the integration package over `sampleFlatController()`: besides R-P5, `room_cost_test` LZ3 and `room_paint_test`'s six cases.
- **R-P11.** The kit's pubspec lists `meta` and `vector_math` besides the Global Constraints' list.
- **R-P12.** `FakePlanServices.settingsOf` reads the map it was given at each call (no copy), so a test can change a tool's settings between events.
- **R-P13 (kit test catalog).** One file, `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart`, created by Task 10 with `ParametricCatalog testCatalog()` and `ParametricSystem installParametric(DraftDocument doc)`; each type task appends its registration in today's order (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`). Domain fixtures (`wall_fixture.dart`, `room_fixture.dart`, `opening_fixture.dart`) import and re-export it; no other names (`architectureCatalog`, `installArchitecture`) are used.
- **R-P14 (integration test support).** One shared rig, `packages/jet_cad_2d_integration/test/support/editor_rig.dart` (Task 9/10: `pumpEditor`, `globalOf`, `status`, `press`, `activeTool`, `pagePlanJson`, `kitCatalog`, `liveOf`); domain support files (`opening_support.dart`, `room_plans.dart`, ...) import it and add only domain fixtures, never a second copy of a rig helper. The reconcile pass merges duplicates.
- **R-P15 (Review Focus 3, corrected to today's).** A grip drag at a refused point: the preview keeps the last accepted state, nothing is reported; a **drop at the refused point commits nothing** (today: `GripDrag.command` asks the provider at the drop point, `grip_drag.dart:303-313`; wall grips return null there, `wall_grips.dart:60-63, 198`); the grips stay usable. C1.8(2) is done through one private refusal rule shared by `execute` and `plan.select`'s `GuardedTool` (Task 7), since `ToolContext.execute` is the Flutter layer's.
- **R-P16.** 2b's renames (`SeatingComponent` → `UnitComponent(kind: table, capacity: n)`, table → unit) count as C7 class 1 (ids). Task 5 does not port ND2 (the plan library has no page-less set-up).
- **R-P17.** R-P15 corrected: at a refused point today's preview is empty (`wall_grips.dart:137-138`, `grip_drag.dart:262-263`), not the last accepted state. `wallsInDocument(doc, host, LiveTypeOf live, {moved})` takes `live` positionally (R-P6's named form struck). The kit test helper for a live reader is `liveOf(doc, {frozen})` in `wall_fixture.dart`; Task 16's `liveIn` is replaced by it.
- **R-P18.** R-16 (spec C6): the table halves of TF1/TF3/TF7, EX2/EX3/EX5 and CZ1 stay in the plan's 2b tests (they use plan internals); the integration package carries their room lines over public routes (Task 28). Spec C6's "full copies" is amended by this ruling.
- **R-P19.** R14-1 accepted: the opening's position range decides "is the host a wall" by the engine's naming rule over a catalog the kit builds lazily from its own raw type registrations (a kit-internal list in `lib/src/`, not from `architectureKit`, so no import cycle). EG8-k/EG9-k/EG10-k's test-local grip dispatch follows DM-R1/R14-7 (a fixture standing in for the plan's dispatch).

