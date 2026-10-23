// The demo's side panel: Save, Revert, Reset layout and Fit, the POS links,
// the pointer line, the service options, the table numbers field, the
// statuses, the tables and groups lines with the numbering warnings, the
// zones, the badges, the host's choices (the editor's profile, the own bar,
// the own export dialog, who owns the keys) and the log. A view over
// `DemoHomeState`; the state is the demo's, the actions are its methods.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'demo_strings.dart';
import 'editor_profiles.dart';
import 'groups.dart';
import 'main.dart';
import 'pos_links.dart';
import 'statuses.dart';

class DemoSidePanel extends StatelessWidget {
  const DemoSidePanel({super.key, required this.home});

  final DemoHomeState home;

  @override
  Widget build(BuildContext context) {
    final words = DemoStrings.of(context);
    final a = home.area;
    final c = a.controller;
    final service = c.mode.value == PlanMode.service;
    final shad = ShadTheme.of(context);
    final title = shad.textTheme.small.copyWith(fontWeight: FontWeight.w600);
    return ListView(
      key: const Key('side-panel'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(a.name, style: shad.textTheme.large),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ValueListenableBuilder<bool>(
            valueListenable: c.dirty,
            builder: (_, dirty, __) => ShadButton(
                key: const Key('save'),
                onPressed: dirty ? home.save : null,
                child: _label(words.save)),
          ),
          ShadButton.outline(
              key: const Key('revert'),
              onPressed: home.revert,
              child: _label(words.revert)),
          if (service)
            ShadButton.outline(
                key: const Key('reset-layout'),
                onPressed: home.resetLayout,
                child: _label(words.resetLayout)),
          ShadButton.outline(
              key: const Key('fit'),
              onPressed: c.fitToView,
              child: _label(words.fit)),
        ]),
        // The POS's ids written into the design.
        if (!service) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ShadButton.outline(
                    key: const Key('link-tables'),
                    onPressed: () => home.link(a),
                    child: _label(words.linkTables)),
                Text(words.unlinked(home.unlinkedTables(a).length),
                    key: const Key('unlinked')),
              ]),
        ],
        if (service) ...[
          // One line, rebuilt alone.
          const SizedBox(height: 8),
          ValueListenableBuilder<PointerLine?>(
            valueListenable: home.pointer,
            builder: (context, line, _) => Text(
                key: const Key('pointer-line'),
                switch (line) {
                  null => '',
                  (table: final n?, floor: _) => words.overTable(n),
                  (table: null, floor: final w?) => words.floorAt(w.dx, w.dy),
                  (table: null, floor: null) => words.overNoTable,
                }),
          ),
          _toggle(const Key('moves'), Text(words.moves),
              value: home.moves, onChanged: home.setMoves),
          _toggle(const Key('long-press-menu'), Text(words.longPressMenu),
              value: home.longPressMenu, onChanged: home.setLongPressMenu),
          _toggle(const Key('floor-band'), Text(words.floorBand),
              value: home.floorBand, onChanged: home.setFloorBand),
        ],
        const SizedBox(height: 16),
        Text(words.tableNumbersField, style: shad.textTheme.muted),
        const SizedBox(height: 4),
        ShadInput(
          key: const Key('select-number'),
          controller: home.numberField,
          onPressedOutside: (_) {},
          onSubmitted: (_) => home.selectTyped(),
        ),
        const SizedBox(height: 8),
        ShadButton.secondary(
            key: const Key('select'),
            onPressed: home.selectTyped,
            child: _label(words.select)),
        const SizedBox(height: 16),
        Text(words.statusOfSelected, style: title),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final name in kStatuses.keys)
            ShadButton.outline(
                key: Key('status-${name.toLowerCase()}'),
                onPressed: () => home.setStatus(name),
                child: _label(words.statusName(name))),
          ShadButton.outline(
              key: const Key('status-random'),
              onPressed: home.randomStatuses,
              child: _label(words.randomStatuses)),
        ]),
        const SizedBox(height: 16),
        Text(words.tables, style: title),
        Text(
            key: const Key('tables'),
            c.units.isEmpty
                ? words.none
                : [for (final u in c.units) '${u.label ?? '—'} (${u.capacity})']
                    .join(', ')),
        const SizedBox(height: 8),
        Text(words.groups, style: title),
        Text(key: const Key('groups'), groupsText(c, words)),
        for (final (i, w) in c.labelWarnings.indexed)
          Text(PlanStrings.of(context).labelWarning(w),
              key: Key('numbering-warning-$i'),
              style: shad.textTheme.small
                  .copyWith(color: shad.colorScheme.destructive)),
        const SizedBox(height: 16),
        Text(words.sections, style: title),
        // Each table's section, read from the details: the record the room
        // is linked to, so it follows a table moved into another room.
        Text(
            key: const Key('table-sections'),
            [
              for (final (label, section) in tableSections(a, words.notLinked))
                '$label: ${section ?? words.none}'
            ].join(', ')),
        if (!service)
          ShadButton.outline(
              key: const Key('link-sections'),
              onPressed: () => home.linkAreaSections(a),
              child: _label(words.linkSections)),
        // Only an area with zones; below the lines the tests read, above the
        // host's choices.
        if (a.zones.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(words.zones, style: title),
          const SizedBox(height: 4),
          ShadTabs<String>(
            key: const Key('zone-toggle'),
            scrollable: true,
            // '' is All: a zone name is never empty.
            value: a.zone ?? '',
            onChanged: (z) => home.setZone(a, z.isEmpty ? null : z),
            tabs: [
              ShadTab(
                  flex: 0,
                  value: '',
                  child: Text(words.allZones, key: const Key('zone-all'))),
              for (final zone in a.zones.keys)
                ShadTab(
                    flex: 0,
                    value: zone,
                    child: Text(zone, key: Key('zone-$zone'))),
            ],
          ),
          const SizedBox(height: 8),
          _toggle(const Key('fade-others'), Text(words.fadeOthers),
              value: a.fadeOthers, onChanged: (v) => home.setFadeOthers(a, v)),
        ],
        // The Salon's badges and its table 7, in the service; below the
        // zones, above the host's choices.
        if (a.offersBadges && service) ...[
          const SizedBox(height: 16),
          _toggle(const Key('badges'), Text(words.badges),
              value: a.badges, onChanged: (v) => home.setBadges(a, v)),
          ShadButton.outline(
              key: const Key('center-7'),
              onPressed: () => home.centerOnSeven(a),
              child: _label(words.centerOnTable('7'))),
        ],
        const SizedBox(height: 16),
        Text(words.hostChoices, style: title),
        if (!service) ...[
          const SizedBox(height: 4),
          Text(words.editor, style: shad.textTheme.muted),
          const SizedBox(height: 4),
          ShadTabs<DemoEditor>(
            key: const Key('editor-profile'),
            scrollable: true,
            value: home.editor,
            onChanged: home.setEditor,
            tabs: [
              ShadTab(
                  flex: 0,
                  value: DemoEditor.full,
                  child: Text(words.editorFull, key: const Key('editor-full'))),
              ShadTab(
                  flex: 0,
                  value: DemoEditor.tables,
                  child: Text(words.editorTables,
                      key: const Key('editor-tables'))),
              ShadTab(
                  flex: 0,
                  value: DemoEditor.readOnly,
                  child: Text(words.editorReadOnly,
                      key: const Key('editor-read-only'))),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (service)
          _toggle(const Key('own-bar'), Text(words.ownBar),
              value: home.ownBar, onChanged: home.setOwnBar),
        _toggle(const Key('own-export-dialog'), Text(words.ownExportDialog),
            value: home.ownExportDialog, onChanged: home.setOwnExportDialog),
        _toggle(const Key('plan-keys'), Text(words.planKeys),
            value: home.planKeys, onChanged: home.setPlanKeys),
        const SizedBox(height: 16),
        Text(words.log, style: title),
        for (final (i, line) in home.log.indexed)
          Text(line, key: Key('log-$i')),
      ],
    );
  }
}

/// A switch with its label, as wide as its content: the switch is the whole
/// of what a click lands on, not the row it sits in.
Widget _toggle(Key key, Widget label,
        {required bool value, required ValueChanged<bool>? onChanged}) =>
    Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ShadSwitch(
                key: key, label: label, value: value, onChanged: onChanged)));

/// A button's label: it wraps within the button instead of overflowing it
/// (a `ShadButton` lays its child out in a row, unbounded).
Widget _label(String text) => Flexible(child: Text(text));
