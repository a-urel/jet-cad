/// The document's handle ceiling.
///
/// Entity records store handles in `Uint32List` columns, so this is a storage
/// invariant on every platform rather than a `dart2js` integer-precision quirk.
/// Long-lived drawings do exceed it; import range-checks against this value and
/// compacts the handle space when it must, which is safe because the original
/// identifier survives in an origin component.
const int kMaxHandle = 0xFFFFFFFF;

/// Thrown when a value cannot be a handle.
class HandleRangeError implements Exception {
  final Object? value;
  final String message;
  const HandleRangeError(this.value, this.message);

  @override
  String toString() => 'HandleRangeError($value): $message';
}

/// Stable identifier for anything addressable in a document — nodes, entities,
/// definitions, and every table record — drawn from one shared space.
///
/// This is an extension type, so it is erased at runtime: `Map<Handle, X>` and
/// `Map<int, X>` are the same type, and a JSON decoder hands back a bare `int`.
/// The type provides static safety only; boundaries must wrap explicitly via
/// [Handle.fromJson].
extension type const Handle(int value) {
  /// The absent handle. DXF treats handle 0 as invalid, so fields use this
  /// rather than `Handle?` — a nullable handle and an implicit zero would both
  /// appear in the codebase and diverge.
  static const Handle none = Handle(0);

  bool get isNone => value == 0;

  /// Range-checked construction. Use at every boundary that accepts a number
  /// from outside the engine.
  static Handle checked(int value) {
    if (value < 0 || value > kMaxHandle) {
      throw HandleRangeError(value, 'outside 0..$kMaxHandle');
    }
    return Handle(value);
  }

  static Handle parseHex(String hex) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) throw HandleRangeError(hex, 'not hexadecimal');
    return checked(parsed);
  }

  static Handle fromJson(Object? json) {
    if (json is! int) throw HandleRangeError(json, 'expected int');
    return checked(json);
  }

  String toHex() => value.toRadixString(16).toUpperCase();

  int toJson() => value;
}

/// Monotonic handle allocator. One per document.
class HandleSeed {
  int _current;

  HandleSeed([Handle start = Handle.none]) : _current = start.value;

  Handle get current => Handle(_current);

  Handle next() {
    if (_current >= kMaxHandle) {
      throw const HandleRangeError(kMaxHandle, 'handle space exhausted');
    }
    return Handle(++_current);
  }

  /// Moves the seed forward to at least [handle]. Never moves it backward —
  /// import raises the seed above the highest handle it read, and a later
  /// smaller value must not reopen already-issued handles.
  void raiseTo(Handle handle) {
    if (handle.value > _current) _current = handle.value;
  }
}
