F1 [major] The plan library
claim: Passing the request document to PlanDxfExporter preserves the plan manifest and identifies every kit used.
evidence: PlanPageFlows._copyOf uses DraftDocumentCodec directly; file/plan_file.dart only synthesizes the current manifest in encodePlan, explicitly leaving the in-memory manifest unchanged.
fix: Prepare the export snapshot with the current manifest using the loaded kit set before invoking the exporter.
F2 [major] Semantics: the JETCAD data
claim: Group transforms, parent links and child order make the original scene tree restorable.
evidence: GroupNode.children contains nodes only, while EntityRecord.owner is authoritative for leaf ownership; baking removes that ownership from DXF containers, and the specified leaf JSON records only components.
fix: Record each leaf's original owner and define where records for componentless groups are stored.
F3 [major] Containers and transforms
claim: Sheared instances are exploded while engine records retain their own handles and semantics remain restorable.
evidence: InstanceNode.definition allows multiple placements of the same Definition; exploding two placements duplicates its leaf records, but Handles provides no occurrence-handle allocation rule and Semantics specifies no exploded-instance mapping.
fix: Define unique handles, resolved styles and provenance for exploded occurrences, preserving the original instance and definition relationship.
F4 [major] The plan library
claim: The shared H2 test requires DXF bytes to equal those produced after deleting the omitted object.
evidence: Handles mints auxiliary records above the document's highest handle, and Version and header exports document extents; deleting the highest-handled or outermost omitted object changes these values despite identical exported geometry.
fix: Define filtered handle-allocation and extents rules that support byte equality, or compare normalized DXF content for H2.
F5 [major] Entities
claim: TEXT writes stored TextJustifyH/V justification and supplies a second alignment point where required.
evidence: TextLayout.resolve in document/text_geometry.dart explicitly downgrades aligned and fit to left because GeometryPayload lacks their required second point; writing the stored justification therefore cannot reproduce the screen without an additional policy.
fix: Specify the aligned/fit fallback, its diagnostic and preservation of the original justification in JETCAD data.
F6 [major] Entity style columns
claim: Transparency maps the engine's 0–255 values onto DXF alpha encoding.
evidence: EntityRecord.transparency and InstanceNode.transparency also accept kByLayer and kByBlock, and DocumentStyleResolver handles these as distinct inheritance modes; the proposed mapping leaves both unspecified.
fix: Define DXF encodings and verification fixtures for inherited transparency on entities and nested INSERTs.
VERDICT: revise — Manifest preparation, reversible semantics, exploded identities and export verification need explicit decisions.
