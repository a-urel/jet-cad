// The README of packages/jet_cad_floor_plan, its Dart blocks verbatim.
import 'package:flutter/material.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

Widget appFor() {
  final symbols = SymbolLibraryLoader(sources: const [furnitureSymbolSource]);
  final controller = FloorPlanController(symbols: symbols);

  final app = MaterialApp(
    supportedLocales: floorPlanSupportedLocales,
    localizationsDelegates: floorPlanLocalizationsDelegates,
    home: Scaffold(body: FloorPlanView(controller: controller)),
  );
  return app;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFloorPlanFonts();
  registerFontLicences();
}

SymbolLibraryLoader loaderWith(SymbolLibrarySource mySymbolSource) {
  final loader = SymbolLibraryLoader(
    sources: [furnitureSymbolSource, mySymbolSource],
  );
  return loader;
}
