/// Fixtures for the tests that run the architecture kit inside the plan
/// library's widgets (spec 3a C6), built over both packages' public
/// libraries only, as a host builds them. Not published. Later tasks add
/// their fixtures here (Task 25: `sampleFlatController`).
library;

import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// A controller over the architecture kit: a new plan (the kit's `prepare`
/// run on it), or [json] opened as it is.
PlanController architectureController(
        {String? json, PlanPermissions permissions = PlanPermissions.full}) =>
    PlanController(
        kits: [architectureKit], json: json, permissions: permissions);

/// [controller]'s `PlanEditor` in an app speaking [locale], with the plan
/// library's locales and delegates.
Widget planEditorApp(PlanController controller,
        {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: PlanEditor(controller: controller),
    );
