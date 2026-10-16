// Spec 3a C1.11 (Task 6): FakePlanServices, a kit author's PlanServices over
// a document: a live index, a camera at a given scale, words from given
// names, settings from a map, one shared object per type disposed with it,
// and liveTypeIdOf over a given catalog and frozen set. The document is the
// contract's fixture: a slab and a post in turned groups off the origin.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/code_fixtures.dart';
import '../support/plan_type_fixtures.dart';

/// A shared object that logs its disposal as [name].
final class _Logged implements Disposable {
  _Logged(this.log, this.name);
  final List<String> log;
  final String name;
  @override
  void dispose() => log.add(name);
}

/// A second shared type, so two types are kept apart.
final class _Faces extends _Logged {
  _Faces(List<String> log) : super(log, 'faces');
}

final class _Bands extends _Logged {
  _Bands(List<String> log) : super(log, 'bands');
}

/// A registry with one kind and no answer.
final class _Registry implements AttachmentRegistry {
  @override
  Set<String> get kinds => const {'wall-face'};
  @override
  Attachment? attach(List<String> kinds, AttachmentQuery query) => null;
}

AttachmentQuery query() => AttachmentQuery(
    footprint: const Aabb2.raw(150, 210, 1750, 960),
    current: Transform2.translation(4120.5, -2310.25)
        .multiply(Transform2.rotation(0.4)),
    pointer: Vector2(4120.5, -2310.25),
    capture: 160,
    edgeCapture: 100,
    mirrored: false,
    mayRotate: true);

void main() {
  test(
      'LS-fake-1 the document, a live index over it, a camera at the scale '
      'given (y up), the object snap given', () {
    final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final s = FakePlanServices(document: doc, scale: 0.25, objectSnap: false);
    addTearDown(s.dispose);
    expect(identical(s.document, doc), isTrue);
    // M-LS-fake-1a: the index made over `DraftDocument.empty()`.
    expect(identical(s.index.document, doc), isTrue);
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(4100.5, -2200.25), Vector2(5300.75, -1650.5)),
        layer: ReservedHandles.layerZero);
    doc.commands.execute(line);
    final found = <int>[];
    s.index.forEachLeafInBand(const Aabb2.raw(4000, -2300, 5400, -1600),
        BandMode.crossing, const QueryFilter.picking(), found.add);
    expect(found, [doc.entities.slotOf(line.record.handle)],
        reason: 'the index follows the document');
    expect(s.camera.value.scale, 0.25);
    // M-LS-fake-1b: the camera's matrix without the y flip
    // (`Transform2(scale, 0, 0, scale, 0, 0)`).
    expect(
        s.camera.value.worldToScreen(Vector2(4000, -2000)), Vector2(1000, 500));
    // M-LS-fake-1c: `objectSnap` always true.
    expect(s.objectSnap, isFalse);
  });

  test(
      'LS-fake-2 the words: the names given, at the locale given, numbers '
      'with the separator given', () {
    final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final s = FakePlanServices(
        document: doc,
        names: const KitNames({
          'en': {'tool:test.slab': 'Slab', 'text:test.count': '{n} slabs'},
          'tr': {'tool:test.slab': 'Tezgâh', 'text:test.count': '{n} tezgâh'},
        }),
        locale: const Locale('tr'),
        decimalSeparator: ',');
    addTearDown(s.dispose);
    // M-LS-fake-2a: the words at `const Locale('en')` whatever is given.
    expect(s.words.locale, const Locale('tr'));
    expect(s.words.word('tool:test.slab'), 'Tezgâh');
    expect(s.words.text('text:test.count', {'n': 3}), '3 tezgâh');
    // M-LS-fake-2b: the separator not passed to the words.
    expect(s.words.decimalSeparator, ',');
  });

  test(
      "LS-fake-3 settingsOf: the map's value for the tool, read at each "
      'call; a tool without one, or settings of another type, is an '
      'ArgumentError', () {
    final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final settings = <String, Object>{'test.slab': 1250.5};
    final s = FakePlanServices(document: doc, settings: settings);
    addTearDown(s.dispose);
    expect(s.settingsOf<double>('test.slab'), 1250.5);
    // R-P12: the map given is read at each call, so a test changes a
    // tool's settings between events. M-LS-fake-3b: the map copied in the
    // constructor (`Map.of(settings)`).
    settings['test.slab'] = 980.25;
    expect(s.settingsOf<double>('test.slab'), 980.25);
    // M-LS-fake-3: `settingsOf` as `_settings[toolId] as S` (a TypeError).
    expect(() => s.settingsOf<String>('test.slab'), throwsArgumentError);
    expect(() => s.settingsOf<double>('test.wall'), throwsArgumentError);
  });

  test(
      'LS-fake-4 shared: one per type, made by the first call over these '
      'services; dispose releases the Disposable ones, last made first, and '
      'serves nothing after', () {
    final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final s = FakePlanServices(document: doc);
    final log = <String>[];
    var made = 0;
    final bands = s.shared<_Bands>((services) {
      made++;
      expect(identical(services, s), isTrue);
      return _Bands(log);
    });
    // M-LS-fake-4a: `shared` not keeping what it made.
    expect(identical(s.shared<_Bands>((_) => _Bands(log)), bands), isTrue);
    expect(made, 1);
    final faces = s.shared<_Faces>((_) => _Faces(log));
    expect(identical(faces, bands), isFalse);
    expect(s.shared<String>((_) => 'plain'), 'plain');
    // A type asked for while it is made.
    expect(
        () => s.shared<Duration>(
            (services) => services.shared<Duration>((_) => Duration.zero)),
        throwsStateError);
    s.dispose();
    // M-LS-fake-4b: dispose in the order made; M-LS-fake-4c: dispose
    // leaving the shared objects alone.
    expect(log, ['faces', 'bands']);
    expect(() => s.shared<_Bands>((_) => _Bands(log)), throwsStateError);
  });

  test(
      'LS-fake-dispose dispose releases the camera and the symbols state '
      '(M-LS-fake-dispose-camera, M-LS-fake-dispose-state)', () {
    final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final s = FakePlanServices(document: doc, scale: 0.25);
    void listener() {}
    // Premises: live before dispose.
    s.camera
      ..addListener(listener)
      ..removeListener(listener);
    s.symbolsState
      ..addListener(listener)
      ..removeListener(listener);
    s.dispose();
    // A disposed ChangeNotifier refuses a listener.
    expect(() => s.camera.addListener(listener), throwsFlutterError,
        reason: 'the camera disposed');
    expect(() => s.symbolsState.addListener(listener), throwsFlutterError,
        reason: 'the symbols state disposed');
  });

  test(
      "LS-fake-5 liveTypeIdOf: the catalog's type id; null for a frozen "
      'object, without a catalog, and for anything else', () {
    final (:doc, :catalog) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final s =
        FakePlanServices(document: doc, catalog: catalog, frozen: {hPost});
    addTearDown(s.dispose);
    expect(s.liveTypeIdOf(hSlab), Slab.id);
    // M-LS-fake-5: the frozen set not consulted.
    expect(s.liveTypeIdOf(hPost), isNull);
    expect(catalog.typeIdOf(doc, hPost), Post.id,
        reason: "premise: the catalog still answers a frozen object's id");
    expect(s.liveTypeIdOf(hBare), isNull);
    expect(s.liveTypeIdOf(doc.rootHandle), isNull);
    final bare = FakePlanServices(document: doc);
    addTearDown(bare.dispose);
    expect(bare.liveTypeIdOf(hSlab), isNull);
  });

  test(
      'LS-fake-6 no symbol library (null, ready); the attachments given, '
      'else a registry with no kind', () {
    final (:doc, catalog: _) = objectDocument([slabType(), postType()]);
    addTearDown(doc.dispose);
    final s = FakePlanServices(document: doc);
    addTearDown(s.dispose);
    expect(s.symbolDefinition('test.table.square.four@1'), isNull);
    expect(s.symbolsState.value, SymbolsState.ready);
    expect(s.attachments.kinds, isEmpty);
    expect(s.attachments.attach(const ['wall-face'], query()), isNull);
    final registry = _Registry();
    final t = FakePlanServices(document: doc, attachments: registry);
    addTearDown(t.dispose);
    // M-LS-fake-6: the registry given ignored.
    expect(identical(t.attachments, registry), isTrue);
  });
}
