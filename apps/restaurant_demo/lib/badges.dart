// The Salon's badges: the host's own widget on each table of the service
// view, through `PlanEditor.unitOverlayBuilder`. Guests over seats and the
// minutes they have been seated, framed in the table's status colour,
// outlined when selected, a dot below the detail breakpoint, faded when the
// zone focus leaves the table out. The minutes are the host's live data: a
// tick rebuilds the counters inside the badge, never the overlays.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'demo_strings.dart';
import 'statuses.dart';

/// The areas whose service view offers badges on its tables: the Salon's.
const Set<String> kBadgeAreas = {'Salon'};

/// The camera scale, in logical pixels per millimetre, below which a badge
/// is a dot: the Salon fitted in a canvas 700 px wide or more is above it,
/// and a zoom out to half of that is below.
const double kBadgeDetailScale = 0.025;

/// Where the badges sit: at the bottom of each table's box on the screen,
/// so the table's number chip stays visible; a dot below
/// [kBadgeDetailScale]. The layer ignores pointers: a tap on a badge is the
/// table's.
const PlanOverlayLayout kBadgeLayout = PlanOverlayLayout(
  anchor: Alignment.bottomCenter,
  detailBreakpoints: [kBadgeDetailScale],
);

/// A badge's figures: the guests at table [number] of [seats] seats and the
/// minutes they had been seated when the demo started, under the
/// [kStatuses] status [name]; null for a free table (no status, Free, or a
/// status the demo does not know). Made up, but fixed by the number, the
/// seats and the status, so a seeded "Random statuses" gives the same
/// badges every run.
({int guests, int minutes})? badgeFigures(
    String number, int seats, String? name) {
  final k = int.tryParse(number) ?? number.length;
  final minutes = switch (name) {
    'Ordered' => 5 + k % 10,
    'Eating' => 20 + 3 * k % 25,
    'Bill' => 45 + 7 * k % 30,
    _ => null,
  };
  if (minutes == null) return null;
  return (guests: 1 + k % math.max(seats, 1), minutes: minutes);
}

/// [unit]'s badge. [minutes] is the host's clock, in minutes since the demo
/// started.
Widget tableBadge(
    BuildContext context, PlanUnitOverlay unit, ValueListenable<int> minutes) {
  final number = unit.detail.unit.label!;
  final seats = unit.detail.unit.capacity;
  final status = unit.status;
  final figures =
      badgeFigures(number, seats, status == null ? null : statusNameOf(status));
  final scheme = ShadTheme.of(context).colorScheme;
  final tone = status?.color.withAlpha(255) ?? scheme.border;
  final words = DemoStrings.of(context);
  final Widget badge;
  if (unit.detailLevel == 0) {
    badge = Container(
      key: Key('badge-dot-$number'),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
          color: figures == null ? scheme.card : tone,
          shape: BoxShape.circle,
          border: Border.all(color: tone, width: 2)),
    );
  } else {
    final style = ShadTheme.of(context)
        .textTheme
        .small
        .copyWith(fontSize: 11, color: scheme.cardForeground);
    badge = Container(
      key: Key('badge-$number'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: unit.selected ? scheme.primary : tone,
              width: unit.selected ? 2 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.user, size: 12, color: tone),
        Text('${figures?.guests ?? 0}/$seats',
            key: Key('badge-guests-$number'), style: style),
        if (figures != null) ...[
          const SizedBox(width: 6),
          ValueListenableBuilder<int>(
            valueListenable: minutes,
            builder: (context, now, _) => Text(
                words.minutes(figures.minutes + now),
                key: Key('badge-minutes-$number'),
                style: style),
          ),
        ],
      ]),
    );
  }
  // One semantics node per badge, named by its table: a screen reader (and
  // the web's accessibility tree) reads each badge apart.
  return Semantics(
    container: true,
    label: words.tableTitle(number),
    child: Opacity(opacity: unit.focused ? 1 : 0.35, child: badge),
  );
}
