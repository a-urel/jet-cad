// The contract's registry function (spec K2): the four contract components
// and nothing else. The wrapped form lets the library decoder (K3) read
// through guarded factories while registering exactly the same types.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'library_component.dart';
import 'manifest_component.dart';
import 'symbol_component.dart';
import 'unit_component.dart';

/// Reads one component of type [T]: [read] is its `fromJson`, [typeId] its
/// type id. Not exported.
typedef ComponentRead = T Function<T extends Component>(String typeId,
    Map<String, Object?> json, T Function(Map<String, Object?> json) read);

/// Registers `jetcad.library`, `jetcad.manifest`, `jetcad.symbol` and
/// `jetcad.unit` on [registry], and nothing else. Once per registry:
/// `register` replaces a type's store.
void registerKitComponents(ComponentRegistry registry) =>
    registerKitComponentsWrapped(registry, _direct);

/// [registerKitComponents] with every factory read through [read]. Not
/// exported.
void registerKitComponentsWrapped(
    ComponentRegistry registry, ComponentRead read) {
  registry
    ..register<LibraryComponent>(
        LibraryComponent.componentTypeId,
        (json) => read(
            LibraryComponent.componentTypeId, json, LibraryComponent.fromJson))
    ..register<ManifestComponent>(
        ManifestComponent.componentTypeId,
        (json) => read(ManifestComponent.componentTypeId, json,
            ManifestComponent.fromJson))
    ..register<SymbolComponent>(
        SymbolComponent.componentTypeId,
        (json) => read(
            SymbolComponent.componentTypeId, json, SymbolComponent.fromJson))
    ..register<UnitComponent>(
        UnitComponent.componentTypeId,
        (json) =>
            read(UnitComponent.componentTypeId, json, UnitComponent.fromJson));
}

T _direct<T extends Component>(String typeId, Map<String, Object?> json,
        T Function(Map<String, Object?> json) read) =>
    read(json);
