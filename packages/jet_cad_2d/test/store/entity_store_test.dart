import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

EntityRecord lineRecord(int handle, {int geomIndex = 0, int owner = 100}) =>
    EntityRecord(
      handle: Handle(handle),
      owner: Handle(owner),
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: geomIndex,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

EntityRecord _textRecord(Handle handle, {String text = ''}) => EntityRecord(
      handle: handle,
      owner: const Handle(100),
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kLineweightDefault,
      transparency: kByLayer,
      flags: 0,
      text: text,
    );

void main() {
  test('round-trips a record through the columns', () {
    final store = EntityStore();
    final record = lineRecord(0x2A, geomIndex: 7).copyWith(
      color: const TrueColor(0xFF8800),
      lineweight: 35,
      transparency: 128,
      flags: EntityFlags.invisible,
      linetypeScale: 2.5,
    );
    final slot = store.add(record);
    expect(store.read(slot), record);
  });

  test('column accessors agree with the record view', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(1, geomIndex: 9, owner: 55));
    expect(store.kindAt(slot), EntityKind.line);
    expect(store.ownerAt(slot), const Handle(55));
    expect(store.geomIndexAt(slot), 9);
    expect(store.layerAt(slot), ReservedHandles.layerZero);
    expect(store.colorAt(slot), kByLayer);
    expect(store.linetypeScaleAt(slot), 1.0);
    expect(store.flagsAt(slot), 0);
  });

  test('stores a handle at the 32-bit ceiling without truncating', () {
    // The columns are Uint32List, which is why the handle space is capped.
    final store = EntityStore();
    final slot = store.add(lineRecord(1, owner: kMaxHandle));
    expect(store.ownerAt(slot), const Handle(kMaxHandle));
  });

  test('rejects a duplicate handle', () {
    final store = EntityStore();
    store.add(lineRecord(5));
    expect(
        () => store.add(lineRecord(5)), throwsA(isA<DuplicateHandleError>()));
  });

  test('slotOf resolves a handle and returns null after removal', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(5));
    expect(store.slotOf(const Handle(5)), slot);
    expect(store.containsHandle(const Handle(5)), isTrue);
    store.remove(slot);
    expect(store.slotOf(const Handle(5)), isNull);
    expect(store.containsHandle(const Handle(5)), isFalse);
  });

  test('a removed slot is reused and the handle may be re-added', () {
    final store = EntityStore();
    final slot = store.add(lineRecord(5));
    store.remove(slot);
    // Undo restores the record; it may legitimately land in a different slot,
    // which is why the inverse command carries the record, not the slot.
    final restored = store.add(lineRecord(5));
    expect(store.read(restored).handle, const Handle(5));
    expect(store.liveCount, 1);
  });

  test('grows past the initial capacity without corrupting earlier rows', () {
    final store = EntityStore();
    for (var i = 1; i <= 300; i++) {
      store.add(lineRecord(i, geomIndex: i * 2));
    }
    expect(store.liveCount, 300);
    expect(store.geomIndexAt(store.slotOf(const Handle(1))!), 2);
    expect(store.geomIndexAt(store.slotOf(const Handle(300))!), 600);
  });

  test('liveSlots is ascending', () {
    final store = EntityStore();
    final a = store.add(lineRecord(1));
    final b = store.add(lineRecord(2));
    final c = store.add(lineRecord(3));
    store.remove(b);
    expect(store.liveSlots.toList(), [a, c]);
  });

  test('replace swaps the record in place and keeps the handle index correct',
      () {
    final store = EntityStore();
    final slot = store.add(lineRecord(5));
    store.replace(slot, lineRecord(5).copyWith(geomIndex: 42));
    expect(store.geomIndexAt(slot), 42);
    expect(store.slotOf(const Handle(5)), slot);
  });

  test('purge compacts entity slots and leaves geomIndex untouched', () {
    // Purging the entity store and purging the geometry store are independent
    // operations; geomIndex points into the other store.
    final store = EntityStore();
    final a = store.add(lineRecord(1, geomIndex: 10));
    final b = store.add(lineRecord(2, geomIndex: 20));
    final c = store.add(lineRecord(3, geomIndex: 30));
    store.remove(b);

    final remap = store.purge();
    expect(remap[a], 0);
    expect(remap[b], -1);
    expect(remap[c], 1);
    expect(store.geomIndexAt(remap[c]), 30);
    expect(store.slotOf(const Handle(3)), remap[c]);
    expect(store.slotOf(const Handle(2)), isNull);
  });

  test('record json round-trips every persisted field', () {
    final record = lineRecord(0x2A).copyWith(color: const IndexedColor(7));
    expect(EntityRecord.fromJson(record.toJson()), record);
  });

  test('geomIndex is neither written nor read back', () {
    // A slot is not durable state: it depends on allocation history, so
    // persisting it would make the same document encode differently before
    // and after a delete.
    final record = lineRecord(0x2A, geomIndex: 7);
    final json = record.toJson();
    expect(json.containsKey('geomIndex'), isFalse);
    expect(EntityRecord.fromJson(json).geomIndex, 0);
    // An older file still carries the field; the value is discarded, not
    // honoured, because it describes the store that wrote it.
    expect(EntityRecord.fromJson({...json, 'geomIndex': 7}).geomIndex, 0);
  });

  test('record json emits keys in a stable order', () {
    expect(lineRecord(1).toJson().keys.toList(), [
      'handle',
      'owner',
      'kind',
      'layer',
      'linetype',
      'linetypeScale',
      'color',
      'lineweight',
      'transparency',
      'flags',
    ]);
  });

  test('text fields round-trip through the store and clear on remove', () {
    final store = EntityStore();
    final slot = store.add(EntityRecord(
      handle: const Handle(1),
      owner: const Handle(100),
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
}
