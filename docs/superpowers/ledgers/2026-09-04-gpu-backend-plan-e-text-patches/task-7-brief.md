### Task 7: The harness draws text, and measures it

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Create: `apps/dev_harness_2d/test/spike_text_test.dart`
- Modify: `.vscode/launch.json`

**Interfaces:**
- Consumes: everything Tasks 1–6 produce; `harnessMeasurer`, `kDrawText`,
  `kMeasurementViewport`, `_intDefine`/`String.fromEnvironment` patterns,
  `AddEntityCommand`, `doc.handleSeed.next()`.
- Produces: `kSpikeText` (`SPIKE_TEXT`, `'false'` default, throws on any
  other string — `kSpikeFills`'s shape); `spikeDocument({..., bool? text})`;
  `_addPatchedLabels(doc, entityCount)`; `GpuSpikeApp(drawText:)`;
  `GpuSpikeState.textOps, patches, subBufferBytes, patchTargetBytes,
  classifyMs`; new GSPIKE lines.

- [ ] **Step 1: Harness tests first**

Create `apps/dev_harness_2d/test/spike_text_test.dart`, modelled on
`spike_fill_scale_test.dart`:

```dart
import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const int _kEntities = 2000;

int _textCount(DraftDocument doc) {
  var n = 0;
  for (final slot in doc.entities.liveSlots) {
    final k = doc.entities.kindAt(slot);
    if (k == EntityKind.text || k == EntityKind.attrib) n++;
  }
  return n;
}

void main() {
  test('SPIKE_TEXT is inert at its default', () {
    expect(_textCount(spikeDocument(entityCount: _kEntities)), 0);
    expect(_textCount(spikeDocument(entityCount: _kEntities, text: false)), 0);
  });

  test('with text on, the corpus carries labels, and some are patched', () {
    final doc = spikeDocument(entityCount: _kEntities, text: true);
    expect(_textCount(doc), greaterThan(0));
    // Collect at the fitted camera and classify, exactly as the arm does:
    // the deliberate patched labels must be patches, or criterion 11 has
    // nothing to measure.
    final index = SpatialIndex(doc);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final collector = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: 1.0,
        measurer: harnessMeasurer,
        textStyleOf: doc.textStyleOf);
    final camera = ViewportTransform.fit(doc.extents, kMeasurementViewport);
    painter.paint(collector, camera, kMeasurementViewport);
    final patches = classifyTextPatches(
        collector.data, collector.instanceCount, collector.texts,
        devicePixelRatio: 1.0);
    expect(collector.skippedOps, 0, reason: 'text is drawn now');
    expect(patches.length, greaterThanOrEqualTo(kPatchedLabelCount),
        reason: 'every deliberate patched label is a patch');
    index.dispose();
  });
}
```

- [ ] **Step 2: `main.dart`**

Beside `kSpikeFills`:

```dart
/// Whether the GPU spike corpus carries text -- Plan E's Task 7. Same shape
/// and same reason as [kSpikeFills]: a `String.fromEnvironment` that throws
/// on anything but `true`/`false`, inert at `false` so every number a run
/// took before this define existed is reproducible unchanged.
///
/// On, [spikeDocument] generates labels at [harnessDocument]'s own fractions
/// (`labelFraction: 0.02`, `attributedInstanceFraction: 0.2`) and adds
/// [kPatchedLabelCount] deliberate **patched** labels through
/// [_addPatchedLabels]: a label, then a thick solid stroke of higher handle
/// through its middle. Criterion 11 requires at least one such label or the
/// text-pass number measures nothing.
final bool kSpikeText = switch (
    const String.fromEnvironment('SPIKE_TEXT', defaultValue: 'false')) {
  'false' => false,
  'true' => true,
  final other =>
    throw StateError('SPIKE_TEXT must be true or false; got "$other"'),
};

/// Deliberate patched labels [_addPatchedLabels] adds. Eight: enough to put
/// a patch on screen at the fitted camera and under every pan step, few
/// enough that the corpus is still the measured corpus plus text.
const int kPatchedLabelCount = 8;

/// A label the fitted camera can read -- 600 units is ~13.5 logical px at
/// 0.0225 px/unit, above `kMinTextCapPixels` at every band scale.
const double kPatchedLabelHeight = 600.0;

/// Adds [kPatchedLabelCount] labels, each followed (higher handle) by a solid
/// stroke of lineweight 100 through its middle -- so each is a patch by
/// construction. Placed in the corridor `_addFillRegions` uses, spaced along
/// x, so a pan of `(4, 0)` per frame keeps at least one on screen.
void _addPatchedLabels(DraftDocument doc, int entityCount) {
  final centerX = kDefaultOriginX + kFloorWidth / 2;
  final centerY = kOriginY + kFloorHeight / 2;
  for (var i = 0; i < kPatchedLabelCount; i++) {
    final x = centerX - 3000.0 + i * 800.0;
    final y = centerY - 750.0;
    final label = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: label,
        owner: doc.rootHandle,
        kind: EntityKind.text,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: 0,
        flags: 0,
        text: 'ROOM ${i + 1}',
        textStyle: ReservedHandles.standardTextStyle,
        textAttrs: packTextAttrs(),
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([x, y]),
        scalars: Float64List.fromList([kPatchedLabelHeight, 0, 1, 0]),
      ),
    ));
    final stroke = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: stroke,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 100,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(
            [x - 100, y + kPatchedLabelHeight * 0.4, x + 2500, y + kPatchedLabelHeight * 0.4]),
        scalars: Float64List(0),
      ),
    ));
  }
}
```

`packTextAttrs`, `kByLayer`, `kDefaultOriginX`, `kFloorWidth`, `kOriginY`,
`kFloorHeight` are what `_addFillRegions` and `addText` (in the flutter
package's fixtures) already use; copy their imports.

`spikeDocument` gains `bool? text`:

```dart
DraftDocument spikeDocument(
    {int? entityCount, bool? fillsEnabled, double? fillScale, bool? text}) {
  final count = entityCount ?? kEntities;
  final withText = text ?? kSpikeText;
  final doc = generateDocument(
    count,
    ...,
    labelFraction: withText ? 0.02 : 0,
    attributedInstanceFraction: withText ? 0.2 : 0,
    measurer: harnessMeasurer,
  );
  if (fillsEnabled ?? kSpikeFills) {
    _addFillRegions(doc, count, sizeScale: fillScale ?? kSpikeFillScale);
  }
  if (withText) _addPatchedLabels(doc, count);
  return doc;
}
```

`GpuSpikeApp(document: spikeDocument(), ..., drawText: kDrawText)`.

- [ ] **Step 3: `gpu_arm.dart`**

- `GpuSpikeApp` gains `required this.drawText`; `_buildResidentGeometry`
  passes `drawText: widget.drawText` to `DraftPainter` (replacing the
  hard-coded `true` and rewriting the comment beside it: with text drawn by
  the arm, `DRAW_TEXT=false` is now the criterion-11 control, not a way to
  undercount).
- The collector: `measurer: harnessMeasurer, textStyleOf:
  widget.document.textStyleOf`.
- After the walk: `final classifyWatch = Stopwatch()..start(); final patches
  = classifyTextPatches(collector.data, collector.instanceCount,
  collector.texts, devicePixelRatio: dpr); classifyWatch.stop();` — `dpr`
  read once from `MediaQuery` beside the existing read.
- `ResidentGeometry.create(collector.data, collector.instanceCount, texts:
  collector.texts, patches: patches, devicePixelRatio: dpr, maxPatchWidth:
  (widget.viewport.width * dpr).round(), maxPatchHeight:
  (widget.viewport.height * dpr).round())`.
- `GpuDrawBackend(geometry, collectionCamera, measurer: harnessMeasurer,
  textStyleOf: widget.document.textStyleOf)`.
- `GpuArmPainter.paint`: replace the `render` + `drawImageRect` pair with
  `backend.paint(canvas, camera.value, size, devicePixelRatio);` and rewrite
  its ownership comment: the main image and each patch image are now handles
  the compositor records into the picture, same lifetime argument, `1 + P`
  per frame instead of one.
- The `GSPIKE collect+upload` line grows: `textOps=N patches=P
  subBuffer=X.XX MB patchTargets=Y.YY MB classify=Z.Z ms` — `subBuffer` is
  `geometry.byteLength - ResidentGeometry.byteLengthFor(instanceCount)`.
- Per phase, arm C: a new line `GSPIKE C | phase | patches rendered=R
  clipped=C offscreen=O` from the backend's counters read after the phase.
- The `GSPIKE note` text: remove "text: Plan E's job"; say text is drawn
  through the compositor and how many patches the corpus has; say
  `DRAW_TEXT=false` is the criterion-11 control.
- The section comment at the top of the file: rewrite the paragraph *"What
  arm C still does not draw"* — nothing, since Plan E; what remains not
  wired is `DraftCanvas` (Plan F).

- [ ] **Step 4: `launch.json`**

Two configurations after the fills pair, same shape:

- `2d: GPU spike -- text ON (criterion 11, DRAW_TEXT=true)`: the measurement
  scale's defines plus `--dart-define=SPIKE_TEXT=true`.
- `2d: GPU spike -- text ON, DRAW_TEXT=false (criterion 11 control)`: the
  same plus `--dart-define=DRAW_TEXT=false`.

With a comment on each saying the pair is read as a difference and neither
number means anything alone.

- [ ] **Step 5: All three gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add apps/dev_harness_2d/lib/main.dart apps/dev_harness_2d/lib/gpu_arm.dart \
  apps/dev_harness_2d/test/spike_text_test.dart .vscode/launch.json
git commit -m "feat(harness): arm C draws text, and SPIKE_TEXT puts labels it must patch in the corpus"
```

---

