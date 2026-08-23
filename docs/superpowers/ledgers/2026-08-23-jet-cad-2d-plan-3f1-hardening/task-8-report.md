# Task 8 report: the exit gate

## Status: DONE

Every command below was run by this task, from a clean tree, after Tasks 1-6
had committed and Task 7 had reverted in full. No production code and no test
changed in this task. `git status --short` was empty before and after every
command in this report.

## Step 1 — the whole gate, both packages, from a clean tree

```
$ git status --short
(empty)

$ flutter --version
Flutter 3.47.1 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 6655482ec0 (4 days ago) • 2026-08-19 10:07:23 -0700
Engine • hash 11d79658c444477b06513d32b52c8c4ccb7276b0 (revision 5d53178869) (4 days ago) • 2026-08-18 23:36:01.000Z
Tools • Dart 3.13.1 • DevTools 2.60.0
```

Confirms the environment note in the task-8 brief: the running Flutter is
**3.47.1**, framework `6655482ec0`. (The `3.27.3` seen in the `flutter_tester`
process path during Task 7's probe is a stale Homebrew cask directory name,
not the running Flutter version — not recorded as one anywhere in this
report or in the results note.)

### `packages/jet_cad_2d`

```
$ cd packages/jet_cad_2d && CI=true dart test
00:00 +0: loading test/core/tolerance_test.dart
00:00 +0: test/core/tolerance_test.dart: standard tolerance is absolute in document units
00:00 +1: test/core/list_equality_test.dart: compares element-wise
00:00 +2: test/core/tolerance_test.dart: eq accepts differences within the linear tolerance
00:00 +3: test/core/list_equality_test.dart: differing lengths are unequal
00:00 +4: test/core/list_equality_test.dart: differing lengths are unequal
00:00 +5: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +6: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +7: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +8: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +9: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +10: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +11: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +12: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +13: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +14: test/core/handle_test.dart: Handle rejects values above the 32-bit ceiling
00:00 +15: test/core/diagnostic_test.dart: handles defaults to empty, not null
00:00 +16: test/core/handle_test.dart: Handle rejects negative values
00:00 +17: test/core/diagnostic_test.dart: is value-equal so tests can assert on expected diagnostic sets
00:00 +18: test/core/diagnostic_test.dart: is value-equal so tests can assert on expected diagnostic sets
00:00 +19: test/core/handle_test.dart: HandleSeed allocates monotonically from one
00:00 +20: test/core/diagnostic_test.dart: toJson emits keys in a stable order and omits absent fields
00:00 +21: test/core/diagnostic_test.dart: toJson emits keys in a stable order and omits absent fields
00:00 +22: test/core/diagnostic_test.dart: toJson emits keys in a stable order and omits absent fields
00:00 +23: test/codec/json_codec_test.dart: encodes the schema version and a fixed top-level key order
00:00 +24: test/codec/instance_style_codec_test.dart: an instance round-trips all four style fields at non-default values
00:00 +25: test/codec/instance_style_codec_test.dart: an instance round-trips all four style fields at non-default values
00:00 +26: test/codec/instance_style_codec_test.dart: an instance round-trips all four style fields at non-default values
00:00 +27: test/codec/instance_style_codec_test.dart: an instance round-trips all four style fields at non-default values
00:00 +28: test/codec/json_codec_test.dart: round-trips a document structurally
00:00 +29: test/codec/json_codec_test.dart: round-trips a document structurally
00:00 +30: test/codec/json_codec_test.dart: round-trips a document structurally
00:00 +31: test/codec/json_codec_test.dart: round-trips a document structurally
00:00 +32: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +33: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +34: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +35: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +36: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +37: test/codec/json_codec_test.dart: serialization is idempotent, which is the determinism guarantee
00:00 +38: test/codec/json_codec_test.dart: serialization is idempotent, which is the determinism guarantee
00:00 +39: test/codec/json_codec_test.dart: two documents built the same way encode identically
00:00 +40: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +41: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +42: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +43: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +44: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +45: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +46: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +47: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +48: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +49: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +50: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +51: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +52: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +53: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +54: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +55: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +56: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +57: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +58: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +59: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +60: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +61: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +62: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +63: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +64: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +65: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +66: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +67: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +68: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +69: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +70: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +71: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +72: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +73: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +74: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +75: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +76: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +77: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +78: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +79: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +80: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +81: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +82: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +83: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +84: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +85: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +86: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +87: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +88: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +89: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +90: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +91: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +92: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +93: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +94: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +95: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +96: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +97: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +98: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +99: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +100: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +101: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +102: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +103: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +104: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +105: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +106: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +107: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +108: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +109: test/invariants/query_allocation_test.dart: (setUpAll)
The Dart VM service is listening on http://127.0.0.1:51790/8uETfcTE7N4=/
00:00 +110: test/invariants/query_allocation_test.dart: (setUpAll)
The Dart DevTools debugger and profiler is available at: http://127.0.0.1:51790/8uETfcTE7N4=/devtools/?uri=ws://127.0.0.1:51790/8uETfcTE7N4=/ws
00:00 +111: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +112: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +113: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +114: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +115: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +116: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +117: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +118: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +119: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +120: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +121: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +122: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +123: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +124: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +125: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +126: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +127: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +128: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +129: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +130: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +131: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +132: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +133: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +134: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +135: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +136: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +137: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +138: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +139: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +140: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +141: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +142: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +143: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +144: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +145: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +146: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +147: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +148: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +149: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +150: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +151: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +152: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +153: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +154: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +155: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +156: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +157: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +158: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +159: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +160: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +161: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +162: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +163: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +164: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +165: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +166: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +167: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +168: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +169: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +170: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +171: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +172: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +173: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +174: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +175: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +176: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +177: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +178: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +179: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +180: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +181: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +182: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +183: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +184: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +185: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +186: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +187: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +188: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +189: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +190: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +191: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +192: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +193: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +194: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +195: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +196: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +197: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +198: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +199: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +200: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +201: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +202: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +203: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +204: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +205: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +206: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +207: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +208: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +209: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +210: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +211: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +212: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +213: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +214: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +215: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +216: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +216: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +217: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +218: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +219: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +220: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +221: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +222: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +223: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +224: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +225: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +226: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +227: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +228: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +229: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +230: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +231: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +232: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +233: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +234: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +235: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +236: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +237: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +238: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +239: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +240: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +241: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +242: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +243: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +244: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +245: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +246: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +247: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +248: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +249: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +250: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +251: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +252: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +253: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +254: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +255: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +256: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +257: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +258: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +259: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +260: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +261: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +262: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +263: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +264: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +265: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +266: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +267: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +268: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +269: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +270: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +271: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +272: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +273: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +274: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +275: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +276: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +277: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +278: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +279: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +280: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +281: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +282: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +283: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +284: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +285: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +286: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +287: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +288: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +289: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +290: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +291: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +292: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +293: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +294: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +295: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +296: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +297: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +298: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +299: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +300: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +301: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +302: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +303: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +304: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +305: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +306: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +307: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +308: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +309: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +310: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +311: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +312: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +313: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +314: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +315: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +316: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +317: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +318: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +319: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +320: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +321: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +322: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +323: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +324: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +325: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +326: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +327: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +328: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +329: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +330: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +331: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +332: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +333: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +334: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +335: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +336: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +337: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +338: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +339: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +340: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +341: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +342: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +343: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +344: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +345: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +346: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +347: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +348: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +349: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +350: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +351: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +352: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +353: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +354: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +355: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +356: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +357: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +358: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +359: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +360: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:00 +361: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +362: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +363: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +364: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +365: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +366: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +367: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +368: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +369: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +370: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +371: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +372: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +373: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +374: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +375: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +376: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +377: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +378: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +379: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +380: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +381: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +382: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +383: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +384: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +385: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +386: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +387: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +388: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +389: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +390: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +391: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +392: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +393: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +394: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +395: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +396: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +397: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +398: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +399: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +400: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +401: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +402: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +403: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +404: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +405: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +406: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +407: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +408: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +409: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +410: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +411: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +412: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +413: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +414: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +415: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +416: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +417: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +418: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +419: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +420: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +421: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +422: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +423: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +424: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +425: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +426: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +427: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +428: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +429: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +430: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +431: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +432: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +433: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +434: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +435: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +436: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +437: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +438: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +439: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +440: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +441: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +442: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +443: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +444: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +445: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +446: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +447: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +448: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +449: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +450: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +451: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +452: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +453: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +454: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +455: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +456: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +457: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +458: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +459: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +460: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +461: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +462: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +463: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +464: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +465: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +466: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +467: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +468: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +469: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +470: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +471: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +472: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +473: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +474: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +475: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +476: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +477: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +478: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +479: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +480: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +481: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +482: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +483: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +484: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +485: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +486: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +487: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +488: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +489: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +490: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +491: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +492: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +493: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +494: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +495: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +496: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +497: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +498: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +499: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +500: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +501: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +502: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +503: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +504: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +505: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +506: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +507: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +508: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +509: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +510: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +511: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +512: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +513: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +514: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +515: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +516: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +517: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +518: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +519: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +520: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +521: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +522: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +523: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +524: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +525: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +526: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +527: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +528: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +529: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +530: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +531: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +532: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +533: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +534: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +535: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +536: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +537: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +538: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +539: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +540: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +541: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +542: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +543: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +544: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +545: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +546: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +547: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +548: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +549: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +550: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +551: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +552: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +553: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +554: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +555: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +556: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +557: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +558: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +559: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +560: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +561: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +562: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +563: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +564: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +565: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +566: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +567: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +568: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +569: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +570: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +571: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +572: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +573: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +574: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +575: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +576: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +577: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +578: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +579: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +580: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +581: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +582: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +583: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +584: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +585: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +586: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +587: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +588: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +589: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +590: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +591: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +592: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +593: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +594: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +595: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +596: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +597: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +598: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +599: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +600: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +601: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +602: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +603: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +604: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +605: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +606: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +607: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +608: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +609: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +610: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +611: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +612: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +613: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +614: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +615: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +616: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +617: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +618: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +619: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +620: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +621: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +622: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +623: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +624: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +625: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +626: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +627: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +628: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +629: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +630: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +631: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +632: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +633: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +634: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +635: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +636: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +637: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +638: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +639: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +640: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +641: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +642: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +643: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +644: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +645: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +646: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +647: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +648: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +649: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +650: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +651: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +652: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +653: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +654: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +655: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +656: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +657: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +658: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +659: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +660: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +661: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +662: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +663: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +664: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +665: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +666: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +667: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +668: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +669: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +670: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +671: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +672: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +673: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +674: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +675: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +676: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +677: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +678: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +679: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +680: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +681: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +682: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +683: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +684: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +685: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +686: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +687: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +688: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +689: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +690: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +691: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +692: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +693: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +694: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +695: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +696: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +697: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +698: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +699: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +700: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +701: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +702: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +703: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +704: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +705: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +706: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +707: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +708: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +709: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +710: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +711: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +712: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +713: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +714: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +715: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +716: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +717: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +718: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +719: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +720: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +721: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +722: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +723: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +724: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +725: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +726: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +727: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +728: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +729: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +730: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +731: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +732: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +733: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +734: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +735: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +736: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +737: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +738: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +739: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +740: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +741: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +742: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +743: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +744: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +745: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +746: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +747: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +748: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +749: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +750: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +751: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +752: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +753: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +754: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +755: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +756: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +757: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +758: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +759: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +760: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +761: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +762: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +763: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +764: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +765: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +766: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +767: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +768: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +769: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +770: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +771: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +772: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +773: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +774: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +775: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +776: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +777: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +778: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +779: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +780: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +781: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +782: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +783: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +784: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +785: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +786: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +787: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +788: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +789: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +790: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +791: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +792: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +793: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +793: All tests passed!
```

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 112 files (0 changed) in 0.20 seconds.
```

**793 tests, all pass. Analyze clean. Format clean.**

### `packages/jet_cad_2d_flutter`

```
$ cd ../jet_cad_2d_flutter && CI=true flutter test
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: every residual reaching Canvas is small at 4.5e6
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: every coordinate reaching Canvas is small at 4.5e6
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: recorded points reproduce world coordinates through the residual
00:00 +3: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: with rebasing disabled, float32 rounding is observable
00:00 +4: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: at the origin the rebase changes nothing measurable
00:00 +5: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor is stable while the camera moves within one grid step
00:00 +6: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor lands on the grid, at or below the view centre
00:00 +7: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor leaves a residual float32 can carry, where the raw coordinate is already lossy
00:00 +8: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor derives its step from the view span, so it works zoomed out
00:00 +9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor snaps downward on negative coordinates, not toward zero
00:00 +10: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor a degenerate view has its origin at the world origin
00:00 +11: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController panBy moves the screen position of a world point by the delta
00:00 +12: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController panBy notifies, so a repaint boundary knows the frame is stale
00:00 +13: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController zoomAt keeps the world point under the cursor fixed
00:00 +14: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController zoomAt multiplies the scale by the factor
00:00 +15: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController zoomAt ignores a factor that would make the camera singular
00:00 +16: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a segment becomes two triangles a half-width either side of it
00:00 +17: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the residual is baked into the positions, not pushed on the canvas
00:00 +18: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: stroke width is device pixels under a non-uniform residual
00:00 +19: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a polyline of n points emits n-1 segments plus a join at each corner
00:00 +20: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a closed polyline draws its closing segment and seam join
00:00 +21: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: colour rides on the vertices, so one buffer carries every colour
00:00 +22: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: draw order survives batching: segments stay in emission order
00:00 +23: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: draw order survives the flush itself, not just the pre-flush buffer
00:00 +24: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: one flush, one draw call, whatever the colours
00:00 +25: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a zero-length segment emits nothing rather than a NaN normal
00:00 +26: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the batched buffers survive a residual ending
00:00 +27: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the segment count is what a rig reads to compare sinks
00:00 +28: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the batch reaches the Canvas before the text it was batched before
00:00 +29: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: an arc is flattened, and its ends sit on the arc
00:00 +30: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the flattened arc stays within a quarter pixel of the true one
00:00 +31: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the segment count follows the arc as the residual scales it
00:00 +32: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a non-uniform residual turns a circle into an ellipse
00:00 +33: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a point is a square of the stroke width, at the residual
00:00 +34: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a circle closes on itself
00:00 +35: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: an unbatchable op flushes first, so draw order holds across it
00:00 +36: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a stroke above the floor keeps its exact width, not a rounded one
00:00 +37: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a sub-pixel stroke gets one device pixel and loses alpha for it
00:00 +38: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the floor is device pixels, so it moves with the ratio
00:00 +39: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a lineweight of zero is a hairline at full alpha
00:00 +40: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: every emitter fades, not just the straight one
00:00 +41: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the fade multiplies the style alpha rather than replacing it
00:00 +42: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a polygon fill emits exactly the triangles it was handed
00:00 +43: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a fill on a hairline layer keeps full alpha
00:00 +44: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a polygon fill is baked into the positions, not pushed on the canvas
00:00 +45: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: an empty triangle list draws nothing, defensively
00:00 +46: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a filled circle and its own outline use the same step count
00:00 +47: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a fill batches with strokes into one flush, not one call each
00:00 +48: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a zero-radius fill circle emits nothing rather than a NaN fan
00:00 +49: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the submitted Vertices is disposed, and the flag reads its state
00:00 +50: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the disposed Vertices rasterises the same pixels a retained one would
00:00 +51: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a flush with nothing batched disposes nothing
00:00 +52: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +53: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +54: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +55: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +56: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text leaf draws one text op under its own composed residual
00:00 +57: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the composed residual lands the glyph box where the bounds say
00:00 +58: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: an empty text entity draws nothing and is still counted
00:00 +59: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: text inside a mirrored instance is drawn mirrored, not corrected
00:00 +60: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the reference walk and the painter agree with text on
00:00 +61: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +62: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +63: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +64: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:00 +65: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:00 +66: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:00 +67: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:00 +68: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:00 +69: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +70: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +71: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas)
00:01 +72: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas)
00:01 +73: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas)
00:01 +74: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +75: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +76: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +77: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +78: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.vertices)
00:01 +79: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.vertices)
00:01 +80: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 2 (RenderBackend.vertices)
00:01 +81: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the painter draws a superset of the reference walk, in order
00:01 +82: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +83: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +84: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +85: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +86: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +87: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +88: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +89: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +90: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +91: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +92: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +93: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +94: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +95: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +96: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +97: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +98: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +99: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +100: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +101: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +102: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +103: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +104: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +105: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +106: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two backends draw the same drawing
00:01 +107: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
00:01 +108: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: the two sinks agree on an opaque fill
00:01 +109: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
00:01 +110: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
00:01 +111: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: anisotropic stroke width diverges, and vertices is right
00:01 +112: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
00:01 +113: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
00:01 +114: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: a full-sweep ARC leaves an unjoined seam. This is a defect
00:01 +115: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:01 +116: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:01 +116: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: round-trips a point at site-plan magnitude in Float64
00:01 +117: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: visibleWorld covers the viewport corners under rotation
00:01 +118: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: scale is the geometric mean of the axis scales
00:01 +119: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: fit puts the centre of the world box at the centre of the viewport
00:01 +120: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: fit flips y, because world is y-up and screen is y-down
00:01 +121: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: fit leaves a 5% margin on the limiting axis
00:01 +122: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: fit an empty document does not produce a singular transform
00:01 +123: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: fit a viewport laid out at zero size does not produce a singular transform
00:01 +124: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: fit a world box with no height does not produce a singular transform
00:01 +125: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
00:02 +126: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
00:02 +127: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
00:02 +128: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/text_cache_invariants_test.dart: the default cache bounds hold 600 distinct keys the way they claim
00:02 +129: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +130: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +131: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +132: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +133: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +134: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +135: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +136: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +137: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +138: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +139: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +140: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +141: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +142: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +143: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +144: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +145: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +146: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +147: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +147: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart: (suite)
  Skip: run explicitly: flutter test --tags rig --run-skipped
00:02 +147 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:02 +148 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: repaints on a camera change without rebuilding
00:02 +149 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: repaints on a camera change without rebuilding
00:02 +150 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +151 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +152 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +153 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +154 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +155 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +156 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +157 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +158 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +159 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +160 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +161 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +162 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +163 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +164 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +165 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +166 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +167 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +168 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +169 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
00:02 +170 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=75ms
00:02 +171 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/drawvertices_antialiasing_test.dart: drawVertices ignores isAntiAlias: the paint flag changes nothing
00:02 +172 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/drawvertices_antialiasing_test.dart: drawVertices shows no coverage ramp on a shared edge where drawPath does
00:02 +173 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: text below the threshold is culled and never measured
00:02 +174 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: the same text at the same camera draws once LOD is off
00:02 +175 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: readable text at the same threshold is not culled
00:02 +176 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a triangle covers its interior and not its outside
00:02 +177 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a triangle covers its interior and not its outside
00:02 +178 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a triangle covers its interior and not its outside
00:02 +179 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a triangle covers its interior and not its outside
00:02 +180 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a triangle covers its interior and not its outside
00:02 +181 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:02 +182 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:02 +183 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:02 +184 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:02 +185 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:02 +186 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: painter and oracle cull the same text under a non-identity placement
00:02 +187 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: geometry outside the surface is clipped, not wrapped
00:02 +188 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a triangle entirely off the surface inks nothing, even after its bounding box is clamped onto the surface
00:02 +189 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: a degenerate triangle inks nothing
00:02 +190 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: vertices exactly on pixel centres ink the pixels they sit on
00:02 +191 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: an edge that passes exactly through a pixel centre inks it: the inclusive side of the boundary wins, on both edges of a shared seam
00:02 +192 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart: wired to a real VerticesDrawSink flush, it reads the submitted stroke band and the exact ARGB->RGBA channel order
00:03 +193 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: the platform default is vertices, unconditionally
00:03 +194 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +195 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +196 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +197 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +198 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +199 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +200 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +201 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +202 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +203 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +204 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +205 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +206 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +207 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +208 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +209 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +210 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +211 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +212 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +213 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +214 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +215 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +216 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +217 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +218 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +219 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +220 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:03 +221 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +222 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +223 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +224 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +225 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +226 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +227 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:03 +228 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +228 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/fill_seam_test.dart: the translucent seam, measured
SEAM interior=656204 over8=0 fraction=0.000% worst=0
00:03 +229 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +230 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +231 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +232 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +233 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +234 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:03 +235 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +236 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +237 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +238 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +239 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +240 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +242 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +243 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +244 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +245 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +246 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:04 +247 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:04 +248 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink captures ops in order with residual-local points
00:04 +249 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink polyline copies the caller buffer
00:04 +250 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink polyline reads count points, not the whole buffer
00:04 +251 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink ops compare by value, which is what the oracle rests on
00:04 +252 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:04 +253 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:04 +254 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:04 +255 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:04 +256 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the miter limit and its cosine are Impellers own
00:04 +257 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink fillPolygon copies the caller buffers
00:04 +258 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a right-angle corner is mitred out to the square corner
00:04 +259 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a right-angle corner is mitred out to the square corner
00:04 +260 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a right-angle corner is mitred out to the square corner
00:04 +261 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a right-angle corner is mitred out to the square corner
00:04 +262 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a right-angle corner is mitred out to the square corner
00:04 +263 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: flatten flatten with a pure scale, as a sanity check on the brief
00:04 +264 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a right (clockwise) turn is mitred out on its own outer side
00:04 +265 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +266 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +267 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +268 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +269 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +270 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +271 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:04 +272 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +273 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +274 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +275 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +276 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +277 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +278 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +279 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +280 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +281 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +282 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +283 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +284 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
00:04 +285 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +286 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +287 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +288 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +289 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +290 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +291 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +292 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +293 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +294 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:04 +295 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:04 +296 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:04 +297 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:04 +298 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:04 +299 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards
00:04 +300 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
00:04 +301 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:04 +302 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle draws a filled circle
00:04 +303 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:04 +304 ~1: All tests passed!
```

```
$ flutter analyze
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.1s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 54 files (0 changed) in 0.10 seconds.
```

**304 tests pass, 1 skipped (the `rig`-tagged microbench, pre-existing, by
design). Analyze clean. Format clean.**

### Golden check

```
$ cd .. && git status --short jet_cad_2d_flutter/test/golden
(empty)

$ git status --short
(empty)
```

No PNG regenerated. No `analysis_options.yaml` drift in any package. Nothing
left uncommitted.

## Step 2 — the seventeen criteria

Full table with commands, observed results and verdicts is in
[docs/superpowers/notes/2026-08-23-plan-3f1-results.md](../../../docs/superpowers/notes/2026-08-23-plan-3f1-results.md).
Summary: **16 PASS / 1 MISS / 0 UNEVALUABLE, out of 17.** The miss is
criterion 17 (the allocation-meter probe), and it is recorded there as the
plan's pre-committed stop clause firing as designed, not as a code defect —
`AllocationMeter.connect()` returned `null` under `flutter test` because
`flutter_tester` launches with `--disable-vm-service`, verified from the real
process line by the Task 7 reviewer, so the meter's in-isolate runtime-start
mechanism cannot work there regardless of retries. The withdrawn implication
("no retry would help") and the plausible-but-unexplored flag-based
alternative are both recorded in full in the results note, along with the
plan's own recurring failure mode (three instances of a stated cause stronger
than its evidence, each caught by running something rather than reading it)
and the three plan premises corrected mid-flight (layer 0's seeded record,
Task 1's "the suite will not move", Task 2's "eight tests, all FAIL").

The note also records, in its own section, what this plan did not close:
permitted divergence 5 (untouched, still unexercised), the malformed-layer
asymmetry (mirrored rather than fixed, an accepted gap), Ruling 4's single
permitted `kParagraphCacheLimit` raise (still unspent, 3,876 beside it), and
criterion 17 in full.

## Step 3 — the mutation log

[docs/superpowers/notes/plan-3f1-mutation-log.md](../../../docs/superpowers/notes/plan-3f1-mutation-log.md)
carries one section per mutant M1-M17: the exact edit, the exact command, the
verbatim output (copied from the task reports that produced it, not
re-synthesized), and the kill verdict. **All seventeen fired, all seventeen
killed. No survivors** — unlike Plan 3f's own log, whose three survivor rows
were part of the motivation for this plan's Decision 6.

## Step 4 — STATUS.md

Updated:
- A new "Plan 3f.1 — hardening before the picture cache" section under the
  roadmap, before the Plan 3g section: what landed, the 16/17 criteria score,
  the commit range `c078677..b1e9ec1`, links to both notes.
- Plan 3g's trap 4 struck through and marked **closed by Plan 3f.1**, with the
  cache-key cardinality consequence (`StyleContext.linetypeScale` compared by
  `==` and hashed; the four fields now carrying real values means instances
  that used to share one definition picture no longer do, and two chains
  whose scales are mathematically equal but reached by different factors are
  different doubles and therefore different keys — a reason 3g may want a
  quantised scale band rather than the raw double).
- A new "What 3f.1 hands it" bullet list in the Plan 3g section, recording
  explicitly that **the Flutter package does not have a working allocation
  meter** and why, plus the correctly-keyed `StyleContext`, the connected
  `linetypeScale`, the now-asserted structural invariants, and Ruling 4's
  still-unspent raise.
- The top-of-file "Verified against" line, the TL;DR, the "Resume here"
  section and the suite-count table were also brought forward to `b1e9ec1`
  and 793/304 — not explicitly required by the brief's four bullets, but
  necessary so the file does not state a stale commit and stale counts next
  to a new, more current Plan 3f.1 section.

## Step 5 — commit


```
$ git add docs/superpowers/notes/2026-08-23-plan-3f1-results.md \
        docs/superpowers/notes/plan-3f1-mutation-log.md \
        STATUS.md
$ git commit -m "docs: Plan 3f.1 results, mutation log, and STATUS update"
[main 490ae8e] docs: Plan 3f.1 results, mutation log, and STATUS update
 3 files changed, 1034 insertions(+), 11 deletions(-)
 create mode 100644 docs/superpowers/notes/2026-08-23-plan-3f1-results.md
 create mode 100644 docs/superpowers/notes/plan-3f1-mutation-log.md
```

Commit SHA: `490ae8e`.

## Outcome

Plan 3f.1's exit gate is closed: **16 of 17 criteria PASS, 1 MISS (criterion
17, the pre-committed stop clause), 0 UNEVALUABLE.** All 17 named mutants
killed, no survivors. Both packages green from a clean tree at `b1e9ec1`, then
the results note, mutation log and `STATUS.md` update committed on top at
`490ae8e`. No worktree existed for this plan, so its
`.superpowers/sdd/2026-08-23-jet-cad-2d-plan-3f1-hardening/` ledger is not yet
archived to `docs/superpowers/ledgers/` — recorded as the next resumer's
chore in `STATUS.md`'s "Resume here" section, per the ordering lesson Plan 3e
and Plan 3f's own archives already record.
