### Task 5: Contract inputs R2, R3, R5, R7 (spec P6)

**Files:**
- Create: `packages/jet_cad_2d_kit/example/cafe_code.dart`
- Modify: `packages/jet_cad_2d_kit/lib/src/model/json_fields.dart` (`optionalField`), `lib/src/model/symbol_component.dart` (R2), `lib/src/authoring/catalog.dart` (R2), `lib/src/authoring/builder.dart` (R2), `lib/src/model/symbol_library.dart` (R7), `lib/src/authoring/conformance.dart` (R3), `README.md`, `CHANGELOG.md`; `docs/kits.md` (repository root; R5 and the code side)
- Test: create `packages/jet_cad_2d_kit/test/kit/example_code_test.dart`; modify `test/model/symbol_component_test.dart`, `test/authoring/builder_test.dart`, `test/authoring/snapshot_test.dart`, `test/model/symbol_library_test.dart`, `test/authoring/conformance_test.dart`, `test/invariants/doc_snippets_test.dart` (the block count)

(All paths below are under `packages/jet_cad_2d_kit/` unless they start at the repository root.)

**Interfaces:**
- Consumes: Task 4's `PlanKit.types`/`tools`/`propertyIds`, `PlanType` (`registerInto`, `fieldsOf`, `commitField`, `recolour`, `colourOf`), `isCodeId`, `KitProblemCode.typeOutsideKit`/`toolOutsideKit`; Task 3's specs and `ColourTarget`. Existing: `SymbolComponent` (`lib/src/model/symbol_component.dart:19-150`, keys alphabetical at `:107-115`, every field required by `fromJson` at `:120-131`), `field<T>` (`lib/src/model/json_fields.dart:8-17`), `CatalogSymbol` (`lib/src/authoring/catalog.dart:66-93`), `buildLibraryDocument` (`lib/src/authoring/builder.dart:31-106`), `geometrySnapshot` (`lib/src/authoring/snapshot.dart:13-29`: base, shapes, unit only), rule 11 (`lib/src/model/symbol_library.dart:311-334`, the area test at `:323-333`), `conformance` (`lib/src/authoring/conformance.dart:25-68`, `_wordProblems` `:139-188`), `doc_snippets_test.dart` DOC1 (`:56`, `docs/kits.md` pinned at 4 blocks), the committed `test/fixtures/sample_kit/sample.jetlib` (held byte-equal by conformance F0).
- Produces:
  - `SymbolComponent({…, bool retired = false})`, `final bool retired`; `CatalogSymbol({…, bool retired = false})`, `final bool retired` (the Shared interfaces' R2 line).
  - `conformance({…, Iterable<String> typeIds = const [], Iterable<String> toolIds = const [], Iterable<String> propertyIds = const []})` (R3, additive).
  - Rule 11 refuses a closed-polyline outline whose `2·area/perimeter` is at or under `Tolerance.standard.linear` (R7).
  - Not exported: `T optionalField<T>(Map<String, Object?> json, String key, String type, T absent)` in `json_fields.dart`.
  - `docs/kits.md` §10, the code side (R5); `example/cafe_code.dart` (`CafeSign`, `CafeSignType`, `signProperties`, `signColour`, `cafeCodeKit`, `cafeCodeNames`), whose two blocks the document shows verbatim.

Plan decision: **`retired` is written only when true and read as false when absent** (contract R2). Writing it always would change the bytes of every library and plan: the committed `test/fixtures/sample_kit/sample.jetlib`, which conformance F0 holds byte-equal to `encodeLibrary(sampleCatalog)` (K7.1), and every kit's committed library after it. Written only when true, its key sits in its alphabetical place (between `name` and `tags`), so K2's fixed key order holds for every text that has it. A present value must be a `bool` (`FormatException` otherwise, as every other field); `retired: false` written by hand reads as false. This departs from K2's plan decision "every field is required": a field added after the format was first written must be optional when read (R2's own words).
Plan decision: **retiring changes no snapshot entry.** `geometrySnapshot` holds geometry and the unit (K7); a retired `key@N` keeps both. The library's bytes change (the definition carries the mark), so conformance reports `builtDiffers` until the generator runs, and conforms after (R2-7).
Plan decision: **R7's width is `2 · area / perimeter`,** the area by the existing shoelace (relative to the first vertex) and the perimeter over the stored points, the closing pair included (a closed polyline repeats its first point, `jet_cad_2d/lib/src/document/drafting.dart:102-116`). Rule 15 runs first and refuses a polyline whose points all lie within the tolerance (`symbol_library.dart:444-449`), so the perimeter is never zero. Checked numerically before writing: the 600 mm × 1e-9 mm sliver at y = 560 has width ≈ 9.99989e-10 (refused); 600 × 2e-9 has ≈ 1.99998e-9 (loads; without the factor 2 it would be ≈ 9.99989e-10 and refused, M-R7c); 600 × 1 has ≈ 0.998.
Plan decision: **V11d and V11e are replaced, V11c's message part changes.** They are this package's own tests of the K3 amendment R7 replaces, not ported tests. V11e's triangle (area 2·linear², about 2e-15 mm wide) loaded under the area test and is refused under the width test: it becomes R7-2, refused. V11d (area linear²/2) is refused under both rules, so it can no longer tell them apart and is dropped. V11c's diagonal is still refused; its message part becomes `is too thin (width 0.0)`.
Plan decision: **R3 codes:** a type id that is not `isCodeId` under the kit is `typeOutsideKit`, a tool id `toolOutsideKit` (Task 4's codes); a property id not under the kit (or without a dot) is `foreignWordId`, since a property id exists only as the word `property:<id>`. A code word without English is `missingEnglish`; with English, it is held to every declared locale by the existing check (`wordMissing`, `wordUntranslated`, `sameAsEnglish`). A code word naming none of the given ids is not an orphan: a kit may pass part of its ids, and a kit calling without them (as before 2a) is held to nothing new (R3-5).
Plan decision: **R5 in `docs/kits.md` is a new §10 plus edits of §§2-9,** and the code it shows is `example/cafe_code.dart`'s (DOC1 requires every ```` ```dart ```` block verbatim in `example/`; the count goes from 4 to 6). The example is a real code-side kit: `example_code_test.dart` validates, registers, edits and regenerates it.

- [ ] **Step 1: R2, the failing tests.** Apply to `test/model/symbol_component_test.dart`, `test/authoring/builder_test.dart` and `test/authoring/snapshot_test.dart`:

```diff
--- a/packages/jet_cad_2d_kit/test/model/symbol_component_test.dart
+++ b/packages/jet_cad_2d_kit/test/model/symbol_component_test.dart
@@ -18,6 +18,7 @@ SymbolComponent sofa({
   List<String> attachTo = const ['wall-face', 'room-corner'],
   String? family = 'sofa-long',
   bool noFamily = false,
+  bool retired = false,
 }) =>
     SymbolComponent(
       key: key,
@@ -27,6 +28,7 @@ SymbolComponent sofa({
       tags: tags,
       attachTo: attachTo,
       family: noFamily ? null : family,
+      retired: retired,
     );
 
 Matcher refusedOn(String field) =>
@@ -216,4 +218,59 @@ void main() {
       expect(SymbolComponent.fromJson({...full, 'newerField': 1}), sofa());
     });
   });
+
+  group('retired (contract R2)', () {
+    test('R2-1 written only when true, in its alphabetical place', () {
+      expect(sofa().retired, isFalse);
+      // M-R2a: always write the key; C7's pinned text goes red too.
+      expect(sofa().toJson().containsKey('retired'), isFalse);
+      expect(sofa(retired: true).toJson().keys.toList(), [
+        'attachTo',
+        'category',
+        'family',
+        'key',
+        'name',
+        'retired',
+        'tags',
+        'version',
+      ]);
+      expect(
+          jsonEncode(sofa(retired: true).toJson()),
+          '{"attachTo":["wall-face","room-corner"],"category":"Living Room",'
+          '"family":"sofa-long","key":"sample.sofa.three",'
+          '"name":"Three-seat sofa","retired":true,'
+          '"tags":["sofa","seating","couch"],"version":3}');
+    });
+
+    test('R2-2 absent reads false; present must be a bool', () {
+      // M-R2b: read it with `field` (required): a map without it, every
+      // library and plan saved before R2, is refused.
+      expect(SymbolComponent.fromJson(full).retired, isFalse);
+      expect(SymbolComponent.fromJson({...full, 'retired': true}),
+          sofa(retired: true));
+      expect(SymbolComponent.fromJson({...full, 'retired': false}), sofa());
+      // M-R2c: `json['retired'] == true` (anything else reads false).
+      for (final bad in <Object?>['true', 1, null]) {
+        expect(() => SymbolComponent.fromJson({...full, 'retired': bad}),
+            throwsFormatException,
+            reason: '$bad');
+      }
+    });
+
+    test('R2-3 equality and the hash see it', () {
+      // M-R2d: drop `retired` from ==.
+      expect(sofa(retired: true), isNot(sofa()));
+      expect(sofa(retired: true), sofa(retired: true));
+      expect(sofa(retired: true).hashCode, sofa(retired: true).hashCode);
+      expect('${sofa(retired: true)}', endsWith(', retired)'));
+    });
+
+    test('R2-4 it reads back through JSON text', () {
+      final s = sofa(retired: true, noFamily: true);
+      expect(
+          SymbolComponent.fromJson((jsonDecode(jsonEncode(s.toJson())) as Map)
+              .cast<String, Object?>()),
+          s);
+    });
+  });
 }
```

```diff
--- a/packages/jet_cad_2d_kit/test/authoring/builder_test.dart
+++ b/packages/jet_cad_2d_kit/test/authoring/builder_test.dart
@@ -224,4 +224,31 @@ void main() {
     expect(() => buildLibraryDocument(throwing), throwsStateError);
     expect(() => encodeLibrary(throwing), throwsStateError);
   });
+
+  test('R2-5 a retired symbol is built retired, the others not', () {
+    const retiredLamp = CatalogSymbol(
+      key: 'sample.lamp.wall',
+      name: 'Wall lamp',
+      category: 'Lighting',
+      tags: ['lamp', 'light'],
+      attachTo: ['wall-face'],
+      family: 'lamp-wall',
+      base: (640, 220),
+      shapes: [
+        CatalogArc((640, 220), 180, 0.25, -2.75),
+        CatalogPolyline([(460, 220), (820, 220), (700, 90)]),
+      ],
+      retired: true,
+    );
+    final bytes = encodeLibrary(
+        const Catalog(kit: 'sample', symbols: [table, retiredLamp, seat]));
+    // M-R2e: the builder leaves `retired` out.
+    expect(
+        [for (final e in SymbolLibrary.decode(bytes).entries) e.symbol.retired],
+        [false, true, false]);
+    expect('"retired":true'.allMatches(utf8.decode(bytes)), hasLength(1));
+    // Not retired, nothing is written: a library built before R2 keeps its
+    // bytes.
+    expect(utf8.decode(encodeLibrary(catalog)), isNot(contains('retired')));
+  });
 }
```

```diff
--- a/packages/jet_cad_2d_kit/test/authoring/snapshot_test.dart
+++ b/packages/jet_cad_2d_kit/test/authoring/snapshot_test.dart
@@ -100,4 +100,27 @@ void main() {
     });
     expect(merged.keys.toList(), ['a.b.c@1', 'b.c.d@1', 'c.d.e@1']);
   });
+
+  test('R2-6 retiring a symbol changes no snapshot entry', () {
+    const retired = CatalogSymbol(
+      key: 'sample.x.y',
+      version: 3,
+      name: 'X',
+      category: 'C',
+      unit: CatalogUnit(
+          kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
+      base: (120.5, -40),
+      shapes: [
+        CatalogLine((10, 20), (30, 40)),
+        CatalogPolyline([(1, 2), (3, 4), (5, 6)], closed: true),
+        CatalogCircle((7, 8), 9),
+        CatalogArc((1, 1), 2, 0.5, -1.25),
+      ],
+      retired: true,
+    );
+    // M-R2f: write `retired` into the entry; a retired key@N would read as
+    // changed geometry.
+    expect(geometrySnapshot(const Catalog(kit: 'sample', symbols: [retired])),
+        geometrySnapshot(const Catalog(kit: 'sample', symbols: [every])));
+  });
 }
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/model/symbol_component_test.dart test/authoring/builder_test.dart test/authoring/snapshot_test.dart`. Expected: each file fails to compile; the errors name the undefined named parameter `retired` (and the getter `retired`). Quote one per file.

- [ ] **Step 2: R2.** Apply to `lib/src/model/json_fields.dart`, `lib/src/model/symbol_component.dart`, `lib/src/authoring/catalog.dart` and `lib/src/authoring/builder.dart`:

```diff
--- a/packages/jet_cad_2d_kit/lib/src/model/json_fields.dart
+++ b/packages/jet_cad_2d_kit/lib/src/model/json_fields.dart
@@ -16,6 +16,13 @@ T field<T>(Map<String, Object?> json, String key, String type) {
   return value;
 }
 
+/// [json]'s value at [key], or [absent] when [json] has no [key]: a field
+/// added after a format was first written, so that what was saved before it
+/// still reads (contract R2). A present value must be a [T].
+T optionalField<T>(
+        Map<String, Object?> json, String key, String type, T absent) =>
+    json.containsKey(key) ? field<T>(json, key, type) : absent;
+
 /// [json]'s list of strings at [key].
 List<String> stringList(Map<String, Object?> json, String key, String type) {
   final list = field<List<Object?>>(json, key, type);
```

```diff
--- a/packages/jet_cad_2d_kit/lib/src/model/symbol_component.dart
+++ b/packages/jet_cad_2d_kit/lib/src/model/symbol_component.dart
@@ -15,6 +15,9 @@ import 'kit_ids.dart';
 /// Immutable and value-equal, [tags] and [attachTo] compared in order;
 /// [toJson] keys are alphabetical. Every bad value is an [ArgumentError]
 /// from the constructor, named by its field.
+///
+/// [retired] (contract R2) is written only when true and read as false when
+/// absent: a library or a plan saved before it keeps its bytes.
 @immutable
 final class SymbolComponent implements Component {
   /// Throws [ArgumentError] (never an assert: a release build refuses too)
@@ -27,6 +30,7 @@ final class SymbolComponent implements Component {
     required List<String> tags,
     List<String> attachTo = const [],
     this.family,
+    this.retired = false,
   })  : tags = List.unmodifiable(tags),
         attachTo = List.unmodifiable(attachTo) {
     if (!isSymbolKey(key)) {
@@ -97,6 +101,10 @@ final class SymbolComponent implements Component {
   /// The size family this symbol belongs to, or null.
   final String? family;
 
+  /// True: the symbol stays in its library, so plans that hold it keep
+  /// drawing it, but the plan library's gallery no longer offers it.
+  final bool retired;
+
   /// `key@version`, the definition's name in a library.
   String get id => '$key@$version';
 
@@ -110,13 +118,14 @@ final class SymbolComponent implements Component {
         'family': family,
         'key': key,
         'name': name,
+        if (retired) 'retired': true,
         'tags': tags,
         'version': version,
       };
 
   /// Throws [FormatException] for a missing or mistyped field, and the
   /// constructor's [ArgumentError] for a value K2 refuses. A field this
-  /// build does not know is ignored.
+  /// build does not know is ignored; an absent `retired` reads false.
   static SymbolComponent fromJson(Map<String, Object?> json) {
     const t = 'SymbolComponent';
     return SymbolComponent(
@@ -127,6 +136,7 @@ final class SymbolComponent implements Component {
       tags: stringList(json, 'tags', t),
       attachTo: stringList(json, 'attachTo', t),
       family: field<String?>(json, 'family', t),
+      retired: optionalField<bool>(json, 'retired', t, false),
     );
   }
 
@@ -139,12 +149,14 @@ final class SymbolComponent implements Component {
       other.category == category &&
       listEquals(other.tags, tags) &&
       listEquals(other.attachTo, attachTo) &&
-      other.family == family;
+      other.family == family &&
+      other.retired == retired;
 
   @override
   int get hashCode => Object.hash(key, version, name, category,
-      Object.hashAll(tags), Object.hashAll(attachTo), family);
+      Object.hashAll(tags), Object.hashAll(attachTo), family, retired);
 
   @override
-  String toString() => 'SymbolComponent($id, $name, $category)';
+  String toString() =>
+      'SymbolComponent($id, $name, $category${retired ? ', retired' : ''})';
 }
```

```diff
--- a/packages/jet_cad_2d_kit/lib/src/authoring/catalog.dart
+++ b/packages/jet_cad_2d_kit/lib/src/authoring/catalog.dart
@@ -62,7 +62,8 @@ final class CatalogUnit {
 }
 
 /// One symbol of a kit's library. A unit draws its outline first (K3 rule
-/// 11): a closed polyline or a circle.
+/// 11): a closed polyline or a circle. A [retired] symbol stays in the
+/// library and leaves the gallery (contract R2).
 final class CatalogSymbol {
   const CatalogSymbol({
     required this.key,
@@ -75,6 +76,7 @@ final class CatalogSymbol {
     this.unit,
     required this.base,
     required this.shapes,
+    this.retired = false,
   });
 
   final String key;
@@ -87,6 +89,7 @@ final class CatalogSymbol {
   final CatalogUnit? unit;
   final CatalogPoint base;
   final List<CatalogShape> shapes;
+  final bool retired;
 
   /// `key@version`.
   String get id => '$key@$version';
```

```diff
--- a/packages/jet_cad_2d_kit/lib/src/authoring/builder.dart
+++ b/packages/jet_cad_2d_kit/lib/src/authoring/builder.dart
@@ -42,6 +42,7 @@ DraftDocument buildLibraryDocument(Catalog catalog) {
         tags: s.tags,
         attachTo: s.attachTo,
         family: s.family,
+        retired: s.retired,
       ),
   ];
   final units = [
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/model test/authoring`. Expected: `All tests passed!` — C7's pinned text and F0's byte equality with the committed `sample.jetlib` included.

- [ ] **Step 3: R7, the failing tests.** Apply to `test/model/symbol_library_test.dart` (rule 11's group):

```diff
--- a/packages/jet_cad_2d_kit/test/model/symbol_library_test.dart
+++ b/packages/jet_cad_2d_kit/test/model/symbol_library_test.dart
@@ -445,8 +445,9 @@ void main() {
       expectRefused(bytesOfJson(j), 11, ['sample.sofa.three@3', hex(sofaLine)]);
     });
 
-    // Amended by the final review: an outline must enclose more than
-    // Tolerance.standard.linear squared, either winding.
+    // Amended by the final review, then by contract R7: an outline must be
+    // wider than Tolerance.standard.linear, its width 2·area/perimeter,
+    // either winding.
     void outline(String name, List<double> coords, List<String> parts) {
       test(name, () {
         final j = validLibraryJson();
@@ -456,26 +457,46 @@ void main() {
       });
     }
 
-    // M-V11c: drop the area check.
+    void loads(String name, List<double> coords) {
+      test(name, () {
+        final j = validLibraryJson();
+        geometryJson(j, tableTop)['coords'] = coords;
+        final lib = SymbolLibrary.decode(bytesOfJson(j));
+        expect(lib.entries[1].leaves.first.payload.coords, coords);
+      });
+    }
+
+    // M-V11c: drop the width check.
     outline(
         'V11c a closed outline on one diagonal, off the origin',
         [950.0, 560.0, 1250.0, 860.0, 1550.0, 1160.0, 950.0, 560.0],
-        ['encloses no area (0.0)']);
-    // Area 5e-19, under linear² (1e-18), and not zero: near the origin, the
-    // only place a double can hold so thin a triangle. M-V11d: `area == 0`.
+        ['is too thin (width 0.0)']);
+    // R7's own case: 600 mm long, 1e-9 mm wide, off the origin. Its area
+    // (6e-7) is far above linear² (1e-18): the area test let it load.
+    // M-R7a: the area test back (`area <= linear * linear`).
+    outline('R7-1 a 600 mm by 1e-9 mm sliver is refused', [
+      950.0, 560.0, 1550.0, 560.0, 1550.0, 560.000000001, 950.0, //
+      560.000000001, 950.0, 560.0
+    ], [
+      'is too thin'
+    ]);
+    // V11e's triangle, of area 2 * linear², loaded under the area test; it
+    // is about 2e-15 mm wide. M-R7a turns this red too.
     outline(
-        'V11d an outline of area linear² / 2',
-        [1e-3, 2e-3, 2e-3, 2e-3, 1e-3, 2e-3 + 1e-15, 1e-3, 2e-3],
-        ['encloses no area']);
-    test('V11e an outline of area 2 * linear² loads', () {
-      // Positive control. M-V11e: `area <= linear` (not squared).
-      final j = validLibraryJson();
-      geometryJson(j, tableTop)['coords'] = [
-        1e-3, 2e-3, 2e-3, 2e-3, 1e-3, 2e-3 + 4e-15, 1e-3, 2e-3, //
-      ];
-      final lib = SymbolLibrary.decode(bytesOfJson(j));
-      expect(lib.entries[1].leaves.first.payload.coords[5], 2e-3 + 4e-15);
-    });
+        'R7-2 a triangle of area 2 * linear² is refused',
+        [1e-3, 2e-3, 2e-3, 2e-3, 1e-3, 2e-3 + 4e-15, 1e-3, 2e-3],
+        ['is too thin']);
+    // Twice the tolerance wide. M-R7c: drop the factor 2 (area/perimeter is
+    // then just under linear).
+    loads('R7-3 a 600 mm by 2e-9 mm outline loads', [
+      950.0, 560.0, 1550.0, 560.0, 1550.0, 560.000000002, 950.0, //
+      560.000000002, 950.0, 560.0,
+    ]);
+    // A healthy thin unit, a positive control: a 600 mm by 1 mm bar.
+    loads('R7-4 a 600 mm by 1 mm outline loads', [
+      950.0, 560.0, 1550.0, 560.0, 1550.0, 561.0, 950.0, 561.0, 950.0, //
+      560.0,
+    ]);
     test('V11f a clockwise outline loads', () {
       // The table's top, its winding reversed. M-V11f: drop `.abs()`.
       final j = validLibraryJson();
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/model/symbol_library_test.dart`. Expected: three red — V11c (the message), R7-1 and R7-2 (the area test lets them load); R7-3 and R7-4 green. Quote each red test's name.

- [ ] **Step 4: R7.** Apply to `lib/src/model/symbol_library.dart`:

```diff
--- a/packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart
+++ b/packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart
@@ -7,6 +7,7 @@
 // Pure Dart: no Flutter, no dart:io.
 import 'dart:async';
 import 'dart:convert';
+import 'dart:math' as math;
 import 'dart:typed_data';
 
 import 'package:jet_cad_2d/jet_cad_2d.dart';
@@ -298,7 +299,7 @@ final class SymbolLibrary {
     }
 
     // Rules 4 and 11, per definition: at least one leaf, a unit's outline
-    // (closed, and enclosing more than the tolerance squared).
+    // (closed, and wider than the tolerance, contract R7).
     final entries = <SymbolEntry>[];
     for (final (definition, symbol, unit) in drafts) {
       final who = 'definition ${definition.handle.toHex()} (${symbol.id})';
@@ -320,15 +321,20 @@ final class SymbolLibrary {
               '${first.record.handle.toHex()}, is not a closed polyline or a '
               'circle');
         }
-        // A circle's radius is already above the tolerance (rule 15).
+        // A circle's radius is already above the tolerance (rule 15). A
+        // closed polyline's width is 2·area/perimeter: a sliver of any
+        // length is as thin as it is wide, so the test scales (R7). Rule 15
+        // has already refused a polyline whose points all lie within the
+        // tolerance, so the perimeter is not zero.
         if (first.record.kind == EntityKind.polyline) {
-          final area = _enclosedArea(first.payload);
-          final linear = Tolerance.standard.linear;
-          if (area <= linear * linear) {
+          final width =
+              2 * _enclosedArea(first.payload) / _perimeter(first.payload);
+          if (width <= Tolerance.standard.linear) {
             throw SymbolLibraryError(
                 11,
                 '$who is a unit whose outline, '
-                '${first.record.handle.toHex()}, encloses no area ($area)');
+                '${first.record.handle.toHex()}, is too thin (width $width): '
+                'service mode would fill nothing');
           }
         }
       }
@@ -402,6 +408,18 @@ final class SymbolLibrary {
     return twice.abs() / 2;
   }
 
+  /// Rule 11: the length of [p]'s path, the closing pair included (a closed
+  /// polyline repeats its first point).
+  static double _perimeter(GeometryPayload p) {
+    final c = p.coords;
+    var length = 0.0;
+    for (var i = 0; i + 1 < p.pointCount; i++) {
+      final dx = c[i * 2 + 2] - c[i * 2], dy = c[i * 2 + 3] - c[i * 2 + 1];
+      length += math.sqrt(dx * dx + dy * dy);
+    }
+    return length;
+  }
+
   /// Rule 15: counts, finiteness, bounds, degeneracy against [Tolerance].
   static void _checkGeometry(EntityKind kind, GeometryPayload p, String who) {
     final (int? coords, int scalars) = switch (kind) {
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/model/symbol_library_test.dart test/authoring`. Expected: `All tests passed!` (the sample kit's and the cafe's outlines are far wider than the tolerance).

- [ ] **Step 5: R3, the failing tests.** Apply to `test/authoring/conformance_test.dart` (`copyOf` carries `retired`; R2-7; the R3 group):

```diff
--- a/packages/jet_cad_2d_kit/test/authoring/conformance_test.dart
+++ b/packages/jet_cad_2d_kit/test/authoring/conformance_test.dart
@@ -48,7 +48,8 @@ CatalogSymbol copyOf(CatalogSymbol s,
         List<String>? attachTo,
         String? family,
         CatalogUnit? unit,
-        List<CatalogShape>? shapes}) =>
+        List<CatalogShape>? shapes,
+        bool? retired}) =>
     CatalogSymbol(
       key: key ?? s.key,
       version: version ?? s.version,
@@ -60,6 +61,7 @@ CatalogSymbol copyOf(CatalogSymbol s,
       unit: unit ?? s.unit,
       base: s.base,
       shapes: shapes ?? s.shapes,
+      retired: retired ?? s.retired,
     );
 
 /// The sample catalog with [symbol] in place of the one of its id.
@@ -346,4 +348,139 @@ void main() {
       expect(withTurkish('Bar stool'), isEmpty, reason: order);
     }
   });
+
+  test('R2-7 a retired published key conforms once regenerated', () {
+    final retired =
+        replacing(copyOf(symbolOf('sample.stool.bar@1'), retired: true));
+    // The library changes (the symbol carries the mark), so the committed
+    // one is stale until the generator runs.
+    expect(codes(problems(catalog: retired)), [KitProblemCode.builtDiffers]);
+    final g = generated(retired);
+    // M-R2f (snapshot_test R2-6) turns this red as snapshotChanged.
+    expect(problems(catalog: retired, library: g.library, snapshot: g.snapshot),
+        isEmpty);
+    expect(g.snapshot, committedSnapshot());
+  });
+
+  group('the code side (contract R3)', () {
+    const Map<String, String> en = {
+      'type:sample.wall': 'Wall',
+      'tool:sample.wall': 'Wall tool',
+      'property:sample.wall.height': 'Height',
+      'property:sample.wall.finish.oiled': 'Oiled',
+    };
+    const Map<String, String> de = {
+      'type:sample.wall': 'Wand',
+      'tool:sample.wall': 'Wandwerkzeug',
+      'property:sample.wall.height': 'Höhe',
+      'property:sample.wall.finish.oiled': 'Geölt',
+    };
+    const Map<String, String> tr = {
+      'type:sample.wall': 'Duvar',
+      'tool:sample.wall': 'Duvar aracı',
+      'property:sample.wall.height': 'Yükseklik',
+      'property:sample.wall.finish.oiled': 'Yağlı',
+    };
+
+    /// The sample kit's words with the code side's added.
+    KitNames codeNames({
+      Map<String, String> english = en,
+      Map<String, String> german = de,
+      Map<String, String> turkish = tr,
+    }) =>
+        KitNames({
+          'en': english,
+          'de': {...sampleNames.words['de']!, ...german},
+          'tr': {...sampleNames.words['tr']!, ...turkish},
+        });
+
+    List<KitProblem> codeProblems({
+      KitNames? names,
+      List<String> types = const ['sample.wall'],
+      List<String> tools = const ['sample.wall'],
+      List<String> properties = const [
+        'sample.wall.height',
+        'sample.wall.finish.oiled',
+      ],
+      Map<String, Set<String>> sameAsEnglish = sampleSameAsEnglish,
+    }) =>
+        conformance(
+          catalog: sampleCatalog,
+          committedLibrary: committedLibrary(),
+          committedSnapshot: committedSnapshot(),
+          names: names ?? codeNames(),
+          locales: sampleLocales,
+          sameAsEnglish: sameAsEnglish,
+          typeIds: types,
+          toolIds: tools,
+          propertyIds: properties,
+        );
+
+    test('R3-1 a kit with types, tools and properties conforms', () {
+      // A positive control for R3-2 to R3-4.
+      expect(codeProblems(), isEmpty);
+    });
+
+    test('R3-2 an id that is not under the kit', () {
+      // M-R3a: drop the check. M-R3b: test `kitOfKey` only ('sample.Wall').
+      for (final id in ['other.wall', 'sample', 'sample.Wall']) {
+        final found = codeProblems(types: [id]);
+        expect(codes(found), [KitProblemCode.typeOutsideKit], reason: id);
+        expect(found.single.message, contains('"$id"'));
+        expect(
+            codes(codeProblems(tools: [id])), [KitProblemCode.toolOutsideKit],
+            reason: id);
+      }
+      // M-R3c: drop the property check. M-R3f: drop its dot test ('sample'
+      // is then under the kit).
+      for (final id in ['other.wall.height', 'height', 'sample']) {
+        expect(codes(codeProblems(properties: [id])),
+            [KitProblemCode.foreignWordId],
+            reason: id);
+      }
+    });
+
+    test('R3-3 a code-side word without English', () {
+      for (final id in en.keys) {
+        // M-R3d: drop the English check.
+        final found =
+            codeProblems(names: codeNames(english: {...en}..remove(id)));
+        expect(codes(found), [KitProblemCode.missingEnglish], reason: id);
+        expect(found.single.message, contains('"$id"'));
+      }
+    });
+
+    test('R3-4 a declared locale holds the code side to the same rule', () {
+      // M-R3e: leave the code words out of the declared-locale check.
+      final found = codeProblems(
+          names: codeNames(german: {...de}..remove('tool:sample.wall')));
+      expect(codes(found), [KitProblemCode.wordMissing]);
+      expect(found.single.message, contains('tool:sample.wall'));
+      final untranslated =
+          codeNames(turkish: {...tr, 'type:sample.wall': 'Wall'});
+      expect(codes(codeProblems(names: untranslated)),
+          [KitProblemCode.wordUntranslated]);
+      expect(
+          codeProblems(names: untranslated, sameAsEnglish: {
+            ...sampleSameAsEnglish,
+            'tr': {...sampleSameAsEnglish['tr']!, 'type:sample.wall'},
+          }),
+          isEmpty);
+    });
+
+    test('R3-5 without ids, the code side is not checked (additive)', () {
+      // A positive control: a kit calling conformance as before 2a, with
+      // code-side words, is held to nothing new.
+      expect(
+          conformance(
+            catalog: sampleCatalog,
+            committedLibrary: committedLibrary(),
+            committedSnapshot: committedSnapshot(),
+            names: codeNames(german: const {}),
+            locales: sampleLocales,
+            sameAsEnglish: sampleSameAsEnglish,
+          ),
+          isEmpty);
+    });
+  });
 }
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/conformance_test.dart`. Expected: a compilation error naming the undefined named parameter `typeIds`. Quote it.

- [ ] **Step 6: R3.** Apply to `lib/src/authoring/conformance.dart`:

```diff
--- a/packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart
+++ b/packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart
@@ -20,6 +20,13 @@ import 'snapshot.dart';
 /// [locales]. [sameAsEnglish] lists, per locale, the word ids whose right
 /// word is the English one. Empty when the kit conforms.
 ///
+/// The code side (contract R3): [typeIds], [toolIds] and [propertyIds] (a
+/// `PlanKit`'s `propertyIds`, without the `property:` prefix) must be under
+/// the kit's id, and each one's word (`type:<id>`, `tool:<id>`,
+/// `property:<id>`) must have English and a word in every declared locale.
+/// A code-side word that names none of them is not reported: a kit may pass
+/// a part of its ids.
+///
 /// Throws [ArgumentError] when [locales] lists English: English is always
 /// required, by stored text or by words.
 List<KitProblem> conformance({
@@ -29,6 +36,9 @@ List<KitProblem> conformance({
   required KitNames names,
   required List<String> locales,
   Map<String, Set<String>> sameAsEnglish = const {},
+  Iterable<String> typeIds = const [],
+  Iterable<String> toolIds = const [],
+  Iterable<String> propertyIds = const [],
 }) {
   if (locales.contains(KitNames.english)) {
     throw ArgumentError.value(locales, 'locales',
@@ -61,12 +71,42 @@ List<KitProblem> conformance({
     problems.add(KitProblem(KitProblemCode.libraryInvalid,
         'the committed library is refused, rule ${e.rule}: ${e.message}'));
   }
+  final code = _codeIds(catalog.kit, typeIds, toolIds, propertyIds);
   problems
     ..addAll(_snapshotProblems(catalog, committedSnapshot))
-    ..addAll(_wordProblems(catalog, names, locales, sameAsEnglish));
+    ..addAll(code.problems)
+    ..addAll(_wordProblems(catalog, names, locales, sameAsEnglish, code.words));
   return problems;
 }
 
+/// Contract R3: type and tool ids are `<kit>.<name>` (spec 2a P1), a
+/// property id is under the kit. The words of those that are.
+({List<KitProblem> problems, Set<String> words}) _codeIds(
+    String kit,
+    Iterable<String> typeIds,
+    Iterable<String> toolIds,
+    Iterable<String> propertyIds) {
+  final problems = <KitProblem>[];
+  final words = <String>{};
+  void check(String what, Iterable<String> ids, KitProblemCode outside,
+      bool Function(String) wellFormed) {
+    for (final id in ids) {
+      if (!wellFormed(id) || kitOfKey(id) != kit) {
+        problems.add(KitProblem(
+            outside, 'the $what id "$id" is not under the kit "$kit"'));
+      } else {
+        words.add('$what:$id');
+      }
+    }
+  }
+
+  check('type', typeIds, KitProblemCode.typeOutsideKit, isCodeId);
+  check('tool', toolIds, KitProblemCode.toolOutsideKit, isCodeId);
+  check('property', propertyIds, KitProblemCode.foreignWordId,
+      (id) => id.contains('.'));
+  return (problems: problems, words: words);
+}
+
 /// Checks 3 and 6, on the catalog itself: keys under the kit, lower case.
 List<KitProblem> _catalogProblems(Catalog catalog) {
   final problems = <KitProblem>[];
@@ -135,9 +175,14 @@ List<KitProblem> _snapshotProblems(Catalog catalog, String text) {
 }
 
 /// Check 5: every declared locale complete, no word the catalog lacks, no
-/// undeclared locale.
-List<KitProblem> _wordProblems(Catalog catalog, KitNames names,
-    List<String> locales, Map<String, Set<String>> sameAsEnglish) {
+/// undeclared locale; and R3: every code-side word in [codeWords] has
+/// English, and is then held to the declared locales like the others.
+List<KitProblem> _wordProblems(
+    Catalog catalog,
+    KitNames names,
+    List<String> locales,
+    Map<String, Set<String>> sameAsEnglish,
+    Set<String> codeWords) {
   // The English of each word id: a key's newest version's name, a
   // category's own text.
   final newest = <String, int>{};
@@ -168,6 +213,16 @@ List<KitProblem> _wordProblems(Catalog catalog, KitNames names,
       }
     }
   }
+  final stored = names.words[KitNames.english] ?? const <String, String>{};
+  for (final id in codeWords) {
+    final en = stored[id];
+    if (en == null) {
+      problems.add(KitProblem(
+          KitProblemCode.missingEnglish, '"$id" has no English word'));
+    } else {
+      english[id] = en;
+    }
+  }
   for (final locale in locales) {
     final words = names.words[locale] ?? const <String, String>{};
     final allowed = sameAsEnglish[locale] ?? const <String>{};
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring`. Expected: `All tests passed!`.

- [ ] **Step 7: R5, the example and its test.** Create `example/cafe_code.dart`:

```dart
// A kit's code side (docs/kits.md section 10): a parametric type, its
// property specs, its colour target and its descriptor. Analysed with the
// package; test/kit/example_code_test.dart runs it.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

enum SignFace { chalk, board }

/// A cafe's menu board: its width in millimetres, its face and its colour.
final class CafeSign implements Component {
  const CafeSign({required this.width, required this.face, this.swatch});

  static const String id = 'cafe.sign';

  final double width;
  final SignFace face;
  final String? swatch;

  CafeSign copyWith({double? width, SignFace? face}) => CafeSign(
      width: width ?? this.width, face: face ?? this.face, swatch: swatch);

  CafeSign withSwatch(String? swatch) =>
      CafeSign(width: width, face: face, swatch: swatch);

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() =>
      {'face': face.name, 'swatch': swatch, 'width': width};

  static CafeSign fromJson(Map<String, Object?> json) => CafeSign(
        width: (json['width']! as num).toDouble(),
        face: SignFace.values.byName(json['face']! as String),
        swatch: json['swatch'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is CafeSign &&
      other.width == width &&
      other.face == face &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(width, face, swatch);
}

/// The sign's geometry: a closed outline, its width by 80 mm, centred on
/// its group's origin.
final class CafeSignType extends ParametricType<CafeSign> {
  const CafeSignType();

  static List<Vector2> outline(CafeSign sign) => [
        Vector2(-sign.width / 2, -40),
        Vector2(sign.width / 2, -40),
        Vector2(sign.width / 2, 40),
        Vector2(-sign.width / 2, 40),
      ];

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(CafeSign params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final p in outline(params)) toWorld.transformPoint(p)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final sign = view.paramsOf<CafeSign>(self)!;
    return [
      Generated(
          EntityKind.polyline, polylinePayload(outline(sign), closed: true)),
    ];
  }
}

final List<PropertySpec<CafeSign>> signProperties = [
  LengthProperty<CafeSign>(
    id: 'width',
    read: (s) => s.width,
    write: (s, v) => s.copyWith(width: v),
    min: 300,
    max: 2400,
  ),
  ChoiceProperty<CafeSign, SignFace>(
    id: 'face',
    values: SignFace.values,
    read: (s) => s.face,
    write: (s, v) => s.copyWith(face: v),
  ),
  ValueDisplay<CafeSign>(
    id: 'area',
    read: (s) => s.width * 80,
    unit: ValueUnit.area,
  ),
];

final ColourTarget<CafeSign> signColour = ColourTarget<CafeSign>(
  read: (s) => s.swatch,
  write: (s, swatch) => s.withSwatch(swatch),
);

final PlanKit cafeCodeKit = PlanKit(
  id: 'cafe',
  version: '0.1.0',
  types: [
    PlanType<CafeSign>(
      id: CafeSign.id,
      fromJson: CafeSign.fromJson,
      parametric: const CafeSignType(),
      properties: signProperties,
      colour: signColour,
    ),
  ],
  names: cafeCodeNames,
);

const KitNames cafeCodeNames = KitNames({
  'en': {
    'type:cafe.sign': 'Menu board',
    'property:cafe.sign.width': 'Width',
    'property:cafe.sign.face': 'Face',
    'property:cafe.sign.face.chalk': 'Chalk',
    'property:cafe.sign.face.board': 'Board',
    'property:cafe.sign.area': 'Area',
  },
  'tr': {
    'type:cafe.sign': 'Menü panosu',
    'property:cafe.sign.width': 'Genişlik',
    'property:cafe.sign.face': 'Yüzey',
    'property:cafe.sign.face.chalk': 'Tebeşir',
    'property:cafe.sign.face.board': 'Pano',
    'property:cafe.sign.area': 'Alan',
  },
});
```

Create `test/kit/example_code_test.dart`:

```dart
// Spec 2a P6 (R5): the code side docs/kits.md shows is the example's, and it
// validates, registers, edits and regenerates.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../../example/cafe_code.dart';

void main() {
  test('R5-1 the documented code kit validates, edits and regenerates', () {
    expect(cafeCodeKit.validate(), isEmpty);
    expect(cafeCodeKit.propertyIds, [
      'cafe.sign.width',
      'cafe.sign.face',
      'cafe.sign.face.chalk',
      'cafe.sign.face.board',
      'cafe.sign.area',
    ]);
    final type = cafeCodeKit.types.single;
    final catalog = ParametricCatalog();
    type.registerInto(catalog);
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    ParametricSystem(doc, catalog).install();
    const sign = Handle(3100);
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: sign,
          parent: doc.rootHandle,
          transform: Transform2.translation(1820.5, 640.25)
              .multiply(Transform2.rotation(math.pi / 5)),
          children: const [])),
      SetComponentCommand<CafeSign>(
          sign, const CafeSign(width: 900, face: SignFace.chalk)),
    ], label: 'Add sign'));
    final width = type.fieldsOf(doc, sign).first;
    expect(width.value, 900.0);
    // M-R5: the example's `min: 300` lowered to 200.
    expect(() => type.commitField(doc, sign, width, 250), throwsArgumentError);
    doc.commands.execute(type.commitField(doc, sign, width, 1500));
    final outline = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == sign)
          doc.geometry.read(doc.entities.geomIndexAt(slot)).coords,
    ].single;
    expect(outline.sublist(0, 4), [-750.0, -40.0, 750.0, -40.0]);
    doc.commands.execute(type.recolour(doc, sign, 'ochre')!);
    expect(type.colourOf(doc, sign), 'ochre');
  });
}
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/kit/example_code_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 8: R5, `docs/kits.md`, the README and DOC1.** Apply to `docs/kits.md` (repository root):

````diff
--- a/docs/kits.md
+++ b/docs/kits.md
@@ -5,10 +5,11 @@ booths, a house's furniture, a cinema's seats. The plan library
 (`jet_cad_2d_plan`) knows no domain; it loads the kits a host gives it.
 Every kit and the plan library depend on one contract, `jet_cad_2d_kit`.
 
-This document is the kit author's contract. It covers the **symbol side**:
-symbols, their library, their words and their tests. Parametric types,
-tools, properties and attachment providers (the code side) are added by
-the plan library's sub-project and documented here then.
+This document is the kit author's contract. Sections 1 to 9 cover the
+**symbol side**: symbols, their library, their words and their tests.
+Section 10 covers the **code side**: parametric types, tools, property
+specs, colour targets and attachment providers, which the plan library
+composes.
 
 ## 1. Packages and dependencies
 
@@ -42,17 +43,17 @@ jet_cad_2d               the engine
 | Target kind, size family, unit kind | lower-case letters and digits joined by single hyphens | `wall-face`, `bed-double`, `table` |
 | Contract component | `jetcad.<name>` | `jetcad.symbol` |
 
-A kit's keys, types and tools all start with its own id. Today the
-conformance test (§8) refuses a key that does not; it checks type and tool
-ids when the code side arrives (the plan library's sub-project).
-`PlanKit.validate` (§6) already reports a word under another kit's id,
-`tool:` and `type:` words included.
+A kit's keys, types and tools all start with its own id. The conformance
+test (§8) refuses a key that does not, and, given the kit's type, tool and
+property ids, an id that does not. `PlanKit.validate` (§6) reports a type
+or tool id that is not `<kit id>.<name>` or is given twice, and a word
+under another kit's id, `tool:` and `type:` words included.
 
 ## 3. What a plan stores
 
 | Component | On | Fields |
 |---|---|---|
-| `jetcad.symbol` (`SymbolComponent`) | a symbol's definition | `key`, `version`, `name` (English), `category` (English), `tags` (search words only, lower case, no duplicates), `attachTo` (target kinds, empty for none), `family` (a size family or null) |
+| `jetcad.symbol` (`SymbolComponent`) | a symbol's definition | `key`, `version`, `name` (English), `category` (English), `tags` (search words only, lower case, no duplicates), `attachTo` (target kinds, empty for none), `family` (a size family or null), `retired` (true: the gallery no longer offers it) |
 | `jetcad.unit` (`UnitComponent`) | a service unit's definition | `kind` (`UnitKinds.table`, `UnitKinds.seat` or another kind), `capacity` (1 or more), `labelling` (`numbered`: the plan numbers it; `assigned`: a kit's type labels it) |
 | `jetcad.library` (`LibraryComponent`) | a library's root | `kit`, `format` (1) |
 | `jetcad.manifest` (`ManifestComponent`) | a plan's root | `format` (1), `kits` (kit id → the version that last saved the plan) |
@@ -61,6 +62,11 @@ Every component refuses a bad value in its constructor (an
 `ArgumentError`) and writes its JSON keys in alphabetical order.
 `registerKitComponents(registry)` registers the four and nothing else.
 
+A field added after a component was first written is optional when read,
+so what was saved before it still reads. `retired` is one: it is written
+only when true and read as false when absent, so a library or a plan
+without a retired symbol keeps its bytes.
+
 Behaviour is in fields, never in tags: a symbol that stands against a wall
 says `attachTo: ['wall-face']`; a symbol in a size family says
 `family: 'bed-double'`.
@@ -86,9 +92,10 @@ each definition's leaves. `SymbolLibrary.decode(bytes)` refuses, with a
 9. a unit in a size family;
 10. a unit component off a symbol's definition;
 11. a unit whose first leaf is not closed (a closed polyline or a circle),
-    or is a closed polyline enclosing no more area than the engine's
-    tolerance squared: a unit's first leaf is its outline, which service
-    mode fills;
+    or is a closed polyline no wider than the engine's tolerance, its
+    width being 2·area/perimeter (a 600 mm sliver 1e-9 mm wide is
+    refused, a 600 mm by 1 mm bar is not): a unit's first leaf is its
+    outline, which service mode fills;
 12. a non-finite base point;
 13. a leaf owned by anything but a definition; a text, fill, attribute or
     point leaf;
@@ -111,7 +118,10 @@ a word id to the word.
 |---|---|
 | `symbol:<key>` | a symbol's name (all versions of the key) |
 | `category:<kit id>/<English category>` | a category, under the kit's id: two kits may both have a `Bar` |
-| `tool:<tool id>`, `type:<type id>`, `property:<type id>.<property>` | the code side's words |
+| `type:<type id>` | a type's name: its panel section's title (§10.2) |
+| `tool:<tool id>` | a tool's name in the palette (§10.5) |
+| `property:<type or tool id>.<property id>` | a field of a type, or of a tool's settings (§10.3) |
+| `property:<type or tool id>.<property id>.<value>` | a choice's value: an enum's name, else the value's text |
 
 Every word id carries its kit's id, so two kits never share one;
 `PlanKit.validate` reports a word under another kit's id. Lookup
@@ -153,6 +163,13 @@ version, a word under another kit's id, a word in no known namespace, a
 code-side word without English. A source's `read` is a call, so a kit's
 descriptor is `final`, not `const`.
 
+The code side (§10) adds `types`, `tools` and `attachments`. `validate()`
+then also lists a type or tool id that is not `<kit id>.<name>`
+(`typeOutsideKit`, `toolOutsideKit`), one given twice (`duplicateType`,
+`duplicateTool`), and every word a type, tool or property needs that has
+no English (`missingEnglish`). `propertyIds` lists the kit's property ids,
+choice values included, for the conformance test.
+
 ## 7. The authoring toolkit
 
 `package:jet_cad_2d_kit/authoring.dart`:
@@ -214,10 +231,12 @@ void main() {
 
 - **A published `key@N` never changes its geometry or its unit.** A change
   of either is a new `key@N+1`, beside the old one. A key is never removed
-  and never reused: a retired symbol stays in the library. Taking a retired
-  symbol out of the gallery is the plan library's sub-project: the contract
-  has no retired mark yet. A plan never needs a library to draw: it copies
-  every placed symbol's definition.
+  and never reused: a retired symbol stays in the library, marked
+  `retired: true` in its catalog entry (`CatalogSymbol.retired`). The
+  gallery stops offering it; a plan that holds it keeps drawing it. A plan
+  never needs a library to draw: it copies every placed symbol's
+  definition. Retiring changes no geometry, so the snapshot does not
+  change; the library does, so run the generator.
 - **Names, categories, words and tags may change at any version**; they are
   not geometry.
 - **Semver at 0.x:** a new symbol, a new `@N`, words or tags is a patch; a
@@ -258,6 +277,14 @@ new one the snapshot lacks; a declared locale missing a word, or giving the
 English word unless `sameAsEnglish` allows it; a word for a key or category
 the catalog lacks; a locale with words that is not declared.
 
+A kit with a code side also passes its ids: `typeIds:` (`[for (final t in
+kit.types) t.id]`), `toolIds:` (`[for (final t in kit.tools) t.id]`) and
+`propertyIds:` (`kit.propertyIds`). Each id must be under the kit's id
+(`typeOutsideKit`, `toolOutsideKit`, and `foreignWordId` for a property),
+its word must have English (`missingEnglish`), and every declared locale
+holds it like a symbol's word (`wordMissing`, `wordUntranslated`). Without
+them, the code side is not checked.
+
 ## 9. A new kit, the symbol part
 
 1. A package `packages/jet_cad_2d_kit_<id>` depending on `jet_cad_2d_kit`
@@ -273,5 +300,207 @@ the catalog lacks; a locale with words that is not declared.
    `kit.validate()` is empty: a word under another kit's id or in no known
    namespace, and a `tool:`, `type:` or `property:` word without English,
    are caught only there.
-7. Its CI line, a demo and its README pictures (the plan library's
+7. Its code side, if it has one (§10): its types and tools under its id,
+   their words in English and in every declared locale, its ids passed to
+   the conformance test.
+8. Its CI line, a demo and its README pictures (the plan library's
    sub-projects describe these).
+
+## 10. The code side
+
+A kit contributes the engine's own types and the Flutter layer's own tools,
+each wrapped in a contract descriptor. The plan library composes them: it
+registers the types, arms the tools, shows the fields, and calls every hook
+through a guard. A kit never registers into the engine itself.
+
+The snippets of this section are `example/cafe_code.dart`'s: a cafe's menu
+board, `CafeSign`, a component with a width, a face and a colour, drawn by
+`CafeSignType`, the engine's `ParametricType<CafeSign>`.
+
+### 10.1 The descriptor
+
+```dart
+final PlanKit cafeCodeKit = PlanKit(
+  id: 'cafe',
+  version: '0.1.0',
+  types: [
+    PlanType<CafeSign>(
+      id: CafeSign.id,
+      fromJson: CafeSign.fromJson,
+      parametric: const CafeSignType(),
+      properties: signProperties,
+      colour: signColour,
+    ),
+  ],
+  names: cafeCodeNames,
+);
+```
+
+`PlanKit` carries `types` (`PlanType`), `tools` (`PlanTool`) and
+`attachments` (factories of `AttachmentProvider`) beside its symbols and
+words. Its factories (a tool's `create`, a type's `grips`, the
+`attachments`) run **once per document**: when the plan is replaced
+(`load`, `newPlan`, an import), the plan library disposes what they made
+and runs them again, so nothing a kit holds outlives its document.
+
+### 10.2 A parametric type
+
+| `PlanType` field | What it is |
+|---|---|
+| `id` | `<kit id>.<name>`, equal to the component's `typeId`: a plan's manifest finds its kits by it |
+| `fromJson` | the component's factory |
+| `parametric` | the engine's `ParametricType<T>`: `reach`, `generate`, `references`, the place hooks |
+| `grips` | `ObjectGripProvider Function(PlanServices)?`: the Flutter layer's grips for its objects |
+| `properties` | the panel's fields (§10.3) |
+| `section` | the escape hatch: `(context, value, commit, words) => Widget`, for what specs cannot say; `commit(T)` is one undo step |
+| `title` | a word id for the section's title, from the value; default `type:<id>` |
+| `colour` | a `ColourTarget` (§10.4) |
+| `exported` | false leaves the type's objects out of every export |
+
+**Covariance.** The plan library holds every type as `PlanType<Component>`.
+A member whose type takes a `T` (a section builder, a spec's `read`) fails
+Dart's runtime type check when read through that supertype, and
+`register` would infer `T = Component`. So `PlanType` keeps those members
+private and offers erased operations that run over its own `T`:
+`registerInto`, `fieldsOf`, `commitField`, `titleWordOf`, `colourOf`,
+`recolour`, `sectionFor`, `gripsFor`. The plan library calls only these. A
+kit calls none of them, and never reads a spec's `read`, `write` or
+`enabled` through a supertype either.
+
+### 10.3 Property specs
+
+```dart
+final List<PropertySpec<CafeSign>> signProperties = [
+  LengthProperty<CafeSign>(
+    id: 'width',
+    read: (s) => s.width,
+    write: (s, v) => s.copyWith(width: v),
+    min: 300,
+    max: 2400,
+  ),
+  ChoiceProperty<CafeSign, SignFace>(
+    id: 'face',
+    values: SignFace.values,
+    read: (s) => s.face,
+    write: (s, v) => s.copyWith(face: v),
+  ),
+  ValueDisplay<CafeSign>(
+    id: 'area',
+    read: (s) => s.width * 80,
+    unit: ValueUnit.area,
+  ),
+];
+
+final ColourTarget<CafeSign> signColour = ColourTarget<CafeSign>(
+  read: (s) => s.swatch,
+  write: (s, swatch) => s.withSwatch(swatch),
+);
+```
+
+| Kind | Holds | The panel |
+|---|---|---|
+| `LengthProperty` | `read`, `write`, `min`, `max` | millimetres, with the plan's decimal separator |
+| `AngleProperty` | `read`, `write` | radians stored, degrees shown |
+| `NumberProperty` | `read`, `write`, `min`, `max`, `decimals` (0 to 10) | rounded to `decimals` on commit |
+| `ChoiceProperty<T, V>` | `values`, `read`, `write` | one of `values`, compared with `==` |
+| `ToggleProperty` | `read`, `write` | a switch |
+| `TextProperty` | `read`, `write`, `maxLength` (code points) | a text field |
+| `ValueDisplay` | `read`, `unit` (`length`, `area`, `angle`, `none`) | read-only: a room's area |
+| `ActionProperty` | `apply` | a button: a door's Flip hinge |
+
+- Every spec has an `id` (a lower-case letter, then lower-case letters,
+  digits and hyphens), an optional `enabled(T)` that greys the field out,
+  and an optional `gate`, the `PlanGate` permission it needs.
+- `write` and `apply` return a changed copy; the plan library commits it
+  as one `SetComponentCommand<T>`, the parametric system regenerates, and
+  the edit is one undo step.
+- Out of range, not finite, not one of the values, too long: the input is
+  refused and the field shows its stored value again. A bad `min`, `max`,
+  `decimals`, `maxLength`, `values` or `id` is an `ArgumentError` when the
+  spec is made.
+- Words: `property:<type id>.<id>`, a choice's values
+  `property:<type id>.<id>.<value>`.
+
+### 10.4 Colour
+
+A `ColourTarget` reads a component's swatch, a name from the plan's palette,
+and writes a copy with another (null clears it). The panel's colour row
+recolours every selected object whose type has one, of any kit, in one
+command; the `recolor` permission gates it.
+
+### 10.5 Tools
+
+| `PlanTool` field | What it is |
+|---|---|
+| `id` | `<kit id>.<name>`; its word is `tool:<id>` |
+| `icon` | the palette's icon |
+| `letter` | a suggested shortcut. The plan library's tools keep V, L, P, R, C, A and T; F is reserved; kits' letters follow in load order, and a letter already taken goes to no later tool (a `letterTaken` diagnostic) |
+| `needs` | the `Capability`s its commits need; the palette disables it where the document's permissions deny one |
+| `settings` | `PlanToolSettings<S>(initial: ..., specs: [...])`: one `S` per tool, edited in the panel with the same specs while the tool is active (words `property:<tool id>.<id>`), read by the tool through `PlanServices.settingsOf` |
+| `create` | `Tool Function(PlanServices)`: the Flutter layer's `Tool` |
+
+### 10.6 The services
+
+`PlanServices` is a live view of one plan, one per kit:
+
+| Member | |
+|---|---|
+| `document`, `index`, `camera` | the current document, its spatial index, the camera (apertures in world units) |
+| `objectSnap` | the effective object-snap flag: F3 and the editor's snapping |
+| `attachments` | every loaded kit's attachment providers (§10.7) |
+| `words` | `KitWords`: this kit's words at the plan's locale, falling back to English, read live |
+| `settingsOf<S>(toolId)` | a tool's current settings |
+| `shared<T>(create)` | one `T` per kit and document, made on first use: what a kit's tools, grips and providers share (a wall's bands). A `T` that implements `Disposable` is disposed with its document |
+
+### 10.7 Attachment
+
+An `AttachmentProvider` offers one target kind (`wall-face`). Asked with an
+`AttachmentQuery` (the symbol's footprint and transform, the pointer, the
+capture distances, whether it is mirrored, whether it may rotate, what to
+exclude, the previous answer), it answers an `Attachment` (where the symbol
+goes, where the plan library draws its marker, a token of its own) or null.
+The plan library asks the providers of every kind in a symbol's `attachTo`
+and keeps the answer whose marker is nearest the pointer. Under
+`rotate: false`, a provider offers only targets the symbol's current turn
+already fits.
+
+### 10.8 When a kit's code fails
+
+Every hook is called through a guard. A failure never stops the plan; it
+becomes a `KitDiagnostic` (kit, subject, `KitDiagnosticCode`, message),
+once per subject and code:
+
+| What throws | What happens |
+|---|---|
+| a `ParametricType` hook | the edit is rolled back; the type's objects are probed, and each one whose hooks throw is frozen (treated as a plain group) and locked; the edit is tried once more. One broken object blocks one edit, once |
+| a component's `fromJson`, on load | the component is kept as stored, and its object is locked |
+| grips, an attachment provider | none for that object; no attachment |
+| a tool's `create` | the tool is disabled |
+| a tool's event or painting | the tool is cancelled and selection is armed |
+| a spec's `write` or `apply` | the field shows its stored value |
+| a section | a small "section failed" box in its place |
+
+A plan that names a kit the host did not load opens: that kit's objects
+draw, are locked, and are saved back unchanged (`kitMissing`). A plan saved
+by a newer version of a loaded kit opens with a warning (`kitNewer`).
+
+### 10.9 The engine's types, and byte equality
+
+**The engine's types bind the contract.** A `PlanType` takes the engine's
+`ParametricType<T>` and `Component`; a tool commits the engine's
+`DraftCommand`s to its `DraftDocument`; a library's `SymbolLeaf` exposes
+`EntityRecord` and `GeometryPayload`, a `SymbolEntry` its `Definition`.
+Wrapping them in contract types would rewrite the parametric and grip
+layers, so the contract uses them as they are. A breaking change of one of
+them in `jet_cad_2d` 0.x is a breaking change of the contract and of every
+kit that uses it.
+
+**Byte equality ties a kit's CI to the codec.** The conformance test
+compares the committed `.jetlib` with `encodeLibrary(catalog)` byte for
+byte, and those bytes are the engine codec's `encodeToString`. An engine
+release that changes that output (a key order, a number's spelling, a new
+field) turns every kit's conformance test red with `builtDiffers` until the
+kit runs its generator again. That is a regeneration, not a change of
+geometry: the snapshot is unaffected and every published `key@N` keeps its
+shapes. A kit that raises its `jet_cad_2d` constraint runs its generator
+and commits the new library in the same change.
````

Apply to `README.md` (its one ```` ```dart ```` block is unchanged):

```diff
--- a/packages/jet_cad_2d_kit/README.md
+++ b/packages/jet_cad_2d_kit/README.md
@@ -1,17 +1,19 @@
 # jet_cad_2d_kit
 
 The kit contract of jet_cad_2d plans. A kit — restaurant, architecture,
-cinema — ships its symbols (and, later, its parametric types and tools) on
-this contract, and the plan library loads any kit without knowing its
-domain. No kit depends on the plan library, and no kit depends on another.
+cinema — ships its symbols, its parametric types and its tools on this
+contract, and the plan library loads any kit without knowing its domain.
+No kit depends on the plan library, and no kit depends on another.
 
 Two libraries:
 
 - `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, the contract (Flutter): the
   components a plan stores (`jetcad.symbol`, `jetcad.unit`,
   `jetcad.manifest`, `jetcad.library`), the `.jetlib` library format and its
-  validator, `KitNames`, `SymbolLibrarySource`, `bundledLibrary` and the
-  `PlanKit` descriptor.
+  validator, `KitNames`, `SymbolLibrarySource`, `bundledLibrary`, the code
+  side (`PlanType`, `PlanTool`, the property specs, `ColourTarget`,
+  attachment providers, `PlanServices`, `KitDiagnostic`) and the `PlanKit`
+  descriptor.
 - `package:jet_cad_2d_kit/authoring.dart`, the authoring toolkit (pure Dart,
   runs under `dart run`): the catalog language, the library builder, shape
   helpers, the geometry snapshot and the conformance test.
@@ -42,5 +44,5 @@ is the built one, every published `key@N` keeps its geometry, and every
 declared locale is complete.
 
 The kit author's contract — naming, components, the format's rules, words,
-versions and the new-kit checklist — is
+versions, the new-kit checklist and the code side — is
 [docs/kits.md](https://github.com/a-urel/jet-cad/blob/main/docs/kits.md).
```

In `test/invariants/doc_snippets_test.dart`, the document has two more blocks:

````diff
--- a/packages/jet_cad_2d_kit/test/invariants/doc_snippets_test.dart
+++ b/packages/jet_cad_2d_kit/test/invariants/doc_snippets_test.dart
@@ -53,7 +53,7 @@ void main() {
 
   // The number of blocks pins the parser to the documents: a parser that
   // finds no block would pass every check below vacuously.
-  for (final (doc, count) in [('../../docs/kits.md', 4), ('README.md', 1)]) {
+  for (final (doc, count) in [('../../docs/kits.md', 6), ('README.md', 1)]) {
     test('DOC1 every ```dart block of $doc is verbatim in example/', () {
       final blocks = dartBlocks(File(doc).readAsStringSync());
       expect(blocks, hasLength(count));
````

Run: `cd packages/jet_cad_2d_kit && flutter test test/invariants`. Expected: `All tests passed!` (DOC1 finds 6 blocks in `docs/kits.md`, each verbatim in `example/cafe_code.dart`, `cafe_kit.dart`, `example.dart`, `generate_cafe.dart` or `cafe_conformance_test.dart`).

- [ ] **Step 9: The CHANGELOG.** Append to the `## 0.1.0` list of `CHANGELOG.md`:

```markdown
- `retired` on `jetcad.symbol` and `CatalogSymbol`, written only when true;
  `conformance` takes `typeIds`, `toolIds` and `propertyIds`; rule 11
  refuses a unit outline by its width, 2·area/perimeter, not by its area.
```

- [ ] **Step 10: The gate.** Run, one at a time: `cd packages/jet_cad_2d_kit && dart format .`, then `flutter test`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`. All exit 0; quote `flutter test`'s last line. Then `cd packages/jet_cad_2d_kit && dart run example/example.dart` still prints its one line, and `git status --short` shows only this task's files.

- [ ] **Step 11: Commit.**

```bash
git add docs/kits.md packages/jet_cad_2d_kit/README.md packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_kit/example/cafe_code.dart packages/jet_cad_2d_kit/lib/src/model/json_fields.dart packages/jet_cad_2d_kit/lib/src/model/symbol_component.dart packages/jet_cad_2d_kit/lib/src/model/symbol_library.dart packages/jet_cad_2d_kit/lib/src/authoring/catalog.dart packages/jet_cad_2d_kit/lib/src/authoring/builder.dart packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart packages/jet_cad_2d_kit/test/kit/example_code_test.dart packages/jet_cad_2d_kit/test/model/symbol_component_test.dart packages/jet_cad_2d_kit/test/model/symbol_library_test.dart packages/jet_cad_2d_kit/test/authoring/builder_test.dart packages/jet_cad_2d_kit/test/authoring/snapshot_test.dart packages/jet_cad_2d_kit/test/authoring/conformance_test.dart packages/jet_cad_2d_kit/test/invariants/doc_snippets_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): retired symbols, code-side conformance, rule 11 by width (R2, R3, R5, R7)

jetcad.symbol and CatalogSymbol gain retired, written only when true and
read as false when absent, so existing libraries and plans keep their
bytes. conformance checks a kit's type, tool and property ids and their
words when given them. Rule 11 refuses an outline whose width,
2*area/perimeter, is at or under the tolerance, so a long sliver no longer
loads. docs/kits.md documents the code side, why the engine's types bind
the contract and what the codec's byte equality means for a kit's CI,
from an analysed and tested example.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check.** On the committed files only, as in Task 3. Every one below was seen red against this code before the task was written. R3-1, R3-5, R7-4 and the R2-7 `builtDiffers` premise are positive controls, exempt. Under M-R7a, `_perimeter` is unused: an analyzer warning, not a compile error, so the test runs.

- **M-R2a** (`lib/src/model/symbol_component.dart`). Replace

  ```dart
  if (retired) 'retired': true,
  ```

  with

  ```dart
  'retired': retired,
  ```

  Run `flutter test test/model/symbol_component_test.dart --plain-name 'R2-1 '`: red.

- **M-R2a(C7)** (`lib/src/model/symbol_component.dart`). Replace

  ```dart
  if (retired) 'retired': true,
  ```

  with

  ```dart
  'retired': retired,
  ```

  Run `flutter test test/model/symbol_component_test.dart --plain-name 'C7 '`: red.

- **M-R2a(F0)** (`lib/src/model/symbol_component.dart`). Replace

  ```dart
  if (retired) 'retired': true,
  ```

  with

  ```dart
  'retired': retired,
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'F0 '`: red.

- **M-R2b** (`lib/src/model/symbol_component.dart`). Replace

  ```dart
  optionalField<bool>(json, 'retired', t, false)
  ```

  with

  ```dart
  field<bool>(json, 'retired', t)
  ```

  Run `flutter test test/model/symbol_component_test.dart --plain-name 'R2-2 '`: red.

- **M-R2c** (`lib/src/model/symbol_component.dart`). Replace

  ```dart
  optionalField<bool>(json, 'retired', t, false)
  ```

  with

  ```dart
  json['retired'] == true
  ```

  Run `flutter test test/model/symbol_component_test.dart --plain-name 'R2-2 '`: red.

- **M-R2d** (`lib/src/model/symbol_component.dart`). Replace

  ```dart
        other.family == family &&
        other.retired == retired;
  ```

  with

  ```dart
        other.family == family;
  ```

  Run `flutter test test/model/symbol_component_test.dart --plain-name 'R2-3 '`: red.

- **M-R2e** (`lib/src/authoring/builder.dart`). Replace

  ```dart
          retired: s.retired,
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/authoring/builder_test.dart --plain-name 'R2-5 '`: red.

- **M-R2f** (`lib/src/authoring/snapshot.dart`). Replace

  ```dart
        'base': _point(s.base),
  ```

  with

  ```dart
        'base': _point(s.base),
        'retired': s.retired,
  ```

  Run `flutter test test/authoring/snapshot_test.dart --plain-name 'R2-6 '`: red.

- **M-R2f(R2-7)** (`lib/src/authoring/snapshot.dart`). Replace

  ```dart
        'base': _point(s.base),
  ```

  with

  ```dart
        'base': _point(s.base),
        'retired': s.retired,
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R2-7 '`: red.

- **M-R3a** (`lib/src/authoring/conformance.dart`). Replace

  ```dart
  if (!wellFormed(id) || kitOfKey(id) != kit) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R3-2 '`: red.

- **M-R3b** (`lib/src/authoring/conformance.dart`). Replace

  ```dart
  if (!wellFormed(id) || kitOfKey(id) != kit) {
  ```

  with

  ```dart
  if (kitOfKey(id) != kit) {
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R3-2 '`: red.

- **M-R3c** (`lib/src/authoring/conformance.dart`). Replace

  ```dart
    check('property', propertyIds, KitProblemCode.foreignWordId,
        (id) => id.contains('.'));
  ```

  with

  ```dart
    words.addAll([for (final id in propertyIds) 'property:$id']);
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R3-2 '`: red.

- **M-R3f** (`lib/src/authoring/conformance.dart`). Replace

  ```dart
        (id) => id.contains('.'));
  ```

  with

  ```dart
        (id) => true);
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R3-2 '`: red.

- **M-R3d** (`lib/src/authoring/conformance.dart`). Replace

  ```dart
        problems.add(KitProblem(
            KitProblemCode.missingEnglish, '"$id" has no English word'));
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R3-3 '`: red.

- **M-R3e** (`lib/src/authoring/conformance.dart`). Replace

  ```dart
        english[id] = en;
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/authoring/conformance_test.dart --plain-name 'R3-4 '`: red.

- **M-R7a** (`lib/src/model/symbol_library.dart`). Replace

  ```dart
            final width =
                2 * _enclosedArea(first.payload) / _perimeter(first.payload);
            if (width <= Tolerance.standard.linear) {
  ```

  with

  ```dart
            final width = _enclosedArea(first.payload);
            if (width <= Tolerance.standard.linear * Tolerance.standard.linear) {
  ```

  Run `flutter test test/model/symbol_library_test.dart --plain-name 'R7-1 '`: red.

- **M-R7a(R7-2)** (`lib/src/model/symbol_library.dart`). Replace

  ```dart
            final width =
                2 * _enclosedArea(first.payload) / _perimeter(first.payload);
            if (width <= Tolerance.standard.linear) {
  ```

  with

  ```dart
            final width = _enclosedArea(first.payload);
            if (width <= Tolerance.standard.linear * Tolerance.standard.linear) {
  ```

  Run `flutter test test/model/symbol_library_test.dart --plain-name 'R7-2 '`: red.

- **M-R7c** (`lib/src/model/symbol_library.dart`). Replace

  ```dart
  2 * _enclosedArea(first.payload) / _perimeter(first.payload);
  ```

  with

  ```dart
  _enclosedArea(first.payload) / _perimeter(first.payload);
  ```

  Run `flutter test test/model/symbol_library_test.dart --plain-name 'R7-3 '`: red.

- **M-V11c** (`lib/src/model/symbol_library.dart`). Replace

  ```dart
            if (width <= Tolerance.standard.linear) {
  ```

  with

  ```dart
            if (false) {
  ```

  Run `flutter test test/model/symbol_library_test.dart --plain-name 'V11c '`: red.

- **M-R5** (`example/cafe_code.dart`). Replace

  ```dart
      min: 300,
      max: 2400,
  ```

  with

  ```dart
      min: 200,
      max: 2400,
  ```

  Run `flutter test test/kit/example_code_test.dart --plain-name 'R5-1 '`: red.

- **M-DOC1(R5)** (`example/cafe_code.dart`). Replace

  ```dart
      min: 300,
      max: 2400,
  ```

  with

  ```dart
      min: 200,
      max: 2400,
  ```

  Run `flutter test test/invariants/doc_snippets_test.dart --plain-name 'DOC1 '`: red.

---

