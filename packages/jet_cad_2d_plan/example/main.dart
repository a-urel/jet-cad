// PlanEditor over an empty plan with no kit: the plan library's own tools,
// the layers and the page; a button in each bar switches to the service
// mode and back. Run from the package directory with
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

  /// Switches the plan to [next]: the service mode works on a copy, so
  /// nothing done there reaches the saved plan.
  Widget modeButton(PlanMode next) => IconButton(
        key: Key('example-${next.name}'),
        tooltip: next.name,
        icon: Icon(next == PlanMode.service
            ? Icons.room_service_outlined
            : Icons.edit_outlined),
        onPressed: () => controller.setMode(next),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: Scaffold(
          body: PlanEditor(
            controller: controller,
            bar: PlanEditorBar(trailing: [modeButton(PlanMode.service)]),
            serviceBar: PlanServiceBar(trailing: [modeButton(PlanMode.design)]),
          ),
        ),
      );
}
