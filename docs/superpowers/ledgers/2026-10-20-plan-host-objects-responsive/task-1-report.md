# Tasks 1 and 2 report

Status: DONE (with concerns). Commits: da3fe0b8 feat(kit): PlanType's area capability; c55185f0 feat(architecture): the room declares its area.

## Task 1
- PlanType gains `area: List<Vector2>? Function(T, PlanObject)?`, private `_area`, `hasArea`, `areaOf(DraftDocument document, Handle group, PlanWords words)`. Deviation: first parameter is `DraftDocument` (as `fieldsOf`/`commitField`), not `CommandTarget`, because `DocumentPlanObject` needs a DraftDocument. Callers pass the document.
- CHANGELOG had no Unreleased heading; added one at top.
- Tests AR1-AR4 (AR4 extra: capability returning null). AR2 uses a group translated (5000,-3000), rotated 30 deg.
- Gates (kit): 407 tests passed; analyze no issues; format 0 changed; check_kit_deps green.
- Mutation: DocumentPlanObject built over `document.rootHandle` instead of `group` -> AR2 red; reverted, git diff clean.

## Task 2
- Choice: trace from the document, `traceRoomAmong(object.world.transformPoint(seed), RoomInputs(doc, live))`; the same trace `RoomType.generate` takes (equal to `Traced.ring`, RA1 compares with `faceAt`). Rejected the generated outline child: only the step-3 tint form has a POLYLINE of the outer ring, steps 1/2 are regions.
- Live rule: a PlanObject carries no services, so live = component presence (WallParams -> wall, SeparatorParams -> separator). A plan's frozen objects (session state, not in the document) are NOT excluded: a frozen wall still bounds the area. Concern for the caller.
- Memo: per document, one RoomInputs (invalidated on state change) and a per-room ring map cleared when `commands.stateId` changes; `debugRoomAreaTraces` counter (visibleForTesting). RoomInputs is never disposed explicitly (its subscription dies with the document).
- Tests RA1-RA5 (RA5 extra: memo and edit follow). RA3 stores a local seed in a group rotated 90 deg and mirrored.
- Gates (architecture): 660 tests passed; analyze no issues (after removing one unnecessary import); format 0 changed; check_kit_deps green.
- Mutations (each on committed code, reverted, git diff clean): seed not mapped by world -> RA3 red; cache.rings.clear() removed -> RA5 red; ring mapped back to local space -> RA3 red (RA1 stays green: its group is the identity).
