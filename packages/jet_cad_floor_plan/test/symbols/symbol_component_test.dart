// Spec 09 D3, D1, F-5 (plan 09a Task 2): the symbol component, its value
// semantics, its bytes, its registration, and what it does and does not meet
// (the parametric system, `purge`).
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_floor_plan/src/new_document.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/parametric/live_objects.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_component.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Three tags, deliberately not sorted, and a version other than 1.
SymbolComponent sofa({
  String key = 'sofa.three',
  String name = 'Three-seat sofa',
  String category = 'Living Room',
  List<String> tags = const ['sofa', 'seating', 'couch'],
  int version = 3,
}) =>
    SymbolComponent(
        key: key, name: name, category: category, tags: tags, version: version);

/// A definition at a far handle with a base point off the origin, two leaves
/// off the origin, and [component] on the definition. The history is cleared.
({DraftDocument doc, Handle def, Handle leafA, Handle leafB}) withSymbol(
    TextMeasurer measurer,
    {SymbolComponent? component}) {
  final doc = prepareDocument(measurer);
  final def = Handle(4200);
  final leafA = Handle(4300), leafB = Handle(4310);
  EntityRecord record(Handle h, EntityKind kind) => EntityRecord(
        handle: h,
        owner: def,
        kind: kind,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
      );
  doc.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: 'sofa.three@3',
        basePoint: Vector2(900, 400),
        children: const [])),
    SetComponentCommand<SymbolComponent>(def, component ?? sofa()),
    AddEntityCommand(
        record: record(leafA, EntityKind.line),
        payload: GeometryPayload(
            coords: Float64List.fromList([120, 340, 1680, 340]),
            scalars: Float64List(0))),
    AddEntityCommand(
        record: record(leafB, EntityKind.line),
        payload: GeometryPayload(
            coords: Float64List.fromList([120, 340, 120, 900]),
            scalars: Float64List(0))),
  ], label: 'Fixture'));
  doc.commands.clearHistory();
  return (doc: doc, def: def, leafA: leafA, leafB: leafB);
}

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  group('value semantics', () {
    test('SC1 equality sees every field, each differing once', () {
      expect(sofa(), sofa());
      expect(sofa().hashCode, sofa().hashCode);
      expect(sofa(), isNot(sofa(key: 'sofa.four')));
      expect(sofa(), isNot(sofa(name: 'Four-seat sofa')));
      expect(sofa(), isNot(sofa(category: 'Office')));
      expect(sofa(), isNot(sofa(tags: const ['sofa', 'seating'])));
      expect(sofa(), isNot(sofa(tags: const ['sofa', 'seating', 'chair'])));
      expect(sofa(), isNot(sofa(version: 4)));
    });

    test('SC2 tag order matters to equality', () {
      final a = sofa(tags: const ['sofa', 'seating', 'couch']);
      final b = sofa(tags: const ['couch', 'sofa', 'seating']);
      expect(a, isNot(b));
      expect(a.toJson(), isNot(b.toJson()));
    });

    test('SC3 tags is an unmodifiable copy', () {
      final source = ['sofa', 'seating', 'couch'];
      final s = sofa(tags: source);
      source[0] = 'mutated';
      expect(s.tags, ['sofa', 'seating', 'couch']);
      expect(() => s.tags.add('x'), throwsUnsupportedError);
    });

    test('SC4 an empty key or a version below 1 is an ArgumentError', () {
      expect(() => sofa(key: ''), throwsArgumentError);
      expect(() => sofa(version: 0), throwsArgumentError);
      expect(() => sofa(version: -2), throwsArgumentError);
      expect(sofa(version: 1).version, 1);
    });

    test('SC5 toJson round-trips and its key order is pinned', () {
      final s = sofa();
      expect(s.toJson().keys.toList(),
          ['category', 'key', 'name', 'tags', 'version']);
      expect(
          jsonEncode(s.toJson()),
          '{"category":"Living Room","key":"sofa.three",'
          '"name":"Three-seat sofa","tags":["sofa","seating","couch"],'
          '"version":3}');
      final back = SymbolComponent.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back, s);
      expect(back.tags, ['sofa', 'seating', 'couch']);
    });

    // One expectation per omitted field: a fromJson that tolerates one
    // missing field (a default in its place) must go red on that field alone.
    const full = <String, Object?>{
      'key': 'sofa.three',
      'name': 'Three-seat sofa',
      'category': 'Living Room',
      'tags': ['sofa', 'seating', 'couch'],
      'version': 3,
    };
    test('SC6 the full map reads back (the control for the omissions)', () {
      expect(SymbolComponent.fromJson(full), sofa());
    });
    for (final field in full.keys) {
      test('SC6 fromJson refuses a map without "$field"', () {
        final json = {...full}..remove(field);
        expect(
            () => SymbolComponent.fromJson(json),
            throwsA(isA<FormatException>()
                .having((e) => e.message, 'message', contains('"$field"'))));
      });
    }
  });

  group('on a definition handle, through the codec', () {
    test('SC7 saves and loads typed, and re-encodes byte-identically', () {
      final r = withSymbol(measurer);
      final saved = DraftDocumentCodec.encodeToString(r.doc);
      final loaded = DraftDocumentCodec.decodeString(saved,
          measurer: measurer, registerComponents: registerAppComponents);
      addTearDown(loaded.dispose);
      expect(loaded.components.get<SymbolComponent>(r.def), sofa());
      expect(loaded.components.get<SymbolComponent>(r.def)!.tags,
          ['sofa', 'seating', 'couch']);
      expect(loaded.tree.definition(r.def)!.basePoint, Vector2(900, 400));
      expect(DraftDocumentCodec.encodeToString(loaded), saved);
    });

    test(
        'SC8 loaded without the registration it is preserved verbatim and '
        're-encodes identically', () {
      final r = withSymbol(measurer);
      final saved = DraftDocumentCodec.encodeToString(r.doc);
      final bare = DraftDocumentCodec.decodeString(saved, measurer: measurer);
      addTearDown(bare.dispose);
      expect(bare.components.get<SymbolComponent>(r.def), isNull);
      expect(bare.components.unknownOf(r.def), hasLength(1));
      expect(DraftDocumentCodec.encodeToString(bare), saved);
    });

    test('SC9 registerAppComponents registers it alongside the page', () {
      final doc = prepareDocument(measurer);
      addTearDown(doc.dispose);
      doc.components.attach(doc.rootHandle, sofa());
      expect(doc.components.get<SymbolComponent>(doc.rootHandle), sofa());
      expect(doc.components.isRegistered<PageComponent>(), isTrue);
    });
  });

  group('not a parametric type (spec D1)', () {
    test(
        'SC10 a document holding it reports no diagnostics, regeneration '
        'leaves it untouched, and the live-object rule never names it', () {
      final r = withSymbol(measurer);
      final system = installParametric(r.doc);
      addTearDown(system.dispose);

      expect(r.doc.validate(), isEmpty);
      expect(system.diagnostics(), isEmpty);
      expect(system.drift(), isEmpty);
      expect(liveObjectsOf<SymbolComponent>(r.doc), isEmpty);
      expect(isLiveObject<SymbolComponent>(r.doc, r.def), isFalse);
      expect(isLiveObject<SymbolComponent>(r.doc, r.leafA), isFalse);

      // An edit runs the expander (regeneration) with a symbol present.
      final before = DraftDocumentCodec.encodeToString(r.doc);
      r.doc.commands.execute(AddEntityCommand(
          record: EntityRecord(
            handle: r.doc.handleSeed.next(),
            owner: r.doc.rootHandle,
            kind: EntityKind.line,
            layer: ReservedHandles.layerZero,
            linetype: ReservedHandles.byLayerLinetype,
            linetypeScale: 1.0,
            geomIndex: 0,
            color: const ByLayerColor(),
            lineweight: kByLayer,
            transparency: kByLayer,
            flags: 0,
          ),
          payload: GeometryPayload(
              coords: Float64List.fromList([5000, 6000, 7000, 6500]),
              scalars: Float64List(0))));
      expect(r.doc.components.get<SymbolComponent>(r.def), sofa());
      expect(system.drift(), isEmpty);
      expect(system.diagnostics(), isEmpty);
      expect(r.doc.validate(), isEmpty);
      expect(DraftDocumentCodec.encodeToString(r.doc), isNot(before));
      expect(r.doc.components.withComponent<SymbolComponent>(), [r.def]);
    });
  });

  group('purge (spec F-5, plan P-6 item 1)', () {
    test(
        'SC11 purge compacts entity and geometry slots and leaves a '
        "definition's component, leaves and bytes alone", () {
      final r = withSymbol(measurer);
      // A hole below a live slot, so purge has real work: the first leaf goes,
      // the second must move down.
      r.doc.commands.execute(RemoveEntityCommand(r.leafA));
      final before = DraftDocumentCodec.encodeToString(r.doc);
      final slotsBefore = r.doc.entities.liveSlots.toList();
      expect(slotsBefore, [1], reason: 'premise: a hole at slot 0');

      r.doc.purge();

      // The purge ran: the surviving leaf was renumbered.
      expect(r.doc.entities.liveSlots.toList(), [0]);
      // The component is still on the definition's handle, equal in value.
      expect(r.doc.components.get<SymbolComponent>(r.def), sofa());
      expect(r.doc.components.withComponent<SymbolComponent>(), [r.def]);
      expect(r.doc.tree.definition(r.def)!.name, 'sofa.three@3');
      expect(r.doc.validate(), isEmpty);
      // What a save writes is unchanged, and loads typed.
      final after = DraftDocumentCodec.encodeToString(r.doc);
      expect(after, before);
      final loaded = DraftDocumentCodec.decodeString(after,
          measurer: measurer, registerComponents: registerAppComponents);
      addTearDown(loaded.dispose);
      expect(loaded.components.get<SymbolComponent>(r.def), sofa());
    });

    test(
        'SC12 a removed definition takes its component with it (spec 09c '
        'D11): undo brings it back byte for byte, and purge finds no '
        'orphan', () {
      final r = withSymbol(measurer);
      final before = DraftDocumentCodec.encodeToString(r.doc);
      r.doc.commands.execute(CompoundCommand([
        RemoveEntityCommand(r.leafA),
        RemoveEntityCommand(r.leafB),
        RemoveDefinitionCommand(r.def),
      ], label: 'Remove symbol'));
      // No component stays on a handle that names nothing.
      expect(r.doc.tree.definition(r.def), isNull);
      expect(r.doc.components.get<SymbolComponent>(r.def), isNull);
      expect(r.doc.components.withComponent<SymbolComponent>(), isEmpty);
      expect(r.doc.components.toJson(),
          isNot(contains(SymbolComponent.componentTypeId)));

      r.doc.commands.undo();
      expect(DraftDocumentCodec.encodeToString(r.doc), before);
      expect(r.doc.components.get<SymbolComponent>(r.def), sofa());

      r.doc.commands.redo();
      expect(r.doc.components.get<SymbolComponent>(r.def), isNull);
      r.doc.purge();
      expect(r.doc.components.withComponent<SymbolComponent>(), isEmpty);
      expect(r.doc.validate(), isEmpty);
    });
  });
}
