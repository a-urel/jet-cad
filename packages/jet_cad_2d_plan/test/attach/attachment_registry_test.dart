// Spec P3 "Attachment" (Task 14): the registry asks the providers of every
// kind the symbol attaches to; the marker nearest the pointer wins; a
// keep goes back to the provider that made it; a throwing provider is no
// attachment and one diagnostic. Fixtures off the origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/attach/attachment_registry.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';

final Vector2 p = Vector2(41250.5, -17320.25);

final class _NoServices implements PlanServices {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('a provider factory read the services');
}

final class Rig {
  final List<KitDiagnostic> reported = [];
  late final PlanAttachmentRegistry registry =
      PlanAttachmentRegistry(report: reported.add);
  final PlanServices services = _NoServices();

  void add(String kit, AttachmentProvider provider) =>
      registry.add(kit, (_) => provider, services);
}

Attachment at(double dx, double dy, Object token) => attachment(
    Transform2.translation(p.x + dx, p.y + dy), p + Vector2(dx, dy), token);

void main() {
  test('AT-1 kinds: every provider\'s kind, once', () {
    final r = Rig()
      ..add('alpha', RecordingProvider('wall-face', (_) => null))
      ..add('beta', RecordingProvider('wall-face', (_) => null))
      ..add('beta', RecordingProvider('room-corner', (_) => null));
    expect(r.registry.kinds, {'wall-face', 'room-corner'});
    expect(() => r.registry.kinds.add('x'), throwsUnsupportedError);
  });

  test(
      'AT-2 the marker nearest the pointer wins across kinds and providers; '
      'a tie goes to the earlier', () {
    final r = Rig();
    final far = RecordingProvider('wall-face', (_) => at(300, 0, 'far'));
    final near = RecordingProvider('room-corner', (_) => at(0, -120, 'near'));
    final same = RecordingProvider('room-corner', (_) => at(120, 0, 'tie'));
    r
      ..add('alpha', far)
      ..add('beta', near)
      ..add('beta', same);
    // M-AT2a: the first non-null answer wins.
    expect(r.registry.attach(['wall-face', 'room-corner'], queryAt(p))!.token,
        'near');
    expect(far.queries, hasLength(1));
    expect(same.queries, hasLength(1));
    // 'near' (0, -120) and 'tie' (120, 0) are equally far: the earlier
    // provider wins. M-AT2b: `<` written `<=` (the later wins).
    expect(r.registry.attach(['room-corner', 'wall-face'], queryAt(p))!.token,
        'near');
  });

  test('AT-3 only the asked kinds\' providers are asked; none is null', () {
    final r = Rig();
    final wall = RecordingProvider('wall-face', (_) => at(10, 0, 'w'));
    final corner = RecordingProvider('room-corner', (_) => at(5, 0, 'c'));
    r
      ..add('alpha', wall)
      ..add('alpha', corner);
    // M-AT3: every provider asked whatever the kinds.
    expect(r.registry.attach(['wall-face'], queryAt(p))!.token, 'w');
    expect(corner.queries, isEmpty);
    expect(r.registry.attach(['ceiling'], queryAt(p)), isNull);
    expect(r.registry.attach(const [], queryAt(p)), isNull);
  });

  test(
      'AT-4 a keep goes only to the provider that made it; the others are '
      'asked without one', () {
    final r = Rig();
    final a = RecordingProvider('wall-face', (_) => at(10, 0, 'a'));
    final b = RecordingProvider('wall-face', (_) => at(400, 0, 'b'));
    r
      ..add('alpha', a)
      ..add('beta', b);
    final first = r.registry.attach(['wall-face'], queryAt(p))!;
    expect(first.token, 'a');
    r.registry.attach(['wall-face'], queryAt(p, keep: first));
    // M-AT4: the query passed on unchanged.
    expect(a.queries.last.keep, same(first));
    expect(b.queries.last.keep, isNull);
    // Every other field reaches the provider asked without the keep.
    final q = b.queries.last;
    expect(q.pointer, p);
    expect(q.capture, 160);
    expect(q.edgeCapture, 100);
    expect(q.footprint.maxX, 1750);
    // A keep no provider of this registry made reaches none.
    final foreign = at(1, 1, 'foreign');
    r.registry.attach(['wall-face'], queryAt(p, keep: foreign));
    expect(a.queries.last.keep, isNull);
    expect(b.queries.last.keep, isNull);
  });

  test(
      'AT-5 a throwing provider is no attachment and a hookFailed; the '
      'others still answer', () {
    final r = Rig();
    final broken = ThrowingProvider('wall-face');
    r
      ..add('alpha', broken)
      ..add('beta', RecordingProvider('wall-face', (_) => at(50, 0, 'ok')));
    // M-AT5: `_ask` calling the provider bare (the error escapes).
    expect(r.registry.attach(['wall-face'], queryAt(p))!.token, 'ok');
    expect(broken.calls, 1);
    expect([for (final d in r.reported) (d.kitId, d.subject, d.code)],
        [('alpha', 'wall-face', KitDiagnosticCode.hookFailed)]);
    expect(r.reported.single.error, isA<StateError>());
  });

  test('AT-6 dispose disposes the Disposable providers and empties it', () {
    final r = Rig();
    final d = DisposableProvider('wall-face', (_) => null);
    r
      ..add('alpha', d)
      ..add('alpha', RecordingProvider('room-corner', (_) => null));
    r.registry.dispose();
    // M-AT6: dispose leaves the providers alone.
    expect(d.disposals, 1);
    expect(r.registry.kinds, isEmpty);
  });

  test('AT-7 a factory that throws adds nothing and reports hookFailed', () {
    final r = Rig();
    r.registry.add('alpha', (_) => throw ArgumentError('no faces'), r.services);
    r.add('beta', RecordingProvider('room-corner', (_) => null));
    // M-AT7: `add` without its try/catch.
    expect(r.registry.kinds, {'room-corner'});
    expect([for (final d in r.reported) (d.kitId, d.subject, d.code)],
        [('alpha', 'attachments', KitDiagnosticCode.hookFailed)]);
  });
}
