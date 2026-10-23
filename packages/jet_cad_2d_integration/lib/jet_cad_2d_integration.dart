/// Fixtures for the tests that run the architecture kit inside the plan
/// library's widgets (spec 3a C6), built over both packages' public
/// libraries only, as a host builds them. Not published. Later tasks add
/// their fixtures here.
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

/// A controller over the architecture kit whose plan is the sample flat
/// (spec C3.7, C1.9): built by the plan library, so it opens clean with
/// nothing to undo, its rooms named in the controller's words (English
/// until a locale is reported).
PlanController sampleFlatController() =>
    PlanController(kits: [architectureKit], build: buildSampleFlat);

/// [controller]'s `PlanEditor` in an app speaking [locale], with the plan
/// library's locales and delegates; its layer panel unless [layerPanel] is
/// false (3a Task 27: the 2a composition, the property panel above the
/// page panel).
Widget planEditorApp(PlanController controller,
        {Locale locale = const Locale('en'), bool layerPanel = true}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      // The planner's column as ported: every section under a selection.
      home: PlanEditor(
          controller: controller,
          layerPanel: layerPanel,
          contextualPanels: false),
    );
