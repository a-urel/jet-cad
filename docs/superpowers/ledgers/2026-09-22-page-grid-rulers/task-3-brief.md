### Task 3: The codec hook, and the two round-trip tests

**Files:**
- Modify: `lib/src/codec/json_codec.dart`
- Test: `test/codec/page_component_roundtrip_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
// test/codec/page_component_roundtrip_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

DraftDocument withPage() {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(SetComponentCommand<PageComponent>(
    doc.rootHandle,
    PageComponent(
        widthMm: 215.9, heightMm: 279.4, orientation: PageOrientation.portrait,
        scaleDenominator: 48, originX: 7350, originY: -1230,
        displayUnit: DisplayUnit.feetInches, background: 0xFFFAF6EC,
        gridStepMm: 152.4, pageBreaks: true),
  ));
  return doc;
}

void main() {
  test('the page round-trips typed when the load registers it, and the '
      'bytes are stable', () {
    // M-04d: registering after loadJson makes the typed value null.
    final doc = withPage();
    final original = doc.components.get<PageComponent>(doc.rootHandle)!;
    final first = DraftDocumentCodec.encodeToString(doc);

    final back = DraftDocumentCodec.decodeString(first,
        registerComponents: PageComponent.register);

    expect(back.components.get<PageComponent>(back.rootHandle), original);
    expect(back.components.unknownOf(back.rootHandle), isEmpty);
    expect(DraftDocumentCodec.encodeToString(back), first);
  });

  test('without registration the bytes survive but the type does not — '
      'which is why the typed assertion above exists', () {
    final doc = withPage();
    final first = DraftDocumentCodec.encodeToString(doc);

    final back = DraftDocumentCodec.decodeString(first);

    expect(() => back.components.get<PageComponent>(back.rootHandle),
        anyOf(returnsNormally, throwsA(anything)));
    final unknown = back.components.unknownOf(back.rootHandle);
    expect(unknown, hasLength(1));
    expect(unknown.single['typeId'], PageComponent.componentTypeId);
    expect(DraftDocumentCodec.encodeToString(back), first);
  });

  test('decode (the map form) takes the same hook', () {
    final doc = withPage();
    final json = DraftDocumentCodec.encode(doc);
    final back = DraftDocumentCodec.decode(json,
        registerComponents: PageComponent.register);
    expect(back.components.get<PageComponent>(back.rootHandle),
        doc.components.get<PageComponent>(doc.rootHandle));
  });
}
```

(In test 2, `get<PageComponent>` on a registry that never registered the
type returns null through `_stores[T]?[handle]`; replace the `anyOf` with
`expect(back.components.get<PageComponent>(back.rootHandle), isNull)` once
you have confirmed that by running it — the `anyOf` is only there so the
first run cannot fail for the wrong reason.)

- [ ] **Step 2: Run to fail** (no named parameter `registerComponents`).

- [ ] **Step 3: Implement.** In `decode`, add the parameter and call it
  right after `DraftDocument.empty(...)`:

```dart
    void Function(ComponentRegistry registry)? registerComponents,
  }) {
    ...
    final doc = DraftDocument.empty(
      measurer: measurer, permissions: permissions, undoLimit: undoLimit);
    // Before the components load, so an application type comes back typed
    // rather than as preserve-unknown bytes (spec 04 D9). After it would be
    // M-04d: the payload lands in `_unknown` and `get<T>` is null.
    registerComponents?.call(doc.components);
```

Add the same parameter to `decodeString` and forward it.

- [ ] **Step 4: Run to pass**, then the `jet_cad_2d` gate line.
- [ ] **Step 5: Commit** — `feat(codec): registerComponents hook on decode
  and decodeString`.

---

