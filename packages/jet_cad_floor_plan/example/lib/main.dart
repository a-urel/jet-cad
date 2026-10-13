// The floor planner over an empty plan, with the furniture library the
// package ships. Run from the package directory with
// `flutter run -t example/lib/main.dart`.
import 'package:flutter/material.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFloorPlanFonts();
  registerFontLicences();
  runApp(const FloorPlanExampleApp());
}

class FloorPlanExampleApp extends StatefulWidget {
  const FloorPlanExampleApp({super.key});

  @override
  State<FloorPlanExampleApp> createState() => FloorPlanExampleAppState();
}

class FloorPlanExampleAppState extends State<FloorPlanExampleApp> {
  /// One loader for the furniture library the package ships.
  final SymbolLibraryLoader symbols =
      SymbolLibraryLoader(sources: const [furnitureSymbolSource]);

  late final FloorPlanController controller =
      FloorPlanController(symbols: symbols);

  @override
  void dispose() {
    controller.dispose();
    symbols.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: floorPlanLocalizationsDelegates,
        home: Scaffold(body: FloorPlanView(controller: controller)),
      );
}
