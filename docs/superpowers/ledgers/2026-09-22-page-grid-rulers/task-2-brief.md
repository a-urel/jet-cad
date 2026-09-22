### Task 2: `DocChange.capability`, and the skip in the index and the tile cache

**Files:**
- Modify: `lib/src/document/doc_change.dart`, `lib/src/document/undo.dart`,
  `lib/src/index/spatial_index.dart` (`_onChange`),
  `test/document/compound_command_test.dart` (one comment),
  `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (`applyChange`),
  `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`
- Test: `test/index/component_edit_skip_test.dart`

**Interfaces:**
- Produces: `CommandApplied/Undone/Redone.capability` (default
  `Capability.geometry`).

- [ ] **Step 1: Write the failing tests.**

```dart
// test/index/component_edit_skip_test.dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: doc.rootHandle, kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype, linetypeScale: 1.0,
      geomIndex: 0, color: const ByLayerColor(), lineweight: kByLayer,
      transparency: kByLayer, flags: 0),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

void main() {
  test('a components-only edit on the root reconciles nothing', () {
    // M-04r (the skip removed) and M-04s (the dispatcher always says
    // geometry): both make rebuildCount grow here.
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    addLine(doc, [990, 500, 1010, 500]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;
    final page = PageComponent(originX: 7350, originY: -1230);

    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(gridVisible: false)));
    doc.commands.undo();
    doc.commands.redo();

    expect(index.rebuildCount, before);
    expect(doc.components.get<PageComponent>(doc.rootHandle),
        page.copyWith(gridVisible: false));
  });

  test('the change carries the capability of the command that made it', () {
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    final seen = <Capability>[];
    doc.commands.onAfterMutate = (change) {
      if (change case CommandApplied(:final capability) ||
          CommandUndone(:final capability) ||
          CommandRedone(:final capability)) {
        seen.add(capability);
      }
    };
    doc.commands.execute(
        SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()));
    addLine(doc, [1, 2, 3, 4]);
    doc.commands.undo();
    doc.commands.undo();
    doc.commands.redo();
    expect(seen, [
      Capability.components, Capability.geometry,
      Capability.geometry, Capability.components, Capability.components,
    ]);
  });

  test('a compound with one geometry member still reconciles', () {
    // The summary capability: components-only skips, mixed does not.
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    final line = addLine(doc, [990, 500, 1010, 500]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;
    doc.commands.execute(CompoundCommand([
      SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()),
      RemoveEntityCommand(line),
    ], label: 'mixed'));
    expect(index.rebuildCount, greaterThan(before));
  });

  test('the default capability is geometry, so old construction sites keep '
      'their meaning', () {
    const change = CommandApplied(label: 'x', touched: {Handle(7)});
    expect(change.capability, Capability.geometry);
  });
}
```

And in `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`, one
test beside the existing `applyChange` tests, using its rig:

```dart
  test('a components-only change drops no tile', () {
    // D13 for the tile cache: the same skip as the index (M-04r's twin).
    final rig = ...;  // the file's existing rig builder with a baked viewport
    final before = rig.cache.liveTileCount;
    rig.cache.applyChange(
        const CommandApplied(label: 'page', touched: {Handle(16)},
            capability: Capability.components),
        rig.doc);
    expect(rig.cache.liveTileCount, before);
    expect(rig.cache.invalidationCount, 0);
  });
```

(Handle 16 is the root in an empty document — check `rig.doc.rootHandle`
and use that instead of the literal.)

- [ ] **Step 2: Run to fail** (compile error: no `capability`).

- [ ] **Step 3: Implement.** In `doc_change.dart`, add
  `import 'command.dart';` and to each of the three classes:

```dart
final class CommandApplied extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;

  /// What kind of edit this was — the command's [DraftCommand.capability],
  /// a [CompoundCommand]'s summary. [Capability.components] means no
  /// geometry and no structure moved: the spatial index and the tile cache
  /// skip it (spec D13). Defaults to [Capability.geometry] so a change built
  /// without it keeps the meaning every consumer gave it before.
  final Capability capability;

  const CommandApplied(
      {required this.label,
      required this.touched,
      this.capability = Capability.geometry});
}
```

Same for `CommandUndone` and `CommandRedone`. In `undo.dart`:
`CommandApplied(label: command.label, touched: result.touched, capability:
command.capability)`; in `undo()` and `redo()`, `capability:
inverse.capability`. In `spatial_index.dart` `_onChange`:

```dart
      case CommandApplied(:final touched, :final capability):
      case CommandUndone(:final touched, :final capability):
      case CommandRedone(:final touched, :final capability):
        // Spec D13. A components-only edit — a page setting on the root,
        // say — names a handle the structural rule would otherwise treat
        // as a node change and rebuild everything for. Components are data
        // this index never reads.
        if (capability == Capability.components) return;
        _reconcile(touched);
```

In `tile_cache.dart` `applyChange`, inside the three-case command arm,
**before** the `touched.isEmpty` check (the hoisted `_dropCarryOver()`
above the switch stays as it is):

```dart
        // Spec D13: a components-only edit moved no pixels.
        if (capability == Capability.components) return;
```

with `:final capability` added to the three patterns. In
`compound_command_test.dart`, replace the comment above the
`compound.capability` assertion with: `// "Highest-ranked" is the
declaration order of enum Capability; the spatial index and the tile cache
read it to skip components-only compounds (spec 04 D13).`

- [ ] **Step 4: Run to pass**: both new tests, then the full `jet_cad_2d`
  and `jet_cad_2d_flutter` gate lines.
- [ ] **Step 5: Commit** — `feat(engine): DocChange carries the command's
  capability; index and tiles skip component edits`.

---

