# Clarity CAT - Design Document

**Date:** 2026-01-09
**Purpose:** Cloud-native CAT tool replacement for Phrase, optimized for KO→EN solo translation workflow

---

## 1. Overview

### Problem Statement
Phrase CAT is feature-bloated for solo translator needs. Need a clean, fast, cloud-synced CAT tool with only essential features plus custom QA/finalization workflows.

### Design Goals
- **Simplicity:** Only features that matter for KO→EN solo work
- **Speed:** Handle 100K+ word projects and 500K+ segment TMs without lag
- **Reliability:** Never lose work - auto-save, backups, cloud sync
- **Portability:** Seamless Mac ↔ Windows workflow via cloud storage

### Non-Goals
- Multi-user collaboration (solo use only)
- Machine translation integration
- Project management features
- Invoicing/business features

---

## 2. Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | Tauri 2.0 | Lightweight (~50MB), Rust backend, native WebView |
| Frontend | SvelteKit + TailwindCSS | Fast reactive UI, clean styling |
| Database | SQLite + FTS5 | Fast fuzzy search, portable, no server |
| Document Processing | docx-rs (Rust) | Native Word handling, preserves formatting |
| Fuzzy Matching | Custom Levenshtein + n-gram indexing | Fast 75%+ matching on 500K+ segments |

### Why Tauri over Electron?
- 3x smaller app size (50MB vs 150MB+)
- Lower memory footprint
- Rust backend = faster TM matching
- Better security model

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        CLARITY CAT                            │
├──────────────────────────────────────────────────────────────┤
│                     FRONTEND (SvelteKit)                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐   │
│  │  Project    │  │   Editor    │  │    Side Panels      │   │
│  │  Navigator  │  │   View      │  │  - TM Matches       │   │
│  │             │  │  (segments) │  │  - TB Terms         │   │
│  │  - Files    │  │             │  │  - QA Warnings      │   │
│  │  - Search   │  │  Source|Tgt │  │  - Comments         │   │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘   │
├──────────────────────────────────────────────────────────────┤
│                      BACKEND (Rust)                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ Document │ │    TM    │ │    TB    │ │   QA Engine      │ │
│  │ Parser   │ │  Engine  │ │  Engine  │ │                  │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────────────────┐  │
│  │ Export   │ │ Import   │ │   Finalization Engine        │  │
│  │ Engine   │ │ Engine   │ │   (formatting, find-replace) │  │
│  └──────────┘ └──────────┘ └──────────────────────────────┘  │
├──────────────────────────────────────────────────────────────┤
│                     STORAGE (SQLite)                          │
│  ┌─────────────────┐  ┌────────────────────────────────────┐ │
│  │  app_settings.db│  │  Per-Project (in project folder):  │ │
│  │  (global prefs) │  │    - segments.db (translations)    │ │
│  │                 │  │    - tm.db (project TM)            │ │
│  │                 │  │    - tb.db (project TB)            │ │
│  └─────────────────┘  └────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              ↕
                   [Cloud Folder Sync]
              (iCloud / OneDrive / Dropbox)
```

---

## 4. Data Model

### 4.1 Project Structure

```
ClarityCAT/                          # Cloud-synced root folder
├── app_settings.db                  # Global app preferences, client profiles
├── projects/
│   └── {project-uuid}/
│       ├── project.json             # Project metadata
│       ├── segments.db              # Project segments (translations)
│       ├── tm.db                    # Project-specific Translation Memory
│       ├── tb.db                    # Project-specific Term Base
│       ├── source_files/            # Original Word docs (reference)
│       └── backups/                 # Project-level backups
│           └── 2026-01-09/
├── backups/                         # Global backup snapshots
│   └── 2026-01-09/
└── exports/                         # Export outputs
```

**Key Design Decision: Per-Project TM/TB**
- Each project maintains its own TM and TB
- Prevents cross-contamination between clients/domains
- Import from other projects' TM/TB when needed
- Optional: "Search all projects" toggle for cross-project lookups

### 4.2 Database Schema

**Translation Memory (tm.db):**
```sql
CREATE TABLE segments (
    id INTEGER PRIMARY KEY,
    source_text TEXT NOT NULL,
    target_text TEXT NOT NULL,
    source_hash TEXT NOT NULL,          -- For exact match lookup
    source_normalized TEXT NOT NULL,    -- For fuzzy matching
    context_before TEXT,                -- Previous segment
    context_after TEXT,                 -- Next segment
    file_name TEXT,                     -- Origin file
    project_name TEXT,                  -- Origin project
    created_at DATETIME,
    modified_at DATETIME,
    usage_count INTEGER DEFAULT 1
);

CREATE INDEX idx_source_hash ON segments(source_hash);
CREATE VIRTUAL TABLE segments_fts USING fts5(source_normalized, target_text);
```

**Term Base (tb.db):**
```sql
CREATE TABLE terms (
    id INTEGER PRIMARY KEY,
    source_term TEXT NOT NULL,
    target_term TEXT NOT NULL,
    domain TEXT,                        -- e.g., "legal", "medical"
    notes TEXT,
    forbidden_translations TEXT,        -- JSON array of what NOT to use
    created_at DATETIME,
    modified_at DATETIME
);

CREATE INDEX idx_source_term ON terms(source_term);
```

**Project Segments (projects/{uuid}/segments.db):**
```sql
CREATE TABLE segments (
    id INTEGER PRIMARY KEY,
    sequence_order INTEGER NOT NULL,    -- Order in document
    source_text TEXT NOT NULL,
    target_text TEXT,                   -- NULL = untranslated
    status TEXT DEFAULT 'draft',        -- draft, confirmed, reviewed
    formatting TEXT,                    -- JSON: bold ranges, italics, etc.
    comments TEXT,                      -- JSON array of comments
    tm_match_percent INTEGER,           -- If auto-filled from TM
    locked BOOLEAN DEFAULT FALSE,
    modified_at DATETIME
);

CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    file_name TEXT NOT NULL,
    original_path TEXT,
    segment_start INTEGER,              -- First segment ID in this file
    segment_end INTEGER,                -- Last segment ID in this file
    word_count_source INTEGER,
    char_count_with_spaces INTEGER,
    char_count_no_spaces INTEGER,
    imported_at DATETIME
);
```

---

## 5. Core Features

### 5.1 Document Import

**Supported Formats:**
- Word (.docx) - Primary
- mxliff (Phrase) - Optional migration
- sdlxliff (Trados 2021) - Optional migration
- Plain text (.txt)

**Import Process:**
1. Parse document structure (paragraphs, tables, lists)
2. Segment text using Korean sentence rules
3. Preserve inline formatting (bold, italic, underline) as markup
4. Store original document for export reference
5. Calculate word/character counts

**Korean Segmentation Rules:**
- Segment on: 。 ? ! (Korean punctuation)
- Don't break on: 「」 『』 (quotation marks mid-sentence)
- Handle mixed Korean/English gracefully

### 5.2 Editor View

**Layout:**
```
┌────────────────────────────────────────────────────────────┐
│ [Project: Legal Contract v2] [File: chapter1.docx]         │
├────────────────────────────────────────────────────────────┤
│ #  │ Source (KO)              │ Target (EN)         │ St  │
├────────────────────────────────────────────────────────────┤
│ 1  │ 본 계약서는 갑과 을...    │ This contract...    │ ✓  │
│ 2  │ 계약 기간은 2026년...     │ The contract term...│ ✓  │
│ 3  │ [현재 편집중인 세그먼트]   │ [cursor here]       │ •  │
│ 4  │ 다음 문장입니다.          │                     │ ○  │
└────────────────────────────────────────────────────────────┘
```

**Status Indicators (3-state workflow: Draft → Confirmed → Reviewed):**
- ○ Empty (untranslated)
- • Draft (has content, unconfirmed)
- ✓ Confirmed (translator approved)
- ✓✓ Reviewed (QA/reviewer approved)
- ★ 100% TM match (auto-filled)
- ⚠ QA warning (needs attention)

**Keyboard Shortcuts:**
| Key | Action |
|-----|--------|
| Enter | Move to next segment |
| Ctrl+Enter | Confirm segment and move to next |
| ↑/↓ | Navigate between segments |
| Ctrl+Space | Copy source text to target |
| Ctrl+1 | Insert TM match #1 |
| Ctrl+2/3/4 | Insert TM match #2/#3/#4 |
| Ctrl+T | Add selected text to TB |
| Tab | Show TM matches panel |
| F7 | Run QA checks (document-wide) |

**Multiline Segments:**
- Each segment can contain multiple lines (newlines preserved)
- Arrow keys navigate between segments, not lines within a segment
- Use standard text editing within a segment (Home/End, Shift+arrows for selection)

### 5.3 TM Matching

**Match Types:**
- **100% Match:** Exact source text match
- **Context Match (101%):** 100% + same surrounding segments
- **Fuzzy Match (75-99%):** Similar source with differences highlighted

**CAT Panel Display:**
```
┌─────────────────────────────────────────┐
│ TM Matches                          [x] │
├─────────────────────────────────────────┤
│ ★ 100% - Legal_Contract_2025.docx      │
│   Modified: 2025-08-15                  │
│   Context: ...이전 문장 | 본 계약서는... │
│   Source: 본 계약서는 갑과 을 사이에     │
│   Target: This contract is between...   │
│   [Insert] [Edit & Insert]              │
├─────────────────────────────────────────┤
│ 87% - NDA_Template.docx                 │
│   Diff: 본 [계약서→합의서]는 갑과...     │
│   ...                                   │
└─────────────────────────────────────────┘
```

**Auto-propagation:**
- Optional: auto-fill 100% matches on import
- Optional: auto-fill during editing when typing matches existing TM
- User confirms before propagating to multiple segments

### 5.4 Term Base

**TB Panel:**
```
┌─────────────────────────────────────────┐
│ Terms Found                         [+] │
├─────────────────────────────────────────┤
│ 갑 → Party A                            │
│ 을 → Party B                            │
│ 계약 기간 → contract term               │
└─────────────────────────────────────────┘
```

**Quick Add to TB:**
1. Select source text
2. Press Ctrl+T
3. Enter target term
4. Optional: add domain/notes
5. Save

**TB Highlighting & Auto-Complete:**
- Source terms in TB are underlined in source pane
- Hover shows approved translation
- Click inserts term into target
- **Auto-complete:** As you type in target, TB matches appear as suggestions
  - Type first few characters → dropdown shows matching TB terms
  - Tab/Enter to accept suggestion
  - Works like IDE auto-complete for consistent terminology

### 5.5 Comments (Threaded)

**Comment Types:**
- Segment comment (attached to specific segment)
- Inline comment (attached to text selection)

**Threaded Discussion Structure:**
```json
{
  "id": "uuid",
  "text": "Check this term with client",
  "created_at": "2026-01-09T10:30:00Z",
  "resolved": false,
  "export_to_word": true,
  "replies": [
    {
      "id": "reply-uuid",
      "text": "Confirmed with client - use 'Party A'",
      "created_at": "2026-01-09T11:00:00Z"
    }
  ]
}
```

**Comment Panel UI:**
```
┌─────────────────────────────────────────┐
│ Comments (3)                        [+] │
├─────────────────────────────────────────┤
│ Seg 12: "Check this term with client"   │
│   └─ Reply: "Confirmed - use Party A"   │
│   [Reply] [Resolve ✓]                   │
├─────────────────────────────────────────┤
│ Seg 45: "Unclear source meaning"        │
│   [Reply] [Resolve ✓]                   │
└─────────────────────────────────────────┘
```

**Export Options:**
- Include comments as Word comments in exported file
- Include comments as footnotes
- Include only unresolved comments
- Exclude comments (clean export)

---

## 6. Import/Export

### 6.1 Bilingual Review Export

**Format:** Excel-compatible TSV/CSV
```
Seg#    Source              Target              Status    Comment
1       본 계약서는...       This contract...    confirmed
2       계약 기간은...       The contract...     draft     Check date
```

**Re-import Process:**
1. Load bilingual file
2. Match by segment number
3. Overwrite target text if changed
4. Preserve/merge comments
5. Update status

### 6.2 Word Export

**Process:**
1. Load original document structure
2. Replace source segments with confirmed targets
3. Apply inline formatting (bold, italic preserved)
4. Apply finalization rules if requested
5. Save as .docx

**Formatting Preservation:**
- Bold → `<b>text</b>` in segment → bold in export
- Italic → `<i>text</i>` in segment → italic in export
- Underline → `<u>text</u>` in segment → underline in export

### 6.3 Phrase Migration

**Import Capabilities:**
- mxliff files → projects
- Phrase TM export (TMX) → tm.db
- Phrase TB export (TBX/CSV) → tb.db

**Migration Workflow:**
1. Export all projects from Phrase as mxliff
2. Export TM as TMX
3. Export TB as TBX or CSV
4. Run Clarity CAT migration wizard
5. Verify segment counts match

---

## 7. QA System (Review Workflow)

### 7.1 Built-in QA Checks

**Segment-Level Checks** (run per segment):
| Check | Description | Severity |
|-------|-------------|----------|
| Extra spaces | Multiple consecutive spaces | Warning |
| Space after opening quote | `" text` instead of `"text` | Warning |
| Number mismatch | Numbers in source don't appear in target | Warning |
| Term violation | TB term not used correctly | Info |

**Document-Level Checks** (run across entire document):
| Check | Description | Severity |
|-------|-------------|----------|
| Missing/unmatched quotes | Unmatched " or ' across document | Error |
| Uncapitalized sentence | Sentence doesn't start with capital (full sentences, not segments) | Warning |
| Duplicate capitals | Same capitalized word twice in a sentence | Warning |
| Missing punctuation | Sentence doesn't end with . ! ? (applies to full sentences) | Warning |

**Note:** Document-level checks analyze the full translated text as continuous prose, not individual segments. This catches issues that span segment boundaries (e.g., a quote opened in segment 5 but never closed).

### 7.2 QA Panel

```
┌─────────────────────────────────────────┐
│ QA Issues (12)                      [▶] │
├─────────────────────────────────────────┤
│ ⚠ Seg 23: Extra spaces detected         │
│   "The  contract" → "The contract"      │
│   [Fix] [Ignore]                        │
├─────────────────────────────────────────┤
│ ✗ Seg 45: Missing closing quote         │
│   "This is incomplete                   │
│   [Go to segment]                       │
└─────────────────────────────────────────┘
```

### 7.3 Batch QA

- Run QA on entire project: F7
- Run QA on current file: Shift+F7
- Filter by severity: All / Errors only / Warnings only
- Export QA report to CSV

### 7.4 Auto-fix Capabilities

**"Clean Up" Button (Ctrl+Shift+Space):**

*Segment-level fixes:*
- Remove extra spaces (multiple → single)
- Trim leading/trailing whitespace

*Sentence-wide fixes (across segment boundaries):*
- Fix space after opening quotes (analyzes full sentences)
- Fix space before closing quotes (analyzes full sentences)

**Note:** Quote spacing fixes operate on complete sentences, not individual segments. A quote that opens in segment 5 and closes in segment 7 will be properly analyzed as one unit.

---

## 8. Finalization Workflow

### 8.1 Finalization Rules (Applied on Export)

**Standard Finalization Settings UI:**
```
┌─────────────────────────────────────────────────────────────┐
│ Standard Finalization Settings                    [Save]    │
├─────────────────────────────────────────────────────────────┤
│ Document Formatting                                         │
│   Font:         [Times New Roman    ▼]                     │
│   Size:         [12pt               ▼]                     │
│   Page Size:    [A4                 ▼]                     │
│   Margins:      [Normal (1" all)    ▼]                     │
├─────────────────────────────────────────────────────────────┤
│ Paragraph Settings                                          │
│   Alignment:    [Left               ▼]                     │
│   Indentation:  [None               ▼]                     │
│   Line Spacing: [1.0                ▼]                     │
│   After Para:   [8pt                ▼]                     │
├─────────────────────────────────────────────────────────────┤
│ Text Cleanup                                                │
│   ☑ Convert to smart quotes ("..." and '...')              │
│   ☑ Remove extra spaces                                     │
│   ☑ Remove double punctuation                               │
│   ☐ Trim trailing whitespace on lines                       │
└─────────────────────────────────────────────────────────────┘
```

**Defaults (can be customized):**
```yaml
formatting:
  font: "Times New Roman"
  size: 12pt
  page_size: A4
  margins: normal  # 1" all sides

paragraph:
  alignment: left
  indentation: none
  line_spacing: 1
  spacing_after: 8pt

text_cleanup:
  smart_quotes: true           # "..." and '...'
  remove_extra_spaces: true
  remove_double_punctuation: true
```

### 8.2 Client-Specific Rules

**Client Profile Management UI:**
```
┌─────────────────────────────────────────────────────────────┐
│ Client Profiles                              [+ New Client] │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│ │Legal    │ │Medical  │ │Tech Co  │ │Finance  │           │
│ │Corp     │ │Inc      │ │         │ │Ltd      │           │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
├─────────────────────────────────────────────────────────────┤
│ Editing: Legal Corp                            [Rename] [×] │
├─────────────────────────────────────────────────────────────┤
│ Find-Replace Rules:                                         │
│ ┌───────────────────┬───────────────────┬──────┬─────────┐ │
│ │ Find              │ Replace           │ Case │         │ │
│ ├───────────────────┼───────────────────┼──────┼─────────┤ │
│ │ Party A           │ the First Party   │ ☑   │ [Edit]  │ │
│ │ Party B           │ the Second Party  │ ☑   │ [Edit]  │ │
│ │ hereinafter       │ hereafter         │ ☐   │ [Edit]  │ │
│ └───────────────────┴───────────────────┴──────┴─────────┘ │
│                                             [+ Add Rule]    │
├─────────────────────────────────────────────────────────────┤
│ [Test Rules on Sample] [Import from CSV] [Export to CSV]   │
└─────────────────────────────────────────────────────────────┘
```

**Storage Format (in app_settings.db):**
```yaml
clients:
  ClientA:
    name: "Legal Corp"
    find_replace:
      - find: "Party A"
        replace: "the First Party"
        case_sensitive: true
      - find: "Party B"
        replace: "the Second Party"
      - find: "hereinafter"
        replace: "hereafter"

  ClientB:
    name: "Medical Inc"
    find_replace:
      - find: "patient"
        replace: "client"
        case_sensitive: false
```

**Export Dialog (applies both standard + client rules):**
```
┌─────────────────────────────────────────────────────────────┐
│ Export with Finalization                                    │
├─────────────────────────────────────────────────────────────┤
│ Standard Finalization:                                      │
│   ☑ Apply document formatting (Times New Roman, A4, etc.)  │
│   ☑ Smart quotes                                            │
│   ☑ Remove extra spaces                                     │
├─────────────────────────────────────────────────────────────┤
│ Client Rules:                                               │
│   [Legal Corp     ▼] (3 find-replace rules)                │
│   ☑ Apply client-specific find-replace                     │
├─────────────────────────────────────────────────────────────┤
│ Preview: "the First Party agrees to..." (hover for more)   │
│                                                             │
│ [Export with Rules] [Export Clean] [Cancel]                │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Cloud Sync & Backup

### 9.1 Sync Strategy

**File Location:**
- User chooses cloud folder (iCloud/OneDrive/Dropbox)
- All databases stored in this folder
- Native cloud provider handles sync

**Conflict Prevention:**
- SQLite WAL mode (safe for cloud sync)
- File locking when editing
- On startup: fast check for newer remote version (< 500ms)

**Sync Status Display (CRITICAL UX):**

The sync status must be:
1. **Always visible** in the status bar
2. **Instant feedback** - show "Saving..." immediately on edit
3. **Clear states** - no ambiguous icons

```
┌────────────────────────────────────────────────────────────────┐
│ Status Bar (always visible at bottom)                          │
├────────────────────────────────────────────────────────────────┤
│ Seg 42/150 │ Words: 12,450 │ [✓ Saved] │ [☁ Synced 10s ago]  │
│ Seg 42/150 │ Words: 12,450 │ [● Saving...] │ [☁ Syncing...]   │
│ Seg 42/150 │ Words: 12,450 │ [✓ Saved] │ [⚡ Offline mode]    │
│ Seg 42/150 │ Words: 12,450 │ [✓ Saved] │ [⚠ Sync conflict]   │
└────────────────────────────────────────────────────────────────┘
```

**Sync States:**
| Icon | State | Color | Meaning |
|------|-------|-------|---------|
| ✓ | Saved | Green | All changes written to local database |
| ● | Saving | Yellow | Writing to local database (< 100ms typically) |
| ☁ | Synced | Blue | Cloud provider has latest version |
| ↑ | Syncing | Blue pulse | Uploading to cloud (shows progress for large files) |
| ⚡ | Offline | Gray | No internet, changes saved locally |
| ⚠ | Conflict | Red | Manual resolution needed (click for details) |

**Performance Targets:**
- Local save: < 100ms (user should never wait)
- Startup sync check: < 500ms
- Conflict detection: immediate on file focus

### 9.2 Backup System

**Automatic Backups:**
- Every 10 minutes: incremental backup to backups/
- Daily: full snapshot at midnight
- Keep 7 daily backups, 4 weekly backups

**Manual Backup:**
- Export entire workspace as ZIP
- Export project as JSON (human-readable)

**Recovery:**
- "Restore from backup" in File menu
- Browse backup history by date
- Preview before restore

### 9.3 Fail-Safe Features

1. **Write-ahead logging:** SQLite WAL prevents corruption
2. **Atomic saves:** Temp file → rename pattern
3. **Version history:** Last 100 edits per segment stored
4. **Crash recovery:** Auto-recover unsaved changes on restart
5. **Export on close:** Option to auto-export bilingual backup on project close

---

## 10. TM/TB Management

### 10.1 TM Management View

```
┌─────────────────────────────────────────────────────────────┐
│ Translation Memory                              [512,847]   │
├─────────────────────────────────────────────────────────────┤
│ Search: [_____________________] [Source ▼] [🔍]            │
├─────────────────────────────────────────────────────────────┤
│ Source              │ Target              │ File    │ Date  │
│ 본 계약서는...       │ This contract...    │ Legal1  │ 01/05 │
│ 계약 기간은...       │ The contract...     │ Legal1  │ 01/05 │
│ ...                                                         │
├─────────────────────────────────────────────────────────────┤
│ [Delete Selected] [Export TMX] [Import TMX] [Maintenance]  │
└─────────────────────────────────────────────────────────────┘
```

**TM Maintenance:**
- Remove duplicates
- Merge similar entries
- Bulk delete by date/project
- Statistics (entries by domain, age distribution)

### 10.2 TB Management View

```
┌─────────────────────────────────────────────────────────────┐
│ Term Base                                          [3,421]  │
├─────────────────────────────────────────────────────────────┤
│ Search: [_____________________] [🔍]                        │
├─────────────────────────────────────────────────────────────┤
│ Source    │ Target       │ Domain    │ Notes               │
│ 갑        │ Party A      │ Legal     │ Standard contract   │
│ 을        │ Party B      │ Legal     │ Standard contract   │
│ 계약      │ contract     │ Legal     │                     │
├─────────────────────────────────────────────────────────────┤
│ [Add Term] [Edit] [Delete] [Export TBX] [Import TBX]       │
└─────────────────────────────────────────────────────────────┘
```

---

## 11. User Interface

### 11.1 Main Window Layout

```
┌────────────────────────────────────────────────────────────────────┐
│ Clarity CAT                                              [─][□][×] │
├────────────────────────────────────────────────────────────────────┤
│ File  Edit  View  Project  Tools  Help              [☁ Synced]    │
├────────────────────────────────────────────────────────────────────┤
│        │                                    │                      │
│ Files  │  #  │ Source        │ Target      │  TM Matches          │
│        │ ────┼───────────────┼─────────────│                      │
│ ▼ Proj │  1  │ 본 계약서는...│ This cont...│  ★ 100% Legal.docx   │
│   ├doc1│  2  │ 계약 기간...  │ The term... │                      │
│   ├doc2│  3  │ [editing]     │ [cursor]    │  Terms               │
│   └doc3│  4  │ 다음 문장...  │             │  갑 → Party A        │
│        │                                    │                      │
│        │                                    │  QA (2 warnings)     │
│        │                                    │  ⚠ Extra space #3    │
├────────────────────────────────────────────────────────────────────┤
│ Segment 3/150 │ Words: 45,231 │ Progress: 67% │ Draft              │
└────────────────────────────────────────────────────────────────────┘
```

### 11.2 Color Schemes

**Built-in Themes (based on popular VS Code themes):**

| Theme | Type | Based On | Best For |
|-------|------|----------|----------|
| Clarity Light | Light | Default | Daytime work |
| Clarity Dark | Dark | Default | Night work |
| One Dark Pro | Dark | One Dark Pro | Popular dark theme |
| Dracula | Dark | Dracula | High contrast |
| Solarized Light | Light | Solarized | Reduced eye strain |
| Solarized Dark | Dark | Solarized | Warm dark colors |
| GitHub Light | Light | GitHub | Clean, minimal |
| GitHub Dark | Dark | GitHub Dimmed | Subtle contrast |
| Nord | Dark | Nord | Cool blue tones |
| Monokai | Dark | Monokai Pro | Vibrant colors |

**Theme Preview (Clarity Light - Default):**
```
┌─────────────────────────────────────────────────────────────┐
│ Theme Settings                                              │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐           │
│ │Clarity  │ │One Dark │ │Dracula  │ │Solarized│           │
│ │ Light ✓ │ │  Pro    │ │         │ │  Light  │           │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘           │
├─────────────────────────────────────────────────────────────┤
│ Preview:                                                    │
│ ┌─────────────────────────────────────────────────────────┐│
│ │ Source (KO)              │ Target (EN)                  ││
│ │ 본 [계약서]는...          │ This [contract]...          ││
│ │ (TB term underlined)     │ (100% TM match highlight)   ││
│ └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

**Semantic Colors (consistent across themes):**
- Source text: Neutral (adapts to theme)
- Target text: Accent blue (varies by theme)
- TM match highlight: Light blue background
- TB term: Green underline
- QA warning: Orange/yellow
- QA error: Red
- Comments: Purple/magenta

### 11.3 Preferences

```yaml
preferences:
  theme: light | dark | system
  font_size: 14
  editor_font: "Noto Sans KR"  # Good for Korean
  auto_propagate_100: true
  auto_save_interval: 500ms
  show_segment_numbers: true
  keyboard_layout: standard | vim
  cloud_folder: "/Users/josh/iCloud/ClarityCAT"
```

---

## 12. Statistics & Reporting

### 12.1 Project Statistics

**Project Overview:**
```
┌─────────────────────────────────────────────────────────────┐
│ Project: Legal Contract Translation                         │
├─────────────────────────────────────────────────────────────┤
│ Source Document Stats:                                      │
│   Total words:           45,231                             │
│   Characters (spaces):   267,483                            │
│   Characters (no space): 223,156                            │
│   Segments:              1,847                              │
├─────────────────────────────────────────────────────────────┤
│ Translation Progress:                                       │
│   Translated:    1,245 (67.4%)  ████████████░░░░░░          │
│   Confirmed:       892 (48.3%)  █████████░░░░░░░░░          │
│   Remaining:       602 (32.6%)                              │
├─────────────────────────────────────────────────────────────┤
│ TM Leverage:                                                │
│   100% matches:    423 (22.9%)                              │
│   85-99% fuzzy:    312 (16.9%)                              │
│   75-84% fuzzy:    198 (10.7%)                              │
│   No match:        914 (49.5%)                              │
└─────────────────────────────────────────────────────────────┘
```

### 12.2 Multi-File Statistics

**Select multiple files to see per-file breakdown (SOURCE text counts):**
```
┌─────────────────────────────────────────────────────────────┐
│ File Statistics (Source Text)             [Select Files ▼]  │
├─────────────────────────────────────────────────────────────┤
│ ☑ Select All  │  3 files selected                          │
├─────────────────────────────────────────────────────────────┤
│ File Name          │ Src Words │ Src Chars │ Src Chars │ Progress │
│                    │           │ (w/space) │ (no space)│          │
├────────────────────┼───────────┼───────────┼───────────┼──────────┤
│ ☑ chapter1.docx    │    12,450 │    73,521 │    61,234 │ 100% ✓   │
│ ☑ chapter2.docx    │    18,721 │   110,832 │    92,456 │  85%     │
│ ☑ chapter3.docx    │    14,060 │    83,130 │    69,466 │  42%     │
│ ☐ appendix.docx    │     5,200 │    30,780 │    25,670 │   0%     │
├────────────────────┼───────────┼───────────┼───────────┼──────────┤
│ SELECTED TOTAL     │    45,231 │   267,483 │   223,156 │  73%     │
└─────────────────────────────────────────────────────────────┘
│ [Copy to Clipboard] [Export CSV] [Print]                    │
└─────────────────────────────────────────────────────────────┘
```

**Note:** All word/character counts are based on **source text** (Korean), which is the standard for translation pricing and project estimation.

**Export Options:**
- Copy table to clipboard (for pasting into invoices/emails)
- Export as CSV
- Print statistics report

---

## 13. Future Extensibility

### 13.1 Plugin Architecture (v2)

Reserved for future custom workflows:
- Review workflow plugins
- Custom QA rules
- Export format plugins
- Integration hooks

### 13.2 Reserved Features (Not in v1)

- Machine translation integration
- Multi-user collaboration
- API access
- Mobile companion app

---

## 14. Implementation Phases

### Phase 1: Core MVP
- [ ] Project creation/management
- [ ] Word document import/export
- [ ] Basic editor (source/target segments)
- [ ] SQLite storage with cloud folder
- [ ] Basic TM matching (100% only)
- [ ] Auto-save

### Phase 2: Full TM/TB
- [ ] Fuzzy matching (75%+) with FTS5
- [ ] TM management UI
- [ ] Term Base with highlighting
- [ ] TB quick-add
- [ ] Context display in TM matches

### Phase 3: QA & Workflows
- [ ] All QA checks (quotes, spaces, caps)
- [ ] QA panel with fix/ignore
- [ ] Finalization rules engine
- [ ] Client profiles for find-replace
- [ ] Bilingual export/re-import

### Phase 4: Migration & Polish
- [ ] Phrase mxliff import
- [ ] Trados sdlxliff import
- [ ] TMX/TBX import
- [ ] Backup system
- [ ] Statistics dashboard
- [ ] Keyboard shortcut customization

---

## 15. Design Decisions (Resolved)

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Segment status workflow** | Draft → Confirmed → Reviewed (3 states) | Full workflow supports QA review stage |
| **Keyboard scheme** | Enter = next, Ctrl+Enter = confirm+next | Faster navigation, explicit confirmation |
| **TM penalty system** | Yes, context mismatches penalized (100% → 99%) | Encourages in-context matches |
| **Comment threading** | Threaded discussions | Better for complex review conversations |
| **TM/TB scope** | Per-project (not unified) | Prevents cross-client contamination |

---

## Appendix A: File Format Details

### A.1 Project JSON Export

```json
{
  "version": "1.0",
  "project": {
    "id": "uuid",
    "name": "Legal Contract v2",
    "source_lang": "ko",
    "target_lang": "en",
    "created": "2026-01-09T10:00:00Z"
  },
  "files": [
    {
      "name": "chapter1.docx",
      "segments": [
        {
          "id": 1,
          "source": "본 계약서는 갑과 을 사이에...",
          "target": "This contract is between...",
          "status": "confirmed",
          "formatting": {"bold": [[0, 3]]},
          "comments": []
        }
      ]
    }
  ]
}
```

### A.2 Bilingual Review Format

```tsv
Segment	Source	Target	Status	Comment	Modified
1	본 계약서는...	This contract...	confirmed		2026-01-09 10:30
2	계약 기간은...	The contract term...	draft	Check date format	2026-01-09 10:31
```

---

*Document generated: 2026-01-09*

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
