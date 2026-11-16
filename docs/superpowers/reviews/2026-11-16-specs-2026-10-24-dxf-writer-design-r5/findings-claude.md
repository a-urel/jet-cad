F1 [major] The plan library
claim: The shared H2 test asserts the DXF bytes of a plan with an `exported: false` object equal the bytes of the same plan with that object deleted.
evidence: "Handles" mints DXF-only handles "above the document's highest handle", which drops when the deleted object held it, while `HandleSeed.raiseTo` in handle.dart never moves backward and json_codec.dart persists the seed; and the spec skips only definitions used solely by omitted instances, so a definition left unreferenced after the delete is still written. Two sources of byte drift in the test's own setup.
fix: Mint from `handleSeed.current`, state that every unreferenced definition is skipped, or compare ezdxf-decoded content instead of bytes.

F2 [major] Containers and transforms
claim: A `GroupNode`'s transform is baked into its leaves and groups with a component become DXF GROUPs; writing groups as anonymous blocks "is wrong to an AutoCAD user".
evidence: 2026-07-27-jet-cad-2d-architecture-design.md ("GroupNode maps to an anonymous block, not to DXF GROUP ... declared in the exporter's diagnostics") and the `GroupNode` doc comment in node.dart both bind the opposite, and this spec neither cites nor supersedes them.
fix: State explicitly that this decision supersedes the architecture spec's rule and amend node.dart's comment in the plan.

F3 [minor] Semantics: the JETCAD data
claim: Per-handle components go in an XRECORD in the entity's, GROUP's or BLOCK record's extension dictionary; the document record carries "its manifest" and a reader needs nothing else to know which kits a plan used.
evidence: manifest.dart says the `PlanManifest` is a component "on a plan's root"; the root is model space and has no entity, GROUP or BLOCK record of its own in the spec's mapping, and `writeDxf` (Shape of the package) takes no document-level data, so the engine-only writer has no stated place for root-handle components.
fix: Say root-handle components are written into the named-object-dictionary document record (or the `*Model_Space` BLOCK_RECORD's dictionary) and that the manifest reaches the file that way.

F4 [minor] Entity style columns
claim: Transparency is code 440 and "the engine's 0–255 maps onto DXF's alpha encoding", pinned at 0, 255 and a middle value.
evidence: `EntityRecord.transparency` in entity_store.dart and `InstanceNode.transparency` in node.dart are "0..255, or one of kByLayer, kByBlock" (−1, −2); the spec never maps the two sentinels, which DXF encodes differently (no 440 for BYLAYER, 0x01000000 for BYBLOCK).
fix: Specify the BYLAYER and BYBLOCK transparency encodings and add both to the pinned test.

F5 [minor] Entities
claim: `text` writes justification in codes 72/73; the `attrib` row gives no justification codes.
evidence: `EntityRecord.textAttrs` in entity_store.dart documents vertical justification as "DXF 73 for TEXT, 74 for ATTRIB — for an ATTRIB, group 73 is field length".
fix: State that ATTDEF/ATTRIB write vertical justification in code 74 and name a mutation for it.

F6 [minor] The units' colours (H4)
claim: Each unit-colour hatch carries a JETCAD record `{ "v": 1, "derived": "unitColour" }`.
evidence: "Semantics" fixes the per-handle record as `{ "v": 1, "components": { … } }`; the spec gives two shapes under the one `JETCAD` key and no rule for a reader to tell them apart.
fix: Define one record shape with an optional `derived` key, and state that a reader skips any record carrying it.

F7 [minor] The plan library
claim: `jet_cad_2d_plan` gains a dependency on the new published package `jet_cad_2d_dxf`.
evidence: tool/ci/lib/host_lock.dart `probedFromCommit` lists the packages the host probe overrides to the commit, and tool/ci/test/dependency_lines_test.dart pins `published`, `carets` and a count of 22 hosted lines; a new published package the plan depends on fails both unless they grow, and the spec names neither.
fix: Add a line that the host probe's override list and the dependency-lines test are extended for `jet_cad_2d_dxf` before the plan library depends on it.

F8 [minor] Verification
claim: The ezdxf oracle tests carry a tag the default `dart test` excludes, and fail rather than skip without Python.
evidence: AGENTS.md "Every task ends green" and "Rules for every agent session" run only the per-package `dart test` and `cd tool/ci && dart test`; a tag-excluded suite is run by none of them, so no task's exit gate ever executes the oracle, and tool/ci/standing_failures.txt is where a "fails locally" test would end up.
fix: Make the tagged run an explicit command in the plan's exit gate and say how a task reviewer runs it without Python.

F9 [hunch] Version and header
claim: AC1027 "is the oldest version that is UTF-8 throughout".
evidence: not checked; DXF R2007 (AC1021) is generally documented as the first UTF-8 version, so the justification may be wrong even though the choice stands.
fix: Justify AC1027 by transparency and lineweight support alone, or correct the UTF-8 claim.

VERDICT: revise — H2 byte-equality test and the group-as-GROUP reversal need resolving before a plan is written.
