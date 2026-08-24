## Task 2: `DocumentTables` gets a mutation counter and a `Listenable`

**Why:** the spec's D12. `TableSection.add`, `remove` and `clear` notify nothing, and `DraftCanvas` repaints only for `Listenable.merge([camera, _changes])` where `_changes` is command-backed. A layer colour change today causes no paint at all, so a revision integer read inside `paint` would be correct and never reached.

**This is the only change this plan makes to `packages/jet_cad_2d`.**

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/tables.dart`
- Test: `packages/jet_cad_2d/test/document/tables_revision_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `DocumentTables.mutationRevision` (`int`) and `DocumentTables.changes` (`Listenable`). Task 9 merges the `Listenable` into `_repaint`.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d/test/document/tables_revision_test.dart`:

```dart
// Table mutations reach nobody today. `DocChange` is emitted only by
// `undo.dart` when a command is applied, undone or redone, and
// `TableSection.add`, `remove` and `clear` go through no command at all
// (`tables.dart:51-68`). Plan 3g's tile cache must invalidate on a layer
// colour change, so the tables grow a revision and a `Listenable`.
//
// All three mutators, because `clear` is the one an earlier draft of the spec
// missed and a load path that clears would otherwise leave every tile stale.

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

LayerRecord layer(int handle, String name) => LayerRecord(
      handle: Handle(handle),
      name: name,
      // Not the default: the anti-degenerate habit applies to fixtures in this
      // repository generally, and a record that differs only by handle proves
      // less than one that differs in a field a resolver reads.
      color: const DraftColor.indexed(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 40,
    );

void main() {
  test('every table mutator bumps the revision and notifies', () {
    final tables = DocumentTables.standard();
    var notifications = 0;
    void listener() => notifications++;
    tables.changes.addListener(listener);
    addTearDown(() => tables.changes.removeListener(listener));

    final start = tables.mutationRevision;

    tables.layers.add(layer(900, 'WALLS'));
    expect(tables.mutationRevision, start + 1, reason: 'add');
    expect(notifications, 1);

    tables.layers.remove(const Handle(900));
    expect(tables.mutationRevision, start + 2, reason: 'remove');
    expect(notifications, 2);

    tables.linetypes.clear();
    expect(tables.mutationRevision, start + 3, reason: 'clear');
    expect(notifications, 3);
  });

  test('a rejected add bumps nothing', () {
    final tables = DocumentTables.standard();
    tables.layers.add(layer(901, 'GRID'));
    final after = tables.mutationRevision;

    expect(() => tables.layers.add(layer(901, 'OTHER')),
        throwsA(isA<DuplicateHandleError>()));
    expect(tables.mutationRevision, after,
        reason: 'a throw is not a mutation; bumping here would invalidate '
            'every tile for an edit the document refused');
  });

  test('a remove of an absent handle bumps nothing', () {
    final tables = DocumentTables.standard();
    final after = tables.mutationRevision;
    tables.layers.remove(const Handle(9999));
    expect(tables.mutationRevision, after);
  });

  test('every section is wired, not just layers', () {
    final tables = DocumentTables.standard();
    var revision = tables.mutationRevision;
    // Six sections; a per-section wiring mistake would leave one silent, and
    // a test that checked `layers` alone would not see it.
    tables.layers.add(layer(910, 'A'));
    expect(tables.mutationRevision, ++revision);
    tables.linetypes.add(LinetypeRecord(
        handle: const Handle(911),
        name: 'DASHED2',
        description: '',
        pattern: const [4.0, -2.0]));
    expect(tables.mutationRevision, ++revision);
    tables.textStyles.add(const TextStyleRecord(
        handle: Handle(912), name: 'TITLE', font: 'Roboto', widthFactor: 1.2));
    expect(tables.mutationRevision, ++revision);
    tables.patterns.add(const PatternRecord(handle: Handle(913), name: 'NET'));
    expect(tables.mutationRevision, ++revision);
    tables.dimStyles.add(const DimStyleRecord(handle: Handle(914), name: 'D1'));
    expect(tables.mutationRevision, ++revision);
    tables.appIds.add(const AppIdRecord(handle: Handle(915), name: 'ACAD2'));
    expect(tables.mutationRevision, ++revision);
  });
}
```

**Before writing this file**, read the six record classes in `tables.dart` and correct the constructor calls above to their real required parameters. The shapes above are what the plan expects; the tree is the authority, and a constructor that does not compile is a plan defect to fix in place, not to work around.

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/tables_revision_test.dart
```

Expected: compile failure — `DocumentTables` has no `mutationRevision` and no `changes`.

- [ ] **Step 3: Implement**

`TableSection` gains a callback, defaulting to null so every existing construction still compiles:

```dart
class TableSection<T extends TableRecord> {
  /// Called after a mutation that actually changed this section.
  ///
  /// **Not a `ChangeNotifier` of its own.** `DocumentTables` holds six sections
  /// as bare field initializers with no back-reference (`tables.dart`), and a
  /// notifier per section would make a listener subscribe six times and a
  /// caller reason about six revisions. One counter on the owner is the whole
  /// contract Plan 3g needs.
  TableSection({this.onMutated});

  final void Function()? onMutated;
```

`add` bumps only after both guards have passed:

```dart
  void add(T record) {
    if (_byHandle.containsKey(record.handle)) {
      throw DuplicateHandleError(record.handle);
    }
    final key = record.name.toLowerCase();
    if (_byName.containsKey(key)) throw DuplicateTableNameError(record.name);
    _byHandle[record.handle] = record;
    _byName[key] = record.handle;
    onMutated?.call();
  }
```

`remove` bumps only when something left:

```dart
  void remove(Handle handle) {
    final record = _byHandle.remove(handle);
    if (record == null) return;
    _byName.remove(record.name.toLowerCase());
    onMutated?.call();
  }
```

`clear` bumps unconditionally — a clear of an empty section is still the caller declaring the table replaced, and treating it as a no-op would make a load path that clears then adds bump once instead of twice:

```dart
  void clear() {
    _byHandle.clear();
    _byName.clear();
    onMutated?.call();
  }
```

`DocumentTables` owns the counter and the notifier:

```dart
class DocumentTables {
  DocumentTables() {
    layers = TableSection(onMutated: _bump);
    linetypes = TableSection(onMutated: _bump);
    textStyles = TableSection(onMutated: _bump);
    patterns = TableSection(onMutated: _bump);
    dimStyles = TableSection(onMutated: _bump);
    appIds = TableSection(onMutated: _bump);
  }

  late final TableSection<LayerRecord> layers;
  late final TableSection<LinetypeRecord> linetypes;
  late final TableSection<TextStyleRecord> textStyles;
  late final TableSection<PatternRecord> patterns;
  late final TableSection<DimStyleRecord> dimStyles;
  late final TableSection<AppIdRecord> appIds;

  int _revision = 0;
  final _TablesNotifier _changes = _TablesNotifier();

  /// Bumped by every table mutation that changed something.
  ///
  /// **Table mutations reach the command system not at all.** `DocChange` is
  /// emitted only by `undo.dart`, and a layer edit goes through `TableSection`
  /// directly, so before this counter existed a layer colour change produced
  /// no signal of any kind. Plan 3g's tile cache reads it, and
  /// `DraftCanvas` merges [changes] into its repaint listenable — the counter
  /// alone would be correct and never reached, because a layer edit causes no
  /// paint.
  ///
  /// **Every table record is `@immutable` with final fields, and `add` throws
  /// on a duplicate handle, so changing a record is necessarily
  /// remove-then-add and both are counted. If a record ever gains a setter,
  /// that mutation is invisible here.**
  int get mutationRevision => _revision;

  /// Notifies after any table mutation.
  Listenable get changes => _changes;

  void _bump() {
    _revision++;
    _changes.fire();
  }
```

`_TablesNotifier` is a three-line `ChangeNotifier` subclass exposing `notifyListeners`. **`package:jet_cad_2d` must not depend on Flutter**, so it cannot use `foundation.ChangeNotifier`; write the minimal listener list here:

```dart
/// A `Listenable` without Flutter.
///
/// `package:jet_cad_2d` is pure Dart on purpose — no `dart:ui`, no Flutter —
/// so `foundation.ChangeNotifier` is not available. This is the whole of the
/// contract `Listenable.merge` needs.
class _TablesNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void fire() {
    // Copied before iteration: a listener that removes itself while being
    // notified would otherwise mutate the list under the loop.
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}
```

`Listenable` and `VoidCallback` are Flutter types. **They are not available in this package.** Declare the minimal equivalents in `tables.dart`:

```dart
typedef VoidCallback = void Function();

/// The subset of Flutter's `Listenable` that `Listenable.merge` requires.
///
/// Declared here rather than imported: this package has no Flutter dependency
/// and gains none for one interface. Flutter's `Listenable.merge` accepts any
/// object with these two methods through its own `Listenable` type, so
/// `DraftCanvas` adapts this in Task 9 rather than passing it directly.
abstract class TableListenable {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}
```

and change `_TablesNotifier implements TableListenable`, `Listenable get changes` → `TableListenable get changes`. Task 9 wraps it.

- [ ] **Step 4: Run it and watch it pass**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/tables_revision_test.dart
```

- [ ] **Step 5: Run the whole engine suite**

The `DocumentTables` constructor changed from field initializers to `late final` assignment. `DocumentTables.standard()` and the JSON codec both construct sections; both must still pass.

```sh
cd packages/jet_cad_2d && CI=true dart test
```

- [ ] **Step 6: Fire mutant M8's counter half**

```sh
cp lib/src/document/tables.dart /tmp/tables.dart.bak
```

Remove `onMutated?.call();` from `clear` only. The `clear` assertion must go red and the other two stay green — which is the point: a per-mutator wiring mistake is invisible to a test that checks `add` alone. Restore:

```sh
cp /tmp/tables.dart.bak lib/src/document/tables.dart && rm /tmp/tables.dart.bak
```

- [ ] **Step 7: Green both packages and commit**

```sh
cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze
git add packages/jet_cad_2d/lib/src/document/tables.dart packages/jet_cad_2d/test/document/tables_revision_test.dart
git commit -m "feat: table mutations finally emit a signal

DocChange is emitted only by undo.dart when a command is applied, undone or
redone. Layer and linetype edits go through TableSection.add, remove and clear,
outside the command system, and emitted nothing at all -- so a layer colour
change produced no signal for any consumer to act on.

DocumentTables now owns a revision counter and a listener list, and every
section reports into it. The Listenable is declared here rather than imported:
this package has no Flutter dependency and gains none for one interface.

A rejected add and a remove of an absent handle both bump nothing. A clear
always does, because a clear of an empty section is still the caller declaring
the table replaced."
```

---

