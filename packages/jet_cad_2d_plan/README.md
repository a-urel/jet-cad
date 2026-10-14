# jet_cad_2d_plan

The plan library of jet_cad_2d. A `PlanController` owns one plan — its
document, the parametric system over it, the camera, the selection, the
tools, the undo history — and the design-mode widgets take only the
controller: `PlanCanvas`, `PlanToolPalette`, `PlanSymbolGallery`,
`PlanPropertyPanel`, `PlanLayerPanel`, `PlanPagePanel` and `PlanShortcuts`,
or `PlanEditor`, which lays them out as one editor.

What a plan holds beyond lines and shapes comes from **kits**
(`package:jet_cad_2d_kit`): their parametric types, tools, attachment
providers and symbol libraries. The library knows no domain. A plan that
names a kit the host did not load opens, draws and saves its objects
unchanged, and locks them; a kit whose code fails is contained to the
objects it broke.

## Use

```dart
// PlanEditor over an empty plan with no kit: the plan library's own tools,
// the layers and the page. Run from the package directory with
// `flutter run -t example/main.dart`.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePlanFonts();
  registerFontLicences();
  runApp(const PlanExampleApp());
}

class PlanExampleApp extends StatefulWidget {
  const PlanExampleApp({super.key});

  @override
  State<PlanExampleApp> createState() => PlanExampleAppState();
}

class PlanExampleAppState extends State<PlanExampleApp> {
  /// One plan and no kit: a kit package adds its types, tools and symbols
  /// through `PlanController(kits: [...])`.
  final PlanController controller = PlanController(kits: const []);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: Scaffold(body: PlanEditor(controller: controller)),
      );
}
```

- `PlanController.save()` and `load(text)` read and write a plan;
  `export('plan.pdf' or 'plan.png', choice)` and `print(choice)` make its
  page's bytes; a host adds its own exporters and importers.
- `PlanPermissions` decide what the editor lets a user change.
- The kit author's contract is `docs/kits.md` in the repository.

Version 0.8.0 is unreleased: it ships with the kits of the next wave.
