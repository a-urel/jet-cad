import 'package:meta/meta.dart';

import '../core/handle.dart';
import '../core/list_equality.dart';
import '../store/entity_store.dart' show DuplicateHandleError;
import 'style.dart';

class DuplicateTableNameError implements Exception {
  final String name;
  const DuplicateTableNameError(this.name);

  @override
  String toString() => 'DuplicateTableNameError($name)';
}

@immutable
abstract class TableRecord {
  Handle get handle;
  String get name;
  Map<String, Object?> toJson();
}

typedef TableListener = void Function();

/// The subset of Flutter's `Listenable` that `Listenable.merge` requires.
///
/// Declared here rather than imported: this package has no Flutter dependency
/// and gains none for one interface. Flutter's `Listenable.merge` accepts any
/// object with these two methods through its own `Listenable` type, so
/// `DraftCanvas` adapts this in Task 9 rather than passing it directly.
abstract class TableListenable {
  void addListener(TableListener listener);
  void removeListener(TableListener listener);
}

/// A `Listenable` without Flutter.
///
/// `package:jet_cad_2d` is pure Dart on purpose — no `dart:ui`, no Flutter —
/// so `foundation.ChangeNotifier` is not available. This is the whole of the
/// contract `Listenable.merge` needs.
class _TablesNotifier implements TableListenable {
  final List<TableListener> _listeners = [];

  @override
  void addListener(TableListener listener) => _listeners.add(listener);

  @override
  void removeListener(TableListener listener) => _listeners.remove(listener);

  /// How many listeners are attached. **Test-only.**
  ///
  /// This list has no automatic cleanup and this class has no `dispose`, so
  /// every subscriber is responsible for its own removal. The only subscriber
  /// is `DraftCanvas`'s adapter, which re-attaches whenever a prop change
  /// rebuilds its derived state; an adapter that unsubscribed on `dispose`
  /// alone would leak one listener per re-attach, forever, and nothing else
  /// in the system could see it happening. This is what makes that visible.
  int get listenerCount => _listeners.length;

  void fire() {
    // Copied before iteration: a listener that removes itself while being
    // notified would otherwise mutate the list under the loop.
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}

/// One named table — layers, linetypes, text styles, and so on.
///
/// Generic rather than six near-identical classes: the only thing that varies
/// per table is the record type.
class TableSection<T extends TableRecord> {
  /// Called after `add` or `remove` actually changes this section, and
  /// unconditionally by `clear()` — `clear()` fires even when the section was
  /// already empty, since [DraftDocument.empty]'s seeded records mean a load
  /// (`json_codec.dart`) always calls `clear()` on all six sections before
  /// repopulating them, and that reset must be observable whether or not the
  /// section it targets happened to hold anything.
  ///
  /// **Not a `ChangeNotifier` of its own.** `DocumentTables` holds six sections
  /// as `late final` fields with no back-reference (`tables.dart`), and a
  /// notifier per section would make a listener subscribe six times and a
  /// caller reason about six revisions. One counter on the owner is the whole
  /// contract Plan 3g needs.
  TableSection({this.onMutated});

  final void Function()? onMutated;

  final Map<Handle, T> _byHandle = {};
  final Map<String, Handle> _byName = {};

  int get length => _byHandle.length;

  bool contains(Handle handle) => _byHandle.containsKey(handle);

  T? operator [](Handle handle) => _byHandle[handle];

  /// DXF table names are case-insensitive, so lookup folds case.
  T? byName(String name) {
    final handle = _byName[name.toLowerCase()];
    return handle == null ? null : _byHandle[handle];
  }

  /// Ascending handle order. Serialization walks this, and byte-identical
  /// output cannot depend on insertion or hash order.
  Iterable<T> get records {
    final handles = _byHandle.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final h in handles) _byHandle[h]!];
  }

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

  void remove(Handle handle) {
    final record = _byHandle.remove(handle);
    if (record == null) return;
    _byName.remove(record.name.toLowerCase());
    onMutated?.call();
  }

  void clear() {
    _byHandle.clear();
    _byName.clear();
    onMutated?.call();
  }
}

@immutable
class LayerRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final DraftColor color;
  final Handle linetype;
  final int lineweight;
  final int transparency;
  final bool visible;
  final bool locked;

  const LayerRecord({
    required this.handle,
    required this.name,
    required this.color,
    required this.linetype,
    required this.lineweight,
    required this.transparency,
    this.visible = true,
    this.locked = false,
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'color': encodeColor(color),
        'linetype': linetype.toJson(),
        'lineweight': lineweight,
        'transparency': transparency,
        'visible': visible,
        'locked': locked,
      };

  static LayerRecord fromJson(Map<String, Object?> json) => LayerRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        color: decodeColor(json['color']! as int),
        linetype: Handle.fromJson(json['linetype']),
        lineweight: json['lineweight']! as int,
        transparency: json['transparency']! as int,
        visible: json['visible']! as bool,
        locked: json['locked']! as bool,
      );

  @override
  bool operator ==(Object other) =>
      other is LayerRecord &&
      other.handle == handle &&
      other.name == name &&
      other.color == color &&
      other.linetype == linetype &&
      other.lineweight == lineweight &&
      other.transparency == transparency &&
      other.visible == visible &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(
      handle, name, color, linetype, lineweight, transparency, visible, locked);
}

/// A linetype's dash sequence, in **paper** units.
///
/// Positive values are dashes, negative values are gaps — the DXF convention.
/// Paper units, not world units, because a dash pattern must not stretch when
/// the drawing is zoomed.
@immutable
class DashPattern {
  final List<double> dashes;
  final double totalLength;

  const DashPattern({required this.dashes, required this.totalLength});

  Map<String, Object?> toJson() =>
      {'dashes': dashes, 'totalLength': totalLength};

  static DashPattern fromJson(Map<String, Object?> json) => DashPattern(
        dashes: [
          for (final d in json['dashes']! as List) (d as num).toDouble(),
        ],
        totalLength: (json['totalLength']! as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is DashPattern &&
      other.totalLength == totalLength &&
      listEquals(other.dashes, dashes);

  @override
  int get hashCode => Object.hash(Object.hashAll(dashes), totalLength);
}

@immutable
class LinetypeRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final String description;
  final DashPattern pattern;

  const LinetypeRecord({
    required this.handle,
    required this.name,
    required this.description,
    required this.pattern,
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'description': description,
        'pattern': pattern.toJson(),
      };

  static LinetypeRecord fromJson(Map<String, Object?> json) => LinetypeRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        description: json['description']! as String,
        pattern: DashPattern.fromJson(
            (json['pattern']! as Map).cast<String, Object?>()),
      );

  @override
  bool operator ==(Object other) =>
      other is LinetypeRecord &&
      other.handle == handle &&
      other.name == name &&
      other.description == description &&
      other.pattern == pattern;

  @override
  int get hashCode => Object.hash(handle, name, description, pattern);
}

@immutable
class TextStyleRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;

  /// The font used for display. SHX styles map here too — see [isShx].
  final String fontFamily;

  final double widthFactor;
  final double obliqueAngle;

  /// Zero means the height is supplied per text entity.
  final double fixedHeight;

  /// True when the original style named an SHX font. Display maps to
  /// [fontFamily] and is declared lossy; the flag and [shxFileName] exist so
  /// the original survives a round-trip.
  final bool isShx;
  final String shxFileName;

  const TextStyleRecord({
    required this.handle,
    required this.name,
    required this.fontFamily,
    this.widthFactor = 1.0,
    this.obliqueAngle = 0.0,
    this.fixedHeight = 0.0,
    this.isShx = false,
    this.shxFileName = '',
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'fontFamily': fontFamily,
        'widthFactor': widthFactor,
        'obliqueAngle': obliqueAngle,
        'fixedHeight': fixedHeight,
        'isShx': isShx,
        'shxFileName': shxFileName,
      };

  static TextStyleRecord fromJson(Map<String, Object?> json) => TextStyleRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        fontFamily: json['fontFamily']! as String,
        widthFactor: (json['widthFactor']! as num).toDouble(),
        obliqueAngle: (json['obliqueAngle']! as num).toDouble(),
        fixedHeight: (json['fixedHeight']! as num).toDouble(),
        isShx: json['isShx']! as bool,
        shxFileName: json['shxFileName']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is TextStyleRecord &&
      other.handle == handle &&
      other.name == name &&
      other.fontFamily == fontFamily &&
      other.widthFactor == widthFactor &&
      other.obliqueAngle == obliqueAngle &&
      other.fixedHeight == fixedHeight &&
      other.isShx == isShx &&
      other.shxFileName == shxFileName;

  @override
  int get hashCode => Object.hash(handle, name, fontFamily, widthFactor,
      obliqueAngle, fixedHeight, isShx, shxFileName);
}

/// One line family of a hatch pattern, in the `.pat` sense.
@immutable
class PatternLine {
  final double angle;
  final double baseX;
  final double baseY;
  final double deltaX;
  final double deltaY;
  final List<double> dashes;

  const PatternLine({
    required this.angle,
    required this.baseX,
    required this.baseY,
    required this.deltaX,
    required this.deltaY,
    required this.dashes,
  });

  Map<String, Object?> toJson() => {
        'angle': angle,
        'baseX': baseX,
        'baseY': baseY,
        'deltaX': deltaX,
        'deltaY': deltaY,
        'dashes': dashes,
      };

  static PatternLine fromJson(Map<String, Object?> json) => PatternLine(
        angle: (json['angle']! as num).toDouble(),
        baseX: (json['baseX']! as num).toDouble(),
        baseY: (json['baseY']! as num).toDouble(),
        deltaX: (json['deltaX']! as num).toDouble(),
        deltaY: (json['deltaY']! as num).toDouble(),
        dashes: [
          for (final d in json['dashes']! as List) (d as num).toDouble(),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is PatternLine &&
      other.angle == angle &&
      other.baseX == baseX &&
      other.baseY == baseY &&
      other.deltaX == deltaX &&
      other.deltaY == deltaY &&
      listEquals(other.dashes, dashes);

  @override
  int get hashCode =>
      Object.hash(angle, baseX, baseY, deltaX, deltaY, Object.hashAll(dashes));
}

@immutable
class PatternRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final List<PatternLine> lines;

  const PatternRecord({
    required this.handle,
    required this.name,
    required this.lines,
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        'lines': [for (final l in lines) l.toJson()],
      };

  static PatternRecord fromJson(Map<String, Object?> json) => PatternRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        lines: [
          for (final l in json['lines']! as List)
            PatternLine.fromJson((l as Map).cast<String, Object?>()),
        ],
      );

  @override
  bool operator ==(Object other) =>
      other is PatternRecord &&
      other.handle == handle &&
      other.name == name &&
      listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(handle, name, Object.hashAll(lines));
}

/// A dimension style, preserved but never interpreted.
///
/// Dimension *editing* is a non-goal: regenerating dimension geometry needs a
/// full DIMSTYLE engine, which this architecture explicitly does not build. The
/// record exists so an imported style survives a round-trip unchanged.
@immutable
class DimStyleRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;
  final Map<String, Object?> opaque;

  const DimStyleRecord({
    required this.handle,
    required this.name,
    this.opaque = const {},
  });

  @override
  Map<String, Object?> toJson() => {
        'handle': handle.toJson(),
        'name': name,
        // Sorted so serialization stays byte-deterministic across runs.
        'opaque': {
          for (final key in opaque.keys.toList()..sort()) key: opaque[key],
        },
      };

  static DimStyleRecord fromJson(Map<String, Object?> json) => DimStyleRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
        opaque: (json['opaque']! as Map).cast<String, Object?>(),
      );

  @override
  bool operator ==(Object other) =>
      other is DimStyleRecord &&
      other.handle == handle &&
      other.name == name &&
      _sameOpaque(other.opaque, opaque);

  static bool _sameOpaque(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        handle,
        name,
        // Sorted key/value pairs, same basis as toJson's sorted traversal, so
        // the hash is order-independent and matches _sameOpaque's semantics.
        Object.hashAll([
          for (final key in opaque.keys.toList()..sort())
            Object.hash(key, opaque[key]),
        ]),
      );
}

@immutable
class AppIdRecord implements TableRecord {
  @override
  final Handle handle;
  @override
  final String name;

  const AppIdRecord({required this.handle, required this.name});

  @override
  Map<String, Object?> toJson() => {'handle': handle.toJson(), 'name': name};

  static AppIdRecord fromJson(Map<String, Object?> json) => AppIdRecord(
        handle: Handle.fromJson(json['handle']),
        name: json['name']! as String,
      );

  @override
  bool operator ==(Object other) =>
      other is AppIdRecord && other.handle == handle && other.name == name;

  @override
  int get hashCode => Object.hash(handle, name);
}

/// Every named table a document owns.
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
  TableListenable get changes => _changes;

  /// How many listeners [changes] currently holds. **Test-only.**
  ///
  /// See `_TablesNotifier.listenerCount`: the leak this exposes is a
  /// subscriber that re-attaches without detaching, and there is no other
  /// instrument for it.
  int get debugListenerCount => _changes.listenerCount;

  void _bump() {
    _revision++;
    _changes.fire();
  }

  /// Seeds the records a document cannot function without.
  ///
  /// BYLAYER and BYBLOCK are real linetype records rather than magic values, so
  /// the entity linetype column needs no sentinels; layer 0 must exist because
  /// it carries the block-inheritance rule. The order records are added in
  /// below is arbitrary: `TableSection.add` does no cross-table referential
  /// validation, so nothing here depends on linetypes preceding the layer.
  factory DocumentTables.standard() {
    final tables = DocumentTables();
    tables.linetypes
      ..add(const LinetypeRecord(
        handle: ReservedHandles.byLayerLinetype,
        name: 'ByLayer',
        description: '',
        pattern: DashPattern(dashes: [], totalLength: 0),
      ))
      ..add(const LinetypeRecord(
        handle: ReservedHandles.byBlockLinetype,
        name: 'ByBlock',
        description: '',
        pattern: DashPattern(dashes: [], totalLength: 0),
      ))
      ..add(const LinetypeRecord(
        handle: ReservedHandles.continuousLinetype,
        name: 'Continuous',
        description: 'Solid line',
        pattern: DashPattern(dashes: [], totalLength: 0),
      ));
    tables.layers.add(const LayerRecord(
      handle: ReservedHandles.layerZero,
      name: '0',
      color: IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
    ));
    tables.textStyles.add(const TextStyleRecord(
      handle: ReservedHandles.standardTextStyle,
      name: 'Standard',
      fontFamily: 'Roboto',
    ));
    return tables;
  }
}
