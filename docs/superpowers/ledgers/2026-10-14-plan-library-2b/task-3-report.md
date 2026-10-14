# Task 3 report: contract additions

Commit b71ab4c8 `feat(kit): the contract's 2b additions (spec 2b S2, S4)`.

## Implemented
Per the brief, steps 1-15: SymbolsState; SymbolDefinitionRef + PlanServices.symbolDefinition/symbolsState;
unit_label.dart (tag, height from Aabb2, stamp, payload, unitLabelAttrib); host_words.dart (validateHostWords);
PlanGate.relabel; `unit:` namespace in PlanKit.validate; KitProblemCode.unitKindWord + conformance unit-kind check;
docs (KitNames, UnitLabelling.assigned, validate), CHANGELOG, barrel exports; plan library: PlanPermissions.relabel
(ctor default true, readOnly false, allows, edits, copyWith, _flags), KitServices stubs (UnimplementedError, Task 4).

## Files
Kit: lib/jet_cad_2d_kit.dart, lib/src/kit/{symbols_state,unit_label,host_words,plan_services,properties,plan_kit}.dart,
lib/src/model/{kit_problem,kit_names,unit_component}.dart, lib/src/authoring/conformance.dart, CHANGELOG.md,
test/support/placements.dart, test/kit/{unit_label,host_words,plan_kit,plan_services,properties}_test.dart,
test/authoring/conformance_test.dart, test/invariants/purity_test.dart.
Plan: lib/src/controller/{permissions,services}.dart, test/controller/permissions_test.dart.

## TDD
RED: `flutter test` in the kit before the lib change: `+277 -7 ... Some tests failed`; compile errors e.g.
`test/kit/host_words_test.dart:25:12: Error: Method not found: 'validateHostWords'.` and PS18/K2B-validate/K2B-pure red.
GREEN: kit `00:05 +340: All tests passed!`; plan `00:38 +735: All tests passed!`.
Plan `flutter analyze` before the follow-up showed the two expected errors (non_exhaustive_switch_expression at
permissions.dart:72, non_abstract_class_inherits_abstract_member at services.dart:21).

## Gates
- kit: flutter test (+340 all passed), flutter analyze `No issues found!`, format exit 0.
- plan: flutter test (+735 all passed), flutter analyze `No issues found!`, format exit 0.
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 1 package(s) checked, none names the plan library or another kit` (exit 0).
- precondition: engine `dart analyze` and plan `flutter analyze` clean at HEAD bcf4d6b8.
- git status at gate: only task files, no analysis_options.yaml.

## Mutations (each reverted with git checkout --, `git diff --quiet` exit 0 every time)
- M-K2B-1 payload stamps identity: K2B-payload red (+ K2B-attrib).
- M-K2B-2 tag '' : K2B-attrib red (GeneratedAttrib refuses an empty tag, so the error is a throw; K2B-attrib-empty also red).
- M-K2B-3 textAttrs removed: `+17 -1: ... K2B-attrib unitLabelAttrib ... [E]`.
- M-K2B-4 anchor mapped: K2B-attrib red.
- M-K2B-5 stamp for another map: K2B-attrib red.
- M-K2B-6 empty check deleted: TL4 and K2B-attrib-empty red.
- M-K2B-stamp `-phi` only: TL1 mirrored cases red.
- M-K2B-height min->max: TL4 and K2B-attrib red.
- M-K2B-7: K2B-host-1 red (+ host-3). M-K2B-8: K2B-host-2 red. M-K2B-9: K2B-host-2 and host-3 red.
- M-K2B-10, M-K2B-11: K2B-validate red.
- M-K2B-12, M-K2B-13: K2B-conf red. M-K2B-14: F0 red (+F1).
- M-K2B-15 flutter import in unit_label.dart: K2B-pure red.
- M-K2B-16: PM-5 red. M-K2B-17: PM-1 and PM-6 red. M-K2B-18: PM-3 and PM-7 red.

## Findings / concerns
1. The brief's K2B-ref test built `CompoundCommand(const [], label: 'Add')`, which throws ArgumentError (children must not be
   empty). Replaced with `AddDefinitionCommand(Definition(handle: Handle(0x4A2), name: 'Booth', basePoint: ..., children: const []))`.
   Only the fixture changed; assertions identical.
2. M-K2B-2 as specified ('' tag) goes red by a throw rather than an assertion mismatch (still red).
3. The plan barrel re-export of SymbolsState (R-3) and the PlanSymbolsState move are not done here: the brief's file list
   does not touch jet_cad_2d_plan.dart; left to Task 4 where KitServices/symbolsState are implemented.
4. Commit trailer uses "Claude Opus 5.5" as the brief and implementer instructions say (the harness reminder said Sonnet 5.5).
5. TL3/TL5-TL7 are not ported here (Task 6/7), as the brief states.

## Fix round 1

Commit c4e69c78 fix(kit): PlanServices keeps its doc comment. Moved the SymbolDefinitionRef block above the 'One plan, as a kit's code sees it' comment, which sits on PlanServices again.
Gates: kit flutter test +340 All tests passed!, analyze No issues found!, format exit 0, check_kit_deps exit 0.

M-K2B-2 with 'TABLE' (non-empty): K2B-attrib red, 'Expected: UNIT  Actual: TABLE' at expect(a.tag, 'UNIT'); reverted, git diff --quiet exit 0.

Red lines of every mutation (first failing lines; each reverted, git diff --quiet exit 0):
```
== M1
00:00 +16 -1: the generated label (spec 2b S2) K2B-payload the payload holds the anchor as given and [height, rotation, widthFactor] stamped for the instance-to-world map [E]
00:00 +16 -2: the generated label (spec 2b S2) K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its own width factor, the payload in definition space, upright and unmirrored in the world [E]
revert 0
== M5
00:00 +17 -1: the generated label (spec 2b S2) K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its own width factor, the payload in definition space, upright and unmirrored in the world [E]
revert 0
== M3
00:00 +17 -1: the generated label (spec 2b S2) K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its own width factor, the payload in definition space, upright and unmirrored in the world [E]
revert 0
== M4
00:00 +17 -1: the generated label (spec 2b S2) K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its own width factor, the payload in definition space, upright and unmirrored in the world [E]
revert 0
== M6
00:00 +15 -1: unitLabelHeight (T8, M-14a-14) TL4 written out by hand [E]
00:00 +17 -2: the generated label (spec 2b S2) K2B-attrib-empty a definition with no served top: the full height [E]
revert 0
== stamp
00:00 +7 -1: unitLabelStamp (T10) TL1 mirrored, 0.0°: the label reads upright in world (M-14a-7, M-14a-8) [E]
00:00 +7 -2: unitLabelStamp (T10) TL1 mirrored, 37.0°: the label reads upright in world (M-14a-7, M-14a-8) [E]
revert 0
== height
00:00 +15 -1: unitLabelHeight (T8, M-14a-14) TL4 written out by hand [E]
00:00 +16 -2: the generated label (spec 2b S2) K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its own width factor, the payload in definition space, upright and unmirrored in the world [E]
revert 0
== M15
00:00 +2 -1: K2B-pure the unit label, the host words and SymbolsState reach no Flutter [E]
revert 0
== M7
00:00 +0 -1: K2B-host-1 a word in every namespace, under any kit (loaded or not), in any locale, is sound [E]
00:00 +1 -2: K2B-host-3 a word that names no kit [E]
revert 0
== M8
00:00 +1 -1: K2B-host-2 a word in no known namespace, in the words' order [E]
revert 0
== M9
00:00 +1 -1: K2B-host-2 a word in no known namespace, in the words' order [E]
00:00 +1 -2: K2B-host-3 a word that names no kit [E]
revert 0
== M10
00:00 +6 -1: K2B-validate a unit kind word under the kit is sound; under another kit, under none, or dotted, it is foreign [E]
revert 0
== M11
00:00 +6 -1: K2B-validate a unit kind word under the kit is sound; under another kit, under none, or dotted, it is foreign [E]
revert 0
== M12
00:00 +27 -1: unit kinds (spec 2b S4) K2B-conf a kind outside UnitKinds needs an English unit word, once per kind; the declared locales are not held to it [E]
revert 0
== M13
00:00 +27 -1: unit kinds (spec 2b S4) K2B-conf a kind outside UnitKinds needs an English unit word, once per kind; the declared locales are not held to it [E]
revert 0
== M14
00:00 +0 -1: F0 the sample kit conforms [E]
00:00 +1 -2: F1 built differs from committed: a renamed symbol [E]
revert 0
== M16
00:00 +4 -1: PM-5 allows(gate) reads that gate's own flag, and only it [E]
revert 0
== M17
00:00 +0 -1: PM-1 full and readOnly, field by field [E]
00:00 +4 -2: PM-6 draft: no edit flag and no tool but select is the engine's readOnly; any edit flag or any other tool opens every group [E]
revert 0
== M18
00:00 +2 -1: PM-3 == and hashCode over every field; the tools as a set [E]
00:00 +5 -2: PM-7 toString names the fields that differ from full [E]
revert 0
```

## Fix round 2 (evidence)

M-K2B-2 entry (unit_label.dart: kUnitLabelTag -> "TABLE" in unitLabelAttrib; flutter test test/kit/unit_label_test.dart), verbatim:
```
00:00 +17 -1: the generated label (spec 2b S2) K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its own width factor, the payload in definition space, upright and unmirrored in the world [E]
  Expected: 'UNIT'
    Actual: 'TABLE'
            Expected: UNIT
              Actual: TABLE
revert, git diff --quiet exit 0
```
