# Pre-flight conflict scan: plan 2026-10-13-kit-contract (12 tasks)

Read-only scan of `docs/superpowers/plans/2026-10-13-kit-contract.md` (6376 lines, at `c9c6929`)
against the spec `2026-10-13-kit-contract-design.md` (K1-K9 and "Amendments while planning"), the
umbrella `2026-10-13-kit-architecture-design.md`, the engine `packages/jet_cad_2d/lib` (0.7.2), the
existing `tool/ci` package and `.github/workflows/ci.yml`. Line numbers ("L") are plan lines.

## 1. Task pairs sharing a file or an interface

| Pair | Producer gives | Consumer uses | Verdict |
|---|---|---|---|
| T1-T2 | T1: empty barrels `lib/jet_cad_2d_kit.dart`, `lib/authoring.dart` (L182-201); P1 walks `lib/authoring.dart` + `lib/src/model/**` (L313-324) | T2 adds `export 'src/model/model.dart';` to both (L1142-1147); model files import only `package:jet_cad_2d`, `package:meta`, local | consistent |
| T1-T3 | P1 allow-list (L215-225) | `manifest_component.dart` imports `dart:collection`; `register.dart` is reached through `model.dart` `show` export | consistent (the walker reads the URI before `show`) |
| T1-T4 | P1 allow-list | `symbol_library.dart` imports `dart:async`, `dart:convert`, `dart:typed_data` (L2523-2525) | consistent |
| T1-T5 | P1 | `kit_names.dart`, `kit_problem.dart` import `package:meta` + local | consistent |
| T1-T6 | `lib/jet_cad_2d_kit.dart` barrel | T6 replaces its export list (L3673-3678); `lib/src/kit/` is reached from neither P1 entry (L3684) | consistent |
| T1-T7/T8/T9 | `lib/authoring.dart` barrel; P1 requires every `lib/src/authoring/*.dart` reached (L321-323) | T7 exports builder+catalog (L4173), T8 adds shapes (L4487), T9 adds snapshot (L4749) then conformance (L5428); each file exported in the same task that creates it | consistent; M-P1 on `builder.dart` (L4181) valid |
| T1-T10 | `README.md`, `CHANGELOG.md` created (L164-180) | replaced wholesale (L5571-5636) | consistent |
| T1-T11 | `packages/jet_cad_2d_kit/pubspec.yaml` exists from T1 | D9 / Step 5 expect "1 package(s) checked" (L6271) | consistent. **But** the existing `tool/ci/test/scripts_test.dart` SC16 ("every live package is in the CI matrix") lists every `packages/*` with a pubspec: red from T1's commit until T11 Step 7 adds the matrix entry; no task before T11 runs `tool/ci` (Finding 3) |
| T1-T12 | `analysis_options.yaml` committed once (L25, L394) | T12 Step 1 grep expects only that path (L6326); LICENSE `cmp` (L162, L6337) | consistent |
| T2-T3 | `field<T>`, `stringList`, `isKitId` (L423, L830, L858-878); `model.dart` (L1137-1139) | `LibraryComponent.fromJson`, `ManifestComponent.fromJson` (L1497-1578); `model.dart` rewritten (L1660-1665) keeping T2's three lines | consistent |
| T2-T4 | Constructor `ArgumentError.value(_, '<field>', _)` names `key`, `version`, `name`, `category`, `tags`, `attachTo`, `family`, `kind`, `capacity`; `FormatException` from `field()` | `_ruleOf` maps `key`→5, `tags/attachTo/family`→8, unit `kind`→8, library→2, else→1 (L2646-2653); V1c-V1f, V5b-e, V8a-g expect exactly these | consistent |
| T2-T5 | `SymbolComponent.key/name/category` | `KitNames.symbolName` (L3221) | consistent |
| T2-T6 | `isKitId`, `kitOfKey` | `PlanKit.validate` (L3630, L3653) | consistent |
| T2-T7 | `SymbolComponent(...)`, `UnitComponent(kind:, capacity:, labelling:)`, `UnitLabelling`, `UnitKinds` | builder (L4088-4108), `CatalogUnit` default `UnitLabelling.numbered` (L3991) | consistent |
| T2-T9 | `kitOfKey`, `UnitKinds`, `UnitLabelling` | conformance L5319; sample kit L4772-4800 | consistent |
| T3-T4 | `registerKitComponentsWrapped(ComponentRegistry, ComponentRead)`, `typedef ComponentRead = T Function<T extends Component>(String, Map<String,Object?>, T Function(Map<String,Object?>))` (L1620-1650), not exported (L1663 `show`) | `decode` passes generic static `_guarded<T extends Component>` (L2611-2612, L2630); imports `register.dart` directly (L2531) | consistent |
| T3-T7 | `registerKitComponents`, `LibraryComponent(kit:)` | builder L4073-4077 | consistent |
| T3-T6 docs | `ManifestComponent` | not consumed in this plan (sub-project 2) | consistent (defined and tested only, per K2) |
| T4-T5 | `SymbolLibrary._(List<String> kits, List<SymbolEntry>)` private ctor, `SymbolEntry.id`, `categories` (L2575-2599) | `merge` added inside the class (L3157-3177); merge_test uses `bytesOf`, `buildValidLibrary` | consistent |
| T4-T6 | `test/support/library_fixtures.dart` `buildValidLibrary`, `bytesOf` | S6 (L3432-3442) | consistent (but see Finding 1: the test file itself does not compile) |
| T4-T7 | `SymbolLibrary.decode`, `SymbolLibraryError.rule` | `encodeLibrary` decodes its own bytes (L4144); B5 expects rule 6 (duplicate `key@version`), 11 (open unit), 15 (zero radius) | consistent: engine `AddDefinitionCommand.apply` checks handles only, not names (commands.dart:533-545), so two `table@2` definitions build and reach rule 6 |
| T4-T9 | `SymbolLibraryError.toString()` = `SymbolLibraryError (rule N): ...` (L2548) | conformance wraps `$e` (L5272); F16 expects message to contain `rule 6` (L5184) | consistent |
| T4-T10 | `decode` | example and E1 | consistent |
| T5-T6 | `KitNames.words/english/empty`, `KitProblem`, `KitProblemCode.{badKitId, emptyVersion, foreignWordId, unknownWordId, missingEnglish}` (L3248-3254) | `PlanKit` (L3613, L3631-3662) | consistent |
| T5-T9 | `KitNames.symbolWord/categoryWord/word/english`, the 14 conformance codes | `conformance` (L5261-5423); M-F11 uses `names.word` (L5449) | consistent; every `KitProblemCode` value is produced somewhere |
| T5-T10 | `KitNames.symbolName` | example L5563 | consistent |
| T6-T10 | `PlanKit`, `SymbolLibrarySource`, `bundledLibrary` | docs/kits.md §6 (L5759-5770), `final` not `const` per amendment 6 | consistent |
| T6-T12 | `bundled_library.dart` header comment names `jet_cad_2d_kit_restaurant` (L3577-3580) | T12 Step 6 grep expects it as the only hit, calls it a "doc comment" (L6343) | consistent (it is a `//` comment; wording only) |
| T7-T8 | `CatalogPoint`, sealed `CatalogShape`, `CatalogLine/Polyline/Circle`, positional ctors (L3947-3984) | `shapes.dart` (L4389-4482) | consistent |
| T7-T9 | `Catalog`, `CatalogSymbol.id`, `encodeLibrary`, `CatalogUnit` fields | snapshot `_entry` (L4672-4683), conformance, sample kit | consistent |
| T7-T10 | `Catalog`, `CatalogSymbol`, `encodeLibrary` | example | consistent |
| T8-T9 | `chairAt`, `chairsAround`, `stoolAt`, `rect`, `inset` | sample kit (L4766-4822) | consistent |
| T8-T10 | `chairsAround`, `cleanCoordinate`, constants | example L5546; docs §7 (L5803-5807) | consistent |
| T9-T10 | `conformance({catalog, committedLibrary, committedSnapshot, names, locales, sameAsEnglish})`, `encodeSnapshot`, `geometrySnapshot`, `parseSnapshot`, `updateSnapshot` | E1 (L5513-5520) consistent; docs/kits.md §7-§8 call `cafeCatalog` (L5816, L5822, L5845), a name neither the example nor the README defines (the example has `buildCafeCatalog()`) | **mismatch** (Finding 7) |
| T9-T12 | sample kit generator, committed `.jetlib` + snapshot | T12 Step 6 regenerate + `cmp` (L6344) | consistent (copy-aside method, Finding 10) |
| T10-T11 | docs say `tool/ci/check_kit_deps.dart` fails CI (L5666) | T11 creates it | consistent |
| T10-T12 | `example/example.dart`, README, CHANGELOG | dry-run file list (L6337) | consistent |
| T11-T12 | script prints `kit dependencies: N package(s) checked, none names ...` (L6262) | T12 Step 3 expects that text with N=1 (L6330) | consistent |

## 2. Each task against itself

| Task | Tests vs code | Files created vs touched | Commands vs files | Verdict |
|---|---|---|---|---|
| T1 | P1-P5 vs walker: path resolution (`Uri.parse('lib/a.dart').resolve('../lib/b.dart').path` = `lib/b.dart`), violation order, conditional URIs all hold; M-P1, M-P2, M-P3, M-P5 each turn their test red | 10 files + root pubspec; all staged by path (L394) | `flutter test test/invariants/purity_test.dart`, three CLAUDE.md gates | consistent; SC16 side effect (Finding 3) |
| T2 | I1-I4, C1-C12, U1-U5 vs `kit_ids`, `SymbolComponent`, `UnitComponent`: every refusal names the field the test expects; `'kit\n'`-style cases fail because Dart `$` is end-of-input; mistyped `attachTo: null`, `family: 4` reach `FormatException`; all named mutations go red | creates 5 lib + 3 test; modifies 2 barrels | `git add packages/jet_cad_2d_kit/lib packages/jet_cad_2d_kit/test/model` stages directories (Finding 4) | consistent |
| T3 | L1-L5, MF1-MF5, R1-R4 vs code: `Map<String,dynamic>` passes `field<Map<Object?,Object?>>`; `ComponentRegistry()` has no built-ins so R1 holds, `DraftDocument.empty` has them (draft_document.dart:108) without affecting R2/R3; components JSON is sorted by type id then handle (component.dart:258-283) so R4's substrings hold | as listed | directory staging (L1677) | consistent |
| T4 | V0a-V15s vs `_validate`: every one-fault edit reaches the named rule (verified against the codec: `Definition.fromJson` takes non-finite base points, `EntityRecord.fromJson` takes any layer/linetype/style/kind, `GeometryPayload.fromJson` takes any counts and infinities, `_rebuildFills` tolerates a circle payload re-kinded `fill`, leaf handles in `children` are tolerated, `tree.definitions` and `tree.nodes` ascend by handle, `withComponent` ascends); `EntityKind` is exactly `point, line, polyline, circle, arc, text, attrib, fill` so the leaf-kind switch is exhaustive; `Node` is sealed (`GroupNode`, `InstanceNode`). Step 6 mutations all go red. The in-test comment for V0a names a different mutation ("entries in component order", L1981) that would **survive** (component order = handle order = definition order); Step 6's M-V0a (sort by key, L2909) is the effective one. M-V0a2 (L1997) is not in Step 6 | as listed | directory staging (L2931) | consistent, one misleading comment (Finding 6) |
| T5 | M1-M3, W1-W5, KP1 vs `merge`, `KitNames`, `KitProblem`: categories `['Lobby','Bar','Living Room']`, M2's "library 1 (kit sample)"/"library 3 (kit sample)", merge precedence all hold; mutations go red | as listed | directory staging (L3314) | consistent |
| T6 | S1 uses `Uint8List.fromList` (L3384) but the file imports only `dart:convert`, `flutter/foundation show FlutterError`, `flutter/services`, `flutter_test`, the kit barrel and the fixtures (L3352-3359); `flutter/services.dart` re-exports `ByteData` only (asset_bundle.dart:17), none of the others exports `Uint8List`: **compile error**. K1-K6 vs `PlanKit.validate`: hold; M-K3a/b, M-K4, M-K4b, M-K6, M-S2/S3/S4 go red | as listed | directory staging (L3689) | **mismatch** (Finding 1) |
| T7 | B1-B7 vs builder: handle arithmetic of B2 holds (seed 17 → def 18, leaves 19-21, def 22...), closed polyline repeats its first point (drafting.dart:102-116) as B3 expects, `CompoundCommand` never empty (library component first); mutations go red. B4, B6, B7 name no mutation | as listed | directory staging (L4188) | consistent |
| T8 | H1-H8 vs helpers: H3/H4/H6 geometry checked by hand (525/690, 450 radius, 165 back distance, dot = -1); H7's dust at (225,225,π/2) is ±1.377e-14 so M-H7a and M-H7b go red through `expect(c, cleanCoordinate(c))` and the `-0.0` check (the `contains(0.0)` line alone would not catch M-H7a: one corner computes to an exact 0); records `(1200, -350)` compare equal to `(1200.0, -350.0)` | as listed; staged by file | consistent |
| T9 | N1-N7, F0-F19 vs snapshot/conformance: every expected code list derived by hand matches (F2 `[builtDiffers, libraryInvalid]`, F11 seven `wordMissing`, F12 two `wordUntranslated`, F13 `en` orphan, F19 newest-version English); M-F15's stated rationale (L5452: "it then builds and passes the other checks") is wrong: with the family check dropped the builder's `SymbolComponent` refuses `Bed-double` and the case reports `catalogInvalid` (still red). All five lower-case checks are shadowed the same way by K2 constructors | as listed; staged by file | Step 8 copies to `/tmp` (L5437) | consistent, one wrong rationale (Finding 6) |
| T10 | E1 vs example: 1 circle + 2×2 chair shapes = 5 leaves; conformance empty with `tr` words; the README and §7 catalog blocks equal the example character for character. docs §7/§8 use undefined `cafeCatalog`; §8 `sameAsEnglish` names `category:cafe/Bar`, a category the cafe kit lacks | as listed | Step 5 greps a name list that omits `cafeCatalog` (L5881) | **mismatch** (Finding 7) |
| T11 | D1-D12 vs `kit_deps.dart`/script: expected problem strings and order hold; D9 runs from `tool/ci` as `scripts_test.dart` does. **M-D5** (`_package.firstMatch`, L6273) **survives**: `_package` only matches `package:` URIs, so on `import 'a.dart' if (...) 'package:jet_cad_2d_kit_architecture/x.dart'` (L6037-6039) its first match is already the forbidden URI | as listed | Step 7 says "only the four additions" (L6291) for five edits (package matrix, Analyze, Format, new step, publishable) | **mismatch** (Findings 2, 9) |
| T12 | n/a (gates) | creates the results note | Step 6 uses copy-aside + `cmp` (L6344) | consistent |

## 3. Plan mandates a reviewer would flag

| Item | Lines | Note |
|---|---|---|
| Directory staging | L1158, L1677, L2931, L3314, L3689, L4188 | Global Constraints L25 say "stage files by explicit path only"; staging `lib`, `lib/src/model`, `test/model`, `lib/src/kit`, `test/kit`, `lib/src/authoring`, `test/authoring` sweeps any stray file (a forgotten mutation probe such as M-P1's `probe.dart`) |
| Verbatim duplicated logic | `_directive` regex + URI loop L237-239 and L6161-6170; `foreignWordId` add block L3649-3650 and L3654-3655; `_sameBytes` L5327-5333 duplicates engine `listEquals` (list_equality.dart:7) | the first is across two packages (acceptable, say so); the other two are cheap to fold |
| Tests that name no mutation | e.g. C2-C4, C8, C11, I4, U2, U4, L2, L4, L5, MF1, MF4, MF5, V0c, V0d, V0f, V8g, S1, S5, S6, K1, K2, K5, B1 (named but not in Step 6), B4, B6, B7, H1, H8, N3-N6, F0, F0b, F2, F6, F9, F10, F14, F16-F18, D2, D4, D7-D9, D11, D12 | Global L31 says every test names its mutation; most are positive controls or premises |
| Undisposed documents | `buildLibraryDocument` creates `DraftDocument.empty()` before `LibraryComponent(kit:)` / `SymbolComponent(...)` can throw (L4072-4099); fixtures `validLibraryJson()`, `bytesOf(buildValidLibrary())` never dispose (L1865-1867, L2994, L3437) | a leaked document on the refusal path in library code |
| `analysis_options.yaml` committed | L25, L394 | CLAUDE.md says "Never commit `analysis_options.yaml`"; the plan's exception for a new file has precedent (`3694f5c`) but needs the coordinator's explicit ruling |
| `/tmp` copies | L5437, L6344 | L27 bans restoring from `/tmp`; this is only a comparison, but the session's scratchpad rule applies and `git diff --quiet` after committing is simpler |
| Unused exports / assertion-free tests | none found | every `KitProblemCode` value is produced; every exported name is used; no test asserts nothing |

## 4. Global Constraints and spec (K1-K9, amended)

| Check | Verdict |
|---|---|
| Purity allow-list (L20) vs every import in `lib/src/model/**`, `lib/src/authoring/**`, `lib/authoring.dart` | consistent: only `dart:async`, `dart:collection`, `dart:convert`, `dart:math`, `dart:typed_data`, `jet_cad_2d`, `meta`, `vector_math_64`, local |
| No `dart:io` under `lib/` | consistent (`generate.dart` is under `test/`) |
| Old packages untouched | consistent (no task touches them) |
| Components (K2): `ArgumentError`, alphabetical keys, value equality | consistent |
| K3 rules 1-15 as amended | consistent; plan adds xref / no-leaf / symbol-off-definition to rule 4 and STANDARD text style / empty text, tag, textAttrs to rule 14 (both inside "exactly what the builder writes") |
| K3 "`SymbolLibrary` holds the kit id" | plan holds `List<String> kits` (L2963); a plan decision not carried into the spec's amendments (Finding 8) |
| K4 word ids incl. `category:<kit>/<cat>` | consistent |
| K5 `PlanKit`, `validate` | consistent; `unknownWordId`, `missingEnglish` are additions justified by K4 |
| K6 catalog, builder, helpers, cleaning | consistent; `cleanCoordinate` public is an addition |
| K7 checks 1-6, `updateSnapshot` mutation | consistent; `snapshotMissing`, `localeUndeclared`, per-locale `sameAsEnglish` are recorded plan decisions |
| K8 docs | consistent except `cafeCatalog` (Finding 7) |
| K9 CI job, dependency rule, vacuous pass | consistent |
| "Every task ends green" | tool/ci SC16 red T1-T10 (Finding 3) |

## 5. Engine API sample (grep in `packages/jet_cad_2d/lib`)

| Used in plan | Found | Signature matches |
|---|---|---|
| `listEquals` | core/list_equality.dart:7 `bool listEquals<T>(List<T>, List<T>)` | yes |
| `Component` | document/component.dart:16 `abstract class Component { typeId; toJson(); }` | yes (`implements`) |
| `ComponentRegistry.register<T>(typeId, factory)`, `isRegistered<T>()`, `registerBuiltIns()`, `get<T>(h)`, `withComponent<T>()` (ascending), `unknownOf(h)` | component.dart:110, 128, 131, 151, 155, 247 | yes; `loadJson` calls the factory directly so `_guarded`'s `SymbolLibraryError` propagates (component.dart:311) |
| `DraftDocumentCodec.encodeToString(doc)`, `decodeString(src, diagnostics:, registerComponents:)` | codec/json_codec.dart:94, 176-191 | yes; registration runs before components load |
| `Handle(int)` const extension type, `.value`, `.toHex()` (upper-case hex) | core/handle.dart:27, 55 | yes |
| `doc.handleSeed.next()` | handle.dart:68 | yes |
| `DrawingUnits.millimeters`, `.inches`; `header.units` mutable | document/header.dart:7, 11 | yes; `DocumentHeader.fromJson` reads `units` by name |
| `Definition(handle:, name:, basePoint:, children:, isXref, xrefPath)`, `==`, `tree.definition(h)` | node.dart:325-411; tree.dart:69 | yes |
| `tree.definitions`, `tree.nodes` ascending | tree.dart:73-83 | yes |
| sealed `Node` / `GroupNode` / `InstanceNode`; JSON keys in `instanceNodeJson` | node.dart:20, 55, 153, 237-262 | yes |
| `EntityKind` values | store/entity_store.dart:13 | exactly the eight the switch lists |
| `EntityRecord(...)` fields incl. `text`, `tag`, `textStyle`, `textAttrs`; `copyWith(geomIndex:)`; `fromJson` | entity_store.dart:31-187 | yes |
| `entities.liveSlots/read/geomIndexAt`, `geometry.read(slot)` | entity_store.dart:278, 295, 347; geometry_store.dart:109 | yes |
| `GeometryPayload.coords/scalars/pointCount/pointAt` | geometry_store.dart:16-30 | yes |
| `linePayload`, `polylinePayload(…, closed:)`, `circlePayload`, `arcPayload(c, r, start, sweep)` | document/drafting.dart:99-126 | yes; closed repeats the first point |
| `isClosedPolyline`, `isDegenerateSegment` | grips.dart:50; drafting.dart:140 | yes |
| `Tolerance.standard.linear/.angular` = 1e-9 | core/tolerance.dart:23 | yes |
| `ReservedHandles.layerZero=1, byLayerLinetype=2, byBlockLinetype=3, continuousLinetype=4, standardTextStyle=5, dashedLinetype=6` | document/style.dart:104-121 | yes (V14d's `hex(6)` holds) |
| `kByLayer=-1`, `kByBlock=-2`, `EntityFlags.invisible=1`, `.unpickable=2`, `ByBlockColor`, `ByLayerColor`, `encodeColor` | style.dart:6, 9, 27, 37, 76, 129-141 | yes |
| `AddEntityCommand({record, payload})`, `AddDefinitionCommand(def)`, `SetComponentCommand<T>(h, v)`, `CompoundCommand(children, label:)` (non-empty), `DraftCommand` | document/commands.dart:39, 518, 638, 972; command.dart:122 | yes |
| `doc.commands.execute/clearHistory`, `doc.dispose()` returns `Future<void>`, `doc.rootHandle` | undo.dart:187, 277; draft_document.dart:119, 213 | yes |
| `Diagnostic.message` | core/diagnostic.dart:34 | yes |
| `OriginComponent`, `PageComponent` exported | jet_cad_2d.dart exports | yes |

## Findings

1. **T6, L3352-3359 / L3384 (S1):** `test/kit/sources_test.dart` uses `Uint8List` without `import 'dart:typed_data';`; `flutter/services.dart` re-exports only `ByteData`, and nothing else in the import list exports `Uint8List`. The file does not compile, so S1-S6 never run. Ruling: add `import 'dart:typed_data';` to the test.
2. **T11, L6036-6039 and L6273 (M-D5):** the named mutation survives. `_package` matches only `package:` URIs, so `firstMatch` on `import 'a.dart' if (dart.library.io) 'package:jet_cad_2d_kit_architecture/x.dart'` still finds the forbidden URI and D5 stays green. Ruling: make the first URI an allowed package URI, e.g. `import 'package:jet_cad_2d_kit/a.dart' if (dart.library.io) 'package:jet_cad_2d_kit_architecture/x.dart';`. T1's M-P5 is fine, because `_uri` matches any quoted string.
3. **T1 (L203, L385-389) through T11 (L6276-6281):** the existing `tool/ci/test/scripts_test.dart` SC16 requires every `packages/*` that has a pubspec to appear in the CI `package` matrix. It goes red at T1's commit and stays red until T11 Step 7. No gate before T11 runs `tool/ci`, so ten commits are silently red. Ruling: move the matrix entry (`- package: packages/jet_cad_2d_kit / tool: flutter`) into T1 and run `cd tool/ci && dart test` in T1's gates. The alternative is to record SC16 as expected-red until T11.
4. **T2, T3, T4, T5, T6, T7 (L1158, L1677, L2931, L3314, L3689, L4188):** these steps `git add` whole directories, which contradicts Global Constraints L25 ("Stage files by explicit path only"). Ruling: list the files, as T8-T11 already do.
5. **Global L31 vs many tests:** a large number of tests name no mutation (listed in §3): positive controls, premises, B4, B6, B7, S1, S5, S6, N3-N6, D7-D12 and others. B1's M-B1 and V0a's M-V0a2 are named in comments but are missing from their Step's mutation list. Ruling: either relax L31 to "every refusal or behaviour test", with positive controls exempt, or add the mutations to each Step.
6. **T4 L1981 vs L2909; T9 L5452:** two mutation descriptions are wrong. V0a's in-test comment names "entries in component order", which would survive because `withComponent` ascends by handle, the same order as the definitions; Step 6's "sort by key" is the effective mutation. M-F15's rationale ("it then builds and passes the other checks") is also wrong: dropping a lower-case check leads to `catalogInvalid`, since the K2 constructors refuse upper case. The test still goes red. Ruling: fix the comment text. Note that conformance check 6 is fully shadowed by K2's constructors.
7. **T10, L5816, L5822 and L5845 (docs/kits.md §7 and §8):** these use `cafeCatalog`, which nothing defines (the example defines `buildCafeCatalog()`), and Step 5's name check (L5881) omits it. §8's `sameAsEnglish` also names `category:cafe/Bar`, a category the cafe kit lacks. Ruling: write `buildCafeCatalog()`, or define `final cafeCatalog = buildCafeCatalog();` in the snippet, and drop or align the `Bar` entry.
8. **T5, L2963 vs spec K3 ("holds the kit id"):** `SymbolLibrary.kits` is a list. This plan decision is not in the spec's "Amendments while planning". Ruling: accept it, and add one line to the amendments so the spec matches.
9. **T11, L6291:** the text says "shows only the four additions", but the step makes five edits (package matrix, Analyze, Format, new step, publishable matrix). Ruling: change it to "five".
10. **T9 L5437, T12 L6344 vs Global L27:** both copy files to `/tmp` and compare them with `cmp`. L27 forbids `/tmp` restores, and the session's scratchpad rule applies. Ruling: at T12, where the files are committed, regenerate and run `git diff --quiet -- test/fixtures/sample_kit`. At T9, use the scratchpad, or commit first and then use the same `git diff` check.
11. **T7, L4071-4099:** `buildLibraryDocument` creates the `DraftDocument` before component constructors that can throw `ArgumentError` (B6). The refusal path therefore leaks an undisposed document. Test fixtures (`validLibraryJson`, `bytesOf(buildValidLibrary())`) also never dispose. Ruling: build the components first, or wrap the body in `try`/`catch` and dispose before rethrowing. The fixture leaks are acceptable.
12. **Duplication, L3649-3655, L5327-5333, L237-239 with L6161-6170:** the `foreignWordId` add block appears twice in `PlanKit.validate`; `_sameBytes` re-implements the engine's `listEquals`; and the directive regex exists in both the walker and `kit_deps`. Ruling: fold the first two. Accept the third, since it crosses packages, and note it in the code.
13. **Global L25 vs CLAUDE.md:** the plan commits `packages/jet_cad_2d_kit/analysis_options.yaml`, but CLAUDE.md says "Never commit `analysis_options.yaml`". The exception has a precedent (`3694f5c`). Ruling: the coordinator confirms the exception explicitly before Task 1.
