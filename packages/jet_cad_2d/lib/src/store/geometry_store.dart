import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../core/list_equality.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import 'slot_allocator.dart';

/// One entity's geometry, detached from any store.
///
/// Commands carry payloads rather than slots: the inverse of a delete has to be
/// able to restore geometry into whichever slot is free at the time.
@immutable
class GeometryPayload {
  /// Interleaved x, y pairs in document units.
  final Float64List coords;

  /// Everything that is not a coordinate: radius, start angle, sweep, text
  /// height. Kept apart from [coords] because a transform applies to points and
  /// must not apply to a radius or an angle in the same way.
  final Float64List scalars;

  const GeometryPayload({required this.coords, required this.scalars});

  int get pointCount => coords.length ~/ 2;

  Vector2 pointAt(int index) =>
      Vector2(coords[index * 2], coords[index * 2 + 1]);

  GeometryPayload transformedBy(Transform2 t) {
    final out = Float64List(coords.length);
    for (var i = 0; i < coords.length; i += 2) {
      out[i] = t.a * coords[i] + t.c * coords[i + 1] + t.e;
      out[i + 1] = t.b * coords[i] + t.d * coords[i + 1] + t.f;
    }
    return GeometryPayload(
      coords: out,
      scalars: Float64List.fromList(scalars),
    );
  }

  Map<String, Object?> toJson() => {
        'coords': coords.toList(),
        'scalars': scalars.toList(),
      };

  static GeometryPayload fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('GeometryPayload expects an object, got: $json');
    }
    return GeometryPayload(
      coords: _readDoubles(json['coords']),
      scalars: _readDoubles(json['scalars']),
    );
  }

  static Float64List _readDoubles(Object? json) {
    if (json is! List) {
      throw FormatException('expected a list of numbers, got: $json');
    }
    final out = Float64List(json.length);
    for (var i = 0; i < json.length; i++) {
      out[i] = (json[i] as num).toDouble();
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is GeometryPayload &&
      listEquals<double>(other.coords, coords) &&
      listEquals<double>(other.scalars, scalars);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(coords), Object.hashAll(scalars));
}

/// Columnar storage for leaf geometry.
///
/// Deliberately kind-agnostic: it stores blobs, not circles. Interpreting a
/// payload belongs to code that knows the entity kind, which is what keeps a
/// new geometry kind from needing to touch this file.
class GeometryStore {
  final SlotAllocator _slots = SlotAllocator();
  final List<GeometryPayload> _payloads = [];

  int get liveCount => _slots.liveCount;

  int add(GeometryPayload payload) {
    final slot = _slots.allocate();
    final stored = GeometryPayload(
      coords: Float64List.fromList(payload.coords),
      scalars: Float64List.fromList(payload.scalars),
    );
    if (slot == _payloads.length) {
      _payloads.add(stored);
    } else {
      _payloads[slot] = stored;
    }
    return slot;
  }

  /// A defensive copy. Callers routinely hand the result to a command as an
  /// inverse payload, and a shared buffer would let a later edit rewrite
  /// history.
  GeometryPayload read(int slot) {
    _requireLive(slot);
    final p = _payloads[slot];
    return GeometryPayload(
      coords: Float64List.fromList(p.coords),
      scalars: Float64List.fromList(p.scalars),
    );
  }

  /// The stored payload, **without copying**.
  ///
  /// The returned buffers are the store's own. Mutating them corrupts the
  /// document silently, and holding one past the next edit to this slot gives
  /// a caller a payload that changes underneath it.
  ///
  /// Exists for the frame path only — hit-testing and snapping read geometry
  /// per candidate at pointer-move rate, where [read]'s defensive copy costs
  /// three allocations per candidate. Anything that stores the result, and
  /// every command, must use [read] instead: an inverse payload sharing the
  /// store's buffer would let a later edit rewrite undo history, which is the
  /// exact hazard [read] exists to prevent.
  GeometryPayload peek(int slot) {
    _requireLive(slot);
    return _payloads[slot];
  }

  void replace(int slot, GeometryPayload payload) {
    _requireLive(slot);
    _payloads[slot] = GeometryPayload(
      coords: Float64List.fromList(payload.coords),
      scalars: Float64List.fromList(payload.scalars),
    );
  }

  void remove(int slot) {
    _requireLive(slot);
    _slots.free(slot);
    // Blank the dead entry so its buffers are released now rather than being
    // pinned until the slot is reused.
    _payloads[slot] =
        GeometryPayload(coords: Float64List(0), scalars: Float64List(0));
  }

  Aabb2 pointBounds(int slot) {
    _requireLive(slot);
    final p = _payloads[slot];
    var box = Aabb2.empty();
    for (var i = 0; i < p.coords.length; i += 2) {
      box = box.expandedToPoint(Vector2(p.coords[i], p.coords[i + 1]));
    }
    return box;
  }

  /// Explicit maintenance compaction. Returns the old-slot to new-slot remap;
  /// the caller must rewrite every reference and clear the undo stack. Never
  /// call this from a command.
  List<int> purge() {
    final remap = _slots.compact();
    final compacted = <GeometryPayload>[];
    for (var old = 0; old < remap.length; old++) {
      if (remap[old] >= 0) compacted.add(_payloads[old]);
    }
    _payloads
      ..clear()
      ..addAll(compacted);
    return remap;
  }

  void clear() {
    _slots.clear();
    _payloads.clear();
  }

  void _requireLive(int slot) {
    if (!_slots.isLive(slot)) throw SlotStateError(slot, 'not live');
  }
}
