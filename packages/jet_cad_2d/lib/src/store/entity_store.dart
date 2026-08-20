import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../core/handle.dart';
import '../document/style.dart';
import 'slot_allocator.dart';

enum EntityKind { point, line, polyline, circle, arc, text, attrib }

class DuplicateHandleError implements Exception {
  final Handle handle;
  const DuplicateHandleError(this.handle);

  @override
  String toString() => 'DuplicateHandleError(${handle.toHex()})';
}

/// A detached leaf record.
///
/// This is a **view**, constructed on demand — never the stored representation.
/// One object per entity is precisely what the columnar decision exists to
/// avoid; hot paths use the store's column accessors instead. Commands carry
/// records for the same reason they carry geometry payloads: an inverse must be
/// able to restore into whichever slot is free.
@immutable
class EntityRecord {
  final Handle handle;

  /// The definition, group node, instance node, or document root that owns
  /// this leaf. Leaf coordinates are expressed in the owner's space.
  final Handle owner;

  final EntityKind kind;
  final Handle layer;
  final Handle linetype;
  final double linetypeScale;

  /// Index into the document's [GeometryStore]. Opaque here.
  final int geomIndex;

  final DraftColor color;

  /// 1/100 mm, or one of [kByLayer], [kByBlock], [kLineweightDefault].
  final int lineweight;

  /// 0..255, or one of [kByLayer], [kByBlock].
  final int transparency;

  /// Bitmask; see [EntityFlags].
  final int flags;

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

  const EntityRecord({
    required this.handle,
    required this.owner,
    required this.kind,
    required this.layer,
    required this.linetype,
    required this.linetypeScale,
    required this.geomIndex,
    required this.color,
    required this.lineweight,
    required this.transparency,
    required this.flags,
    this.text = '',
    this.tag = '',
    this.textStyle = ReservedHandles.standardTextStyle,
    this.textAttrs = 0,
  });

  EntityRecord copyWith({
    Handle? handle,
    Handle? owner,
    EntityKind? kind,
    Handle? layer,
    Handle? linetype,
    double? linetypeScale,
    int? geomIndex,
    DraftColor? color,
    int? lineweight,
    int? transparency,
    int? flags,
    String? text,
    String? tag,
    Handle? textStyle,
    int? textAttrs,
  }) =>
      EntityRecord(
        handle: handle ?? this.handle,
        owner: owner ?? this.owner,
        kind: kind ?? this.kind,
        layer: layer ?? this.layer,
        linetype: linetype ?? this.linetype,
        linetypeScale: linetypeScale ?? this.linetypeScale,
        geomIndex: geomIndex ?? this.geomIndex,
        color: color ?? this.color,
        lineweight: lineweight ?? this.lineweight,
        transparency: transparency ?? this.transparency,
        flags: flags ?? this.flags,
        text: text ?? this.text,
        tag: tag ?? this.tag,
        textStyle: textStyle ?? this.textStyle,
        textAttrs: textAttrs ?? this.textAttrs,
      );

  /// Key order is fixed, because serialization must be byte-deterministic.
  ///
  /// [geomIndex] is deliberately **not** written. It is a slot in the geometry
  /// store, and slots are never persisted: a slot depends on allocation
  /// history, so a document with a hole in it would encode one set of indices
  /// and the same document reloaded — which reallocates densely — would encode
  /// another. That breaks the `save(load(save(d))) == save(d)` determinism
  /// guarantee outright. The codec stores each payload inline next to its
  /// record and re-points the record at whichever slot the payload lands in on
  /// load, so nothing downstream needs the number.
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'owner': owner.toJson(),
        'kind': kind.name,
        'layer': layer.toJson(),
        'linetype': linetype.toJson(),
        'linetypeScale': linetypeScale,
        'color': encodeColor(color),
        'lineweight': lineweight,
        'transparency': transparency,
        'flags': flags,
        'text': text,
        'tag': tag,
        'textStyle': textStyle.toJson(),
        'textAttrs': textAttrs,
      };

  /// [geomIndex] is always 0 on the way back in, whether or not the source
  /// names one. Files written before `geomIndex` was dropped from [toJson] do
  /// carry it, and that stored value is deliberately discarded rather than
  /// honoured: it describes the allocation history of the store that saved it,
  /// which has nothing to do with the store loading it. The caller re-points
  /// the record with [copyWith] at the slot its geometry actually receives.
  static EntityRecord fromJson(Object? json) {
    if (json is! Map) {
      throw FormatException('EntityRecord expects an object, got: $json');
    }
    return EntityRecord(
      handle: Handle.fromJson(json['handle']),
      owner: Handle.fromJson(json['owner']),
      kind: EntityKind.values.byName(json['kind']! as String),
      layer: Handle.fromJson(json['layer']),
      linetype: Handle.fromJson(json['linetype']),
      linetypeScale: (json['linetypeScale']! as num).toDouble(),
      geomIndex: 0,
      color: decodeColor(json['color']! as int),
      lineweight: json['lineweight']! as int,
      transparency: json['transparency']! as int,
      flags: json['flags']! as int,
      // Absent in a schema-3 document — these four defaults *are* the
      // v3->v4 migration. `DraftDocumentCodec.decode` accepts anything from
      // schema 1 through the current version, so a document written before
      // Plan 3c reaches this constructor with none of these keys set, and
      // the record ends up exactly as if it had always carried empty text.
      text: json['text'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      textStyle: json['textStyle'] == null
          ? ReservedHandles.standardTextStyle
          : Handle.fromJson(json['textStyle']),
      textAttrs: json['textAttrs'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntityRecord &&
      other.handle == handle &&
      other.owner == owner &&
      other.kind == kind &&
      other.layer == layer &&
      other.linetype == linetype &&
      other.linetypeScale == linetypeScale &&
      other.geomIndex == geomIndex &&
      other.color == color &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.flags == flags &&
      other.text == text &&
      other.tag == tag &&
      other.textStyle == textStyle &&
      other.textAttrs == textAttrs;

  @override
  int get hashCode => Object.hash(
      handle,
      owner,
      kind,
      layer,
      linetype,
      linetypeScale,
      geomIndex,
      color,
      lineweight,
      transparency,
      flags,
      text,
      tag,
      textStyle,
      textAttrs);

  @override
  String toString() => 'EntityRecord(${kind.name} ${handle.toHex()})';
}

/// Columnar storage for leaf entity records, including tier-1 style.
///
/// Style lives in columns here rather than in a component store because these
/// are native CAD fields required for lossless round-trip, whereas components
/// are the extension mechanism. Defaults are `BYLAYER` sentinels, so the common
/// case costs one small integer per column.
class EntityStore {
  static const int _initialCapacity = 64;

  final SlotAllocator _slots = SlotAllocator();
  final Map<Handle, int> _slotOf = {};

  Uint8List _kind = Uint8List(_initialCapacity);
  Uint32List _owner = Uint32List(_initialCapacity);
  Uint32List _handle = Uint32List(_initialCapacity);
  Uint32List _layer = Uint32List(_initialCapacity);
  Uint32List _linetype = Uint32List(_initialCapacity);
  Float64List _linetypeScale = Float64List(_initialCapacity);
  Uint32List _geomIndex = Uint32List(_initialCapacity);
  Int32List _color = Int32List(_initialCapacity);
  Int16List _lineweight = Int16List(_initialCapacity);

  /// `Int16` rather than `Uint8`: transparency may itself be BYLAYER or
  /// BYBLOCK, and those sentinels are negative.
  Int16List _transparency = Int16List(_initialCapacity);

  Uint8List _flags = Uint8List(_initialCapacity);

  // Not typed lists, because a string is not a number. This is the one place
  // the all-typed-list shape of this store is broken, and interning into a
  // `Uint32List` index column is the recorded alternative — rejected for now
  // because it puts a refcount on the slot lifetime.
  List<String> _text = List<String>.filled(_initialCapacity, '');
  List<String> _tag = List<String>.filled(_initialCapacity, '');
  Uint32List _textStyle = Uint32List(_initialCapacity);
  Uint16List _textAttrs = Uint16List(_initialCapacity);

  int get liveCount => _slots.liveCount;

  Iterable<int> get liveSlots => _slots.liveSlots;

  int? slotOf(Handle handle) => _slotOf[handle];

  bool containsHandle(Handle handle) => _slotOf.containsKey(handle);

  int add(EntityRecord record) {
    if (_slotOf.containsKey(record.handle)) {
      throw DuplicateHandleError(record.handle);
    }
    final slot = _slots.allocate();
    _ensureCapacity(_slots.capacity);
    _write(slot, record);
    _slotOf[record.handle] = slot;
    return slot;
  }

  EntityRecord read(int slot) {
    _requireLive(slot);
    return EntityRecord(
      handle: Handle(_handle[slot]),
      owner: Handle(_owner[slot]),
      kind: EntityKind.values[_kind[slot]],
      layer: Handle(_layer[slot]),
      linetype: Handle(_linetype[slot]),
      linetypeScale: _linetypeScale[slot],
      geomIndex: _geomIndex[slot],
      color: decodeColor(_color[slot]),
      lineweight: _lineweight[slot],
      transparency: _transparency[slot],
      flags: _flags[slot],
      text: _text[slot],
      tag: _tag[slot],
      textStyle: Handle(_textStyle[slot]),
      textAttrs: _textAttrs[slot],
    );
  }

  void replace(int slot, EntityRecord record) {
    _requireLive(slot);
    final existing = Handle(_handle[slot]);
    if (record.handle != existing) {
      if (_slotOf.containsKey(record.handle)) {
        throw DuplicateHandleError(record.handle);
      }
      _slotOf.remove(existing);
      _slotOf[record.handle] = slot;
    }
    _write(slot, record);
  }

  void remove(int slot) {
    _requireLive(slot);
    _slotOf.remove(Handle(_handle[slot]));
    // Strings are heap references, unlike every other column here: a stale
    // number left behind in a freed slot is harmless, but a stale string
    // reference keeps the whole document's text alive after deletion. Clear
    // both before freeing so removal actually releases the memory.
    _text[slot] = '';
    _tag[slot] = '';
    _slots.free(slot);
  }

  EntityKind kindAt(int slot) => EntityKind.values[_kind[slot]];
  Handle ownerAt(int slot) => Handle(_owner[slot]);
  Handle handleAt(int slot) => Handle(_handle[slot]);
  Handle layerAt(int slot) => Handle(_layer[slot]);
  Handle linetypeAt(int slot) => Handle(_linetype[slot]);
  double linetypeScaleAt(int slot) => _linetypeScale[slot];
  int geomIndexAt(int slot) => _geomIndex[slot];
  int colorAt(int slot) => _color[slot];
  int lineweightAt(int slot) => _lineweight[slot];
  int transparencyAt(int slot) => _transparency[slot];
  int flagsAt(int slot) => _flags[slot];
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

  /// Explicit maintenance compaction of **entity** slots.
  ///
  /// Returns the old-slot to new-slot remap. `geomIndex` values are references
  /// into the geometry store and are deliberately untouched: purging the two
  /// stores are independent operations. The caller must rewrite every reference
  /// to an entity slot and clear the undo stack.
  List<int> purge() {
    final remap = _slots.compact();
    for (var old = 0; old < remap.length; old++) {
      final to = remap[old];
      if (to < 0 || to == old) continue;
      _kind[to] = _kind[old];
      _owner[to] = _owner[old];
      _handle[to] = _handle[old];
      _layer[to] = _layer[old];
      _linetype[to] = _linetype[old];
      _linetypeScale[to] = _linetypeScale[old];
      _geomIndex[to] = _geomIndex[old];
      _color[to] = _color[old];
      _lineweight[to] = _lineweight[old];
      _transparency[to] = _transparency[old];
      _flags[to] = _flags[old];
      _text[to] = _text[old];
      _tag[to] = _tag[old];
      _textStyle[to] = _textStyle[old];
      _textAttrs[to] = _textAttrs[old];
    }
    _slotOf.clear();
    for (final slot in _slots.liveSlots) {
      _slotOf[Handle(_handle[slot])] = slot;
    }
    return remap;
  }

  void clear() {
    _slots.clear();
    _slotOf.clear();
    // Refill rather than leave stale references: the numeric columns don't
    // need this because a stray number is harmless, but a stray string keeps
    // the whole document's text alive.
    _text = List<String>.filled(_text.length, '');
    _tag = List<String>.filled(_tag.length, '');
  }

  void _write(int slot, EntityRecord r) {
    _kind[slot] = r.kind.index;
    _owner[slot] = r.owner.value;
    _handle[slot] = r.handle.value;
    _layer[slot] = r.layer.value;
    _linetype[slot] = r.linetype.value;
    _linetypeScale[slot] = r.linetypeScale;
    _geomIndex[slot] = r.geomIndex;
    _color[slot] = encodeColor(r.color);
    _lineweight[slot] = r.lineweight;
    _transparency[slot] = r.transparency;
    _flags[slot] = r.flags;
    _text[slot] = r.text;
    _tag[slot] = r.tag;
    _textStyle[slot] = r.textStyle.value;
    _textAttrs[slot] = r.textAttrs;
  }

  /// Growth reallocates and copies. It never reorders live slots, because a
  /// slot value may only change inside a command that rewrites every reference
  /// to it — and growing is not such a command.
  void _ensureCapacity(int needed) {
    if (needed <= _kind.length) return;
    var capacity = _kind.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    _kind = Uint8List(capacity)..setAll(0, _kind);
    _owner = Uint32List(capacity)..setAll(0, _owner);
    _handle = Uint32List(capacity)..setAll(0, _handle);
    _layer = Uint32List(capacity)..setAll(0, _layer);
    _linetype = Uint32List(capacity)..setAll(0, _linetype);
    _linetypeScale = Float64List(capacity)..setAll(0, _linetypeScale);
    _geomIndex = Uint32List(capacity)..setAll(0, _geomIndex);
    _color = Int32List(capacity)..setAll(0, _color);
    _lineweight = Int16List(capacity)..setAll(0, _lineweight);
    _transparency = Int16List(capacity)..setAll(0, _transparency);
    _flags = Uint8List(capacity)..setAll(0, _flags);
    _text = List<String>.filled(capacity, '')..setAll(0, _text);
    _tag = List<String>.filled(capacity, '')..setAll(0, _tag);
    _textStyle = Uint32List(capacity)..setAll(0, _textStyle);
    _textAttrs = Uint16List(capacity)..setAll(0, _textAttrs);
  }

  void _requireLive(int slot) {
    if (!_slots.isLive(slot)) throw SlotStateError(slot, 'not live');
  }
}
