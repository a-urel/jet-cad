// Spec 2a E4: a component whose registered factory throws is kept raw, as
// an unknown type is, and reported with its handle, when the caller asks
// for that. Otherwise the load fails as it always did. Groups sit off the
// origin at rotations; the spars have non-round sizes.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Refuses a non-positive width with ArgumentError, and reads its fields
/// with casts, so a missing field is a TypeError.
final class Spar implements Component {
  Spar(this.width, this.depth) {
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive');
    }
  }

  static const String id = 'test.spar';

  final double width;
  final double depth;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'width': width, 'depth': depth};

  static Spar fromJson(Map<String, Object?> j) =>
      Spar((j['width']! as num).toDouble(), (j['depth']! as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is Spar && other.width == width && other.depth == depth;

  @override
  int get hashCode => Object.hash(width, depth);
}

void registerSpar(ComponentRegistry registry) =>
    registry.register<Spar>(Spar.id, Spar.fromJson);

const Handle h1 = Handle(4100);
const Handle h2 = Handle(4200);
const Handle h3 = Handle(4300);

/// Three spars as a registry writes them; [replaced] is written in place of
/// the payload of each handle it names.
Map<String, Object?> sparsJson(
        [Map<Handle, Map<String, Object?>> replaced = const {}]) =>
    {
      Spar.id: {
        for (final (h, s) in [
          (h1, Spar(2400.5, 120)),
          (h2, Spar(900.25, 80)),
          (h3, Spar(1750, 95.5)),
        ])
          '${h.value}': replaced[h] ?? s.toJson(),
      },
    };

/// Two spars on two root-level groups, each at its own rotated placement,
/// encoded by the codec, with the second spar's payload replaced by
/// [unreadable]. The text is the codec's own, so a save can be compared
/// byte for byte.
({String text, Handle readable, Handle unreadable}) savedWithUnreadable(
    Map<String, Object?> unreadable) {
  final doc = DraftDocument.empty();
  registerSpar(doc.components);
  final groups = <Handle>[];
  for (final (i, spar) in [Spar(2400.5, 120), Spar(900.25, 80)].indexed) {
    final g = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: g,
        parent: doc.rootHandle,
        transform: Transform2.translation(7010.0 + 2600 * i, 3020.0 - 450 * i)
            .multiply(Transform2.rotation(math.pi / 6 + i)),
        children: const [])));
    doc.commands.execute(SetComponentCommand<Spar>(g, spar));
    groups.add(g);
  }
  final json = DraftDocumentCodec.encode(doc);
  final spars = (json['components']! as Map<String, Object?>)[Spar.id]!
      as Map<String, Object?>;
  spars['${groups[1].value}'] = unreadable;
  return (text: jsonEncode(json), readable: groups[0], unreadable: groups[1]);
}

void main() {
  test(
      'E4-1 with a list, a throwing factory keeps the payload raw and '
      'reports its handle', () {
    final registry = ComponentRegistry()
      ..register<Spar>(Spar.id, Spar.fromJson);
    final diagnostics = <Diagnostic>[];
    final json = sparsJson({
      h2: {'width': -5.0, 'depth': 80.0},
    });
    registry.loadJson(json, diagnostics: diagnostics);

    expect(registry.get<Spar>(h1), Spar(2400.5, 120));
    expect(registry.get<Spar>(h3), Spar(1750, 95.5));
    expect(registry.get<Spar>(h2), isNull);
    // M-E4a: the catch keeps nothing raw.
    expect(registry.unknownOf(h2), [
      {'typeId': Spar.id, 'width': -5.0, 'depth': 80.0},
    ]);
    // M-E4b: nothing reported. M-E4c: no handle. M-E4d: no type id.
    expect(diagnostics, hasLength(1));
    final d = diagnostics.single;
    expect(d.severity, DiagnosticSeverity.error);
    expect(d.code, 'component.unreadable');
    expect(d.handles, [h2]);
    expect(d.message, startsWith('test.spar: '));
    expect(d.message, contains('must be positive'));
    // Written back unchanged, byte for byte.
    expect(jsonEncode(registry.toJson()), jsonEncode(json));
  });

  test('E4-2 an Error thrown by the factory counts too', () {
    final registry = ComponentRegistry()
      ..register<Spar>(Spar.id, Spar.fromJson);
    final diagnostics = <Diagnostic>[];
    // No width: `j['width']!` throws a TypeError, not an Exception.
    // M-E4e: `on Exception catch` lets it end the load.
    registry.loadJson(
        sparsJson({
          h3: {'depth': 95.5},
        }),
        diagnostics: diagnostics);
    expect(registry.get<Spar>(h1), Spar(2400.5, 120));
    expect(registry.unknownOf(h3), [
      {'typeId': Spar.id, 'depth': 95.5},
    ]);
    expect([
      for (final d in diagnostics) d.handles
    ], [
      [h3],
    ]);
  });

  test("E4-3 with no list, the factory's error propagates as before", () {
    final registry = ComponentRegistry()
      ..register<Spar>(Spar.id, Spar.fromJson);
    // M-E4f: the factory is caught whether or not a list was given.
    expect(
        () => registry.loadJson(sparsJson({
              h2: {'width': -5.0, 'depth': 80.0},
            })),
        throwsArgumentError);
  });

  test('E4-4 a value attached to that handle later is the one written', () {
    final registry = ComponentRegistry()
      ..register<Spar>(Spar.id, Spar.fromJson);
    registry.loadJson(
        sparsJson({
          h2: {'width': -5.0, 'depth': 80.0},
        }),
        diagnostics: <Diagnostic>[]);
    registry.attach(h2, Spar(950.5, 80));
    // M-E4g: registered values written first, so the raw payload
    // overwrites the new value.
    expect((registry.toJson()[Spar.id]! as Map<String, Object?>)['4200'],
        {'width': 950.5, 'depth': 80.0});
  });

  test(
      'E4-5 the codec keeps an unreadable component when asked, and a save '
      'writes it back byte for byte', () {
    final saved = savedWithUnreadable({'width': -5.0, 'depth': 80.0});
    final diagnostics = <Diagnostic>[];
    // M-E4h: the codec hands loadJson no list; the decode throws.
    final loaded = DraftDocumentCodec.decodeString(saved.text,
        diagnostics: diagnostics,
        keepUnreadableComponents: true,
        registerComponents: registerSpar);
    expect(loaded.components.get<Spar>(saved.readable), Spar(2400.5, 120));
    expect(loaded.components.get<Spar>(saved.unreadable), isNull);
    expect([for (final d in diagnostics) (d.code, d.severity)],
        [('component.unreadable', DiagnosticSeverity.error)]);
    expect(diagnostics.single.handles, [saved.unreadable]);
    expect(DraftDocumentCodec.encodeToString(loaded), saved.text);

    // With no list, it is kept all the same. M-E4j: the codec hands on the
    // caller's null.
    final quiet = DraftDocumentCodec.decodeString(saved.text,
        keepUnreadableComponents: true, registerComponents: registerSpar);
    expect(DraftDocumentCodec.encodeToString(quiet), saved.text);
  });

  test('E4-6 without the flag, the codec fails on it as before', () {
    final saved = savedWithUnreadable({'width': -5.0, 'depth': 80.0});
    // M-E4i: the codec hands on its list whatever the flag; a symbol
    // library with a bad component would then decode (jet_cad_2d_kit's
    // SymbolLibrary.decode relies on this throw).
    expect(
        () => DraftDocumentCodec.decodeString(saved.text,
            diagnostics: <Diagnostic>[], registerComponents: registerSpar),
        throwsArgumentError);
    expect(
        () => DraftDocumentCodec.decodeString(saved.text,
            registerComponents: registerSpar),
        throwsArgumentError);
  });
}
