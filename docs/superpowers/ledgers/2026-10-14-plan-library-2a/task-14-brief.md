### Task 14: Attachment, `plan.symbol` and the move resolver (spec P3 "Attachment")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/attach/attachment_registry.dart` (`PlanAttachmentRegistry`)
- Create: `packages/jet_cad_2d_plan/lib/src/attach/attachment_painter.dart` (`paintAttachmentMarker`)
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart` (port + `footprintOf`)
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/symbol_ghost.dart` (port)
- Create: `packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart` (`PlanSymbolTool`, `kAttachPixels`, `kGhostCrossPixels`)
- Create: `packages/jet_cad_2d_plan/lib/src/tools/move_resolver.dart` (`PlanMoveResolver`, `isOrthonormal`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` and `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (Task 8 keeps the per-document build and teardown in `DocumentSession`: `session.dart` gains `runAttachmentFactories`, `addSymbolTool`, `symbolTool`, the constructor's `moveResolver` and the registry's disposal in `disposeKitProducts`; `plan_controller.dart` gains `_moveResolver`, the `_open` calls, `_allowsTool`'s armed check, the unoffered-kind diagnostic)
- Test support: `packages/jet_cad_2d_plan/test/support/attach_fixtures.dart` (new)
- Test: `test/attach/attachment_registry_test.dart`, `test/symbols/symbol_box_test.dart` (port), `test/symbols/symbol_ghost_test.dart` (port), `test/tools/plan_symbol_tool_test.dart` (port + new), `test/tools/move_resolver_test.dart`, `test/controller/attachment_controller_test.dart`; add the highlight test to `test/panels/plan_symbol_gallery_test.dart` (Task 13's file)

(Paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root.)

**Interfaces:**
- Consumes:
  - Task 4 (`package:jet_cad_2d_kit/jet_cad_2d_kit.dart`): `AttachmentProvider` (`kind`, `attach`), `AttachmentQuery`, `Attachment`, `AttachmentRegistry` (`attach`, `kinds`), `PlanServices`, `PlanKit.attachments` (`List<AttachmentProvider Function(PlanServices)>`), `KitDiagnostic`, `KitDiagnosticCode.hookFailed`, `.attachmentKindUnoffered`.
  - Task 13: `PlanSymbol`, `placeSymbol`, `placementTransform`, `PlanController.armedSymbol` / `armSymbol` / `symbols`, the symbol fixtures.
  - Task 12: `PlanToolIds`, `buildGenericTools(moveResolver:)`, `registerToolNeeds`, the permissions setter, `test/support/tool_events.dart`.
  - Task 11: the guarded tool wrapping (`GuardedTool` at build time: `plan.symbol` is wrapped like every tool); `guardAttachment`.
  - `MoveResolver`, `Tool`, `ToolContext`, `ToolPointerEvent`, `drawSnapMarker`, `resolveDragPoint`, `DragPoint`, `SnapResult`, `dragGridStepMm`, `kSnapMarkerStrokePixels`, `kPreviewStrokePixels`, `PaperPalette`, `ViewportTransform` from `jet_cad_2d_flutter`; `Aabb2`, `Transform2`, `SnapKind`, `kSnapAperturePixels` from `jet_cad_2d`.
- Produces (all internal; nothing new is exported):
  - `final class PlanAttachmentRegistry implements AttachmentRegistry` — `PlanAttachmentRegistry({required void Function(KitDiagnostic diagnostic) report})`; `void add(String kitId, AttachmentProvider Function(PlanServices) factory, PlanServices services)`; `Set<String> get kinds`; `Attachment? attach(List<String> kinds, AttachmentQuery query)`; `void dispose()`.
  - `void paintAttachmentMarker(Canvas canvas, ViewportTransform camera, Vector2 marker, Paint paint)`.
  - `class PlanSymbolTool extends Tool` — `PlanSymbolTool(ValueListenable<PlanSymbol?> armed, {AttachmentRegistry? attachments, bool Function()? canRotate, bool Function()? canMirror})`.
  - `final class PlanMoveResolver implements MoveResolver` — `PlanMoveResolver({required AttachmentRegistry Function() attachments, bool Function()? canRotate})`.
  - `SymbolBox`, `boxOfLeaves`, `boxOfEntry`, `boxOfDefinition` (ported), `Aabb2 footprintOf(SymbolBox box)`; `ghostPathFor`, `GhostMatrix`, `writeGhostMatrix`, `identityGhostMatrix` (ported).

Plan decision (`keep`, spec P3 "the previous answer (hysteresis)"): the registry remembers which provider made each `Attachment` it returned and hands a query's `keep` only to that provider; every other provider is asked with `keep: null`. A provider then never sees another's token, and two kits offering the same kind cannot confuse each other. The tool's `keep` is its last answer, cleared when the armed symbol changes; the move resolver's is its last answer for the same node while the document's `stateId` is unchanged (one drag).

Plan decision (the winner): every asked provider answers; the marker nearest the raw pointer (`query.pointer`) wins, squared distances compared exactly; on a tie the earlier wins (kinds in the symbol's `attachTo` order, then providers in kit load order).

Plan decision (the move's pointer): `MoveResolver.resolveMove` receives no pointer (`select_tool.dart:36-42`), so the move query's `pointer` is the plain-moved footprint's back-centre, local `((minX + maxX) / 2, maxY)`, today's anchor (`symbol_move.dart:50-52`, spec 09c D8: "anchored on its plain-moved back-centre, so a drag along the wall stays on the face"); `current` is the plain-moved transform `delta · T`; `exclude` holds the node.

Plan decision (the guard): an `AttachmentProvider.attach` that throws is taken as no attachment and reports `KitDiagnostic(hookFailed, subject: <kind>)` through the controller's log, which keeps one per kit, subject and code (spec P4 table). A factory that throws adds no provider and reports `hookFailed` with subject `attachments`. `PlanAttachmentRegistry._ask` calls Task 11's `guardAttachment(kitId, provider, query, report)` (`lib/src/kits/guard.dart`) with the registry's `report`; the factory's try/catch sits in `add`. AT-5 and AT-9 pin the behaviour.

Plan decision (no `WallFaces`): the tool and the resolver know no wall (spec P3 "Who uses it"). Today's band invalidation after a placement (`symbol_place_tool.dart:500`) is the wall-face provider's business (sub-project 3): a provider that caches reads `document.commands.stateId`.

Ported (assertions unchanged; fixtures, names and imports adapted):

| Source | Tests | Destination |
|---|---|---|
| `jet_cad_floor_plan/test/symbols/symbol_place_tool_test.dart:440-1366, 1742-1804` | the fixture test; the groups pointer, snap, the ghost, keys, permissions; SP-T1; the camera; the paper set | `test/tools/plan_symbol_tool_test.dart` |
| `test/symbols/symbol_ghost_test.dart` (whole) | every test | `test/symbols/symbol_ghost_test.dart` |
| `test/symbols/symbol_box_test.dart:122-319, 341-368, 371-389, 412-435` | `SymbolBox`, `boxOfLeaves`, arcs by their true extents, "the off-centre fixtures", "memoised per entry", "a placed definition gives the same box as its entry", "not a definition … no box" | `test/symbols/symbol_box_test.dart` |
| `test/symbols/symbol_panel_test.dart:505-532` | "the highlight follows the active tool and the armed entry (M-09b9)" | `test/panels/plan_symbol_gallery_test.dart` |

Not ported: `symbol_place_tool_test.dart:1368-1740` (the wall attachment) and `symbol_move_test.dart`, `wall_attach_test.dart`, `wall_faces_test.dart`, `wall_attach_property_test.dart`: they move with the wall-face provider to sub-project 3 (spec P3 "Tests"); AT and MV tests below cover the registry, the tool's and the resolver's side. `symbol_box_test.dart:321-339, 391-410` pin the furniture asset's literal boxes (the asset moves with its kit).

- [ ] **Step 1: The attachment fixtures.** Create `test/support/attach_fixtures.dart`:

```dart
// Attachment providers for tests (Task 14): scripted answers, recorded
// queries, a provider that throws and one that is Disposable. The
// geometry of a real provider (a wall face) is a kit's (sub-project 3);
// here only the plan library's plumbing is under test.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
// Disposable is the kit's (jet_cad_2d_kit, Task 4; controller ruling
// R-d), imported above.
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// An attachment: [transform], its [marker], and a [token].
Attachment attachment(Transform2 transform, Vector2 marker, Object token) =>
    Attachment(transform: transform, marker: marker, token: token);

/// Answers with [answer] and records every query.
final class RecordingProvider implements AttachmentProvider {
  RecordingProvider(this.kind, this.answer);

  @override
  final String kind;

  Attachment? Function(AttachmentQuery query) answer;
  final List<AttachmentQuery> queries = [];

  @override
  Attachment? attach(AttachmentQuery query) {
    queries.add(query);
    return answer(query);
  }
}

/// Throws on every query.
final class ThrowingProvider implements AttachmentProvider {
  ThrowingProvider(this.kind);

  @override
  final String kind;
  int calls = 0;

  @override
  Attachment? attach(AttachmentQuery query) {
    calls++;
    throw StateError('the $kind provider broke');
  }
}

/// A provider with a dispose (the kit's Disposable, Task 4).
final class DisposableProvider extends RecordingProvider implements Disposable {
  DisposableProvider(super.kind, super.answer);

  int disposals = 0;

  @override
  void dispose() => disposals++;
}

/// A query near the fixtures' world (off the origin, a turned current).
AttachmentQuery queryAt(Vector2 pointer,
        {Attachment? keep,
        bool mayRotate = true,
        bool mirrored = false,
        Set<Handle> exclude = const {}}) =>
    AttachmentQuery(
      footprint: const Aabb2.raw(150, 210, 1750, 960),
      current: Transform2.translation(pointer.x, pointer.y)
          .multiply(Transform2.rotation(0.4)),
      pointer: pointer,
      capture: 160,
      edgeCapture: 100,
      mirrored: mirrored,
      mayRotate: mayRotate,
      exclude: exclude,
      keep: keep,
    );
```

- [ ] **Step 2: Write the failing registry tests.** Create `test/attach/attachment_registry_test.dart`:

```dart
// Spec P3 "Attachment" (Task 14): the registry asks the providers of every
// kind the symbol attaches to; the marker nearest the pointer wins; a
// keep goes back to the provider that made it; a throwing provider is no
// attachment and one diagnostic. Fixtures off the origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/attach/attachment_registry.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';

final Vector2 p = Vector2(41250.5, -17320.25);

final class _NoServices implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}

final class Rig {
  final List<KitDiagnostic> reported = [];
  late final PlanAttachmentRegistry registry =
      PlanAttachmentRegistry(report: reported.add);
  final PlanServices services = _NoServices();

  void add(String kit, AttachmentProvider provider) =>
      registry.add(kit, (_) => provider, services);
}

Attachment at(double dx, double dy, Object token) => attachment(
    Transform2.translation(p.x + dx, p.y + dy), p + Vector2(dx, dy), token);

void main() {
  test('AT-1 kinds: every provider\'s kind, once', () {
    final r = Rig()
      ..add('alpha', RecordingProvider('wall-face', (_) => null))
      ..add('beta', RecordingProvider('wall-face', (_) => null))
      ..add('beta', RecordingProvider('room-corner', (_) => null));
    expect(r.registry.kinds, {'wall-face', 'room-corner'});
    expect(() => r.registry.kinds.add('x'), throwsUnsupportedError);
  });

  test(
      'AT-2 the marker nearest the pointer wins across kinds and providers; '
      'a tie goes to the earlier', () {
    final r = Rig();
    final far = RecordingProvider('wall-face', (_) => at(300, 0, 'far'));
    final near = RecordingProvider('room-corner', (_) => at(0, -120, 'near'));
    final same = RecordingProvider('room-corner', (_) => at(120, 0, 'tie'));
    r
      ..add('alpha', far)
      ..add('beta', near)
      ..add('beta', same);
    // M-AT2a: the first non-null answer wins.
    expect(r.registry.attach(['wall-face', 'room-corner'], queryAt(p))!.token,
        'near');
    expect(far.queries, hasLength(1));
    expect(same.queries, hasLength(1));
    // 'near' (0, -120) and 'tie' (120, 0) are equally far: the earlier
    // provider wins. M-AT2b: `<` written `<=` (the later wins).
    expect(
        r.registry.attach(['room-corner', 'wall-face'], queryAt(p))!.token,
        'near');
  });

  test('AT-3 only the asked kinds\' providers are asked; none is null', () {
    final r = Rig();
    final wall = RecordingProvider('wall-face', (_) => at(10, 0, 'w'));
    final corner = RecordingProvider('room-corner', (_) => at(5, 0, 'c'));
    r
      ..add('alpha', wall)
      ..add('alpha', corner);
    // M-AT3: every provider asked whatever the kinds.
    expect(r.registry.attach(['wall-face'], queryAt(p))!.token, 'w');
    expect(corner.queries, isEmpty);
    expect(r.registry.attach(['ceiling'], queryAt(p)), isNull);
    expect(r.registry.attach(const [], queryAt(p)), isNull);
  });

  test(
      'AT-4 a keep goes only to the provider that made it; the others are '
      'asked without one', () {
    final r = Rig();
    final a = RecordingProvider('wall-face', (_) => at(10, 0, 'a'));
    final b = RecordingProvider('wall-face', (_) => at(400, 0, 'b'));
    r
      ..add('alpha', a)
      ..add('beta', b);
    final first = r.registry.attach(['wall-face'], queryAt(p))!;
    expect(first.token, 'a');
    r.registry.attach(['wall-face'], queryAt(p, keep: first));
    // M-AT4: the query passed on unchanged.
    expect(a.queries.last.keep, same(first));
    expect(b.queries.last.keep, isNull);
    // Every other field reaches the provider asked without the keep.
    final q = b.queries.last;
    expect(q.pointer, p);
    expect(q.capture, 160);
    expect(q.edgeCapture, 100);
    expect(q.footprint.maxX, 1750);
    // A keep no provider of this registry made reaches none.
    final foreign = at(1, 1, 'foreign');
    r.registry.attach(['wall-face'], queryAt(p, keep: foreign));
    expect(a.queries.last.keep, isNull);
    expect(b.queries.last.keep, isNull);
  });

  test(
      'AT-5 a throwing provider is no attachment and a hookFailed; the '
      'others still answer', () {
    final r = Rig();
    final broken = ThrowingProvider('wall-face');
    r
      ..add('alpha', broken)
      ..add('beta', RecordingProvider('wall-face', (_) => at(50, 0, 'ok')));
    // M-AT5: `_ask` calling the provider bare (the error escapes).
    expect(r.registry.attach(['wall-face'], queryAt(p))!.token, 'ok');
    expect(broken.calls, 1);
    expect([for (final d in r.reported) (d.kitId, d.subject, d.code)],
        [('alpha', 'wall-face', KitDiagnosticCode.hookFailed)]);
    expect(r.reported.single.error, isA<StateError>());
  });

  test('AT-6 dispose disposes the Disposable providers and empties it', () {
    final r = Rig();
    final d = DisposableProvider('wall-face', (_) => null);
    r
      ..add('alpha', d)
      ..add('alpha', RecordingProvider('room-corner', (_) => null));
    r.registry.dispose();
    // M-AT6: dispose leaves the providers alone.
    expect(d.disposals, 1);
    expect(r.registry.kinds, isEmpty);
  });

  test('AT-7 a factory that throws adds nothing and reports hookFailed', () {
    final r = Rig();
    r.registry.add('alpha', (_) => throw ArgumentError('no faces'), r.services);
    r.add('beta', RecordingProvider('room-corner', (_) => null));
    // M-AT7: `add` without its try/catch.
    expect(r.registry.kinds, {'room-corner'});
    expect([for (final d in r.reported) (d.kitId, d.subject, d.code)],
        [('alpha', 'attachments', KitDiagnosticCode.hookFailed)]);
  });
}
```

- [ ] **Step 3: Port the box and ghost tests.**
  - `test/symbols/symbol_box_test.dart`: copy the ranges named in the table, with the helpers they use from `:1-121` (`cx`, `cy`, `r`, `arc`, `boxOfArc`, `ends`, `near`, `target()`, `definitionOf`; drop `assetLibrary` and the catalog's literal boxes). Adaptations: imports → `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `package:jet_cad_2d_plan/src/symbols/symbol_box.dart`, `package:jet_cad_2d_plan/src/symbols/symbol_placer.dart`, `../support/symbol_fixtures.dart`; `registerAppComponents` → `registerKitComponents` in `target()`; the library is `SymbolLibrary.decode(bytesOf(buildValidLibrary()))`; `entryIn(lib, key)` reads `e.symbol.key`; key literals gain the kit id (`'sofa.three'` → `'fixture.sofa.three'`, `'armchair.single'` → `'fixture.armchair.single'`, `'nightstand.single'` → `'fixture.nightstand.single'`); "memoised per entry" uses `fixture.sofa.three` for the toilet and `fixture.armchair.single` for the tub; "a placed definition gives the same box" uses the three fixture keys for its four asset keys (`quarterTurns: i + 1`, `mirrored: i.isOdd` as before); `definitionOf` matches `SymbolComponent.key` against the prefixed key.
  - `test/symbols/symbol_ghost_test.dart`: copy the whole file. Adaptations: imports → the kit, `package:jet_cad_2d_plan/src/symbols/symbol_ghost.dart`, `…/symbol_placer.dart`, `../support/symbol_fixtures.dart`; `library` is `SymbolLibrary.decode(bytesOf(buildValidLibrary()))`; `entry(key)` reads `e.symbol.key`; `keys` (`:91`) becomes `['fixture.sofa.three', 'fixture.nightstand.single', 'fixture.armchair.single']` and every other asset key literal maps in the same order (`office.chair` → `fixture.sofa.three`, `bath.toilet` → `fixture.nightstand.single`, `dining.table.rect.six` → `fixture.armchair.single`).
  - A ported assertion that fails after these adaptations is a finding: stop and report it.

- [ ] **Step 4: Port the placement tool tests.** Create `test/tools/plan_symbol_tool_test.dart` from `symbol_place_tool_test.dart` `:1-438` (the header, the rig and the helpers, adapted below), `:440-1366` and `:1742-1804` (assertions unchanged). Adaptations:
  - Imports: drop the planner's; add `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:jet_cad_2d_plan/src/symbols/symbol_ghost.dart`, `…/symbols/symbol_placer.dart`, `…/tools/plan_symbol_tool.dart`, `../support/symbol_fixtures.dart`, `../support/attach_fixtures.dart`; keep flutter, flutter_test, jet_cad_2d, jet_cad_2d_flutter, vector_math.
  - The entries (`:69-76`):

```dart
final SymbolLibrary library =
    SymbolLibrary.decode(bytesOf(buildValidLibrary()));

PlanSymbol entry(String key) => PlanSymbol(
    kitId: 'fixture',
    names: KitNames.empty,
    entry: library.entries.singleWhere((e) => e.symbol.key == key));

/// Today's office chair: a symbol whose base point is off its leaves.
final PlanSymbol chair = entry('fixture.sofa.three');

/// Today's toilet: the second symbol a re-arm swaps to.
final PlanSymbol toilet = entry('fixture.nightstand.single');
```

  - Accessors over a symbol: `chair.definition` → `chair.entry.definition` (and for `toilet`, `e`); `ghostPathFor(x)` → `ghostPathFor(x.entry)`; `toilet.key` → `toilet.component.key`.
  - The rig (`:96-170`): no walls. Replace the constructor and the fields it sets with:

```dart
  Rig(
      {bool page = true,
      bool? objectSnap,
      double? step = gridStep,
      AttachmentRegistry? attachments,
      bool Function()? canRotate,
      bool Function()? canMirror}) {
    document = DraftDocument.empty(measurer: const InsertionPointMeasurer());
    registerKitComponents(document.components);
    document.header.units = DrawingUnits.millimeters;
    if (page) {
      document.commands.execute(SetComponentCommand<PageComponent>(
          document.rootHandle,
          PageComponent(
              originX: gridOriginX, originY: gridOriginY, gridStepMm: step)));
    }
    document.commands.execute(addDrafted(
        document, EntityKind.line, linePayload(e0, e0 + Vector2(1200, 700)),
        layer: ReservedHandles.layerZero));
    document.commands.clearHistory();
    index = SpatialIndex(document);
    final linear = Transform2.scale(scale, -scale);
    final mid = linear.transformPoint(Vector2(76000, -41000));
    camera = CountingCamera(ViewportTransform(
        worldToScreenMatrix:
            Transform2.translation(400 - mid.x, 300 - mid.y).multiply(linear)));
    selection = SelectionController(document);
    pages = PageNotifier(document);
    snap = objectSnap == null ? null : SnapSettings(objectSnap: objectSnap);
    ctx = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: pages,
        snap: snap);
    armed = CountingNotifier(chair);
    tool = PlanSymbolTool(armed,
        attachments: attachments, canRotate: canRotate, canMirror: canMirror);
    tool.addListener(() => notifications.add(tool.isMidShape));
    addTearDown(() {
      if (!disposed) tool.dispose();
      armed.dispose();
      pages.dispose();
      snap?.dispose();
      selection.dispose();
      camera.dispose();
      index.dispose();
    });
  }
```

    and drop the fields `bands`, `wallFaces`, `wallHandles`. `CountingNotifier` (`:209-224`) extends `ValueNotifier<PlanSymbol?>`. `late final SymbolPlaceTool tool` → `late final PlanSymbolTool tool`.
  - Drop `:366-438` (the wall attachment's fixtures and the `runOn` / `attachOf` / `freeOf` extension); keep `linear` (`:362-363`).
  - In the ported tests the class name `SymbolPlaceTool` becomes `PlanSymbolTool`; `kGhostCrossPixels` comes from `plan_symbol_tool.dart`.

  Then add, in the same file, the attachment tests:

```dart
  group('attachment through the registry (spec P3)', () {
    /// The demo's shelves: each attaches to a test edge or corner.
    PlanSymbol shelf([String key = 'demo.shelf.wall']) => PlanSymbol(
        kitId: 'demo',
        names: KitNames.empty,
        entry: SymbolLibrary.decode(
                encodeLibrary(Catalog(kit: 'demo', symbols: [
          box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
              attachTo: ['test-edge', 'test-corner'], base: (950, 410)),
          box('demo.shelf.high', 'High shelf', 'Storage', ['high'],
              attachTo: ['test-edge'], base: (720.25, 515.5)),
        ])))
            .entries
            .singleWhere((e) => e.symbol.key == key));

    ({Rig rig, RecordingProvider edge, PlanAttachmentRegistry registry})
        attachRig({bool rotate = true, Attachment? Function(AttachmentQuery)? answer}) {
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      final edge = RecordingProvider('test-edge', answer ?? (_) => null);
      registry.add('demo', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry, canRotate: () => rotate);
      addTearDown(registry.dispose);
      return (rig: rig, edge: edge, registry: registry);
    }

    test(
        'AT-8 an armed symbol with no attachTo never asks; with attachTo, '
        'the query carries the footprint, the free placement, the raw '
        'pointer and the captures in world units', () {
      final r = attachRig();
      r.rig.hover(pB);
      expect(r.edge.queries, isEmpty, reason: 'the sofa attaches to nothing');
      final s = shelf();
      r.rig.armed.value = s;
      r.rig.hover(pA);
      final q = r.edge.queries.last;
      // M-AT8a: the snapped point passed as the pointer.
      expect(q.pointer, pA);
      expect(gridOf(pA) == pA, isFalse, reason: 'premise: the grid moves it');
      // M-AT8b: kAttachPixels written as the snap aperture.
      expect(q.capture, closeTo(16 / scale, 1e-9));
      expect(q.edgeCapture, closeTo(kSnapAperturePixels / scale, 1e-9));
      final box = boxOfEntry(s.entry)!;
      expect([q.footprint.minX, q.footprint.minY, q.footprint.maxX,
              q.footprint.maxY],
          [box.left, box.front, box.right, box.back]);
      expect(partsOf(q.current), partsOf(placementTransform(
          at: gridOf(pA), basePoint: s.entry.definition.basePoint)));
      expect(q.mirrored, isFalse);
      expect(q.mayRotate, isTrue);
      expect(q.exclude, isEmpty);
      expect(q.keep, isNull);
    });

    test(
        'AT-9 attached: the ghost and the release use the attachment\'s '
        'transform verbatim, and the marker is drawn at its marker', () {
      final turned = Transform2.translation(81000.5, -36000.25)
          .multiply(Transform2.rotation(-1.1));
      final marker = Vector2(80990.75, -35810.5);
      final r = attachRig(answer: (_) => attachment(turned, marker, 'run-7'));
      r.rig.armed.value = shelf();
      r.rig.hover(pB);
      expect(partsOf(r.rig.tool.ghostPlacement!), partsOf(turned));
      final screen = RecordingCanvas();
      r.rig.tool.paintOverlay(
          screen, r.rig.camera.value, const ui.Size(800, 600), PaperPalette.light);
      final s = r.rig.camera.value.worldToScreen(marker);
      // The nearest glyph: four lines, the first along its top edge from
      // (−h, −h) to (h, −h) around the marker (snap_marker.dart:57-60).
      final lines = screen.named('drawLine').toList();
      expect(lines, hasLength(4));
      const h = kSnapMarkerPixels / 2;
      final start = lines.first.positionalArguments[0] as ui.Offset;
      // M-AT9b: the attached marker drawn at the snapped point.
      expect(start.dx, closeTo(s.x - h, 1e-9));
      expect(start.dy, closeTo(s.y - h, 1e-9));
      r.rig.place(pA, pB);
      // M-AT9: the release ignores the attachment (places freely).
      expect(partsOf(r.rig.instances.single.transform), partsOf(turned));
    });

    test('AT-10 object snap off: nothing is asked (today\'s rule)', () {
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      final edge = RecordingProvider('test-edge', (_) => null);
      registry.add('demo', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry, objectSnap: false);
      rig.armed.value = shelf();
      rig.hover(pA);
      // M-AT10: the `_rawObjectSnap` test dropped.
      expect(edge.queries, isEmpty);
    });

    test(
        'AT-11 hysteresis: each query keeps the last answer; a re-arm '
        'clears it', () {
      final a = attachment(Transform2.translation(80000.5, -36000.5),
          Vector2(80000.5, -36000.5), 'face');
      final r = attachRig(answer: (_) => a);
      r.rig.armed.value = shelf();
      r.rig.hover(pA);
      expect(r.edge.queries.last.keep, isNull);
      r.rig.hover(pB);
      // M-AT11a: `keep: previous` written `keep: null`.
      expect(r.edge.queries.last.keep, same(a));
      // A re-arm with the ghost shown asks again at once, for the new
      // symbol, with no keep.
      final asked = r.edge.queries.length;
      r.rig.armed.value = shelf('demo.shelf.high');
      expect(r.edge.queries.length, asked + 1);
      // M-AT11b: `_onArmed` keeps the previous symbol's attachment.
      expect(r.edge.queries.last.keep, isNull);
    });

    test(
        'AT-12 rotate refused: mayRotate is false and the current transform '
        'unturned whatever R stored; M mirrors in place', () {
      var rotate = true;
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      final edge = RecordingProvider('test-edge', (_) => null);
      registry.add('demo', (_) => edge, _ServicesStub());
      final rig = Rig(attachments: registry, canRotate: () => rotate);
      final s = shelf();
      rig.armed.value = s;
      rig.key(kR);
      rig.hover(pA);
      expect(edge.queries.last.mayRotate, isTrue);
      expect(linear(edge.queries.last.current), [0.0, 1.0, -1.0, 0.0],
          reason: 'one quarter turn');
      rotate = false;
      rig.tool.gatesChanged();
      // M-AT12: mayRotate passed as true.
      expect(edge.queries.last.mayRotate, isFalse);
      expect(linear(edge.queries.last.current), [1.0, 0.0, 0.0, 1.0]);
      rig.key(kM);
      expect(edge.queries.last.mirrored, isTrue);
      expect(linear(edge.queries.last.current), [-1.0, 0.0, 0.0, 1.0]);
    });

    test('AT-13 a throwing provider: the ghost places freely', () {
      final reported = <KitDiagnostic>[];
      final registry = PlanAttachmentRegistry(report: reported.add);
      addTearDown(registry.dispose);
      registry.add('demo', (_) => ThrowingProvider('test-edge'), _ServicesStub());
      final rig = Rig(attachments: registry);
      final s = shelf();
      rig.armed.value = s;
      rig.hover(pA);
      expect(rig.tool.ghostAttachment, isNull);
      expect(partsOf(rig.tool.ghostPlacement!), partsOf(placementTransform(
          at: gridOf(pA), basePoint: s.entry.definition.basePoint)));
      expect(reported.single.code, KitDiagnosticCode.hookFailed);
    });
  });
```

  with, at the file's top level:

```dart
final class _ServicesStub implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];
```

  and the imports `package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary`, `package:jet_cad_2d_plan/src/attach/attachment_registry.dart`, `package:jet_cad_2d_plan/src/symbols/symbol_box.dart`.

- [ ] **Step 5: Write the failing move-resolver tests.** Create `test/tools/move_resolver_test.dart`:

```dart
// Spec P3 "Attachment" (Task 14): plan.select's move resolver asks the
// registry for a root-level symbol instance whose jetcad.symbol attaches
// somewhere; the query is the plain-moved transform, anchored on the moved
// footprint's back-centre, the node excluded. A turned, mirrored placement
// far from the origin; a camera at 0.1 px/mm.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/attach/attachment_registry.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_box.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/tools/move_resolver.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/symbol_fixtures.dart';

final class _ServicesStub implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}

final SymbolLibrary lib = SymbolLibrary.decode(encodeLibrary(Catalog(
    kit: 'demo',
    symbols: [
      box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
          attachTo: ['test-edge'], base: (950, 410)),
      box('demo.table.free', 'Table', 'Dining', ['table'], base: (950, 410)),
    ])));

SymbolEntry entry(String key) =>
    lib.entries.singleWhere((e) => e.symbol.key == key);

final class Scene {
  Scene({String key = 'demo.shelf.wall', bool objectSnap = true}) {
    doc = DraftDocument.empty();
    registerKitComponents(doc.components);
    doc.header.units = DrawingUnits.millimeters;
    doc.commands.execute(placeSymbol(doc, entry(key),
        at: Vector2(100000.25, -70000.75), quarterTurns: 1, mirrored: true));
    instance = doc.tree.nodes.whereType<InstanceNode>().single.handle;
    index = SpatialIndex(doc);
    selection = SelectionController(doc);
    camera = CameraController(ViewportTransform(
        worldToScreenMatrix:
            Transform2(0.1, 0, 0, -0.1, -9600, -6600)));
    snap = SnapSettings(objectSnap: objectSnap);
    ctx = ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap);
    registry = PlanAttachmentRegistry(report: reported.add);
    edge = RecordingProvider('test-edge', (q) => answer?.call(q));
    registry.add('demo', (_) => edge, _ServicesStub());
    resolver = PlanMoveResolver(
        attachments: () => registry, canRotate: () => rotate);
    addTearDown(() {
      registry.dispose();
      snap.dispose();
      selection.dispose();
      index.dispose();
      camera.dispose();
    });
  }

  late final DraftDocument doc;
  late final Handle instance;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final CameraController camera;
  late final SnapSettings snap;
  late final ToolContext ctx;
  late final PlanAttachmentRegistry registry;
  late final RecordingProvider edge;
  late final PlanMoveResolver resolver;
  final List<KitDiagnostic> reported = [];
  Attachment? Function(AttachmentQuery q)? answer;
  bool rotate = true;

  Transform2 get transform => (doc.tree[instance]! as InstanceNode).transform;
}

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

final Transform2 delta = Transform2.translation(310.5, -125.25);

void main() {
  test(
      'MV-1 the query: the plain move, its back-centre, the node excluded, '
      'its mirror, mayRotate; the answer is the move', () {
    final s = Scene();
    final placed = attachment(Transform2.translation(99000.5, -69000.25),
        Vector2(99010.25, -69020.5), 'face');
    s.answer = (_) => placed;
    final r = s.resolver.resolveMove(s.ctx, s.instance, delta)!;
    expect(partsOf(r.transform), partsOf(placed.transform));
    expect(r.marker, placed.marker);
    final q = s.edge.queries.single;
    final moved = delta.multiply(s.transform);
    expect(partsOf(q.current), partsOf(moved));
    final box = boxOfEntry(entry('demo.shelf.wall'))!;
    // M-MV1a: the raw transform's back-centre (no delta).
    expect(q.pointer, moved.transformPoint(box.backCentre));
    // M-MV1b: the node not excluded.
    expect(q.exclude, {s.instance});
    expect(q.mirrored, isTrue, reason: 'placed mirrored');
    expect(q.mayRotate, isTrue);
    expect(q.capture, closeTo(16 / 0.1, 1e-9));
    expect(q.edgeCapture, closeTo(kSnapAperturePixels / 0.1, 1e-9));
    expect([q.footprint.minX, q.footprint.maxY], [box.left, box.back]);
    s.rotate = false;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    expect(s.edge.queries.last.mayRotate, isFalse);
  });

  test(
      'MV-2 nothing is asked for a symbol that attaches to nothing, a '
      'non-symbol, with object snap off, or for a scaled instance', () {
    final free = Scene(key: 'demo.table.free');
    // M-MV2a: the attachTo test dropped.
    expect(free.resolver.resolveMove(free.ctx, free.instance, delta), isNull);
    expect(free.edge.queries, isEmpty);

    final off = Scene(objectSnap: false);
    off.answer = (_) => attachment(Transform2.identity(), Vector2(1, 1), 't');
    // M-MV2b: the object snap test dropped.
    expect(off.resolver.resolveMove(off.ctx, off.instance, delta), isNull);
    expect(off.edge.queries, isEmpty);

    final scaled = Scene();
    scaled.doc.commands.execute(TransformNodeCommand(scaled.instance,
        Transform2.scale(2, 2).multiply(scaled.transform)));
    expect(
        scaled.resolver.resolveMove(scaled.ctx, scaled.instance, delta), isNull);
    expect(scaled.edge.queries, isEmpty);

    final line = addDrafted(scaled.doc, EntityKind.line,
        linePayload(Vector2(100500, -70500), Vector2(101500, -70100)),
        layer: ReservedHandles.layerZero);
    scaled.doc.commands.execute(line);
    expect(scaled.resolver.resolveMove(scaled.ctx, line.record.handle, delta),
        isNull);
  });

  test(
      'MV-3 within one drag a query keeps the last answer; after the '
      'document changes it starts afresh', () {
    final s = Scene();
    final a = attachment(Transform2.translation(99000.5, -69000.25),
        Vector2(99010.25, -69020.5), 'face');
    s.answer = (_) => a;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    // M-MV3a: keep always null.
    expect(s.edge.queries.last.keep, same(a));
    s.doc.commands
        .execute(TransformNodeCommand(s.instance, a.transform));
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    // M-MV3b: the stateId reset dropped.
    expect(s.edge.queries.last.keep, isNull);
  });

  test('MV-4 the footprint is the definition\'s live leaves', () {
    final s = Scene();
    final node = s.doc.tree[s.instance]! as InstanceNode;
    final box = boxOfDefinition(s.doc, node.definition)!;
    s.answer = (_) => null;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    final f = s.edge.queries.single.footprint;
    expect([f.minX, f.minY, f.maxX, f.maxY],
        [box.left, box.front, box.right, box.back]);
  });
}
```

(`TransformNodeCommand(Handle, Transform2)` is the engine's, as `symbol_move_test.dart:107-108` uses it.)

- [ ] **Step 6: Write the failing controller tests.** Create `test/controller/attachment_controller_test.dart`:

```dart
// Spec P1 "Lifetimes", P3 "Attachment", P4 diagnostics (Task 14), through
// the controller: the providers run once per document and go with it; a
// throwing factory or provider is a diagnostic; an attachTo kind no
// provider offers is a diagnostic; plan.symbol is armed by the gallery's
// symbol and attaches through a kit's provider; plan.select's move
// resolver asks the same registry.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/symbol_fixtures.dart';
import '../support/tool_events.dart';

Uint8List shelfBytes() => encodeLibrary(Catalog(kit: 'demo', symbols: [
      box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
          attachTo: ['test-edge'], base: (950, 410)),
      box('demo.lamp.corner', 'Corner lamp', 'Lighting', ['lamp'],
          attachTo: ['room-corner'], base: (402.75, 233.5)),
    ]));

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanController c) => [
      for (final d in c.diagnostics.value) (d.kitId, d.subject, d.code),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'AT-14 the providers run once per document: a new plan makes new '
      'ones, disposes the old, and the services see the current registry',
      () async {
    final made = <DisposableProvider>[];
    PlanServices? seen;
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', attachments: [
        (services) {
          seen = services;
          final p = DisposableProvider('test-edge', (_) => null);
          made.add(p);
          return p;
        },
      ]),
    ]);
    addTearDown(c.dispose);
    expect(made, hasLength(1));
    expect(seen!.attachments.kinds, {'test-edge'});
    c.newPlan();
    // M-AT14: the per-document registry not disposed on a swap.
    expect(made, hasLength(2));
    expect(made.first.disposals, 1);
    expect(made.last.disposals, 0);
    expect(seen!.attachments.kinds, {'test-edge'});
  });

  test('AT-15 a throwing factory is a hookFailed; the plan still opens',
      () async {
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', attachments: [
        (_) => throw StateError('no faces'),
      ]),
    ]);
    addTearDown(c.dispose);
    expect(problemsOf(c),
        contains(('demo', 'attachments', KitDiagnosticCode.hookFailed)));
  });

  test(
      'AT-16 an attachTo kind no provider offers is one '
      'attachmentKindUnoffered per kit and kind; an offered one is none',
      () async {
    final c = PlanController(kits: [
      PlanKit(
          id: 'demo',
          version: '1.0.0',
          symbols: [
            SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
          ],
          attachments: [(_) => RecordingProvider('test-edge', (_) => null)]),
    ]);
    addTearDown(c.dispose);
    await settle();
    // M-AT16: `_reportUnofferedKinds` not called after the load.
    expect(
        problemsOf(c)
            .where((p) => p.$3 == KitDiagnosticCode.attachmentKindUnoffered),
        [('demo', 'room-corner', KitDiagnosticCode.attachmentKindUnoffered)]);
    c.newPlan();
    expect(
        problemsOf(c)
            .where((p) => p.$3 == KitDiagnosticCode.attachmentKindUnoffered),
        hasLength(1),
        reason: 'once per kit, subject and code');
  });

  test(
      'AT-17 plan.symbol: refused with nothing armed (T4-b); armed, it '
      'places through the kit\'s provider; under rotate: false R is not the '
      'tool\'s', () async {
    final turned = Transform2.translation(4600.5, -1200.25)
        .multiply(Transform2.rotation(0.7));
    final edge = RecordingProvider(
        'test-edge', (_) => attachment(turned, Vector2(4610.5, -1190.25), 'e'));
    final c = PlanController(kits: [
      PlanKit(
          id: 'demo',
          version: '1.0.0',
          symbols: [
            SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
          ],
          attachments: [(_) => edge]),
    ]);
    addTearDown(c.dispose);
    useTestCamera(c);
    await settle();
    // M-AT17a: the "nothing armed" refusal dropped.
    expect(c.selectTool('plan.symbol'), isFalse);
    expect(c.activeTool.value, 'plan.select');
    final shelf = c.symbolById('demo.shelf.wall@1')!;
    expect(c.armSymbol(shelf), isTrue);
    expect(c.activeTool.value, 'plan.symbol');
    tapAt(c, Vector2(4500.25, -1300.75));
    final placed = c.document.tree.nodes.whereType<InstanceNode>().single;
    expect([placed.transform.a, placed.transform.e],
        [turned.a, turned.e]);
    expect(edge.queries.last.exclude, isEmpty);

    c.permissions = PlanPermissions.full.copyWith(rotate: false);
    expect(c.activeTool.value, 'plan.symbol', reason: 'still allowed');
    final r = c.toolController.active.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyR,
            logicalKey: LogicalKeyboardKey.keyR,
            timeStamp: Duration.zero),
        c.toolController.context);
    // M-AT17b: canRotate wired as `() => true`.
    expect(r, KeyEventResult.ignored);
    c.permissions = PlanPermissions.full.copyWith(tools: {'plan.select'});
    expect(c.activeTool.value, 'plan.select');
    expect(c.armSymbol(shelf), isFalse, reason: 'plan.symbol not permitted');
  });

  test(
      'AT-18 plan.select\'s body drag of an attaching symbol asks the same '
      'registry, the instance excluded, and commits its answer', () async {
    Attachment? answer;
    final edge = RecordingProvider('test-edge', (_) => answer);
    final c = PlanController(kits: [
      PlanKit(
          id: 'demo',
          version: '1.0.0',
          symbols: [
            SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
          ],
          attachments: [(_) => edge]),
    ]);
    addTearDown(c.dispose);
    useTestCamera(c);
    await settle();
    c.armSymbol(c.symbolById('demo.shelf.wall@1')!);
    tapAt(c, Vector2(4500.25, -1300.75));
    final node = c.document.tree.nodes.whereType<InstanceNode>().single;
    c.selectTool('plan.select');
    c.selection.replace([SelectionKey.root(node.handle)]);
    final target = Transform2.translation(5200.5, -900.25)
        .multiply(Transform2.rotation(-0.35));
    answer = attachment(target, Vector2(5210.5, -890.25), 'f');
    edge.queries.clear();
    final inside =
        node.transform.transformPoint(Vector2(950, 585)); // on its middle line
    dragFrom(c, inside, inside + Vector2(600, 300));
    // M-AT18: buildGenericTools given no move resolver.
    expect(edge.queries, isNotEmpty);
    expect(edge.queries.last.exclude, {node.handle});
    final moved = c.document.tree[node.handle]! as InstanceNode;
    expect([moved.transform.a, moved.transform.b, moved.transform.e],
        [target.a, target.b, target.e]);
  });
}
```

(Add `import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;` and `import 'package:flutter/widgets.dart' show KeyEventResult;`.)

- [ ] **Step 7: The highlight test.** In `test/panels/plan_symbol_gallery_test.dart`, add the port of `symbol_panel_test.dart:505-532` (assertions unchanged; the state is reached through the controller: `armSymbol` then `selectTool('plan.select')` stands for "armed, another tool active", `selectTool('plan.symbol')` for `tools.activate(tool)`, `selectTool('plan.select')` for `tools.activate(idle)`):

```dart
    testWidgets(
        'the highlight follows the active tool and the armed entry '
        '(M-09b9)', (tester) async {
      final h = Host(tester);
      await h.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull);

      h.controller.armSymbol(h.loaded('demo.bed.double'));
      h.controller.selectTool('plan.select');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull,
          reason: 'armed, but another tool is active');

      h.controller.selectTool('plan.symbol');
      await tester.pump();
      expect(gallery(tester).selectedId, 'demo.bed.double@1');

      h.controller.armSymbol(h.loaded('demo.bed.single'));
      await tester.pump();
      expect(gallery(tester).selectedId, 'demo.bed.single@1');

      h.controller.selectTool('plan.select');
      await tester.pump();
      expect(gallery(tester).selectedId, isNull,
          reason: 'another tool chosen: the highlight clears, armed stays');
      expect(h.controller.armedSymbol.value, same(h.loaded('demo.bed.single')));
    });
```

- [ ] **Step 8: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/attach test/symbols/symbol_box_test.dart test/symbols/symbol_ghost_test.dart test/tools test/controller/attachment_controller_test.dart test/panels/plan_symbol_gallery_test.dart`. Expected: compilation errors naming `PlanAttachmentRegistry`, `PlanSymbolTool`, `PlanMoveResolver`, `boxOfEntry`, `ghostPathFor` (no test runs). Quote the first.

- [ ] **Step 9: The registry and the marker.** Create `lib/src/attach/attachment_registry.dart`:

```dart
// Spec P3 "Attachment" (Task 14): the registry over the kits' providers,
// one per document (spec P1 "Lifetimes": a kit's factories run once per
// document). plan.symbol and plan.select's move resolver use it, and
// nothing else.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/guard.dart' show guardAttachment;

/// The providers of one document, by kind, in the order they were added
/// (kit load order).
///
/// [attach] asks every provider of each kind in its `kinds` and returns
/// the answer whose marker is nearest the query's pointer (the earlier on
/// a tie). A query's `keep` reaches only the provider that made it. A
/// provider that throws is taken as no attachment and reported; so is a
/// factory that throws, which adds no provider.
final class PlanAttachmentRegistry implements AttachmentRegistry {
  PlanAttachmentRegistry(
      {required void Function(KitDiagnostic diagnostic) report})
      : _report = report;

  final void Function(KitDiagnostic diagnostic) _report;
  final Map<String, List<_Provider>> _byKind = <String, List<_Provider>>{};
  final Expando<_Provider> _origin = Expando<_Provider>('attachment origin');

  /// Runs [factory] over [services] and adds its provider.
  void add(String kitId, AttachmentProvider Function(PlanServices) factory,
      PlanServices services) {
    final AttachmentProvider provider;
    try {
      provider = factory(services);
    } catch (e) {
      _report(KitDiagnostic(
          kitId: kitId,
          subject: 'attachments',
          code: KitDiagnosticCode.hookFailed,
          message: 'an attachment provider factory of "$kitId" threw: $e',
          error: e));
      return;
    }
    (_byKind[provider.kind] ??= <_Provider>[])
        .add(_Provider(kitId, provider));
  }

  @override
  Set<String> get kinds => Set.unmodifiable(_byKind.keys);

  @override
  Attachment? attach(List<String> kinds, AttachmentQuery query) {
    final keep = query.keep;
    final keeper = keep == null ? null : _origin[keep];
    AttachmentQuery? bare;
    Attachment? best;
    var bestDistance = double.infinity;
    for (final kind in kinds) {
      final providers = _byKind[kind];
      if (providers == null) continue;
      for (final p in providers) {
        final q = keep == null || identical(p, keeper)
            ? query
            : (bare ??= _withoutKeep(query));
        final a = _ask(p, q);
        if (a == null) continue;
        _origin[a] = p;
        final d = a.marker.distanceToSquared(query.pointer);
        if (d < bestDistance) {
          best = a;
          bestDistance = d;
        }
      }
    }
    return best;
  }

  /// [p]'s answer through Task 11's guard: a throw is no attachment and
  /// one hookFailed (subject: the provider's kind).
  Attachment? _ask(_Provider p, AttachmentQuery q) =>
      guardAttachment(p.kitId, p.provider, q, _report);

  static AttachmentQuery _withoutKeep(AttachmentQuery q) => AttachmentQuery(
        footprint: q.footprint,
        current: q.current,
        pointer: q.pointer,
        capture: q.capture,
        edgeCapture: q.edgeCapture,
        mirrored: q.mirrored,
        mayRotate: q.mayRotate,
        exclude: q.exclude,
      );

  /// Disposes every provider that is [Disposable] and empties the
  /// registry (the document is going).
  void dispose() {
    for (final providers in _byKind.values) {
      for (final p in providers) {
        final provider = p.provider;
        if (provider is Disposable) provider.dispose();
      }
    }
    _byKind.clear();
  }
}

final class _Provider {
  const _Provider(this.kitId, this.provider);

  final String kitId;
  final AttachmentProvider provider;
}
```

(`Disposable` comes from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, Task 4's `plan_services.dart`; controller ruling R-d.)

Create `lib/src/attach/attachment_painter.dart`:

```dart
// Spec P3 "Drawing" (Task 14): the plan library draws every kit's
// attachment marker alike: the nearest glyph at the marker's screen point
// (today's attached marker, symbol_place_tool.dart:503-522).
import 'dart:ui' show Canvas, Offset, Paint;

import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform, drawSnapMarker;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Draws the attachment marker at world [marker] with [paint]. Allocates
/// only the screen offset.
void paintAttachmentMarker(
    Canvas canvas, ViewportTransform camera, Vector2 marker, Paint paint) {
  final m = camera.worldToScreenMatrix;
  final at = Offset(m.a * marker.x + m.c * marker.y + m.e,
      m.b * marker.x + m.d * marker.y + m.f);
  drawSnapMarker(canvas, at, SnapKind.nearest, grid: false, paint: paint);
}
```

- [ ] **Step 10: The box and the ghost.** 
  - `lib/src/symbols/symbol_box.dart`: a copy of `jet_cad_floor_plan/lib/src/symbols/symbol_box.dart:1-146` with its `symbol_library.dart` import replaced by `package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolEntry`, and this function added at the end:

```dart
/// [box] as the engine's box, the shape `AttachmentQuery.footprint` takes:
/// x from left to right, y from front to back, in the definition's
/// coordinates.
Aabb2 footprintOf(SymbolBox box) =>
    Aabb2.raw(box.left, box.front, box.right, box.back);
```

  - `lib/src/symbols/symbol_ghost.dart`: a copy of `jet_cad_floor_plan/lib/src/symbols/symbol_ghost.dart:1-150` with its `symbol_library.dart` import replaced by `package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolEntry`. No other change (the kit's `SymbolEntry.leaves` has the same `record` / `payload` shape).

- [ ] **Step 11: `plan.symbol`.** Create `lib/src/tools/plan_symbol_tool.dart`, ported from `symbol_place_tool.dart:1-561`. Unchanged regions: the pointer, key, cancel and camera logic (`:154-482` but for the lines below), the ghost painting (`:524-551`). Changed: the armed value is a `PlanSymbol`; attachment asks the registry over the symbol's `attachTo` (no `WallFaces`, no `againstWallTag`); the marker is `paintAttachmentMarker`; no band invalidation. The full file:

```dart
// Spec P3 "Attachment" (Task 14): plan.symbol, ported from
// jet_cad_floor_plan's symbol_place_tool.dart (spec 09b D6, F-5, F-6,
// F-12, F-14, F-16; 09c D5, D6, D12). A ghost of the armed symbol's
// outline follows the pointer, snapping like the drawing tools; press,
// drag, release places it at the release point; one undo step per
// placement; the tool stays armed. A symbol whose jetcad.symbol names
// attachment kinds attaches through the registry, while object snap is on.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        MouseCursor,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show Attachment, AttachmentQuery, AttachmentRegistry;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../attach/attachment_painter.dart';
import '../symbols/plan_symbol.dart';
import '../symbols/symbol_box.dart';
import '../symbols/symbol_ghost.dart';
import '../symbols/symbol_placer.dart';
import 'generic_tools.dart' show PlanToolIds;

/// The half-size of the ghost's base-point cross, in screen pixels.
const double kGhostCrossPixels = 6.0;

/// How near, in screen pixels, the raw pointer may be for an attachment
/// (today's kWallAttachPixels, spec 09c D4, D6): larger than the snap
/// aperture, since the pointer is often the symbol's centre.
const double kAttachPixels = 16.0;

/// Places the [armed] symbol on release (spec 09b D6; see the header).
///
/// - Nothing armed is idle: every pointer event is ignored, every key
///   bubbles, the cursor defers.
/// - R, Shift+R and M turn and mirror the next placement while
///   [canRotate] / [canMirror] allow (null allows); a refused turn or
///   mirror is not used (the stored one returns with the flag).
/// - Attachment (spec P3): for a symbol whose component's `attachTo` is not
///   empty, with object snap on and [attachments] given, each recompute
///   asks `attachments.attach(attachTo, query)` with the symbol's
///   footprint, the free placement as `current`, the raw pointer, the
///   captures `kAttachPixels / scale` and `kSnapAperturePixels / scale`,
///   the mirror, `mayRotate` ([canRotate]) and the last answer as `keep`.
///   Attached, the ghost and the release use the answer's transform
///   verbatim and the marker is drawn at its marker; M mirrors in place.
class PlanSymbolTool extends Tool {
  PlanSymbolTool(this.armed,
      {this.attachments, this.canRotate, this.canMirror}) {
    armed.addListener(_onArmed);
    _syncPath();
  }

  final ValueListenable<PlanSymbol?> armed;
  final AttachmentRegistry? attachments;
  final bool Function()? canRotate;
  final bool Function()? canMirror;

  final DragPoint _at = DragPoint();
  final SnapResult _scratch = SnapResult();
  final GhostMatrix _matrix = GhostMatrix();
  final ui.Paint _ghostPaint = ui.Paint()..style = ui.PaintingStyle.stroke;
  final ui.Paint _markerPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = kSnapMarkerStrokePixels;

  ui.Path? _path;
  bool _ghostVisible = false;
  bool _pressed = false;
  int _pressPointer = -1;
  int _quarterTurns = 0;
  bool _mirrored = false;
  Transform2? _placement;
  Attachment? _attached;

  final Vector2 _raw = Vector2.zero();
  bool _rawObjectSnap = true;
  double _rawScale = 1;
  bool _hasRaw = false;

  ui.Offset _lastScreen = ui.Offset.zero;
  ToolContext? _context;
  ToolContext? _listening;

  /// What a placement commits (spec D6: the definition copy, its leaves and
  /// its jetcad.symbol).
  static const Set<Capability> needs = PlanToolIds.symbolNeeds;

  @override
  String get name => 'Symbol';

  @override
  ToolPhase get phase => _pressed ? ToolPhase.pressed : ToolPhase.idle;

  @override
  TouchPress get touchPress => TouchPress.press;

  @override
  bool get isMidShape => _pressed;

  @override
  MouseCursor get cursor =>
      armed.value == null ? MouseCursor.defer : SystemMouseCursors.precise;

  bool get ghostVisible => _ghostVisible && armed.value != null;

  Vector2 get ghostAt => _at.point;

  @visibleForTesting
  ui.Path? get ghostPath => _path;

  @visibleForTesting
  Transform2? get ghostPlacement => _placement;

  @visibleForTesting
  GhostMatrix get ghostMatrix => _matrix;

  /// The attachment the ghost (and a release) uses, or null.
  @visibleForTesting
  Attachment? get ghostAttachment => _attached;

  int get quarterTurns => _quarterTurns;
  bool get mirrored => _mirrored;

  int get _turns => (canRotate?.call() ?? true) ? _quarterTurns : 0;
  bool get _mirror => _mirrored && (canMirror?.call() ?? true);

  /// The permissions may have changed: the ghost and its attachment are
  /// computed again with the turn and the mirror now allowed.
  void gatesChanged() {
    if (armed.value == null) return;
    final ctx = _listening ?? _context;
    if (ctx != null) _syncAttachment(ctx);
    _syncPlacement();
    notifyListeners();
  }

  void _syncPath() {
    final symbol = armed.value;
    _path = symbol == null ? null : ghostPathFor(symbol.entry);
  }

  void _onArmed() {
    _syncPath();
    _syncCamera();
    // The previous symbol's answer is no keep for this one.
    _attached = null;
    final ctx = _listening;
    if (ctx != null) {
      _update(ctx, _worldUnderPointer(ctx));
    } else {
      _syncPlacement();
    }
    _pressed = false;
    _pressPointer = -1;
    notifyListeners();
  }

  /// The free placement: the resolved point, the turns, the mirror.
  Transform2? _free() {
    final symbol = armed.value;
    return symbol == null
        ? null
        : placementTransform(
            at: _at.point,
            basePoint: symbol.entry.definition.basePoint,
            quarterTurns: _turns,
            mirrored: _mirror);
  }

  void _syncPlacement() => _placement = _attached?.transform ?? _free();

  void _syncAttachment(ToolContext ctx) {
    final previous = _attached;
    _attached = null;
    final registry = attachments;
    final symbol = armed.value;
    if (registry == null || symbol == null || !_hasRaw || !_rawObjectSnap) {
      return;
    }
    final kinds = symbol.component.attachTo;
    if (kinds.isEmpty) return;
    final box = boxOfEntry(symbol.entry);
    if (box == null) return;
    _attached = registry.attach(
        kinds,
        AttachmentQuery(
          footprint: footprintOf(box),
          current: _free()!,
          pointer: _raw.clone(),
          capture: kAttachPixels / _rawScale,
          edgeCapture: kSnapAperturePixels / _rawScale,
          mirrored: _mirror,
          mayRotate: canRotate?.call() ?? true,
          exclude: const {},
          keep: previous,
        ));
  }

  void _resolve(ToolContext ctx, Vector2 raw) {
    final cam = ctx.camera.value;
    final page = ctx.page?.value;
    resolveDragPoint(
      raw: raw,
      orthoBase: null,
      index: ctx.index,
      apertureWorld: kSnapAperturePixels / cam.scale,
      objectSnap: ctx.snap?.objectSnap ?? true,
      page: page,
      gridStepMm: dragGridStepMm(page, cam.scale),
      scratch: _scratch,
      out: _at,
    );
  }

  void _update(ToolContext ctx, Vector2 raw) {
    _resolve(ctx, raw);
    _raw.setFrom(raw);
    _rawObjectSnap = ctx.snap?.objectSnap ?? true;
    _rawScale = ctx.camera.value.scale;
    _hasRaw = true;
    _syncAttachment(ctx);
    _syncPlacement();
  }

  void _track(ToolPointerEvent e, ToolContext ctx) {
    _lastScreen = e.screen;
    _context = ctx;
  }

  Vector2 _worldUnderPointer(ToolContext ctx) =>
      ctx.camera.value.screenToWorld(Vector2(_lastScreen.dx, _lastScreen.dy));

  void _syncCamera() {
    final want = ghostVisible ? _context : null;
    if (identical(want, _listening)) return;
    _listening?.camera.removeListener(_onCamera);
    _listening = want;
    want?.camera.addListener(_onCamera);
  }

  void _onCamera() {
    final ctx = _listening;
    if (ctx == null) return;
    _update(ctx, _worldUnderPointer(ctx));
    notifyListeners();
  }

  // onPointerDown, onPointerMove, onPointerUp, onPointerExit: copied from
  // symbol_place_tool.dart:362-410 unchanged (they call _track, _update,
  // _syncCamera and _place as before).

  // onKey and _hasModifier: copied from symbol_place_tool.dart:426-469
  // unchanged.

  // cancel: copied from symbol_place_tool.dart:474-482 unchanged.

  /// The one commit path: one command, one undo step; the permissions are
  /// checked before placeSymbol allocates a handle (Ruling 05-3, F-16).
  void _place(ToolContext ctx, PlanSymbol symbol) {
    if (!needs.every(ctx.document.commands.permissions.allows)) return;
    ctx.execute(placeSymbol(ctx.document, symbol.entry,
        at: _at.point,
        quarterTurns: _turns,
        mirrored: _mirror,
        transform: _attached?.transform));
  }

  @override
  void paintOverlay(ui.Canvas canvas, ViewportTransform camera,
      ui.Size viewport, PaperPalette paper) {
    if (!ghostVisible) return;
    _markerPaint.color = paper.snap;
    final attached = _attached;
    if (attached != null) {
      paintAttachmentMarker(canvas, camera, attached.marker, _markerPaint);
      return;
    }
    final m = camera.worldToScreenMatrix;
    final p = _at.point;
    final at =
        ui.Offset(m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f);
    drawSnapMarker(canvas, at, _at.objectKind,
        grid: _at.grid, paint: _markerPaint);
  }

  // paintWorldOverlay: copied from symbol_place_tool.dart:528-551 with
  // `final entry = armed.value;` → `final entry = armed.value?.entry;`.

  @override
  void dispose() {
    armed.removeListener(_onArmed);
    _listening?.camera.removeListener(_onCamera);
    _listening = null;
    _context = null;
    super.dispose();
  }
}
```

  In the copied `onPointerUp` (`:388-402`), `final entry = armed.value;` → `final symbol = armed.value;` and `_place(ctx, entry)` → `_place(ctx, symbol)`. The `pointer` in the query is `_raw.clone()` because `_raw` is reused: an answer kept as `keep` must not see the next event's point. The class comment of `SymbolPlaceTool` (`:44-74`) is replaced by the one above.

- [ ] **Step 12: The move resolver.** Create `lib/src/tools/move_resolver.dart`:

```dart
// Spec P3 "Attachment" (Task 14): plan.select's move resolver, ported from
// jet_cad_floor_plan's symbol_move.dart (spec 09c D8) over the registry.
// A root-level symbol instance whose jetcad.symbol names attachment kinds,
// dragged by its body with object snap on, attaches as a placement does,
// anchored on its plain-moved back-centre.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show MoveResolver, ToolContext;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show Attachment, AttachmentQuery, AttachmentRegistry, SymbolComponent;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../symbols/symbol_box.dart';
import 'plan_symbol_tool.dart' show kAttachPixels;

/// Whether [g]'s linear part is orthonormal (spec 09c W-8, S-10; ported
/// from wall_attach.dart:402-407): a mirror is, a scale is not.
bool isOrthonormal(Transform2 g) {
  final tol = Tolerance.standard.linear;
  return (g.a * g.a + g.b * g.b - 1).abs() <= tol &&
      (g.c * g.c + g.d * g.d - 1).abs() <= tol &&
      (g.a * g.c + g.b * g.d).abs() <= tol;
}

final class PlanMoveResolver implements MoveResolver {
  PlanMoveResolver({required this.attachments, this.canRotate});

  /// The current document's registry, read at each call.
  final AttachmentRegistry Function() attachments;

  /// Whether a move may turn the symbol (the permissions' rotate), read at
  /// each call; null allows.
  final bool Function()? canRotate;

  DraftDocument? _document;
  int _state = -1;
  Handle? _node;
  Attachment? _last;
  final Map<Handle, SymbolBox?> _boxes = <Handle, SymbolBox?>{};

  /// For a root-level instance of a live definition whose `SymbolComponent`
  /// names attachment kinds, with object snap on and an orthonormal
  /// transform (a scaled instance never attaches, so its scale is never
  /// dropped): the registry's answer for the plain move `delta · T`; else
  /// null.
  @override
  ({Transform2 transform, Vector2 marker})? resolveMove(
      ToolContext ctx, Handle node, Transform2 delta) {
    final doc = ctx.document;
    if (!(ctx.snap?.objectSnap ?? true)) return null;
    final n = doc.tree[node];
    if (n is! InstanceNode || n.parent != doc.rootHandle) return null;
    if (doc.tree.definition(n.definition) == null) return null;
    final symbol = doc.components.get<SymbolComponent>(n.definition);
    if (symbol == null || symbol.attachTo.isEmpty) return null;
    final t = n.transform;
    if (!isOrthonormal(t)) return null;
    _sync(doc, node);
    final box = _boxes.putIfAbsent(
        n.definition, () => boxOfDefinition(doc, n.definition));
    if (box == null) return null;
    final moved = delta.multiply(t);
    final scale = ctx.camera.value.scale;
    final a = attachments().attach(
        symbol.attachTo,
        AttachmentQuery(
          footprint: footprintOf(box),
          current: moved,
          pointer: moved.transformPoint(box.backCentre),
          capture: kAttachPixels / scale,
          edgeCapture: kSnapAperturePixels / scale,
          mirrored: t.a * t.d - t.b * t.c < 0,
          mayRotate: canRotate?.call() ?? true,
          exclude: {node},
          keep: _last,
        ));
    _last = a;
    if (a == null) return null;
    return (transform: a.transform, marker: a.marker);
  }

  /// One drag is one document state and one node: outside it the boxes
  /// and the keep start afresh.
  void _sync(DraftDocument doc, Handle node) {
    final state = doc.commands.stateId;
    if (identical(doc, _document) && state == _state) {
      if (node != _node) {
        _node = node;
        _last = null;
      }
      return;
    }
    _document = doc;
    _state = state;
    _node = node;
    _last = null;
    _boxes.clear();
  }
}
```

- [ ] **Step 13: The session and the controller.** The registry and `plan.symbol` are per-document: they live in Task 8's `DocumentSession` (`lib/src/controller/session.dart`) and go with it (Shared interfaces). The attachment providers are kit products: they are made with the kit tools (spec P1 lifetimes, step 3) and disposed with them in `disposeKitProducts()`, at the swap (step 2), before the next document's are made.
  1. In `session.dart` (import `../attach/attachment_registry.dart`, `../tools/plan_symbol_tool.dart` and `generic_tools.dart`'s `PlanToolIds`):
     - The constructor gains `MoveResolver? moveResolver`, passed on as Task 12's `buildGenericTools(gates: gates, fill: fill, moveResolver: moveResolver)`.
     - Add:

```dart
  /// plan.symbol of this document (Task 14); in the tool map, which owns
  /// and disposes it.
  late final PlanSymbolTool symbolTool;

  /// Runs every kit's attachment-provider factories over this document,
  /// once (spec P1 lifetimes), before its tools: the registry is what
  /// `PlanServices.attachments` returns from here on.
  void runAttachmentFactories(KitSet kits, Map<String, PlanServices> services,
      void Function(KitDiagnostic) report) {
    final registry = PlanAttachmentRegistry(report: report);
    attachments = registry;
    for (final kit in kits.kits) {
      for (final factory in kit.attachments) {
        registry.add(kit.id, factory, services[kit.id]!);
      }
    }
  }

  /// Puts [tool] in the map as plan.symbol, after the generic tools and
  /// before the kits'.
  void addSymbolTool(PlanSymbolTool tool) {
    symbolTool = tool;
    addTool(PlanToolIds.symbol, tool);
  }
```

     - In `disposeKitProducts()`, right after the grip providers' loop: `final registry = attachments; if (registry is PlanAttachmentRegistry) registry.dispose();` (it disposes each provider that is `Disposable`). Nothing disposes `symbolTool` but the map.
  2. In `plan_controller.dart`, a controller-lifetime member (it reads the current document from each call's context and the current registry from the session):

```dart
  late final PlanMoveResolver _moveResolver = PlanMoveResolver(
      attachments: () => _session.attachments,
      canRotate: () => _permissions.rotate);
```

  3. In Task 8's `_open`: the `DocumentSession(...)` call gains `moveResolver: _moveResolver`; right after `_session = session;` (so the kit's `PlanServices` already read this session's registry) and before `session.runKitFactories(...)`:

```dart
    session.runAttachmentFactories(kits, _services, _diagnostics.add);
    session.addSymbolTool(PlanSymbolTool(_armed,
        attachments: session.attachments,
        canRotate: () => _permissions.rotate,
        canMirror: () => _permissions.mirror));
    registerToolNeeds(PlanToolIds.symbol, PlanToolIds.symbolNeeds);
```

     (`_services` is Task 8's per-kit `PlanServices` map behind `servicesOf`; `addTool` guards the tool as Task 11 guards every tool.) `_open` ends with `_reportUnofferedKinds();`.
  4. No per-document dispose in the controller: the session disposes the registry in `disposeKitProducts()` and `plan.symbol` with its map.
  5. `_allowsTool`: first line `if (id == PlanToolIds.symbol && _armed.value == null) return false;` (today: "`symbol` … is refused with none armed", `planner_shell.dart:945-951`).
  6. The permissions setter (Task 12): after the fallback to plan.select, `else if (activeTool.value == PlanToolIds.symbol && (old.rotate != value.rotate || old.mirror != value.mirror)) _session.symbolTool.gatesChanged();` (today's `planner_shell.dart:1100-1104`).
  7. `_loadSymbols` (Task 13): after the diagnostics loop, `_reportUnofferedKinds();`, and add:

```dart
  /// One attachmentKindUnoffered per kit and kind (the log keeps one per
  /// kit, subject and code) for each loaded symbol's attachTo kind that no
  /// provider of the current document offers.
  void _reportUnofferedKinds() {
    final offered = _session.attachments.kinds;
    for (final s in _symbols) {
      for (final kind in s.component.attachTo) {
        if (offered.contains(kind)) continue;
        _diagnostics.add(KitDiagnostic(
            kitId: s.kitId,
            subject: kind,
            code: KitDiagnosticCode.attachmentKindUnoffered,
            message: '${s.id} attaches to "$kind", which no loaded kit '
                'offers'));
      }
    }
  }
```

- [ ] **Step 14: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/attach test/symbols test/tools test/controller test/panels`. Expected: `All tests passed!`. Then `flutter test`. Expected: `All tests passed!` (Task 13's S-14 still green: `armSymbol` now also activates plan.symbol).

- [ ] **Step 15: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 16: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/attach/attachment_registry.dart packages/jet_cad_2d_plan/lib/src/attach/attachment_painter.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_ghost.dart packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart packages/jet_cad_2d_plan/lib/src/tools/move_resolver.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/test/support/attach_fixtures.dart packages/jet_cad_2d_plan/test/attach/attachment_registry_test.dart packages/jet_cad_2d_plan/test/symbols/symbol_box_test.dart packages/jet_cad_2d_plan/test/symbols/symbol_ghost_test.dart packages/jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart packages/jet_cad_2d_plan/test/tools/move_resolver_test.dart packages/jet_cad_2d_plan/test/controller/attachment_controller_test.dart packages/jet_cad_2d_plan/test/panels/plan_symbol_gallery_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): attachment, plan.symbol and the move resolver (P3)

The attachment registry runs each kit's provider factories once per
document, asks every provider of a symbol's attachTo kinds, keeps the
marker nearest the pointer and hands a keep back to the provider that
made it; a throwing provider is no attachment and a diagnostic. plan.symbol
and plan.select's move resolver attach through it, with no wall in the
plan library; the plan library paints the marker and the ghost. An
attachTo kind no provider offers is reported once.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 17: Mutation check** (committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-AT2a `attachment_registry.dart`: `return a;` right after `_origin[a] = p;` (first answer wins) → AT-2 red; M-AT2b: `if (d < bestDistance)` → `if (d <= bestDistance)` → AT-2 red.
  - M-AT3 `attachment_registry.dart`: iterate `_byKind.keys` in place of `kinds` → AT-3 red.
  - M-AT4 `attachment_registry.dart`: `final q = query;` → AT-4 red.
  - M-AT5 `attachment_registry.dart`: `_ask` returns `p.provider.attach(q)` instead of `guardAttachment(…)` → AT-5 red.
  - M-AT6 `attachment_registry.dart`: delete `if (provider is Disposable) provider.dispose();` → AT-6 red (and AT-14).
  - M-AT7 `attachment_registry.dart`: `add` calls `factory(services)` without the try → AT-7 red.
  - M-AT8a `plan_symbol_tool.dart`: `pointer: _raw.clone()` → `pointer: _at.point.clone()` → AT-8 red; M-AT8b: `kAttachPixels / _rawScale` → `kSnapAperturePixels / _rawScale` → AT-8 red.
  - M-AT9 `plan_symbol_tool.dart`: `transform: _attached?.transform` → `transform: null` in `_place` → AT-9 red; M-AT9b: in `paintOverlay` delete the `if (attached != null) { … return; }` block → AT-9 red.
  - M-AT10 `plan_symbol_tool.dart`: delete `|| !_rawObjectSnap` → AT-10 red.
  - M-AT11a `plan_symbol_tool.dart`: `keep: previous` → `keep: null` → AT-11 red; M-AT11b: delete `_attached = null;` from `_onArmed` → AT-11 red.
  - M-AT12 `plan_symbol_tool.dart`: `mayRotate: canRotate?.call() ?? true` → `mayRotate: true` → AT-12 red.
  - M-MV1a `move_resolver.dart`: `pointer: moved.transformPoint(…)` → `pointer: t.transformPoint(box.backCentre)` → MV-1 red; M-MV1b: `exclude: {node}` → `exclude: const {}` → MV-1 red.
  - M-MV2a `move_resolver.dart`: delete `|| symbol.attachTo.isEmpty` → MV-2 red; M-MV2b: delete the object-snap line → MV-2 red.
  - M-MV3a `move_resolver.dart`: `keep: _last` → `keep: null` → MV-3 red; M-MV3b: make `_sync` return at once when `identical(doc, _document)` (ignoring the state) → MV-3 red.
  - M-AT14 `session.dart`: in `disposeKitProducts()`, delete `if (registry is PlanAttachmentRegistry) registry.dispose();` → AT-14 red.
  - M-AT16 `plan_controller.dart`: delete the `_reportUnofferedKinds();` call in `_loadSymbols` → AT-16 red.
  - M-AT17a `plan_controller.dart`: delete the `_armed.value == null` line of `_allowsTool` → AT-17 red; M-AT17b: `canRotate: () => _permissions.rotate` → `canRotate: () => true` for the `PlanSymbolTool` made in `_open` → AT-17 red.
  - M-AT18 `plan_controller.dart`: drop `moveResolver: _moveResolver` from `_open`'s `DocumentSession(...)` call → AT-18 red.
  - The ported tool tests' own mutants (09b's M-09b… and the dark theme's M-DT-8) stay named in their tests; run M-09b9 on the gallery (`_selectedId` returns `armed.id` whatever the tool) → the highlight test red.

#### Assumed from earlier tasks

- Task 4: `AttachmentQuery({required Aabb2 footprint, required Transform2 current, required Vector2 pointer, required double capture, required double edgeCapture, required bool mirrored, required bool mayRotate, Set<Handle> exclude = const {}, Attachment? keep})` (Task 4: `mirrored` and `mayRotate` have no default; every call here passes both) with a getter per field; `Attachment({required Transform2 transform, required Vector2 marker, required Object token})` with getters; `AttachmentRegistry` (`attach`, `kinds`); `AttachmentProvider` (`kind`, `attach`); `PlanKit({..., List<AttachmentProvider Function(PlanServices)> attachments = const []})`; `PlanServices.attachments`; `KitDiagnosticCode.hookFailed`, `.attachmentKindUnoffered`. `Aabb2` is the engine's (`jet_cad_2d/lib/src/geometry/aabb2.dart`, `Aabb2.raw(minX, minY, maxX, maxY)`).
- Task 8: the per-document build and dispose (`_open`, `DocumentSession`), `@internal servicesOf(kitId)` giving each kit's `PlanServices`, whose `attachments` reads `DocumentSession.attachments` (this task's `runAttachmentFactories` sets it); `KitSet get kits`; the log `_diagnostics`; `newPlan()`; the diagnostics log (`add`) deduplicating by kit id, subject and code (Task 11's `DiagnosticsLog`); `Disposable` (Task 4, `jet_cad_2d_kit`; controller ruling R-d).
- Task 11: `GuardedTool` forwards `onKey`, the pointer calls and `isMidShape` (AT-17 calls `toolController.active.onKey`).
- Task 12: `PlanToolIds.symbol`, `.symbolNeeds`; `buildGenericTools({required SelectGates gates, required ValueListenable<bool> fill, MoveResolver? moveResolver})`; `registerToolNeeds`; the permissions setter; `_allowsTool`; `test/support/tool_events.dart` (`useTestCamera`, `tapAt`, `dragFrom`).
- Task 13: `PlanSymbol`, `placeSymbol`, `placementTransform`, `_armed`, `_symbols`, `_loadSymbols`, `PlanController.armSymbol`, `symbolById`, `selection` (`@internal`, Task 8), `test/support/symbol_fixtures.dart` (`box`, `settle`, `buildValidLibrary`, `bytesOf`), and the gallery test's `Host`, `entryOf`, `gallery`, `field`.

#### Interface problem

Resolved by controller ruling R-d (`Disposable` is Task 4's, in `jet_cad_2d_kit`'s `plan_services.dart`; the registry and the fixture import it from the kit's barrel). The note on `keep` needs no change: `current` plus `mayRotate` carry today's meaning (AT-12).

---

