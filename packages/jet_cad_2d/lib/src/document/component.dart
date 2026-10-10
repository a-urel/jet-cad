import 'package:meta/meta.dart';

import '../core/handle.dart';
import 'object_layer.dart';
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

/// Every component one handle carries, taken by [ComponentRegistry.snapshotOf]
/// and put back by [ComponentRegistry.restore] (spec 09c D11).
///
/// Immutable: both lists are unmodifiable copies taken when the snapshot is,
/// so a later attach, detach or `attachUnknown` on the registry does not
/// change it. The components are the registry's own values (immutable by the
/// [Component] contract); the unknown payloads are the same references
/// [ComponentRegistry.unknownOf] hands out, under the same rule: never
/// mutated in place.
@immutable
class ComponentSnapshot {
  /// The registered components, as `(typeId, value)` pairs ascending by type
  /// id.
  final List<(String, Component)> components;

  /// The unknown-component payloads, in the registry's own order (oldest
  /// first, as [ComponentRegistry.unknownOf] lists them), each still carrying
  /// its `typeId`. Not re-sorted by type id: [ComponentRegistry.restore]
  /// appends them in this order, so `unknownOf` reads back exactly as it did.
  final List<Map<String, Object?>> unknown;

  ComponentSnapshot._(
      List<(String, Component)> components, List<Map<String, Object?>> unknown)
      : components = List.unmodifiable(components),
        unknown = List.unmodifiable(unknown);

  /// A snapshot of a handle that carries nothing.
  static final ComponentSnapshot empty =
      ComponentSnapshot._(const [], const []);

  /// True when the handle carried no component, registered or unknown.
  bool get isEmpty => components.isEmpty && unknown.isEmpty;

  bool get isNotEmpty => !isEmpty;
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

  /// Whether `T` already has a store. `register` replaces the store
  /// unconditionally, wiping every component of `T` in the process, so a
  /// caller that must not clobber an already-loaded document — a second
  /// `ParametricSystem` over the same document, for instance (Ruling
  /// 06-13) — checks this first.
  bool isRegistered<T extends Component>() => _stores.containsKey(T);

  /// Registers the component types the engine owns.
  void registerBuiltIns() {
    register<OriginComponent>(
      OriginComponent.componentTypeId,
      OriginComponent.fromJson,
      internal: true,
    );
    // Not internal (spec 12b S-16): an object's layer is document content.
    register<ObjectLayer>(ObjectLayer.componentTypeId, ObjectLayer.fromJson);
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

  /// Every component on [handle]: each registered one (ascending by type id)
  /// and each unknown payload (oldest first), as an immutable value (spec
  /// 09c D11). Reads only.
  ComponentSnapshot snapshotOf(Handle handle) {
    final registered = <(String, Component)>[];
    for (final entry in _stores.entries) {
      final component = entry.value[handle];
      if (component != null) {
        registered.add((_typeIdOf[entry.key]!, component));
      }
    }
    final unknown = _unknown[handle] ?? const <Map<String, Object?>>[];
    if (registered.isEmpty && unknown.isEmpty) return ComponentSnapshot.empty;
    registered.sort((a, b) => a.$1.compareTo(b.$1));
    return ComponentSnapshot._(registered, unknown);
  }

  /// Detaches every component on [handle], registered and unknown. Other
  /// handles are untouched.
  void detachAll(Handle handle) {
    for (final store in _stores.values) {
      store.remove(handle);
    }
    _unknown.remove(handle);
  }

  /// Throws [StateError] when a registered type id of [snapshot] maps to
  /// no store in this registry, and writes nothing: the check [restore]
  /// makes before its first write, for a caller that must make it before
  /// any other mutation (`AddNodeCommand`, spec D-1). Only a snapshot from
  /// another document can fail it.
  void checkRestorable(Handle handle, ComponentSnapshot snapshot) {
    for (final (typeId, _) in snapshot.components) {
      if (_stores[_typeOf[typeId]] == null) {
        throw StateError('cannot restore $typeId on ${handle.toHex()}: '
            'the type is not registered');
      }
    }
  }

  /// Re-attaches each component of [snapshot] to [handle], exactly: each
  /// registered value into its type's store (replacing one of that type
  /// already there, as [attach] does), each unknown payload appended in the
  /// snapshot's order (as [attachUnknown] does). Meant for a handle that
  /// carries nothing, which is how `RemoveDefinitionCommand`'s and
  /// `RemoveNodeCommand`'s inverses use it: on a handle that already
  /// carries unknown payloads, the snapshot's are appended after them, and
  /// the encoding keeps only the last payload per type id and handle.
  /// Nothing outside the snapshot is added, so a type registered after the
  /// snapshot was taken gets no component.
  ///
  /// All-or-nothing: [checkRestorable] runs first, before anything is
  /// written.
  void restore(Handle handle, ComponentSnapshot snapshot) {
    checkRestorable(handle, snapshot);
    for (final (typeId, component) in snapshot.components) {
      _stores[_typeOf[typeId]]!.set(handle, component);
    }
    for (final payload in snapshot.unknown) {
      attachUnknown(handle, payload);
    }
  }

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
