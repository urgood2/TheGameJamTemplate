# Clarity CAT Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a cloud-native CAT (Computer-Assisted Translation) tool optimized for KO→EN solo translation workflow, replacing Phrase with a lightweight, fast alternative.

**Architecture:** Tauri 2.0 app with Rust backend handling document parsing, TM/TB matching, and SQLite operations. SvelteKit frontend provides the editor UI with reactive segment editing. All data stored in SQLite databases within a cloud-synced folder (iCloud/OneDrive/Dropbox) for seamless Mac↔Windows portability.

**Tech Stack:** Tauri 2.0, Rust, SvelteKit, TailwindCSS, SQLite + FTS5, docx-rs

---

## Project Setup

### Task 1: Initialize Tauri + SvelteKit Project

**Files:**
- Create: `clarity-cat/` (new project root)
- Create: `clarity-cat/src-tauri/` (Rust backend)
- Create: `clarity-cat/src/` (SvelteKit frontend)

**Step 1: Create project directory and initialize Tauri**

```bash
cd ~/Projects
npm create tauri-app@latest clarity-cat -- --template sveltekit-ts
cd clarity-cat
```

**Step 2: Verify project structure**

```bash
ls -la
# Expected:
# src-tauri/  (Rust backend)
# src/        (SvelteKit frontend)
# package.json
# svelte.config.js
# vite.config.ts
```

**Step 3: Install additional frontend dependencies**

```bash
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

**Step 4: Configure TailwindCSS**

Create `tailwind.config.js`:
```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

Update `src/app.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**Step 5: Add Rust dependencies to Cargo.toml**

Edit `src-tauri/Cargo.toml`:
```toml
[dependencies]
tauri = { version = "2", features = [] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rusqlite = { version = "0.31", features = ["bundled", "vtab"] }
thiserror = "1"
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
```

**Step 6: Run dev server to verify setup**

```bash
npm run tauri dev
```
Expected: Tauri window opens with SvelteKit app

**Step 7: Commit**

```bash
git init
git add .
git commit -m "chore: initialize Tauri + SvelteKit project with TailwindCSS"
```

---

### Task 2: Create SQLite Database Module (Rust)

**Files:**
- Create: `src-tauri/src/db/mod.rs`
- Create: `src-tauri/src/db/connection.rs`
- Create: `src-tauri/src/db/migrations.rs`
- Modify: `src-tauri/src/lib.rs`

**Step 1: Create db module structure**

Create `src-tauri/src/db/mod.rs`:
```rust
pub mod connection;
pub mod migrations;

pub use connection::Database;
```

**Step 2: Write failing test for database connection**

Create `src-tauri/src/db/connection.rs`:
```rust
use rusqlite::{Connection, Result as SqliteResult};
use std::path::Path;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DbError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open or create a database at the given path
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, DbError> {
        let conn = Connection::open(path)?;
        // Enable WAL mode for cloud sync safety
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        Ok(Self { conn })
    }

    /// Create an in-memory database (for testing)
    pub fn in_memory() -> Result<Self, DbError> {
        let conn = Connection::open_in_memory()?;
        Ok(Self { conn })
    }

    pub fn connection(&self) -> &Connection {
        &self.conn
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_open_in_memory() {
        let db = Database::in_memory();
        assert!(db.is_ok());
    }

    #[test]
    fn test_open_file() {
        let temp_dir = std::env::temp_dir();
        let db_path = temp_dir.join("test_clarity_cat.db");

        let db = Database::open(&db_path);
        assert!(db.is_ok());

        // Cleanup
        std::fs::remove_file(&db_path).ok();
    }
}
```

**Step 3: Run tests to verify**

```bash
cd src-tauri
cargo test db::connection::tests
```
Expected: 2 tests pass

**Step 4: Commit**

```bash
git add src-tauri/src/db/
git commit -m "feat(db): add SQLite database connection module with WAL mode"
```

---

### Task 3: Create Database Migrations for Project Segments

**Files:**
- Modify: `src-tauri/src/db/migrations.rs`

**Step 1: Write failing test for migrations**

Create `src-tauri/src/db/migrations.rs`:
```rust
use rusqlite::Connection;
use crate::db::DbError;

/// Run all migrations on the given connection
pub fn run_migrations(conn: &Connection) -> Result<(), DbError> {
    // Create version tracking table
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        );"
    )?;

    let current_version: i32 = conn
        .query_row(
            "SELECT COALESCE(MAX(version), 0) FROM schema_version",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    if current_version < 1 {
        migrate_v1(conn)?;
    }

    Ok(())
}

fn migrate_v1(conn: &Connection) -> Result<(), DbError> {
    conn.execute_batch(
        r#"
        -- Project segments table
        CREATE TABLE IF NOT EXISTS segments (
            id INTEGER PRIMARY KEY,
            sequence_order INTEGER NOT NULL,
            source_text TEXT NOT NULL,
            target_text TEXT,
            status TEXT DEFAULT 'draft' CHECK(status IN ('draft', 'confirmed', 'reviewed')),
            formatting TEXT,
            comments TEXT,
            tm_match_percent INTEGER,
            locked INTEGER DEFAULT 0,
            modified_at TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_segments_sequence ON segments(sequence_order);

        -- Files table
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY,
            file_name TEXT NOT NULL,
            original_path TEXT,
            segment_start INTEGER,
            segment_end INTEGER,
            word_count_source INTEGER,
            char_count_with_spaces INTEGER,
            char_count_no_spaces INTEGER,
            imported_at TEXT
        );

        -- Record migration
        INSERT INTO schema_version (version, applied_at) VALUES (1, datetime('now'));
        "#
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    #[test]
    fn test_migrations_create_tables() {
        let conn = Connection::open_in_memory().unwrap();

        let result = run_migrations(&conn);
        assert!(result.is_ok());

        // Verify segments table exists
        let count: i32 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='segments'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1);
    }

    #[test]
    fn test_migrations_idempotent() {
        let conn = Connection::open_in_memory().unwrap();

        // Run twice - should not error
        run_migrations(&conn).unwrap();
        let result = run_migrations(&conn);
        assert!(result.is_ok());
    }
}
```

**Step 2: Update db/mod.rs to include migrations**

```rust
pub mod connection;
pub mod migrations;

pub use connection::{Database, DbError};
pub use migrations::run_migrations;
```

**Step 3: Run tests**

```bash
cd src-tauri
cargo test db::migrations::tests
```
Expected: 2 tests pass

**Step 4: Commit**

```bash
git add src-tauri/src/db/
git commit -m "feat(db): add migrations for segments and files tables"
```

---

### Task 4: Create TM Database Schema

**Files:**
- Create: `src-tauri/src/db/tm_migrations.rs`
- Modify: `src-tauri/src/db/mod.rs`

**Step 1: Write TM migrations with FTS5**

Create `src-tauri/src/db/tm_migrations.rs`:
```rust
use rusqlite::Connection;
use crate::db::DbError;

/// Run TM-specific migrations
pub fn run_tm_migrations(conn: &Connection) -> Result<(), DbError> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS tm_schema_version (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        );"
    )?;

    let current_version: i32 = conn
        .query_row(
            "SELECT COALESCE(MAX(version), 0) FROM tm_schema_version",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    if current_version < 1 {
        migrate_tm_v1(conn)?;
    }

    Ok(())
}

fn migrate_tm_v1(conn: &Connection) -> Result<(), DbError> {
    conn.execute_batch(
        r#"
        -- Translation Memory segments
        CREATE TABLE IF NOT EXISTS tm_segments (
            id INTEGER PRIMARY KEY,
            source_text TEXT NOT NULL,
            target_text TEXT NOT NULL,
            source_hash TEXT NOT NULL,
            source_normalized TEXT NOT NULL,
            context_before TEXT,
            context_after TEXT,
            file_name TEXT,
            project_name TEXT,
            created_at TEXT,
            modified_at TEXT,
            usage_count INTEGER DEFAULT 1
        );

        CREATE INDEX IF NOT EXISTS idx_tm_source_hash ON tm_segments(source_hash);

        -- FTS5 virtual table for fuzzy matching
        CREATE VIRTUAL TABLE IF NOT EXISTS tm_segments_fts USING fts5(
            source_normalized,
            target_text,
            content='tm_segments',
            content_rowid='id'
        );

        -- Triggers to keep FTS in sync
        CREATE TRIGGER IF NOT EXISTS tm_segments_ai AFTER INSERT ON tm_segments BEGIN
            INSERT INTO tm_segments_fts(rowid, source_normalized, target_text)
            VALUES (new.id, new.source_normalized, new.target_text);
        END;

        CREATE TRIGGER IF NOT EXISTS tm_segments_ad AFTER DELETE ON tm_segments BEGIN
            INSERT INTO tm_segments_fts(tm_segments_fts, rowid, source_normalized, target_text)
            VALUES ('delete', old.id, old.source_normalized, old.target_text);
        END;

        CREATE TRIGGER IF NOT EXISTS tm_segments_au AFTER UPDATE ON tm_segments BEGIN
            INSERT INTO tm_segments_fts(tm_segments_fts, rowid, source_normalized, target_text)
            VALUES ('delete', old.id, old.source_normalized, old.target_text);
            INSERT INTO tm_segments_fts(rowid, source_normalized, target_text)
            VALUES (new.id, new.source_normalized, new.target_text);
        END;

        -- Record migration
        INSERT INTO tm_schema_version (version, applied_at) VALUES (1, datetime('now'));
        "#
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    #[test]
    fn test_tm_migrations() {
        let conn = Connection::open_in_memory().unwrap();

        let result = run_tm_migrations(&conn);
        assert!(result.is_ok());

        // Verify FTS table exists
        let count: i32 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='tm_segments_fts'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1);
    }

    #[test]
    fn test_fts_insert_trigger() {
        let conn = Connection::open_in_memory().unwrap();
        run_tm_migrations(&conn).unwrap();

        // Insert a TM entry
        conn.execute(
            "INSERT INTO tm_segments (source_text, target_text, source_hash, source_normalized)
             VALUES ('안녕하세요', 'Hello', 'hash123', '안녕하세요')",
            [],
        ).unwrap();

        // Verify FTS was populated
        let count: i32 = conn
            .query_row(
                "SELECT COUNT(*) FROM tm_segments_fts WHERE source_normalized MATCH '안녕하세요'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1);
    }
}
```

**Step 2: Update mod.rs**

```rust
pub mod connection;
pub mod migrations;
pub mod tm_migrations;

pub use connection::{Database, DbError};
pub use migrations::run_migrations;
pub use tm_migrations::run_tm_migrations;
```

**Step 3: Run tests**

```bash
cd src-tauri
cargo test db::tm_migrations::tests
```
Expected: 2 tests pass

**Step 4: Commit**

```bash
git add src-tauri/src/db/
git commit -m "feat(db): add TM schema with FTS5 for fuzzy matching"
```

---

### Task 5: Create Term Base Schema

**Files:**
- Create: `src-tauri/src/db/tb_migrations.rs`
- Modify: `src-tauri/src/db/mod.rs`

**Step 1: Write TB migrations**

Create `src-tauri/src/db/tb_migrations.rs`:
```rust
use rusqlite::Connection;
use crate::db::DbError;

/// Run TB-specific migrations
pub fn run_tb_migrations(conn: &Connection) -> Result<(), DbError> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS tb_schema_version (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        );"
    )?;

    let current_version: i32 = conn
        .query_row(
            "SELECT COALESCE(MAX(version), 0) FROM tb_schema_version",
            [],
            |row| row.get(0),
        )
        .unwrap_or(0);

    if current_version < 1 {
        migrate_tb_v1(conn)?;
    }

    Ok(())
}

fn migrate_tb_v1(conn: &Connection) -> Result<(), DbError> {
    conn.execute_batch(
        r#"
        -- Term Base entries
        CREATE TABLE IF NOT EXISTS terms (
            id INTEGER PRIMARY KEY,
            source_term TEXT NOT NULL,
            target_term TEXT NOT NULL,
            domain TEXT,
            notes TEXT,
            forbidden_translations TEXT,
            created_at TEXT,
            modified_at TEXT
        );

        CREATE INDEX IF NOT EXISTS idx_terms_source ON terms(source_term);

        -- Record migration
        INSERT INTO tb_schema_version (version, applied_at) VALUES (1, datetime('now'));
        "#
    )?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    #[test]
    fn test_tb_migrations() {
        let conn = Connection::open_in_memory().unwrap();

        let result = run_tb_migrations(&conn);
        assert!(result.is_ok());

        // Verify terms table exists
        let count: i32 = conn
            .query_row(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='terms'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        assert_eq!(count, 1);
    }
}
```

**Step 2: Update mod.rs**

```rust
pub mod connection;
pub mod migrations;
pub mod tm_migrations;
pub mod tb_migrations;

pub use connection::{Database, DbError};
pub use migrations::run_migrations;
pub use tm_migrations::run_tm_migrations;
pub use tb_migrations::run_tb_migrations;
```

**Step 3: Run tests**

```bash
cd src-tauri
cargo test db::tb_migrations::tests
```
Expected: 1 test passes

**Step 4: Commit**

```bash
git add src-tauri/src/db/
git commit -m "feat(db): add Term Base schema"
```

---

### Task 6: Create Project Manager (Rust)

**Files:**
- Create: `src-tauri/src/project/mod.rs`
- Create: `src-tauri/src/project/manager.rs`
- Create: `src-tauri/src/project/types.rs`

**Step 1: Define project types**

Create `src-tauri/src/project/types.rs`:
```rust
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub id: Uuid,
    pub name: String,
    pub source_lang: String,
    pub target_lang: String,
    pub created_at: DateTime<Utc>,
    pub modified_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectMetadata {
    pub version: String,
    pub project: Project,
}

impl Project {
    pub fn new(name: String, source_lang: String, target_lang: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            name,
            source_lang,
            target_lang,
            created_at: now,
            modified_at: now,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Segment {
    pub id: i64,
    pub sequence_order: i32,
    pub source_text: String,
    pub target_text: Option<String>,
    pub status: SegmentStatus,
    pub formatting: Option<String>,
    pub comments: Option<String>,
    pub tm_match_percent: Option<i32>,
    pub locked: bool,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SegmentStatus {
    Draft,
    Confirmed,
    Reviewed,
}

impl Default for SegmentStatus {
    fn default() -> Self {
        Self::Draft
    }
}

impl std::fmt::Display for SegmentStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Draft => write!(f, "draft"),
            Self::Confirmed => write!(f, "confirmed"),
            Self::Reviewed => write!(f, "reviewed"),
        }
    }
}
```

**Step 2: Create project manager**

Create `src-tauri/src/project/manager.rs`:
```rust
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;
use crate::db::{Database, DbError, run_migrations, run_tm_migrations, run_tb_migrations};
use crate::project::types::{Project, ProjectMetadata};

#[derive(Error, Debug)]
pub enum ProjectError {
    #[error("Database error: {0}")]
    Db(#[from] DbError),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("Project not found: {0}")]
    NotFound(String),
}

pub struct ProjectManager {
    root_path: PathBuf,
}

impl ProjectManager {
    pub fn new<P: AsRef<Path>>(root_path: P) -> Self {
        Self {
            root_path: root_path.as_ref().to_path_buf(),
        }
    }

    /// Create a new project
    pub fn create_project(&self, name: String, source_lang: String, target_lang: String) -> Result<Project, ProjectError> {
        let project = Project::new(name, source_lang, target_lang);
        let project_path = self.project_path(&project.id);

        // Create directory structure
        fs::create_dir_all(&project_path)?;
        fs::create_dir_all(project_path.join("source_files"))?;
        fs::create_dir_all(project_path.join("backups"))?;

        // Write project.json
        let metadata = ProjectMetadata {
            version: "1.0".to_string(),
            project: project.clone(),
        };
        let json = serde_json::to_string_pretty(&metadata)?;
        fs::write(project_path.join("project.json"), json)?;

        // Create and initialize databases
        let segments_db = Database::open(project_path.join("segments.db"))?;
        run_migrations(segments_db.connection())?;

        let tm_db = Database::open(project_path.join("tm.db"))?;
        run_tm_migrations(tm_db.connection())?;

        let tb_db = Database::open(project_path.join("tb.db"))?;
        run_tb_migrations(tb_db.connection())?;

        Ok(project)
    }

    /// List all projects
    pub fn list_projects(&self) -> Result<Vec<Project>, ProjectError> {
        let projects_path = self.root_path.join("projects");
        if !projects_path.exists() {
            return Ok(vec![]);
        }

        let mut projects = Vec::new();
        for entry in fs::read_dir(projects_path)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_dir() {
                let project_json = path.join("project.json");
                if project_json.exists() {
                    let content = fs::read_to_string(project_json)?;
                    let metadata: ProjectMetadata = serde_json::from_str(&content)?;
                    projects.push(metadata.project);
                }
            }
        }

        Ok(projects)
    }

    fn project_path(&self, id: &uuid::Uuid) -> PathBuf {
        self.root_path.join("projects").join(id.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_create_project() {
        let temp_dir = TempDir::new().unwrap();
        let manager = ProjectManager::new(temp_dir.path());

        let project = manager.create_project(
            "Test Project".to_string(),
            "ko".to_string(),
            "en".to_string(),
        );

        assert!(project.is_ok());
        let project = project.unwrap();
        assert_eq!(project.name, "Test Project");
        assert_eq!(project.source_lang, "ko");
        assert_eq!(project.target_lang, "en");
    }

    #[test]
    fn test_list_projects() {
        let temp_dir = TempDir::new().unwrap();
        let manager = ProjectManager::new(temp_dir.path());

        // Create two projects
        manager.create_project("Project 1".to_string(), "ko".to_string(), "en".to_string()).unwrap();
        manager.create_project("Project 2".to_string(), "ko".to_string(), "en".to_string()).unwrap();

        let projects = manager.list_projects().unwrap();
        assert_eq!(projects.len(), 2);
    }
}
```

**Step 3: Create mod.rs**

Create `src-tauri/src/project/mod.rs`:
```rust
pub mod manager;
pub mod types;

pub use manager::{ProjectManager, ProjectError};
pub use types::{Project, Segment, SegmentStatus};
```

**Step 4: Add tempfile dev dependency**

Update `src-tauri/Cargo.toml`:
```toml
[dev-dependencies]
tempfile = "3"
```

**Step 5: Run tests**

```bash
cd src-tauri
cargo test project::manager::tests
```
Expected: 2 tests pass

**Step 6: Commit**

```bash
git add src-tauri/
git commit -m "feat(project): add project manager with create and list operations"
```

---

### Task 7: Create Tauri Commands for Project Management

**Files:**
- Create: `src-tauri/src/commands/mod.rs`
- Create: `src-tauri/src/commands/project.rs`
- Modify: `src-tauri/src/lib.rs`

**Step 1: Create project commands**

Create `src-tauri/src/commands/project.rs`:
```rust
use tauri::State;
use std::sync::Mutex;
use crate::project::{ProjectManager, Project};

pub struct AppState {
    pub project_manager: Mutex<ProjectManager>,
}

#[tauri::command]
pub fn create_project(
    state: State<AppState>,
    name: String,
    source_lang: String,
    target_lang: String,
) -> Result<Project, String> {
    let manager = state.project_manager.lock().map_err(|e| e.to_string())?;
    manager
        .create_project(name, source_lang, target_lang)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn list_projects(state: State<AppState>) -> Result<Vec<Project>, String> {
    let manager = state.project_manager.lock().map_err(|e| e.to_string())?;
    manager.list_projects().map_err(|e| e.to_string())
}
```

**Step 2: Create commands mod.rs**

Create `src-tauri/src/commands/mod.rs`:
```rust
pub mod project;

pub use project::{create_project, list_projects, AppState};
```

**Step 3: Update lib.rs to wire everything together**

Update `src-tauri/src/lib.rs`:
```rust
mod commands;
mod db;
mod project;

use commands::{create_project, list_projects, AppState};
use project::ProjectManager;
use std::sync::Mutex;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            // Get app data directory
            let app_data = app.path().app_data_dir().expect("Failed to get app data dir");
            std::fs::create_dir_all(&app_data).expect("Failed to create app data dir");

            // Initialize project manager
            let project_manager = ProjectManager::new(&app_data);

            app.manage(AppState {
                project_manager: Mutex::new(project_manager),
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            create_project,
            list_projects,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**Step 4: Build to verify compilation**

```bash
cd src-tauri
cargo build
```
Expected: Build succeeds

**Step 5: Commit**

```bash
git add src-tauri/src/
git commit -m "feat(commands): add Tauri commands for project management"
```

---

### Task 8: Create SvelteKit Project List UI

**Files:**
- Create: `src/lib/stores/projects.ts`
- Create: `src/lib/components/ProjectList.svelte`
- Modify: `src/routes/+page.svelte`

**Step 1: Create projects store**

Create `src/lib/stores/projects.ts`:
```typescript
import { writable } from 'svelte/store';
import { invoke } from '@tauri-apps/api/core';

export interface Project {
  id: string;
  name: string;
  source_lang: string;
  target_lang: string;
  created_at: string;
  modified_at: string;
}

export const projects = writable<Project[]>([]);
export const loading = writable(false);
export const error = writable<string | null>(null);

export async function loadProjects() {
  loading.set(true);
  error.set(null);
  try {
    const result = await invoke<Project[]>('list_projects');
    projects.set(result);
  } catch (e) {
    error.set(String(e));
  } finally {
    loading.set(false);
  }
}

export async function createProject(name: string, sourceLang: string, targetLang: string): Promise<Project> {
  const result = await invoke<Project>('create_project', {
    name,
    sourceLang,
    targetLang,
  });
  await loadProjects();
  return result;
}
```

**Step 2: Create ProjectList component**

Create `src/lib/components/ProjectList.svelte`:
```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { projects, loading, error, loadProjects, createProject } from '$lib/stores/projects';

  let showNewProject = false;
  let newProjectName = '';
  let newSourceLang = 'ko';
  let newTargetLang = 'en';

  onMount(() => {
    loadProjects();
  });

  async function handleCreate() {
    if (!newProjectName.trim()) return;

    try {
      await createProject(newProjectName, newSourceLang, newTargetLang);
      showNewProject = false;
      newProjectName = '';
    } catch (e) {
      console.error('Failed to create project:', e);
    }
  }
</script>

<div class="p-4">
  <div class="flex justify-between items-center mb-4">
    <h1 class="text-2xl font-bold">Projects</h1>
    <button
      class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      on:click={() => (showNewProject = !showNewProject)}
    >
      New Project
    </button>
  </div>

  {#if showNewProject}
    <div class="mb-4 p-4 border rounded bg-gray-50">
      <h2 class="text-lg font-semibold mb-2">Create New Project</h2>
      <div class="space-y-2">
        <input
          type="text"
          bind:value={newProjectName}
          placeholder="Project name"
          class="w-full px-3 py-2 border rounded"
        />
        <div class="flex gap-2">
          <select bind:value={newSourceLang} class="px-3 py-2 border rounded">
            <option value="ko">Korean</option>
            <option value="ja">Japanese</option>
            <option value="zh">Chinese</option>
          </select>
          <span class="py-2">→</span>
          <select bind:value={newTargetLang} class="px-3 py-2 border rounded">
            <option value="en">English</option>
          </select>
        </div>
        <button
          class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
          on:click={handleCreate}
        >
          Create
        </button>
      </div>
    </div>
  {/if}

  {#if $loading}
    <p class="text-gray-500">Loading projects...</p>
  {:else if $error}
    <p class="text-red-500">Error: {$error}</p>
  {:else if $projects.length === 0}
    <p class="text-gray-500">No projects yet. Create one to get started.</p>
  {:else}
    <div class="space-y-2">
      {#each $projects as project}
        <div class="p-4 border rounded hover:bg-gray-50 cursor-pointer">
          <h3 class="font-semibold">{project.name}</h3>
          <p class="text-sm text-gray-500">
            {project.source_lang.toUpperCase()} → {project.target_lang.toUpperCase()}
          </p>
        </div>
      {/each}
    </div>
  {/if}
</div>
```

**Step 3: Update main page**

Update `src/routes/+page.svelte`:
```svelte
<script>
  import ProjectList from '$lib/components/ProjectList.svelte';
</script>

<main class="min-h-screen bg-gray-100">
  <ProjectList />
</main>
```

**Step 4: Run dev to verify**

```bash
npm run tauri dev
```
Expected: App shows project list with "New Project" button

**Step 5: Commit**

```bash
git add src/
git commit -m "feat(ui): add project list and creation UI"
```

---

### Task 9: Create Segment Editor Component

**Files:**
- Create: `src/lib/stores/editor.ts`
- Create: `src/lib/components/SegmentEditor.svelte`
- Create: `src/lib/components/SegmentRow.svelte`

**Step 1: Create editor store**

Create `src/lib/stores/editor.ts`:
```typescript
import { writable, derived } from 'svelte/store';

export interface Segment {
  id: number;
  sequence_order: number;
  source_text: string;
  target_text: string | null;
  status: 'draft' | 'confirmed' | 'reviewed';
  tm_match_percent: number | null;
  locked: boolean;
}

export const segments = writable<Segment[]>([]);
export const activeSegmentId = writable<number | null>(null);
export const editingText = writable('');

export const activeSegment = derived(
  [segments, activeSegmentId],
  ([$segments, $activeId]) => $segments.find((s) => s.id === $activeId) || null
);

export function setActiveSegment(id: number) {
  activeSegmentId.set(id);
  const seg = segments.subscribe((segs) => {
    const found = segs.find((s) => s.id === id);
    if (found) {
      editingText.set(found.target_text || '');
    }
  });
  seg(); // unsubscribe immediately
}

export function updateSegmentText(id: number, text: string) {
  segments.update((segs) =>
    segs.map((s) =>
      s.id === id
        ? { ...s, target_text: text, status: s.status === 'draft' ? 'draft' : s.status }
        : s
    )
  );
}

export function confirmSegment(id: number) {
  segments.update((segs) =>
    segs.map((s) => (s.id === id ? { ...s, status: 'confirmed' as const } : s))
  );
}

export function moveToNextSegment() {
  let currentId: number | null = null;
  activeSegmentId.subscribe((id) => (currentId = id))();

  if (currentId === null) return;

  segments.subscribe((segs) => {
    const currentIndex = segs.findIndex((s) => s.id === currentId);
    if (currentIndex < segs.length - 1) {
      setActiveSegment(segs[currentIndex + 1].id);
    }
  })();
}

export function moveToPrevSegment() {
  let currentId: number | null = null;
  activeSegmentId.subscribe((id) => (currentId = id))();

  if (currentId === null) return;

  segments.subscribe((segs) => {
    const currentIndex = segs.findIndex((s) => s.id === currentId);
    if (currentIndex > 0) {
      setActiveSegment(segs[currentIndex - 1].id);
    }
  })();
}
```

**Step 2: Create SegmentRow component**

Create `src/lib/components/SegmentRow.svelte`:
```svelte
<script lang="ts">
  import type { Segment } from '$lib/stores/editor';
  import { activeSegmentId, setActiveSegment, updateSegmentText, confirmSegment, moveToNextSegment } from '$lib/stores/editor';

  export let segment: Segment;

  $: isActive = $activeSegmentId === segment.id;

  function getStatusIcon(status: string, matchPercent: number | null): string {
    if (matchPercent === 100) return '★';
    switch (status) {
      case 'confirmed': return '✓';
      case 'reviewed': return '✓✓';
      case 'draft': return segment.target_text ? '•' : '○';
      default: return '○';
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && e.ctrlKey) {
      confirmSegment(segment.id);
      moveToNextSegment();
      e.preventDefault();
    } else if (e.key === 'Enter' && !e.shiftKey) {
      moveToNextSegment();
      e.preventDefault();
    }
  }

  function handleInput(e: Event) {
    const target = e.target as HTMLTextAreaElement;
    updateSegmentText(segment.id, target.value);
  }
</script>

<div
  class="grid grid-cols-[40px_1fr_1fr_40px] border-b hover:bg-blue-50 transition-colors"
  class:bg-blue-100={isActive}
  on:click={() => setActiveSegment(segment.id)}
  role="row"
>
  <!-- Segment number -->
  <div class="p-2 text-center text-gray-500 text-sm border-r">
    {segment.sequence_order}
  </div>

  <!-- Source text -->
  <div class="p-2 border-r text-sm whitespace-pre-wrap">
    {segment.source_text}
  </div>

  <!-- Target text -->
  <div class="p-2 border-r">
    {#if isActive}
      <textarea
        class="w-full h-full min-h-[60px] p-1 border rounded resize-none focus:outline-none focus:ring-2 focus:ring-blue-400"
        value={segment.target_text || ''}
        on:input={handleInput}
        on:keydown={handleKeydown}
        autofocus
      />
    {:else}
      <div class="text-sm whitespace-pre-wrap text-gray-700">
        {segment.target_text || ''}
      </div>
    {/if}
  </div>

  <!-- Status -->
  <div class="p-2 text-center">
    <span class:text-green-600={segment.status === 'confirmed'}
          class:text-yellow-600={segment.tm_match_percent === 100}>
      {getStatusIcon(segment.status, segment.tm_match_percent)}
    </span>
  </div>
</div>
```

**Step 3: Create SegmentEditor component**

Create `src/lib/components/SegmentEditor.svelte`:
```svelte
<script lang="ts">
  import { segments, activeSegmentId, setActiveSegment, moveToPrevSegment, moveToNextSegment } from '$lib/stores/editor';
  import SegmentRow from './SegmentRow.svelte';

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'ArrowUp' && e.altKey) {
      moveToPrevSegment();
      e.preventDefault();
    } else if (e.key === 'ArrowDown' && e.altKey) {
      moveToNextSegment();
      e.preventDefault();
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

<div class="flex flex-col h-full">
  <!-- Header -->
  <div class="grid grid-cols-[40px_1fr_1fr_40px] bg-gray-200 border-b font-semibold text-sm">
    <div class="p-2 text-center border-r">#</div>
    <div class="p-2 border-r">Source (KO)</div>
    <div class="p-2 border-r">Target (EN)</div>
    <div class="p-2 text-center">St</div>
  </div>

  <!-- Segments -->
  <div class="flex-1 overflow-y-auto">
    {#each $segments as segment (segment.id)}
      <SegmentRow {segment} />
    {/each}
  </div>

  <!-- Status bar -->
  <div class="bg-gray-100 border-t p-2 text-sm text-gray-600 flex gap-4">
    <span>Segment {$activeSegmentId ?? '-'}/{$segments.length}</span>
    <span>|</span>
    <span>Enter: Next | Ctrl+Enter: Confirm & Next | Alt+↑/↓: Navigate</span>
  </div>
</div>
```

**Step 4: Commit**

```bash
git add src/lib/
git commit -m "feat(ui): add segment editor component with keyboard navigation"
```

---

### Task 10: Create Word Document Import (Rust Backend)

**Files:**
- Create: `src-tauri/src/import/mod.rs`
- Create: `src-tauri/src/import/docx.rs`
- Create: `src-tauri/src/import/segmenter.rs`
- Modify: `src-tauri/Cargo.toml`

**Step 1: Add docx dependency**

Update `src-tauri/Cargo.toml`:
```toml
[dependencies]
# ... existing deps ...
docx-rs = "0.4"
zip = "0.6"
quick-xml = "0.31"
```

**Step 2: Create Korean segmenter**

Create `src-tauri/src/import/segmenter.rs`:
```rust
/// Korean text segmentation rules
/// Segments on: 。 ? ! (Korean/Chinese punctuation) and . ? ! (English)
/// Preserves quotation marks within sentences

pub fn segment_korean_text(text: &str) -> Vec<String> {
    let mut segments = Vec::new();
    let mut current = String::new();
    let mut chars = text.chars().peekable();

    while let Some(c) = chars.next() {
        current.push(c);

        // Check for sentence-ending punctuation
        let is_sentence_end = matches!(c, '。' | '？' | '！' | '.' | '?' | '!');

        if is_sentence_end {
            // Don't break if next char is a closing quote
            let next = chars.peek();
            if !matches!(next, Some('」') | Some('』') | Some('"') | Some('\'')) {
                let trimmed = current.trim().to_string();
                if !trimmed.is_empty() {
                    segments.push(trimmed);
                }
                current.clear();
            }
        }
    }

    // Don't forget remaining text
    let trimmed = current.trim().to_string();
    if !trimmed.is_empty() {
        segments.push(trimmed);
    }

    segments
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_segment_korean_sentences() {
        let text = "안녕하세요. 반갑습니다. 오늘 날씨가 좋네요.";
        let segments = segment_korean_text(text);

        assert_eq!(segments.len(), 3);
        assert_eq!(segments[0], "안녕하세요.");
        assert_eq!(segments[1], "반갑습니다.");
        assert_eq!(segments[2], "오늘 날씨가 좋네요.");
    }

    #[test]
    fn test_preserve_quotes() {
        let text = "그는 \"안녕하세요.\"라고 말했습니다.";
        let segments = segment_korean_text(text);

        // Should be one segment because quote is mid-sentence
        assert_eq!(segments.len(), 1);
    }

    #[test]
    fn test_mixed_punctuation() {
        let text = "이것은 질문입니까? 네, 그렇습니다!";
        let segments = segment_korean_text(text);

        assert_eq!(segments.len(), 2);
    }
}
```

**Step 3: Create docx parser**

Create `src-tauri/src/import/docx.rs`:
```rust
use std::fs::File;
use std::io::Read;
use std::path::Path;
use thiserror::Error;
use zip::ZipArchive;
use quick_xml::Reader;
use quick_xml::events::Event;

use crate::import::segmenter::segment_korean_text;
use crate::project::Segment;
use crate::project::SegmentStatus;

#[derive(Error, Debug)]
pub enum DocxError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Zip error: {0}")]
    Zip(#[from] zip::result::ZipError),
    #[error("XML error: {0}")]
    Xml(#[from] quick_xml::Error),
    #[error("Invalid document structure")]
    InvalidStructure,
}

pub struct DocxImporter;

impl DocxImporter {
    pub fn import<P: AsRef<Path>>(path: P) -> Result<Vec<Segment>, DocxError> {
        let file = File::open(path)?;
        let mut archive = ZipArchive::new(file)?;

        // Read document.xml
        let mut doc_xml = String::new();
        {
            let mut doc_file = archive.by_name("word/document.xml")?;
            doc_file.read_to_string(&mut doc_xml)?;
        }

        // Extract text from XML
        let paragraphs = Self::extract_paragraphs(&doc_xml)?;

        // Segment and create Segment structs
        let mut segments = Vec::new();
        let mut sequence = 1;

        for para in paragraphs {
            let text_segments = segment_korean_text(&para);
            for text in text_segments {
                segments.push(Segment {
                    id: sequence as i64,
                    sequence_order: sequence,
                    source_text: text,
                    target_text: None,
                    status: SegmentStatus::Draft,
                    formatting: None,
                    comments: None,
                    tm_match_percent: None,
                    locked: false,
                });
                sequence += 1;
            }
        }

        Ok(segments)
    }

    fn extract_paragraphs(xml: &str) -> Result<Vec<String>, DocxError> {
        let mut reader = Reader::from_str(xml);
        reader.config_mut().trim_text(true);

        let mut paragraphs = Vec::new();
        let mut current_para = String::new();
        let mut in_text = false;

        loop {
            match reader.read_event() {
                Ok(Event::Start(e)) => {
                    if e.name().as_ref() == b"w:t" {
                        in_text = true;
                    }
                }
                Ok(Event::Text(e)) if in_text => {
                    current_para.push_str(&e.unescape().unwrap_or_default());
                }
                Ok(Event::End(e)) => {
                    if e.name().as_ref() == b"w:t" {
                        in_text = false;
                    } else if e.name().as_ref() == b"w:p" {
                        let trimmed = current_para.trim().to_string();
                        if !trimmed.is_empty() {
                            paragraphs.push(trimmed);
                        }
                        current_para.clear();
                    }
                }
                Ok(Event::Eof) => break,
                Err(e) => return Err(DocxError::Xml(e)),
                _ => {}
            }
        }

        Ok(paragraphs)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_paragraphs_from_xml() {
        let xml = r#"<?xml version="1.0"?>
        <w:document>
            <w:body>
                <w:p><w:r><w:t>첫 번째 문단입니다.</w:t></w:r></w:p>
                <w:p><w:r><w:t>두 번째 문단입니다.</w:t></w:r></w:p>
            </w:body>
        </w:document>"#;

        let paragraphs = DocxImporter::extract_paragraphs(xml).unwrap();
        assert_eq!(paragraphs.len(), 2);
        assert_eq!(paragraphs[0], "첫 번째 문단입니다.");
    }
}
```

**Step 4: Create mod.rs**

Create `src-tauri/src/import/mod.rs`:
```rust
pub mod docx;
pub mod segmenter;

pub use docx::{DocxImporter, DocxError};
```

**Step 5: Run tests**

```bash
cd src-tauri
cargo test import::
```
Expected: All import tests pass

**Step 6: Commit**

```bash
git add src-tauri/src/import/ src-tauri/Cargo.toml
git commit -m "feat(import): add Word document importer with Korean segmentation"
```

---

## Phase 2 Summary (Full TM/TB)

Tasks 11-20 would cover:
- **Task 11:** TM matching engine with Levenshtein distance
- **Task 12:** FTS5 fuzzy search integration
- **Task 13:** TM match display panel (SvelteKit)
- **Task 14:** Term Base lookup and highlighting
- **Task 15:** TB quick-add (Ctrl+T workflow)
- **Task 16:** Auto-complete from TB
- **Task 17:** Context matching (101% matches)
- **Task 18:** TM management view
- **Task 19:** TB management view
- **Task 20:** Auto-propagation of 100% matches

---

## Phase 3 Summary (QA & Workflows)

Tasks 21-30 would cover:
- **Task 21:** QA engine - extra spaces check
- **Task 22:** QA engine - number mismatch check
- **Task 23:** QA engine - quote matching (document-level)
- **Task 24:** QA panel UI with fix/ignore
- **Task 25:** Finalization rules engine
- **Task 26:** Client profile management
- **Task 27:** Find-replace execution
- **Task 28:** Bilingual export (TSV)
- **Task 29:** Bilingual re-import
- **Task 30:** Word export with formatting

---

## Phase 4 Summary (Migration & Polish)

Tasks 31-40 would cover:
- **Task 31:** Phrase mxliff parser
- **Task 32:** Trados sdlxliff parser
- **Task 33:** TMX import
- **Task 34:** TBX import
- **Task 35:** Backup system (auto + manual)
- **Task 36:** Statistics dashboard
- **Task 37:** Theme system (10 VS Code themes)
- **Task 38:** Keyboard shortcut customization
- **Task 39:** Cloud sync status display
- **Task 40:** Crash recovery

---

## Testing Strategy

**Unit Tests (Rust):**
- Database operations (migrations, CRUD)
- TM matching algorithm
- Korean segmentation
- Document parsing

**Component Tests (Svelte):**
- Segment editing behavior
- Keyboard navigation
- Store updates

**Integration Tests:**
- Full import → edit → export workflow
- TM matching performance (500K+ segments)

**E2E Tests (Tauri):**
- Project creation flow
- Document import flow
- Cloud sync simulation

---

## Performance Targets

| Operation | Target | Test Method |
|-----------|--------|-------------|
| App startup | < 2s | Timer from launch to ready |
| TM lookup (500K entries) | < 100ms | Benchmark test |
| Segment navigation | < 16ms | 60fps target |
| Auto-save | < 100ms | Should not block UI |
| Cloud sync check | < 500ms | Startup validation |

---

## Commit Strategy

- Commit after each task
- Use conventional commits: `feat:`, `fix:`, `test:`, `docs:`
- Tag releases: `v0.1.0` (Phase 1), `v0.2.0` (Phase 2), etc.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
