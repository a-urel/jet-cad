## Task 6: `RemoveEntityCommand` cascades to fills

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart` (`RemoveEntityCommand`)
- Modify: `packages/jet_cad_2d/test/document/region_command_test.dart`

**Interfaces:**
- Consumes: `FillIndex.fillsOf`, `FillIndex.dropBoundary`, `FillIndex.unlink`.
- Produces: `RemoveEntityCommand` unchanged in signature; its inverse is now `AddRegionCommand` when it removed a pair.

**The rule:** removing a boundary removes its fills, in the same transaction, restored together by the inverse. An orphaned fill that draws nothing and reports nothing is the failure mode this codebase names as the worst kind — it looks like it works.

Removing a **fill** alone is allowed and unlinks it; the boundary's triangulation stays, because the boundary is still live and another fill may name it.

- [ ] **Step 1: Write the failing tests**

```dart
  test('removing a boundary removes its fill, and undo restores both', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.boundary.handle));
    expect(doc.entities.slotOf(cmd.fill.handle), isNull,
        reason: 'an orphaned fill draws nothing and reports nothing');
    expect(doc.fills.entryCount, 0);
    expect(doc.fills.linkCount, 0);
    doc.commands.undo();
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('removing a fill alone unlinks it and leaves the boundary drawable', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(RemoveEntityCommand(cmd.fill.handle));
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.fillsOf(cmd.boundary.handle), isEmpty);
  });
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — the fill survives its boundary.

- [ ] **Step 3: Implement**

Replace `RemoveEntityCommand.apply`:

```dart
  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) {
      throw StateError('no entity with handle ${handle.toHex()}');
    }
    final record = target.entities.read(slot);
    final payload = target.geometry.read(record.geomIndex);

    if (record.kind == EntityKind.fill) {
      target.entities.remove(slot);
      target.geometry.remove(record.geomIndex);
      target.fills.unlink(handle);
      target.invalidateDerived();
      return CommandResult(
        inverse: AddEntityCommand(record: record, payload: payload),
        touched: {handle},
      );
    }

    // Removing a boundary removes the fills that name it, in this same
    // mutation. The alternative is an orphaned fill: it draws nothing, reports
    // nothing, and looks like it works.
    final dependents = target.fills.fillsOf(handle);
    if (dependents.length == 1) {
      final fillSlot = target.entities.slotOf(dependents.single)!;
      final fillRecord = target.entities.read(fillSlot);
      target.entities.remove(fillSlot);
      target.geometry.remove(fillRecord.geomIndex);
      target.entities.remove(slot);
      target.geometry.remove(record.geomIndex);
      target.fills.dropBoundary(handle);
      target.invalidateDerived();
      return CommandResult(
        inverse: AddRegionCommand(
            fill: fillRecord, boundary: record, boundaryPayload: payload),
        touched: {handle, fillRecord.handle},
      );
    }
    if (dependents.isNotEmpty) {
      // More than one fill on one boundary is not something this plan's
      // commands can create, and inventing an n-ary inverse for it here would
      // be untested machinery. Refuse rather than half-handle it.
      throw StateError(
          '${handle.toHex()} carries ${dependents.length} fills; remove them '
          'before removing the boundary');
    }

    target.entities.remove(slot);
    target.geometry.remove(record.geomIndex);
    target.fills.dropBoundary(handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddEntityCommand(record: record, payload: payload),
      touched: {handle},
    );
  }
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test` — the whole engine suite, because
this changes a command every other test uses.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/commands.dart
cp "$F" /tmp/t6.dart
trap 'cp /tmp/t6.dart "$F"' EXIT
run() { dart test test/document/region_command_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T6a: do not cascade -- leave the fill orphaned
perl -0pi -e 's/    if \(dependents\.length == 1\) \{/    if (false) {/' "$F"; run; cp /tmp/t6.dart "$F"
# T6b: cascade but forget the index
perl -0pi -e 's/      target\.fills\.dropBoundary\(handle\);\n      target\.invalidateDerived\(\);\n      return CommandResult\(\n        inverse: AddRegionCommand\(/      target.invalidateDerived();\n      return CommandResult(\n        inverse: AddRegionCommand(/' "$F"; run; cp /tmp/t6.dart "$F"
# T6c: removing a fill forgets to unlink it
perl -0pi -e 's/      target\.fills\.unlink\(handle\);//' "$F"; run; cp /tmp/t6.dart "$F"
```

All three must print `KILLED`.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/commands.dart \
        packages/jet_cad_2d/test/document/region_command_test.dart
git commit -m "feat: removing a boundary removes its fill, in one mutation"
```

---

