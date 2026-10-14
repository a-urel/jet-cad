### Task 7: The plan file: the manifest, load, save, versions (spec P4 "The plan file", P5 import manifest)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/file/plan_format_exception.dart`, `packages/jet_cad_2d_plan/lib/src/file/semver.dart`, `packages/jet_cad_2d_plan/lib/src/file/manifest.dart`, `packages/jet_cad_2d_plan/lib/src/file/plan_file.dart`
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (exports), `packages/jet_cad_2d_plan/test/support/harness.dart` (adds `planText`)
- Test: `packages/jet_cad_2d_plan/test/file/plan_file_test.dart`, `packages/jet_cad_2d_plan/test/file/manifest_test.dart`, `packages/jet_cad_2d_plan/test/file/semver_test.dart`

**Interfaces:**
- Consumes: `KitSet`, `validateKitSet` (Task 6); `ManifestComponent` (`format`, `kits`, `fromJson`, `toJson`, `componentTypeId = 'jetcad.manifest'`), `SymbolComponent.componentTypeId = 'jetcad.symbol'`, `isKitId`, `kitOfKey`, `KitDiagnostic({required String kitId, String? subject, required KitDiagnosticCode code, required String message, Object? error})`, `KitDiagnosticCode.kitMissing`, `KitDiagnosticCode.kitNewer` (contract, Tasks 1 of sub-project 1 and Task 4); `DraftDocumentCodec.encode`, `DraftDocumentCodec.decode(..., {List<Diagnostic>? diagnostics, void Function(ComponentRegistry)? registerComponents, bool keepUnreadableComponents = false})` (engine, E4 as the Task 1 ruling made it: opt-in); the test kit API and `planDocument`, `installSystem`, `catalogOf`, `registerPlanComponents`, `addObject`, `addLine` (Task 6).
- Produces (exported from the barrel unless marked internal):
  - `enum PlanFormatCode { noManifest, formatTooNew, schema, notJson, damagedUnsavable }`.
  - `final class PlanFormatException implements FormatException` — `const PlanFormatException(PlanFormatCode code, String message)`; `code`, `message`, `source` (null), `offset` (null); `toString()` = `PlanFormatException(<code>): <message>`.
  - `const int kPlanFormat = 1`.
  - `final class PlanManifest` — `const PlanManifest({int format = 1, Map<String, String> kits = const {}})`; `format`, `kits`; value equality.
  - `PlanManifest? manifestOf(DraftDocument d)` — the root's `jetcad.manifest` as read, or null.
  - `Set<String> usedKits(DraftDocument d)` — sorted kit ids of component type ids and symbol keys, `jetcad` and non-kit prefixes excluded.
  - `PlanManifest manifestToWrite(PlanManifest? read, Set<String> used, KitSet loaded)`.
  - `final class ManifestCheck` — `Set<String> missing`, `List<KitDiagnostic> diagnostics`; `ManifestCheck checkManifest(PlanManifest manifest, Set<String> used, KitSet loaded)`.
  - `DraftDocument decodePlan(String text, {required void Function(ComponentRegistry) register, required List<Diagnostic> diagnostics, TextMeasurer measurer = const InsertionPointMeasurer(), DraftPermissions permissions = DraftPermissions.all})`.
  - `String encodePlan(DraftDocument d, KitSet loaded)`.
  - `String ensureManifest(String text)`.
  - `final class SemVer implements Comparable<SemVer>` (`major`, `minor`, `patch`, `pre`; `static SemVer? tryParse(String)`) and `bool? isNewerVersion(String plan, String loaded)` — **internal** (not exported; the tests import `package:jet_cad_2d_plan/src/file/semver.dart`).
  - harness: `String planText(List<PlanKit> kits, void Function(DraftDocument d) build, {DecimalSeparator separator = DecimalSeparator.point})`.

Plan decision: `decodePlan` checks the manifest on the **raw JSON**, before the engine decodes anything, so a format-2 plan is refused as `formatTooNew` even when this build could not read its components. The check reads `components['jetcad.manifest']['<root handle>']` and runs `ManifestComponent.fromJson` on it; a manifest that does not read (a format that is not an int, a kit id that is not one, an empty version) is `schema`. Order: `notJson` (not JSON, or not an object), `noManifest`, `schema` (a manifest that does not read), `formatTooNew`, then the engine's decode, any of whose errors is `schema`.
Plan decision: `decodePlan` passes `keepUnreadableComponents: true` and its `diagnostics` list to the codec (the Task 1 ruling): a component whose factory throws is kept raw with a `component.unreadable` diagnostic naming its handle, and the plan opens. Task 11 turns those diagnostics into `componentUnreadable` and locks and freezes the handles.
Plan decision: saving never mutates the document. `encodePlan` encodes the document, then replaces the root's entry of `jetcad.manifest` in the encoded `components` map and re-sorts that map's type ids (and the manifest's handles) as `ComponentRegistry.toJson` sorts them (`component.dart:254-286`), so `encodePlan(decodePlan(x)) == x` for every `x` it wrote. The manifest in memory stays the one read, so a missing kit's entry is still the one read at the next save.
Plan decision: the manifest written is, for every kit that is used or listed in the manifest read: a loaded kit's version when it is used (a loaded kit no longer used is dropped); a kit that is not loaded keeps its entry as read, used or not (its objects are locked, Task 10, so they cannot have gone). A used kit neither loaded nor listed gets no entry: there is no version to write.
Plan decision: "used" is read from the encoded `components` map: a type id `<kit>.<...>` whose `<kit>` is a kit id other than `jetcad` (so the engine's `jet_cad.object_layer` and `jetcad.page`, and today's `floor_planner.*`, are not kits), and the `key` of every `jetcad.symbol` payload. Raw (unknown or unreadable) components count, by their type id.
Plan decision: `checkManifest` visits the union of the manifest's kits and the used kits, sorted by id: a kit not loaded is missing (`kitMissing`); a loaded kit whose saved version is newer than the loaded one by semver precedence warns (`kitNewer`); a version that does not parse is not compared (no diagnostic, never a refusal).
Plan decision: `ensureManifest` returns the very string it was given when the plan already carries a manifest on its root, and when the text is JSON but no plan (no `root` int, no `components` map: `decodePlan` refuses it with its own code); otherwise it adds `{"format": 1, "kits": {}}` on the root and re-encodes.

- [ ] **Step 1: Write the failing tests.** In `packages/jet_cad_2d_plan/test/support/harness.dart`, add the import `import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';` and, at the end:

```dart
/// A saved plan over [kits]: [planDocument] with the kits' system
/// installed, [build] run on it, then [encodePlan] (a manifest of the
/// loaded kits the plan uses).
String planText(List<PlanKit> kits, void Function(DraftDocument d) build,
    {DecimalSeparator separator = DecimalSeparator.point}) {
  final d = planDocument(kits, separator: separator);
  final system = ParametricSystem(d, catalogOf(kits))..install();
  try {
    build(d);
  } finally {
    system.dispose();
  }
  return encodePlan(d, validateKitSet(kits));
}
```

  Create `packages/jet_cad_2d_plan/test/file/semver_test.dart`:

```dart
// Spec 2a P4 "Versions (R6)": kit versions are semantic versions compared
// by precedence; one that does not parse is not compared.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/file/semver.dart';

void main() {
  test('PF-7 precedence, semver 2.0.0 section 11; build metadata ignored', () {
    const ordered = [
      '0.9.9',
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0',
      '1.0.1',
      '1.2.0',
      '1.10.0',
      '2.0.0',
    ];
    for (var i = 0; i < ordered.length; i++) {
      for (var j = 0; j < ordered.length; j++) {
        final a = SemVer.tryParse(ordered[i])!, b = SemVer.tryParse(ordered[j])!;
        // M-PF-7a: pre-release identifiers compared as text ('11' < '2').
        // M-PF-7b: a pre-release ranked above its release.
        // M-PF-7c: minor compared as text ('10' < '2').
        expect(a.compareTo(b).sign, i.compareTo(j).sign,
            reason: '${ordered[i]} vs ${ordered[j]}');
      }
    }
    expect(SemVer.tryParse('1.2.3+build.7')!.compareTo(SemVer.tryParse('1.2.3')!),
        0);
  });

  test('PF-7u what does not parse is null, and is never compared', () {
    for (final text in ['', '1', '1.2', '1.2.x', '01.2.3', '1.2.3-', 'v1.2.3',
        '1.2.3-01', '99999999999999999999.0.0']) {
      // M-PF-7u: tryParse on the major.minor.patch prefix only.
      expect(SemVer.tryParse(text), isNull, reason: text);
    }
    expect(isNewerVersion('1.x', '1.0.0'), isNull);
    expect(isNewerVersion('2.0.0', 'dev'), isNull);
    expect(isNewerVersion('1.2.1', '1.2.0'), isTrue);
    expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('1.2.0', '1.2.0-rc.1'), isTrue);
  });
}
```

  Create `packages/jet_cad_2d_plan/test/file/manifest_test.dart`:

```dart
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
  test('PF-3 used kits: component type ids and symbol keys under a kit id',
      () {
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
    ]));
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
        const PlanManifest(kits: {'gone': '2.0.0', 'test': '0.9.0', 'old': '1.0.0'}),
        {'test', 'gone'},
        loaded);
    // M-PF-4: a kit that is not loaded drops its entry.
    expect(written,
        const PlanManifest(kits: {'gone': '2.0.0', 'old': '1.0.0', 'test': '1.2.0'}));
  });

  test('PF-5 a loaded kit the plan no longer uses is dropped', () {
    final loaded = validateKitSet([testKit(), discKit()]);
    // M-PF-5: every loaded kit read is written, used or not.
    expect(
        manifestToWrite(const PlanManifest(kits: {'disc': '0.4.0', 'test': '1.0.0'}),
            {'test'}, loaded),
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
    expect([for (final d in check.diagnostics) (d.kitId, d.code)], [
      ('gone', KitDiagnosticCode.kitMissing),
      ('lost', KitDiagnosticCode.kitMissing),
      ('test', KitDiagnosticCode.kitNewer),
    ]);
    expect(check.diagnostics.last.message, allOf(contains('2.0.0'), contains('1.2.0')));

    // M-PF-8a: a version that does not parse taken as newer.
    for (final (saved, have) in [('1.x', '1.2.0'), ('9.0.0', 'dev'), ('0.9.0', '1.2.0')]) {
      final quiet = checkManifest(PlanManifest(kits: {'test': saved}), const {},
          validateKitSet([testKit(version: have)]));
      expect(quiet.diagnostics, isEmpty, reason: '$saved over $have');
      expect(quiet.missing, isEmpty);
    }
    final pre = checkManifest(const PlanManifest(kits: {'test': '1.2.0'}),
        const {}, validateKitSet([testKit(version: '1.2.0-rc.1')]));
    expect([for (final d in pre.diagnostics) d.code], [KitDiagnosticCode.kitNewer]);
  });
}
```

  Create `packages/jet_cad_2d_plan/test/file/plan_file_test.dart`:

```dart
// Spec 2a P4 "The plan file", P5 "Imported text without a manifest": a
// load refuses by code and changes nothing; a save writes the manifest and
// is byte-stable; a component this build cannot read is kept raw; an
// import gets an empty manifest.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

/// The fixture: a turned slab off the origin, a disc, a line.
String fixture() => planText([testKit(), discKit()], (d) {
      addObject<SlabComponent>(
          d,
          SlabComponent(
              width: 1800, height: 900, angle: 0.4, finish: 'tiled', swatch: 'red'),
          at: Vector2(2350, -1180));
      addObject<DiscComponent>(d, DiscComponent(radius: 650),
          at: Vector2(-3100, 2240));
      addLine(d, Vector2(-500, 700), Vector2(1800, 2400));
    });

DraftDocument decode(String text,
    {List<PlanKit>? kits, List<Diagnostic>? diagnostics}) {
  final catalog = catalogOf(kits ?? [testKit(), discKit()]);
  return decodePlan(text,
      register: (r) => registerPlanComponents(r, catalog),
      diagnostics: diagnostics ?? <Diagnostic>[]);
}

Map<String, Object?> jsonOf(String text) =>
    (jsonDecode(text) as Map<String, Object?>);

Map<String, Object?> componentsOf(Map<String, Object?> json) =>
    json['components']! as Map<String, Object?>;

String rootKey(Map<String, Object?> json) => '${json['root']}';

Matcher refusedWith(PlanFormatCode code) => throwsA(allOf(
    isA<FormatException>(),
    isA<PlanFormatException>().having((e) => e.code, 'code', code)));

void main() {
  test('PF-1 each refusal has its code, and is a FormatException', () {
    final good = jsonOf(fixture());
    String withManifest(Object? manifest) {
      final json = jsonOf(fixture());
      final byHandle = componentsOf(json)['jetcad.manifest']! as Map<String, Object?>;
      byHandle[rootKey(json)] = manifest;
      return jsonEncode(json);
    }

    final noManifest = jsonOf(fixture());
    componentsOf(noManifest).remove('jetcad.manifest');
    final cases = <String, PlanFormatCode>{
      'not json': PlanFormatCode.notJson,
      '[1, 2]': PlanFormatCode.notJson,
      '{}': PlanFormatCode.noManifest,
      jsonEncode(noManifest): PlanFormatCode.noManifest,
      withManifest({'format': 2, 'kits': <String, Object?>{}}):
          PlanFormatCode.formatTooNew,
      withManifest({'format': '1', 'kits': <String, Object?>{}}):
          PlanFormatCode.schema,
      withManifest({
        'format': 1,
        'kits': {'Bad': '1.0.0'},
      }): PlanFormatCode.schema,
      jsonEncode({...good, 'schemaVersion': 9999}): PlanFormatCode.schema,
      jsonEncode({...good, 'entities': 7}): PlanFormatCode.schema,
    };
    // M-PF-1a: no manifest check. M-PF-1b: `format > kPlanFormat + 1`.
    // M-PF-1c: the engine's errors rethrown as they are, not as schema.
    for (final MapEntry(key: text, value: code) in cases.entries) {
      expect(() => decode(text), refusedWith(code), reason: text);
    }
    expect('${const PlanFormatException(PlanFormatCode.noManifest, 'none')}',
        'PlanFormatException(noManifest): none');
  });

  test('PF-unreadable a component whose factory throws is kept raw: the plan '
      'opens, the diagnostic names it, and a save writes it byte for byte',
      () {
    final json = jsonOf(fixture());
    final slabs = componentsOf(json)[slabTypeId]! as Map<String, Object?>;
    final key = slabs.keys.single;
    (slabs[key]! as Map<String, Object?>)['width'] = 'wide';
    final broken = jsonEncode(json);
    final diagnostics = <Diagnostic>[];
    // M-PF-unreadable: `keepUnreadableComponents: true` removed from
    // decodePlan's codec call: the load is refused as schema.
    final d = decode(broken, diagnostics: diagnostics);
    final h = Handle.checked(int.parse(key));
    expect(d.components.get<SlabComponent>(h), isNull);
    expect(d.components.unknownOf(h), hasLength(1));
    expect(
        diagnostics.where((x) => x.code == 'component.unreadable').single.handles,
        [h]);
    final saved = componentsOf(jsonOf(encodePlan(d, validateKitSet([testKit(), discKit()]))));
    expect(jsonEncode(saved[slabTypeId]), jsonEncode(slabs));
  });

  test('PF-6 a save is byte-stable: encode(decode(x)) == x, twice', () {
    final x = planText([testKit(), discKit()], (d) {
      addObject<SlabComponent>(d, SlabComponent(width: 1800, height: 900, angle: 0.4),
          at: Vector2(2350, -1180));
      addObject<DiscComponent>(d, DiscComponent(radius: 650),
          at: Vector2(-3100, 2240));
      d.components.attachUnknown(d.rootHandle, {'typeId': 'gone.widget', 'size': 3});
    });
    final loaded = validateKitSet([testKit(), discKit()]);
    final types = componentsOf(jsonOf(x)).keys.toList();
    // M-PF-6: the components map not re-sorted after the manifest is put in.
    expect(types, [...types]..sort(), reason: 'premise: the canonical order');
    final y = encodePlan(decode(x), loaded);
    expect(y, x);
    expect(encodePlan(decode(y), loaded), x);
  });

  test("PF-9 a missing kit's entry and objects round-trip through a save", () {
    final json = jsonOf(fixture());
    componentsOf(json)['gone.widget'] = {
      rootKey(json): {'b': 2, 'a': 1},
    };
    final manifest = componentsOf(json)['jetcad.manifest']! as Map<String, Object?>;
    manifest[rootKey(json)] = {
      'format': 1,
      'kits': {'disc': '0.4.0', 'gone': '3.1.0', 'test': '9.0.0'},
    };
    final saved = jsonOf(encodePlan(decode(jsonEncode(json)),
        validateKitSet([testKit(version: '1.2.0'), discKit()])));
    expect(
        (componentsOf(saved)['jetcad.manifest']! as Map<String, Object?>)[rootKey(saved)],
        {
          'format': 1,
          'kits': {'disc': '0.4.0', 'gone': '3.1.0', 'test': '1.2.0'},
        });
    expect(jsonEncode(componentsOf(saved)['gone.widget']),
        jsonEncode({rootKey(json): {'b': 2, 'a': 1}}));
  });

  test('PF-10 an import without a manifest gets an empty one and opens as '
      'plain geometry; one with a manifest is returned as it is', () {
    final kits = [testKit()];
    final drawing = planDocument(kits);
    final line = addLine(drawing, Vector2(-500, 700), Vector2(1800, 2400));
    final imported = DraftDocumentCodec.encodeToString(drawing);
    expect(() => decode(imported), refusedWith(PlanFormatCode.noManifest),
        reason: 'premise: without the manifest the load refuses');
    // M-PF-10a: ensureManifest returns its text unchanged.
    final d = decode(ensureManifest(imported), kits: kits);
    expect(manifestOf(d), const PlanManifest());
    expect(usedKits(d), isEmpty);
    expect(d.entities.containsHandle(line), isTrue);

    final plan = fixture();
    // M-PF-10b: ensureManifest always re-encodes.
    expect(ensureManifest(plan), same(plan));
    expect(() => ensureManifest('not json'), refusedWith(PlanFormatCode.notJson));
  });
}
```

- [ ] **Step 2: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/file`. Expected: compilation errors naming `encodePlan`, `decodePlan`, `PlanFormatException`, and the missing `src/file/semver.dart`.

- [ ] **Step 3: The exception.** Create `packages/jet_cad_2d_plan/lib/src/file/plan_format_exception.dart`:

```dart
// A plan the library refuses to open or save (spec 2a P4): a
// FormatException, as today's load throws (floor_plan_controller.dart:
// 1192-1203), with a code a host can test.

/// Why a plan was refused.
enum PlanFormatCode {
  /// The plan carries no `jetcad.manifest` on its root.
  noManifest,

  /// The manifest's format is above the one this library writes.
  formatTooNew,

  /// The engine's schema check refused it, or its manifest does not read.
  schema,

  /// The text is not a JSON object.
  notJson,

  /// A damaged plan whose encoding does not decode again (Task 11).
  damagedUnsavable,
}

/// A refused plan. A [FormatException], so a host that catches today's
/// keeps working.
final class PlanFormatException implements FormatException {
  const PlanFormatException(this.code, this.message);

  final PlanFormatCode code;

  @override
  final String message;

  /// Not kept: a plan's text can be megabytes.
  @override
  Object? get source => null;

  @override
  int? get offset => null;

  @override
  String toString() => 'PlanFormatException(${code.name}): $message';
}
```

- [ ] **Step 4: Versions.** Create `packages/jet_cad_2d_plan/lib/src/file/semver.dart`:

```dart
// Kit versions in a plan's manifest (spec 2a P4 "Versions", contract R6):
// semantic versions 2.0.0, compared by precedence. A version that does not
// parse is not compared, and never refuses a load.
import 'dart:math' as math;

import 'package:meta/meta.dart';

final RegExp _semver = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?'
    r'(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$');

final RegExp _numeric = RegExp(r'^\d+$');

@immutable
final class SemVer implements Comparable<SemVer> {
  const SemVer._(this.major, this.minor, this.patch, this.pre);

  final int major, minor, patch;

  /// The pre-release identifiers; empty for a release. Build metadata is
  /// not kept: it takes no part in precedence.
  final List<String> pre;

  /// [text] as a semantic version, or null when it is not one (or a part
  /// overflows an int).
  static SemVer? tryParse(String text) {
    final m = _semver.firstMatch(text);
    if (m == null) return null;
    final major = int.tryParse(m[1]!);
    final minor = int.tryParse(m[2]!);
    final patch = int.tryParse(m[3]!);
    if (major == null || minor == null || patch == null) return null;
    final pre = m[4];
    return SemVer._(major, minor, patch,
        pre == null ? const [] : List.unmodifiable(pre.split('.')));
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (pre.isEmpty || other.pre.isEmpty) {
      // A release ranks above its pre-releases.
      return (other.pre.isEmpty ? 0 : 1) - (pre.isEmpty ? 0 : 1);
    }
    for (var i = 0; i < math.min(pre.length, other.pre.length); i++) {
      final c = _compareIdentifier(pre[i], other.pre[i]);
      if (c != 0) return c;
    }
    return pre.length.compareTo(other.pre.length);
  }

  /// Numeric identifiers numerically (no leading zero: the longer is the
  /// larger, so no int can overflow), below alphanumeric ones, which
  /// compare in ASCII order.
  static int _compareIdentifier(String a, String b) {
    final an = _numeric.hasMatch(a), bn = _numeric.hasMatch(b);
    if (an && bn) {
      return a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b);
    }
    if (an != bn) return an ? -1 : 1;
    return a.compareTo(b);
  }

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(pre));
}

/// Whether [plan] is newer than [loaded] by precedence; null when either
/// does not parse.
bool? isNewerVersion(String plan, String loaded) {
  final a = SemVer.tryParse(plan), b = SemVer.tryParse(loaded);
  if (a == null || b == null) return null;
  return a.compareTo(b) > 0;
}
```

- [ ] **Step 5: The manifest.** Create `packages/jet_cad_2d_plan/lib/src/file/manifest.dart`:

```dart
// The plan manifest (spec 2a P4, umbrella A8): on a plan's root, the
// format and `{kit id: version}` for each kit the plan uses. Read as it
// was saved, written at each save, checked against the loaded kits.
import 'dart:collection';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

import '../kits/kit_set.dart';
import 'semver.dart';

/// The plan format this library writes and reads.
const int kPlanFormat = 1;

/// A plan's manifest: its format and its kits' versions.
@immutable
final class PlanManifest {
  const PlanManifest({this.format = kPlanFormat, this.kits = const {}});

  final int format;

  /// Kit id → the version that last saved the plan.
  final Map<String, String> kits;

  @override
  bool operator ==(Object other) {
    if (other is! PlanManifest ||
        other.format != format ||
        other.kits.length != kits.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in kits.entries) {
      if (other.kits[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      format,
      Object.hashAllUnordered(
          [for (final e in kits.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'PlanManifest($format, $kits)';
}

/// [d]'s root manifest as read, or null when it has none (a new plan).
PlanManifest? manifestOf(DraftDocument d) {
  if (!d.components.isRegistered<ManifestComponent>()) return null;
  final m = d.components.get<ManifestComponent>(d.rootHandle);
  return m == null ? null : PlanManifest(format: m.format, kits: m.kits);
}

/// The kits [d] uses, sorted (spec P4): see [usedKitsIn].
Set<String> usedKits(DraftDocument d) => usedKitsIn(d.components.toJson());

/// The kits an encoded `components` map uses: the `<kit>` of each type id
/// `<kit>.<...>` whose `<kit>` is a kit id other than `jetcad`, and the
/// kit of each `jetcad.symbol` payload's `key`. Raw components count by
/// their type id.
Set<String> usedKitsIn(Map<String, Object?> components) {
  final used = SplayTreeSet<String>();
  void add(String id) {
    final dot = id.indexOf('.');
    if (dot <= 0) return;
    final kit = id.substring(0, dot);
    if (kit != 'jetcad' && isKitId(kit)) used.add(kit);
  }

  for (final MapEntry(key: typeId, value: byHandle) in components.entries) {
    add(typeId);
    if (typeId == SymbolComponent.componentTypeId &&
        byHandle is Map<String, Object?>) {
      for (final payload in byHandle.values) {
        if (payload is Map<String, Object?> && payload['key'] is String) {
          add(payload['key']! as String);
        }
      }
    }
  }
  return used;
}

/// The manifest a save writes (spec P4): for each kit used or read, a
/// loaded kit's version when it is used, and a kit that is not loaded
/// with its entry as read.
PlanManifest manifestToWrite(
    PlanManifest? read, Set<String> used, KitSet loaded) {
  final kits = SplayTreeMap<String, String>();
  for (final id in {...used, ...?read?.kits.keys}) {
    final kit = loaded.kitOf(id);
    if (kit != null) {
      if (used.contains(id)) kits[id] = kit.version;
    } else if (read?.kits[id] case final version?) {
      kits[id] = version;
    }
  }
  return PlanManifest(kits: Map.unmodifiable(kits));
}

/// What a load finds (spec P4): the kits the plan names or uses that are
/// not loaded, and one diagnostic for each such kit (`kitMissing`) and for
/// each loaded kit whose saved version is newer (`kitNewer`).
@immutable
final class ManifestCheck {
  const ManifestCheck(this.missing, this.diagnostics);

  final Set<String> missing;
  final List<KitDiagnostic> diagnostics;
}

ManifestCheck checkManifest(
    PlanManifest manifest, Set<String> used, KitSet loaded) {
  final missing = SplayTreeSet<String>();
  final diagnostics = <KitDiagnostic>[];
  for (final id in SplayTreeSet<String>.of({...manifest.kits.keys, ...used})) {
    final saved = manifest.kits[id];
    final kit = loaded.kitOf(id);
    if (kit == null) {
      missing.add(id);
      diagnostics.add(KitDiagnostic(
          kitId: id,
          code: KitDiagnosticCode.kitMissing,
          message: 'the plan uses the kit "$id"'
              '${saved == null ? '' : ' $saved'}, which is not loaded'));
      continue;
    }
    if (saved != null && isNewerVersion(saved, kit.version) == true) {
      diagnostics.add(KitDiagnostic(
          kitId: id,
          code: KitDiagnosticCode.kitNewer,
          message: 'the plan was saved by "$id" $saved, newer than the '
              'loaded ${kit.version}'));
    }
  }
  return ManifestCheck(Set.unmodifiable(missing), List.unmodifiable(diagnostics));
}
```

- [ ] **Step 6: Load, save, import.** Create `packages/jet_cad_2d_plan/lib/src/file/plan_file.dart`:

```dart
// A plan's text (spec 2a P4 "The plan file", P5): the engine's JSON with
// the manifest on its root. Loading refuses by code and changes nothing;
// saving writes the manifest without touching the document; an import
// without a manifest gets an empty one.
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';
import 'manifest.dart';
import 'plan_format_exception.dart';

const String _manifestType = ManifestComponent.componentTypeId;

/// [text] as a plan document, or a [PlanFormatException] (spec P4): not
/// JSON (`notJson`); no manifest on the root (`noManifest`); a manifest
/// that does not read (`schema`) or whose format is above [kPlanFormat]
/// (`formatTooNew`); anything the engine's decode throws (`schema`).
/// [register] registers the plan's component types (the page, the
/// contract's, the kits'); [diagnostics] receives the engine's load
/// diagnostics, `component.unreadable` included: a component whose factory
/// throws is kept raw and the plan opens (E4, opt-in).
DraftDocument decodePlan(String text,
    {required void Function(ComponentRegistry registry) register,
    required List<Diagnostic> diagnostics,
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all}) {
  final json = _object(text);
  _checkManifest(json);
  try {
    return DraftDocumentCodec.decode(json,
        measurer: measurer,
        permissions: permissions,
        diagnostics: diagnostics,
        registerComponents: register,
        keepUnreadableComponents: true);
  } catch (e) {
    throw PlanFormatException(PlanFormatCode.schema, 'not a plan: $e');
  }
}

Map<String, Object?> _object(String text) {
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    throw PlanFormatException(PlanFormatCode.notJson, 'not JSON: ${e.message}');
  }
  if (json is! Map<String, Object?>) {
    throw const PlanFormatException(
        PlanFormatCode.notJson, 'not a JSON object');
  }
  return json;
}

/// The root's manifest, read from the raw JSON before anything else.
void _checkManifest(Map<String, Object?> json) {
  final root = json['root'];
  final components = json['components'];
  final byHandle =
      components is Map<String, Object?> ? components[_manifestType] : null;
  final raw = root is int && byHandle is Map<String, Object?>
      ? byHandle['$root']
      : null;
  if (raw is! Map<String, Object?>) {
    throw const PlanFormatException(PlanFormatCode.noManifest,
        'the plan carries no $_manifestType on its root');
  }
  final ManifestComponent manifest;
  try {
    manifest = ManifestComponent.fromJson(raw);
  } catch (e) {
    throw PlanFormatException(
        PlanFormatCode.schema, 'its $_manifestType does not read: $e');
  }
  if (manifest.format > kPlanFormat) {
    throw PlanFormatException(PlanFormatCode.formatTooNew,
        'the plan format ${manifest.format} is newer than $kPlanFormat');
  }
}

/// [d]'s text with the manifest a save writes (spec P4, [manifestToWrite])
/// on its root. [d] is not changed: the manifest in memory stays the one
/// read. The components map is written in the order the engine writes it
/// (type ids sorted, handles ascending), so a plan read and saved again
/// is the same bytes.
String encodePlan(DraftDocument d, KitSet loaded) {
  final json = DraftDocumentCodec.encode(d);
  final components =
      Map<String, Object?>.of(json['components']! as Map<String, Object?>);
  final manifest =
      manifestToWrite(manifestOf(d), usedKitsIn(components), loaded);
  final byHandle = <String, Object?>{
    ...?(components[_manifestType] as Map<String, Object?>?),
    '${d.rootHandle.value}':
        ManifestComponent(format: manifest.format, kits: manifest.kits)
            .toJson(),
  };
  components[_manifestType] = {
    for (final h in byHandle.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b))))
      h: byHandle[h],
  };
  json['components'] = {
    for (final typeId in components.keys.toList()..sort())
      typeId: components[typeId],
  };
  return jsonEncode(json);
}

/// An imported plan's text, with an empty manifest on its root when it has
/// none (spec P5, A17.5), so it opens as plain geometry. [text] itself
/// when it already has one, or when it is JSON but no plan ([decodePlan]
/// then refuses it by its own code). Not JSON: `notJson`.
String ensureManifest(String text) {
  final json = _object(text);
  final root = json['root'];
  final components = json['components'];
  if (root is! int || components is! Map<String, Object?>) return text;
  final byHandle = components[_manifestType];
  if (byHandle is Map<String, Object?> && byHandle.containsKey('$root')) {
    return text;
  }
  components[_manifestType] = <String, Object?>{
    if (byHandle is Map<String, Object?>) ...byHandle,
    '$root': ManifestComponent(kits: const {}).toJson(),
  };
  return jsonEncode(json);
}
```

  In `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`, the exports become:

```dart
export 'src/file/manifest.dart'
    show
        ManifestCheck,
        PlanManifest,
        checkManifest,
        kPlanFormat,
        manifestOf,
        manifestToWrite,
        usedKits;
export 'src/file/plan_file.dart';
export 'src/file/plan_format_exception.dart';
export 'src/kits/kit_set.dart';
```

  (`usedKitsIn` stays internal; `semver.dart` is not exported.)

- [ ] **Step 7: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/file test/kits`. Expected: `All tests passed!`.

- [ ] **Step 8: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/lib/src/file/plan_format_exception.dart packages/jet_cad_2d_plan/lib/src/file/semver.dart packages/jet_cad_2d_plan/lib/src/file/manifest.dart packages/jet_cad_2d_plan/lib/src/file/plan_file.dart packages/jet_cad_2d_plan/test/support/harness.dart packages/jet_cad_2d_plan/test/file/plan_file_test.dart packages/jet_cad_2d_plan/test/file/manifest_test.dart packages/jet_cad_2d_plan/test/file/semver_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the plan file: manifest, load, save and versions

decodePlan refuses by code (notJson, noManifest, schema, formatTooNew),
checking the root's jetcad.manifest on the raw JSON first, and keeps a
component whose factory throws raw with its diagnostic. encodePlan writes
the manifest of the kits the plan uses without touching the document and
in the engine's order, so a plan read and saved is the same bytes; a
missing kit's entry is kept as read. Kit versions compare as semver; one
that does not parse is never compared. ensureManifest gives an import an
empty manifest.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation step** (committed files only; after each, run the named test with `cd packages/jet_cad_2d_plan && flutter test <file> --plain-name '<id> '`, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` exits 0).
  - M-PF-1a (`lib/src/file/plan_file.dart`): delete the `_checkManifest(json);` line in `decodePlan` → PF-1 red (`{}` and the plan without a manifest refused as `schema` or opened).
  - M-PF-1b (`plan_file.dart`): `if (manifest.format > kPlanFormat + 1)` → PF-1 red (format 2 opens).
  - M-PF-1c (`plan_file.dart`): replace `} catch (e) { throw PlanFormatException(PlanFormatCode.schema, ...); }` in `decodePlan` with `} on PlanFormatException { rethrow; }` → PF-1 red (schema 9999 and `entities: 7` escape as other types).
  - M-PF-unreadable (`plan_file.dart`): delete `keepUnreadableComponents: true` from the codec call → PF-unreadable red (the load is refused as `schema`).
  - M-PF-6 (`plan_file.dart`): `json['components'] = components;` in place of the sorted map → PF-6 red (the manifest lands after `test.slab`; the second save sorts it).
  - M-PF-10a (`plan_file.dart`): `String ensureManifest(String text) => text;` (keep `_object` used elsewhere) → PF-10 red.
  - M-PF-10b (`plan_file.dart`): delete the `if (byHandle is Map<String, Object?> && byHandle.containsKey('$root')) { return text; }` early return → PF-10 red (`same(plan)` fails: re-encoded).
  - M-PF-3a (`lib/src/file/manifest.dart`): delete the `if (typeId == SymbolComponent.componentTypeId ...) { ... }` block → PF-3 red (no `cafe`).
  - M-PF-3b (`manifest.dart`): `if (isKitId(kit)) used.add(kit);` → PF-3 red (`jetcad` appears).
  - M-PF-4 (`manifest.dart`): delete the `else if (read?.kits[id] case final version?) { ... }` branch → PF-4 red (`gone`, `old` dropped) and PF-9 red.
  - M-PF-5 (`manifest.dart`): `kits[id] = kit.version;` without the `if (used.contains(id))` → PF-5 red (`disc` written).
  - M-PF-8a (`manifest.dart`): `isNewerVersion(saved, kit.version) != false` → PF-8 red (`1.x` and `dev` warn).
  - M-PF-8b (`manifest.dart`): `for (final id in SplayTreeSet<String>.of(manifest.kits.keys))` → PF-8 red (`lost` not missing).
  - M-PF-7a (`lib/src/file/semver.dart`): `_compareIdentifier` returns `a.compareTo(b)` always → PF-7 red (`beta.11` < `beta.2`).
  - M-PF-7b (`semver.dart`): `return (pre.isEmpty ? 0 : 1) - (other.pre.isEmpty ? 0 : 1);` (signs swapped) → PF-7 red.
  - M-PF-7c (`semver.dart`): `if (minor != other.minor) return '$minor'.compareTo('${other.minor}');` → PF-7 red (`1.10.0` < `1.2.0`).
  - M-PF-7u (`semver.dart`): drop the trailing `$` anchor of `_semver` → PF-7u red (`1.2.3-01` and `1.2.3-` parse, as `1.2.3`).

---

