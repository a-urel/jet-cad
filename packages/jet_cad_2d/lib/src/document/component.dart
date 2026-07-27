import '../core/handle.dart';
import 'origin_component.dart';

/// Extension data attached to any handle.
///
/// Contract for every implementation: **immutable, value-equal, and [toJson]
/// emits keys in a fixed order.** Value equality lets value-diff undo compare
/// and restore component state; fixed key order keeps serialization
/// byte-deterministic.
///
/// Data only, never behavior. Behavior lives in application-side systems, so
/// that the document stays serializable, deterministic and undoable.
abstract class Component {
  String get typeId;
  Map<String, Object?> toJson();
}

typedef ComponentFactory<T extends Component> = T Function(
    Map<String, Object?> json);

class UnregisteredComponentError implements Exception {
  final Type type;
  const UnregisteredComponentError(this.type);

  @override
  String toString() =>
      'UnregisteredComponentError($type): call registry.register first';
}

/// Sparse storage for one component type.
class ComponentStore<T extends Component> {
  final Map<Handle, T> _byHandle = {};

  int get length => _byHandle.length;

  T? operator [](Handle handle) => _byHandle[handle];

  void set(Handle handle, T component) => _byHandle[handle] = component;

  void remove(Handle handle) => _byHandle.remove(handle);

  /// Ascending, so query results are stably ordered.
  Iterable<Handle> get handles {
    final list = _byHandle.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  void clear() => _byHandle.clear();
}

/// All component stores for one document, plus the type-id mapping.
///
/// Stores are sparse and keyed by `Type` rather than living on each entity:
/// entity records stay lean at scale, and "every handle carrying component X"
/// costs the component count rather than the entity count.
class ComponentRegistry {
  final Map<Type, ComponentStore<Component>> _stores = {};
  final Map<Type, String> _typeIdOf = {};
  final Map<String, ComponentFactory<Component>> _factories = {};
  final Map<String, Type> _typeOf = {};
  final Set<String> _internal = {};

  /// Preserved verbatim: types this build has never heard of.
  final Map<Handle, List<Map<String, Object?>>> _unknown = {};

  void register<T extends Component>(
    String typeId,
    ComponentFactory<T> factory, {
    bool internal = false,
  }) {
    _stores[T] = ComponentStore<Component>();
    _typeIdOf[T] = typeId;
    _typeOf[typeId] = T;
    _factories[typeId] = factory;
    if (internal) _internal.add(typeId);
  }

  /// Registers the component types the engine owns.
  void registerBuiltIns() {
    register<OriginComponent>(
      OriginComponent.componentTypeId,
      OriginComponent.fromJson,
      internal: true,
    );
  }

  /// True when a component type must never be written to a foreign format as
  /// extended data.
  bool isInternal(String typeId) => _internal.contains(typeId);

  void attach<T extends Component>(Handle handle, T component) {
    final store = _stores[T];
    if (store == null) throw UnregisteredComponentError(T);
    store.set(handle, component);
  }

  T? get<T extends Component>(Handle handle) => _stores[T]?[handle] as T?;

  void detach<T extends Component>(Handle handle) => _stores[T]?.remove(handle);

  Iterable<Handle> withComponent<T extends Component>() =>
      _stores[T]?.handles ?? const <Handle>[];

  /// Records a component whose `typeId` this build does not know. The payload
  /// is stored exactly as read and written back unchanged.
  void attachUnknown(Handle handle, Map<String, Object?> json) =>
      _unknown.putIfAbsent(handle, () => []).add(json);

  /// The unknown-component payloads recorded for [handle], oldest first.
  ///
  /// The **list** is a read-only view: handing back the store's own growable
  /// list let a caller `clear()` it and delete an entire handle's worth of
  /// preserve-unknown data with no call to [attachUnknown] or [clear] and no
  /// way for the store to notice — the next save simply wrote nothing.
  ///
  /// The **payloads** inside it are the same references the store holds, not
  /// copies, exactly as documented on [RawDataStore.get]: this registry never
  /// inspects an unknown payload, so it has no way to clone one and no reason
  /// to. Treat a payload obtained here as immutable. Mutating one in place
  /// mutates what a later save writes, which is the one thing
  /// preserve-unknown exists to prevent.
  List<Map<String, Object?>> unknownOf(Handle handle) =>
      List.unmodifiable(_unknown[handle] ?? const []);

  /// Shape: `{ typeId: { handleDecimal: payload } }`.
  ///
  /// Type ids sort lexicographically and handles sort numerically, so the same
  /// registry always produces the same bytes.
  Map<String, Object?> toJson() {
    final byTypeId = <String, Map<String, Object?>>{};

    for (final entry in _stores.entries) {
      final typeId = _typeIdOf[entry.key]!;
      for (final handle in entry.value.handles) {
        (byTypeId[typeId] ??= {})[handle.value.toString()] =
            entry.value[handle]!.toJson();
      }
    }

    final unknownHandles = _unknown.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final handle in unknownHandles) {
      for (final payload in _unknown[handle]!) {
        final typeId = payload['typeId']! as String;
        // The enclosing map key already names the type, so the written
        // payload must not duplicate it — mirrors the registered branch,
        // whose `toJson()` never embeds its own typeId. `unknownOf` keeps the
        // stored copy (with typeId) untouched; only the written form is bare.
        final withoutTypeId = {
          for (final e in payload.entries)
            if (e.key != 'typeId') e.key: e.value,
        };
        (byTypeId[typeId] ??= {})[handle.value.toString()] = withoutTypeId;
      }
    }

    final sortedTypeIds = byTypeId.keys.toList()..sort();
    return {
      for (final typeId in sortedTypeIds)
        typeId: _sortedByHandle(byTypeId[typeId]!),
    };
  }

  static Map<String, Object?> _sortedByHandle(Map<String, Object?> raw) {
    final keys = raw.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return {for (final k in keys) k: raw[k]};
  }

  void loadJson(Map<String, Object?> json) {
    clear();
    for (final typeId in json.keys.toList()..sort()) {
      final perHandle = (json[typeId]! as Map).cast<String, Object?>();
      final handleKeys = perHandle.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      final factory = _factories[typeId];
      for (final key in handleKeys) {
        final handle = Handle.checked(int.parse(key));
        final payload = (perHandle[key]! as Map).cast<String, Object?>();
        if (factory == null) {
          // Unknown to this build: keep it exactly as read, including the
          // typeId, so it can be written back untouched.
          attachUnknown(handle, {'typeId': typeId, ...payload});
          continue;
        }
        _stores[_typeOf[typeId]!]!.set(handle, factory(payload));
      }
    }
  }

  void clear() {
    for (final store in _stores.values) {
      store.clear();
    }
    _unknown.clear();
  }
}
