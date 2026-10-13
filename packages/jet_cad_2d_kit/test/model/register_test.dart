// Spec K2: registerKitComponents registers the four contract components and
// nothing else; a document carrying them saves and loads typed and
// byte-identical, and without the registration it is preserved verbatim
// (ported from jet_cad_floor_plan's symbol_component_test SC7-SC8).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

SymbolComponent highTop() => SymbolComponent(
      key: 'sample.table.high-top',
      version: 2,
      name: 'High-top table',
      category: 'Bar',
      tags: const ['table', 'bar', 'high'],
      attachTo: const ['wall-face'],
    );

/// A document off the origin carrying all four components: the manifest and
/// the library on the root, the symbol and the unit on a definition.
({DraftDocument doc, Handle def}) withEveryComponent() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  final def = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: 'sample.table.high-top@2',
        basePoint: Vector2(1250, 860),
        children: const [])),
    SetComponentCommand<SymbolComponent>(def, highTop()),
    SetComponentCommand<UnitComponent>(
        def, UnitComponent(kind: UnitKinds.table, capacity: 4)),
    SetComponentCommand<ManifestComponent>(
        doc.rootHandle,
        ManifestComponent(
            kits: const {'sample': '0.3.1', 'architecture': '0.1.0'})),
    SetComponentCommand<LibraryComponent>(
        doc.rootHandle, LibraryComponent(kit: 'sample')),
    AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
      ),
      payload: linePayload(Vector2(950, 560), Vector2(1550, 1160)),
    ),
  ], label: 'Every kit component'));
  doc.commands.clearHistory();
  return (doc: doc, def: def);
}

void main() {
  test('R1 the four components, and nothing else', () {
    final registry = ComponentRegistry();
    registerKitComponents(registry);
    expect(registry.isRegistered<SymbolComponent>(), isTrue);
    expect(registry.isRegistered<UnitComponent>(), isTrue);
    expect(registry.isRegistered<LibraryComponent>(), isTrue);
    expect(registry.isRegistered<ManifestComponent>(), isTrue);
    // M-R1: call registry.registerBuiltIns() inside registerKitComponents.
    expect(registry.isRegistered<OriginComponent>(), isFalse);
    expect(registry.isRegistered<PageComponent>(), isFalse);
  });

  test('R2 saved and loaded typed, re-encoded byte-identically', () {
    final r = withEveryComponent();
    addTearDown(r.doc.dispose);
    final saved = DraftDocumentCodec.encodeToString(r.doc);
    final loaded = DraftDocumentCodec.decodeString(saved,
        registerComponents: registerKitComponents);
    addTearDown(loaded.dispose);
    expect(loaded.components.get<SymbolComponent>(r.def), highTop());
    expect(loaded.components.get<UnitComponent>(r.def),
        UnitComponent(kind: UnitKinds.table, capacity: 4));
    expect(loaded.components.get<LibraryComponent>(loaded.rootHandle),
        LibraryComponent(kit: 'sample'));
    expect(
        loaded.components.get<ManifestComponent>(loaded.rootHandle),
        ManifestComponent(
            kits: const {'architecture': '0.1.0', 'sample': '0.3.1'}));
    expect(DraftDocumentCodec.encodeToString(loaded), saved);
  });

  test('R3 without the registration every component is kept verbatim', () {
    final r = withEveryComponent();
    addTearDown(r.doc.dispose);
    final saved = DraftDocumentCodec.encodeToString(r.doc);
    final bare = DraftDocumentCodec.decodeString(saved);
    addTearDown(bare.dispose);
    expect(bare.components.get<SymbolComponent>(r.def), isNull);
    expect(bare.components.unknownOf(r.def), hasLength(2));
    expect(bare.components.unknownOf(bare.rootHandle), hasLength(2));
    expect(DraftDocumentCodec.encodeToString(bare), saved);
  });

  test('R4 the components as the file holds them', () {
    final r = withEveryComponent();
    addTearDown(r.doc.dispose);
    final saved = DraftDocumentCodec.encodeToString(r.doc);
    final root = r.doc.rootHandle.value;
    expect(
        saved,
        contains('"jetcad.unit":{"${r.def.value}":'
            '{"capacity":4,"kind":"table","labelling":"numbered"}}'));
    expect(
        saved,
        contains('"jetcad.manifest":{"$root":{"format":1,'
            '"kits":{"architecture":"0.1.0","sample":"0.3.1"}}}'));
    expect(saved,
        contains('"jetcad.library":{"$root":{"format":1,"kit":"sample"}}'));
  });
}
