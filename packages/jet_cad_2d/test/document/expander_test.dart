import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Wraps a command: its own label, a declared capability set, and an
/// inverse that is also a `_Tagged`, so the test can see what history holds.
class _Tagged extends DraftCommand {
  _Tagged(this.inner, this.needs);
  final DraftCommand inner;
  final Set<Capability> needs;
  static int applies = 0;

  @override
  Capability get capability => Capability.structure;
  @override
  Set<Capability> get capabilities => needs;
  @override
  String get label => 'tagged ${inner.label}';
  @override
  CommandResult apply(CommandTarget target) {
    applies++;
    final r = inner.apply(target);
    return CommandResult(
        inverse: _Tagged(r.inverse, needs), touched: r.touched);
  }
}

AddEntityCommand line(DraftDocument doc) => addDrafted(doc, EntityKind.line,
    linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));

void main() {
  test('X1 execute runs the expanded command and reports it', () async {
    final doc = DraftDocument.empty();
    doc.commands.expander = (c) => _Tagged(c, {Capability.geometry});
    final seen = <DocChange>[];
    final sub = doc.commands.changes.listen(seen.add);
    doc.commands.execute(line(doc));
    await Future<void>.delayed(Duration.zero);
    final applied = seen.single as CommandApplied;
    expect(applied.label, 'tagged Add line');
    expect(applied.capability, Capability.structure);
    await sub.cancel();
  });

  test('X2 undo and redo never call the expander', () {
    final doc = DraftDocument.empty();
    var calls = 0;
    doc.commands.expander = (c) {
      calls++;
      return c;
    };
    doc.commands.execute(line(doc));
    doc.commands.undo();
    doc.commands.redo();
    doc.commands.undo();
    expect(calls, 1);
  });

  test('X3 permissions are checked on the expanded command', () {
    final doc = DraftDocument.empty();
    doc.commands.expander = (c) => _Tagged(c, {Capability.structure});
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: true, structure: false);
    // Built first: the handle is taken when the command is built.
    final add = line(doc);
    final before = DraftDocumentCodec.encodeToString(doc);
    _Tagged.applies = 0;
    expect(
        () => doc.commands.execute(add), throwsA(isA<PermissionDeniedError>()));
    expect(_Tagged.applies, 0);
    expect(doc.commands.undoDepth, 0);
    expect(DraftDocumentCodec.encodeToString(doc), before);
  });

  test('X4 history holds the expanded command\'s inverse', () {
    final doc = DraftDocument.empty();
    doc.commands.expander =
        (c) => c is _Tagged ? c : _Tagged(c, c.capabilities);
    doc.commands.execute(line(doc));
    _Tagged.applies = 0;
    doc.commands.undo();
    expect(_Tagged.applies, 1, reason: 'the inverse is a _Tagged');
  });
}
