// The separators' DASHED linetype (spec 3a C1.3, C3.4): ported from
// jet_cad_floor_plan/lib/src/parametric/separator.dart:122-149. The kit's
// prepare (lib/src/kit.dart) is ensureDashedLinetype.
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The DASHED linetype a separator draws with (spec 10 D3, R-4; Ruling
/// 10-14), on [ReservedHandles.dashedLinetype].
///
/// In model millimetres, because the painter scales a pattern by world to
/// screen: 4 mm and 2 mm on paper at 1:50, 2 mm and 1 mm at 1:100. It does
/// not follow the page scale.
const LinetypeRecord kDashedLinetypeRecord = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);

/// Adds [kDashedLinetypeRecord] to [doc]'s linetypes, outside the history
/// (spec 10 D3): the kit's `prepare`, which the plan library runs only on
/// the plans it makes (spec 3a C1.3). A loaded or imported plan is never
/// given it: a file without the record opens without one, saves back
/// byte-identical, and its separators draw continuous (today's R-3).
///
/// A no-op when [ReservedHandles.dashedLinetype] already holds a record,
/// whatever it is, and when another handle already carries the name
/// `DASHED` (the table's names are case-insensitive): that record is kept,
/// and a separator, which still names handle 6, draws continuous there.
void ensureDashedLinetype(DraftDocument doc) {
  final linetypes = doc.tables.linetypes;
  if (linetypes.contains(kDashedLinetypeRecord.handle)) return;
  if (linetypes.byName(kDashedLinetypeRecord.name) != null) return;
  linetypes.add(kDashedLinetypeRecord);
}
