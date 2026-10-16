### Task 9: The scaffold: the kit package, the integration package, their CI, the words and `prepare` (spec C2, C6; C1.3's user, C1.6's words)

**Files:**
- Modify (repository root): `pubspec.yaml` (two workspace members), `.github/workflows/ci.yml` (three matrix entries), `tool/ci/test/scripts_test.dart` (SC20c)
- Create (`packages/jet_cad_2d_kit_architecture/`): `pubspec.yaml`, `analysis_options.yaml` (copied, committed once), `LICENSE` (the root's), `README.md` (stub), `CHANGELOG.md`, `lib/jet_cad_2d_kit_architecture.dart`, `lib/src/kit.dart`, `lib/src/ids.dart`, `lib/src/live.dart`, `lib/src/separator_linetype.dart`, `lib/src/words/en.dart`, `lib/src/words/de.dart`, `lib/src/words/tr.dart`, `lib/src/words/words.dart`, `example/main.dart`, `test/example_test.dart`, `test/scaffold/kit_test.dart`, `test/scaffold/words_test.dart`, `test/scaffold/live_test.dart`
- Create (`packages/jet_cad_2d_integration/`): `pubspec.yaml`, `analysis_options.yaml` (copied, committed once), `README.md`, `lib/jet_cad_2d_integration.dart`, `test/support/editor_rig.dart`, `test/scaffold/smoke_test.dart`, `test/scaffold/prepare_test.dart`

**Interfaces:**
- Consumes:
  - Task 2: nothing directly (the kit has no type yet).
  - Task 3 (C1.6): `KitWords.text(String id, [Map<String, Object> args = const {}])`, `KitNamesWords(KitNames names, Locale Function() locale, {String Function()? decimalSeparator})`, `Set<String> placeholdersOf(String template)`, `PlanKit.validate` and `conformance` accepting `text:<kit>.<id>` (conformance reporting `KitProblemCode.placeholderMismatch`).
  - Task 5 (C1.3): `PlanKit({..., void Function(DraftDocument document)? prepare})`; the plan runs every kit's `prepare` on the constructor's plan without `json` and on `newPlan`, never on `load` or a `json` plan.
  - Task 6 (C1.5, C1.11): `PlanServices.liveTypeIdOf(Handle handle)`; `package:jet_cad_2d_kit/testing.dart`'s `FakePlanServices({required DraftDocument document, ParametricCatalog? catalog, Set<Handle> frozen = const {}, ...})` and its `dispose()`.
  - The contract today: `PlanKit` (`jet_cad_2d_kit/lib/src/kit/plan_kit.dart:16-140`), `KitNames` (`model/kit_names.dart:14-53`), `conformance` (`authoring/conformance.dart:36-46`), `Catalog`, `encodeLibrary`, `geometrySnapshot`, `encodeSnapshot` (`authoring/catalog.dart:99`, `builder.dart:114`, `snapshot.dart:13, :82`).
  - The plan library today: `PlanController({required List<PlanKit> kits, String? json, ..., PlanPermissions permissions = PlanPermissions.full, ...})` (`controller/plan_controller.dart:253-264`), `document`, `dirty`, `canUndo`, `save`, `load`, `newPlan`, `kits` (a `KitSet`, `.kits`), `missingKits`, `permissions` (`:2027`), `typeOf` (`:850`), `camera`; `PlanEditor` (status line keyed `status-text`, `editor/plan_editor.dart:593-595`); `planSupportedLocales`, `planLocalizationsDelegates`, `ensureManifest` (all exported by `lib/jet_cad_2d_plan.dart`).
  - The Flutter layer: `InteractionLayer` (its `tools`, a `ToolController`, `jet_cad_2d_flutter/lib/src/interaction_layer.dart:90`), `Tool.isMidShape` (`tool.dart:139`), `ViewportTransform`.
- Produces (Shared interfaces, exact):

```dart
// lib/jet_cad_2d_kit_architecture.dart: at this task it exports
//   architectureKit, ArchitectureTypes, ArchitectureTools
// (each type task adds its parameter classes; Task 25 buildSampleFlat).
final PlanKit architectureKit;                                  // lib/src/kit.dart
abstract final class ArchitectureTypes {                        // lib/src/ids.dart
  static const box = 'architecture.box', wall = 'architecture.wall',
      opening = 'architecture.opening', separator = 'architecture.separator',
      room = 'architecture.room', dimension = 'architecture.dimension';
}
abstract final class ArchitectureTools {
  static const box = 'architecture.box', wall = 'architecture.wall', door = 'architecture.door',
      window = 'architecture.window', gap = 'architecture.gap', room = 'architecture.room',
      separator = 'architecture.separator', dimension = 'architecture.dimension';
}
typedef LiveTypeOf = String? Function(Handle handle);           // lib/src/live.dart
LiveTypeOf liveTypesOf(PlanServices services);                  // services.liveTypeIdOf
void ensureDashedLinetype(DraftDocument doc);                    // lib/src/separator_linetype.dart
// The word ids of the plan's "Word ids" table, all three locales (lib/src/words/).

// package:jet_cad_2d_integration/jet_cad_2d_integration.dart
PlanController architectureController({String? json, PlanPermissions permissions = PlanPermissions.full});
Widget planEditorApp(PlanController controller, {Locale locale = const Locale('en')});
```

  Also produced (see "New shared name"): `isLiveOf`, `liveObjectsOf` (`live.dart`), `kDashedLinetypeRecord` (`separator_linetype.dart`), `architectureNames` and `architectureSameAsEnglish` (`words/words.dart`), `describeArchitectureKit` (`example/main.dart`), and the integration package's test rig (`test/support/editor_rig.dart`).

**Appendix A rows closed:**
- D-18 (the old `example_test`, 1 case): **not ported, replaced.** Its premise is the planner widget over the furniture library read from the package asset (`jet_cad_floor_plan/test/example_test.dart:11-27`); the planner widget is the plan library's (2a's ED-8, `jet_cad_2d_plan/test/example_test.dart`), the kit may not import it (A1, `tool/ci/lib/kit_deps.dart`), and the furniture asset read from a package-key bundle is Task 23's (PA2, PA3). The kit's own example (`example/main.dart`: the descriptor and its `prepare` over a bare engine document) and its test (SC-example) land here; Task 23 may add the furniture library's line and Task 25 the sample flat's, each extending SC-example.
- D-25 (the architecture words): every id of the plan's word table in English, German and Turkish (SC-words, SC-text); the contract half is Task 3's.
- D-47, the words half: the kit validates and conformance holds German and Turkish complete over every code-side word (SC-conformance); the catalog half is Task 23's.
- D-28, the hook half: the kit's `prepare` writes the DASHED record on the plans the plan library makes (SC-prepare); `new_document_test`'s DASHED lines are Task 17's.

Plan decisions and rulings:
- **The words.** Today's strings (`jet_cad_floor_plan/lib/src/l10n/strings_en.dart:61, :76-97, :190-250, :304-308, :416, :422-437`; `strings_de.dart:61, :76-97, :190-250, :304-308, :420, :426-441`; `strings_tr.dart:60, :75-96, :189-249, :303-307, :414, :420-435`) under the plan's ids. A parameterised member becomes a template (`roomName(n)` → `'Room {n}'`; `endOnWall(wall, atStart, side)` → `'Wall {wall}, {end}, {side}'` with `end-start`/`end-end` as the two words of today's `atStart ? 'start' : 'end'`). New words, which no string carries today (the specs add them, C2 "Words"): `type:architecture.opening` (`Opening`/`Wandöffnung`/`Açıklık`: the German `Öffnung` is today's Gap tool's), `property:architecture.wall.justification` (`Justification`/`Ausrichtung`/`Hizalama`: today's segmented button has no label, `selection_panel.dart:1313-1331`), `property:architecture.dimension.kind` (`Kind`/`Art`/`Tür`), `property:architecture.dimension.axes` (`Axes`/`Achsen`/`Eksenler`), and `text:architecture.dimension-value` (`{value}` in every language: today's notice is the value alone, `'Dimension — 4.69'`). Type words otherwise repeat the tool words (today's section titles are the tool strings, `selection_panel.dart:1304, 1309, 1378, 945`).
- **German words equal to English** (`Position`, `Name`, `Horizontal`) are listed in `architectureSameAsEnglish`, which conformance takes as `sameAsEnglish`; `text:architecture.dimension-value` is listed too, for `de` and `tr`: Task 3's conformance holds every English `text:` word to the declared locales, `wordUntranslated` included, and a lone `{value}` is the same in every language.
- **SC-conformance runs over the empty catalog** (spec C2 "The conformance test checks every locale complete"; `builder_test.dart` B7 pins that an empty catalog builds). Its code ids are the words' own `type:`, `tool:` and `property:` ids joined with the descriptor's (`architectureKit.types`, `.tools`, `.propertyIds`), so every later type task is held to the table without editing this test, and a property id a task adds without a word fails here.
- **`analysis_options.yaml` (plan decision, Global Constraints):** each new package's is a copy of `packages/jet_cad_2d_plan/analysis_options.yaml`, created and committed once, here, by explicit path. Step 1 checks that the human confirmed it.
- **Dependencies:** the kit lists `meta` and `vector_math` besides the four Global Constraints name, and the integration package lists the engine, the Flutter layer, the contract and `vector_math` directly: see "Interface problem".
- **`tool/ci`:** SC16 (`scripts_test.dart:333-347`) already requires every `packages/*` directory in the CI matrix, so it goes red the moment the two packages exist without their entries; SC20c pins the integration package's `--enable-vmservice` (as SC20b does the plan library's, `:437-447`). `dependency_lines_test.dart`'s list (`:12-23`) is the old line's pubspecs (2a and 2b did not add theirs) and is not changed; `readmes_test.dart` checks only the README probes it names (`:12-16`) and the kit's README carries no Dart block.
- **The integration package's entry sits before `jet_cad_floor_plan` in the matrix:** SC20b and SC20c read up to the next `- package: ` line, which the last entry of the matrix does not have.

- [ ] **Step 1: Precondition.** Tasks 1-8 are committed (`git log --oneline -9`). The controller has the human's confirmation of the plan decision on the two new `analysis_options.yaml` files (committed once, here); without it, stop and report. `git status --short` is empty. `dart run tool/ci/check_kit_deps.dart` prints `kit dependencies: 1 package(s) checked, none names the plan library or another kit`. Read `packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart` (Task 5's `prepare` field), `lib/src/kit/plan_services.dart` (Task 3's `text`, `decimalSeparator`; Task 6's `liveTypeIdOf`), `lib/src/model/kit_text.dart` (Task 3's `placeholdersOf`) and `lib/testing.dart` (Task 6): each name below must exist as the Shared interfaces give it; anything else is a finding, stop and report it.

- [ ] **Step 2: The two package skeletons and the workspace.**
  1. Root `pubspec.yaml`: after `  - packages/jet_cad_2d_plan` add the two lines `  - packages/jet_cad_2d_kit_architecture` and `  - packages/jet_cad_2d_integration`.
  2. Create `packages/jet_cad_2d_kit_architecture/pubspec.yaml`:

```yaml
name: jet_cad_2d_kit_architecture
description: >-
  The architecture kit for jet_cad_2d plans: walls, doors, windows, gaps,
  room separators, rooms, dimensions, boxes, a furniture library and wall
  attachment.
version: 0.1.0
repository: https://github.com/a-urel/jet-cad
issue_tracker: https://github.com/a-urel/jet-cad/issues
funding:
  - https://github.com/sponsors/a-urel
  - https://buymeacoffee.com/yazemo
topics:
  - cad
  - floor-plan
  - architecture
resolution: workspace

environment:
  sdk: ^3.6.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d: ^0.7.2
  jet_cad_2d_flutter: ^0.7.2
  jet_cad_2d_kit: ^0.1.0
  meta: ^1.18.0
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
```

  3. Create `packages/jet_cad_2d_integration/pubspec.yaml`:

```yaml
name: jet_cad_2d_integration
description: >-
  Not published: the tests that run the architecture kit inside the plan
  library's widgets, over both packages' public libraries.
publish_to: none
version: 0.0.0
resolution: workspace

environment:
  sdk: ^3.6.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d: ^0.7.2
  jet_cad_2d_flutter: ^0.7.2
  jet_cad_2d_kit: ^0.1.0
  jet_cad_2d_kit_architecture: ^0.1.0
  jet_cad_2d_plan: ^0.8.0
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
  vm_service: ^15.2.0
```

  4. From the repository root: `cp packages/jet_cad_2d_plan/analysis_options.yaml packages/jet_cad_2d_kit_architecture/analysis_options.yaml`, `cp packages/jet_cad_2d_plan/analysis_options.yaml packages/jet_cad_2d_integration/analysis_options.yaml`, `cp LICENSE packages/jet_cad_2d_kit_architecture/LICENSE`; then `cmp LICENSE packages/jet_cad_2d_kit_architecture/LICENSE` (exit 0, the CI's `publishable` check).
  5. Create `packages/jet_cad_2d_kit_architecture/README.md`:

```markdown
# jet_cad_2d_kit_architecture

The architecture kit of jet_cad_2d plans: walls, doors, windows and gaps,
room separators, rooms, dimensions, boxes, a furniture library and the
attachment of furniture to wall faces, as one `PlanKit` on the kit contract
(`jet_cad_2d_kit`).

A host loads it into the plan library (`jet_cad_2d_plan`):
`PlanController(kits: [architectureKit])`. The kit itself depends on the
contract only, never on the plan library.

This README is a stub; the kit's first release brings the full one.
```

  6. Create `packages/jet_cad_2d_kit_architecture/CHANGELOG.md`:

```markdown
## 0.1.0 (unreleased)

The architecture kit of jet_cad_2d plans (sub-project 3a).

- `architectureKit`: the kit's descriptor (id `architecture`), its type and
  tool ids (`ArchitectureTypes`, `ArchitectureTools`), its words in
  English, German and Turkish, and its `prepare`, which gives a plan the
  plan library makes the separators' DASHED linetype.
```

  7. Create `packages/jet_cad_2d_integration/README.md`:

```markdown
# jet_cad_2d_integration

Not published. The tests that run the architecture kit
(`jet_cad_2d_kit_architecture`) inside the plan library's widgets
(`jet_cad_2d_plan`): the kit's tools on the canvas, its property sections,
the layer rules for its objects, its grips through the select tool, the
wall attachment end to end, and the export of rooms and separators.

A kit may not name the plan library (umbrella A1,
`tool/ci/check_kit_deps.dart`), and the plan library's own tests stay free
of any domain, so these tests live here, in a package that imports both
through their public libraries only, as a host does (spec 3a C6). `lib/`
holds the fixtures, `test/` the tests.

Run with `flutter test --enable-vmservice`: the paint-allocation invariant
reads the VM's allocation profiler.
```

  8. Run `flutter pub get` from the repository root, then `git status --short`. Expected: the files above as new (`??`), `pubspec.yaml` modified. A rewritten `analysis_options.yaml` of an existing package is restored with `git checkout -- <file>`; never stage one.

- [ ] **Step 3: The failing kit tests.**
  1. Create `packages/jet_cad_2d_kit_architecture/test/scaffold/kit_test.dart`:

```dart
// Spec 3a C2: the kit's descriptor. Its id and version (the pubspec's), its
// words and its prepare, and the type and tool ids of A7.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart';

void main() {
  test(
      'SC-ids the kit is architecture at its pubspec\'s version, with its '
      'words and its prepare; its type and tool ids are the spec\'s (C2)',
      () {
    expect(architectureKit.id, 'architecture');
    // M-SC-ver: the kit's version moved without the pubspec's.
    expect(architectureKit.version, '0.1.0');
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('\nversion: ${architectureKit.version}\n'));
    expect(identical(architectureKit.names, architectureNames), isTrue);
    // M-SC-1: the kit without its prepare.
    expect(architectureKit.prepare, ensureDashedLinetype);
    expect([
      ArchitectureTypes.box,
      ArchitectureTypes.wall,
      ArchitectureTypes.opening,
      ArchitectureTypes.separator,
      ArchitectureTypes.room,
      ArchitectureTypes.dimension,
    ], [
      'architecture.box',
      'architecture.wall',
      'architecture.opening',
      'architecture.separator',
      'architecture.room',
      'architecture.dimension',
    ]);
    // M-SC-ids: a tool id renamed.
    expect([
      ArchitectureTools.box,
      ArchitectureTools.wall,
      ArchitectureTools.door,
      ArchitectureTools.window,
      ArchitectureTools.gap,
      ArchitectureTools.room,
      ArchitectureTools.separator,
      ArchitectureTools.dimension,
    ], [
      'architecture.box',
      'architecture.wall',
      'architecture.door',
      'architecture.window',
      'architecture.gap',
      'architecture.room',
      'architecture.separator',
      'architecture.dimension',
    ]);
  });
}
```

  2. Create `packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart`:

```dart
// Spec 3a C2 "Words", C1.6: the kit's words. Every locale holds exactly the
// plan's word table (symbol and category words, Task 23's, aside); each
// text: word keeps English's placeholders and fills them; the kit validates,
// and conformance (A16) holds German and Turkish complete over every
// code-side word, the descriptor's and the table's.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, conformance, encodeLibrary, encodeSnapshot, geometrySnapshot;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart';

/// The 3a plan's "Word ids" table, written out (55 ids).
const Set<String> wordTable = {
  'tool:architecture.box',
  'tool:architecture.wall',
  'tool:architecture.door',
  'tool:architecture.window',
  'tool:architecture.gap',
  'tool:architecture.room',
  'tool:architecture.separator',
  'tool:architecture.dimension',
  'type:architecture.box',
  'type:architecture.wall',
  'type:architecture.opening',
  'type:architecture.separator',
  'type:architecture.room',
  'type:architecture.dimension',
  'property:architecture.box.width',
  'property:architecture.box.height',
  'property:architecture.wall.thickness',
  'property:architecture.wall.justification',
  'property:architecture.wall.justification.left',
  'property:architecture.wall.justification.centre',
  'property:architecture.wall.justification.right',
  'property:architecture.opening.width',
  'property:architecture.opening.position',
  'property:architecture.opening.flip-hinge',
  'property:architecture.opening.flip-swing',
  'property:architecture.room.name',
  'property:architecture.room.area',
  'property:architecture.dimension.value',
  'property:architecture.dimension.kind',
  'property:architecture.dimension.kind.aligned',
  'property:architecture.dimension.kind.horizontal',
  'property:architecture.dimension.kind.vertical',
  'property:architecture.dimension.axes',
  'property:architecture.dimension.end-1',
  'property:architecture.dimension.end-2',
  'property:architecture.door.width',
  'property:architecture.window.width',
  'property:architecture.gap.width',
  'text:architecture.room-name',
  'text:architecture.room-occupied',
  'text:architecture.axes-turned',
  'text:architecture.end-on-wall',
  'text:architecture.end-start',
  'text:architecture.end-end',
  'text:architecture.end-fixed',
  'text:architecture.face-left',
  'text:architecture.face-centre',
  'text:architecture.face-right',
  'text:architecture.dimension-value',
  'text:architecture.sample-hall',
  'text:architecture.sample-kitchen',
  'text:architecture.sample-bath',
  'text:architecture.sample-living',
  'text:architecture.sample-dining',
  'text:architecture.sample-bedroom',
};

/// [locale]'s word ids, less the catalog's (symbol, category).
Set<String> codeWords(String locale) => {
      for (final id in architectureNames.words[locale]!.keys)
        if (!id.startsWith('symbol:') && !id.startsWith('category:')) id,
    };

void main() {
  test(
      'SC-words English, German and Turkish each hold exactly the plan\'s '
      'word table', () {
    expect(wordTable, hasLength(55), reason: 'premise: the table');
    expect(architectureNames.words.keys.toSet(), {'en', 'de', 'tr'});
    for (final locale in ['en', 'de', 'tr']) {
      // M-SC-3: a word deleted from one locale.
      expect(codeWords(locale), wordTable, reason: locale);
    }
  });

  test(
      'SC-text each text: word keeps English\'s placeholders in German and '
      'Turkish, and KitWords fills them as today\'s strings did', () {
    final en = architectureNames.words['en']!;
    for (final locale in ['de', 'tr']) {
      final words = architectureNames.words[locale]!;
      for (final id in wordTable.where((id) => id.startsWith('text:'))) {
        // M-SC-4: a placeholder renamed in one locale.
        expect(placeholdersOf(words[id]!), placeholdersOf(en[id]!),
            reason: '$locale: $id');
      }
    }
    expect(placeholdersOf(en['text:architecture.end-on-wall']!),
        {'wall', 'end', 'side'});
    expect(placeholdersOf(en['text:architecture.sample-bedroom']!), {'n'});
    final tr = KitNamesWords(architectureNames, () => const Locale('tr'));
    // Today's strings_tr.dart:60 and :306-307.
    expect(tr.text('text:architecture.room-occupied', {'name': 'Oda 1'}),
        'Zaten bir oda: Oda 1');
    expect(
        tr.text('text:architecture.end-on-wall', {
          'wall': '1F',
          'end': tr.text('text:architecture.end-start'),
          'side': tr.text('text:architecture.face-left'),
        }),
        'Duvar 1F, başlangıç, sol yüzey');
    final de = KitNamesWords(architectureNames, () => const Locale('de'));
    // Today's strings_de.dart:304.
    expect(de.text('text:architecture.axes-turned', {'degrees': '12,5'}),
        'Achsen um 12,5° gedreht');
  });

  test(
      'SC-conformance the kit validates, and conformance over the empty '
      'catalog holds German and Turkish complete for every code-side word',
      () {
    expect(architectureKit.validate(), isEmpty);
    const catalog = Catalog(kit: 'architecture', symbols: []);
    final english = architectureNames.words['en']!.keys;
    Set<String> ids(String namespace) => {
          for (final id in english)
            if (id.startsWith('$namespace:'))
              id.substring(namespace.length + 1),
        };
    final problems = conformance(
      catalog: catalog,
      committedLibrary: encodeLibrary(catalog),
      committedSnapshot: encodeSnapshot(geometrySnapshot(catalog)),
      names: architectureNames,
      locales: const ['de', 'tr'],
      sameAsEnglish: architectureSameAsEnglish,
      typeIds: {...ids('type'), for (final t in architectureKit.types) t.id},
      toolIds: {...ids('tool'), for (final t in architectureKit.tools) t.id},
      propertyIds: {...ids('property'), ...architectureKit.propertyIds},
    );
    // M-SC-3 and M-SC-4 are red here too (wordMissing, placeholderMismatch).
    expect(problems, isEmpty);
  });
}
```

  3. Create `packages/jet_cad_2d_kit_architecture/test/scaffold/live_test.dart`:

```dart
// Spec 3a C1.5: the kit asks "is this a live T" of the plan's services,
// never of a catalog of its own. Two test types in a catalog of their own,
// groups far off the origin and turned by 0.3 + 0.7k rad, one of them
// frozen.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/live.dart';

final class Peg implements Component {
  const Peg();

  static const String id = 'architecture.peg';

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => const {};

  static Peg fromJson(Map<String, Object?> json) => const Peg();
}

final class Pin implements Component {
  const Pin();

  static const String id = 'architecture.pin';

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => const {};

  static Pin fromJson(Map<String, Object?> json) => const Pin();
}

/// A type that draws nothing: only the naming rule is under test.
final class Inert<T extends Component> extends ParametricType<T> {
  const Inert();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(T params, Transform2 toWorld) => Aabb2.empty();

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];
}

Handle add<T extends Component>(DraftDocument doc, int h, T value, double k) {
  final handle = Handle(h);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: handle,
        parent: doc.rootHandle,
        transform: Transform2.translation(4500000 + 311.5 * k, -173.25 * k)
            .multiply(Transform2.rotation(0.3 + 0.7 * k)),
        children: const [])),
    SetComponentCommand<T>(handle, value),
  ], label: 'Add'));
  return handle;
}

void main() {
  test(
      'SC-live liveTypesOf answers the services\' live type id; isLiveOf and '
      'liveObjectsOf read it: a frozen object is in neither, while the '
      'catalog still names it', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final catalog = ParametricCatalog()
      ..register<Peg>(Peg.id, Peg.fromJson, const Inert<Peg>())
      ..register<Pin>(Pin.id, Pin.fromJson, const Inert<Pin>());
    catalog.registerComponents(doc.components);
    final frozen = add(doc, 4050, const Peg(), 1);
    final a = add(doc, 4100, const Peg(), 2);
    final b = add(doc, 4200, const Pin(), 3);
    final c = add(doc, 4300, const Peg(), 4);
    final services = FakePlanServices(
        document: doc, catalog: catalog, frozen: {frozen});
    addTearDown(services.dispose);
    expect(catalog.typeIdOf(doc, frozen), Peg.id,
        reason: 'premise: the catalog names a frozen object');

    final live = liveTypesOf(services);
    // M-SC-live-3: liveTypesOf answering null for everything.
    expect(live(a), Peg.id);
    expect(live(b), Pin.id);
    expect(live(frozen), isNull);
    expect(live(doc.rootHandle), isNull);
    // M-SC-live-2: isLiveOf asking only "is it live".
    expect(isLiveOf(live, a, Peg.id), isTrue);
    expect(isLiveOf(live, b, Peg.id), isFalse);
    expect(isLiveOf(live, frozen, Peg.id), isFalse);
    // M-SC-live-1: liveObjectsOf without its filter.
    expect(liveObjectsOf<Peg>(doc, live, Peg.id), [a, c]);
    expect(liveObjectsOf<Pin>(doc, live, Pin.id), [b]);
  });
}
```

  4. Create `packages/jet_cad_2d_kit_architecture/test/example_test.dart`:

```dart
// The kit's published example (spec 3a C2; Appendix A D-18): the
// descriptor and the hook a new plan runs, over a bare engine document.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/main.dart';

void main() {
  test(
      'SC-example the example names the kit and its version, every tool '
      'with its letter, no problems, and the DASHED record its prepare '
      'writes', () {
    final lines = describeArchitectureKit();
    expect(
        lines.first,
        'architecture 0.1.0: ${architectureKit.types.length} types, '
        '${architectureKit.tools.length} tools');
    for (final tool in architectureKit.tools) {
      expect(lines, contains('${tool.id} (${tool.letter})'));
    }
    expect(lines, contains('validate: no problems'));
    // M-SC-10: the example without the prepare call.
    expect(lines.last, 'prepare: DASHED at handle 6');
  });
}
```

- [ ] **Step 4: Run them, expecting failure.** `cd packages/jet_cad_2d_kit_architecture && flutter test`. Expected: compilation errors, `Target of URI doesn't exist: 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'` (and the `src/` files, and `../example/main.dart`). Quote them.

- [ ] **Step 5: The kit's code.**
  1. `lib/src/ids.dart`:

```dart
// The architecture kit's type and tool ids (spec 3a C2, umbrella A7): today's
// floor_planner.<type> (jet_cad_floor_plan/lib/src/parametric/catalog.dart:
// 27-39) under the kit's id. A type id is its component's codec type id.

/// The kit's parametric type ids.
abstract final class ArchitectureTypes {
  static const String box = 'architecture.box';
  static const String wall = 'architecture.wall';
  static const String opening = 'architecture.opening';
  static const String separator = 'architecture.separator';
  static const String room = 'architecture.room';
  static const String dimension = 'architecture.dimension';
}

/// The kit's tool ids; a tool's word is `tool:<id>`.
abstract final class ArchitectureTools {
  static const String box = 'architecture.box';
  static const String wall = 'architecture.wall';
  static const String door = 'architecture.door';
  static const String window = 'architecture.window';
  static const String gap = 'architecture.gap';
  static const String room = 'architecture.room';
  static const String separator = 'architecture.separator';
  static const String dimension = 'architecture.dimension';
}
```

  2. `lib/src/live.dart` (new; replaces today's `jet_cad_floor_plan/lib/src/parametric/live_objects.dart:1-29`, which asked the global `parametricCatalog`):

```dart
// "Is this a live T", as the kit asks it (spec 3a C1.5): of the plan's
// services, never of a catalog of the kit's own, so a frozen object (spec 2a
// E2) is absent from the kit's caches exactly as it is from generate. Today
// (jet_cad_floor_plan/lib/src/parametric/live_objects.dart) the app asked
// its global parametricCatalog.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanServices;

/// The type id of [handle]'s live object, or null: a frozen object, one of
/// a missing kit, and anything that is not a live object answer null.
typedef LiveTypeOf = String? Function(Handle handle);

/// The plan's answer: `PlanServices.liveTypeIdOf`.
LiveTypeOf liveTypesOf(PlanServices services) => services.liveTypeIdOf;

/// Whether [handle] is a live object of [typeId].
bool isLiveOf(LiveTypeOf live, Handle handle, String typeId) =>
    live(handle) == typeId;

/// Every live object of [typeId] carrying a `T` in [document], ascending by
/// handle value (`ComponentRegistry.withComponent` is ascending; the filter
/// keeps it): today's `liveObjectsOf<T>(doc)`. A fresh list.
///
/// Cost: O(k) calls of [live] for k holders of a `T`.
List<Handle> liveObjectsOf<T extends Component>(
        DraftDocument document, LiveTypeOf live, String typeId) =>
    [
      for (final h in document.components.withComponent<T>())
        if (live(h) == typeId) h,
    ];
```

  3. `lib/src/separator_linetype.dart`: ported from `packages/jet_cad_floor_plan/lib/src/parametric/separator.dart:122-149`. Copy lines 122-133 (`kDashedLinetypeRecord` and its doc) and 144-149 (`ensureDashedLinetype`'s body) unchanged; the file header and `ensureDashedLinetype`'s doc (today's :135-143) are adapted, because the sample plan, the fixtures and `installParametric` it names are gone:

```dart
// The separators' DASHED linetype (spec 3a C1.3, C3.4): ported from
// jet_cad_floor_plan/lib/src/parametric/separator.dart:122-149. The kit's
// prepare (lib/src/kit.dart) is ensureDashedLinetype.
import 'package:jet_cad_2d/jet_cad_2d.dart';

// [copy separator.dart:122-133 unchanged: the doc and kDashedLinetypeRecord]

/// Adds [kDashedLinetypeRecord] to [doc]'s linetypes, outside the history
/// (spec 10 D3): the kit's `prepare`, which the plan library runs only on
/// the plans it makes (spec 3a C1.3). A loaded or imported plan is never
/// given it: a file without the record opens without one, saves back
/// byte-identical, and its separators draw continuous (today's R-3).
///
/// A no-op when [ReservedHandles.dashedLinetype] already holds a record,
/// whatever it is, and when another handle already carries the name
/// `DASHED` (the table's names are case-insensitive): that record is kept,
/// and a separator, which still names handle 6, draws continuous there.
// [copy separator.dart:144-149 unchanged: void ensureDashedLinetype(...)]
```

  4. The words. `lib/src/words/en.dart`:

```dart
// The architecture kit's English words (spec 3a C2, C1.6): today's
// jet_cad_floor_plan/lib/src/l10n/strings_en.dart (:61, :76-97, :190-250,
// :304-308, :416, :422-437) under the 3a plan's word ids, and the words the
// specs add (the opening type, the justification, the dimension's kind and
// axes, the dimension's notice).

const Map<String, String> englishWords = {
  'tool:architecture.box': 'Box',
  'tool:architecture.wall': 'Wall',
  'tool:architecture.door': 'Door',
  'tool:architecture.window': 'Window',
  'tool:architecture.gap': 'Gap',
  'tool:architecture.room': 'Room',
  'tool:architecture.separator': 'Separator',
  'tool:architecture.dimension': 'Dimension',
  'type:architecture.box': 'Box',
  'type:architecture.wall': 'Wall',
  'type:architecture.opening': 'Opening',
  'type:architecture.separator': 'Separator',
  'type:architecture.room': 'Room',
  'type:architecture.dimension': 'Dimension',
  'property:architecture.box.width': 'Width',
  'property:architecture.box.height': 'Height',
  'property:architecture.wall.thickness': 'Thickness',
  'property:architecture.wall.justification': 'Justification',
  'property:architecture.wall.justification.left': 'Left',
  'property:architecture.wall.justification.centre': 'Centre',
  'property:architecture.wall.justification.right': 'Right',
  'property:architecture.opening.width': 'Width',
  'property:architecture.opening.position': 'Position',
  'property:architecture.opening.flip-hinge': 'Flip hinge',
  'property:architecture.opening.flip-swing': 'Flip swing',
  'property:architecture.room.name': 'Name',
  'property:architecture.room.area': 'Area',
  'property:architecture.dimension.value': 'Value',
  'property:architecture.dimension.kind': 'Kind',
  'property:architecture.dimension.kind.aligned': 'Aligned',
  'property:architecture.dimension.kind.horizontal': 'Horizontal',
  'property:architecture.dimension.kind.vertical': 'Vertical',
  'property:architecture.dimension.axes': 'Axes',
  'property:architecture.dimension.end-1': 'End 1',
  'property:architecture.dimension.end-2': 'End 2',
  'property:architecture.door.width': 'Width',
  'property:architecture.window.width': 'Width',
  'property:architecture.gap.width': 'Width',
  'text:architecture.room-name': 'Room {n}',
  'text:architecture.room-occupied': 'Already a room: {name}',
  'text:architecture.axes-turned': 'Axes turned {degrees}°',
  'text:architecture.end-on-wall': 'Wall {wall}, {end}, {side}',
  'text:architecture.end-start': 'start',
  'text:architecture.end-end': 'end',
  'text:architecture.end-fixed': 'Fixed',
  'text:architecture.face-left': 'left face',
  'text:architecture.face-centre': 'centreline',
  'text:architecture.face-right': 'right face',
  'text:architecture.dimension-value': '{value}',
  'text:architecture.sample-hall': 'Hall',
  'text:architecture.sample-kitchen': 'Kitchen',
  'text:architecture.sample-bath': 'Bath',
  'text:architecture.sample-living': 'Living',
  'text:architecture.sample-dining': 'Dining',
  'text:architecture.sample-bedroom': 'Bedroom {n}',
};
```

  `lib/src/words/de.dart` (header as `en.dart`'s, naming `strings_de.dart` `:61, :76-97, :190-250, :304-308, :420, :426-441`), `const Map<String, String> germanWords = {` with the same 55 ids in the same order and these words: tools `Kasten`, `Wand`, `Tür`, `Fenster`, `Öffnung`, `Raum`, `Trennlinie`, `Bemaßung`; types `Kasten`, `Wand`, `Wandöffnung`, `Trennlinie`, `Raum`, `Bemaßung`; properties `Breite`, `Höhe`, `Dicke`, `Ausrichtung`, `Links`, `Mitte`, `Rechts`, `Breite`, `Position`, `Anschlag wechseln`, `Aufschlag wechseln`, `Name`, `Fläche`, `Wert`, `Art`, `Ausgerichtet`, `Horizontal`, `Vertikal`, `Achsen`, `Ende 1`, `Ende 2`, `Breite`, `Breite`, `Breite`; texts `Raum {n}`, `Bereits ein Raum: {name}`, `Achsen um {degrees}° gedreht`, `Wand {wall}, {end}, {side}`, `Anfang`, `Ende`, `Fest`, `linke Seite`, `Mittellinie`, `rechte Seite`, `{value}`, `Flur`, `Küche`, `Bad`, `Wohnen`, `Essen`, `Schlafzimmer {n}`.

  `lib/src/words/tr.dart` (naming `strings_tr.dart` `:60, :75-96, :189-249, :303-307, :414, :420-435`), `const Map<String, String> turkishWords = {`: tools `Kutu`, `Duvar`, `Kapı`, `Pencere`, `Boşluk`, `Oda`, `Ayırıcı`, `Ölçü`; types `Kutu`, `Duvar`, `Açıklık`, `Ayırıcı`, `Oda`, `Ölçü`; properties `Genişlik`, `Yükseklik`, `Kalınlık`, `Hizalama`, `Sol`, `Orta`, `Sağ`, `Genişlik`, `Konum`, `Menteşeyi çevir`, `Açılışı çevir`, `Ad`, `Alan`, `Değer`, `Tür`, `Hizalı`, `Yatay`, `Dikey`, `Eksenler`, `Uç 1`, `Uç 2`, `Genişlik`, `Genişlik`, `Genişlik`; texts `Oda {n}`, `Zaten bir oda: {name}`, `Eksenler {degrees}° döndürülmüş`, `Duvar {wall}, {end}, {side}`, `başlangıç`, `bitiş`, `Sabit`, `sol yüzey`, `eksen`, `sağ yüzey`, `{value}`, `Hol`, `Mutfak`, `Banyo`, `Oturma odası`, `Yemek odası`, `Yatak odası {n}`.

  `lib/src/words/words.dart`:

```dart
// The architecture kit's words (spec 3a C2 "Words", C1.6): tool:, type:,
// property: and text: ids in English, German and Turkish. Task 23 adds the
// furniture library's symbol: and category: words.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitNames;

import 'de.dart';
import 'en.dart';
import 'tr.dart';

/// The kit's words by locale.
const KitNames architectureNames =
    KitNames({'en': englishWords, 'de': germanWords, 'tr': turkishWords});

/// The words whose right word is the English one, per locale: conformance's
/// `sameAsEnglish` (contract K7). The dimension's notice is the value alone
/// in every language.
const Map<String, Set<String>> architectureSameAsEnglish = {
  'de': {
    'property:architecture.opening.position',
    'property:architecture.room.name',
    'property:architecture.dimension.kind.horizontal',
    'text:architecture.dimension-value',
  },
  'tr': {
    'text:architecture.dimension-value',
  },
};
```

  Then check every non-ASCII literal against its source (Global Constraints): `grep -n "[^ -~]" packages/jet_cad_2d_kit_architecture/lib/src/words/de.dart packages/jet_cad_2d_kit_architecture/lib/src/words/tr.dart packages/jet_cad_2d_kit_architecture/lib/src/words/en.dart` and compare each hit, byte for byte, with `grep -n "[^ -~]" packages/jet_cad_floor_plan/lib/src/l10n/strings_de.dart` (and `_tr`, `_en`): the characters must be literal (`ö`, `ü`, `ä`, `ß`, `ı`, `ş`, `ğ`, `ç`, `Ö`, `°`), never an escape the file tool wrote.
  5. `lib/src/kit.dart`:

```dart
// The architecture kit's descriptor (spec 3a C2): its types, tools,
// attachment providers, symbols, words and prepare. Each type task adds its
// own (Tasks 10-25); the tools keep today's palette order (box, wall, door,
// window, gap, room, separator, dimension; planner_shell.dart:546-601).
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'separator_linetype.dart';
import 'words/words.dart';

/// The architecture kit: a host passes it to the plan library,
/// `PlanController(kits: [architectureKit])`.
final PlanKit architectureKit = PlanKit(
  id: 'architecture',
  version: '0.1.0',
  names: architectureNames,
  prepare: ensureDashedLinetype,
);
```

  6. `lib/jet_cad_2d_kit_architecture.dart`:

```dart
/// The architecture kit of jet_cad_2d plans (sub-project 3a): walls,
/// openings, room separators, rooms, dimensions, boxes, a furniture library
/// and wall attachment, as one `PlanKit` a host passes to the plan library,
/// `PlanController(kits: [architectureKit])`. The parameter classes and the
/// type ids let a host build a plan in code.
library;

export 'src/ids.dart' show ArchitectureTools, ArchitectureTypes;
export 'src/kit.dart' show architectureKit;
```

  7. `example/main.dart`:

```dart
// The architecture kit as a host sees it. A host passes `architectureKit` to
// the plan library -- `PlanController(kits: [architectureKit])`, and a
// `PlanEditor` over it (the plan library's package) -- which this package
// does not depend on, nor does its example (umbrella A1). What the example shows
// is the descriptor itself, and the one hook a new plan runs: `prepare`,
// which gives a document the separators' DASHED linetype.
//
// The kit is a Flutter library (its tools draw with Flutter's icons): the
// example is analysed with the package, and test/example_test.dart runs it.
import 'dart:async' show unawaited;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

/// The kit's descriptor, line by line: its id and version, its types, its
/// tools with their letters, what `validate` finds, and what `prepare`
/// writes into a bare engine document.
List<String> describeArchitectureKit() {
  final kit = architectureKit;
  final problems = kit.validate();
  final doc = DraftDocument.empty();
  kit.prepare?.call(doc);
  final dashed = doc.tables.linetypes[ReservedHandles.dashedLinetype];
  unawaited(doc.dispose());
  return [
    '${kit.id} ${kit.version}: ${kit.types.length} types, '
        '${kit.tools.length} tools',
    for (final type in kit.types)
      '${type.id}${type.exported ? '' : ' (not exported)'}',
    for (final tool in kit.tools) '${tool.id} (${tool.letter})',
    problems.isEmpty
        ? 'validate: no problems'
        : 'validate: ${problems.length} problems',
    dashed == null
        ? 'prepare: no DASHED record'
        : 'prepare: ${dashed.name} at handle ${dashed.handle.value}',
  ];
}

void main() {
  for (final line in describeArchitectureKit()) {
    print(line);
  }
}
```

- [ ] **Step 6: Run the kit's tests, expecting pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` (SC-ids, SC-words, SC-text, SC-conformance, SC-live, SC-example).

- [ ] **Step 7: The failing integration tests.**
  1. Create `packages/jet_cad_2d_integration/test/support/editor_rig.dart`:

```dart
// The integration tests' editor rig (spec 3a C6): PlanEditor over a
// controller in planEditorApp, at 1440 x 900, under a zoomed, turned,
// non-reflecting camera; the status line, a key press, a world point's
// global position and the active tool; a plan holding only a page; the kit's
// types in an engine catalog; a controller's live objects of one type. Its
// own copies of the plan library's test fixtures (canvas_fixture.dart's
// pumpDraw and globalOf, design_harness.dart's status and press), which
// another package cannot import, over the public libraries only.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, Tool, ViewportTransform;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Pumps [c]'s editor in [locale] at 1440 x 900 (reset after the test).
/// With [centre], then sets a camera turned by [turn] at [scale] px/mm,
/// **non-reflecting** (a reflection's `b == c` hides a transposition),
/// with [centre] in the middle of the drawing area: the plan library's
/// `pumpDraw` (canvas_fixture.dart:427-443) over PlanEditor. [wrap], when
/// given, wraps the app (a capture boundary, Task 14's RD1).
Future<void> pumpEditor(WidgetTester tester, PlanController c,
    {Locale locale = const Locale('en'),
    Vector2? centre,
    double scale = 2,
    double turn = 0.35,
    Widget Function(Widget app)? wrap}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final app = planEditorApp(c, locale: locale);
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await tester.pump();
  if (centre == null) return;
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(turn).multiply(Transform2.scale(scale, scale));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// World ([x], [y])'s global position under [c]'s camera.
Offset globalOf(WidgetTester tester, PlanController c, double x, double y) {
  final s = c.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// World [p]'s global position ([globalOf] over a point).
Offset globalAt(WidgetTester tester, PlanController c, Vector2 p) =>
    globalOf(tester, c, p.x, p.y);

/// The editor's status line (`status-text`).
String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

/// Sends [key], then a pump: whether a handler took it.
Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// The canvas's active tool, as its interaction layer holds it: a kit's
/// tool in the plan library's guard, which forwards `isMidShape`.
Tool activeTool(WidgetTester tester) =>
    tester.widget<InteractionLayer>(find.byType(InteractionLayer)).tools.active;

/// A plan holding [page] and nothing else (no manifest kit, no DASHED
/// record): `jet_cad_floor_plan/test/support/box_rig.dart:16-28`'s
/// `boxDoc`, as the text a controller opens.
String pagePlanJson(PageComponent page) {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.commands
      .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  unawaited(doc.dispose());
  return json;
}

/// The kit's types (`architectureKit.types`) in an engine catalog of their
/// own, unguarded: for `ParametricSystem(c.document, kitCatalog()).drift()`.
ParametricCatalog kitCatalog() {
  final catalog = ParametricCatalog();
  for (final type in architectureKit.types) {
    type.registerInto(catalog);
  }
  return catalog;
}

/// [c]'s live objects of [typeId] carrying a `T`, ascending: today's
/// `liveObjectsOf<T>(doc)` through the controller's `typeOf` (E1).
List<Handle> liveOf<T extends Component>(PlanController c, String typeId) => [
      for (final h in c.document.components.withComponent<T>())
        if (c.typeOf(h)?.id == typeId) h,
    ];
```

  2. Create `packages/jet_cad_2d_integration/test/scaffold/smoke_test.dart`:

```dart
// Spec 3a C6: the integration package's two fixtures. A controller over the
// kit, with the permissions asked; the editor over it, in the language asked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_rig.dart';

void main() {
  testWidgets(
      'SC-smoke the controller loads the kit with the permissions asked; '
      'the editor shows the plan in the language asked', (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    expect([for (final k in c.kits.kits) k.id], ['architecture']);
    expect(c.missingKits, isEmpty);
    expect(c.permissions, PlanPermissions.full);
    final readOnly =
        architectureController(permissions: PlanPermissions.readOnly);
    addTearDown(readOnly.dispose);
    // M-SC-perm: architectureController dropping `permissions`.
    expect(readOnly.permissions, PlanPermissions.readOnly);

    await pumpEditor(tester, c);
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(status(tester), 'Select');
    // M-SC-7: planEditorApp ignoring `locale`.
    await pumpEditor(tester, c, locale: const Locale('tr'));
    expect(status(tester), 'Seç');
    expect(tester.takeException(), isNull);
  });
}
```

  3. Create `packages/jet_cad_2d_integration/test/scaffold/prepare_test.dart`:

```dart
// Spec 3a C1.3, C3.4; Review Focus 1, the kit half (the plan half is Task
// 5's PB3-prepare-load): a plan the library makes holds the separators'
// DASHED record at handle 6, clean and with nothing to undo; a loaded file
// without it opens, and saves back, without it (today's R-3).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The kit's kDashedLinetypeRecord, written out (it is not exported):
/// jet_cad_floor_plan/lib/src/parametric/separator.dart:128-133.
const LinetypeRecord dashed = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);

void main() {
  testWidgets(
      'SC-prepare a new plan holds DASHED at handle 6, clean, with nothing to '
      'undo, and so does newPlan; a loaded file without it opens and saves '
      'back without it', (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    // M-SC-1 (no prepare) and M-SC-2 (another pattern).
    expect(c.document.tables.linetypes[ReservedHandles.dashedLinetype], dashed);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.document.commands.undoDepth, 0);

    c.newPlan(decimalSeparator: ',');
    expect(c.document.tables.linetypes[ReservedHandles.dashedLinetype], dashed);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);

    // A plan with no kit, so no prepare: no record.
    final bare = PlanController(kits: const []);
    addTearDown(bare.dispose);
    expect(
        bare.document.tables.linetypes
            .contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'premise: no kit, no record');
    final file = bare.save();

    final opened = architectureController(json: file);
    addTearDown(opened.dispose);
    expect(
        opened.document.tables.linetypes
            .contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'open adds nothing');
    expect(opened.document.tables.linetypes.byName('DASHED'), isNull);
    expect(opened.dirty.value, isFalse);
    expect(opened.save(), file, reason: 'byte-identical');

    c.load(file);
    expect(
        c.document.tables.linetypes.contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'a load adds nothing either');
    expect(c.save(), file);
  });
}
```

- [ ] **Step 8: Run them, expecting failure.** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice`. Expected: compilation errors, `Target of URI doesn't exist: 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart'` and `Undefined name 'architectureController'`. Quote them.

- [ ] **Step 9: The integration package's library.** `lib/jet_cad_2d_integration.dart`:

```dart
/// Fixtures for the tests that run the architecture kit inside the plan
/// library's widgets (spec 3a C6), built over both packages' public
/// libraries only, as a host builds them. Not published. Later tasks add
/// their fixtures here (Task 25: `sampleFlatController`).
library;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// A controller over the architecture kit: a new plan (the kit's `prepare`
/// run on it), or [json] opened as it is.
PlanController architectureController(
        {String? json, PlanPermissions permissions = PlanPermissions.full}) =>
    PlanController(
        kits: [architectureKit], json: json, permissions: permissions);

/// [controller]'s `PlanEditor` in an app speaking [locale], with the plan
/// library's locales and delegates.
Widget planEditorApp(PlanController controller,
        {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: PlanEditor(controller: controller),
    );
```

- [ ] **Step 10: Run the integration tests, expecting pass.** `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice`. Expected: `All tests passed!` (SC-smoke, SC-prepare).

- [ ] **Step 11: CI.**
  1. `.github/workflows/ci.yml`, the `package` matrix: after the `jet_cad_2d_plan` entry (its `test_flags` line, `:49`), insert:

```yaml
          - package: packages/jet_cad_2d_kit_architecture
            tool: flutter
          - package: packages/jet_cad_2d_integration
            tool: flutter
            # The paint-allocation invariant over the sample flat (spec 3a
            # C6) reads the VM's allocation profiler, as the plan
            # library's does.
            test_flags: --enable-vmservice
```

  2. The `publishable` matrix: after `          - packages/jet_cad_2d_plan` (`:179`) add `          - packages/jet_cad_2d_kit_architecture` (the kit is publishable, spec C2; the integration package is not).
  3. `tool/ci/test/scripts_test.dart`, after SC20b (`:437-447`):

```dart
  // 3a Task 9: the integration package carries the paint-allocation
  // invariant over the sample flat (spec 3a C6), which reads the VM's
  // allocation profiler; without the flag it skips, which the standing
  // comparison reads as red.
  test('SC20c the integration package\'s tests run with --enable-vmservice', () {
    final entry = workflow.indexOf(
      '- package: packages/jet_cad_2d_integration',
    );
    expect(entry, isNot(-1));
    final next = workflow.indexOf('- package: ', entry + 1);
    expect(next, isNot(-1), reason: 'premise: not the matrix\'s last entry');
    expect(
      workflow.substring(entry, next),
      contains('\n            test_flags: --enable-vmservice\n'),
    );
  });
```

  4. Run `cd tool/ci && dart format test/scripts_test.dart && dart test`. Expected: `All tests passed!` (SC16 lists both new packages; SC20b still finds the plan library's flag; SC20c the integration package's).

- [ ] **Step 12: The dependency check sees the kit.** From the repository root, `dart run tool/ci/check_kit_deps.dart`. Expected, quoted: `kit dependencies: 2 package(s) checked, none names the plan library or another kit` (the contract and `jet_cad_2d_kit_architecture`, picked by name, `check_kit_deps.dart:58-63`; the integration package is neither, as spec C6 says).

- [ ] **Step 13: Format and the gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `cd tool/ci && dart test && dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart && dart format --output=none --set-exit-if-changed lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart ../readme_probe/lib` — green (the CI's `ci-tools` job, `ci.yml:133-149`).
  - `dart run tool/ci/check_kit_deps.dart` — Step 12's line.
  - `git status --short`: only this task's files (no `analysis_options.yaml` but the two new ones).

- [ ] **Step 14: Commit.**

```bash
git add pubspec.yaml .github/workflows/ci.yml tool/ci/test/scripts_test.dart packages/jet_cad_2d_kit_architecture/pubspec.yaml packages/jet_cad_2d_kit_architecture/analysis_options.yaml packages/jet_cad_2d_kit_architecture/LICENSE packages/jet_cad_2d_kit_architecture/README.md packages/jet_cad_2d_kit_architecture/CHANGELOG.md packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/lib/src/ids.dart packages/jet_cad_2d_kit_architecture/lib/src/live.dart packages/jet_cad_2d_kit_architecture/lib/src/separator_linetype.dart packages/jet_cad_2d_kit_architecture/lib/src/words/en.dart packages/jet_cad_2d_kit_architecture/lib/src/words/de.dart packages/jet_cad_2d_kit_architecture/lib/src/words/tr.dart packages/jet_cad_2d_kit_architecture/lib/src/words/words.dart packages/jet_cad_2d_kit_architecture/example/main.dart packages/jet_cad_2d_kit_architecture/test/example_test.dart packages/jet_cad_2d_kit_architecture/test/scaffold/kit_test.dart packages/jet_cad_2d_kit_architecture/test/scaffold/words_test.dart packages/jet_cad_2d_kit_architecture/test/scaffold/live_test.dart packages/jet_cad_2d_integration/pubspec.yaml packages/jet_cad_2d_integration/analysis_options.yaml packages/jet_cad_2d_integration/README.md packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart packages/jet_cad_2d_integration/test/support/editor_rig.dart packages/jet_cad_2d_integration/test/scaffold/smoke_test.dart packages/jet_cad_2d_integration/test/scaffold/prepare_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the scaffold of the kit and the integration package

jet_cad_2d_kit_architecture 0.1.0: architectureKit with its type and
tool ids, its words in English, German and Turkish under tool:, type:,
property: and text:, the live rule through the plan's services, and its
prepare, which gives a plan the library makes the separators' DASHED
linetype. jet_cad_2d_integration (not published): the controller and
editor fixtures the kit's integration tests run on. Both join the
workspace and CI; check_kit_deps reads the new kit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: The dry run.** `cd packages/jet_cad_2d_kit_architecture && dart pub publish --dry-run`. Expected: `Package has 0 warnings.` (the CI's `publishable` job). A warning is a finding: fix it in a follow-up commit, never by an `analysis_options.yaml` change.

- [ ] **Step 16: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests run with `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`; the integration package's with `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`; `tool/ci`'s with `cd tool/ci && dart test test/scripts_test.dart`.
  - M-SC-1 `packages/jet_cad_2d_kit_architecture/lib/src/kit.dart`: delete `prepare: ensureDashedLinetype,` → SC-ids, SC-example and SC-prepare red.
  - M-SC-2 `lib/src/separator_linetype.dart`: `dashes: [200, -100]` → `dashes: [200, -50]` → SC-prepare red.
  - M-SC-ver `lib/src/kit.dart`: `version: '0.1.0'` → `version: '0.1.1'` → SC-ids and SC-example red.
  - M-SC-ids `lib/src/ids.dart`: `gap = 'architecture.gap'` → `gap = 'architecture.gaps'` → SC-ids red.
  - M-SC-3 `lib/src/words/tr.dart`: delete the `'tool:architecture.gap'` line → SC-words and SC-conformance red (`wordMissing`).
  - M-SC-4 `lib/src/words/de.dart`: `'Bereits ein Raum: {name}'` → `'Bereits ein Raum: {n}'` → SC-text red (and SC-conformance, Task 3's `placeholderMismatch`).
  - M-SC-5 `lib/src/words/words.dart`: delete `'property:architecture.opening.position',` from `architectureSameAsEnglish` → SC-conformance red (`wordUntranslated`).
  - M-SC-live-1 `lib/src/live.dart`: in `liveObjectsOf`, `if (live(h) == typeId) h,` → `h,` → SC-live red.
  - M-SC-live-2 `lib/src/live.dart`: `live(handle) == typeId` → `live(handle) != null` → SC-live red.
  - M-SC-live-3 `lib/src/live.dart`: `=> services.liveTypeIdOf;` → `=> (handle) => null;` → SC-live red.
  - M-SC-10 `packages/jet_cad_2d_kit_architecture/example/main.dart`: delete `kit.prepare?.call(doc);` → SC-example red.
  - M-SC-7 `packages/jet_cad_2d_integration/lib/jet_cad_2d_integration.dart`: delete `locale: locale,` → SC-smoke red.
  - M-SC-perm `lib/jet_cad_2d_integration.dart`: `permissions: permissions` → `permissions: PlanPermissions.full` → SC-smoke red.
  - M-SC-8 `.github/workflows/ci.yml`: delete the integration entry's `test_flags: --enable-vmservice` line → SC20c red.
  - M-SC-9 `.github/workflows/ci.yml`: delete the two lines of the `jet_cad_2d_kit_architecture` package entry → SC16 red.
  - M-SC-deps `packages/jet_cad_2d_kit_architecture/test/scaffold/kit_test.dart`: add `import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';` after the last import → `dart run tool/ci/check_kit_deps.dart` exits 1, printing `jet_cad_2d_kit_architecture: test/scaffold/kit_test.dart imports jet_cad_2d_plan` (the check parses text; the import need not resolve).

  Quote each red line.

#### Assumed from earlier tasks

- Task 3: `KitNamesWords.text` fills `{name}` from the map (`fillText`), `placeholdersOf` is exported by `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, and `PlanKit.validate`/`conformance` accept `text:architecture.<id>` with a hyphenated id (`room-name`).
- Task 5: `PlanKit.prepare` exists, and the plan runs it on the constructor's plan without `json` and on `newPlan` only.
- Task 6: `package:jet_cad_2d_kit/testing.dart` exports `FakePlanServices` with `frozen`, and `PlanServices.liveTypeIdOf` exists.

#### Notes for later tasks

- Each type task appends its `PlanType` to `architectureKit.types` and its `PlanTool`(s) to `.tools` in today's palette order (box, wall, door, window, gap, room, separator, dimension), adds its parameter classes to the barrel with `export '...' show ...;`, and adds a CHANGELOG bullet under `## 0.1.0 (unreleased)`. SC-conformance then holds the new property ids to the word table without an edit; a `wordMissing` there means the task's spec id differs from the table's.
- Task 23 adds the furniture words to `architectureNames` (`symbol:`, `category:`; SC-words ignores them) and passes `architectureSameAsEnglish` (extended for any furniture name equal to English) to its conformance call over the real catalog. `furnitureSource` joins `architectureKit.symbols` in Task 24, with the wall-face provider (ruling R-P2).
- Placement (ruling R-P1): every integration test here and later imports public libraries only; the rig above is built on them. A case that needs a kit internal runs in the kit.

#### Interface problem

1. **(Resolved by rulings R-P6 and R-P11: the kit lists `meta` and `vector_math`; the integration package `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `vector_math`.)** **The kit's runtime dependencies.** Global Constraints list `flutter`, `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_2d_kit` "and nothing else at runtime". Every ported file imports `package:vector_math/vector_math_64.dart` (e.g. `jet_cad_floor_plan/lib/src/parametric/box.dart:4`, `separator.dart:2`, 25 of the 27 files in `parametric/`), `jet_cad_2d`'s barrel does not export `Vector2` (`packages/jet_cad_2d/lib/jet_cad_2d.dart`), and `room.dart` and `dimension.dart` import `package:meta/meta.dart`; `lints/core.yaml:19` enables `depend_on_referenced_packages`. **Proposed fix (Step 2 is written for it):** the kit lists `meta: ^1.18.0` and `vector_math: ^2.2.0`, the contract's and the plan library's own floors (`packages/jet_cad_2d_kit/pubspec.yaml`, `packages/jet_cad_2d_plan/pubspec.yaml`), and the Global Constraints line reads "and on nothing else at runtime but `meta` and `vector_math`". Tasks 16 and 20 raise the same problem with the same fix.
2. **The integration package's dependencies.** Its tests and fixtures import `jet_cad_2d` (documents, commands), `jet_cad_2d_flutter` (`InteractionLayer`, `ViewportTransform`, the export functions), `jet_cad_2d_kit` (`PlanKit` for a test kit) and `vector_math` (`Vector2`) directly; `depend_on_referenced_packages` needs each listed. **Proposed fix (Step 2):** the Global Constraints' "(and what they export)" reads as these four, `vector_math` included.

#### New shared name

- `packages/jet_cad_2d_kit_architecture/lib/src/live.dart` (the File structure names `isLiveOf` without a signature):

```dart
bool isLiveOf(LiveTypeOf live, Handle handle, String typeId);
List<Handle> liveObjectsOf<T extends Component>(
    DraftDocument document, LiveTypeOf live, String typeId);   // today's liveObjectsOf<T>(doc)
```

- `lib/src/separator_linetype.dart`: `const LinetypeRecord kDashedLinetypeRecord` (today's, `separator.dart:128-133`), used by Tasks 16, 17 and 20's tests.
- `lib/src/words/words.dart`: `const KitNames architectureNames` (the kit's `names`; Task 21 and 23 read it) and `const Map<String, Set<String>> architectureSameAsEnglish` (conformance's `sameAsEnglish`; Task 23 extends it).
- `example/main.dart`: `List<String> describeArchitectureKit()`; Tasks 23 and 25 may append lines (the furniture library, the sample flat) and extend SC-example.
- `packages/jet_cad_2d_integration/test/support/editor_rig.dart` (the integration tests' rig; every integration task imports it):

```dart
Future<void> pumpEditor(WidgetTester tester, PlanController c,
    {Locale locale = const Locale('en'), Vector2? centre, double scale = 2, double turn = 0.35,
    Widget Function(Widget app)? wrap});
Offset globalOf(WidgetTester tester, PlanController c, double x, double y);
Offset globalAt(WidgetTester tester, PlanController c, Vector2 p);  // globalOf over a point
String status(WidgetTester tester);
Future<bool> press(WidgetTester tester, LogicalKeyboardKey key);
Tool activeTool(WidgetTester tester);                 // the guarded tool; isMidShape forwards
String pagePlanJson(PageComponent page);              // box_rig.dart's boxDoc as a plan's text
ParametricCatalog kitCatalog();                       // architectureKit.types, unguarded
List<Handle> liveOf<T extends Component>(PlanController c, String typeId);
```

---

