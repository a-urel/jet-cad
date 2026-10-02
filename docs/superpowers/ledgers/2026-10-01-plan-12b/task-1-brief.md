# Task 1 brief — the header, the target, schema 7 (spec D3, D4, F8)
Read common.md in this directory first and follow it. HEAD 9ee2e60. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/l1/.
Do plan Task 1 exactly (DocumentHeader.currentLayer + codec + _loadHeader; kSchemaVersion 7 with the v6->v7 paragraph; CommandTarget.header and the two test fakes; LayerRecord.copyWith; new lib/src/document/layer_commands.dart with layerNameError and drawingLayer, exported from package:jet_cad_2d/jet_cad_2d.dart; plan P-7 re-baselines; test/document/layer_header_test.dart).
Read first: packages/jet_cad_2d/lib/src/document/{header,tables,command,draft_document}.dart; lib/src/codec/{json_codec,schema_version}.dart; test/codec/json_codec_test.dart around :505-585; the instance_style_codec_test.dart pins (:80, :191); test/testing/generate_document_test.dart (:59-62, :243-246) and how earlier plans re-baselined it (git log -p on that file).
Record the 2 standing engine failures' names before and after (plan P-7).
Mutants: M-LP-12, M-LP-13, M-LP-21, plus one per layerNameError branch (M-LP-T1a, b, ...). Gates: all packages (common.md).
