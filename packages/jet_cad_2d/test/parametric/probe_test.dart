// Spec 2a E2: probe runs one live object's hooks in isolation, returns the
// first error or null, and changes nothing.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/frozen_clients.dart';

/// The recorded calls, without the survey's reach and references of every
/// object.
List<String> beyondSurvey() => [
      for (final c in hookCalls)
        if (!c.startsWith('reach ') && !c.startsWith('references ')) c,
    ];

void main() {
  setUp(resetHooks);

  test('E2-P1 a healthy object: null, its own hooks only, nothing changes', () {
    final s = frozenScene(places: true);
    final before = encoded(s.doc);
    final state = s.doc.commands.stateId;
    final depth = s.doc.commands.undoDepth;
    resetHooks();
    expect(s.system.probe(hN), isNull);
    // M-E2p-plan: neither dissolves nor generate runs.
    expect(beyondSurvey(),
        ['pageKey tile', 'dissolves N', 'generate N', 'diagnose N']);
    expect(encoded(s.doc), before);
    expect(s.doc.commands.stateId, state);
    expect(s.doc.commands.undoDepth, depth);
    expect(s.doc.commands.canRedo, isFalse);
  });

  for (final (call, object) in [
    ('reach N', hN),
    ('references N', hN),
    ('pageKey tile', hN),
    ('dissolves N', hN),
    ('generate N', hN),
    ('diagnose N', hN),
    ('placeBox Q', hQ),
    ('placeInput Q', hQ),
    ('readBox S', hS),
  ]) {
    test('E2-P2 the error is returned, nothing changes: $call', () {
      final s = frozenScene(places: true);
      final before = encoded(s.doc);
      final state = s.doc.commands.stateId;
      resetHooks();
      failingHooks.add(call);
      // M-E2p-catch: the error escapes. M-E2p-page, M-E2p-place,
      // M-E2p-input, M-E2p-read, M-E2p-plan, M-E2p-diag: that hook is not
      // run.
      expect(s.system.probe(object), HookFailure(call));
      expect(encoded(s.doc), before);
      expect(s.doc.commands.stateId, state);
    });
  }

  test("E2-P3 a broken neighbour's error is not reported as another's", () {
    final s = frozenScene();
    for (final call in ['reach F', 'references F']) {
      resetHooks();
      failingHooks.add(call);
      // M-E2p-iso: the probe's survey keeps F and throws its error for N.
      expect(s.system.probe(hN), isNull, reason: call);
      expect(s.system.probe(hF), HookFailure(call), reason: call);
    }
  });

  test('E2-P4 a hook that executes is refused, and nothing changes', () {
    final s = frozenScene();
    final before = encoded(s.doc);
    final state = s.doc.commands.stateId;
    final depth = s.doc.commands.undoDepth;
    Tile.reenter = s.doc;
    Tile.reentries = 1;
    // M-E2p-guard: unguarded, N's generate executes an edit that lands.
    expect(
        s.system.probe(hN),
        isA<StateError>()
            .having((e) => e.message, 'message', contains('must not mutate')));
    expect(encoded(s.doc), before);
    expect(s.doc.commands.stateId, state);
    expect(s.doc.commands.undoDepth, depth);
  });

  test('E2-P5 a frozen object, or no object, is not probed', () {
    final s = frozenScene();
    s.frozen.add(hF);
    resetHooks();
    // M-E2p-live: F, frozen, is probed by the catalog's rule.
    expect(s.system.probe(hF), isNull);
    expect(hookCalls, isEmpty);
    for (final h in [
      s.doc.rootHandle,
      childrenOf(s.doc, hN).first,
      const Handle(987654),
    ]) {
      expect(s.system.probe(h), isNull, reason: h.toHex());
    }
    expect(hookCalls, isEmpty);
  });
}
