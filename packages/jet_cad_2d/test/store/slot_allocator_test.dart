import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('allocates densely from zero', () {
    final slots = SlotAllocator();
    expect(slots.allocate(), 0);
    expect(slots.allocate(), 1);
    expect(slots.allocate(), 2);
    expect(slots.capacity, 3);
    expect(slots.liveCount, 3);
  });

  test('reuses a freed slot rather than growing', () {
    // Rule 2: deletion returns the slot to a free list. Growing instead would
    // leak capacity across an edit-heavy session.
    final slots = SlotAllocator();
    slots.allocate();
    final second = slots.allocate();
    slots.allocate();
    slots.free(second);
    expect(slots.liveCount, 2);
    expect(slots.allocate(), second);
    expect(slots.capacity, 3);
  });

  test('isLive and liveSlots report only live slots, in ascending order', () {
    final slots = SlotAllocator();
    for (var i = 0; i < 5; i++) {
      slots.allocate();
    }
    slots.free(1);
    slots.free(3);
    expect(slots.isLive(1), isFalse);
    expect(slots.isLive(2), isTrue);
    // Ascending order is required: query results must be stably ordered, and
    // hash iteration order would make tests flaky.
    expect(slots.liveSlots.toList(), [0, 2, 4]);
  });

  test('isLive is total and returns false outside the valid range', () {
    // isLive does not throw for out-of-range slots, unlike free.
    final slots = SlotAllocator();
    slots.allocate();
    slots.allocate();
    slots.allocate();
    expect(slots.isLive(-1), isFalse);
    expect(slots.isLive(slots.capacity), isFalse);
    expect(slots.isLive(999), isFalse);
  });

  test('rejects double free and out-of-range free', () {
    final slots = SlotAllocator();
    slots.allocate();
    slots.free(0);
    expect(() => slots.free(0), throwsA(isA<SlotStateError>()));
    expect(() => slots.free(7), throwsA(isA<SlotStateError>()));
    expect(() => slots.free(-1), throwsA(isA<SlotStateError>()));
  });

  test('compact returns a dense remap that preserves relative order', () {
    // Rule 3: compaction exists only inside an explicit purge, which rewrites
    // every reference using exactly this map.
    final slots = SlotAllocator();
    for (var i = 0; i < 5; i++) {
      slots.allocate();
    }
    slots.free(1);
    slots.free(3);

    final remap = slots.compact();
    expect(remap.length, 5);
    expect(remap[0], 0);
    expect(remap[1], -1); // dead
    expect(remap[2], 1);
    expect(remap[3], -1); // dead
    expect(remap[4], 2);

    expect(slots.capacity, 3);
    expect(slots.liveCount, 3);
    expect(slots.liveSlots.toList(), [0, 1, 2]);
    // The free list is empty after compaction, so the next allocation grows.
    expect(slots.allocate(), 3);
  });

  test('clear resets to the initial state', () {
    final slots = SlotAllocator();
    slots.allocate();
    slots.allocate();
    slots.clear();
    expect(slots.capacity, 0);
    expect(slots.liveCount, 0);
    expect(slots.allocate(), 0);
  });
}
