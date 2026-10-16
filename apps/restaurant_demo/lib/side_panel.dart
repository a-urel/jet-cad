// The demo's side panel: Save, Revert, Reset layout and Fit, the POS links,
// the pointer line, the service options, the table numbers field, the
// statuses, the tables and groups lines with the numbering warnings, the
// zones, the badges, the host's choices (the editor's profile, the own bar,
// the own export dialog, who owns the keys) and the log. A view over
// `DemoHomeState`; the state is the demo's, the actions are its methods.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

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
    final title = Theme.of(context).textTheme.titleSmall;
    return ListView(
      key: const Key('side-panel'),
      padding: const EdgeInsets.all(12),
      children: [
        Text(a.name, style: title),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ValueListenableBuilder<bool>(
            valueListenable: c.dirty,
            builder: (_, dirty, __) => FilledButton(
                key: const Key('save'),
                onPressed: dirty ? home.save : null,
                child: Text(words.save)),
          ),
          OutlinedButton(
              key: const Key('revert'),
              onPressed: home.revert,
              child: Text(words.revert)),
          if (service)
            OutlinedButton(
                key: const Key('reset-layout'),
                onPressed: home.resetLayout,
                child: Text(words.resetLayout)),
          OutlinedButton(
              key: const Key('fit'),
              onPressed: c.fitToView,
              child: Text(words.fit)),
        ]),
        // The POS's ids written into the design.
        if (!service) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                    key: const Key('link-tables'),
                    onPressed: () => home.link(a),
                    child: Text(words.linkTables)),
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
          SwitchListTile(
              key: const Key('moves'),
              contentPadding: EdgeInsets.zero,
              title: Text(words.moves),
              value: home.moves,
              onChanged: home.setMoves),
          SwitchListTile(
              key: const Key('long-press-menu'),
              contentPadding: EdgeInsets.zero,
              title: Text(words.longPressMenu),
              value: home.longPressMenu,
              onChanged: home.setLongPressMenu),
          SwitchListTile(
              key: const Key('floor-band'),
              contentPadding: EdgeInsets.zero,
              title: Text(words.floorBand),
              value: home.floorBand,
              onChanged: home.setFloorBand),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('select-number'),
          controller: home.numberField,
          decoration: InputDecoration(labelText: words.tableNumbersField),
          onSubmitted: (_) => home.selectTyped(),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
            key: const Key('select'),
            onPressed: home.selectTyped,
            child: Text(words.select)),
        const SizedBox(height: 16),
        Text(words.statusOfSelected, style: title),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final name in kStatuses.keys)
            OutlinedButton(
                key: Key('status-${name.toLowerCase()}'),
                onPressed: () => home.setStatus(name),
                child: Text(words.statusName(name))),
          OutlinedButton(
              key: const Key('status-random'),
              onPressed: home.randomStatuses,
              child: Text(words.randomStatuses)),
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
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        // Only an area with zones; below the lines the tests read, above the
        // host's choices.
        if (a.zones.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(words.zones, style: title),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            key: const Key('zone-toggle'),
            showSelectedIcon: false,
            segments: [
              // '' is All: a zone name is never empty.
              ButtonSegment(
                  value: '',
                  label: Text(words.allZones, key: const Key('zone-all'))),
              for (final zone in a.zones.keys)
                ButtonSegment(
                    value: zone, label: Text(zone, key: Key('zone-$zone'))),
            ],
            selected: {a.zone ?? ''},
            onSelectionChanged: (s) =>
                home.setZone(a, s.single.isEmpty ? null : s.single),
          ),
          SwitchListTile(
              key: const Key('fade-others'),
              contentPadding: EdgeInsets.zero,
              title: Text(words.fadeOthers),
              value: a.fadeOthers,
              onChanged: (v) => home.setFadeOthers(a, v)),
        ],
        // The Salon's badges and its table 7, in the service; below the
        // zones, above the host's choices.
        if (a.offersBadges && service) ...[
          const SizedBox(height: 16),
          SwitchListTile(
              key: const Key('badges'),
              contentPadding: EdgeInsets.zero,
              title: Text(words.badges),
              value: a.badges,
              onChanged: (v) => home.setBadges(a, v)),
          OutlinedButton(
              key: const Key('center-7'),
              onPressed: () => home.centerOnSeven(a),
              child: Text(words.centerOnTable('7'))),
        ],
        const SizedBox(height: 16),
        Text(words.hostChoices, style: title),
        if (!service) ...[
          const SizedBox(height: 4),
          Text(words.editor),
          const SizedBox(height: 4),
          SegmentedButton<DemoEditor>(
            key: const Key('editor-profile'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: DemoEditor.full,
                  label: Text(words.editorFull, key: const Key('editor-full'))),
              ButtonSegment(
                  value: DemoEditor.tables,
                  label: Text(words.editorTables,
                      key: const Key('editor-tables'))),
              ButtonSegment(
                  value: DemoEditor.readOnly,
                  label: Text(words.editorReadOnly,
                      key: const Key('editor-read-only'))),
            ],
            selected: {home.editor},
            onSelectionChanged: (s) => home.setEditor(s.single),
          ),
        ],
        if (service)
          SwitchListTile(
              key: const Key('own-bar'),
              contentPadding: EdgeInsets.zero,
              title: Text(words.ownBar),
              value: home.ownBar,
              onChanged: home.setOwnBar),
        SwitchListTile(
            key: const Key('own-export-dialog'),
            contentPadding: EdgeInsets.zero,
            title: Text(words.ownExportDialog),
            value: home.ownExportDialog,
            onChanged: home.setOwnExportDialog),
        SwitchListTile(
            key: const Key('plan-keys'),
            contentPadding: EdgeInsets.zero,
            title: Text(words.planKeys),
            value: home.planKeys,
            onChanged: home.setPlanKeys),
        const SizedBox(height: 16),
        Text(words.log, style: title),
        for (final (i, line) in home.log.indexed)
          Text(line, key: Key('log-$i')),
      ],
    );
  }
}
