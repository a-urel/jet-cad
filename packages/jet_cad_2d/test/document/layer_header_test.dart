import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Spec 12b D3 (the current layer, schema 7) and D4 (names).
///
/// Fixture (plan P-6): layers A (ACI 1), B (ACI 5, locked) and C (ACI 3,
/// hidden) beside a visible layer 0, handles drawn from the document's seed.
/// No colour is ACI 7; the hidden layer is not layer 0.
class _Fixture {
  final DraftDocument doc = DraftDocument.empty();
  late final Handle a = _add('A', 1);
  late final Handle b = _add('B', 5, locked: true);
  late final Handle c = _add('C', 3, visible: false);

  _Fixture() {
    // Force the late fields in a fixed order, so the handles are stable.
    a;
    b;
    c;
  }

  Handle _add(String name, int aci,
      {bool visible = true, bool locked = false}) {
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    final handle = doc.handleSeed.next();
    doc.tables.layers.add(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    ));
    return handle;
  }

  /// A direct table write (no command): replace [handle]'s record.
  void replace(Handle handle, LayerRecord Function(LayerRecord) edit) {
    final old = doc.tables.layers[handle]!;
    doc.tables.layers
      ..remove(handle)
      ..add(edit(old));
  }
}

Map<String, Object?> _json(String source) =>
    (jsonDecode(source) as Map).cast<String, Object?>();

Map<String, Object?> _headerOf(Map<String, Object?> json) =>
    (json['header']! as Map).cast<String, Object?>();

void main() {
  group('DocumentHeader.currentLayer', () {
    test('defaults to layer 0 on a new document', () {
      expect(
          DraftDocument.empty().header.currentLayer, ReservedHandles.layerZero);
      expect(DocumentHeader().currentLayer, ReservedHandles.layerZero);
    });

    test(
        'a non-zero current layer round-trips: save, load and save is '
        'byte-identical', () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.a;
      final first = DraftDocumentCodec.encodeToString(f.doc);
      expect(_headerOf(_json(first))['currentLayer'], f.a.value,
          reason: 'the file carries the stored handle');
      final loaded = DraftDocumentCodec.decodeString(first);
      expect(loaded.header.currentLayer, f.a);
      expect(DraftDocumentCodec.encodeToString(loaded), first);
    });

    test('the key follows globalLinetypeScale in the header', () {
      final keys = _headerOf(DraftDocumentCodec.encode(_Fixture().doc)).keys;
      final list = keys.toList();
      expect(list.indexOf('currentLayer'),
          list.indexOf('globalLinetypeScale') + 1);
    });

    test('a v6 document (no currentLayer key) loads with layer 0 current', () {
      final f = _Fixture();
      // Written with A current, so the default is what the load supplies,
      // not what the source happened to hold.
      f.doc.header.currentLayer = f.a;
      final json = DraftDocumentCodec.encode(f.doc);
      _headerOf(json).remove('currentLayer');
      json['schemaVersion'] = 6;
      final loaded = DraftDocumentCodec.decode(
          _json(jsonEncode(json))); // through bytes, as a file would be
      expect(loaded.header.currentLayer, ReservedHandles.layerZero);
      expect(loaded.tables.layers[f.a]!.name, 'A');
    });

    test('this build writes schema 9, reads 7, and refuses the next one', () {
      // Plan Q0 Task 1: writes 8 since the page gained decimalSeparator; the
      // literal-7 read below stays a v7 read.
      // Slice 2 Task 1: writes 9 (E-9); the literal-7 read is unchanged.
      expect(kSchemaVersion, 9);
      // B: a current layer that is neither layer 0 nor the first added.
      final f = _Fixture();
      f.doc.header.currentLayer = f.b;
      final json = DraftDocumentCodec.encode(f.doc);
      expect(json['schemaVersion'], 9);
      // A literal 7 file loads: a build that still writes 6 would refuse it.
      final v7 = _json(jsonEncode(json))..['schemaVersion'] = 7;
      expect(DraftDocumentCodec.decode(v7).header.currentLayer, f.b);
      final future = _json(jsonEncode(json))
        ..['schemaVersion'] = kSchemaVersion + 1;
      expect(() => DraftDocumentCodec.decode(future),
          throwsA(isA<SchemaVersionError>()));
    });

    test(
        'a dangling stored current layer round-trips exactly and draws on '
        'layer 0', () {
      final f = _Fixture();
      // Above every handle the document has issued: names no layer.
      final dangling = Handle(f.doc.handleSeed.current.value + 40);
      f.doc.header.currentLayer = dangling;
      expect(f.doc.tables.layers.contains(dangling), isFalse,
          reason: 'premise');
      expect(drawingLayer(f.doc), ReservedHandles.layerZero);

      final first = DraftDocumentCodec.encodeToString(f.doc);
      final loaded = DraftDocumentCodec.decodeString(first);
      expect(loaded.header.currentLayer, dangling,
          reason: 'a stored value is kept, not repaired');
      expect(drawingLayer(loaded), ReservedHandles.layerZero);
      expect(DraftDocumentCodec.encodeToString(loaded), first);
    });

    test(
        'a hidden stored current layer round-trips exactly, draws on layer 0, '
        'and becomes current again when shown (S-5)', () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.c;
      expect(drawingLayer(f.doc), ReservedHandles.layerZero);

      final first = DraftDocumentCodec.encodeToString(f.doc);
      final loaded = DraftDocumentCodec.decodeString(first);
      expect(loaded.header.currentLayer, f.c);
      expect(drawingLayer(loaded), ReservedHandles.layerZero);
      expect(DraftDocumentCodec.encodeToString(loaded), first);

      // Show C by a direct table write: the stored value never changed, so
      // drawingLayer follows it back.
      f.replace(f.c, (r) => r.copyWith(visible: true));
      expect(drawingLayer(f.doc), f.c);
      expect(f.doc.header.currentLayer, f.c);
    });

    test('drawingLayer is the stored layer when it is visible, locked or not',
        () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.a;
      expect(drawingLayer(f.doc), f.a);
      // Decision 7: the current layer may be locked; it is drawn on.
      f.doc.header.currentLayer = f.b;
      expect(drawingLayer(f.doc), f.b);
    });

    test('drawingLayer falls back to layer 0 when the stored layer is removed',
        () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.a;
      f.doc.tables.layers.remove(f.a);
      expect(drawingLayer(f.doc), ReservedHandles.layerZero);
      expect(f.doc.header.currentLayer, f.a);
    });
  });

  group('LayerRecord.copyWith', () {
    test('replaces exactly the named field and keeps every other', () {
      const base = LayerRecord(
        handle: Handle(300),
        name: 'Walls',
        color: IndexedColor(1),
        linetype: Handle(71),
        lineweight: 35,
        transparency: 12,
        visible: true,
        locked: false,
      );
      expect(base.copyWith(), base);
      final edits = <String, LayerRecord>{
        'handle': base.copyWith(handle: const Handle(301)),
        'name': base.copyWith(name: 'Doors'),
        'color': base.copyWith(color: const IndexedColor(5)),
        'linetype': base.copyWith(linetype: const Handle(72)),
        'lineweight': base.copyWith(lineweight: 50),
        'transparency': base.copyWith(transparency: 40),
        'visible': base.copyWith(visible: false),
        'locked': base.copyWith(locked: true),
      };
      Map<String, Object?> diff(LayerRecord r) {
        final x = r.toJson(), y = base.toJson();
        return {
          for (final k in x.keys)
            if (x[k] != y[k]) k: x[k]
        };
      }

      expect({
        for (final e in edits.entries) e.key: diff(e.value)
      }, {
        'handle': {'handle': 301},
        'name': {'name': 'Doors'},
        'color': {'color': encodeColor(const IndexedColor(5))},
        'linetype': {'linetype': 72},
        'lineweight': {'lineweight': 50},
        'transparency': {'transparency': 40},
        'visible': {'visible': false},
        'locked': {'locked': true},
      });
    });
  });

  test('layerNameProblem names each reason as a value (spec 14d L6)', () {
    final f = _Fixture();
    final doc = f.doc;
    expect(layerNameProblem(doc, ''), isA<LayerNameEmpty>());
    expect(layerNameProblem(doc, ' Walls'), isA<LayerNameEdgeSpace>());
    expect((layerNameProblem(doc, 'w' * 256)! as LayerNameTooLong).max, 255);
    expect(
        (layerNameProblem(doc, 'Wa;lls')! as LayerNameBadCharacter).character,
        ';');
    final dup = layerNameProblem(doc, 'A')! as LayerNameDuplicate;
    expect(dup.existing, doc.tables.layers[f.a]!.name);
    expect(layerNameProblem(doc, 'Walls'), isNull);
    expect(layerNameError(doc, ''), 'A layer name cannot be empty.');
    expect(layerNameError(doc, 'Wa;lls'), 'A layer name cannot contain ;.');
  });

  group('layerNameError (D4)', () {
    test('accepts a fresh, well-formed name', () {
      final f = _Fixture();
      expect(layerNameError(f.doc, 'Walls'), isNull);
      expect(layerNameError(f.doc, 'Layer 1'), isNull,
          reason: 'an inner space is fine');
      expect(layerNameError(f.doc, 'Ä-plan_2.b'), isNull);
    });

    test('refuses the empty name', () {
      expect(layerNameError(_Fixture().doc, ''), isNotNull);
    });

    test('refuses an untrimmed name, either end', () {
      final doc = _Fixture().doc;
      expect(layerNameError(doc, ' Walls'), isNotNull);
      expect(layerNameError(doc, 'Walls '), isNotNull);
      expect(layerNameError(doc, 'Walls\t'), isNotNull);
    });

    test('allows 255 UTF-16 units and refuses 256', () {
      final doc = _Fixture().doc;
      expect(layerNameError(doc, 'w' * 255), isNull);
      expect(layerNameError(doc, 'w' * 256), isNotNull);
      // Counted in UTF-16 units: 128 surrogate pairs are 256 units.
      final pairs = '\u{1F600}' * 128;
      expect(pairs.length, 256, reason: 'premise');
      expect(layerNameError(doc, pairs), isNotNull);
    });

    test('refuses every DXF-forbidden character, alone and inside a name', () {
      final doc = _Fixture().doc;
      const forbidden = [
        '<',
        '>',
        '/',
        '\\',
        '"',
        ':',
        ';',
        '?',
        '*',
        '|',
        '=',
        '`'
      ];
      for (final c in forbidden) {
        expect(layerNameError(doc, 'Wa${c}lls'), isNotNull, reason: c);
        expect(layerNameError(doc, c), isNotNull, reason: c);
      }
    });

    test('refuses another layer\'s name under toLowerCase()', () {
      final f = _Fixture();
      expect(layerNameError(f.doc, 'A'), isNotNull);
      expect(layerNameError(f.doc, 'a'), isNotNull);
      expect(layerNameError(f.doc, 'c'), isNotNull,
          reason: 'a hidden layer still owns its name');
      expect(layerNameError(f.doc, '0'), isNotNull);
      // Renaming B to A's folded name is a duplicate even with self given.
      expect(layerNameError(f.doc, 'a', self: f.b), isNotNull);
    });

    test('excludes self: a case-only rename, or no change, is valid', () {
      final f = _Fixture();
      expect(layerNameError(f.doc, 'a', self: f.a), isNull);
      expect(layerNameError(f.doc, 'A', self: f.a), isNull);
      // And the name is then accepted by the table itself.
      f.replace(f.a, (r) => r.copyWith(name: 'a'));
      expect(f.doc.tables.layers[f.a]!.name, 'a');
    });
  });
}
