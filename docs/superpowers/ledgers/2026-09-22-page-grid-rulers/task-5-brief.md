### Task 5: `chrome_style.dart`, `page_fit.dart`, `PageNotifier`, the fixture

**Files:**
- Create: `lib/src/chrome_style.dart`, `lib/src/page_fit.dart`,
  `lib/src/page_notifier.dart`, `test/support/page_fixture.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (three exports now, six by Task 8)
- Test: `test/page_fit_test.dart`, `test/page_notifier_test.dart`

- [ ] **Step 1: The fixture.**

```dart
// test/support/page_fixture.dart
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The spec's standard fixture: an off-origin A4 landscape at 1:50 in
/// metres, partly visible under a zoomed, panned camera.
PageComponent standardPage() =>
    PageComponent(originX: 7350, originY: -1230);

CameraController standardCamera() => CameraController(ViewportTransform(
    worldToScreenMatrix:
        const Transform2(0.137, 0, 0, -0.137, -611.5, 412.25)));

const Size kChromeSize = Size(800, 600);

DraftDocument documentWithPage([PageComponent? page]) {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, page ?? standardPage()));
  return doc;
}
```

- [ ] **Step 2: Write the failing tests.**

```dart
// test/page_fit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';

void main() {
  test('fitToPage fits the sheet rect, not the extents', () {
    // M-04k's render half.
    final page = standardPage();
    final fitted = fitToPage(page, kChromeSize);
    final expected = ViewportTransform.fit(sheetWorldRect(page), kChromeSize);
    expect(fitted.scale, closeTo(expected.scale, 1e-12));
    final centre = sheetWorldRect(page).center;
    final s = fitted.worldToScreen(centre);
    expect(s.x, closeTo(400, 1e-6));
    expect(s.y, closeTo(300, 1e-6));
    expect(fitted.worldToScreen(Vector2(page.originX, page.originY)).y,
        greaterThan(300), reason: 'y flips: the bottom-left is below centre');
  });
}
```

```dart
// test/page_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/page_fixture.dart';

void main() {
  test('seeds from the document before any event', () {
    // M-04u.
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    expect(n.value, standardPage());
  });

  test('follows apply, undo and redo through the stream', () async {
    // M-04l (undo ignored).
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    final seen = <PageComponent?>[];
    n.addListener(() => seen.add(n.value));
    final edited = standardPage().copyWith(pageBreaks: true);

    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle, edited));
    await Future<void>.delayed(Duration.zero);
    doc.commands.undo();
    await Future<void>.delayed(Duration.zero);
    doc.commands.redo();
    await Future<void>.delayed(Duration.zero);

    expect(seen, [edited, standardPage(), edited]);
  });

  test('an unrelated edit and an equal value do not notify', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    var notified = 0;
    n.addListener(() => notified++);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage()));  // equal value
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: doc.handleSeed.next(), parent: doc.rootHandle,
        transform: Transform2.translation(5, 5), children: const [])));
    await Future<void>.delayed(Duration.zero);
    expect(notified, 0);
  });

  test('a load re-reads, and dispose stops listening', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage().copyWith(gridVisible: false)));
    await Future<void>.delayed(Duration.zero);
    doc.commands.notifyLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(n.value!.gridVisible, isFalse);
    n.dispose();
    expect(() => doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage())), returnsNormally);
  });
}
```

- [ ] **Step 3: Run to fail.**

- [ ] **Step 4: Implement.**

```dart
// lib/src/chrome_style.dart
import 'dart:ui' show Color;

/// Thickness of each ruler bar and the corner box, logical pixels.
const double kRulerThickness = 24.0;
const double kMajorTickPixels = 12.0;
const double kMinorTickPixels = 6.0;

/// Below this on-screen sheet size the page-break tiling is not drawn: the
/// bound at extreme zoom-out (spec D8).
const double kBreaksMinSheetPixels = 16.0;

const Color kSheetEdgeColor = Color(0xFF9E9E9E);
const Color kMajorGridColor = Color(0x33000000);
const Color kMinorGridColor = Color(0x14000000);
const Color kPageBreakColor = Color(0xFF3366CC);
const Color kRulerBackground = Color(0xFFF2F2F2);
const Color kRulerInk = Color(0xFF444444);
const Color kRulerPointer = Color(0xFFE53935);
const double kRulerLabelSize = 10.0;
```

```dart
// lib/src/page_fit.dart
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'viewport_transform.dart';

/// The camera that shows the whole sheet with `fit`'s 5 % margin (spec D4).
ViewportTransform fitToPage(PageComponent page, Size viewport) =>
    ViewportTransform.fit(sheetWorldRect(page), viewport);
```

```dart
// lib/src/page_notifier.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The document's page as a listenable (spec D10): seeded in the
/// constructor, re-read on any change that touches the root, on a load and
/// on a purge. `ValueNotifier` skips the notification when the value is
/// `==`, so an unrelated root edit costs its listeners nothing.
class PageNotifier extends ValueNotifier<PageComponent?> {
  PageNotifier(this.document)
      : super(document.components.get<PageComponent>(document.rootHandle)) {
    _subscription = document.changes.listen(_onChange);
  }

  final DraftDocument document;
  late final StreamSubscription<DocChange> _subscription;

  void _onChange(DocChange change) {
    final root = document.rootHandle;
    final refresh = switch (change) {
      CommandApplied(:final touched) ||
      CommandUndone(:final touched) ||
      CommandRedone(:final touched) =>
        touched.contains(root),
      DocumentLoaded() || DocumentPurged() => true,
    };
    if (refresh) value = document.components.get<PageComponent>(root);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
```

Exports: `src/chrome_style.dart`, `src/page_fit.dart`,
`src/page_notifier.dart`.

- [ ] **Step 5: Run to pass**, then the `jet_cad_2d_flutter` gate line.
- [ ] **Step 6: Commit** — `feat(render): chrome style, fitToPage,
  PageNotifier`.

---

