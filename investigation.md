# Anki SQLite Database Reference

## Pitfalls

1. **Disk I/O error** when opening the file in-place. Anki uses SQLite WAL mode, and the database was likely not cleanly closed. Copying the file to `/tmp` works around this because the copy contains only the main database file without the WAL/SHM lock files.

2. **`no such collation sequence: unicase`** error. Anki registers a custom `unicase` collation at runtime (case-insensitive Unicode comparison via `str.casefold()`). Vanilla `sqlite3` doesn't have it. This collation is referenced in the schema of the `decks` table, so any query that triggers sorting or comparison on its text columns (e.g., `GROUP BY d.name`, `ORDER BY name`, or a JOIN involving the `decks` table) will fail. Simple `SELECT` without ordering works fine. Workaround: query `decks` and `cards` separately and correlate by deck id, or register the collation yourself (e.g., via Python `connection.create_collation` or Haskell `sqlite-simple`).

## Schema overview

### Key tables

| Table | Purpose |
|---|---|
| `decks` | Deck id and name |
| `cards` | One row per card. Links to notes and decks |
| `notes` | One row per note. Contains all fields as a single string |
| `notetypes` | Note type id and name |
| `fields` | Field definitions per note type (name + position) |
| `templates` | Card templates per note type (e.g., Forward/Reverse) |
| `col` | Single-row table with collection metadata. Column 2 is the creation epoch timestamp |
| `config` | Key-value config. `creationOffset` stores timezone offset in minutes |

### Notes and fields

`notes.flds` stores all fields for a note as a single string delimited by `0x1f` (ASCII Unit Separator, shows as `^_` in terminal output). The field order matches `fields.ord` for the given note type.

Example for a note type with fields `[English, Portuguese, Note, Forward]`:
```
English<0x1f>Portuguese<0x1f>Note<0x1f>Forward
```

To split: `T.splitOn "\US"` in Haskell, or `IFS=$'\x1f'` in bash.

### Cards, notes, and note types relationship

- A **note** holds the content (fields). A **card** is a reviewable quiz generated from a note.
- One note can produce multiple cards, one per template in its note type (e.g., Forward + Reverse = 2 cards per note).
- `cards.nid` → `notes.id`, `cards.did` → `decks.id`, `notes.mid` → `notetypes.id`.

### Card scheduling columns

| Column | Meaning |
|---|---|
| `type` | 0 = new, 1 = learning, 2 = review |
| `queue` | 0 = new, 1 = learning, 2 = review, 3 = day-learn, -1 = suspended, -2 = buried |
| `due` | Meaning depends on `type`: for **new** (0) it's the position in the new queue; for **review** (2) it's days since collection creation; for **learning** (1) it's an epoch timestamp |
| `ivl` | Current interval in days |
| `factor` | Ease factor (2500 = 250%) |
| `reps` | Total review count |
| `lapses` | Number of times the card lapsed (was forgotten) |

### Calculating "today" for due date comparison

Review cards store `due` as days since collection creation. To compute today's day number:

```
creation_epoch = column 2 of the single row in `col`
today_day = (current_epoch - creation_epoch) / 86400
```

The `creationOffset` in `config` may shift this by a timezone offset (stored as minutes, e.g., -60).

### When updating notes

Set `mod = <current epoch>` and `usn = -1` so Anki recognizes changes and syncs them.

## Useful queries

```sql
-- Deck names
SELECT id, name FROM decks;

-- Cards and notes per deck (avoids unicase issue)
SELECT did, COUNT(DISTINCT nid) AS notes, COUNT(*) AS cards FROM cards GROUP BY did;

-- Note type structure (fields and templates)
SELECT ntid, name, ord FROM fields ORDER BY ntid, ord;
SELECT ntid, name, ord FROM templates ORDER BY ntid, ord;

-- Which note types are used in each deck
SELECT c.did, n.mid, COUNT(*) AS cards
FROM cards c JOIN notes n ON n.id = c.nid
GROUP BY c.did, n.mid;

-- Card type/queue distribution for a deck
SELECT type, queue, COUNT(*), MIN(due), MAX(due)
FROM cards WHERE did = ? GROUP BY type, queue;

-- Review cards due today with note fields
SELECT DISTINCT n.id, n.flds
FROM cards c JOIN notes n ON n.id = c.nid
WHERE c.did = ? AND c.queue = 2 AND c.due <= ?;
```
