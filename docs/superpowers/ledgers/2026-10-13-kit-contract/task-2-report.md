# Task 2 report (K2)

Commit: 1a70657f feat(kit): the identifier patterns, SymbolComponent and UnitComponent (K2)

Implemented kit_ids, json_fields, SymbolComponent, UnitComponent, model.dart, both barrel exports, and three test files, all verbatim from the brief (dart format reflowed two test files only).

Gate (packages/jet_cad_2d_kit): `flutter test` -> "+55: All tests passed!"; `flutter analyze` -> "No issues found!"; `dart format --output=none --set-exit-if-changed .` -> exit 0.

TDD note: I wrote the source before running the tests, so no RED compile-failure transcript exists; the mutation step below is the red evidence.

Mutations (on committed files, each reverted with git checkout, `git diff --quiet` exit 0):
- M-I1 (`[a-z0-9][a-z0-9]*`): I1 red ("Expected: false Actual: <true>"; I3 also red).
- M-I2 (`^[a-z0-9-]+$`): "I2 a kind is lower-case letters ... [E] Expected: false Actual: <true>".
- M-I3a (`{1,}`): "I3 a key is a kit id, then two or more segments [E] Expected: false Actual: <true>".
- M-I3b (drop kit-id check): same I3 line red.
- M-C1 (drop attachTo listEquals): "C1 equality sees every field ... [E] Expected: not SymbolComponent..." (C2 also red).
- M-C5 (drop seenTags.add check): "C5 a repeated tag is refused on "tags" [E] ... returned SymbolComponent".
- M-C6 (`^[a-z ]+$` tag test): "C6 the allowed edges are accepted [E]" (C5 outer-white-space case also red).
- M-C7 (swap key/family): "C7 ... [E] Actual: [..., 'key', 'family', ...] at location [2] is 'key' instead of 'family'".
- M-C9 (`json['family'] as String?`): "C9 fromJson refuses a map without "family" [E] ... returned SymbolComponent" (C10 family also red, TypeError).
- M-C10 (`json['version']! as int`): "C10 fromJson refuses "version": 3 ... [E] threw _TypeError" (C9 version also red).
- M-U3 (drop labelling from ==): "U3 equality sees every field [E] Expected: not UnitComponent(table, 6, assigned)".
- M-U5 (byName): "U5 fromJson refusals [E] ... threw ArgumentError: No enum value with that name: "random"".

git status after: clean (no analysis_options.yaml changes).
