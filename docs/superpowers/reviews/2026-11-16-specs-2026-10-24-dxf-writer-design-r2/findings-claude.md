F1 [major] Containers and transforms
claim: A `GroupNode`'s transform is baked into its leaves; "writing each group as an anonymous block plus INSERT ... is wrong".
evidence: The binding architecture spec 2026-07-27 ("`GroupNode` maps to an anonymous block, not to DXF GROUP ... Groups created in the designer export as anonymous blocks") and the `GroupNode` doc comment in node.dart ("Exports as an anonymous block rather than a DXF GROUP") both decide the opposite; this spec neither amends nor supersedes them.
fix: Add an amendment to the 2026-07-27 spec (and schedule the `GroupNode` doc-comment change) stating that baking supersedes the anonymous-block rule, or adopt the earlier rule.

F2 [major] The plan library
claim: The shared H2 test asserts the DXF of a plan with an `exported: false` object equals, byte for byte, the DXF of the same plan with that object deleted.
evidence: `DraftDocument.extents` (draft_document.dart, `_computeExtents` over `leavesByOwner()`) includes omitted leaves, so `$EXTMIN`/`$EXTMAX` differ; handles are "minted above the document's highest handle", which the omitted object may hold; the parent `GroupNode.children` order carried in the JETCAD `node` record names the omitted handle. All three make the bytes differ, so the gate cannot pass as written.
fix: Define extents, the minting base and the tree record over the written set only, or compare a normalised form instead of bytes.

F3 [minor] Entity style columns
claim: "Transparency. Code 440. The engine's 0–255 maps onto DXF's alpha encoding."
evidence: `EntityRecord.transparency` (entity_store.dart) and `InstanceNode.transparency` (node.dart) are documented as "0..255, or one of kByLayer, kByBlock"; the spec gives no mapping for the −1/−2 cases, so an emitter may write them as alpha −1/−2 or omit them.
fix: State that `kByLayer` omits code 440 and `kByBlock` writes DXF's ByBlock transparency, and add both to the pinned test.

F4 [minor] Semantics: the JETCAD data
claim: Every component on a handle is written in that handle's XRECORD; separately, "an XRECORD under `JETCAD` in the named object dictionary holds ... the plan's manifest".
evidence: `ManifestComponent` (`jetcad.manifest`, manifest_component.dart) is a component attached to `doc.rootHandle` like `LibraryComponent` in builder.dart, so the per-handle rule and the document rule both claim it; the document owner of the root's XRECORD (model-space BLOCK_RECORD or the dictionary) is unstated.
fix: Say where root-handle components go (per-handle, document XRECORD, or both) and which DXF object owns the root's extension dictionary.

F5 [minor] Handles
claim: Records the engine lacks "get handles minted above the document's highest handle", and `$HANDSEED` "lies above every handle written".
evidence: `HandleSeed` (handle.dart) is monotonic and `raiseTo` never moves back, so `HandleSeed.current` can exceed the highest handle in use after deletes; regeneration.dart reserves "handles above the seed" for new children. Minting from the highest in-use handle and minting from the seed are two different implementations with different bytes.
fix: Mint from `HandleSeed.current` and write `$HANDSEED` from the last minted handle, and say so.

F6 [minor] The units' colours (H4)
claim: The layer is "named `JETCAD-UNIT-COLOURS` (name: my call)" and also "minted by the writer from the `extraFills`' layer name".
evidence: `DxfExtraFill` carries a layer name per fill (Shape of the package), so the name is the plan exporter's; nothing says what the writer does with two fills naming different layers, or who owns the constant.
fix: Put the constant in the plan exporter, and state that the writer mints one LAYER per distinct `extraFills` layer name.

F7 [minor] Version and header
claim: "`customVariables` ... only a reader fills them. Today the writer reports one `Diagnostic` if any are present and does not write them."
evidence: `DocumentHeader.customVariables` (header.dart) is a public mutable map the codec round-trips today, so any host or test can fill it; a `Diagnostic` of severity `loss` for data the writer could emit as plain header variables is a declared loss with no reason given.
fix: Either write string and numeric `customVariables` as `$NAME` header variables now, or state the severity and code of the diagnostic.

F8 [hunch] Entities
claim: A polyline is closed "when the stored last vertex `==` the first ... a stored-value test, so exact".
evidence: `GeometryPayload` (geometry_store.dart) has only `coords` and `scalars`, no closed flag, so the rule is plausible; whether the painter and `triangulationFor` use the same equality test for closure was not checked.
fix: Cite the engine function whose closure test the writer must match, so the DXF closed flag cannot disagree with the screen.

F9 [minor] Verification
claim: Oracle tests "fail rather than skip" when Python is absent, excluded from the default suite by a tag in `dart_test.yaml`.
evidence: Only packages/jet_cad_2d_flutter/dart_test.yaml exists; AGENTS.md's "Every task ends green" and "Before finishing ... `cd tool/ci && dart test`" do not mention a tag, and tool/ci/standing_failures.txt is the only mechanism for a known failure, so a reviewer running the package's full suite without Python sees red with no rule naming it expected.
fix: Name the tag, add the `dart_test.yaml` to the new package's file list, and say how a reviewer runs and reports the oracle locally.

F10 [minor] The plan library
claim: `PlanExportRequest` "gains a way for an exporter to report `Diagnostic`s" and `PlanExport` gains `diagnostics`; "both are additions, not breaking changes".
evidence: `PlanExport` (registries.dart) is `@immutable final class` with a `const` constructor of three required fields, so a defaulted field is additive; but `PlanExportRequest` is constructed by `PlanPageFlows._requestOf` only, and the spec does not say whether the reporting channel is a mutable list on the request or a return-type change to `PlanExporter.export`, the second of which breaks every host exporter.
fix: Fix the channel as a sink on the request (not a change to `PlanExporter.export`'s signature) and say so.

F11 [minor] Draw order
claim: "No `SORTENTSTABLE` is needed" because entities are written in ascending handle order "within each container".
evidence: After baking, a group's leaves and its instances' INSERTs land in model space alongside root leaves, and spatial_index.dart orders a root leaf against instanced content by the enclosing instance's handle; the spec never states that INSERTs, baked leaves and root leaves interleave by one ascending handle sequence in model space.
fix: State that model space is one merged ascending-handle sequence over root leaves, baked group leaves and INSERTs (the INSERT at the `InstanceNode`'s handle), and name the mutation that catches a per-group block of leaves.

VERDICT: revise — two binding contradictions (group export rule, H2 byte-equality gate) must be resolved before a plan is written.
