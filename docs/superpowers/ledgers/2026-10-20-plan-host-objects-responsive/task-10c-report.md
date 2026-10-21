# Task 10c report

Status: DONE

Commits (on feat/pos-host, after e7899f06):
- 8d8d60ca feat(kit): PlanType name capability (name, hasName, nameOf; NM1, NM2; CHANGELOG)
- 32701b77 fix(kit): drop an unused import from the name test
- dd1f2c06 feat(kit_architecture): the room declares its name (RN1; CHANGELOG)
- 847ccd16 feat(plan): label = name else title word; PlanController.sectionDetails (SD1, SD2; zone kit gains a name and a "no width = no area" case; CHANGELOG)
- df384066 test(integration): SD3 Salon/VIP/Garden real rooms
- 109853a0 feat(restaurant_demo): linkSections by room name via sectionDetails; kSectionProbeTable removed; inspector shows the room's name (Key object-name)
- e6b3b064 docs: guide 6.10 (label rule) and 6.11 (sectionDetails block, room selected by label), probe block

Gates run (real results):
- jet_cad_2d_kit: flutter test 409 passed; analyze clean; format clean.
- jet_cad_2d_kit_architecture: 661 passed; analyze clean; format clean.
- jet_cad_2d_plan (--enable-vmservice): 1630 passed; analyze clean; format clean.
- jet_cad_2d_integration (--enable-vmservice): 235 passed; analyze clean; format clean.
- restaurant_demo: 112 passed; analyze clean; format clean.
- check_kit_deps ok; check_guide: all 35 code blocks in the probe; host_probe.sh at HEAD: built web, exit 0.

Mutations (each run on committed code, reverted, git diff --quiet):
- Kit: nameOf returns null -> NM2 red.
- Architecture: room `name:` returns null -> RN1 red (run before the commit, reverted and reapplied).
- Plan: label ignores the name -> SD2 red. sectionDetails keeps every typed object (not only area types) -> SD1 and SD2 red.
- Demo: link sections match record.id instead of record.name -> LK1, LK3 red. Name text emptied in the inspector -> LK2 red.

Decisions:
- Existing assertion changed with `// Decided:` in apps/restaurant_demo/test/linking_test.dart LK2: key `type:Room` became `type:VIP` (a room's label is now its name, by D9/R8). Comment about "probe tables" updated.
- sectionDetails lists by area-capable type, even when the area is null now (zone with w = 0 in SD1).
- linkSections skips a name shared by two rooms (links neither).
- Plan library names no kit type id.

Concerns:
- Commit 32701b77 is a small fixup that could have been squashed.
- The kit-level name is a single string; a room named only with whitespace falls back to the title word only if empty (not trimmed in the plan library; the room refuses empty names on write).
