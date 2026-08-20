## Task 0: Text columns on the store and the record

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/store/entity_store.dart`
- Test: `packages/jet_cad_2d/test/store/entity_store_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `EntityRecord({..., String text = '', String tag = '', Handle textStyle = ReservedHandles.standardTextStyle, int textAttrs = 0})`; `EntityStore.textAt(int slot) -> String`, `tagAt(int slot) -> String`, `textStyleAt(int slot) -> Handle`, `textAttrsAt(int slot) -> int`.

- [ ] **Step 1: Write the failing test**

```dart
// test/store/entity_store_test.dart
test('text fields round-trip through the store and clear on remove', () {
  final store = EntityStore();
  final slot = store.add(EntityRecord(
    handle: const Handle(1),
    owner: ReservedHandles.root,
    kind: EntityKind.text,
    layer: ReservedHandles.layerZero,
    linetype: ReservedHandles.byLayerLinetype,
    linetypeScale: 1.0,
    geomIndex: 0,
    color: const ByLayerColor(),
    lineweight: kLineweightDefault,
    transparency: kByLayer,
    flags: 0,
    text: 'WC',
    tag: 'ROOM',
    textStyle: const Handle(7),
    textAttrs: 0x0121,
  ));

  expect(store.textAt(slot), 'WC');
  expect(store.tagAt(slot), 'ROOM');
  expect(store.textStyleAt(slot), const Handle(7));
  expect(store.textAttrsAt(slot), 0x0121);
  expect(store.read(slot).text, 'WC');

  store.remove(slot);
  // Strings are heap references: an unreachable slot that still points at a
  // string keeps the whole document's text alive after deletion. The typed
  // columns can afford to keep stale numbers; these cannot.
  expect(store.debugRawTextAt(slot), '');
  expect(store.debugRawTagAt(slot), '');
});

test('purge carries the text columns with the slot', () {
  final store = EntityStore();
  final a = store.add(_textRecord(const Handle(1), text: 'A'));
  final b = store.add(_textRecord(const Handle(2), text: 'B'));
  store.remove(a);
  final remap = store.purge();
  expect(store.textAt(remap[b]), 'B');
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/store/entity_store_test.dart`
Expected: FAIL — `EntityRecord` has no named parameter `text`.

- [ ] **Step 3: Add the record fields**

In `EntityRecord`: four new final fields with defaults, added to the constructor, to `copyWith`, to `==`, and to `hashCode` — all three, because command inverses and the codec's idempotence tests compare records.

```dart
  /// The displayed string. `''` for every kind but [EntityKind.text] and
  /// [EntityKind.attrib].
  final String text;

  /// A DXF ATTRIB's tag. `''` for a TEXT.
  final String tag;

  final Handle textStyle;

  /// Packed: bits 0-3 horizontal justification (DXF 72), bits 4-7 vertical
  /// justification (DXF 73 for TEXT, **74 for ATTRIB** — for an ATTRIB, group
  /// 73 is field length, not justification), bit 8 `widthFactor` is
  /// overridden, bit 9 `obliqueAngle` is overridden.
  final int textAttrs;
```

- [ ] **Step 4: Add the columns**

```dart
  // Not typed lists, because a string is not a number. This is the one place
  // the all-typed-list shape of this store is broken, and interning into a
  // `Uint32List` index column is the recorded alternative — rejected for now
  // because it puts a refcount on the slot lifetime.
  List<String> _text = List<String>.filled(_initialCapacity, '');
  List<String> _tag = List<String>.filled(_initialCapacity, '');
  Uint32List _textStyle = Uint32List(_initialCapacity);
  Uint16List _textAttrs = Uint16List(_initialCapacity);
```

Extend `_write`, `read`, `_ensureCapacity` (`List<String>.filled(capacity, '')..setAll(0, _text)`), `purge` (copy all four), and `clear` (refill both string lists with `''`). In `remove`, before freeing the slot: `_text[slot] = ''; _tag[slot] = '';`.

Add the accessors, plus two debug-only readers the test above uses:

```dart
  String textAt(int slot) => _text[slot];
  String tagAt(int slot) => _tag[slot];
  Handle textStyleAt(int slot) => Handle(_textStyle[slot]);
  int textAttrsAt(int slot) => _textAttrs[slot];

  /// Reads the column without the live check, so a test can assert that
  /// [remove] released the string reference.
  @visibleForTesting
  String debugRawTextAt(int slot) => _text[slot];
  @visibleForTesting
  String debugRawTagAt(int slot) => _tag[slot];
```

- [ ] **Step 5: Run the store suite**

Run: `cd packages/jet_cad_2d && dart test test/store/`
Expected: PASS.

- [ ] **Step 6: Run the whole engine suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS — the defaults keep every existing record construction valid. The codec still writes ten keys; that is Task 1.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib/src/store/entity_store.dart packages/jet_cad_2d/test/store/entity_store_test.dart
git commit -m "feat(jet_cad_2d): store text content, tag, style and packed attributes"
```

---

