## Task 5: `SetEntityTextCommand`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Test: `packages/jet_cad_2d/test/document/commands_test.dart`, and unskip `test/index/text_overlay_test.dart`

**Interfaces:**
- Consumes: Task 0's columns.
- Produces: `SetEntityTextCommand(Handle handle, String text, String tag)`.

- [ ] **Step 1: Write the failing test**

```dart
test('setting text is undoable and dirties the index', () {
  // ... build a doc with one text entity 'A' ...
  final index = SpatialIndex(doc);
  final before = index.rootIndex.boxOfLeaf(slot).maxX;

  doc.commands.execute(SetEntityTextCommand(handle, 'AAAAAAAA', 'TAG'));
  expect(doc.entities.textAt(slot), 'AAAAAAAA');
  expect(doc.entities.tagAt(slot), 'TAG');
  expect(index.rootIndex.boxOfLeaf(slot).maxX, greaterThan(before));

  doc.commands.undo();
  expect(doc.entities.textAt(slot), 'A');
  expect(doc.entities.tagAt(slot), '');
  expect(index.rootIndex.boxOfLeaf(slot).maxX, closeTo(before, 1e-9));

  doc.commands.redo();
  expect(doc.entities.textAt(slot), 'AAAAAAAA');
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/commands_test.dart`
Expected: FAIL — `SetEntityTextCommand` is undefined.

- [ ] **Step 3: Implement it, following `SetComponentCommand`'s shape**

```dart
/// Rewrites a text entity's content.
///
/// A string change changes the laid-out box, so this emits `touched` exactly as
/// a geometry edit does and the index re-derives the leaf through its
/// incremental path. Writing the column directly would leave a stale box.
class SetEntityTextCommand extends DraftCommand {
  SetEntityTextCommand(this.handle, this.text, this.tag);

  final Handle handle;
  final String text;
  final String tag;

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Set text';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) return CommandResult.rejected('no such entity: $handle');
    final previous = target.entities.read(slot);
    if (previous.kind != EntityKind.text && previous.kind != EntityKind.attrib) {
      return CommandResult.rejected('not a text entity: $handle');
    }
    target.entities
        .replace(slot, previous.copyWith(text: text, tag: tag));
    return CommandResult.applied(
      touched: {handle},
      inverse: SetEntityTextCommand(handle, previous.text, previous.tag),
    );
  }
}
```

Match `CommandResult`'s actual factory names and `DraftCommand`'s actual member
set by reading `command.dart` and one existing command before writing this.

- [ ] **Step 4: Run, then unskip the overlay test**

Run: `cd packages/jet_cad_2d && dart test test/document/commands_test.dart test/index/text_overlay_test.dart`
Expected: PASS both, including the overlay-equals-rebuild case.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): add SetEntityTextCommand with an index-dirtying inverse"
```

---

