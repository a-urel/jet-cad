# Task 7 review: the plan file (aeb5e610..6df8967a)

### Spec Compliance

- ✅ Spec compliant. The diff matches the brief's code in every lib file. The only differences are `dart format` reflow, one added doc comment (manifest.dart:114-116) and `label: 'Add a symbol'` in the PF-3 test (manifest_test.dart:37). That label is needed because `CompoundCommand` requires it, and it changes no assertion.
  - P4 manifest on the root, format 1, `{kit: version}`: `encodePlan` writes `manifestToWrite(...)` on the root (plan_file.dart:88-111). For a kit used or read, it writes the loaded version when the kit is used, keeps the entry as read when the kit is not loaded, and drops a loaded kit that is no longer used (manifest.dart:89-101). PF-4, PF-5 and PF-9 pin this.
  - P4 refusals: `notJson` comes first, then `noManifest`, `schema` (a manifest that does not read), `formatTooNew` (format > 1), and then any engine decode error as `schema` (plan_file.dart:29-81). PF-1 covers each code. `PlanFormatException implements FormatException`, with null `source`/`offset` and the specified `toString` (plan_format_exception.dart:25-41). The test checks it with `isA<FormatException>()` (plan_file_test.dart:54-56).
  - P4 load diagnostics kept and ruling R-c: the caller's `diagnostics` and `keepUnreadableComponents: true` reach the codec (plan_file.dart:32-37). PF-unreadable pins the raw component, the `component.unreadable` handle and the byte-for-byte save.
  - R6 semver: precedence follows semver 2.0.0 §11 and ignores build metadata (semver.dart:40-73). A newer kit warns with `kitNewer` and an unparseable version gives no diagnostic (manifest.dart:117-143). PF-7, PF-7u and PF-8 pin this.
  - P5: `ensureManifest` adds `{"format":1,"kits":{}}` on the root and returns the same instance when a manifest is already there (plan_file.dart:117-131). PF-10 pins both.
  - Unknown components round-trip byte for byte: PF-9 (`gone.widget` with non-sorted keys `{'b':2,'a':1}`) and PF-6 (an attached unknown, two saves).
  - Barrel: matches the brief. `usedKitsIn` and `semver.dart` stay internal (jet_cad_2d_plan.dart).
- ⚠️ Cannot verify from diff:
  - Nothing in this diff calls `checkManifest`. Whether a load *surfaces* the `kitMissing`/`kitNewer` diagnostics is up to the controller (Task 8/10). The controller should check that a load runs `checkManifest(manifestOf(d)!, usedKits(d), loaded)` and reports the result.
  - Which `diagnostics` list the controller passes to `decodePlan` (see Minor 3).

### Strengths

- Checking the manifest on the raw JSON before the engine decodes (plan_file.dart:57-81) means a format-2 plan is `formatTooNew` even when this build could not read its components. The ordering is clear and documented.
- `encodePlan` edits a copy of the encoded components map. It reproduces `ComponentRegistry.toJson`'s ordering exactly: type ids by default `String` sort, handles numerically (checked against jet_cad_2d/lib/src/document/component.dart:254-290). So byte stability holds by construction, and PF-6 confirms it twice.
- `SemVer._compareIdentifier` compares numeric identifiers by length and then lexically (semver.dart:59-68). This avoids int overflow for long numeric pre-release identifiers. `hashCode` agrees with `==`.
- Fixtures sit off the origin, at a rotation, with non-default attributes (`finish: 'tiled'`, `swatch: 'red'`) and plan/loaded version skews. Every behaviour test names its mutation. The report gives a quoted red line for all 17 mutations, plus the gate output.
- Named risk checked: whether `jet_cad.object_layer` or `floor_planner.*` could leak in as kits. `isKitId` is `^[a-z][a-z0-9]*$` (jet_cad_2d_kit/lib/src/model/kit_ids.dart:5), so underscore prefixes are excluded as the brief intends.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **manifest.dart:65-70: `usedKitsIn.add` re-implements `kitOfKey`.** The contract's `kitOfKey` (kit_ids.dart:31-34) is listed in the brief's Consumes block. A local `indexOf('.')`/`substring` repeats it. Fix: `if (!id.contains('.')) return; final kit = kitOfKey(id);`. Brief-mandated code, polish only.

2. **plan_file.dart:38-40: `decodePlan` loses the original error.** `catch (e)` turns every throw from the engine decode into `schema` with only `'$e'` in the message. That includes `Error`s, and also a bug in the host's own `register` callback (for example, an `ArgumentError` from a duplicate registration). The original object and stack trace are lost. This is intended per the brief; the report's self-review states it. It still makes host bugs look like damaged files. Fix: keep the stack with `Error.throwWithStackTrace(PlanFormatException(...), st)`, or narrow the catch so `register`'s own throws escape. Both would need a brief/contract ruling.

3. **plan_file.dart:32-37: a refused load can still write to the caller's diagnostics.** The codec appends tree-repair diagnostics (json_codec.dart:138) and `component.unreadable` diagnostics (json_codec.dart:143-146) before steps that can still throw: `json['rawData']! as Map` at json_codec.dart:147, and the fills rebuild. Such a load is refused as `schema`, but the caller's list keeps entries for a document that was never returned. This conflicts with "a load refuses by code and changes nothing" (the plan_file_test.dart header). Fix: decode into a local list, then `diagnostics.addAll(local)` only after success. The real risk depends on Task 8 passing a long-lived list (⚠️ above).

4. **No test pins "saving never mutates the document" (plan decision).** If `encodePlan` wrote the new manifest onto `d` (for example with a `SetComponentCommand<ManifestComponent>` before encoding), no test would go red. PF-6 and PF-9 encode once per decode and never re-read `manifestOf(d)` or the history afterwards. Suggested test: after `encodePlan(d, loaded)`, assert `manifestOf(d)` equals the manifest read and `d.commands.canUndo` is unchanged, with a named mutation.

5. **manifest.dart:69: the reserved kit id `plan` is not excluded the way `jetcad` is.** No `plan.*` component type exists today (grep of `componentTypeId = '` in jet_cad_2d, jet_cad_2d_kit and jet_cad_2d_plan lib). If a later task registers one, `usedKits` would report a kit `plan` and `checkManifest` would call it `kitMissing`. The brief only names `jetcad`, so this is a forward risk only.

6. **semver.dart:28-34: the overflow guard depends on the VM.** On the VM, `int.tryParse('99999999999999999999')` returns null. On the web it returns a value, so the PF-7u case `'99999999999999999999.0.0'` would parse there. This matters only if the package's tests or the library run on the web.

### Assessment

**Task quality:** Approved

**Reasoning:** The implementation follows the brief and spec P4/P5 and ruling R-c exactly. All 17 named mutations are reported red with quoted output, and the refusal codes, manifest write rules, semver precedence and byte-stable save are each pinned by a test. The remaining items are polish: duplicated helper logic, a lost cause on `schema`, and diagnostics written on a refused load. None of them blocks this task.
