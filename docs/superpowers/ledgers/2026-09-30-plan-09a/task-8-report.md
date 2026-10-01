# Task 8 report
Commit 10770f8. Gates: app 789 tests pass (780 + 9: 3 new chair tests, 6 per-symbol placed/size cases), analyze clean, format 0 changed, flutter build web --release OK. Engine and render untouched.
Tables (symbol bbox, table at lower-left offset, base = table centre): square.two table 800x800, chairs bottom+top, symbol 800x1500, base (400,750); square.four 900x900, 4 sides, 1600x1600, base (800,800); rect.four 1400x800, 2 per long side, 1400x1500, base (700,750); rect.six 1800x900, 2 per long side + each end, 2500x1600, base (1250,800). Chair: closed 450x450 + back line 60 in from outer edge, 100 mm under the table.
Closed polylines: 4, 6, 6, 8. Tests: literal tables updated, 25->27, new group (chair count per seat, 450 size + 100 tuck, no bbox overlap).
Mutants: (a) drop right chair of rect.six -> closed-count and chair-count tests red; (b) rect.four chair moved onto another -> overlap test red; (c) base (0,0) -> origin test red; (d) 25 left -> "27 shipped keys" test red. Catalog and asset restored by cp; regenerated asset equals committed.
Contact sheet: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/t8/tables.png

## Task 8b
Commit 2d12067 ('docs+test: dining table review follow-ups (8b)'). Docs: spec asset size 44,212 (33,423 labelled as the 25-symbol asset), results note 25/27 wording, R-T5-1 sentence, 33,423 lines labelled Task 5/6-time, tasks-table row for 8/8b. New test: each new table's basePoint equals the literal table centre and the table outline's centre. Gates: app 790 passing, analyze clean, format 0 changed; engine/render untouched. Mutant: baseX +50 (+regenerate) -> 'each table's base point is its table centre' red (+98 -1); catalog and asset restored by cp, regenerated asset equal, git status clean.
