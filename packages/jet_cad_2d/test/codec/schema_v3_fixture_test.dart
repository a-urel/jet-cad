import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A hand-built schema-3 document: one text entity carrying exactly the one
/// scalar (height) that schema 3 wrote for TEXT. The top-level shape mirrors
/// what `DraftDocumentCodec.encode(DraftDocument.empty())` actually produces
/// (plain integer handles, not hex strings, and `definitions`/`root`/`nodes`
/// rather than a nested `tree`) — this package's codec, not the illustrative
/// shape a plan brief sketches from memory.
const _v3Document = '''
{
  "schemaVersion": 3,
  "header": {"units": "unitless", "scale": 1.0, "customVariables": {}},
  "tables": {
    "layers": [
      {"handle": 1, "name": "0", "color": 7, "linetype": 4,
       "lineweight": -3, "transparency": 0, "visible": true, "locked": false}
    ],
    "linetypes": [
      {"handle": 2, "name": "ByLayer", "description": "",
       "pattern": {"dashes": [], "totalLength": 0.0}},
      {"handle": 3, "name": "ByBlock", "description": "",
       "pattern": {"dashes": [], "totalLength": 0.0}},
      {"handle": 4, "name": "Continuous", "description": "Solid line",
       "pattern": {"dashes": [], "totalLength": 0.0}}
    ],
    "textStyles": [
      {"handle": 5, "name": "Standard", "fontFamily": "Roboto",
       "widthFactor": 1.0, "obliqueAngle": 0.0, "fixedHeight": 0.0,
       "isShx": false, "shxFileName": ""}
    ],
    "patterns": [],
    "dimStyles": [],
    "appIds": []
  },
  "definitions": [],
  "root": 17,
  "nodes": [
    {"type": "group", "handle": 17, "parent": 0,
     "transform": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0], "visible": true,
     "children": [], "exportAsDxfGroup": false}
  ],
  "entities": [
    {
      "record": {
        "handle": 100, "owner": 17, "kind": "text", "layer": 1,
        "linetype": 2, "linetypeScale": 1.0, "color": -1, "lineweight": -3,
        "transparency": -1, "flags": 0
      },
      "geometry": {"coords": [10.0, 20.0], "scalars": [100.0]}
    }
  ],
  "components": {},
  "rawData": {},
  "handleSeed": 101
}
''';

void main() {
  test('a version-3 document loads under the version-4 build', () {
    final doc = DraftDocumentCodec.decodeString(_v3Document);
    final slot = doc.entities.liveSlots.single;
    expect(doc.entities.textAt(slot), '');
    expect(doc.entities.tagAt(slot), '');
    expect(doc.entities.textStyleAt(slot), ReservedHandles.standardTextStyle);
    expect(doc.entities.textAttrsAt(slot), 0);
    // One scalar, not four. Reading scalars[1] must not throw.
    final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
    expect(scalarOr(payload, 1, 0.0), 0.0);
    expect(scalarOr(payload, 0, 0.0), 100.0);
  });

  test('a version-3 document survives a round-trip unpadded', () {
    final once =
        DraftDocumentCodec.encodeToString(DraftDocumentCodec.decodeString(
      _v3Document,
    ));
    final twice =
        DraftDocumentCodec.encodeToString(DraftDocumentCodec.decodeString(
      once,
    ));
    expect(twice, once);
    // The payload is not rewritten on load: padding it would change geometry
    // the file never contained.
    expect(once.contains('"scalars":[100.0]'), isTrue);
  });
}
