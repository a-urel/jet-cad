// The app's root and dialogs (spec D1, D5, D6): a plain `ShadApp` in the zinc
// theme, no `MaterialApp`; the Material theme the canvas reads is the one
// `ShadApp` derives from the `ShadTheme`. The error dialog, the Save / Don't
// Save / Cancel dialog and the web's name prompt are shadcn's, and the last
// two work from the keyboard alone.
import 'dart:async';

import 'package:architecture_demo/app_theme.dart';
import 'package:architecture_demo/document_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'support/app_rig.dart';

/// Whether the primary focus is the widget keyed [key], or inside it.
bool focusIn(WidgetTester tester, String key) {
  final node = FocusManager.instance.primaryFocus;
  if (node?.context == null) return false;
  return find
      .descendant(
          of: find.byKey(Key(key)),
          matching: find.byElementPredicate((e) => e == node!.context),
          matchRoot: true)
      .evaluate()
      .isNotEmpty;
}

void main() {
  testWidgets(
      'AD1 the root is one ShadApp: no MaterialApp, no Scaffold of the '
      'demo\'s own, and Open sample is a ShadIconButton', (tester) async {
    await pumpApp(tester);
    expect(find.byType(ShadApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsNothing);
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(
        find.ancestor(
            of: find.byType(PlanEditor), matching: find.byType(Scaffold)),
        findsNothing,
        reason: 'only the editor\'s own Scaffold, below it');
    expect(tester.widget(find.byKey(const Key('toolbar-open-sample'))),
        isA<ShadIconButton>());
    expect(
        await tooltipShows(tester, find.byKey(const Key('toolbar-open-sample')),
            'Open sample'),
        isTrue);
    final context = tester.element(find.byType(PlanEditor));
    final brightness = tester.platformDispatcher.platformBrightness;
    expect(ShadTheme.of(context).colorScheme,
        appShadTheme(brightness).colorScheme);
  });

  testWidgets('AD2 the derived Material theme follows the platform brightness',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    for (final b in [Brightness.dark, Brightness.light]) {
      tester.platformDispatcher.platformBrightnessTestValue = b;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(PlanEditor));
      expect(Theme.of(context).brightness, b);
      expect(Theme.of(context).colorScheme.surface,
          appShadTheme(b).colorScheme.background);
      expect(ShadTheme.of(context).brightness, b);
    }
  });

  testWidgets(
      'AD3 a failed open shows a ShadDialog with its title and text; '
      'OK closes it', (tester) async {
    final rig = await pumpApp(tester);
    rig.files.scriptOpenThrow(StateError('no such file'));
    unawaited(rig.host.openFlow());
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('document-error')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('document-error'))),
        isA<ShadDialog>());
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-title'))).data,
        isNotEmpty);
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-text'))).data,
        contains('no such file'));
    expect(tester.widget(find.byKey(const Key('document-error-ok'))),
        isA<ShadButton>());
    await dismissError(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('document-error')), findsNothing);
  });

  testWidgets(
      'AD4 with the plan dirty, New asks in a ShadDialog: Save has the focus, '
      'Escape cancels, a tap outside does nothing; the name prompt takes '
      'Enter', (tester) async {
    final rig = await pumpApp(tester);
    await rig.editOnce();
    final c = rig.controller;
    final before = c.document;
    expect(c.dirty.value, isTrue, reason: 'premise: dirty');

    var done = false;
    unawaited(rig.host.newFlow().then((_) => done = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byKey(const Key('replace-dialog'));
    expect(dialog, findsOneWidget);
    expect(tester.widget(dialog), isA<ShadDialog>());
    expect(focusIn(tester, 'replace-save'), isTrue,
        reason: 'Save has the focus');

    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(dialog, findsOneWidget, reason: 'a tap outside does nothing');
    expect(done, isFalse);

    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(dialog, findsNothing, reason: 'Escape closes it');
    expect(done, isTrue, reason: 'the flow ended on Cancel');
    expect(identical(c.document, before), isTrue,
        reason: 'Cancel leaves the plan');
    expect(c.dirty.value, isTrue);

    // The name prompt: the field is a ShadInput, focused, and Enter submits.
    final context = tester.element(find.byType(PlanEditor));
    final answer = showDocumentNamePrompt(context, 'Hall.jetplan');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.byKey(const Key('name-prompt-field'));
    expect(tester.widget(field), isA<ShadInput>());
    expect(focusIn(tester, 'name-prompt-field'), isTrue,
        reason: 'the field has the focus');
    expect(tester.widget<ShadInput>(field).controller!.text, 'Hall.jetplan');
    await tester.enterText(field, 'Kitchen.jetplan');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(await answer, 'Kitchen.jetplan');
  });

  testWidgets(
      'AD5 a bare Text takes the ShadTheme\'s text style (Roboto, the '
      'foreground), light and dark', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    for (final b in [Brightness.light, Brightness.dark]) {
      tester.platformDispatcher.platformBrightnessTestValue = b;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final theme = appShadTheme(b);
      final style =
          DefaultTextStyle.of(tester.element(find.byType(DocumentHost)));
      expect(style.style.fontFamily, 'Roboto', reason: '$b');
      expect(style.style.color, theme.colorScheme.foreground, reason: '$b');
      expect(style.style.fontSize, theme.textTheme.p.fontSize, reason: '$b');
    }
  });
}
