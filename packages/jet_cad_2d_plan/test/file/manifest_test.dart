// Spec 2a P4 "The plan file": which kits a plan uses, the manifest a save
// writes, and what a load reports against the loaded kits.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

void main() {
  test('PF-3 used kits: component type ids and symbol keys under a kit id', () {
    final kits = [testKit(), discKit()];
    final d = planDocument(kits);
    installSystem(d, kits);
    addObject<SlabComponent>(
        d, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    addObject<DiscComponent>(d, DiscComponent(radius: 650),
        at: Vector2(-3100, 2240));
    final symbolHolder = d.handleSeed.next();
    d.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: symbolHolder,
          parent: d.rootHandle,
          transform: Transform2.translation(4100, -900),
          children: const [])),
      SetComponentCommand<SymbolComponent>(
          symbolHolder,
          SymbolComponent(
              key: 'cafe.table.round',
              version: 2,
              name: 'Round table',
              category: 'Tables',
              tags: const ['table'])),
    ], label: 'Add a symbol'));
    // Premise: the page and the objects' layers are there, and are no kit.
    expect(d.components.get<PageComponent>(d.rootHandle), isNotNull);
    // M-PF-3a: symbol keys not read. M-PF-3b: 'jetcad' not excluded.
    expect(usedKits(d), {'cafe', 'disc', 'test'});
    expect(usedKits(d).toList(), ['cafe', 'disc', 'test'], reason: 'sorted');
  });

  test('PF-4 a missing kit keeps the entry read; a loaded used kit is written',
      () {
    final loaded = validateKitSet([testKit(), discKit()]);
    final written = manifestToWrite(
        const PlanManifest(
            kits: {'gone': '2.0.0', 'test': '0.9.0', 'old': '1.0.0'}),
        {'test', 'gone'},
        loaded);
    // M-PF-4: a kit that is not loaded drops its entry.
    expect(
        written,
        const PlanManifest(
            kits: {'gone': '2.0.0', 'old': '1.0.0', 'test': '1.2.0'}));
  });

  test('PF-5 a loaded kit the plan no longer uses is dropped', () {
    final loaded = validateKitSet([testKit(), discKit()]);
    // M-PF-5: every loaded kit read is written, used or not.
    expect(
        manifestToWrite(
            const PlanManifest(kits: {'disc': '0.4.0', 'test': '1.0.0'}),
            {'test'},
            loaded),
        const PlanManifest(kits: {'test': '1.2.0'}));
    expect(manifestToWrite(null, {'disc', 'lost'}, loaded),
        const PlanManifest(kits: {'disc': '0.4.0'}),
        reason: 'a used kit neither loaded nor read has no version to write');
  });

  test('PF-8 missing kits, a newer kit warns, an unparsed version never does',
      () {
    final loaded =
        validateKitSet([testKit(version: '1.2.0'), discKit(version: '0.4.0')]);
    final check = checkManifest(
        const PlanManifest(
            kits: {'gone': '1.0.0', 'test': '2.0.0', 'disc': '0.4.0'}),
        {'test', 'disc', 'lost'},
        loaded);
    // M-PF-8b: only the manifest's kits visited ('lost' is used, not listed).
    expect(check.missing, {'gone', 'lost'});
    expect([
      for (final d in check.diagnostics) (d.kitId, d.code)
    ], [
      ('gone', KitDiagnosticCode.kitMissing),
      ('lost', KitDiagnosticCode.kitMissing),
      ('test', KitDiagnosticCode.kitNewer),
    ]);
    expect(check.diagnostics.last.message,
        allOf(contains('2.0.0'), contains('1.2.0')));

    // M-PF-8a: a version that does not parse taken as newer.
    for (final (saved, have) in [
      ('1.x', '1.2.0'),
      ('9.0.0', 'dev'),
      ('0.9.0', '1.2.0')
    ]) {
      final quiet = checkManifest(PlanManifest(kits: {'test': saved}), const {},
          validateKitSet([testKit(version: have)]));
      expect(quiet.diagnostics, isEmpty, reason: '$saved over $have');
      expect(quiet.missing, isEmpty);
    }
    final pre = checkManifest(const PlanManifest(kits: {'test': '1.2.0'}),
        const {}, validateKitSet([testKit(version: '1.2.0-rc.1')]));
    expect([for (final d in pre.diagnostics) d.code],
        [KitDiagnosticCode.kitNewer]);
  });
}
