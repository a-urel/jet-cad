### Task 3: Contract additions (spec S2 "The label", "The contract gains", S4 "Permissions", "Words", "The contract inputs, settled")

**Files:**
- Create (`packages/jet_cad_2d_kit/`): `lib/src/kit/symbols_state.dart`, `lib/src/kit/unit_label.dart`, `lib/src/kit/host_words.dart`, `test/support/placements.dart`, `test/kit/unit_label_test.dart`, `test/kit/host_words_test.dart`
- Modify (`packages/jet_cad_2d_kit/`): `lib/jet_cad_2d_kit.dart` (three exports), `lib/src/kit/plan_services.dart` (`SymbolDefinitionRef`, two members), `lib/src/kit/properties.dart` (`PlanGate.relabel`), `lib/src/kit/plan_kit.dart` (the `unit:` namespace), `lib/src/model/kit_problem.dart` (`unitKindWord`), `lib/src/model/kit_names.dart` (doc), `lib/src/model/unit_component.dart` (`assigned`'s doc), `lib/src/authoring/conformance.dart` (the unit kind check; the plan's file structure lists it under `model/`, the file lives under `authoring/`), `CHANGELOG.md`; tests `test/kit/plan_kit_test.dart`, `test/kit/plan_services_test.dart`, `test/kit/properties_test.dart` (PS18's premise list), `test/authoring/conformance_test.dart`, `test/invariants/purity_test.dart`
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/controller/permissions.dart` (the `relabel` flag and switch arm), `lib/src/controller/services.dart` (two compile stubs Task 4 replaces), `test/controller/permissions_test.dart` (its flag tables gain `relabel`)

**Interfaces:**
- Consumes:
  - Task 1 (E5): `GeneratedAttrib(String tag, String text, GeometryPayload payload, {int textAttrs = 0})`, exported from `package:jet_cad_2d/jet_cad_2d.dart` (fields `tag`, `text`, `payload`, `textAttrs`).
  - Engine: `packTextAttrs`, `TextJustifyH`, `TextJustifyV` (`jet_cad_2d/lib/src/document/text_geometry.dart:33`), `Aabb2` (`geometry/aabb2.dart:19`; `Aabb2.empty()`, `isEmpty` `:48`), `Transform2`, `GeometryPayload`, `Handle`, `DraftCommand`.
  - Contract today: `KitNames` (`model/kit_names.dart:14-51`), `KitProblem`/`KitProblemCode` (`model/kit_problem.dart:7-57`), `isKitId`, `kitOfKey` (`model/kit_ids.dart:14`, `:31`), `UnitKinds` (`model/unit_component.dart:23-26`), `CatalogSymbol.unit` (`authoring/catalog.dart:52-62`), `PlanKit.validate` (`kit/plan_kit.dart:59-138`), `conformance` (`authoring/conformance.dart:32-80`).
  - Plan library today: `PlanPermissions` (`controller/permissions.dart:24-180`), `KitServices` (`controller/services.dart:21-65`).
- Produces (Shared interfaces, exact):

```dart
// symbols_state.dart
enum SymbolsState { loading, ready, failed }
// plan_services.dart
final class SymbolDefinitionRef {
  const SymbolDefinitionRef({required this.handle, required this.add,
      required this.basePoint, required this.top});
  final Handle handle;
  final DraftCommand? add;
  final Vector2 basePoint;
  final Aabb2 top;
}
// on PlanServices:
SymbolDefinitionRef? symbolDefinition(String key);
ValueListenable<SymbolsState> get symbolsState;
// unit_label.dart
const String kUnitLabelTag = 'UNIT';
const double kUnitLabelMaxHeight = 200;
const double kUnitLabelTopShare = 0.4;
final int kUnitLabelTextAttrs;
double unitLabelHeight(Aabb2 top);
({double rotation, double widthFactor}) unitLabelStamp(Transform2 instanceToWorld);
GeometryPayload unitLabelPayload(
    {required Vector2 anchor, required double height, required Transform2 instanceToWorld});
GeneratedAttrib unitLabelAttrib(String text,
    {required Transform2 instanceToWorld, required Vector2 anchor, required Aabb2 top});
// host_words.dart
List<KitProblem> validateHostWords(KitNames words);
// properties.dart: PlanGate gains `relabel` (last value).
// kit_problem.dart: KitProblemCode gains `unitKindWord` (last value).
// PlanKit.validate: 'unit:<kit id>/<kind>' in the slash (category) branch.
// conformance(): a UnitComponent kind outside UnitKinds needs English 'unit:<kit id>/<kind>'.
// jet_cad_2d_plan: PlanPermissions gains `relabel` (bool, default true; false in readOnly).
```

Plan decisions:
- **`unitLabelHeight` reads a box** (Shared interfaces). Today's `tableLabelHeight(kind, payload)` (`jet_cad_floor_plan/lib/src/tables/table_label.dart:25-44`) took the first leaf's kind and payload: a circle's side `2r`, a polyline's bounding box, any other kind the full 200. The box form gives the same numbers for a circle (`(c + r) - (c - r)`) and a polyline; "any other kind" becomes an **empty** box (`Aabb2.empty()`), which gives 200. Task 7's placer reads the box of today's rule (Task 6's `placedLabelTop`, controller ruling R-21: the first leaf's box when it is a circle or a polyline, open or closed, else an empty box), so a placed unit keeps today's height exactly. A generated unit gets `SymbolDefinitionRef.top`, which the spec makes the definition's box when there is no served top (S2): `0.4 × min side` of that box, capped at 200. That is the spec's rule for a new kind of label, not a change of today's.
- **What is ported from `table_label_test.dart`, and what is not.** TL1, TL2 (the stamp) and TL4 (the height) are pure functions this task owns; they are ported, assertions unchanged. TL3 tests `restampedTableLabel`, TL5 `tableLabelRecord`, TL6 `addTableLabelCommand` and TL7 `firstLeafOf`: none of them is in the contract's Shared interfaces (the label system's restamp, the placed label's record and command, and the first leaf read from a document are the plan library's, Task 7). TL3 is Task 7's and TL5-TL7 are Task 6's (both port them); this task's results line in the ledger says so.
- **`unit:` words need English only in conformance, not in `validate`.** `validate` treats `unit:` like `category:` (the part before the slash must be the kit's id; no English required there). Conformance requires the English word for a kind outside `UnitKinds` (`KitProblemCode.unitKindWord`) and, as the spec asks no more, does **not** hold the declared locales to it (a `unit:` word is outside check 5's `english` map, so it is neither `wordMissing` in another locale nor a `wordOrphan`). This is what lets Task 5's test kit carry the booth's English word only (spec Tests).
- **`validateHostWords`' codes.** An id in no known namespace is `unknownWordId` (as `validate`'s); an id that names no kit (`tool:wall`, `category:Tables`, `type:Acme.wall`) is `foreignWordId`. "Names a kit" is `isKitId` of the part before the first `.` (`symbol`, `tool`, `type`, `property`, which must hold a `.`) or before the `/` (`category`, `unit`): any kit, loaded or not.
- **`PlanGate.relabel` and the plan library.** The new enum value breaks `PlanPermissions.allows`' exhaustive switch (`jet_cad_2d_plan/lib/src/controller/permissions.dart:72-82`). This task adds the `relabel` flag there, whole: constructor (default `true`), `readOnly` (`false`, today's `readOnly` has `renumber: false`, `jet_cad_floor_plan/lib/src/host/editor_capabilities.dart:192`), `allows`, `edits` (an edit flag), `copyWith`, `==`/`hashCode`/`toString` (through `_flags`). Task 8 adds `selectUnitsOnly`, `serviceMove`, `serviceMerge`, `unitsOnly` and `isUnitSymbol`. `permissions_test.dart` (2a's own test, not a ported one) gains `relabel` in its flag tables; PM-7's `readOnly` string gains `relabel: false` at its declaration position.
- **`KitServices` compiles through two stubs.** `PlanServices` gains two abstract members, so `jet_cad_2d_plan`'s `KitServices` (`controller/services.dart:21`) must implement them for the workspace to stay green. This task adds both as `UnimplementedError` stubs naming Task 4, which replaces them (no kit calls them before Task 5). Every other `PlanServices` in the workspace is a test fake over `noSuchMethod` (`jet_cad_2d_kit/test/kit/plan_type_test.dart:32`, `jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart:349`, `test/tools/move_resolver_test.dart:20`, `test/attach/attachment_registry_test.dart:15`) and compiles unchanged.

- [ ] **Step 1: Precondition.** Tasks 1 and 2 are committed. Run `cd packages/jet_cad_2d && dart analyze` (expected `No issues found!`), then `cd packages/jet_cad_2d_plan && flutter analyze`. Expected: `No issues found!`. Task 1 added `GuardedType.instances` (controller ruling R-1), so the plan library compiles; any other result is a finding: stop and report it.

- [ ] **Step 2: The test support.** Create `packages/jet_cad_2d_kit/test/support/placements.dart` (the kit depends on neither package it copies from):

```dart
// Two placements, copied for the label tests ported in 2b Task 3: today's
// fixture placement (jet_cad_floor_plan/test/tables/table_fixture.dart:
// 72-78) and the placer's quarter-turn form (jet_cad_floor_plan/lib/src/
// symbols/symbol_placer.dart:51-78, the `rotation` form left out). The kit
// depends on neither package.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// `translate(at) · R(theta) · (mirror x) · translate(-base)`.
Transform2 placementAt(double x, double y, double theta,
        {bool mirrored = false, double baseX = 900, double baseY = 700}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-baseX, -baseY));

/// `translation(at) · rotation · scale(mirrored ? -1 : 1, 1) ·
/// translation(-basePoint)`, the rotation [quarterTurns] counter-clockwise
/// with exact cosine and sine, and no stored `-0.0`.
Transform2 placementTransform({
  required Vector2 at,
  required Vector2 basePoint,
  int quarterTurns = 0,
  bool mirrored = false,
}) {
  final (cos, sin) = const [
    (1.0, 0.0),
    (0.0, 1.0),
    (-1.0, 0.0),
    (0.0, -1.0)
  ][((quarterTurns % 4) + 4) % 4];
  final m = Transform2.translation(at.x, at.y)
      .multiply(Transform2(cos, sin, -sin, cos, 0, 0))
      .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
      .multiply(Transform2.translation(-basePoint.x, -basePoint.y));
  double clean(double v) => v == 0 ? 0.0 : v;
  return Transform2(
      clean(m.a), clean(m.b), clean(m.c), clean(m.d), clean(m.e), clean(m.f));
}
```

- [ ] **Step 3: The failing label tests.** Create `packages/jet_cad_2d_kit/test/kit/unit_label_test.dart`.

  Ported (source `packages/jet_cad_floor_plan/test/tables/table_label_test.dart`; assertions unchanged): TL1 (lines 27-47, the loop), TL2 (`:49-76`), TL4 (`:94-111`). Adaptations: `tableLabelStamp` → `unitLabelStamp`; `tableLabelHeight(EntityKind.circle, circle(r))` → `unitLabelHeight(circle(r))` where `circle` and `box` now build the payloads' bounding boxes (`Aabb2`) instead of the payloads; the `EntityKind.line` case → `unitLabelHeight(Aabb2.empty())` (no served top, the expected 200 unchanged); imports: the kit's barrel and `../support/placements.dart` instead of `symbol_placer.dart` and `table_fixture.dart`. New: K2B-payload, K2B-attrib, K2B-attrib-empty.

```dart
// Spec 2b S2 "The label": a unit's label stamp, height and payload, and
// unitLabelAttrib, a generated unit's label (E5). TL1, TL2 and TL4 are
// ported from jet_cad_floor_plan's test/tables/table_label_test.dart (spec
// 14a T8, T10), assertions unchanged: table -> unit, the height read from
// the top's box. The stamp is checked the way it is drawn: the label's
// world linear map is the instance's linear part times the text's own,
// `R(rotation) · diag(widthFactor, 1)`, and must be the identity.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/placements.dart';

/// The label's world linear map under [placement], from [rotation] and
/// [widthFactor] (the stamp's, by default).
Transform2 worldLinear(Transform2 placement,
    {double? rotation, double? widthFactor}) {
  final s = unitLabelStamp(placement);
  final linear =
      Transform2(placement.a, placement.b, placement.c, placement.d, 0, 0);
  return linear
      .multiply(Transform2.rotation(rotation ?? s.rotation))
      .multiply(Transform2.scale(widthFactor ?? s.widthFactor, 1));
}

void expectIdentity(Transform2 w) {
  expect(w.a, closeTo(1, 1e-12));
  expect(w.b, closeTo(0, 1e-12));
  expect(w.c, closeTo(0, 1e-12));
  expect(w.d, closeTo(1, 1e-12));
}

void main() {
  group('unitLabelStamp (T10)', () {
    const degrees = [0.0, 37.0, 90.0, 180.0, -123.0, 270.0, 179.0];
    for (final mirrored in [false, true]) {
      for (final deg in degrees) {
        test(
            'TL1 ${mirrored ? 'mirrored, ' : ''}$deg°: the label reads '
            'upright in world (M-14a-7, M-14a-8)', () {
          final p =
              placementAt(-4321, 2468, deg * math.pi / 180, mirrored: mirrored);
          final w = worldLinear(p);
          expect(w.a, closeTo(1, 1e-12));
          expect(w.b, closeTo(0, 1e-12));
          expect(w.c, closeTo(0, 1e-12));
          expect(w.d, closeTo(1, 1e-12));
          final s = unitLabelStamp(p);
          expect(s.rotation, greaterThan(-math.pi));
          expect(s.rotation, lessThanOrEqualTo(math.pi));
          expect(s.widthFactor, mirrored ? -1.0 : 1.0);
        });
      }
    }

    test('TL2 placements store clean values: no −0.0, exact quarter turns', () {
      final bp = Vector2(900, 700);
      final plain = unitLabelStamp(
          placementTransform(at: Vector2(3000, -1200), basePoint: bp));
      expect((plain.rotation, plain.widthFactor), (0.0, 1.0));
      expect(plain.rotation.isNegative, isFalse);

      final mirrored = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, mirrored: true));
      expect((mirrored.rotation, mirrored.widthFactor), (0.0, -1.0));
      expect(mirrored.rotation.isNegative, isFalse);

      final quarter = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, quarterTurns: 1));
      expect((quarter.rotation, quarter.widthFactor), (-math.pi / 2, 1.0));

      final half = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, quarterTurns: 2));
      expect((half.rotation, half.widthFactor), (math.pi, 1.0));

      final threeMirrored = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200),
          basePoint: bp,
          quarterTurns: 3,
          mirrored: true));
      expect((threeMirrored.rotation, threeMirrored.widthFactor),
          (-math.pi / 2, -1.0));
    });
  });

  group('unitLabelHeight (T8, M-14a-14)', () {
    // The boxes of today's circle (centre (400, 300)) and box payloads.
    Aabb2 circle(double r) => Aabb2.raw(400 - r, 300 - r, 400 + r, 300 + r);
    Aabb2 box(double w, double h) => Aabb2.raw(100, 200, 100 + w, 200 + h);

    test('TL4 written out by hand', () {
      expect(unitLabelHeight(circle(190)), 152);
      expect(unitLabelHeight(circle(300)), 200);
      expect(unitLabelHeight(box(2000, 400)), 160);
      expect(unitLabelHeight(box(1200, 750)), 200);
      expect(unitLabelHeight(box(450, 600)), 180);
      expect(unitLabelHeight(Aabb2.empty()), 200);
    });
  });

  group('the generated label (spec 2b S2)', () {
    // A seat turned three quarters and mirrored, in a row turned 37° far
    // off the origin: the instance-to-world map is neither the identity,
    // nor a rotation, nor the seat's own transform.
    final row = Transform2.translation(-41250.5, 17320.25)
        .multiply(Transform2.rotation(37 * math.pi / 180));
    final seat = placementTransform(
        at: Vector2(1200.5, -350.25),
        basePoint: Vector2(225, 190),
        quarterTurns: 3,
        mirrored: true);
    final toWorld = row.multiply(seat);
    final anchor = Vector2(225, 190);
    // The served top: 380 × 450, so 0.4 × 380 = 152.
    const top = Aabb2.raw(35, 0, 415, 450);

    test(
        'K2B-payload the payload holds the anchor as given and [height, '
        'rotation, widthFactor] stamped for the instance-to-world map', () {
      final p = unitLabelPayload(
          anchor: anchor, height: 152, instanceToWorld: toWorld);
      final s = unitLabelStamp(toWorld);
      expect(s.widthFactor, -1.0, reason: 'premise: the map mirrors');
      // M-K2B-1: unitLabelPayload stamping the identity instead.
      expect(p.coords, [225, 190]);
      expect(p.scalars, [152, s.rotation, s.widthFactor]);
    });

    test(
        'K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its '
        'own width factor, the payload in definition space, upright and '
        'unmirrored in the world', () {
      final a = unitLabelAttrib('B12',
          instanceToWorld: toWorld, anchor: anchor, top: top);
      expect(kUnitLabelTag, 'UNIT');
      // M-K2B-2: the attribute tagged '' (or 'TABLE').
      expect(a.tag, 'UNIT');
      expect(a.text, 'B12');
      // M-K2B-3: `textAttrs:` left out (0).
      expect(a.textAttrs, kUnitLabelTextAttrs);
      expect(a.textAttrs & 0xF, TextJustifyH.centre.index);
      expect((a.textAttrs >> 4) & 0xF, TextJustifyV.middle.index);
      expect(a.textAttrs & (1 << 8), isNot(0),
          reason: 'the width factor is read only with bit 8');
      // M-K2B-4: the anchor mapped into the world before it is stored.
      expect(a.payload.coords, [225, 190], reason: 'definition space');
      expect(a.payload.scalars[0], 152);
      // M-K2B-5: the stamp taken for another map: no longer upright.
      expectIdentity(worldLinear(toWorld,
          rotation: a.payload.scalars[1], widthFactor: a.payload.scalars[2]));
    });

    test('K2B-attrib-empty a definition with no served top: the full height',
        () {
      // M-K2B-6: unitLabelHeight without its empty-box check (an inverted
      // box gives -infinity).
      final a = unitLabelAttrib('7',
          instanceToWorld: toWorld, anchor: anchor, top: Aabb2.empty());
      expect(a.payload.scalars[0], kUnitLabelMaxHeight);
      expect(kUnitLabelMaxHeight, 200);
      expect(kUnitLabelTopShare, 0.4);
    });
  });
}
```

- [ ] **Step 4: The failing host words, validate, conformance, purity and premise tests.**
  1. Create `packages/jet_cad_2d_kit/test/kit/host_words_test.dart`:

```dart
// Spec 2b S4 "Words": a host's words (PlanController(words:)) are checked by
// validateHostWords: every id in a known namespace, naming a kit, any kit.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

List<KitProblemCode> codes(List<KitProblem> problems) =>
    [for (final p in problems) p.code];

void main() {
  test(
      'K2B-host-1 a word in every namespace, under any kit (loaded or not), '
      'in any locale, is sound', () {
    const words = KitNames({
      'en': {
        'symbol:acme.table.round': 'Round table',
        'category:acme/Tables': 'Tables',
        'tool:acme.wall': 'Wall',
        'type:acme.wall': 'Wall',
        'property:acme.wall.height': 'Height',
        'unit:acme/booth': 'Booth',
      },
      'fr': {'tool:other.door': 'Porte', 'unit:other/seat': 'Siège'},
    });
    // M-K2B-7: `'unit'` left out of the slash namespaces (unknownWordId).
    expect(validateHostWords(words), isEmpty);
    expect(validateHostWords(KitNames.empty), isEmpty);
  });

  test('K2B-host-2 a word in no known namespace, in the words\' order', () {
    final found = validateHostWords(const KitNames({
      'en': {'label:acme.x': 'x', 'acme.table.round': 'y'},
      'de': {'tool:wall': 'z'},
    }));
    // M-K2B-8: the default branch reporting nothing.
    expect(codes(found), [
      KitProblemCode.unknownWordId,
      KitProblemCode.unknownWordId,
      KitProblemCode.foreignWordId,
    ]);
    expect(found[0].message, contains('"label:acme.x"'));
    expect(found[0].message, startsWith('en: '));
    expect(found[1].message, contains('"acme.table.round"'));
    expect(found[2].message, startsWith('de: '));
  });

  test('K2B-host-3 a word that names no kit', () {
    for (final id in [
      'tool:wall',
      'type:Acme.wall',
      'symbol:acme',
      'property:acme',
      'category:Tables',
      'category:/Tables',
      'unit:booth',
      'unit:Acme/booth',
    ]) {
      final found = validateHostWords(KitNames({
        'de': {id: 'x'},
      }));
      // M-K2B-9: the kit check dropped (every id in a known namespace
      // passes).
      expect(codes(found), [KitProblemCode.foreignWordId], reason: id);
      expect(found.single.message, contains('"$id"'));
    }
  });
}
```

  2. In `packages/jet_cad_2d_kit/test/kit/plan_kit_test.dart`, after K6 (inside `main`, before the `group('the code side ...`), add:

```dart
  test(
      'K2B-validate a unit kind word under the kit is sound; under another '
      'kit, under none, or dotted, it is foreign', () {
    const sound = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'en': {'unit:sample/booth': 'Booth'},
          'tr': {'unit:sample/booth': 'Loca'},
        }));
    // M-K2B-10: `'unit'` left out of the slash branch (unknownWordId).
    expect(sound.validate(), isEmpty);
    for (final id in ['unit:other/booth', 'unit:booth', 'unit:sample.booth']) {
      final kit = PlanKit(
          id: 'sample',
          version: '0.1.0',
          names: KitNames({
            'en': {id: 'x'},
          }));
      // M-K2B-11: `'unit'` in the dot branch instead ('unit:sample/booth'
      // is then foreign, and 'unit:sample.booth' sound).
      expect(codes(kit), [KitProblemCode.foreignWordId], reason: id);
      expect(kit.validate().single.message, contains(id));
    }
  });
```

  3. In `packages/jet_cad_2d_kit/test/authoring/conformance_test.dart`, at the end of `main` (after the R3 group), add:

```dart
  group('unit kinds (spec 2b S4)', () {
    // Two booths: a kind the contract does not name. New keys, so the
    // generator writes them into the library and the snapshot.
    CatalogSymbol booth(String key, String name, double x) => CatalogSymbol(
          key: key,
          name: name,
          category: tables,
          tags: const ['booth'],
          unit: const CatalogUnit(kind: 'booth', capacity: 6),
          base: (x + 900, 2450),
          shapes: [rect(x, 2000, 1800, 900)],
        );
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      booth('sample.booth.corner', 'Corner booth', 3000),
      booth('sample.booth.long', 'Long booth', 5200),
    ]);
    final g = generated(catalog);

    /// The sample's words, the booths' symbol words in its two locales, and
    /// [english] (none when empty).
    KitNames named(Map<String, String> english) => KitNames({
          ...sampleNames.words,
          'de': {
            ...sampleNames.words['de']!,
            'symbol:sample.booth.corner': 'Eckbank',
            'symbol:sample.booth.long': 'Lange Bank',
          },
          'tr': {
            ...sampleNames.words['tr']!,
            'symbol:sample.booth.corner': 'Köşe koltuk',
            'symbol:sample.booth.long': 'Uzun koltuk',
          },
          if (english.isNotEmpty) 'en': english,
        });

    List<KitProblem> boothProblems(KitNames names) => problems(
        catalog: catalog,
        library: g.library,
        snapshot: g.snapshot,
        names: names);

    test(
        'K2B-conf a kind outside UnitKinds needs an English unit word, once '
        'per kind; the declared locales are not held to it', () {
      // M-K2B-12: the unit kind check not called.
      final found = boothProblems(named(const {}));
      // M-K2B-13: the once-per-kind set dropped (two problems).
      expect(codes(found), [KitProblemCode.unitKindWord]);
      expect(found.single.message, contains('"unit:sample/booth"'));
      expect(boothProblems(named(const {'unit:sample/booth': 'Booth'})),
          isEmpty);
      expect(
          codes(boothProblems(named(const {'unit:other/booth': 'Booth'}))),
          [KitProblemCode.unitKindWord],
          reason: "another kit's word does not count");
    });
  });
```

     And amend F0's body: `expect(problems(), isEmpty);` stays; add above it the comment `// M-K2B-14: the UnitKinds exemption dropped: the sample's tables and stool need a unit word.` (F0 is the positive control that this mutation turns red.)
  4. In `packages/jet_cad_2d_kit/test/invariants/purity_test.dart`, after P9, add:

```dart
  test('K2B-pure the unit label, the host words and SymbolsState reach no '
      'Flutter', () {
    // Spec 2b S2: a kit's parametric type (pure Dart) builds its labels with
    // unitLabelAttrib. M-K2B-15: import package:flutter/foundation.dart in
    // unit_label.dart.
    const files = [
      'lib/src/kit/unit_label.dart',
      'lib/src/kit/host_words.dart',
      'lib/src/kit/symbols_state.dart',
    ];
    final walk = walkImports('.', 'jet_cad_2d_kit', files);
    expect(walk.violations, isEmpty);
    expect(walk.visited, containsAll(files));
  });
```

  5. In `packages/jet_cad_2d_kit/test/kit/properties_test.dart`, PS18's list (lines 314-324) gains `'relabel',` after `'editPage',` (a premise of the declaration).
  6. In `packages/jet_cad_2d_kit/test/kit/plan_services_test.dart`, add the imports `import 'package:jet_cad_2d/jet_cad_2d.dart';` and `import 'package:vector_math/vector_math_64.dart' show Vector2;`, and after PT24:

```dart
  test('K2B-ref SymbolDefinitionRef holds its four fields; SymbolsState '
      'lists its three states', () {
    // A premise of the declarations, exempt from the mutation rule.
    final add = CompoundCommand(const [], label: 'Add');
    final ref = SymbolDefinitionRef(
        handle: const Handle(0x4A2),
        add: add,
        basePoint: Vector2(2100.5, 1300.25),
        top: const Aabb2.raw(1650.5, 850.25, 2550.5, 1750.25));
    expect(ref.handle, const Handle(0x4A2));
    expect(identical(ref.add, add), isTrue);
    expect(ref.basePoint, Vector2(2100.5, 1300.25));
    expect([ref.top.minX, ref.top.minY, ref.top.maxX, ref.top.maxY],
        [1650.5, 850.25, 2550.5, 1750.25]);
    expect(SymbolsState.values.map((s) => s.name),
        ['loading', 'ready', 'failed']);
  });
```

- [ ] **Step 5: Run the kit's tests, expecting failure.** `cd packages/jet_cad_2d_kit && flutter test`. Expected: compile errors naming `unitLabelStamp`, `unitLabelHeight`, `unitLabelPayload`, `unitLabelAttrib`, `kUnitLabelTag`, `validateHostWords`, `SymbolDefinitionRef`, `SymbolsState`, `KitProblemCode.unitKindWord` (the files that reference them fail to load); PS18 fails on `'relabel'`.

- [ ] **Step 6: `SymbolsState`.** Create `packages/jet_cad_2d_kit/lib/src/kit/symbols_state.dart`:

```dart
// The symbol libraries' state (spec 2b S2), moved from jet_cad_2d_plan
// (2a's PlanSymbolsState): a kit's tool reads it through
// PlanServices.symbolsState to tell a key no loaded library has from
// libraries still loading or failed.
//
// Pure Dart: no Flutter, no dart:io.

/// Whether a plan's symbol libraries are loading, ready or failed.
enum SymbolsState {
  /// A library has not settled yet.
  loading,

  /// Every library settled and one at least was read, or there is none.
  ready,

  /// There was a library and every one failed.
  failed,
}
```

- [ ] **Step 7: `PlanServices` gains `symbolDefinition` and `symbolsState`.** In `packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart`:
  1. The header comment's first line gains: `// ... and (spec 2b S2) the symbol definitions a kit's types place.` Imports become:

```dart
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show CameraController;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../model/kit_names.dart';
import 'attachment.dart';
import 'symbols_state.dart';
```

  2. Before `abstract interface class PlanServices`, add:

```dart
/// A symbol definition a kit's code uses (spec 2b S2): a parametric type
/// generates instances of it (E5), a tool places it. Every value is in the
/// definition's space.
final class SymbolDefinitionRef {
  const SymbolDefinitionRef(
      {required this.handle,
      required this.add,
      required this.basePoint,
      required this.top});

  /// The definition's handle in the current document: a definition it
  /// holds, or the one [add] adds.
  final Handle handle;

  /// One command that adds the definition, its leaves and its
  /// `jetcad.symbol` and `jetcad.unit` (the plan's symbol placer's), or
  /// null when the document holds the definition. Executed once, before
  /// or with the first command that uses [handle].
  final DraftCommand? add;

  /// The definition's base point.
  final Vector2 basePoint;

  /// The definition's first leaf's box when that leaf is a closed
  /// polyline or a circle (a unit's served top), else the definition's
  /// box. `unitLabelAttrib`'s `top`.
  final Aabb2 top;
}
```

  3. At the end of `PlanServices`, add:

```dart
  /// The symbol [key], a full versioned key (`kit.kind.variant@N`), as a
  /// definition of the current document: the one it holds, or one to add.
  /// Null when no loaded library has [key], or while the libraries load or
  /// after they failed ([symbolsState] tells which).
  ///
  /// A ref with an `add` took its handles from the document's seed, one
  /// per definition and per leaf: call this once per placement, never per
  /// preview. A second call for [key] before that `add` executes returns
  /// the same ref, `add` included (spec 2b S2): execute it once.
  SymbolDefinitionRef? symbolDefinition(String key);

  /// The symbol libraries' state: the plan's own listenable, so a tool can
  /// wait for `ready`.
  ValueListenable<SymbolsState> get symbolsState;
```

- [ ] **Step 8: The unit label.** Create `packages/jet_cad_2d_kit/lib/src/kit/unit_label.dart`. Ported from `packages/jet_cad_floor_plan/lib/src/tables/table_label.dart:13-82`; adaptations: `kTableLabelTag`/`'TABLE'` → `kUnitLabelTag`/`'UNIT'`, every `tableLabel*` → `unitLabel*`, `placement` → `instanceToWorld`, the height reads an `Aabb2` (plan decision), `restampedTableLabel` left to Task 7, `tableLabelRecord`, `addTableLabelCommand` and `firstLeafOf` to Task 6 (they need a document); `unitLabelAttrib` new.

```dart
// A unit's label, drawn (spec 2b S2 "The label"): an ATTRIB tagged `UNIT`
// owned by the unit's instance, its text the label, anchored at the
// definition's base point and stamped so it reads upright and unmirrored in
// the world whatever the instance's rotation and mirror. Ported from
// jet_cad_floor_plan's tables/table_label.dart (spec 14a T2, T8, T10): the
// tag, the height rule, the stamp, the text attributes and the payload; the
// height now reads the top's box. unitLabelAttrib is new: a kit's
// parametric type gives a generated unit its label with it (E5).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The tag of the ATTRIB that holds a unit's label (today's `TABLE`).
const String kUnitLabelTag = 'UNIT';

/// The label's height on a top whose smaller side is 500 and more, in
/// drawing units (T8).
const double kUnitLabelMaxHeight = 200;

/// The share of the top's smaller side a label may take (T8).
const double kUnitLabelTopShare = 0.4;

/// `min(200, 0.4 × min(w, h))`, where `w × h` is [top], the served top's
/// box in definition space (`SymbolDefinitionRef.top`). An empty [top] (no
/// served top) gives the full height: today's rule for a definition whose
/// first leaf is neither a closed polyline nor a circle.
double unitLabelHeight(Aabb2 top) {
  if (top.isEmpty) return kUnitLabelMaxHeight;
  final side = math.min(top.maxX - top.minX, top.maxY - top.minY);
  return math.min(kUnitLabelMaxHeight, kUnitLabelTopShare * side);
}

/// The rotation and width factor that make a label owned by an instance
/// whose definition-to-world map is [instanceToWorld] read left to right,
/// unmirrored, along world +x (T10). The only place this is computed.
///
/// With the linear part's columns `(a, b)`, `(c, d)`, `φ = atan2(b, a)`:
/// a proper map (`det > 0`) takes rotation `−φ` and width factor `+1`; a
/// mirrored one takes `φ + π` and `−1`, since a reflection is
/// `R(φ) · diag(1, −1)` and the text's own map is `R(rot) · diag(wf, 1)`.
/// The rotation is normalised to `(−π, π]`, and `0.0` is stored for `−0.0`.
({double rotation, double widthFactor}) unitLabelStamp(
    Transform2 instanceToWorld) {
  final phi = math.atan2(instanceToWorld.b, instanceToWorld.a);
  final det = instanceToWorld.a * instanceToWorld.d -
      instanceToWorld.b * instanceToWorld.c;
  final mirrored = det < 0;
  var rotation = mirrored ? phi + math.pi : -phi;
  if (rotation > math.pi) rotation -= 2 * math.pi;
  if (rotation <= -math.pi) rotation += 2 * math.pi;
  if (rotation == 0) rotation = 0.0;
  return (rotation: rotation, widthFactor: mirrored ? -1.0 : 1.0);
}

/// `textAttrs` of every unit label: centred on its anchor both ways, the
/// width factor its own (bit 8), so a mirror can be undone by `−1`.
final int kUnitLabelTextAttrs = packTextAttrs(
    h: TextJustifyH.centre, v: TextJustifyV.middle, overrideWidthFactor: true);

/// The label payload, in definition space: [anchor], then
/// `[height, rotation, widthFactor]` stamped for [instanceToWorld].
GeometryPayload unitLabelPayload(
    {required Vector2 anchor,
    required double height,
    required Transform2 instanceToWorld}) {
  final s = unitLabelStamp(instanceToWorld);
  return GeometryPayload(
    coords: Float64List.fromList([anchor.x, anchor.y]),
    scalars: Float64List.fromList([height, s.rotation, s.widthFactor]),
  );
}

/// A generated unit's label (spec 2b S2, E5): [text] tagged
/// [kUnitLabelTag], anchored at [anchor] (the definition's base point),
/// its height from [top] (the definition's top box) and its stamp from
/// [instanceToWorld] (the object's world map times the instance's
/// transform, `view.toWorld(self).multiply(instanceTransform)`). The
/// payload is in the instance's local (definition) space, so a kit never
/// re-derives it. The text is not checked: a label outside the text rule
/// is the plan library's `unit.bad_label`.
GeneratedAttrib unitLabelAttrib(String text,
        {required Transform2 instanceToWorld,
        required Vector2 anchor,
        required Aabb2 top}) =>
    GeneratedAttrib(
        kUnitLabelTag,
        text,
        unitLabelPayload(
            anchor: anchor,
            height: unitLabelHeight(top),
            instanceToWorld: instanceToWorld),
        textAttrs: kUnitLabelTextAttrs);
```

- [ ] **Step 9: Host words.** Create `packages/jet_cad_2d_kit/lib/src/kit/host_words.dart`:

```dart
// A host's words (spec 2b S4 "Words"): the KitNames a host gives
// PlanController(words:), merged before each kit's own. Checked here, so
// the plan library refuses a word no kit could ever read.
//
// Pure Dart: no Flutter, no dart:io.
import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';

/// The problems of a host's [words], in their order (locale, then word
/// id): an id in no known namespace (`symbol:`, `category:`, `tool:`,
/// `type:`, `property:`, `unit:`) is [KitProblemCode.unknownWordId]; one
/// that names no kit is [KitProblemCode.foreignWordId]. Any kit will do: a
/// host's word may be for a kit it has not loaded. A `category:` or `unit:`
/// id names its kit before a `/`, the others before their first `.`.
/// Empty when sound.
List<KitProblem> validateHostWords(KitNames words) {
  final problems = <KitProblem>[];
  for (final MapEntry(key: locale, value: map) in words.words.entries) {
    for (final wordId in map.keys) {
      final colon = wordId.indexOf(':');
      final namespace = colon < 0 ? '' : wordId.substring(0, colon);
      final rest = wordId.substring(colon + 1);
      final bool named;
      switch (namespace) {
        case 'category' || 'unit':
          final slash = rest.indexOf('/');
          named = slash > 0 && isKitId(rest.substring(0, slash));
        case 'symbol' || 'tool' || 'type' || 'property':
          named = rest.contains('.') && isKitId(kitOfKey(rest));
        default:
          problems.add(KitProblem(KitProblemCode.unknownWordId,
              '$locale: "$wordId" is in no known namespace'));
          continue;
      }
      if (!named) {
        problems.add(KitProblem(
            KitProblemCode.foreignWordId, '$locale: "$wordId" names no kit'));
      }
    }
  }
  return problems;
}
```

- [ ] **Step 10: The gate, the namespace, the code, the docs.**
  1. `lib/src/kit/properties.dart`: `PlanGate` gains, after `editPage,`:

```dart
  /// A unit's label (spec 2b S4; today's `renumber`).
  relabel,
```

  2. `lib/src/kit/plan_kit.dart`: in `validate`, `case 'category':` (line 80) becomes `case 'category' || 'unit':`. The doc of `validate` (lines 54-58) reads: `/// The descriptor's problems: a bad id, an empty version, a word under another kit's id or in no known namespace (a `category:` or `unit:` word names the kit before its `/`); a type or tool id ...` (rest unchanged).
  3. `lib/src/model/kit_problem.dart`: after `typePlaceConflict,` add:

```dart
  // Spec 2b S4: conformance, a unit kind the contract does not name with no
  // English `unit:<kit>/<kind>` word.
  unitKindWord,
```

  4. `lib/src/model/kit_names.dart`: the class doc (lines 9-12) becomes:

```dart
/// A kit's words by locale. Word ids: `symbol:<key>`,
/// `category:<kit id>/<English category>`, sub-project 2's
/// `tool:<tool id>`, `type:<type id>`, `property:<type id>.<property>`, and
/// 2b's `unit:<kit id>/<unit kind>`. Every id carries its kit's id, so two
/// kits never share one.
```

  5. `lib/src/model/unit_component.dart`: `assigned`'s doc (line 18) becomes:

```dart
  /// The label comes from a kit's type (a seat in a row), the property
  /// panel or the host; the plan gives no number.
  assigned,
```

  6. `lib/src/authoring/conformance.dart`: add `import '../model/unit_component.dart' show UnitKinds;` (sorted after `symbol_library.dart`); in `conformance`, the problems cascade (lines 75-78) becomes:

```dart
  problems
    ..addAll(_snapshotProblems(catalog, committedSnapshot))
    ..addAll(code.problems)
    ..addAll(_unitKindProblems(catalog, names))
    ..addAll(_wordProblems(catalog, names, locales, sameAsEnglish, code.words));
```

     and add after `_codeIds`:

```dart
/// Spec 2b S4: every unit kind the catalog carries that the contract does
/// not name ([UnitKinds]) has an English `unit:<kit>/<kind>` word; one
/// problem per kind. The declared locales are not held to it.
List<KitProblem> _unitKindProblems(Catalog catalog, KitNames names) {
  final english = names.words[KitNames.english] ?? const <String, String>{};
  final problems = <KitProblem>[];
  final asked = <String>{};
  for (final s in catalog.symbols) {
    final kind = s.unit?.kind;
    if (kind == null || kind == UnitKinds.table || kind == UnitKinds.seat) {
      continue;
    }
    final wordId = 'unit:${catalog.kit}/$kind';
    if (asked.add(wordId) && !english.containsKey(wordId)) {
      problems.add(KitProblem(
          KitProblemCode.unitKindWord,
          '"$wordId" has no English word: the unit kind "$kind" is not one '
          'the contract names'));
    }
  }
  return problems;
}
```

     The function's doc (before `List<KitProblem> conformance(`) gains a paragraph after the code-side one: `/// A unit kind the contract does not name ([UnitKinds]) needs an English /// `unit:<kit>/<kind>` word ([KitProblemCode.unitKindWord], spec 2b S4).`
  7. `lib/jet_cad_2d_kit.dart`: add, in order, `export 'src/kit/host_words.dart';` (after `colour.dart`), `export 'src/kit/symbols_state.dart';` and `export 'src/kit/unit_label.dart';` (after `symbol_library_source.dart`).
  8. `CHANGELOG.md`: under `## 0.1.0` (the unreleased version), append:

```markdown
- Sub-project 2b: `PlanServices.symbolDefinition` (`SymbolDefinitionRef`)
  and `symbolsState`; `SymbolsState`, moved from the plan library; a unit's
  label (`kUnitLabelTag`, `unitLabelHeight`, `unitLabelStamp`,
  `unitLabelPayload`, `unitLabelAttrib`, which builds a generated unit's
  label as an E5 `GeneratedAttrib`); `PlanGate.relabel`; the `unit:` word
  namespace and `validateHostWords`; `KitProblemCode.unitKindWord`, which
  conformance reports for a unit kind the contract does not name without
  an English word. `UnitLabelling.assigned`: the label comes from a kit's
  type, the property panel or the host.
```

- [ ] **Step 11: Run the kit's tests.** `cd packages/jet_cad_2d_kit && dart format . && flutter test`. Expected: `All tests passed!`.

- [ ] **Step 12: The plan library follows.** Run `cd packages/jet_cad_2d_plan && flutter analyze`. Expected: errors — `The type 'PlanGate' is not exhaustively matched by the switch cases since it doesn't match 'PlanGate.relabel'` (`permissions.dart:72`), and `Missing concrete implementations of 'PlanServices.symbolDefinition' and 'getter PlanServices.symbolsState'` (`services.dart:21`).
  1. `test/controller/permissions_test.dart` first (its failing form): `kFlagNames` gains `'relabel',` after `'editPage',`; `flagsOf` gains `'relabel': p.relabel,` after `editPage`; `copyFlag` gains `'relabel' => p.copyWith(relabel: v),` after `editPage`; `kGateFlag` gains `PlanGate.relabel: 'relabel',`; `kReadOnly` gains `'relabel': false,` after `editPage`; PM-6's `for (final name in kFlagNames.take(9))` → `take(10)` and its comment `// move .. relabel: each alone is an edit.`; PM-6's `everyTool` gains `relabel: false,` after `editPage: false`; PM-7's `readOnly` string becomes `'PlanPermissions(tools: {plan.select}, move: false, rotate: false, mirror: false, reshape: false, delete: false, changeLayer: false, recolor: false, editLayers: false, editPage: false, relabel: false, undo: false)'` (split over lines as now). No other assertion changes.
  2. `lib/src/controller/permissions.dart`:
     - the class doc's bullet list gains `/// - [relabel]: a unit's label field (2b's unit section) and the property specs gated by it.` after the `[editLayers], [editPage]` bullet, and "A property spec's `gate` names one of the first nine" → "one of the first ten";
     - constructor: `this.relabel = true,` after `this.editPage = true,`;
     - `readOnly`: `relabel: false,` after `editPage: false,`;
     - fields: `final bool changeLayer, recolor, editLayers, editPage, relabel;`;
     - `allows`: `PlanGate.relabel => relabel,` after the `editPage` arm;
     - `edits`: `relabel ||` after `editPage ||`;
     - `copyWith`: parameter `bool? relabel,` after `editPage`, and `relabel: relabel ?? this.relabel,` after `editPage:`;
     - `_flags`: `('relabel', relabel),` after `('editPage', editPage),`.
  3. `lib/src/controller/services.dart`, at the end of `KitServices`:

```dart
  // Spec 2b S2. Task 4 implements both; no kit calls them before it.
  @override
  SymbolDefinitionRef? symbolDefinition(String key) =>
      throw UnimplementedError('KitServices.symbolDefinition (2b Task 4)');

  @override
  ValueListenable<SymbolsState> get symbolsState =>
      throw UnimplementedError('KitServices.symbolsState (2b Task 4)');
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/controller/permissions_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 13: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0 (the kit names neither the plan library nor a kit).
  - `git status --short`: only this task's files (no `analysis_options.yaml`).

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/lib/src/kit/symbols_state.dart packages/jet_cad_2d_kit/lib/src/kit/plan_services.dart packages/jet_cad_2d_kit/lib/src/kit/unit_label.dart packages/jet_cad_2d_kit/lib/src/kit/host_words.dart packages/jet_cad_2d_kit/lib/src/kit/properties.dart packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart packages/jet_cad_2d_kit/lib/src/model/kit_problem.dart packages/jet_cad_2d_kit/lib/src/model/kit_names.dart packages/jet_cad_2d_kit/lib/src/model/unit_component.dart packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_kit/test/support/placements.dart packages/jet_cad_2d_kit/test/kit/unit_label_test.dart packages/jet_cad_2d_kit/test/kit/host_words_test.dart packages/jet_cad_2d_kit/test/kit/plan_kit_test.dart packages/jet_cad_2d_kit/test/kit/plan_services_test.dart packages/jet_cad_2d_kit/test/kit/properties_test.dart packages/jet_cad_2d_kit/test/authoring/conformance_test.dart packages/jet_cad_2d_kit/test/invariants/purity_test.dart packages/jet_cad_2d_plan/lib/src/controller/permissions.dart packages/jet_cad_2d_plan/lib/src/controller/services.dart packages/jet_cad_2d_plan/test/controller/permissions_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the contract's 2b additions (spec 2b S2, S4)

PlanServices gains symbolDefinition and symbolsState (SymbolsState moves
into the contract); a unit's label stamp, height and payload are the
contract's, and unitLabelAttrib builds a generated unit's label. PlanGate
gains relabel (the plan library's permissions follow), the words gain the
unit: namespace, validateHostWords checks a host's words, and
conformance asks an English word for a unit kind the contract does not
name.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests run with `cd packages/jet_cad_2d_kit && flutter test <file>`; the plan library's with `cd packages/jet_cad_2d_plan && flutter test <file>`.
  - M-K2B-1 `jet_cad_2d_kit/lib/src/kit/unit_label.dart`: in `unitLabelPayload`, `unitLabelStamp(instanceToWorld)` → `unitLabelStamp(Transform2.identity())` (`transform2.dart:33`) → K2B-payload red.
  - M-K2B-2 `unit_label.dart`: `kUnitLabelTag,` in `unitLabelAttrib` → `'',` → K2B-attrib red.
  - M-K2B-3 `unit_label.dart`: delete `textAttrs: kUnitLabelTextAttrs` from `unitLabelAttrib` → K2B-attrib red.
  - M-K2B-4 `unit_label.dart`: in `unitLabelAttrib`, `anchor: anchor,` → `anchor: instanceToWorld.transformPoint(anchor),` → K2B-attrib red.
  - M-K2B-5 `unit_label.dart`: in `unitLabelAttrib`, `instanceToWorld: instanceToWorld` → `instanceToWorld: Transform2.scale(-1, 1)` (a stamp for another map) → K2B-attrib red (not upright).
  - M-K2B-6 `unit_label.dart`: delete `if (top.isEmpty) return kUnitLabelMaxHeight;` → K2B-attrib-empty and TL4 red.
  - M-K2B-stamp `unit_label.dart`: `mirrored ? phi + math.pi : -phi` → `-phi` → TL1 red (every mirrored case).
  - M-K2B-height `unit_label.dart`: `math.min(top.maxX - top.minX, top.maxY - top.minY)` → `math.max(...)` → TL4 red.
  - M-K2B-7 `jet_cad_2d_kit/lib/src/kit/host_words.dart`: `case 'category' || 'unit':` → `case 'category':` → K2B-host-1 red.
  - M-K2B-8 `host_words.dart`: the `default:` branch's `problems.add(...)` deleted (keep `continue;`) → K2B-host-2 red.
  - M-K2B-9 `host_words.dart`: both `named = ...` → `named = true` → K2B-host-3 red.
  - M-K2B-10 `jet_cad_2d_kit/lib/src/kit/plan_kit.dart`: `case 'category' || 'unit':` → `case 'category':` → K2B-validate red.
  - M-K2B-11 `plan_kit.dart`: move `'unit'` to the dot branch (`case 'symbol' || 'tool' || 'type' || 'property' || 'unit':`, the slash branch `case 'category':`) → K2B-validate red.
  - M-K2B-12 `jet_cad_2d_kit/lib/src/authoring/conformance.dart`: delete `..addAll(_unitKindProblems(catalog, names))` → K2B-conf red.
  - M-K2B-13 `conformance.dart`: `asked.add(wordId) &&` deleted → K2B-conf red (two problems).
  - M-K2B-14 `conformance.dart`: `|| kind == UnitKinds.table || kind == UnitKinds.seat` deleted → F0 red.
  - M-K2B-15 `unit_label.dart`: add `import 'package:flutter/foundation.dart';` → K2B-pure red.
  - M-K2B-16 `jet_cad_2d_plan/lib/src/controller/permissions.dart`: `PlanGate.relabel => relabel,` → `PlanGate.relabel => editPage,` → PM-5 red.
  - M-K2B-17 `permissions.dart`: delete `relabel: false,` from `readOnly` → PM-1 red.
  - M-K2B-18 `permissions.dart`: delete `('relabel', relabel),` from `_flags` → PM-3 red (`==` ignores relabel).

  Quote each red line.

#### Assumed from earlier tasks

- Task 1: `GeneratedAttrib` as in the Shared interfaces, exported from `package:jet_cad_2d/jet_cad_2d.dart`, its constructor throwing only for an empty tag.
- Task 1 leaves `jet_cad_2d_plan` compiling: it adds the `GuardedType.instances` forwarder to `guard.dart` (controller ruling R-1).

#### Interface problem

Resolved by R-1 (Task 1 adds the `GuardedType.instances` forwarder and runs the plan library's gates; Task 4 keeps only PB-guard).

---

