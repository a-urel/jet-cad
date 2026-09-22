### Task 6: `SelectTool` — keys and Delete

**Files:**
- Modify: `lib/src/select_tool.dart`
- Test: `test/select_tool_test.dart` (a `group('keys and delete')`)

- [ ] **Step 1: Failing tests**

Build key events with
`KeyDownEvent(physicalKey: PhysicalKeyboardKey.delete, logicalKey: LogicalKeyboardKey.delete, timeStamp: Duration.zero)`
and the `KeyUpEvent`/`KeyRepeatEvent` twins.

1. `'Escape when idle clears'`.
2. **M-02x at tool level** — `'a KeyUpEvent and a KeyRepeatEvent do nothing'`:
   select two lines; send the up and the repeat for Delete → both still
   present, `onKey` returned `ignored`.
3. `'Delete removes a leaf and an instance through the log; undo restores geometry, not selection'`:
   `document.commands.undo()` twice → both present again, selection empty.
4. **M-02j** — `'Delete cascades a group: leaves, child instance, nested group, then the group'`:
   after Delete, all slots null, all nodes null; `document.commands.canUndo`.
5. `'a region inside a group is deleted once: the boundary's command takes the fill'`:
   group owning a boundary+fill pair (`AddRegionCommand.allocate(owner:
   group, ...)`); Delete → no `StateError`, both gone.
6. **M-02n** — `'a read-only document is selectable and Delete is a no-op'`:
   `DraftDocument.empty(permissions: DraftPermissions.readOnly)`; select;
   Delete → no throw, entity present, still selected.
7. `'a refused object stays selected, a permitted one goes'`:
   `DraftPermissions(transform: false, components: false, geometry: true,
   structure: false)`; select a leaf and an instance; Delete → leaf gone,
   instance present and still selected.

- [ ] **Step 2: Implement**

```dart
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (_phase == ToolPhase.dragging) {
        cancel(ctx);
      } else if (_phase == ToolPhase.idle) {
        ctx.selection.clear();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_phase != ToolPhase.idle) return KeyEventResult.ignored;
      _deleteSelection(ctx);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _deleteSelection(ToolContext ctx) {
    final doc = ctx.document;
    final permissions = doc.commands.permissions;
    final keys = ctx.selection.keys.toList()
      ..sort((a, b) => a.target.value.compareTo(b.target.value));
    Map<Handle, List<int>>? byOwner;
    for (final key in keys) {
      final List<DraftCommand> list;
      final node = doc.tree[key.target];
      if (node is GroupNode) {
        byOwner ??= doc.leavesByOwner();
        list = _groupCascade(doc, node, byOwner);
      } else if (node is InstanceNode) {
        list = [RemoveNodeCommand(key.target)];
      } else if (doc.entities.slotOf(key.target) != null) {
        list = [RemoveEntityCommand(key.target)];
      } else {
        continue;
      }
      if (!list.every((c) => permissions.allows(c.capability))) continue;
      for (final c in list) {
        ctx.execute(c);
      }
      ctx.selection.remove([key]);
    }
  }

  /// Leaves first (fills whose boundary is here skipped), child instances,
  /// nested groups recursively, the group last.
  List<DraftCommand> _groupCascade(
      DraftDocument doc, GroupNode group, Map<Handle, List<int>> byOwner) {
    final out = <DraftCommand>[];
    final leaves = byOwner[group.handle] ?? const <int>[];
    final boundaries = <Handle>{};
    for (final slot in leaves) {
      if (doc.entities.kindAt(slot) != EntityKind.fill) {
        boundaries.add(doc.entities.handleAt(slot));
      }
    }
    final skip = <Handle>{for (final b in boundaries) ...doc.fills.fillsOf(b)};
    for (final slot in leaves) {
      final h = doc.entities.handleAt(slot);
      if (skip.contains(h)) continue;
      out.add(RemoveEntityCommand(h));
    }
    for (final child in doc.tree.childNodesOf(group.children)) {
      final n = doc.tree[child];
      if (n is GroupNode) {
        out.addAll(_groupCascade(doc, n, byOwner));
      } else if (n is InstanceNode) {
        out.add(RemoveNodeCommand(child));
      }
    }
    out.add(RemoveNodeCommand(group.handle));
    return out;
  }
```

- [ ] **Step 3: Run, gate line, commit**

```sh
git add lib/src/select_tool.dart test/select_tool_test.dart
git commit -m "feat(tools): Escape and Delete on SelectTool, with the group cascade"
```

---

