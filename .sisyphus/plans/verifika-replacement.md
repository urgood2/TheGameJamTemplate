# Verifika Replacement - Translation QA Desktop App

## Project Location

**This project will be created as a NEW STANDALONE REPOSITORY.**

- **Repository name**: `translation-qa`
- **Location**: Outside of TheGameJamTemplate (separate project)
- **Structure**: Fresh Tauri 2.x project initialized via `npm create tauri-app@latest`

**NOT** a subdirectory of TheGameJamTemplate. This plan is stored here for planning purposes only.

### Canonical Naming (LOCKED - used throughout plan)

| Property | Value | Notes |
|----------|-------|-------|
| Repository name | `translation-qa` | Git repo directory |
| Tauri productName | `TranslationQA` | User-visible app name |
| Tauri identifier | `com.translationqa.app` | Bundle ID |
| Binary name | `translation-qa` | Rust target name |
| macOS bundle | `TranslationQA.app` | Derived from productName |
| Windows installer | `TranslationQA_x.y.z_x64.msi` | Derived from productName |

**tauri.conf.json** (canonical):
```json
{
  "productName": "TranslationQA",
  "identifier": "com.translationqa.app",
  "build": {
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build",
    "devUrl": "http://localhost:1420",
    "frontendDist": "../dist"
  }
}
```

**Cargo.toml** (canonical):
```toml
[package]
name = "translation-qa"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "translation-qa"
path = "src/main.rs"
```

All bundling scripts (`scripts/bundle-hunspell-*.sh`) use these canonical names.

---

## Context

### Original Request
Build a Tauri-based desktop application to replace Verifika (commercial translation QA tool) to eliminate subscription costs while retaining critical functionality including custom QA scripting with regex, spell checking, and native support for SDLXLIFF and Phrase MXLIFF files.

### Interview Summary
**Key Discussions**:
- **QA Checks**: 8 categories confirmed - tags, numbers, punctuation, spelling, terminology, consistency, empty segments, forbidden words
- **Custom Scripting**: Essential daily use - full CTWRP system plus cross-segment back-reference (B flag)
- **File Formats**: SDLXLIFF, Phrase MXLIFF, standard XLIFF (all with read + write back)
- **Glossaries**: Excel (XLSX), TBX, CSV/TSV
- **Spell Check**: English + Korean (offline Hunspell only)
- **Multi-file**: Tab-based UI for multiple files
- **Editing**: In-app with undo/redo, save back to source
- **Profiles**: Save/load rule sets for different clients
- **Platforms**: macOS + Windows

**Research Findings**:
- SDLXLIFF = XLIFF 1.2 + SDL proprietary extensions (`sdl:` namespace for segment status, locked, match%)
- MXLIFF = XLIFF 1.2 + Phrase extensions (`{j}` join markers, `mda:` namespace)
- `xliff` npm package handles XLIFF 1.2/2.0 with inline elements
- Hunspell 1.7.0+ required (1.6.0 has critical Korean bugs)
- `hunspell-dict-ko` is the only viable open-source Korean dictionary (53K words)
- Tauri 2.x uses Channels for streaming, `quick-xml` for Rust XML parsing

### UTF-16 Encoding Strategy (CRITICAL)

**Problem**: `quick-xml` does NOT support UTF-16 natively.

**Solution**: Pre-process files before parsing:
1. On file open, detect encoding via BOM or XML declaration
2. If UTF-16 detected, use `encoding_rs` crate to transcode to UTF-8 in memory
3. Parse UTF-8 with `quick-xml`
4. On write-back, transcode back to original encoding if it was UTF-16

**Note**: Most XLIFF files are UTF-8. UTF-16 is rare but must be handled correctly.

**Implementation in Task 4**:
```rust
use encoding_rs::{UTF_16LE, UTF_16BE, UTF_8};

fn detect_and_normalize(bytes: &[u8]) -> (String, OriginalEncoding) {
    // Check BOM or XML declaration
    // Transcode to UTF-8 if needed
    // Return (utf8_content, original_encoding)
}
```

### Metis Review
**Identified Gaps** (addressed):
- Korean spell check quality: User accepted offline Hunspell limitations
- Multi-file vs single-file: Confirmed tab-based multi-file
- Undo/redo: Confirmed essential
- Performance: No specific target (reasonable is acceptable)
- XML round-trip: Added explicit guardrails for namespace/whitespace preservation

---

## Test Fixtures Strategy

### Canonical Fixture Sets

**There are TWO fixture sets with different purposes:**

#### 1. In-Repo Minimal Fixtures (For CI/Unit Tests)

These ship with the repository and are the **default verification targets** for all task acceptance criteria.

```
fixtures/
├── sdlxliff/
│   ├── minimal_basic.sdlxliff         # 3 segments, basic SDL structure
│   ├── minimal_locked.sdlxliff        # 2 segments, one locked
│   └── minimal_namespaces.sdlxliff    # 2 segments, extra SDL namespaces
├── mxliff/
│   ├── minimal_basic.mxliff           # 3 segments, basic Phrase structure
│   └── minimal_joined.mxliff          # 2 segments with {j} join markers
├── xliff/
│   ├── minimal_12.xliff               # XLIFF 1.2, 3 segments
│   ├── minimal_20.xliff               # XLIFF 2.0, 3 segments
│   └── minimal_utf16.xliff            # UTF-16LE encoded, 2 segments
└── glossary/
    ├── minimal.xlsx                   # 5 terms
    ├── minimal.tbx                    # 5 terms
    └── minimal.csv                    # 5 terms
```

**Properties of minimal fixtures**:
- Anonymized (placeholder text like "Source text one", "Target text one")
- Cover structural edge cases (locked segments, namespaces, join markers, UTF-16)
- Small enough to commit to repo (<10KB each)
- Sufficient for CI tests

#### 2. User-Provided Fixtures (For Manual/E2E Validation - OPTIONAL)

Users can add real-world files for comprehensive testing. These are NOT required for CI.

```
fixtures/
├── user/                              # .gitignored directory
│   ├── sdlxliff/
│   │   ├── trados2019_real.sdlxliff  # Real file from Trados 2019
│   │   └── trados2024_real.sdlxliff  # Real file from Trados 2024
│   ├── mxliff/
│   │   └── phrase_real.mxliff        # Real Phrase export
│   └── README.md                      # Instructions for anonymization
```

**The `fixtures/user/` directory is .gitignored** - users add their own files for local testing.

### Acceptance Criteria Reference Rule

**All task acceptance criteria reference in-repo minimal fixtures by default:**
- Task 4: `fixtures/xliff/minimal_12.xliff`, `fixtures/xliff/minimal_20.xliff`
- Task 5: `fixtures/sdlxliff/minimal_basic.sdlxliff`, `fixtures/sdlxliff/minimal_locked.sdlxliff`
- Task 6: `fixtures/mxliff/minimal_basic.mxliff`, `fixtures/mxliff/minimal_joined.mxliff`
- Task 7: `fixtures/xliff/minimal_utf16.xliff`

**Manual CAT tool verification** (documented in `docs/TESTING_CHECKLIST.md`) can use user-provided fixtures.

### Minimal Fixture Content (Created in Task 1)

**fixtures/xliff/minimal_12.xliff**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <file original="test.txt" source-language="en" target-language="ko" datatype="plaintext">
    <body>
      <trans-unit id="1">
        <source>Hello world</source>
        <target>안녕하세요</target>
      </trans-unit>
      <trans-unit id="2">
        <source>Click <g id="1">here</g> to continue</source>
        <target>계속하려면 <g id="1">여기</g>를 클릭하세요</target>
      </trans-unit>
      <trans-unit id="3">
        <source>Item 123 costs $45.67</source>
        <target>항목 123의 가격은 $45.67입니다</target>
      </trans-unit>
    </body>
  </file>
</xliff>
```

**fixtures/xliff/minimal_20.xliff**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="2.0" xmlns="urn:oasis:names:tc:xliff:document:2.0" srcLang="en" trgLang="ko">
  <file id="f1">
    <unit id="1">
      <segment>
        <source>Hello world</source>
        <target>안녕하세요</target>
      </segment>
    </unit>
    <unit id="2">
      <segment>
        <source>Click <pc id="1">here</pc> to continue</source>
        <target>계속하려면 <pc id="1">여기</pc>를 클릭하세요</target>
      </segment>
    </unit>
  </file>
</xliff>
```

**fixtures/xliff/minimal_utf16.xliff** (UTF-16LE with BOM):
```xml
<?xml version="1.0" encoding="UTF-16"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <file original="utf16test.txt" source-language="en" target-language="ko" datatype="plaintext">
    <body>
      <trans-unit id="1">
        <source>UTF-16 test</source>
        <target>UTF-16 테스트</target>
      </trans-unit>
    </body>
  </file>
</xliff>
```
(Note: This must be saved as UTF-16LE with BOM bytes `FF FE` at start)

**fixtures/sdlxliff/minimal_basic.sdlxliff**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2"
       xmlns:sdl="http://sdl.com/FileTypes/SdlXliff/1.0">
  <file original="test.docx" source-language="en-US" target-language="ko-KR" datatype="x-sdlfilterframework2">
    <header>
      <sdl:ref-files/>
    </header>
    <body>
      <trans-unit id="1">
        <source>Source text one</source>
        <target>대상 텍스트 1</target>
        <sdl:seg-defs>
          <sdl:seg id="1" conf="Translated" percent="0"/>
        </sdl:seg-defs>
      </trans-unit>
    </body>
  </file>
</xliff>
```

**fixtures/sdlxliff/minimal_locked.sdlxliff**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2"
       xmlns:sdl="http://sdl.com/FileTypes/SdlXliff/1.0">
  <file original="test.docx" source-language="en-US" target-language="ko-KR" datatype="x-sdlfilterframework2">
    <body>
      <trans-unit id="1">
        <source>Unlocked segment</source>
        <target>잠기지 않은 세그먼트</target>
        <sdl:seg-defs>
          <sdl:seg id="1" conf="Translated" locked="false"/>
        </sdl:seg-defs>
      </trans-unit>
      <trans-unit id="2">
        <source>Locked segment</source>
        <target>잠긴 세그먼트</target>
        <sdl:seg-defs>
          <sdl:seg id="2" conf="ApprovedTranslation" locked="true" percent="100"/>
        </sdl:seg-defs>
      </trans-unit>
    </body>
  </file>
</xliff>
```

**fixtures/mxliff/minimal_basic.mxliff**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <file original="test.html" source-language="en" target-language="ko" datatype="html">
    <body>
      <trans-unit id="1">
        <source>First sentence.</source>
        <target>첫 번째 문장.</target>
      </trans-unit>
      <trans-unit id="2">
        <source>Second sentence.</source>
        <target>두 번째 문장.</target>
      </trans-unit>
    </body>
  </file>
</xliff>
```

**fixtures/mxliff/minimal_joined.mxliff**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <file original="test.html" source-language="en" target-language="ko" datatype="html">
    <body>
      <trans-unit id="1-2">
        <source>First sentence.{j}Second sentence.</source>
        <target>첫 번째 문장.{j}두 번째 문장.</target>
      </trans-unit>
    </body>
  </file>
</xliff>
```

**fixtures/sdlxliff/minimal_namespaces.sdlxliff** (with multiple namespaces):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2"
       xmlns:sdl="http://sdl.com/FileTypes/SdlXliff/1.0"
       xmlns:sdl-doc="http://schemas.sdl.com/xliff/documentation"
       xmlns:custom="http://example.com/custom">
  <file original="test.docx" source-language="en-US" target-language="ko-KR" datatype="x-sdlfilterframework2">
    <header>
      <sdl:ref-files/>
      <sdl-doc:comments/>
    </header>
    <body>
      <trans-unit id="1">
        <source>Text with custom namespace</source>
        <target>사용자 정의 네임스페이스가 있는 텍스트</target>
        <sdl:seg-defs>
          <sdl:seg id="1" conf="Translated"/>
        </sdl:seg-defs>
        <custom:metadata>preserve this</custom:metadata>
      </trans-unit>
    </body>
  </file>
</xliff>
```

### Glossary Fixture Schema

**fixtures/glossary/minimal.xlsx** (Excel file structure):

| Column | Header | Required | Description |
|--------|--------|----------|-------------|
| A | en | Yes | English source term |
| B | ko | Yes | Korean target term |
| C | forbidden | No | Forbidden translations (comma-separated) |
| D | notes | No | Usage notes |

**Row contents**:
```
en          | ko          | forbidden      | notes
computer    | 컴퓨터      | 콤퓨터,컴퓨타  | Standard translation
save        | 저장        |                | Verb form
file        | 파일        | 화일           | Use 파일 not 화일
click       | 클릭        |                | 
button      | 버튼        | 단추           | Use 버튼 not 단추
```

**fixtures/glossary/minimal.tbx**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<martif type="TBX-Basic" xml:lang="en">
  <martifHeader>
    <fileDesc>
      <sourceDesc><p>Minimal test glossary</p></sourceDesc>
    </fileDesc>
  </martifHeader>
  <text>
    <body>
      <termEntry id="1">
        <langSet xml:lang="en">
          <tig><term>computer</term></tig>
        </langSet>
        <langSet xml:lang="ko">
          <tig><term>컴퓨터</term></tig>
        </langSet>
      </termEntry>
      <termEntry id="2">
        <langSet xml:lang="en">
          <tig><term>save</term></tig>
        </langSet>
        <langSet xml:lang="ko">
          <tig><term>저장</term></tig>
        </langSet>
      </termEntry>
    </body>
  </text>
</martif>
```

**fixtures/glossary/minimal.csv**:
```csv
en,ko,forbidden,notes
computer,컴퓨터,"콤퓨터,컴퓨타",Standard translation
save,저장,,Verb form
file,파일,화일,Use 파일 not 화일
click,클릭,,
button,버튼,단추,Use 버튼 not 단추
```

### Glossary Column Detection Algorithm

```rust
fn detect_glossary_columns(headers: &[String]) -> GlossaryColumnMapping {
    let mut mapping = GlossaryColumnMapping::default();
    
    for (idx, header) in headers.iter().enumerate() {
        let lower = header.to_lowercase();
        
        // Source language detection
        if matches!(lower.as_str(), "en" | "eng" | "english" | "source" | "en-us" | "en_us") {
            mapping.source_col = Some(idx);
        }
        // Target language detection  
        else if matches!(lower.as_str(), "ko" | "kor" | "korean" | "target" | "ko-kr" | "ko_kr") {
            mapping.target_col = Some(idx);
        }
        // Forbidden column
        else if lower.contains("forbidden") || lower.contains("prohibited") {
            mapping.forbidden_col = Some(idx);
        }
        // Notes column
        else if lower.contains("note") || lower.contains("comment") {
            mapping.notes_col = Some(idx);
        }
    }
    
    mapping
}
```

### Verification Without CAT Tools

Since CI won't have Trados/Phrase installed, verification uses:

1. **Diff-based verification**: Compare original vs round-tripped file
   - `git diff --no-index original.sdlxliff modified.sdlxliff`
   - Expected: Only `<target>` content differs, all namespaces/attributes preserved

2. **Schema validation**: Validate against XLIFF 1.2 XSD
   - Use `xmllint --schema xliff-core-1.2-strict.xsd file.xliff`

3. **Structural assertions**: Unit tests verify:
   - Namespace count unchanged
   - Attribute order preserved (where tracked)
   - SDL/Phrase extension elements present

4. **Manual CAT tool verification**: Document in `docs/TESTING_CHECKLIST.md`:
   - [ ] Open modified SDLXLIFF in Trados 2024 - no warnings
   - [ ] Open modified MXLIFF in Phrase - imports successfully
   - (Manual step during E2E testing, not CI)

---

## Behavioral Reference Documentation

### CTWRP + B-Flag Behavior Specification

Since Verifika documentation is proprietary, behavior is specified here:

#### CTWRP Flags

| Flag | Name | Behavior |
|------|------|----------|
| **C** | Case-sensitive | `"Hello"` matches "Hello" but not "hello" |
| **T** | Tags | Search includes inline tag content (e.g., finds "bold" inside `<g id="1">bold</g>`) |
| **W** | Whole words | Pattern bounded by word boundaries. `"test"` matches "test" but not "testing" |
| **R** | Regex | Interpret pattern as regular expression |
| **P** | Power search | Enable boolean operators: `word1 AND word2`, `word1 OR word2`, `word1 AND NOT word2` |

#### B-Flag (Cross-Segment Back-Reference)

**Purpose**: Capture a pattern in source, require it to appear in target.

**Example**:
- Source pattern: `(\d{3}-\d{4})` (captures phone number like "123-4567")
- Target pattern: `\1` (must find "123-4567" in target)
- If source has "Call 123-4567" and target has "전화 123-4567", PASS
- If source has "Call 123-4567" and target has "전화 999-9999", FAIL (back-reference mismatch)

**Behavior details**:
- `\1` refers to first capture group, `\2` to second, etc.
- If source pattern doesn't match, skip segment (no error)
- If source matches but target doesn't contain back-reference value, report error
- Works with other flags (e.g., CR = case-sensitive regex)

---

## B-Flag Execution Model (CRITICAL)

### Problem: Rust `regex` Crate Doesn't Support Backreferences

The Rust `regex` crate explicitly does NOT support backreferences in patterns. A pattern like `\1` will not compile or behave as expected.

### Solution: Placeholder Substitution (NOT Regex Backreference)

**The `\1`, `\2`, etc. in target patterns are NOT regex backreferences.** They are placeholders that get substituted with captured values BEFORE the target pattern is compiled/searched.

**Execution Flow**:

```rust
fn execute_b_flag_script(
    source_pattern: &str,
    target_pattern: &str, 
    segment: &Segment,
    flags: &Flags,
) -> Result<Option<QAError>, ScriptError> {
    // 1. Compile and execute source pattern (with captures)
    let source_regex = Regex::new(source_pattern)?;
    let source_text = segment.source.text_only();
    
    let captures = match source_regex.captures(&source_text) {
        Some(c) => c,
        None => return Ok(None), // Source doesn't match, skip segment
    };
    
    // 2. Substitute placeholders in target pattern with captured values
    let mut resolved_target_pattern = target_pattern.to_string();
    for i in 1..=9 {
        let placeholder = format!("\\{}", i);
        if let Some(captured) = captures.get(i) {
            // ESCAPE the captured value for literal matching
            let escaped = regex::escape(captured.as_str());
            resolved_target_pattern = resolved_target_pattern.replace(&placeholder, &escaped);
        }
    }
    
    // 3. Compile resolved target pattern and search
    let target_regex = Regex::new(&resolved_target_pattern)?;
    let target_text = segment.target.as_ref().map(|t| t.text_only()).unwrap_or_default();
    
    if target_regex.is_match(&target_text) {
        Ok(None) // PASS
    } else {
        Ok(Some(QAError {
            segment_id: segment.id.clone(),
            error_type: QAErrorType::CustomScript,
            message: format!(
                "B-flag mismatch: captured '{}' in source but not found in target",
                captures.get(1).map(|m| m.as_str()).unwrap_or("")
            ),
            ..Default::default()
        }))
    }
}
```

**Key Points**:
1. Source pattern runs with captures: `(\d{3}-\d{4})`
2. Extract captured text: `"123-4567"`
3. Substitute `\1` in target pattern with **escaped literal**: `"123-4567"` → `"123\\-4567"`
4. Target pattern becomes a literal search (or regex if other patterns present)
5. Search target text for the resolved pattern

**Escaping Rule**: Captured values are `regex::escape()`-ed before substitution to ensure literal matching.

**Example Walkthrough**:
```
Source pattern: "Order #(\d+)"
Target pattern: "#\1"
Source text: "Order #12345 confirmed"
Target text: "주문 #12345 확인됨"

Step 1: Match source → captures["1"] = "12345"
Step 2: Substitute → target pattern becomes "#12345" (escaped: "#12345")
Step 3: Search target for "#12345" → FOUND → PASS
```

---

#### Search Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| 1 | Source AND target match | Find where both have pattern X |
| 2 | Source matches, target DOESN'T | Find untranslated patterns |
| 3 | Target matches, source DOESN'T | Find incorrectly added content |
| 4 | Count mismatch | Source has pattern 3 times, target has 2 times |

---

## Power Search (P-Flag) Grammar Specification

### Syntax

**Operators** (case-insensitive):
- `AND` or `&` - both operands must match
- `OR` or `|` - either operand must match  
- `AND NOT` or `& ~` - left operand matches AND right operand does NOT match

**Precedence** (highest to lowest):
1. Quoted literals (`"..."`)
2. `AND NOT` / `& ~`
3. `AND` / `&`
4. `OR` / `|`

**Parentheses**: NOT supported (keep implementation simple). Expressions evaluate left-to-right within same precedence level.

**Quoting**:
- Double quotes `"..."` for literal phrases containing spaces or operators
- Single quotes `'...'` also accepted
- To match literal quote, escape with backslash: `\"` or `\'`

### Grammar (Pseudo-BNF)

```
expression := or_expr

or_expr := and_expr (('OR' | '|') and_expr)*

and_expr := not_expr (('AND' | '&') not_expr)*

not_expr := term (('AND NOT' | '& ~') term)?
          | term

term := quoted_string
      | word

quoted_string := '"' [^"]* '"'
               | "'" [^']* "'"

word := [^\s"'&|]+    # Any non-whitespace, non-operator sequence
```

### Examples

| Input | Interpretation |
|-------|----------------|
| `hello world` | `hello AND world` (implicit AND when no operator) |
| `hello OR world` | Match if contains "hello" OR "world" |
| `"hello world"` | Match literal phrase "hello world" |
| `TBD AND NOT approved` | Contains "TBD" but does NOT contain "approved" |
| `cat & dog | bird` | `(cat AND dog) OR bird` |
| `error & ~warning` | Contains "error" but NOT "warning" |

### Interaction with R (Regex) Flag

When both `P` and `R` flags are set:
- Each term in the boolean expression is treated as a regex pattern
- Operators still work as boolean combinators
- Example: `\d+ AND NOT \d{5}` → matches if any number exists but NOT a 5-digit number

### Implementation

```rust
fn evaluate_power_search(expr: &str, text: &str, is_regex: bool) -> bool {
    let ast = parse_power_expr(expr);
    evaluate_ast(&ast, text, is_regex)
}

enum PowerExpr {
    Term(String),
    And(Box<PowerExpr>, Box<PowerExpr>),
    Or(Box<PowerExpr>, Box<PowerExpr>),
    AndNot(Box<PowerExpr>, Box<PowerExpr>),
}

fn evaluate_ast(expr: &PowerExpr, text: &str, is_regex: bool) -> bool {
    match expr {
        PowerExpr::Term(pattern) => match_term(pattern, text, is_regex),
        PowerExpr::And(left, right) => 
            evaluate_ast(left, text, is_regex) && evaluate_ast(right, text, is_regex),
        PowerExpr::Or(left, right) => 
            evaluate_ast(left, text, is_regex) || evaluate_ast(right, text, is_regex),
        PowerExpr::AndNot(left, right) => 
            evaluate_ast(left, text, is_regex) && !evaluate_ast(right, text, is_regex),
    }
}
```

---

### QA Checker Behavioral Examples

#### Tags Checker
```
Source: "Click <g id="1">here</g> to continue"
Target: "Cliquez pour continuer"
Error: Missing tag id="1" in target

Source: "Press <x id="1"/> button"
Target: "Appuyez sur le bouton <x id="1"/> <x id="2"/>"
Error: Extra tag id="2" in target
```

#### Numbers Checker
```
Source: "Total: $1,234.56"
Target: "Total: 1234,56 $"
OK (if locale allows comma decimal separator)

Source: "Page 5 of 10"
Target: "Page 5 sur"
Error: Missing number "10" in target
```

#### Punctuation Checker
```
Source: "Hello world."
Target: "Bonjour monde"
Error: End punctuation mismatch (source has ".", target has none)

Source: "Open (file) now"
Target: "Ouvrir (fichier maintenant"
Error: Unmatched bracket "(" in target
```

---

## Implementation Decisions (Locked)

### Hunspell Integration: `hunspell-rs` crate (CHOSEN)

**Decision**: Use `hunspell-rs` crate (Rust bindings to libhunspell).

**Rationale**: 
- Native Rust bindings via hunspell-sys (links to libhunspell)
- Supports loading .dic/.aff files at runtime
- Hunspell 1.7.0+ required (1.6.0 has Korean bugs)

**Implementation**:
```rust
// Cargo.toml
hunspell-rs = "0.4"

// Usage
use hunspell_rs::Hunspell;
let hs = Hunspell::new("en_US.aff", "en_US.dic")?;
let is_correct = hs.check("hello");
let suggestions = hs.suggest("helo");
```

**Dictionary Distribution**:
- Bundle dictionaries in `src-tauri/dictionaries/`:
  - `en_US.dic`, `en_US.aff` (from LibreOffice dictionaries, MPL/LGPL)
  - `en_GB.dic`, `en_GB.aff`
  - `ko_KR.dic`, `ko_KR.aff` (from hunspell-dict-ko 0.7.94+, GPL-3.0)
- Include in Tauri bundle via `resources` config

**License Compliance Strategy**:

| Dictionary | License | Compliance Approach |
|------------|---------|---------------------|
| en_US/en_GB | MPL 2.0 / LGPL | Compatible with proprietary distribution. Include license file. |
| ko_KR (hunspell-dict-ko) | GPL-3.0 | **Requires one of**: (a) Release app as GPL-compatible, or (b) Don't bundle; let user provide their own .dic/.aff, or (c) Use different Korean dictionary with permissive license |

**CHOSEN APPROACH: Option B (User-Provided Korean Dictionary)**

The app will NOT bundle the GPL-licensed Korean dictionary. Instead:
- **English dictionaries**: Bundled (MPL/LGPL compatible with any license)
- **Korean dictionary**: User downloads and provides their own

**Implementation in Task 17**:
1. On first Korean spell check attempt, check if `ko_KR.dic` and `ko_KR.aff` exist in `<app_data>/dictionaries/`
2. If not found, show dialog:
   ```
   Korean spell check requires a dictionary file.
   
   1. Download hunspell-dict-ko from: https://github.com/spellcheck-ko/hunspell-dict-ko/releases
   2. Extract ko_KR.dic and ko_KR.aff
   3. Click "Select Dictionary Folder" to locate the files
   
   [Select Dictionary Folder] [Cancel]
   ```
3. Copy selected files to `<app_data>/dictionaries/`
4. Persist the path; subsequent runs auto-load

**Why Option B**:
- Avoids GPL license propagation to the entire app
- User downloads from official source (not redistributed)
- Clear license boundary
- Same quality dictionary, just user-sourced

**Acceptance Criteria Update for Task 17**:
- [ ] English spell check works out of box (dictionaries bundled)
- [ ] Korean spell check shows "dictionary needed" dialog if ko_KR.dic missing
- [ ] After user provides dictionary, Korean spell check works
- [ ] Dictionary path persists across app restarts

**Acceptance Criteria Update for Task 29 (Build)**:
- [ ] `en_US.dic`, `en_US.aff`, `en_GB.dic`, `en_GB.aff` bundled in app resources
- [ ] `ko_KR.dic` NOT bundled (user-provided)
- [ ] `LICENSE-THIRD-PARTY.txt` includes LibreOffice dictionary licenses
- [ ] README documents Korean dictionary setup

---

## Hunspell Cross-Platform Packaging (CRITICAL)

### Problem
`hunspell-rs` depends on `hunspell-sys` which requires libhunspell to be available at compile time and runtime.

### Solution Per Platform

**macOS**:
- **Build time**: `brew install hunspell` (provides libhunspell.dylib)
- **Runtime**: Bundle libhunspell.1.7.dylib with the app
- **Tauri config**:
  ```json
  // tauri.conf.json
  "bundle": {
    "macOS": {
      "frameworks": ["libhunspell.1.7.dylib"]
    },
    "resources": ["dictionaries/*"]
  }
  ```
- **Version verification**: At app startup, call `hunspell_version()` or check dylib filename

**Windows**:
- **Build time**: Use vcpkg or pre-built Hunspell binaries
  ```bash
  vcpkg install hunspell:x64-windows
  ```
- **Runtime**: Bundle hunspell.dll (1.7+) with the app
- **Tauri config**:
  ```json
  "bundle": {
    "windows": {
      "resources": ["hunspell.dll", "dictionaries/*"]
    }
  }
  ```
- **Version verification**: Check DLL version info or Hunspell_create() return

**Alternative: Static Linking**:
If dynamic linking proves problematic, consider:
- Building hunspell-sys with static linking feature
- Pros: No runtime DLL dependency
- Cons: Larger binary, potential license implications

### Known-Good Packaging Recipe

#### macOS

**Build Environment Setup**:
```bash
# Install Hunspell 1.7+
brew install hunspell

# Verify version
hunspell --version  # Should show 1.7.x or higher

# Library location after brew install
ls /opt/homebrew/lib/libhunspell*.dylib  # ARM Mac
ls /usr/local/lib/libhunspell*.dylib     # Intel Mac
```

**Tauri Bundle Config** (tauri.conf.json):
```json
{
  "bundle": {
    "macOS": {
      "frameworks": [],
      "externalBin": [],
      "minimumSystemVersion": "10.15"
    },
    "resources": ["dictionaries/*"]
  }
}
```

**Library Bundling Script** (scripts/bundle-hunspell-macos.sh):
```bash
#!/bin/bash
# Run after `npm run tauri build` to bundle Hunspell dylib
set -e

APP_BUNDLE="src-tauri/target/release/bundle/macos/TranslationQA.app"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

# CANONICAL: Hunspell dylib discovery
# 1. Use brew --prefix to find Homebrew installation
# 2. Find the actual dylib (handling version variations like 1.7.0, 1.7.2, etc.)
# 3. Resolve symlinks to get canonical name
BREW_PREFIX=$(brew --prefix)
HUNSPELL_LIB=$(find "$BREW_PREFIX/lib" -name "libhunspell-1.7*.dylib" -type f | head -1)

if [ -z "$HUNSPELL_LIB" ]; then
  echo "ERROR: libhunspell-1.7.x.dylib not found in $BREW_PREFIX/lib"
  echo "Install with: brew install hunspell"
  exit 1
fi

# Get the actual filename (e.g., libhunspell-1.7.2.dylib)
DYLIB_NAME=$(basename "$HUNSPELL_LIB")
echo "Found Hunspell: $HUNSPELL_LIB"

# Verify version >= 1.7.0 (required for Korean support)
if ! hunspell --version 2>/dev/null | grep -q "1\.[7-9]"; then
  echo "WARNING: Hunspell version may be < 1.7.0. Korean spell check may not work."
fi

mkdir -p "$FRAMEWORKS_DIR"
cp "$HUNSPELL_LIB" "$FRAMEWORKS_DIR/$DYLIB_NAME"

# Also create a versioned symlink for consistency
ln -sf "$DYLIB_NAME" "$FRAMEWORKS_DIR/libhunspell-1.7.dylib"

# Fix library paths in the main executable
install_name_tool -change "$HUNSPELL_LIB" \
  "@executable_path/../Frameworks/$DYLIB_NAME" \
  "$APP_BUNDLE/Contents/MacOS/translation-qa"

echo "Successfully bundled $DYLIB_NAME"
```

**Expected Bundle Structure** (macOS):
```
TranslationQA.app/
├── Contents/
│   ├── MacOS/
│   │   └── translation-qa          # Main executable
│   ├── Frameworks/
│   │   └── libhunspell-1.7.dylib   # Bundled Hunspell
│   └── Resources/
│       └── dictionaries/
│           ├── en_US.dic           # Bundled (English)
│           ├── en_US.aff
│           ├── en_GB.dic           # Bundled (English UK)
│           ├── en_GB.aff
│           └── README.md           # "Korean: see docs for user-provided setup"
                                    # NOTE: ko_KR.dic NOT bundled (user-provided)
```

#### Windows

**Build Environment Setup**:
```powershell
# Option 1: vcpkg (recommended)
git clone https://github.com/microsoft/vcpkg
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg install hunspell:x64-windows

# Set environment for hunspell-sys
$env:HUNSPELL_INCLUDE_DIR = "C:\vcpkg\installed\x64-windows\include"
$env:HUNSPELL_LIB_DIR = "C:\vcpkg\installed\x64-windows\lib"

# Option 2: Pre-built binaries
# Download from https://github.com/nickvergessen/hunspell-binaries
```

**Tauri Bundle Config** (tauri.conf.json):
```json
{
  "bundle": {
    "windows": {
      "wix": {},
      "webviewInstallMode": { "type": "downloadBootstrapper" }
    },
    "resources": ["hunspell.dll", "dictionaries/*"]
  }
}
```

**DLL Copy Script** (scripts/bundle-hunspell-windows.ps1):
```powershell
# Copy Hunspell DLL to target directory before bundling
$vcpkgRoot = "C:\vcpkg\installed\x64-windows"
$targetDir = "src-tauri\target\release"

Copy-Item "$vcpkgRoot\bin\hunspell.dll" "$targetDir\"
```

**Expected Install Structure** (Windows):
```
C:\Program Files\TranslationQA\
├── translation-qa.exe
├── hunspell.dll                    # Bundled Hunspell
└── dictionaries\
    ├── en_US.dic                   # Bundled (English)
    ├── en_US.aff
    ├── en_GB.dic                   # Bundled (English UK)
    ├── en_GB.aff
    └── README.txt                  # "Korean: see docs for user-provided setup"
                                    # NOTE: ko_KR.dic NOT bundled (user-provided)
```

### CI Setup

**GitHub Actions** (.github/workflows/build.yml):
```yaml
name: Build

on: [push, pull_request]

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Hunspell
        run: brew install hunspell
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install Rust
        uses: dtolnay/rust-action@stable
      - name: Install deps
        run: npm ci
      - name: Build
        run: npm run tauri build
      - name: Bundle Hunspell
        run: ./scripts/bundle-hunspell-macos.sh
      - name: Verify bundle
        run: |
          ls -la "src-tauri/target/release/bundle/macos/TranslationQA.app/Contents/Frameworks/"
          otool -L "src-tauri/target/release/bundle/macos/TranslationQA.app/Contents/MacOS/translation-qa"

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install vcpkg
        run: |
          git clone https://github.com/microsoft/vcpkg C:\vcpkg
          C:\vcpkg\bootstrap-vcpkg.bat
          C:\vcpkg\vcpkg install hunspell:x64-windows
        shell: cmd
      - name: Set Hunspell env
        run: |
          echo "HUNSPELL_INCLUDE_DIR=C:\vcpkg\installed\x64-windows\include" >> $env:GITHUB_ENV
          echo "HUNSPELL_LIB_DIR=C:\vcpkg\installed\x64-windows\lib" >> $env:GITHUB_ENV
      - name: Install deps
        run: npm ci
      - name: Build
        run: npm run tauri build
      - name: Bundle Hunspell DLL
        run: ./scripts/bundle-hunspell-windows.ps1
```

### Runtime Validation

**NOTE**: Korean dictionary is USER-PROVIDED (Option B), so startup validation MUST NOT hard-fail if Korean dictionary is missing.

```rust
/// Called at app startup to verify Hunspell is correctly loaded
fn validate_hunspell_setup() -> Result<HunspellStatus, StartupError> {
    let bundled_dict_path = get_bundled_dictionary_path()?;  // src-tauri/dictionaries/ in bundle
    let user_dict_path = get_user_dictionary_path()?;        // <app_data>/dictionaries/
    
    // 1. Verify BUNDLED English dictionary exists (required, bundled with app)
    let en_aff = bundled_dict_path.join("en_US.aff");
    let en_dic = bundled_dict_path.join("en_US.dic");
    if !en_dic.exists() {
        return Err(StartupError::MissingBundledDictionary("en_US".into()));
    }
    
    // 2. Verify Hunspell loads (this tests the dylib/dll is found)
    let hs_en = Hunspell::new(
        en_aff.to_str().unwrap(),
        en_dic.to_str().unwrap()
    ).map_err(|e| StartupError::HunspellLoadFailed(e.to_string()))?;
    
    // 3. Verify basic English functionality
    if !hs_en.check("hello") {
        return Err(StartupError::HunspellBroken("English check failed".into()));
    }
    
    // 4. Check for USER-PROVIDED Korean dictionary (optional, NOT bundled)
    let ko_aff = user_dict_path.join("ko_KR.aff");
    let ko_dic = user_dict_path.join("ko_KR.dic");
    let korean_available = if ko_dic.exists() && ko_aff.exists() {
        // Try to load and verify
        match Hunspell::new(ko_aff.to_str().unwrap(), ko_dic.to_str().unwrap()) {
            Ok(hs_ko) if hs_ko.check("안녕하세요") => true,
            Ok(_) => {
                log::warn!("Korean dictionary loaded but check failed - may be Hunspell < 1.7.0");
                false
            }
            Err(e) => {
                log::warn!("Korean dictionary found but failed to load: {}", e);
                false
            }
        }
    } else {
        log::info!("Korean dictionary not found at {:?} - Korean spell check disabled", user_dict_path);
        false
    };
    
    Ok(HunspellStatus {
        english_available: true,
        korean_available,
    })
}

pub struct HunspellStatus {
    pub english_available: bool,
    pub korean_available: bool,
}
```

### Dictionary Path Strategy

| Dictionary | Location | Bundled? | Required? |
|------------|----------|----------|-----------|
| en_US.dic/.aff | `<app_bundle>/dictionaries/` | YES | YES - app fails if missing |
| en_GB.dic/.aff | `<app_bundle>/dictionaries/` | YES | Optional (falls back to en_US) |
| ko_KR.dic/.aff | `<app_data>/dictionaries/` | NO | NO - user provides |

**Paths**:
- macOS bundle: `TranslationQA.app/Contents/Resources/dictionaries/`
- Windows install: `C:\Program Files\TranslationQA\dictionaries\`
- User dictionaries (all platforms): Resolved via Tauri `app_data_dir()` + `/dictionaries/`

---

### Virtual Scrolling: `@tanstack/react-virtual` (CHOSEN)

**Decision**: Use `@tanstack/react-virtual` for segment list virtualization.

**Rationale**:
- Modern, well-maintained, framework-agnostic core
- Excellent React integration
- Handles 10K+ items smoothly

**Performance Target**: 
- Frame time < 16ms during scroll on M1 Mac / Intel i5 baseline
- No input stalls > 100ms when navigating 5K segment list

### Locale Number Formatting: Simplified Config (CHOSEN)

**Decision**: Use simplified locale config in profiles, NOT full ICU/CLDR.

**Rationale**: Full ICU is heavyweight; translation QA needs only:
- Decimal separator (`,` or `.`)
- Thousands separator (`,`, `.`, ` `, or none)
- Percentage spacing (`50%` vs `50 %`)

**Implementation**:
```json
// In profile JSON
"locale_config": {
  "decimal_separator": ".",
  "thousands_separator": ",",
  "percent_space": false
}
```

---

## Write-Back Strategy (CRITICAL)

### Problem
`quick-xml` re-serialization does NOT preserve:
- Exact whitespace between elements
- Attribute order
- CDATA vs escaped text
- Entity forms (`&amp;` vs `&#38;`)

### Solution: Targeted Byte Patching

Instead of re-serializing the entire document, we:
1. Parse to extract segments and their byte ranges
2. Store original file bytes
3. On save, patch only the `<target>` element bytes

---

## Byte Range Source of Truth (CRITICAL)

### Problem: UTF-16 Files and Byte Offsets

When parsing UTF-16 files:
1. We transcode to UTF-8 for `quick-xml` parsing
2. Byte offsets from parsing are in the UTF-8 buffer, NOT the original UTF-16 bytes
3. We cannot directly patch the original UTF-16 bytes using UTF-8 offsets

### Solution: Always Work in UTF-8 Internally

**Strategy**: Store and patch the **UTF-8 transcoded version**, then transcode back on write.

```rust
struct ParsedFile {
    /// UTF-8 content (transcoded if original was UTF-16)
    working_bytes: Vec<u8>,
    
    /// Original encoding for write-back
    original_encoding: Encoding,
    
    /// Whether we need to add BOM on write
    had_bom: bool,
    
    /// Segments with byte ranges in working_bytes (UTF-8)
    segments: Vec<ParsedSegment>,
}

struct ParsedSegment {
    id: String,
    source: SegmentContent,
    target: Option<SegmentContent>,
    
    /// Byte ranges in working_bytes (UTF-8)
    target_start_byte: Option<usize>,
    target_end_byte: Option<usize>,
    trans_unit_end_byte: usize,
}
```

**On File Open**:
1. Read raw bytes from disk
2. Detect encoding (UTF-8, UTF-16LE, UTF-16BE) via BOM or XML declaration
3. Transcode to UTF-8 → `working_bytes`
4. Parse `working_bytes` with `quick-xml`
5. Extract byte ranges (these are UTF-8 offsets in `working_bytes`)

**On File Save**:
1. Apply patches to `working_bytes` (all operations in UTF-8)
2. Transcode `working_bytes` back to original encoding (see below)
3. Add BOM if `had_bom` was true
4. Write to disk

**Key Invariant**: All byte ranges (`target_start_byte`, etc.) are measured in UTF-8 `working_bytes`, never in original encoding.

### UTF-16 Encoding on Write (CRITICAL)

**Problem**: `encoding_rs` does NOT support UTF-16 encoding (only decoding).

**Solution**: Use Rust standard library for UTF-16 encoding:

```rust
fn transcode_to_original(utf8_content: &str, encoding: Encoding, had_bom: bool) -> Vec<u8> {
    match encoding {
        Encoding::Utf8 => {
            let mut bytes = Vec::new();
            if had_bom {
                bytes.extend_from_slice(&[0xEF, 0xBB, 0xBF]); // UTF-8 BOM
            }
            bytes.extend_from_slice(utf8_content.as_bytes());
            bytes
        }
        Encoding::Utf16Le => {
            let mut bytes = Vec::new();
            if had_bom {
                bytes.extend_from_slice(&[0xFF, 0xFE]); // UTF-16LE BOM
            }
            // Rust str is UTF-8, encode_utf16 gives UTF-16 code units
            for code_unit in utf8_content.encode_utf16() {
                bytes.extend_from_slice(&code_unit.to_le_bytes());
            }
            bytes
        }
        Encoding::Utf16Be => {
            let mut bytes = Vec::new();
            if had_bom {
                bytes.extend_from_slice(&[0xFE, 0xFF]); // UTF-16BE BOM
            }
            for code_unit in utf8_content.encode_utf16() {
                bytes.extend_from_slice(&code_unit.to_be_bytes());
            }
            bytes
        }
    }
}
```

**Dependencies**: No external crate needed for UTF-16 encoding - Rust stdlib suffices.

### Encoding Detection and Transcoding

```rust
fn detect_encoding(bytes: &[u8]) -> (Encoding, bool) {
    // Check BOM first
    if bytes.starts_with(&[0xEF, 0xBB, 0xBF]) {
        return (Encoding::Utf8, true);
    }
    if bytes.starts_with(&[0xFF, 0xFE]) {
        return (Encoding::Utf16Le, true);
    }
    if bytes.starts_with(&[0xFE, 0xFF]) {
        return (Encoding::Utf16Be, true);
    }
    
    // Check XML declaration: <?xml ... encoding="UTF-16"?>
    // (simplified - actual impl needs proper parsing)
    if let Some(decl) = find_xml_declaration(bytes) {
        if decl.contains("UTF-16") || decl.contains("utf-16") {
            // Determine endianness from content or default to LE
            return (Encoding::Utf16Le, false);
        }
    }
    
    // Default to UTF-8
    (Encoding::Utf8, false)
}
```

---

---

## Canonical Parser/Writer Data Model (SINGLE SOURCE OF TRUTH)

**All other code snippets in this plan derive from these definitions.**

```rust
/// Represents a parsed XLIFF-family file ready for editing and write-back
pub struct ParsedFile {
    /// UTF-8 content (transcoded if original was UTF-16)
    pub working_bytes: Vec<u8>,
    
    /// Original encoding for write-back
    pub original_encoding: Encoding,
    
    /// Whether original had BOM
    pub had_bom: bool,
    
    /// Parsed segments with byte ranges in working_bytes
    pub segments: Vec<ParsedSegment>,
    
    /// Original file path (for backup naming)
    pub source_path: PathBuf,
}

/// A segment parsed from the file with byte range metadata
pub struct ParsedSegment {
    /// Segment ID from trans-unit/unit
    pub id: String,
    
    /// Parsed source content
    pub source: SegmentContent,
    
    /// Parsed target content (None if <target> element missing entirely)
    pub target: Option<SegmentContent>,
    
    /// Byte offset of '<' in <target...> (None if no target element)
    /// For <target/>, this is the position of '<' in <target/>
    pub target_start_byte: Option<usize>,
    
    /// Byte offset AFTER '>' in </target> or after '/>' in <target/>
    /// For <target>x</target>: position after final '>'
    /// For <target/>: position after '/>'
    pub target_end_byte: Option<usize>,
    
    /// Byte offset AFTER '>' in </source> - insertion point for missing target
    pub source_end_byte: usize,
    
    /// True if original was <target/>, false if <target>...</target> or missing
    pub target_is_self_closing: bool,
    
    /// Translation state (from SDL conf or XLIFF 2.0 state)
    pub state: SegmentState,
    
    /// Whether segment is locked
    pub locked: bool,
    
    /// Match percentage if from TM
    pub match_percent: Option<u8>,
}

/// A change to be applied during write-back
pub struct SegmentChange {
    /// Index into ParsedFile.segments
    pub segment_index: usize,
    
    /// New target content to write
    pub new_target: SegmentContent,
}
```

**Byte Patch Ordering Rule** (CANONICAL):
```rust
// When applying changes, sort by target_start_byte (or source_end_byte if no target) DESCENDING
// This ensures earlier byte ranges remain valid as we splice later ones
let mut sorted_changes: Vec<(usize, &SegmentChange)> = changes.iter()
    .map(|c| {
        let seg = &parsed.segments[c.segment_index];
        let pos = seg.target_start_byte.unwrap_or(seg.source_end_byte);
        (pos, c)
    })
    .collect();
sorted_changes.sort_by(|a, b| b.0.cmp(&a.0));  // Descending by position

for (_, change) in sorted_changes {
    // Apply patch...
}
```

---

**Algorithm** (Using Canonical Model above):

```rust
// CANONICAL DATA MODEL - all byte ranges are in UTF-8 working_bytes
struct ParsedFile {
    /// UTF-8 content (transcoded if original was UTF-16)
    working_bytes: Vec<u8>,
    
    /// Original encoding for write-back
    original_encoding: Encoding,
    
    /// Whether original had BOM
    had_bom: bool,
    
    /// Segments with byte ranges in working_bytes
    segments: Vec<ParsedSegment>,
}

struct ParsedSegment {
    id: String,
    source: SegmentContent,
    target: Option<SegmentContent>,
    
    /// Byte ranges in working_bytes (UTF-8)
    /// Start of <target> including the opening tag
    target_start_byte: Option<usize>,
    /// End of </target> including the closing tag
    target_end_byte: Option<usize>,
    /// Position after </source> where <target> should be inserted if missing
    source_end_byte: usize,
}

fn save_file(parsed: &mut ParsedFile, changes: &[SegmentChange]) -> Result<Vec<u8>> {
    // Clone working_bytes (UTF-8) for patching
    let mut output = parsed.working_bytes.clone();
    
    // Sort changes by byte position descending (patch from end to avoid offset shifts)
    let mut sorted_changes = changes.to_vec();
    sorted_changes.sort_by(|a, b| b.byte_position.cmp(&a.byte_position));
    
    for change in sorted_changes {
        let segment = &parsed.segments[change.segment_index];
        
        if let (Some(start), Some(end)) = (segment.target_start_byte, segment.target_end_byte) {
            // Replace existing <target>...</target>
            let new_target = format_target_element(&change.new_target, segment);
            output.splice(start..end, new_target.bytes());
        } else {
            // Insert new <target> element after </source>
            let insert_pos = segment.source_end_byte;
            let new_target = format_target_element(&change.new_target, segment);
            output.splice(insert_pos..insert_pos, new_target.bytes());
        }
    }
    
    // Transcode patched UTF-8 back to original encoding
    let utf8_str = std::str::from_utf8(&output)?;
    let final_bytes = transcode_to_original(utf8_str, parsed.original_encoding, parsed.had_bom);
    
    Ok(final_bytes)
}

fn format_target_element(content: &SegmentContent, original: &ParsedSegment) -> String {
    // Preserve original <target> attributes if they existed (captured separately)
    // Serialize inline elements back to XML
    // Preserve CDATA if original used CDATA (tracked in SegmentContent)
    // ...
}
```

**Key Invariants**:
1. Bytes outside `<target>` elements are NEVER modified in `working_bytes`
2. Attribute order within `<target>` preserved (capture original attributes as string)
3. If original used CDATA, output uses CDATA (tracked in `SegmentContent.uses_cdata`)
4. If `<target>` doesn't exist, insert after `</source>` with same indentation
5. Descending patch order ensures byte offsets remain valid during splicing

**Handling Missing `<target>`**:
- Detect via `target_start_byte == None`
- Insert position: `source_end_byte` (immediately after `</source>`)
- Indentation: capture whitespace between `</source>` and next element during parsing

---

## Byte Range Capture with quick-xml (Task 4 Implementation Detail)

### How to Get Byte Offsets

`quick-xml::Reader` provides `buffer_position()` which returns the current byte offset in the input buffer.

**IMPORTANT API NOTE**: 
- Use `Reader::from_str()` or `Reader::from_reader(Cursor::new(bytes))` for byte-offset tracking
- `buffer_position()` returns the position BEFORE the current event was read
- For end tags, `buffer_position()` after `read_event` returns position AFTER the `>`

**Canonical Snippet (Compile-Correct)**:

```rust
use quick_xml::Reader;
use quick_xml::events::Event;
use std::io::Cursor;

fn parse_with_byte_ranges(utf8_content: &[u8]) -> Result<Vec<ParsedSegment>, ParseError> {
    // CRITICAL: Use Cursor to wrap bytes for proper BufRead implementation
    let cursor = Cursor::new(utf8_content);
    let mut reader = Reader::from_reader(cursor);
    reader.config_mut().trim_text(false);  // Preserve whitespace!
    
    let mut segments = Vec::new();
    let mut current_segment: Option<SegmentBuilder> = None;
    let mut buf = Vec::new();
    
    loop {
        // Position BEFORE reading the event
        let position_before = reader.buffer_position() as usize;
        
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(e)) if e.name().as_ref() == b"trans-unit" => {
                // Extract id attribute
                let id = e.attributes()
                    .filter_map(|a| a.ok())
                    .find(|a| a.key.as_ref() == b"id")
                    .map(|a| String::from_utf8_lossy(&a.value).to_string())
                    .unwrap_or_default();
                current_segment = Some(SegmentBuilder::new(id));
            }
            Ok(Event::Start(e)) if e.name().as_ref() == b"source" => {
                if let Some(ref mut seg) = current_segment {
                    seg.source_start_byte = position_before;
                }
            }
            Ok(Event::End(e)) if e.name().as_ref() == b"source" => {
                if let Some(ref mut seg) = current_segment {
                    // Position AFTER </source> - this is where <target> would be inserted
                    seg.source_end_byte = reader.buffer_position() as usize;
                }
            }
            Ok(Event::Start(e)) if e.name().as_ref() == b"target" => {
                if let Some(ref mut seg) = current_segment {
                    seg.target_start_byte = Some(position_before);
                    seg.target_is_self_closing = false;
                    // Extract original attributes for preservation
                    seg.target_original_attrs = extract_attributes_string(&e, utf8_content, position_before);
                }
            }
            Ok(Event::End(e)) if e.name().as_ref() == b"target" => {
                if let Some(ref mut seg) = current_segment {
                    // Position AFTER </target>
                    seg.target_end_byte = Some(reader.buffer_position() as usize);
                }
            }
            // Self-closing <target/> - single event, no End
            Ok(Event::Empty(e)) if e.name().as_ref() == b"target" => {
                if let Some(ref mut seg) = current_segment {
                    seg.target_start_byte = Some(position_before);
                    seg.target_end_byte = Some(reader.buffer_position() as usize);
                    seg.target_is_self_closing = true;
                    seg.target_original_attrs = extract_attributes_string(&e, utf8_content, position_before);
                    // Empty target exists but has no content
                    seg.target_content = Some(SegmentContent {
                        text: String::new(),
                        inline_elements: vec![],
                        uses_cdata: false,
                        original_attributes: seg.target_original_attrs.clone(),
                    });
                }
            }
            Ok(Event::End(e)) if e.name().as_ref() == b"trans-unit" => {
                if let Some(seg) = current_segment.take() {
                    segments.push(seg.build());
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => return Err(ParseError::InvalidXml(e.to_string())),
            _ => {}
        }
        buf.clear();
    }
    
    Ok(segments)
}

/// Extract attributes as a string from the raw bytes (for round-trip preservation)
fn extract_attributes_string(e: &quick_xml::events::BytesStart, bytes: &[u8], start_pos: usize) -> String {
    // Find the '>' that closes this opening tag
    let tag_slice = &bytes[start_pos..];
    if let Some(end) = tag_slice.iter().position(|&b| b == b'>') {
        let tag_str = String::from_utf8_lossy(&tag_slice[..end]);
        // Extract attributes portion after element name
        if let Some(space_pos) = tag_str.find(char::is_whitespace) {
            let attrs = tag_str[space_pos..].trim();
            // Remove trailing '/' if self-closing
            attrs.trim_end_matches('/').trim().to_string()
        } else {
            String::new()
        }
    } else {
        String::new()
    }
}
```

**Byte Position Semantics**:
| Scenario | `position_before` | `buffer_position()` after read |
|----------|-------------------|-------------------------------|
| `<target>` | Position of `<` | Position after `>` |
| `</target>` | Position of `<` | Position after `>` |
| `<target/>` | Position of `<` | Position after `>` |

**Stored Ranges**:
- `target_start_byte`: Position of `<` in opening tag
- `target_end_byte`: Position AFTER `>` in closing tag (or self-closing `/>`)
- This means `&bytes[start..end]` gives the ENTIRE `<target>...</target>` element
```

### Namespace Handling Clarification

**"Preserve ALL namespaces"** means:
- We do NOT use `NsReader` (namespace-resolving reader)
- We use basic `Reader` which treats namespaced elements as literal bytes
- Since we only patch `<target>` content and never touch namespace declarations, all namespaces are preserved automatically
- This is a consequence of byte-patching: we don't re-serialize the document, so xmlns declarations remain untouched

---

## Empty/Self-Closing Element Handling (CRITICAL)

### Problem

`quick-xml` represents elements differently:
- `<target>text</target>` → `Event::Start` ... `Event::End`
- `<target/>` (self-closing, empty) → `Event::Empty` (single event, no End)

This affects byte-range capture AND write-back strategy.

### Detection During Parsing

```rust
loop {
    let position_before = reader.buffer_position();
    
    match reader.read_event_into(&mut buf)? {
        // Normal case: <target>...</target>
        Event::Start(e) if e.name().as_ref() == b"target" => {
            if let Some(ref mut seg) = current_segment {
                seg.target_start_byte = Some(position_before);
                seg.target_is_self_closing = false;
            }
        }
        Event::End(e) if e.name().as_ref() == b"target" => {
            if let Some(ref mut seg) = current_segment {
                seg.target_end_byte = Some(reader.buffer_position());
            }
        }
        
        // Self-closing case: <target/>
        Event::Empty(e) if e.name().as_ref() == b"target" => {
            if let Some(ref mut seg) = current_segment {
                seg.target_start_byte = Some(position_before);
                seg.target_end_byte = Some(reader.buffer_position());
                seg.target_is_self_closing = true;
                // Empty target still "exists" - just has no content
                seg.target = Some(SegmentContent {
                    text: String::new(),
                    inline_elements: vec![],
                    uses_cdata: false,
                    original_attributes: extract_attributes(&e),
                });
            }
        }
        
        // Similar handling for inline elements like <x/>, <bx/>, <ex/>
        Event::Empty(e) if is_inline_element(&e) => {
            // Record as InlineElement with original_xml = "<x id=\"1\"/>"
            // These are NEVER expanded to start+end form
        }
        
        // ...
    }
}
```

### Segment Target States

| File Content | Detection | `target_start_byte` | `target` field | `target_is_self_closing` |
|--------------|-----------|---------------------|----------------|--------------------------|
| `<source>text</source>` (no target) | No target event | `None` | `None` | N/A |
| `<target/>` | `Event::Empty` | `Some(pos)` | `Some(empty content)` | `true` |
| `<target></target>` | `Start` + `End` | `Some(pos)` | `Some(empty content)` | `false` |
| `<target>text</target>` | `Start` + `End` | `Some(pos)` | `Some(content)` | `false` |

### Write-Back for Empty/Self-Closing Elements

**Rule**: We ALWAYS write back as `<target>NEW CONTENT</target>` (expanded form), even if original was `<target/>`.

**Rationale**: 
- Simpler implementation (one code path)
- All CAT tools accept expanded form
- Original was empty anyway, so no "formatting preservation" concern

**Implementation**:

```rust
/// CANONICAL: Format a target element for write-back
/// 
/// # Arguments
/// * `content` - New content (with original_attributes from parsing)
/// 
/// # Returns
/// Complete `<target ...>content</target>` string ready for byte splicing
fn format_target_element(content: &SegmentContent) -> String {
    // Get original attributes from content (captured during parsing)
    let attrs = &content.original_attributes;
    // Serialize tokens back to XML
    let inner_xml = content.to_xml();
    
    // Always output expanded form, regardless of original self-closing status
    if attrs.is_empty() {
        format!("<target>{}</target>", inner_xml)
    } else {
        // CRITICAL: Preserve original attributes EXACTLY as captured
        // This maintains attribute ORDER because we store the raw substring
        format!("<target {}>{}</target>", attrs, inner_xml)
    }
}

// Example: original_attributes captured during parsing
// Original: <target xml:lang="ko" state="needs-review-translation">text</target>
// Captured: 'xml:lang="ko" state="needs-review-translation"'
// On write-back: attributes reproduced in exact same order

/// CANONICAL: Save file with pending changes
fn save_file(parsed: &mut ParsedFile, changes: &[SegmentChange]) -> Result<Vec<u8>> {
    let mut output = parsed.working_bytes.clone();
    
    // Sort by position descending (patch from end to avoid offset shifts)
    let mut sorted_changes: Vec<_> = changes.iter()
        .map(|c| {
            let seg = &parsed.segments[c.segment_index];
            let pos = seg.target_start_byte.unwrap_or(seg.source_end_byte);
            (pos, c)
        })
        .collect();
    sorted_changes.sort_by(|a, b| b.0.cmp(&a.0));
    
    for (_, change) in sorted_changes {
        let segment = &parsed.segments[change.segment_index];
        
        match (segment.target_start_byte, segment.target_end_byte) {
            // Case 1: Target exists (normal or self-closing)
            (Some(start), Some(end)) => {
                // change.new_target already has original_attributes copied from segment
                let new_target = format_target_element(&change.new_target);
                output.splice(start..end, new_target.bytes());
            }
            
            // Case 2: No target exists - insert after </source>
            (None, None) => {
                let insert_pos = segment.source_end_byte;
                // For new target, original_attributes is empty (no previous target)
                let new_target = format_target_element(&change.new_target);
                // Preserve indentation: capture whitespace pattern before inserting
                output.splice(insert_pos..insert_pos, new_target.bytes());
            }
            
            _ => unreachable!("Invalid state"),
        }
    }
    
    // Transcode back to original encoding
    let utf8_str = std::str::from_utf8(&output)?;
    let final_bytes = transcode_to_original(utf8_str, parsed.original_encoding, parsed.had_bom);
    
    Ok(final_bytes)
}
```

**Note**: When creating a `SegmentChange`, the caller should copy `original_attributes` from the existing segment's target (if any), or leave empty for new targets.

### Inline Self-Closing Elements

Inline elements like `<x/>`, `<bx/>`, `<ex/>`, `<ph/>` are handled differently:
- They are NEVER modified by our app (we only edit text, not tags)
- They are stored in `InlineElement.original_xml` as-is
- On write-back, they are reproduced exactly as original (via `original_xml`)

**No expansion**: `<x id="1"/>` stays as `<x id="1"/>`, not `<x id="1"></x>`

---

## Inline Tag Preservation Model (CRITICAL for Editing + Write-Back)

### Problem

When user edits a segment, they edit the TEXT only. Inline tags must be preserved in correct positions.

**Example**:
- Original target: `Click <g id="1">here</g> to continue`
- User edits text to: `Cliquez ici pour continuer`
- But where does `<g id="1">` go now?

### Solution: Tokenized Content Model

Content is stored as a sequence of **tokens** (text or tag):

```
Original: "Click <g id="1">here</g> to continue"

Tokens:
  [0] Text("Click ")
  [1] Tag(<g id="1">)    // Opening tag
  [2] Text("here")
  [3] Tag(</g>)          // Closing tag
  [4] Text(" to continue")
```

### Editing Rules

**User sees**: Just the text (tags hidden or shown as placeholders)
**User edits**: Text fragments only - tags are "anchored" between text fragments

**UI Behavior**:
1. Display tags as visual badges/placeholders between text
2. User can edit text on either side of a tag
3. User CANNOT delete a tag (blocked in UI)
4. User CANNOT move a tag (position is fixed)

**Example editing session**:
```
Display: "Click [1] here [/1] to continue"
         └─────┘    └────┘    └─────────┘
          Text      Text      Text

User changes "Click " to "Cliquez ": 
  Token[0] becomes Text("Cliquez ")

User changes "here" to "ici":
  Token[2] becomes Text("ici")

User changes " to continue" to " pour continuer":
  Token[4] becomes Text(" pour continuer")

Result tokens:
  [0] Text("Cliquez ")
  [1] Tag(<g id="1">)
  [2] Text("ici")
  [3] Tag(</g>)
  [4] Text(" pour continuer")

Serialized: "Cliquez <g id="1">ici</g> pour continuer"
```

### Parsing (Token Extraction) - CANONICAL ALGORITHM

**Goal**: Extract inline tags with EXACT original XML bytes for round-trip preservation.

**Key insight**: We have `working_bytes` (the UTF-8 buffer) and `buffer_position()` gives us byte offsets. We can slice directly from `working_bytes` to get exact original XML.

```rust
/// CANONICAL: Parse segment content into tokens while preserving exact tag XML
fn parse_segment_content(
    working_bytes: &[u8],      // Full file UTF-8 bytes
    content_start: usize,      // Byte offset of first char after <target...>
    content_end: usize,        // Byte offset of '<' in </target>
) -> Result<SegmentContent, ParseError> {
    let content_slice = &working_bytes[content_start..content_end];
    
    let mut tokens = Vec::new();
    let mut current_text = String::new();
    let mut uses_cdata = false;
    
    // Use quick-xml to parse the content slice
    let mut reader = quick_xml::Reader::from_reader(std::io::Cursor::new(content_slice));
    reader.config_mut().trim_text(false);
    let mut buf = Vec::new();
    
    loop {
        let pos_before = reader.buffer_position() as usize;
        
        match reader.read_event_into(&mut buf)? {
            Event::Text(e) => {
                // Append decoded text
                current_text.push_str(&e.unescape()?);
            }
            Event::CData(e) => {
                uses_cdata = true;
                current_text.push_str(&String::from_utf8_lossy(e.as_ref()));
            }
            
            // INLINE TAG HANDLING - extract exact original bytes
            Event::Start(e) if is_inline_element(&e) => {
                // Flush pending text
                if !current_text.is_empty() {
                    tokens.push(ContentToken::Text(std::mem::take(&mut current_text)));
                }
                
                // Extract exact original XML from content_slice
                let tag_end = find_tag_end(&content_slice[pos_before..], false)?;
                let original_xml = String::from_utf8_lossy(
                    &content_slice[pos_before..pos_before + tag_end]
                ).to_string();
                
                tokens.push(ContentToken::Tag(InlineElement {
                    id: extract_id(&e),
                    kind: tag_kind_from_name(e.name().as_ref()),
                    content: None,  // Will be filled by nested content
                    rid: extract_rid(&e),
                    original_xml,
                }));
            }
            Event::End(e) if is_inline_element(&e) => {
                // Flush pending text
                if !current_text.is_empty() {
                    tokens.push(ContentToken::Text(std::mem::take(&mut current_text)));
                }
                
                // Extract exact original XML for closing tag
                let tag_end = find_tag_end(&content_slice[pos_before..], false)?;
                let original_xml = String::from_utf8_lossy(
                    &content_slice[pos_before..pos_before + tag_end]
                ).to_string();
                
                tokens.push(ContentToken::Tag(InlineElement {
                    id: extract_id_from_end(&e),
                    kind: tag_kind_from_name(e.name().as_ref()),
                    content: None,
                    rid: None,
                    original_xml,
                }));
            }
            Event::Empty(e) if is_inline_element(&e) => {
                // Self-closing inline tag like <x/>, <ph/>
                if !current_text.is_empty() {
                    tokens.push(ContentToken::Text(std::mem::take(&mut current_text)));
                }
                
                let tag_end = find_tag_end(&content_slice[pos_before..], true)?;
                let original_xml = String::from_utf8_lossy(
                    &content_slice[pos_before..pos_before + tag_end]
                ).to_string();
                
                tokens.push(ContentToken::Tag(InlineElement {
                    id: extract_id(&e),
                    kind: tag_kind_from_name(e.name().as_ref()),
                    content: None,
                    rid: extract_rid(&e),
                    original_xml,
                }));
            }
            
            Event::Eof => break,
            _ => {}  // Ignore other events within content
        }
        buf.clear();
    }
    
    // Flush any remaining text
    if !current_text.is_empty() {
        tokens.push(ContentToken::Text(current_text));
    }
    
    Ok(SegmentContent {
        tokens,
        uses_cdata,
        original_attributes: String::new(),  // Set by caller from <target> element
    })
}

/// Find the end of an XML tag in raw bytes
/// Returns byte offset of character AFTER '>' (or '/>')
fn find_tag_end(bytes: &[u8], is_self_closing: bool) -> Result<usize, ParseError> {
    let mut in_quotes = false;
    let mut quote_char = b'"';
    
    for (i, &b) in bytes.iter().enumerate() {
        if in_quotes {
            if b == quote_char {
                in_quotes = false;
            }
        } else {
            match b {
                b'"' | b'\'' => {
                    in_quotes = true;
                    quote_char = b;
                }
                b'>' => {
                    return Ok(i + 1);  // Position after '>'
                }
                _ => {}
            }
        }
    }
    
    Err(ParseError::InvalidXml("Unclosed tag".into()))
}

/// Check if this element is an inline XLIFF element
fn is_inline_element(e: &quick_xml::events::BytesStart) -> bool {
    matches!(
        e.name().as_ref(),
        b"g" | b"x" | b"bx" | b"ex" | b"ph" | b"bpt" | b"ept" | b"it" |
        b"pc" | b"sc" | b"ec" | b"mrk"  // XLIFF 2.0 elements
    )
}
```

**Example trace**:
```
Input content bytes: b"Click <g id=\"1\">here</g> to continue"
                       ^0    ^6           ^22   ^27

Parsing:
1. Text event: "Click " → tokens.push(Text("Click "))
2. Start event: <g id="1"> at pos 6
   - find_tag_end finds '>' at offset 10
   - original_xml = "<g id=\"1\">" (bytes 6..16)
   - tokens.push(Tag(InlineElement { original_xml: "<g id=\"1\">", ... }))
3. Text event: "here" → tokens.push(Text("here"))
4. End event: </g> at pos 22
   - find_tag_end finds '>' at offset 4
   - original_xml = "</g>" (bytes 22..26)
   - tokens.push(Tag(InlineElement { original_xml: "</g>", ... }))
5. Text event: " to continue" → tokens.push(Text(" to continue"))

Result: 5 tokens with exact original XML preserved
```

### Write-Back (Token Serialization)

```rust
fn serialize_content(content: &SegmentContent) -> String {
    content.tokens.iter()
        .map(|token| match token {
            ContentToken::Text(s) => escape_xml(s),
            ContentToken::Tag(tag) => tag.original_xml.clone(), // Exact reproduction
        })
        .collect()
}
```

### Acceptance Criteria (Added to Task 4 and Task 7)

**Task 4 (parsing)**:
- [ ] Content parsed into token sequence
- [ ] `SegmentContent.text_only()` returns correct plain text
- [ ] `SegmentContent.to_xml()` reproduces original exactly
- [ ] Unit test `parser::test_tokenized_content`:
  - Parse `<target>Click <g id="1">here</g> to continue</target>`
  - Verify 5 tokens: Text, Tag, Text, Tag, Text
  - Verify `to_xml()` == original content

**Task 7 (write-back)**:
- [ ] Modified tokens serialize correctly
- [ ] Tags preserved in exact original form
- [ ] **Attribute preservation**: Target element attributes reproduced in original order
- [ ] Unit test `parser::writer::test_tag_preservation`:
  - Parse fixture with inline tags
  - Modify text tokens only
  - Write back
  - Verify tags unchanged in output (exact byte match for tag portions)
- [ ] Unit test `parser::writer::test_attribute_preservation`:
  - Parse: `<target xml:lang="ko" state="translated">text</target>`
  - Modify text to "new text"
  - Write back
  - Verify output: `<target xml:lang="ko" state="translated">new text</target>` (attributes in same order)

### Fixture Requirements

Add to Task 1 fixtures:

**`fixtures/xliff/minimal_empty_target.xliff`**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
  <file original="test.txt" source-language="en" target-language="ko" datatype="plaintext">
    <body>
      <trans-unit id="1">
        <source>Text with self-closing target</source>
        <target/>
      </trans-unit>
      <trans-unit id="2">
        <source>Text with no target at all</source>
      </trans-unit>
      <trans-unit id="3">
        <source>Text with empty expanded target</source>
        <target></target>
      </trans-unit>
    </body>
  </file>
</xliff>
```

### Acceptance Criteria (Added to Task 4 and Task 7)

**Task 4 (parsing)**:
- [ ] `<target/>` (self-closing) detected as existing but empty target
- [ ] Missing `<target>` detected as `target = None`
- [ ] `<target></target>` (empty expanded) detected as existing but empty
- [ ] Unit test `parser::xliff::test_empty_target_variants` passes

**Task 7 (write-back)**:
- [ ] Editing segment with `<target/>` expands to `<target>NEW</target>`
- [ ] Editing segment with no `<target>` inserts `<target>NEW</target>` after `</source>`
- [ ] Diff shows only target changes (no other modifications)
- [ ] Unit test `parser::writer::test_empty_target_writeback` passes

---

---

## Test Fixtures Strategy

### Minimum Seed Fixtures (Ship In-Repo)

Create minimal anonymized fixtures that cover critical cases:

```
fixtures/
├── sdlxliff/
│   ├── minimal_basic.sdlxliff       # 3 segments, basic structure
│   ├── minimal_locked.sdlxliff      # 2 segments, one locked
│   └── minimal_namespaces.sdlxliff  # 2 segments, extra namespaces
├── mxliff/
│   ├── minimal_basic.mxliff         # 3 segments
│   └── minimal_joined.mxliff        # 2 segments with {j}
├── xliff/
│   ├── minimal_12.xliff             # XLIFF 1.2, 3 segments
│   ├── minimal_20.xliff             # XLIFF 2.0, 3 segments
│   └── minimal_utf16.xliff          # UTF-16 encoded, 2 segments
└── glossary/
    ├── minimal.xlsx                 # 5 terms
    ├── minimal.tbx                  # 5 terms
    └── minimal.csv                  # 5 terms
```

**Anonymization Checklist**:
- [ ] No real client names in content
- [ ] No proprietary product names
- [ ] Use placeholder text: "Source text one", "Target text one"
- [ ] Preserve structural complexity (namespaces, locked flags, etc.)

**User-Provided Fixtures** (Optional, for comprehensive testing):
- User can add real (anonymized) files from their workflow
- README in each `fixtures/` subdir explains what to add

### XLIFF Schema Location

**Vendored at**: `schemas/xliff-core-1.2-strict.xsd`

**Source**: https://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd

**Validation command**: `xmllint --schema schemas/xliff-core-1.2-strict.xsd file.xliff`

---

## UI Reference Map (Canonical Library Choices)

### Chosen UI Libraries (LOCKED)

| Purpose | Library | Version | Doc URL | Decision Rationale |
|---------|---------|---------|---------|-------------------|
| **CSS Framework** | TailwindCSS | 3.x | https://tailwindcss.com/docs | Standard, no runtime, tree-shakeable |
| **State Management** | Zustand | 4.x | https://docs.pmnd.rs/zustand/getting-started/introduction | Minimal boilerplate, TypeScript native |
| **Virtual Scrolling** | @tanstack/react-virtual | 3.x | https://tanstack.com/virtual/latest/docs/framework/react/react-virtual | Best React performance, maintained |
| **Tab Component** | None (custom) | N/A | See pattern below | Tauri integration needs custom close handling |
| **Toast/Notifications** | Sonner | 1.x | https://sonner.emilkowal.ski/ | Minimal, accessible, unstyled option |
| **Editor** | textarea + custom logic | N/A | See pattern below | ContentEditable has IME/undo issues |
| **Dialog/Modal** | @radix-ui/react-dialog | 1.x | https://www.radix-ui.com/primitives/docs/components/dialog | Accessible, unstyled, focus trap |
| **Keyboard Shortcuts** | Custom hook | N/A | See pattern below | Simple, platform-aware |

### UI Implementation Patterns

**Tab Component Pattern** (Task 21):
```typescript
// Custom tab component for file management
interface FileTab {
  id: string;
  path: string;
  filename: string;
  modified: boolean;
}

function TabBar({ tabs, activeTab, onSelect, onClose }: TabBarProps) {
  return (
    <div className="flex gap-1 border-b">
      {tabs.map(tab => (
        <button
          key={tab.id}
          onClick={() => onSelect(tab.id)}
          className={activeTab === tab.id ? 'bg-blue-100' : ''}
        >
          {tab.filename}{tab.modified && '*'}
          <span onClick={(e) => { e.stopPropagation(); onClose(tab.id); }}>×</span>
        </button>
      ))}
    </div>
  );
}
```

**Segment Editor Pattern** (Task 23):
```typescript
// Use textarea (NOT contenteditable) for IME safety and predictable undo
function SegmentEditor({ segment, onChange }: Props) {
  const [localValue, setLocalValue] = useState(segment.target?.text ?? '');
  const [history, setHistory] = useState<string[]>([localValue]);
  const [historyIndex, setHistoryIndex] = useState(0);

  const handleUndo = () => {
    if (historyIndex > 0) {
      setHistoryIndex(i => i - 1);
      setLocalValue(history[historyIndex - 1]);
    }
  };
  
  // Use textarea with onKeyDown for Ctrl+Z handling
  return <textarea value={localValue} onChange={...} onKeyDown={handleKeyDown} />;
}
```

**Keyboard Shortcuts Pattern** (Task 28):
```typescript
// Platform-aware keyboard shortcuts
function useKeyboardShortcuts(shortcuts: ShortcutConfig[]) {
  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const modifier = isMac ? e.metaKey : e.ctrlKey;
      for (const shortcut of shortcuts) {
        if (modifier === shortcut.needsModifier && e.key === shortcut.key) {
          e.preventDefault();
          shortcut.action();
        }
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [shortcuts, isMac]);
}
```

**Toast Pattern** (Task 27):
```typescript
// Using Sonner for notifications
import { toast } from 'sonner';

// Success
toast.success('File saved successfully');

// Error  
toast.error('Failed to save file: Permission denied');

// With action
toast('Unsaved changes', {
  action: { label: 'Save', onClick: () => saveFile() }
});
```

### Tauri-Specific References

| Task | Tauri Feature | Doc URL |
|------|---------------|---------|
| Task 3 | Commands + Channels | https://v2.tauri.app/develop/calling-rust/#channels |
| Task 21 | File Dialog | https://v2.tauri.app/plugin/dialog/ |
| Task 28 | Menus | https://v2.tauri.app/learn/window-customization/#menus |
| Task 29 | Bundler Config | https://v2.tauri.app/distribute/sign-macos/ |
| Task 29 | Resources | https://v2.tauri.app/develop/resources/ |

---

## Reference Map

All file paths in this plan are categorized:

### External References (URLs - Verifiable Now)
| Reference | URL |
|-----------|-----|
| Tauri 2.x docs | https://v2.tauri.app/start/create-project/ |
| XLIFF 1.2 spec | https://docs.oasis-open.org/xliff/v1.2/os/xliff-core.html |
| XLIFF 2.0 spec | https://docs.oasis-open.org/xliff/xliff-core/v2.0/xliff-core-v2.0.html |
| quick-xml docs | https://docs.rs/quick-xml/latest/quick_xml/ |
| hunspell-rs | https://docs.rs/hunspell-rs/latest/hunspell_rs/ |
| @tanstack/react-virtual | https://tanstack.com/virtual/latest |
| encoding_rs | https://docs.rs/encoding_rs/latest/encoding_rs/ |
| calamine | https://docs.rs/calamine/latest/calamine/ |
| TBX spec | https://www.tbxinfo.net/ |

### Will Be Created (Task 1 Bootstrap)
All paths below are created as stubs in Task 1. Later tasks fill in implementation.

| Path | Created In | Used By |
|------|------------|---------|
| `src-tauri/src/parser/xliff.rs` | Task 1 (stub) | Task 4 (impl) |
| `src-tauri/src/parser/xliff2.rs` | Task 1 (stub) | Task 4b (impl) |
| `src-tauri/src/parser/sdlxliff.rs` | Task 1 (stub) | Task 5 (impl) |
| `src-tauri/src/parser/mxliff.rs` | Task 1 (stub) | Task 6 (impl) |
| `src-tauri/src/parser/writer.rs` | Task 1 (stub) | Task 7 (impl) |
| `src-tauri/src/qa/*.rs` | Task 1 (stubs) | Tasks 8-19 (impl) |
| `fixtures/xliff/*.xliff` | Task 1 (minimal seeds) | Tasks 4-7 (tests) |
| `fixtures/sdlxliff/*.sdlxliff` | Task 1 (minimal seeds) | Task 5 (tests) |
| `fixtures/mxliff/*.mxliff` | Task 1 (minimal seeds) | Task 6 (tests) |
| `schemas/xliff-core-1.2-strict.xsd` | Task 1 (vendored) | Tasks 4-7 (validation) |
| `docs/TESTING_CHECKLIST.md` | Task 1 (template) | Task 30 (manual tests) |

---

## Plan Verification Pack

**CRITICAL: All Internal File Paths Are Targets To Be Created**

This plan describes a NEW repository (`translation-qa/`) to be created. All internal file paths (e.g., `src-tauri/src/parser/xliff.rs`, `fixtures/xliff/minimal_12.xliff`) are **targets** to be created during Task 1 bootstrap, NOT files that exist in any current repository.

**Verification Rules:**
1. **External URLs** (XLIFF spec, crate docs, etc.) → Verifiable now
2. **Internal file paths** → Will exist after Task 1 completes
3. **Fixture contents** → Fully specified in this document (copy-paste ready)
4. **Type definitions** → Fully specified in "Complete Type Definitions" section (canonical source of truth)

**For plan reviewers:**
- Do NOT attempt to verify internal file paths exist (they won't until Task 1)
- DO verify that all referenced internal paths are listed in Task 1's directory structure
- DO verify that fixture contents are fully specified in this document
- DO verify that type definitions are complete and consistent

All type definitions, mappings, and fixture contents are fully specified in this plan document.
A developer can implement directly from these specifications.

---

### Module Boundaries (Canonical Signatures)

**Parser Module** (`src-tauri/src/parser/mod.rs`):
```rust
pub mod xliff;    // XLIFF 1.2
pub mod xliff2;   // XLIFF 2.0
pub mod sdlxliff;
pub mod mxliff;
pub mod writer;

// Core trait all parsers implement
pub trait XliffParser {
    fn parse(bytes: &[u8]) -> Result<ParsedFile, ParseError>;
    fn detect(bytes: &[u8]) -> bool;  // Can this parser handle this file?
}

// Core write-back interface
pub trait XliffWriter {
    fn write_changes(parsed: &ParsedFile, changes: &[SegmentChange]) -> Result<Vec<u8>>;
}
```

**QA Module** (`src-tauri/src/qa/mod.rs`):
```rust
pub trait QAChecker {
    fn name(&self) -> &str;
    fn check(&self, segments: &[Segment], config: &CheckConfig) -> Vec<QAError>;
}
```

---

## Complete Type Definitions (Task 2 Implementation)

All types referenced in this plan are fully defined here:

### Core Enums

```rust
/// Segment translation state
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SegmentState {
    /// Not translated yet
    NotTranslated,
    /// Draft translation (needs review)
    Draft,
    /// Translated but not reviewed
    Translated,
    /// Reviewed and approved
    Reviewed,
    /// Signed off / final
    SignedOff,
}

/// SDLXLIFF @conf value mapping
impl SegmentState {
    pub fn from_sdl_conf(conf: &str) -> Self {
        match conf {
            "Draft" => SegmentState::Draft,
            "Translated" => SegmentState::Translated,
            "RejectedTranslation" => SegmentState::Draft,
            "ApprovedTranslation" => SegmentState::Reviewed,
            "RejectedSignOff" => SegmentState::Reviewed,
            "ApprovedSignOff" => SegmentState::SignedOff,
            _ => SegmentState::NotTranslated,
        }
    }
}

/// Type of QA error
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum QAErrorType {
    MissingTag,
    ExtraTag,
    TagOrderMismatch,
    UnpairedTag,
    MissingNumber,
    NumberFormatMismatch,
    PunctuationMismatch,
    UnmatchedBracket,
    UnmatchedQuote,
    DoubleSpace,
    EmptyTarget,
    IdenticalSourceTarget,
    PartialTranslation,
    ForbiddenWord,
    TargetInconsistency,
    SourceInconsistency,
    MissingTermTranslation,
    ForbiddenTermUsed,
    SpellingError,
    CustomScript,
}

/// Type of inline element
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum TagKind {
    /// Generic span <g>
    GenericSpan,
    /// Standalone placeholder <x/>
    Placeholder,
    /// Begin paired <bx/>
    BeginPaired,
    /// End paired <ex/>
    EndPaired,
    /// Phrase <ph>
    Phrase,
    /// Begin paired tag <bpt>
    BeginPairedTag,
    /// End paired tag <ept>
    EndPairedTag,
    /// XLIFF 2.0 paired code <pc>
    PairedCode,
    /// XLIFF 2.0 start code <sc>
    StartCode,
    /// XLIFF 2.0 end code <ec>
    EndCode,
}

/// Search mode for custom scripts
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SearchMode {
    /// Both source and target match pattern
    SourceAndTarget,
    /// Source matches, target doesn't
    SourceNotTarget,
    /// Target matches, source doesn't
    TargetNotSource,
    /// Different count in source vs target
    CountMismatch,
}

/// Original file encoding
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Encoding {
    Utf8,
    Utf16Le,
    Utf16Be,
}
```

### Core Structs

```rust
/// A text range within a segment
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TextRange {
    /// Start character offset (0-based)
    pub start: usize,
    /// End character offset (exclusive)
    pub end: usize,
}

/// Inline element within segment content
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InlineElement {
    /// Element ID (from id attribute)
    pub id: String,
    /// Type of element
    pub kind: TagKind,
    /// Inner content (if any)
    pub content: Option<String>,
    /// Relation ID for paired elements
    pub rid: Option<String>,
    /// Original XML representation (for round-trip)
    pub original_xml: String,
}

/// Content of a source or target - uses TOKENIZED representation for tag preservation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SegmentContent {
    /// Tokenized content - interleaved text and tag tokens
    /// This is the CANONICAL representation for editing and write-back
    pub tokens: Vec<ContentToken>,
    /// Whether original used CDATA
    pub uses_cdata: bool,
    /// Original attributes on <source> or <target> element
    pub original_attributes: String,
}

/// A token in segment content - either text or an inline tag
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ContentToken {
    /// Plain text fragment
    Text(String),
    /// Inline tag (preserved exactly for round-trip)
    Tag(InlineElement),
}

impl SegmentContent {
    /// Get plain text only (for QA checks, spell check, display)
    pub fn text_only(&self) -> String {
        self.tokens.iter()
            .filter_map(|t| match t {
                ContentToken::Text(s) => Some(s.as_str()),
                ContentToken::Tag(_) => None,
            })
            .collect()
    }
    
    /// Serialize back to XML string (for write-back)
    pub fn to_xml(&self) -> String {
        self.tokens.iter()
            .map(|t| match t {
                ContentToken::Text(s) => escape_xml(s),
                ContentToken::Tag(tag) => tag.original_xml.clone(),
            })
            .collect()
    }
}

/// A translation segment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Segment {
    pub id: String,
    pub source: SegmentContent,
    pub target: Option<SegmentContent>,
    pub state: SegmentState,
    pub locked: bool,
    pub match_percent: Option<u8>,
    pub notes: Vec<String>,
}

/// A QA error
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QAError {
    pub segment_id: String,
    pub error_type: QAErrorType,
    pub message: String,
    pub source_range: Option<TextRange>,
    pub target_range: Option<TextRange>,
    pub suggestion: Option<String>,
}

/// Configuration for a specific QA check
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckConfig {
    pub enabled: bool,
    /// Check-specific settings as JSON value
    pub settings: serde_json::Value,
}

/// A custom QA script
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomScript {
    pub name: String,
    pub source_pattern: String,
    pub target_pattern: String,
    pub flags: ScriptFlags,
    pub search_mode: SearchMode,
}

/// Flags for custom scripts (CTWRPB)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ScriptFlags {
    /// Case-sensitive
    pub case_sensitive: bool,
    /// Search within tags
    pub include_tags: bool,
    /// Whole words only
    pub whole_words: bool,
    /// Regex mode
    pub regex: bool,
    /// Power search (boolean)
    pub power_search: bool,
    /// Back-reference (cross-segment)
    pub back_reference: bool,
}

/// QA profile (saved to JSON)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QAProfile {
    pub name: String,
    pub checks: HashMap<String, CheckConfig>,
    pub forbidden_words: Vec<String>,
    pub custom_scripts: Vec<CustomScript>,
    pub glossary_paths: Vec<String>,
    pub locale_config: LocaleConfig,
}

/// Represents a pending change to a segment (for write-back)
#[derive(Debug, Clone)]
pub struct SegmentChange {
    /// Index into ParsedFile.segments
    pub segment_index: usize,
    /// New target content to write
    pub new_target: SegmentContent,
}

/// Errors that can occur during parsing
#[derive(Debug, Clone, thiserror::Error)]
pub enum ParseError {
    #[error("Invalid XML: {0}")]
    InvalidXml(String),
    #[error("Unsupported XLIFF version: {0}")]
    UnsupportedVersion(String),
    #[error("Encoding error: {0}")]
    EncodingError(String),
    #[error("IO error: {0}")]
    IoError(String),
    #[error("Missing required element: {0}")]
    MissingElement(String),
}

/// Errors that can occur during save
#[derive(Debug, Clone, thiserror::Error)]
pub enum SaveError {
    #[error("File is locked by another process")]
    FileLocked,
    #[error("Permission denied: {0}")]
    PermissionDenied(String),
    #[error("IO error: {0}")]
    IoError(String),
    #[error("Invalid segment index: {0}")]
    InvalidSegmentIndex(usize),
}

/// Locale-specific number formatting config
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocaleConfig {
    pub decimal_separator: char,
    pub thousands_separator: Option<char>,
    pub percent_space: bool,
}

/// File data sent to frontend
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileData {
    pub path: String,
    pub segments: Vec<Segment>,
    pub format: FileFormat,
    pub modified: bool,
}

/// Detected file format
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FileFormat {
    Xliff12,
    Xliff20,
    Sdlxliff,
    Mxliff,
}

/// QA progress update (sent via Channel)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QAProgress {
    pub current_check: String,
    pub segments_processed: usize,
    pub total_segments: usize,
    pub errors_found: usize,
}
```

### TypeScript Equivalents (MUST MATCH RUST CANONICAL TYPES)

**IPC Contract**: Frontend receives tokenized content exactly as Rust stores it.
Editing updates individual text tokens; tag tokens are read-only.

```typescript
// types/index.ts

export type SegmentState = 
  | 'NotTranslated' 
  | 'Draft' 
  | 'Translated' 
  | 'Reviewed' 
  | 'SignedOff';

export type QAErrorType = 
  | 'MissingTag' 
  | 'ExtraTag' 
  | 'TagOrderMismatch'
  | 'UnpairedTag'
  | 'MissingNumber'
  | 'NumberFormatMismatch'
  | 'PunctuationMismatch'
  | 'UnmatchedBracket'
  | 'UnmatchedQuote'
  | 'DoubleSpace'
  | 'EmptyTarget'
  | 'IdenticalSourceTarget'
  | 'PartialTranslation'
  | 'ForbiddenWord'
  | 'TargetInconsistency'
  | 'SourceInconsistency'
  | 'MissingTermTranslation'
  | 'ForbiddenTermUsed'
  | 'SpellingError'
  | 'CustomScript';

export type TagKind = 
  | 'GenericSpan' 
  | 'Placeholder' 
  | 'BeginPaired'
  | 'EndPaired'
  | 'Phrase'
  | 'BeginPairedTag'
  | 'EndPairedTag'
  | 'PairedCode'
  | 'StartCode'
  | 'EndCode';

export type SearchMode = 
  | 'SourceAndTarget' 
  | 'SourceNotTarget' 
  | 'TargetNotSource' 
  | 'CountMismatch';

export interface TextRange {
  start: number;
  end: number;
}

export interface InlineElement {
  id: string;
  kind: TagKind;
  content?: string;
  rid?: string;
  original_xml: string;  // CRITICAL: Exact original XML for round-trip
}

// CANONICAL: Token model matches Rust exactly
export type ContentToken = 
  | { type: 'Text'; value: string }
  | { type: 'Tag'; value: InlineElement };

// CANONICAL: SegmentContent uses token array (matches Rust)
export interface SegmentContent {
  tokens: ContentToken[];  // Interleaved text and tag tokens
  uses_cdata: boolean;
  original_attributes: string;
}

// Helper functions for working with tokens
export function getTextOnly(content: SegmentContent): string {
  return content.tokens
    .filter((t): t is { type: 'Text'; value: string } => t.type === 'Text')
    .map(t => t.value)
    .join('');
}

export function updateTextToken(
  content: SegmentContent,
  tokenIndex: number,
  newText: string
): SegmentContent {
  const newTokens = [...content.tokens];
  if (newTokens[tokenIndex]?.type === 'Text') {
    newTokens[tokenIndex] = { type: 'Text', value: newText };
  }
  return { ...content, tokens: newTokens };
}

export interface Segment {
  id: string;
  source: SegmentContent;
  target?: SegmentContent;
  state: SegmentState;
  locked: boolean;
  match_percent?: number;
  notes: string[];
}

export interface QAError {
  segment_id: string;
  error_type: QAErrorType;
  message: string;
  source_range?: TextRange;
  target_range?: TextRange;
  suggestion?: string;
}

export interface QAProgress {
  current_check: string;
  segments_processed: number;
  total_segments: number;
  errors_found: number;
}

// --- IPC Payloads ---

// Frontend sends text-only edit; backend reconstructs tokens
export interface UpdateSegmentRequest {
  file_id: string;
  segment_id: string;
  token_edits: Array<{
    token_index: number;  // Index into content.tokens (must be Text token)
    new_value: string;
  }>;
}

// Alternative: frontend sends entire updated tokens array
export interface UpdateSegmentFullRequest {
  file_id: string;
  segment_id: string;
  new_target_tokens: ContentToken[];  // Only Text tokens modified; Tag tokens unchanged
}
```

### Frontend ↔ Backend IPC Architecture

**Editing Flow**:
1. Frontend loads `Segment` with `target.tokens` array
2. Frontend renders tags as non-editable badges between text inputs
3. User edits text in textarea/input fields (one per Text token)
4. Frontend sends `UpdateSegmentRequest` with changed token indices
5. Backend validates (tag tokens unchanged), updates `ParsedFile`, marks dirty
6. On save: Backend reconstructs full `<target>` via `SegmentContent.to_xml()`

**Why Token-Based**:
- Tags are preserved byte-for-byte (exact `original_xml`)
- No ambiguity about tag positions after edit
- Simple UI: render tokens linearly, edit only Text tokens

---

## XLIFF 2.0 Handling Strategy

### Detection
XLIFF 2.0 detected via:
- `version="2.0"` or `version="2.1"` attribute on `<xliff>` element
- Namespace: `urn:oasis:names:tc:xliff:document:2.0`

### Structural Differences from 1.2

| XLIFF 1.2 | XLIFF 2.0 |
|-----------|-----------|
| `<trans-unit>` | `<unit>` containing `<segment>` |
| `<source>`, `<target>` direct children | `<source>`, `<target>` inside `<segment>` |
| `<g>`, `<x>`, `<bx>`, `<ex>`, `<ph>`, `<bpt>`, `<ept>` | `<pc>`, `<ph>`, `<sc>`, `<ec>`, `<mrk>` |

### Implementation (Task 4b - XLIFF 2.0 Parser)

**Added to Task 4**: After implementing XLIFF 1.2 parser, add XLIFF 2.0 support:

```rust
// xliff2.rs
pub fn parse_xliff2(bytes: &[u8]) -> Result<ParsedFile, ParseError> {
    // 1. Detect encoding, transcode to UTF-8
    // 2. Parse <xliff version="2.0">
    // 3. For each <file>:
    //    For each <unit>:
    //      For each <segment>:
    //        Extract <source>, <target> with byte ranges
    // 4. Map 2.0 inline elements to common InlineElement enum
}
```

### Write-Back for XLIFF 2.0

Same byte-patching strategy as 1.2, but:
- `<target>` is inside `<segment>`, not directly in `<unit>`
- If `<target>` missing, insert after `</source>` within `<segment>`
- If `<segment>` has multiple `<source>`/`<target>` pairs (rare), handle each

### Acceptance Criteria (XLIFF 2.0)
- [ ] Parses `fixtures/xliff/minimal_20.xliff` without error
- [ ] Extracts segments with inline elements
- [ ] Round-trip preserves structure (diff shows only target changes)
- [ ] `cargo test parser::xliff2` passes

---

## Regex Timeout Strategy (CRITICAL)

### Problem
The Rust `regex` crate does NOT support true mid-execution cancellation. A blocking regex search cannot be interrupted.

### Solution: Size Limits + Thread-Based Timeout

**Strategy**:
1. Use `RegexBuilder::size_limit()` to cap DFA/NFA size (prevents catastrophic backtracking from exploding memory)
2. Run regex matching in a separate thread with a timeout wrapper
3. On timeout, the thread continues but its result is discarded
4. UI unblocks immediately on timeout

**Canonical Implementation** (copy this exactly):

```rust
use regex::{Regex, RegexBuilder};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

/// Default timeout for regex execution (configurable in profile)
const DEFAULT_REGEX_TIMEOUT_SECS: u64 = 5;
/// DFA size limit to prevent memory explosion
const REGEX_SIZE_LIMIT: usize = 10 * (1 << 20);  // 10MB

#[derive(Debug)]
pub enum RegexError {
    InvalidPattern(String),
    Timeout,
    ThreadPanicked,
}

/// Result of a regex match - owned data that can cross thread boundaries
#[derive(Debug, Clone)]
pub struct MatchSpan {
    pub start: usize,
    pub end: usize,
}

/// Execute a regex search with timeout protection
/// 
/// # Arguments
/// * `pattern` - Regex pattern string
/// * `text` - Text to search
/// * `timeout_secs` - Maximum seconds to wait (default: 5)
/// 
/// # Returns
/// * `Ok(Some(span))` - Pattern found at (start, end) byte offsets
/// * `Ok(None)` - Pattern not found (within timeout)
/// * `Err(RegexError::Timeout)` - Search exceeded timeout
/// * `Err(RegexError::InvalidPattern)` - Pattern failed to compile
/// 
/// # Note
/// Returns owned `MatchSpan` instead of `Match<'_>` because we can't return
/// a reference to data owned by the worker thread. Use the span to slice
/// the original text if you need the matched substring.
pub fn regex_find_with_timeout(
    pattern: &str,
    text: &str,
    timeout_secs: Option<u64>,
) -> Result<Option<MatchSpan>, RegexError> {
    // 1. Compile regex with size limit (this is fast, no timeout needed)
    let regex = RegexBuilder::new(pattern)
        .size_limit(REGEX_SIZE_LIMIT)
        .build()
        .map_err(|e| RegexError::InvalidPattern(e.to_string()))?;
    
    // 2. Create channel for result communication
    let (tx, rx) = mpsc::channel();
    let text_owned = text.to_string();
    let timeout = Duration::from_secs(timeout_secs.unwrap_or(DEFAULT_REGEX_TIMEOUT_SECS));
    
    // 3. Spawn worker thread - regex is moved into thread
    thread::spawn(move || {
        let result = regex.find(&text_owned);
        // Convert Match to owned MatchSpan for sending across thread boundary
        let result_data = result.map(|m| MatchSpan { start: m.start(), end: m.end() });
        let _ = tx.send(result_data);  // Ignore if receiver dropped (timeout case)
    });
    
    // 4. Wait for result with timeout
    match rx.recv_timeout(timeout) {
        Ok(span) => Ok(span),
        Err(mpsc::RecvTimeoutError::Timeout) => Err(RegexError::Timeout),
        Err(mpsc::RecvTimeoutError::Disconnected) => Err(RegexError::ThreadPanicked),
    }
}

/// Execute a regex with captures and timeout protection (used by B-flag)
/// 
/// # Returns
/// * `Ok(Some(captures))` - Vector of capture groups (index 0 = full match, 1+ = groups)
/// * `Ok(None)` - Pattern not found
pub fn regex_captures_with_timeout(
    pattern: &str,
    text: &str,
    timeout_secs: Option<u64>,
) -> Result<Option<Vec<Option<String>>>, RegexError> {
    let regex = RegexBuilder::new(pattern)
        .size_limit(REGEX_SIZE_LIMIT)
        .build()
        .map_err(|e| RegexError::InvalidPattern(e.to_string()))?;
    
    let (tx, rx) = mpsc::channel();
    let text_owned = text.to_string();
    let timeout = Duration::from_secs(timeout_secs.unwrap_or(DEFAULT_REGEX_TIMEOUT_SECS));
    
    thread::spawn(move || {
        let result = regex.captures(&text_owned).map(|caps| {
            // Convert captures to owned strings
            caps.iter()
                .map(|m| m.map(|m| m.as_str().to_string()))
                .collect::<Vec<_>>()
        });
        let _ = tx.send(result);
    });
    
    match rx.recv_timeout(timeout) {
        Ok(result) => Ok(result),
        Err(mpsc::RecvTimeoutError::Timeout) => Err(RegexError::Timeout),
        Err(mpsc::RecvTimeoutError::Disconnected) => Err(RegexError::ThreadPanicked),
    }
}
```

**Usage in QA code**:
```rust
// Finding a pattern
match regex_find_with_timeout(pattern, &segment.target.text_only(), None) {
    Ok(Some(span)) => {
        // Pattern found - use span.start/span.end for highlighting
        let matched_text = &text[span.start..span.end];
        // ...
    }
    Ok(None) => { /* Not found */ }
    Err(RegexError::Timeout) => {
        errors.push(QAError {
            error_type: QAErrorType::CustomScript,
            message: format!("Regex timed out after {}s: {}", DEFAULT_REGEX_TIMEOUT_SECS, pattern),
            ..Default::default()
        });
    }
    // ...
}

// With captures (B-flag)
match regex_captures_with_timeout(source_pattern, &source_text, None) {
    Ok(Some(captures)) => {
        // captures[0] = full match, captures[1] = first group, etc.
        if let Some(Some(captured_value)) = captures.get(1) {
            // Use captured_value for B-flag substitution
        }
    }
    // ...
}
```

**Error Handling in QA**:
```rust
match regex_with_timeout(pattern, text, Some(5)) {
    Ok(Some(m)) => { /* Pattern found */ }
    Ok(None) => { /* Pattern not found */ }
    Err(RegexError::Timeout) => {
        // Report as QA error, not crash
        errors.push(QAError {
            error_type: QAErrorType::CustomScript,
            message: format!("Regex timed out after 5s: {}", pattern),
            ..
        });
    }
    Err(RegexError::InvalidPattern(e)) => {
        errors.push(QAError {
            error_type: QAErrorType::CustomScript,
            message: format!("Invalid regex pattern: {}", e),
            ..
        });
    }
    Err(RegexError::ThreadPanicked) => {
        // Log and continue with other checks
        log::error!("Regex thread panicked for pattern: {}", pattern);
    }
}
```

**Guarantees**:
- UI unblocks after timeout (result discarded)
- Thread may continue briefly but will complete (no infinite loops due to size_limit)
- Memory bounded by size_limit
- Thread will be cleaned up when regex search completes (no persistent leak)

**NOT Guaranteed**:
- Immediate CPU release (thread runs to completion or size limit hit)

**Acceptable for this use case**: User gets responsive UI; background thread completes quickly due to size limits.

---

## Tauri 2 Storage API (Corrected)

### Profile Storage Location

**Tauri 2 API** (corrected from deprecated `tauri::api::path`):

```rust
use tauri::Manager;
use tauri::path::BaseDirectory;

// In a Tauri command
#[tauri::command]
fn get_profiles_dir(app: tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map_err(|e| e.to_string())
}

// Or using PathResolver
let app_data = app.path().resolve("profiles", BaseDirectory::AppData)?;
```

**Storage Paths**:
- Profiles: `<app_data>/profiles/*.json`
- Custom dictionaries: `<app_data>/dictionaries/custom.dic`
- Recent files: `<app_data>/recent_files.json`

**Capabilities** (in `src-tauri/capabilities/default.json`):

**CRITICAL: User-Chosen File Access Strategy**

The app must open user-chosen XLIFF/SDLXLIFF/MXLIFF files from arbitrary filesystem locations.
Tauri 2 uses capabilities + plugins to control file access.

**Strategy: Use `@tauri-apps/plugin-dialog` + `@tauri-apps/plugin-fs`**

1. User selects file via `open()` dialog → returns path with temporary permission
2. Read/write uses `@tauri-apps/plugin-fs` with that path
3. Permissions are scoped per-dialog-selection (not persisted across restarts)
4. For recent files: Re-prompt user to re-select if path no longer permitted

**Capability Configuration** (`src-tauri/capabilities/default.json`):
```json
{
  "identifier": "default",
  "description": "Default capability for Translation QA app",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "dialog:default",
    "dialog:allow-open",
    "dialog:allow-save",
    "fs:default",
    "fs:allow-read",
    "fs:allow-write",
    "fs:scope-read-recursive",
    "fs:scope-write-recursive"
  ]
}
```

**Plugin Configuration** (`src-tauri/Cargo.toml`):
```toml
[dependencies]
tauri-plugin-dialog = "2"
tauri-plugin-fs = "2"
```

**Plugin Registration** (`src-tauri/src/lib.rs`):
```rust
tauri::Builder::default()
    .plugin(tauri_plugin_dialog::init())
    .plugin(tauri_plugin_fs::init())
    // ...
```

### File I/O Architecture (CANONICAL - SINGLE SOURCE OF TRUTH)

**Decision: RUST HANDLES ALL FILE I/O**

The frontend ONLY handles dialog selection. All file reading, parsing, write-back, backup, and locking happens in Rust commands.

**Why Rust-side I/O**:
- File locking (`fs2`) only works reliably from Rust
- Backup `.bak` creation requires atomic operations
- Encoding detection and transcoding is Rust-only
- ParsedFile byte ranges must be consistent with what Rust reads
- Avoids double permission grants

**Frontend Usage Pattern**:
```typescript
import { open, save } from '@tauri-apps/plugin-dialog';
import { invoke } from '@tauri-apps/api/core';

// Step 1: User selects file via dialog (frontend)
const path = await open({
  filters: [{ name: 'XLIFF', extensions: ['xliff', 'xlf', 'sdlxliff', 'mxliff'] }]
});

// Step 2: Send path to Rust for reading + parsing (IPC)
if (path) {
  // Rust reads file bytes, parses, stores in managed state
  const fileData: FileData = await invoke('open_file', { path });
  // Frontend receives parsed segments, not raw bytes
}

// Step 3: Editing happens in frontend state (tokens modified)

// Step 4: Save via Rust command (IPC)
await invoke('save_file', { 
  fileId: fileData.id,
  // Token edits already sent via update_segment, or:
  // changes: [{ segment_id, new_target_tokens }]
});
// Rust handles: backup creation, byte patching, encoding, file locking, write
```

**Tauri Command Flow**:
```
Frontend                          Rust Backend
   │                                   │
   │ open() dialog                     │
   │ ─────────────────────────────────>│
   │ path: "/path/to/file.xliff"       │
   │                                   │
   │ invoke('open_file', { path })     │
   │ ─────────────────────────────────>│
   │                                   │  std::fs::read(path)
   │                                   │  detect_encoding()
   │                                   │  transcode_to_utf8()
   │                                   │  parse_xliff()
   │                                   │  store in ManagedState
   │ <─────────────────────────────────│
   │ FileData { id, segments, ... }    │
   │                                   │
   │ invoke('update_segment', { ... }) │
   │ ─────────────────────────────────>│
   │                                   │  update tokens in state
   │                                   │
   │ invoke('save_file', { fileId })   │
   │ ─────────────────────────────────>│
   │                                   │  try_lock_exclusive()
   │                                   │  create .bak backup
   │                                   │  apply_byte_patches()
   │                                   │  transcode_to_original()
   │                                   │  std::fs::write()
   │                                   │  unlock()
   │ <─────────────────────────────────│
   │ Ok(())                            │
```

**Recent Files & Permission Handling**:
- Rust stores recent file paths in `<app_data>/recent_files.json`
- When user clicks recent file: Frontend calls `invoke('open_file', { path })`
- If permission denied (Tauri scope expired): Rust returns error
- Frontend shows: "Please re-select this file" and opens dialog
- After re-selection, Rust reads with new permission scope

**What Happens on Restart**:
- Recent files list stores paths, but permissions are NOT persisted
- When user clicks recent file: We attempt to read it
- If permission denied: Show "Please re-select this file" dialog
- This is a Tauri 2 security feature, not a bug

**Alternative (if persistence needed later)**: Use `tauri-plugin-persisted-scope` to remember permissions.

---

## File Locking Strategy

### Cross-Platform Approach

**macOS/Linux**: Use `fs2` crate for advisory file locking
**Windows**: Use `fs2` crate (wraps Windows file locking)

```rust
use fs2::FileExt;
use std::fs::File;

fn try_lock_for_write(path: &Path) -> Result<File, LockError> {
    let file = File::options()
        .read(true)
        .write(true)
        .open(path)?;
    
    match file.try_lock_exclusive() {
        Ok(()) => Ok(file),
        Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
            Err(LockError::FileInUse)
        }
        Err(e) => Err(LockError::IoError(e)),
    }
}
```

**Testing** (Advisory Lock Compatible):

Since `fs2` uses advisory locks, testing with unrelated apps (TextEdit, Notepad) may not work. Instead:

1. **Self-Lock Test**: Create a helper binary or test that holds an exclusive lock:
   ```rust
   // In tests/lock_holder.rs
   fn main() {
       let file = File::open("test.xliff").unwrap();
       file.lock_exclusive().unwrap();
       println!("Holding lock. Press Enter to release.");
       std::io::stdin().read_line(&mut String::new()).unwrap();
   }
   ```

2. **Integration Test**:
   ```rust
   #[test]
   fn test_file_lock_detection() {
       let path = "fixtures/xliff/minimal_12.xliff";
       let file = File::open(path).unwrap();
       file.lock_exclusive().unwrap();
       
       // Attempt to save should fail
       let result = try_save_file(path, &changes);
       assert!(matches!(result, Err(SaveError::FileLocked)));
       
       file.unlock().unwrap();
   }
   ```

**Acceptance Criteria**:
- [ ] When same process holds exclusive lock, `try_lock_for_write` returns `Err(LockError::FileInUse)`
- [ ] When test helper holds lock, main app shows "file in use" error
- [ ] Lock released after successful save
- [ ] `cargo test parser::writer::lock` passes

---

## Performance Measurement Strategy

### Segment List Performance (Task 22)

**Measurement Method**:
1. Enable React DevTools Profiler
2. Load 5000-segment test file (create `fixtures/xliff/perf_5000.xliff` with script)
3. Record interaction: Scroll from top to bottom
4. Check: No render > 16ms, no "stalled" markers

**Automated Check** (in acceptance test):
```typescript
// In Vitest test
import { performance } from 'perf_hooks';

test('segment list scrolls 5K items performantly', async () => {
  const start = performance.now();
  // Simulate scroll to bottom
  await scrollToBottom();
  const elapsed = performance.now() - start;
  
  // Should complete within 500ms (generous for test environment)
  expect(elapsed).toBeLessThan(500);
});
```

**Fixture Generation Script** (create `scripts/generate_perf_fixture.js`):
```javascript
// Generates fixtures/xliff/perf_5000.xliff with 5000 segments
```

---

## Work Objectives

### Core Objective
Build a production-ready Tauri desktop app that performs translation QA with custom scripting, spell checking, and terminology verification for XLIFF-based files, matching Verifika's core functionality for daily professional use.

### Concrete Deliverables
- Tauri 2.x desktop app (macOS + Windows builds)
- XLIFF parser (SDLXLIFF, MXLIFF, standard XLIFF) with write-back
- 8 QA check engines (tags, numbers, punctuation, spelling, terminology, consistency, empty, forbidden)
- Custom QA scripting engine (CTWRP + B flag)
- Glossary parser (Excel, TBX, CSV)
- Hunspell integration (English + Korean)
- Tab-based multi-file UI
- In-app segment editing with undo/redo
- QA profiles (save/load)

### Definition of Done
- [ ] App opens SDLXLIFF from Trados 2019-2024 without error
- [ ] App opens Phrase MXLIFF without error
- [ ] Round-trip save preserves ALL XML structure (namespaces, whitespace, metadata)
- [ ] All 8 QA check types work correctly
- [ ] Custom regex scripts with B-flag cross-reference work
- [ ] Spell check works for English and Korean
- [ ] Terminology check works against Excel glossary
- [ ] Profiles save and load correctly
- [ ] Undo/redo works during editing
- [ ] Builds run on macOS and Windows

### Must Have
- XLIFF file parsing with full extension support
- Write-back without data loss
- All 8 QA check categories
- Full CTWRP + B-flag custom scripting
- Hunspell spell checking (EN + KO)
- Terminology checking (Excel, TBX, CSV)
- Tab-based multi-file UI
- Undo/redo for segment edits
- QA profiles (save/load)
- macOS + Windows builds

### Must NOT Have (Guardrails)
- Machine Translation features
- Translation Memory lookup/matching
- Cloud sync or backup features
- Batch folder processing (beyond tabs)
- Pretty-printed XML on save (breaks compatibility)
- Modified namespaces on write-back
- Report exports (Excel, HTML, PDF, JSON)
- Auto-fix without user confirmation per segment
- Linux builds (can add later)
- Web API spell check (Naver etc.)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: NO (new project)
- **User wants tests**: TDD recommended for QA engine
- **Framework**: Rust unit tests for backend, Vitest for frontend

### Test Commands (Concrete)

```bash
# After Task 1, these commands will exist:

# Run Rust unit tests
cd src-tauri && cargo test

# Run Rust tests with coverage
cd src-tauri && cargo tarpaulin --out Html

# Run frontend tests (Vitest)
npm test

# Run frontend tests with watch
npm run test:watch

# Type check frontend
npm run type-check

# Lint
npm run lint
```

**Package.json scripts** (defined in Task 1):
```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "test": "vitest run",
    "test:watch": "vitest",
    "type-check": "tsc --noEmit",
    "lint": "eslint src --ext .ts,.tsx",
    "tauri": "tauri"
  }
}
```

### Per-TODO Verification
Each TODO includes:
1. Rust unit tests for backend logic (`cargo test` must pass)
2. Manual verification with fixture files from `fixtures/`
3. Cross-platform check (macOS + Windows)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer (React)                       │
│  - Tab-based file management                                │
│  - Segment list with virtual scrolling                      │
│  - QA results panel                                         │
│  - Segment editor with undo/redo                            │
│  - Profile manager                                          │
│  - Custom script editor                                     │
└──────────────────────────┬──────────────────────────────────┘
                           │ Tauri IPC (invoke + Channel)
┌──────────────────────────▼──────────────────────────────────┐
│               Tauri Commands (Rust Backend)                 │
│  - File operations (open, save)                             │
│  - QA orchestration                                         │
│  - Profile management                                       │
│  - Progress streaming via Channel                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              File Parser Layer (Rust)                       │
│  - XLIFF 1.2/2.0 base parser                                │
│  - SDLXLIFF extension handler                               │
│  - MXLIFF extension handler                                 │
│  - Namespace preservation                                   │
│  - Write-back with whitespace preservation                  │
│  - Returns Segment abstraction                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                 QA Engine Layer (Rust)                      │
│  - TagsChecker                                              │
│  - NumbersChecker                                           │
│  - PunctuationChecker                                       │
│  - SpellChecker (Hunspell)                                  │
│  - TerminologyChecker                                       │
│  - ConsistencyChecker                                       │
│  - EmptyChecker                                             │
│  - ForbiddenChecker                                         │
│  - CustomScriptEngine (CTWRP + B-flag)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              Support Services (Rust)                        │
│  - GlossaryParser (Excel, TBX, CSV)                         │
│  - ProfileManager (JSON)                                    │
│  - DictionaryManager (Hunspell)                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Task Flow

```
Phase 1: Foundation
  1 → 2 → 3

Phase 2: File Parsing
  4 → 5 → 6 → 7

Phase 3: QA Engine Core
  8 → 9 → 10 → 11 → 12

Phase 4: Advanced QA
  13 → 14 → 15 → 16

Phase 5: Spell & Terminology
  17 → 18 → 19

Phase 6: UI Shell
  20 → 21 → 22 → 23

Phase 7: Integration
  24 → 25 → 26

Phase 8: Polish
  27 → 28 → 29 → 30
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 8, 9, 10, 11 | Independent QA checkers |
| B | 17, 18 | Spell check + Glossary parsing independent |
| C | 20, 21 | UI layout + Tab system independent |

| Task | Depends On | Reason |
|------|------------|--------|
| 5, 6, 7 | 4 | Need base XLIFF parser |
| 8-16 | 4-7 | Need parsed segments for QA |
| 19 | 17, 18 | Terminology needs spell check + glossary |
| 24 | 8-19 | Integration needs all QA engines |
| 25 | 20-23 | Integration needs UI shell |

---

## TODOs

### Phase 1: Foundation

- [ ] 1. Initialize Tauri 2.x Project

  **What to do**:
  - Create new Tauri 2.x project with React/Vite frontend
  - Configure for macOS + Windows builds
  - **Create stub files for all future task references** (enables path verification):
    ```
    translation-qa/                  # New repo root
    ├── src-tauri/
    │   ├── src/
    │   │   ├── main.rs             # Tauri entry point
    │   │   ├── lib.rs              # Library root
    │   │   ├── commands/
    │   │   │   └── mod.rs          # Stub
    │   │   ├── parser/
    │   │   │   ├── mod.rs          # Stub with XliffParser trait
    │   │   │   ├── xliff.rs        # Stub: "// TODO: Task 4 - XLIFF 1.2"
    │   │   │   ├── xliff2.rs       # Stub: "// TODO: Task 4 - XLIFF 2.0"
    │   │   │   ├── sdlxliff.rs     # Stub: "// TODO: Task 5"
    │   │   │   ├── mxliff.rs       # Stub: "// TODO: Task 6"
    │   │   │   └── writer.rs       # Stub: "// TODO: Task 7"
    │   │   ├── qa/
    │   │   │   ├── mod.rs          # Stub
    │   │   │   ├── tags_checker.rs       # Stub: "// TODO: Task 8"
    │   │   │   ├── numbers_checker.rs    # Stub: "// TODO: Task 9"
    │   │   │   ├── punctuation_checker.rs # Stub: "// TODO: Task 10"
    │   │   │   ├── empty_checker.rs      # Stub: "// TODO: Task 11"
    │   │   │   ├── forbidden_checker.rs  # Stub: "// TODO: Task 12"
    │   │   │   ├── consistency_checker.rs # Stub: "// TODO: Task 13"
    │   │   │   ├── custom_script.rs      # Stub: "// TODO: Task 14, 15"
    │   │   │   ├── spell_checker.rs      # Stub: "// TODO: Task 17"
    │   │   │   └── terminology_checker.rs # Stub: "// TODO: Task 19"
    │   │   ├── services/
    │   │   │   ├── mod.rs          # Stub
    │   │   │   ├── profile_manager.rs    # Stub: "// TODO: Task 16"
    │   │   │   └── glossary_parser.rs    # Stub: "// TODO: Task 18"
    │   │   └── types/
    │   │       └── mod.rs          # Stub: "// TODO: Task 2"
    │   ├── Cargo.toml
    │   ├── dictionaries/               # Bundled dictionaries (English only)
    │   │   ├── en_US.dic               # Downloaded in Task 17
    │   │   ├── en_US.aff
    │   │   └── README.md               # "Korean dictionary: user-provided, see docs"
    │   └── capabilities/
    │       └── default.json            # Tauri 2 capabilities config
    ├── src/
    │   ├── App.tsx
    │   ├── components/
    │   │   ├── Layout/             # Stub dirs for UI tasks
    │   │   ├── Tabs/
    │   │   ├── SegmentList/
    │   │   ├── SegmentEditor/
    │   │   ├── QAResults/
    │   │   ├── ScriptEditor/
    │   │   ├── ProfileManager/
    │   │   └── common/
    │   ├── hooks/
    │   │   ├── useQA.ts                    # Stub: "// TODO: Task 24"
    │   │   └── useKeyboardShortcuts.ts     # Stub: "// TODO: Task 28"
    │   └── types/
    │       └── index.ts            # Stub
    ├── fixtures/                    # Test fixtures
    │   ├── sdlxliff/
    │   │   └── README.md           # "Add .sdlxliff files here"
    │   ├── mxliff/
    │   │   └── README.md
    │   ├── xliff/
    │   │   └── README.md
    │   └── glossary/
    │       └── README.md
    ├── schemas/
    │   └── xliff-core-1.2-strict.xsd  # Vendored XLIFF schema
    ├── docs/
    │   ├── TESTING_CHECKLIST.md    # Manual CAT tool tests
    │   ├── GETTING_STARTED.md      # Stub: "// TODO: Task 30"
    │   ├── CUSTOM_SCRIPTS.md       # Stub: "// TODO: Task 30"
    │   └── KEYBOARD_SHORTCUTS.md   # Stub: "// TODO: Task 30"
    ├── scripts/
    │   ├── generate_perf_fixture.js    # Generates 5000-segment test file
    │   ├── bundle-hunspell-macos.sh    # Stub: "# TODO: Task 29"
    │   └── bundle-hunspell-windows.ps1 # Stub: "# TODO: Task 29"
    ├── .github/
    │   └── workflows/
    │       └── build.yml               # Stub: "# TODO: Task 29"
    ├── package.json
    ├── README.md
    └── LICENSE-THIRD-PARTY.txt         # Stub: "# TODO: Task 29 - Add bundled component licenses"
    ```
  - Add Rust dependencies: `quick-xml`, `serde`, `regex`, `tokio`, `encoding_rs`, `fs2` (file locking)
  - Add frontend dependencies: React, Zustand (state), TailwindCSS, `@tanstack/react-virtual` (virtual list - CHOSEN)
  - Configure Tauri capabilities for file system access
  - **Download and vendor XLIFF schema**:
    ```bash
    curl -o schemas/xliff-core-1.2-strict.xsd \
      https://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd
    ```
  - **Create minimal seed fixtures** (see "Test Fixtures Strategy" section):
    - `fixtures/xliff/minimal_12.xliff`:
      ```xml
      <?xml version="1.0" encoding="UTF-8"?>
      <xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
        <file original="test.txt" source-language="en" target-language="ko" datatype="plaintext">
          <body>
            <trans-unit id="1">
              <source>Hello world</source>
              <target>안녕하세요</target>
            </trans-unit>
            <trans-unit id="2">
              <source>Click <g id="1">here</g> to continue</source>
              <target>계속하려면 <g id="1">여기</g>를 클릭하세요</target>
            </trans-unit>
          </body>
        </file>
      </xliff>
      ```
    - Similar minimal files for SDLXLIFF, MXLIFF (with appropriate namespaces)

  **Must NOT do**:
  - Add unnecessary dependencies
  - Over-engineer folder structure

  **Parallelizable**: NO (foundation)

  **References**:
  - Tauri 2.x docs: https://v2.tauri.app/start/create-project/
  - Tauri IPC: https://v2.tauri.app/develop/calling-rust/
  - @tanstack/react-virtual: https://tanstack.com/virtual/latest

  **Acceptance Criteria**:
  
  **macOS (primary dev platform)**:
  - [ ] `npm run tauri dev` launches app window on macOS
  - [ ] `npm run tauri build` produces macOS .dmg
  
  **Windows (CI verification)**:
  - [ ] GitHub Actions workflow (`build.yml`) runs successfully on `windows-latest`
  - [ ] OR: Local Windows build `npm run tauri build` produces .msi or .exe installer
  
  **Cross-platform**:
  - [ ] Basic "Hello from Tauri" command works (returns string from Rust)
  - [ ] File system permission configured in capabilities (`src-tauri/capabilities/default.json`)
  - [ ] All stub files exist at paths referenced by later tasks (see Reference Map)
  - [ ] `schemas/xliff-core-1.2-strict.xsd` exists (vendored)
  - [ ] `fixtures/` directory structure exists with minimal seed fixtures
  - [ ] `fixtures/xliff/minimal_12.xliff` and `minimal_20.xliff` exist with valid content
  - [ ] `fixtures/xliff/minimal_empty_target.xliff` exists with self-closing, missing, and empty-expanded target variants
  - [ ] `scripts/generate_perf_fixture.js` exists and generates 5000-segment file

  **Commit**: YES
  - Message: `feat(init): initialize Tauri 2.x project with stub files for all modules`
  - Files: entire project structure

---

- [ ] 2. Define Core Data Types

  **What to do**:
  - **CANONICAL SOURCE**: Copy ALL type definitions exactly from the "Complete Type Definitions" section of this plan. That section is the single source of truth.
  - Implement in `src-tauri/src/types/mod.rs`:
    - All enums: `SegmentState`, `QAErrorType`, `TagKind`, `SearchMode`, `Encoding`
    - All structs: `TextRange`, `InlineElement`, `SegmentContent`, `Segment`, `QAError`, `CheckConfig`, `CustomScript`, `ScriptFlags`, `QAProfile`, `LocaleConfig`, `FileData`, `QAProgress`
  - **CRITICAL fields for write-back** (must be included):
    - `SegmentContent.uses_cdata: bool` - tracks if original used CDATA
    - `SegmentContent.original_attributes: String` - captures original `<target>` attributes
    - `InlineElement.original_xml: String` - preserves exact original XML for round-trip
  - Implement serde serialization for IPC
  - Add TypeScript type definitions that mirror Rust types (see "TypeScript Equivalents" in Complete Type Definitions section)

  **Must NOT do**:
  - Invent your own type definitions (use the canonical ones in this plan)
  - Add file format-specific details to core types
  - Couple types to specific parsers

  **Parallelizable**: NO (depends on 1)

  **References**:
  - **CANONICAL**: "Complete Type Definitions" section of this plan (scroll up)
  - Rust serde: https://serde.rs/

  **Acceptance Criteria**:
  - [ ] All types from "Complete Type Definitions" section are implemented
  - [ ] `SegmentContent` includes `uses_cdata`, `original_attributes` fields
  - [ ] `InlineElement` includes `original_xml` field
  - [ ] All types compile without warnings
  - [ ] Types serialize/deserialize correctly (unit test: serialize → deserialize → compare)
  - [ ] TypeScript types match Rust types exactly

  **Commit**: YES
  - Message: `feat(types): define core data types for segments, QA errors, profiles`
  - Files: `src-tauri/src/types/`

---

- [ ] 3. Set Up Tauri Command Infrastructure

  **What to do**:
  - Create command module structure:
    ```rust
    #[tauri::command]
    async fn open_file(path: String) -> Result<FileData, String>;
    
    #[tauri::command]
    async fn save_file(path: String, data: FileData) -> Result<(), String>;
    
    #[tauri::command]
    async fn run_qa(file_id: String, profile: QAProfile, channel: Channel<QAProgress>) -> Result<Vec<QAError>, String>;
    ```
  - Set up Channel for QA progress streaming
  - Create error handling pattern (custom AppError type)
  - Set up managed state for open files (`Mutex<HashMap<String, FileData>>`)

  **Must NOT do**:
  - Implement actual file parsing (just structure)
  - Add all commands at once (just core ones)

  **Parallelizable**: NO (depends on 2)

  **References**:
  - Tauri commands: https://v2.tauri.app/develop/calling-rust/
  - Tauri Channel: https://v2.tauri.app/develop/calling-rust/#channels

  **Acceptance Criteria**:
  - [ ] Commands register and can be invoked from frontend
  - [ ] Channel sends progress updates to frontend
  - [ ] State management works (add/remove file from map)
  - [ ] Error handling returns proper Result types

  **Commit**: YES
  - Message: `feat(commands): set up Tauri command infrastructure with Channel streaming`
  - Files: `src-tauri/src/commands/`

---

### Phase 2: File Parsing

- [ ] 4. Implement XLIFF Parsers (1.2 and 2.0)

  **What to do**:
  
  **Part A: XLIFF 1.2 Parser**
  - Parse XLIFF 1.2 structure using `quick-xml`
  - Handle core elements: `<xliff>`, `<file>`, `<body>`, `<trans-unit>`, `<source>`, `<target>`
  - Parse inline elements: `<g>`, `<x/>`, `<bx/>`, `<ex/>`, `<ph>`, `<bpt>`, `<ept>`
  - **Namespace preservation**: Use basic `Reader` (not `NsReader`); treat namespace-prefixed elements as literal bytes. Since we only patch `<target>` content via byte splicing, all xmlns declarations and prefixed elements are automatically preserved without explicit handling.
  - Preserve whitespace: Set `reader.trim_text(false)` to keep all whitespace
  - Store original XML structure for write-back
  - **UTF-16 handling**: Use `encoding_rs` crate to detect and transcode:
    ```rust
    // Cargo.toml dependency
    encoding_rs = "0.8"
    
    // Detection and transcoding
    fn load_xliff(path: &Path) -> Result<(String, Encoding)> {
        let bytes = std::fs::read(path)?;
        let (encoding, had_bom) = detect_encoding(&bytes);
        let utf8_content = transcode_to_utf8(&bytes, encoding)?;
        Ok((utf8_content, encoding))
    }
    ```
  
  **Byte Range Capture (CRITICAL for write-back)**:
  During parsing, capture these byte positions in the UTF-8 working buffer:
  
  1. **Target element byte range** (`target_start_byte`, `target_end_byte`):
     - `target_start_byte`: Position of `<` in `<target...>`
     - `target_end_byte`: Position after `>` in `</target>`
     - Captured using `reader.buffer_position()` at `Event::Start`/`Event::End`
  
  2. **Target attributes** (`original_attributes`):
     - At `Event::Start(e)` for `<target>`, extract raw attribute bytes:
       ```rust
       let attrs_raw = &working_bytes[target_start_byte..];
       // Find end of opening tag '>'
       // Extract attribute portion as string
       // Store in SegmentContent.original_attributes
       ```
     - Example: `<target xml:lang="ko" state="translated">` → store `xml:lang="ko" state="translated"`
  
  3. **CDATA detection**:
     - On `Event::CData`, set `uses_cdata = true` in `SegmentContent`
  
  4. **Whitespace between elements** (for insertion):
     - After `</source>`, capture bytes until next non-whitespace
     - Store as `source_end_byte` for insertion point when `<target>` is missing
     - When inserting new `<target>`, replicate the whitespace pattern from source
  
  **See**: "Byte Range Capture with quick-xml" section for full implementation code

  **Must NOT do**:
  - Handle SDLXLIFF or MXLIFF extensions (separate tasks)
  - Pretty-print or normalize XML
  - Strip whitespace

  **Parallelizable**: NO (foundation for 5, 6, 7)

  **References**:
  - XLIFF 1.2 spec: https://docs.oasis-open.org/xliff/v1.2/os/xliff-core.html
  - quick-xml docs: https://docs.rs/quick-xml/latest/quick_xml/
  - encoding_rs: https://docs.rs/encoding_rs/latest/encoding_rs/

  **Part B: XLIFF 2.0 Parser** (see "XLIFF 2.0 Handling Strategy" section)
  - Detect XLIFF 2.0 via `version="2.0"` attribute
  - Parse `<unit>` → `<segment>` → `<source>`/`<target>` structure
  - Map 2.0 inline elements (`<pc>`, `<ph>`, `<sc>`, `<ec>`) to common InlineElement enum
  - Store byte ranges for write-back

  **Acceptance Criteria (XLIFF 1.2)**:
  - [ ] Parses valid XLIFF 1.2 file into Segment structs
  - [ ] Preserves all inline elements with IDs
  - [ ] Round-trip: parse → modify segment text → write = valid XLIFF
  - [ ] Preserves unknown namespaces
  - [ ] Unit tests with `fixtures/xliff/minimal_12.xliff`
  - [ ] UTF-8 files parse directly
  - [ ] UTF-16 files detected via BOM/declaration and transcoded before parsing
  - [ ] `cargo test parser::xliff` passes

  **Acceptance Criteria (XLIFF 2.0)**:
  - [ ] Parses `fixtures/xliff/minimal_20.xliff` into Segment structs
  - [ ] Extracts segments from `<unit>/<segment>` structure
  - [ ] Maps 2.0 inline elements correctly
  - [ ] Round-trip preserves structure
  - [ ] `cargo test parser::xliff2` passes

  **Commit**: YES
  - Message: `feat(parser): implement XLIFF 1.2 and 2.0 parsers with round-trip support`
  - Files: `src-tauri/src/parser/xliff.rs`, `src-tauri/src/parser/xliff2.rs`

---

- [ ] 5. Implement SDLXLIFF Extension Handler

  **What to do**:
  - Detect SDLXLIFF via `sdl:` namespace
  - Parse SDL-specific elements:
    - `<sdl:seg-defs>` and `<sdl:seg>` for segment metadata
    - `@conf` (confirmation level), `@locked`, `@percent`, `@origin`
  - Map SDL segment status to our SegmentState enum
  - Handle SDL internal file data (`<internal-file>`)
  - Preserve ALL SDL extensions on write-back

  **Must NOT do**:
  - Modify SDL metadata
  - Drop unknown SDL attributes

  **Parallelizable**: NO (depends on 4)

  **References**:
  - SDLXLIFF structure (based on XLIFF 1.2 with SDL namespace):
    ```xml
    <!-- Key SDL extensions to handle -->
    <sdl:seg-defs>
      <sdl:seg id="1" conf="Translated" locked="false" percent="100" origin="tm"/>
    </sdl:seg-defs>
    
    <!-- Namespace declaration -->
    xmlns:sdl="http://sdl.com/FileTypes/SdlXliff/1.0"
    ```
  - Fixture files: `fixtures/sdlxliff/*.sdlxliff`

  **Acceptance Criteria**:
  - [ ] Parses `fixtures/sdlxliff/minimal_basic.sdlxliff` without error
  - [ ] Parses `fixtures/sdlxliff/minimal_locked.sdlxliff` and extracts locked status
  - [ ] Parses `fixtures/sdlxliff/minimal_namespaces.sdlxliff` and preserves extra namespaces
  - [ ] Extracts segment status (locked, match%, confirmation)
  - [ ] Round-trip: `diff original.sdlxliff modified.sdlxliff` shows only target changes
  - [ ] Schema validation passes: `xmllint --schema schemas/xliff-core-1.2-strict.xsd minimal_basic.sdlxliff`
  - [ ] `cargo test parser::sdlxliff` passes
  - [ ] (Optional) Manual verification with user-provided fixtures documented in `docs/TESTING_CHECKLIST.md`

  **Commit**: YES
  - Message: `feat(parser): add SDLXLIFF extension handler with metadata extraction`
  - Files: `src-tauri/src/parser/sdlxliff.rs`

---

- [ ] 6. Implement MXLIFF Extension Handler

  **What to do**:
  - Detect Phrase MXLIFF format
  - Handle join tags `{j}` in segment content
  - Parse `mda:` namespace metadata
  - Preserve join tag integrity on write-back
  - Handle Phrase-specific segment states

  **Must NOT do**:
  - Remove or modify `{j}` join markers
  - Drop Phrase-specific metadata

  **Parallelizable**: NO (depends on 4)

  **References**:
  - MXLIFF join tag structure:
    ```xml
    <!-- Joined segments use {j} marker -->
    <source>First sentence.{j}Second sentence.</source>
    <target>Première phrase.{j}Deuxième phrase.</target>
    
    <!-- mda namespace for metadata -->
    xmlns:mda="urn:oasis:names:tc:xliff:metadata:2.0"
    ```
  - Fixture files: `fixtures/mxliff/*.mxliff`

  **Acceptance Criteria**:
  - [ ] Parses `fixtures/mxliff/minimal_basic.mxliff` without error
  - [ ] Parses `fixtures/mxliff/minimal_joined.mxliff` and preserves `{j}` markers
  - [ ] Count of `{j}` in output equals count in input
  - [ ] Round-trip: `diff original.mxliff modified.mxliff` shows only target changes
  - [ ] `cargo test parser::mxliff` passes
  - [ ] (Optional) Manual verification with user-provided fixtures documented in `docs/TESTING_CHECKLIST.md`

  **Commit**: YES
  - Message: `feat(parser): add MXLIFF extension handler for Phrase files`
  - Files: `src-tauri/src/parser/mxliff.rs`

---

- [ ] 7. Implement File Write-Back System

  **What to do**:
  - Write modified segments back to original XML structure
  - Preserve:
    - All namespaces (exactly as original)
    - Whitespace and formatting
    - Comments
    - Processing instructions
    - Attribute order (where possible)
  - Create backup before write (`.bak` file in same directory)
  - Handle file locking (detect if file is open elsewhere via try-lock)
  - **Use byte-patching strategy** (see "Write-Back Strategy" section above)
  - **Encoding preservation**: If original was UTF-16, transcode back from UTF-8:
    ```rust
    fn save_xliff(path: &Path, content: &str, original_encoding: Encoding) -> Result<()> {
        let bytes = match original_encoding {
            Encoding::Utf16Le => transcode_to_utf16le(content),
            Encoding::Utf16Be => transcode_to_utf16be(content),
            Encoding::Utf8 => content.as_bytes().to_vec(),
        };
        std::fs::write(path, bytes)?;
        Ok(())
    }
    ```

  **Must NOT do**:
  - Pretty-print output
  - Reorder attributes
  - Normalize whitespace
  - Modify anything outside changed segments

  **Parallelizable**: NO (depends on 4, 5, 6)

  **IMPLEMENTATION CLARIFICATION**:
  This task uses **byte-patching**, NOT `quick-xml::Writer` for reserialization.
  
  - **DO use**: `Vec<u8>` byte splicing with stored byte ranges from parsing
  - **DO NOT use**: `quick_xml::Writer` to reserialize the document (destroys formatting)
  
  The `quick-xml writer docs` reference below is for understanding what we're avoiding, not for implementation guidance.
  See "Write-Back Strategy (CRITICAL)" and "Byte Range Capture with quick-xml" sections for the actual algorithm.

  **References**:
  - **PRIMARY**: "Write-Back Strategy (CRITICAL)" section of this plan
  - **PRIMARY**: "Byte Range Capture with quick-xml" section for capture implementation
  - quick-xml writer docs (for reference only, NOT used): https://docs.rs/quick-xml/latest/quick_xml/writer/struct.Writer.html
  - encoding_rs for encoding conversion

  **Acceptance Criteria**:
  
  **For UTF-8 files**:
  - [ ] `diff -u original.xliff written.xliff` shows only `<target>` content changes
  - [ ] Backup `.bak` file created before write
  - [ ] Namespace count in output equals input: `grep -c 'xmlns' original.xliff` == `grep -c 'xmlns' written.xliff`
  
  **For UTF-16 files** (CRITICAL - binary diff not human-readable):
  - [ ] **BOM preserved**: `xxd fixtures/xliff/minimal_utf16.xliff | head -1` shows `ff fe` (UTF-16LE BOM)
  - [ ] After write: `xxd written_utf16.xliff | head -1` still shows `ff fe`
  - [ ] **Transcode-then-diff verification**:
    ```bash
    # Convert both to UTF-8 for comparison
    iconv -f UTF-16LE -t UTF-8 original_utf16.xliff > /tmp/orig_as_utf8.xliff
    iconv -f UTF-16LE -t UTF-8 written_utf16.xliff > /tmp/written_as_utf8.xliff
    # Now diff is human-readable
    diff -u /tmp/orig_as_utf8.xliff /tmp/written_as_utf8.xliff
    # Expected: Only <target> content differs
    ```
  - [ ] Unit test `parser::writer::test_utf16_roundtrip`:
    1. Load `fixtures/xliff/minimal_utf16.xliff`
    2. Modify a target segment
    3. Save
    4. Verify first 2 bytes are `0xFF 0xFE` (UTF-16LE BOM)
    5. Transcode to UTF-8 and parse again
    6. Verify only modified segment changed
  
  **Common**:
  - [ ] Error message shown when file is locked by another process (test with `fs2` self-lock)
  - [ ] `cargo test parser::writer` passes (all tests including UTF-16)

  **Commit**: YES
  - Message: `feat(parser): implement write-back with namespace and whitespace preservation`
  - Files: `src-tauri/src/parser/writer.rs`

---

### Phase 3: QA Engine Core

- [ ] 8. Implement Tags QA Checker

  **What to do**:
  - Check for missing tags in target (source has tag, target doesn't)
  - Check for extra tags in target
  - Check tag ID consistency
  - Check tag order (configurable: strict or relaxed)
  - Handle paired tags (`<bx>`/`<ex>`, `<bpt>`/`<ept>`) - verify pairs match
  - Report tag-related errors with specific tag IDs

  **Must NOT do**:
  - Auto-fix tag issues
  - Check tag content (just structure)

  **Parallelizable**: YES (with 9, 10, 11)

  **References**:
  - Behavioral spec: See "QA Checker Behavioral Examples > Tags Checker" section above
  - XLIFF inline elements: https://docs.oasis-open.org/xliff/v1.2/os/xliff-core.html#Struct_InLine

  **Acceptance Criteria (Fixture-Based)**:
  
  **Test fixture**: `fixtures/xliff/qa_test_tags.xliff` (created in Task 8)
  
  | Segment ID | Source | Target | Expected Error |
  |------------|--------|--------|----------------|
  | 1 | `Click <g id="1">here</g>` | `Cliquez ici` | `MissingTag { id: "1" }` |
  | 2 | `Press <x id="1"/> button` | `Appuyez <x id="1"/> <x id="2"/>` | `ExtraTag { id: "2" }` |
  | 3 | `<g id="1">A</g><g id="2">B</g>` | `<g id="2">B</g><g id="1">A</g>` | `TagOrderMismatch` (if strict_order=true) |
  | 4 | `<bx id="1"/>text<ex id="1"/>` | `<bx id="1"/>text` | `UnpairedTag { id: "1", kind: "bx without ex" }` |
  | 5 | `Click <g id="1">here</g>` | `Cliquez <g id="1">ici</g>` | (no error) |
  
  **Unit test**: `cargo test qa::tags_checker::test_all_scenarios`
  - [ ] Test passes with fixture above
  - [ ] Each error includes segment_id, error_type, and tag id in message

  **Commit**: YES
  - Message: `feat(qa): implement tags QA checker with pair validation`
  - Files: `src-tauri/src/qa/tags_checker.rs`

---

- [ ] 9. Implement Numbers QA Checker

  **What to do**:
  - Detect numbers in source and verify presence in target
  - Handle locale-specific formatting:
    - Decimal separators (1,000.00 vs 1.000,00)
    - Percentage formats (50% vs 50 %)
  - Check number order consistency (configurable)
  - Handle ranges (10-20, 10–20)
  - Configurable tolerance for formatting differences

  **Must NOT do**:
  - Validate number values (just presence)
  - Handle dates (different complexity)

  **Parallelizable**: YES (with 8, 10, 11)

  **References**:
  - Behavioral spec: See "QA Checker Behavioral Examples > Numbers Checker" section above
  - Locale config: Use simplified config from profile (see "Implementation Decisions > Locale Number Formatting")

  **Acceptance Criteria (Fixture-Based)**:
  
  | Segment ID | Source | Target | Locale | Expected Error |
  |------------|--------|--------|--------|----------------|
  | 1 | `Total: $1,234.56` | `Total: $1,234.56` | en-US | (no error) |
  | 2 | `Page 5 of 10` | `Page 5 sur` | any | `MissingNumber { value: "10" }` |
  | 3 | `50%` | `50 %` | fr-FR | (no error - French allows space) |
  | 4 | `50%` | `50 %` | en-US | `NumberFormatMismatch { expected: "50%", found: "50 %" }` |
  | 5 | `Range: 10-20` | `Plage: 10–20` | any | (no error - en-dash acceptable) |
  | 6 | `1.000,50` | `1,000.50` | de-DE→en-US | (no error - locale conversion) |
  
  **Unit test**: `cargo test qa::numbers_checker::test_locale_scenarios`
  - [ ] Test passes with scenarios above
  - [ ] Locale config from profile is respected

  **Commit**: YES
  - Message: `feat(qa): implement numbers QA checker with locale support`
  - Files: `src-tauri/src/qa/numbers_checker.rs`

---

- [ ] 10. Implement Punctuation QA Checker

  **What to do**:
  - Check end punctuation consistency (. vs .)
  - Check bracket matching ((), [], {})
  - Check quotation mark matching ("", '', «»)
  - Detect double spaces
  - Detect double punctuation
  - Check spaces around punctuation (configurable per locale)
  - Handle multiple punctuation styles per locale

  **Must NOT do**:
  - Auto-fix punctuation
  - Handle CJK punctuation (later enhancement)

  **Parallelizable**: YES (with 8, 9, 11)

  **References**:
  - Behavioral spec: See "QA Checker Behavioral Examples > Punctuation Checker" section above
  - Punctuation rules configurable per locale in profile settings

  **Acceptance Criteria (Fixture-Based)**:
  
  | Segment ID | Source | Target | Expected Error |
  |------------|--------|--------|----------------|
  | 1 | `Hello world.` | `Bonjour monde` | `PunctuationMismatch { expected: ".", found: "" }` |
  | 2 | `Open (file) now` | `Ouvrir (fichier maintenant` | `UnmatchedBracket { char: "(" }` |
  | 3 | `Say "hello"` | `Dire "bonjour` | `UnmatchedQuote { char: '"' }` |
  | 4 | `Double  space` | `Double  espace` | `DoubleSpace { position: 7 }` |
  | 5 | `Question?` | `Question?` | (no error) |
  | 6 | `List:` | `Liste :` | (no error if French locale allows colon space) |
  
  **Unit test**: `cargo test qa::punctuation_checker::test_scenarios`
  - [ ] Test passes with scenarios above
  - [ ] Double space detection includes character position

  **Commit**: YES
  - Message: `feat(qa): implement punctuation QA checker with bracket/quote matching`
  - Files: `src-tauri/src/qa/punctuation_checker.rs`

---

- [ ] 11. Implement Empty Segment Checker

  **What to do**:
  - Detect empty target (source has content, target is empty)
  - Detect same source and target (potential untranslated)
  - Detect partial translation (target much shorter than source)
  - Configurable thresholds for "partial"
  - Option to skip locked segments

  **Must NOT do**:
  - Flag legitimate "same" translations (proper nouns, etc.)
  - Check segment status (handled separately)

  **Parallelizable**: YES (with 8, 9, 10)

  **References**:
  - Empty = target is empty or whitespace-only when source has content
  - Identical = source text equals target text (potential untranslated)

  **Acceptance Criteria (Fixture-Based)**:
  
  | Segment ID | Source | Target | locked | Expected Error |
  |------------|--------|--------|--------|----------------|
  | 1 | `Hello world` | `` | false | `EmptyTarget` |
  | 2 | `Hello world` | `Hello world` | false | `IdenticalSourceTarget` |
  | 3 | `This is a longer sentence with content` | `Short` | false | `PartialTranslation { ratio: 0.13 }` (if threshold=0.3) |
  | 4 | `Locked text` | `` | true | (no error if skip_locked=true) |
  | 5 | `OK` | `OK` | false | (no error - short identical is acceptable) |
  
  **Unit test**: `cargo test qa::empty_checker::test_scenarios`
  - [ ] Test passes with scenarios above
  - [ ] Threshold from profile settings is respected

  **Commit**: YES
  - Message: `feat(qa): implement empty/omission segment checker`
  - Files: `src-tauri/src/qa/empty_checker.rs`

---

- [ ] 12. Implement Forbidden Words Checker

  **What to do**:
  - Load forbidden word list (from profile)
  - Check target for forbidden words
  - Support case-sensitive and case-insensitive modes
  - Support whole-word matching
  - Option to ignore if source also contains forbidden word
  - Report word and position in segment

  **Must NOT do**:
  - Regex support (that's custom scripting)
  - Auto-fix

  **Parallelizable**: YES (after 8-11 done)

  **References**:
  - Forbidden words defined in profile as JSON array: `["TBD", "TODO", "FIXME"]`
  - Each word checked against target text with configurable case/whole-word options

  **Acceptance Criteria (Fixture-Based)**:
  
  Forbidden words list: `["TBD", "TODO", "testing"]`
  
  | Segment ID | Source | Target | Settings | Expected Error |
  |------------|--------|--------|----------|----------------|
  | 1 | `Feature A` | `TBD feature` | default | `ForbiddenWord { word: "TBD", position: 0 }` |
  | 2 | `Feature B` | `tbd feature` | case_sensitive=false | `ForbiddenWord { word: "TBD" }` |
  | 3 | `Feature C` | `tbd feature` | case_sensitive=true | (no error - case mismatch) |
  | 4 | `Testing needed` | `Testing nécessaire` | ignore_if_in_source=true | (no error - "Testing" in source) |
  | 5 | `Feature D` | `Atesting feature` | whole_words=true | (no error - not whole word) |
  | 6 | `Feature E` | `A testing feature` | whole_words=true | `ForbiddenWord { word: "testing" }` |
  
  **Unit test**: `cargo test qa::forbidden_checker::test_scenarios`
  - [ ] Test passes with scenarios above
  - [ ] Position in error points to start of forbidden word in target

  **Commit**: YES
  - Message: `feat(qa): implement forbidden words checker`
  - Files: `src-tauri/src/qa/forbidden_checker.rs`

---

### Phase 4: Advanced QA

- [ ] 13. Implement Consistency Checker

  **What to do**:
  - Build source→target mapping across all segments
  - Detect target inconsistency (same source → different targets)
  - Detect source inconsistency (different sources → same target)
  - Options:
    - Ignore case
    - Ignore punctuation
    - Ignore numbers
    - Ignore leading/trailing spaces
  - Group inconsistent segments for review

  **Must NOT do**:
  - Auto-select "correct" translation
  - Consider segment status for consistency

  **Parallelizable**: NO (needs all segments)

  **References**:
  - Target inconsistency: Build HashMap<SourceText, Vec<TargetText>>, flag where Vec.len() > 1
  - Source inconsistency: Build HashMap<TargetText, Vec<SourceText>>, flag where Vec.len() > 1

  **Acceptance Criteria (Fixture-Based)**:
  
  **Multi-segment test file**: 
  | Segment ID | Source | Target |
  |------------|--------|--------|
  | 1 | `Hello` | `Bonjour` |
  | 2 | `Hello` | `Salut` |
  | 3 | `Goodbye` | `Bonjour` |
  | 4 | `Hello.` | `Bonjour.` |
  
  **Expected errors**:
  - `TargetInconsistency { source: "Hello", targets: ["Bonjour", "Salut"], segment_ids: [1, 2] }`
  - `SourceInconsistency { target: "Bonjour", sources: ["Hello", "Goodbye"], segment_ids: [1, 3] }`
  
  **With ignore_punctuation=true**:
  - Segment 1 and 4 have same source ("Hello" == "Hello.") → additional inconsistency if targets differ
  
  **Unit test**: `cargo test qa::consistency_checker::test_scenarios`
  - [ ] Target inconsistency detected (same source, different targets)
  - [ ] Source inconsistency detected (different sources, same target)
  - [ ] ignore_case, ignore_punctuation, ignore_numbers settings work
  - [ ] Result groups related segment IDs together

  **Commit**: YES
  - Message: `feat(qa): implement consistency checker for source/target variations`
  - Files: `src-tauri/src/qa/consistency_checker.rs`

---

- [ ] 14. Implement Custom Script Engine - CTWRP Flags

  **What to do**:
  - Implement search parameter system:
    - **C**: Case-sensitive matching
    - **T**: Search within inline tags (not just text)
    - **W**: Whole words only
    - **R**: Regular expression mode
    - **P**: Power search (Boolean logic: AND, OR, AND NOT)
  - Implement search modes:
    1. Source AND target found
    2. Source found, target NOT found
    3. Target found, source NOT found
    4. Different count in source vs target
  - Use Rust `regex` crate with timeout protection
  - Validate regex before execution
  - Parse Boolean expressions for Power search

  **Must NOT do**:
  - Implement B-flag yet (separate task)
  - Allow infinite regex execution

  **Parallelizable**: NO (depends on 8-12)

  **References**:
  - Behavioral spec: See "CTWRP + B-Flag Behavior Specification" section above
  - Rust regex crate: https://docs.rs/regex/latest/regex/
  - Timeout: Use `regex::RegexBuilder::size_limit()` and wrap in timeout

  **Acceptance Criteria**:
  - [ ] All CTWRP flags work correctly
  - [ ] All 4 search modes work
  - [ ] Regex times out after configurable seconds (default 5s)
  - [ ] Invalid regex returns clear error
  - [ ] Boolean expressions parse correctly
  - [ ] Unit tests for each flag and mode combination

  **Commit**: YES
  - Message: `feat(qa): implement custom script engine with CTWRP flags`
  - Files: `src-tauri/src/qa/custom_script.rs`

---

- [ ] 15. Implement Custom Script Engine - B-Flag (Cross-Segment)

  **What to do**:
  - Implement B-flag: capture group in source, reference in target
  - Example: source pattern `(\d{3})` captures "123", target pattern `\1` must find "123"
  - Support multiple capture groups (\1, \2, etc.)
  - Handle case where source capture doesn't exist
  - Combine with existing CTWRP flags
  
  **CRITICAL IMPLEMENTATION DETAIL**:
  The `\1`, `\2`, etc. in target patterns are **NOT regex backreferences** (Rust `regex` crate doesn't support them).
  They are **placeholder tokens** that get **substituted with captured values BEFORE** the target pattern is compiled.
  
  **Execution model** (from "B-Flag Execution Model" section):
  1. Run source pattern with captures: `(\d{3}-\d{4})` on "Order #123-4567"
  2. Extract captured text: `captures[1] = "123-4567"`
  3. Substitute `\1` in target pattern with **regex-escaped literal**: `"123-4567"` → `"123\\-4567"`
  4. Compile resulting target pattern (now literal, not a backreference)
  5. Search target text for the resolved pattern
  
  **Example**:
  - Source pattern: `Order #(\d+)`
  - Target pattern: `#\1`
  - Source text: "Order #12345 confirmed"
  - Step 1: Match → `captures[1] = "12345"`
  - Step 2: Substitute → target pattern becomes `#12345`
  - Step 3: Search target for `#12345` → found → PASS

  **Must NOT do**:
  - Named capture groups (keep it simple like Verifika)
  - Capture groups across segments (within single segment only)
  - Use Rust regex backreferences (not supported)

  **Parallelizable**: NO (depends on 14)

  **References**:
  - Behavioral spec: See "B-Flag Execution Model (CRITICAL)" section above for full algorithm
  - Rust regex capture groups: https://docs.rs/regex/latest/regex/struct.Captures.html
  - `regex::escape()` for escaping captured values: https://docs.rs/regex/latest/regex/fn.escape.html

  **Acceptance Criteria**:
  - [ ] Single capture group: Source `(\d+)`, Target `\1`, Source="ID: 123", Target="ID: 123" → PASS
  - [ ] Single capture group fail: Source `(\d+)`, Target `\1`, Source="ID: 123", Target="ID: 456" → ERROR reported
  - [ ] Multiple capture groups: Source `(\d+)-(\w+)`, Target `\2-\1`, Source="123-ABC", Target="ABC-123" → PASS
  - [ ] Missing group: Target `\3` when source only has 2 groups → clear error message
  - [ ] Special chars escaped: Source `(.+)` captures "a.b*c" → target search looks for literal "a.b*c", not regex
  - [ ] Works with C flag: Case-sensitive matching respected
  - [ ] `cargo test qa::custom_script::b_flag` passes

  **Commit**: YES
  - Message: `feat(qa): implement B-flag cross-segment back-reference in custom scripts`
  - Files: `src-tauri/src/qa/custom_script.rs` (extend)

---

- [ ] 16. Implement QA Profile System

  **What to do**:
  - Define profile schema (JSON) - **MUST match canonical types exactly**:
    ```json
    {
      "name": "Client A",
      "checks": {
        "tags": { 
          "enabled": true, 
          "settings": { "strict_order": false, "check_paired": true }
        },
        "numbers": { 
          "enabled": true, 
          "settings": { "check_order": false }
        },
        "punctuation": {
          "enabled": true,
          "settings": { "check_end": true, "check_brackets": true, "check_quotes": true, "check_double_space": true }
        },
        "empty": {
          "enabled": true,
          "settings": { "check_identical": true, "partial_threshold": 0.3, "skip_locked": true }
        },
        "forbidden": {
          "enabled": true,
          "settings": { "case_sensitive": false, "whole_words": true, "ignore_if_in_source": false }
        },
        "consistency": {
          "enabled": true,
          "settings": { "ignore_case": true, "ignore_punctuation": true, "ignore_numbers": false }
        },
        "spelling": {
          "enabled": true,
          "settings": { "dictionaries": ["en_US", "ko_KR"], "skip_tags": true }
        },
        "terminology": {
          "enabled": true,
          "settings": { "case_sensitive": false, "whole_words": true, "check_reverse": false }
        }
      },
      "forbidden_words": ["TBD", "TODO"],
      "custom_scripts": [
        { 
          "name": "Check X", 
          "source_pattern": "pattern", 
          "target_pattern": "pattern", 
          "flags": {
            "case_sensitive": true,
            "include_tags": false,
            "whole_words": false,
            "regex": true,
            "power_search": false,
            "back_reference": true
          },
          "search_mode": "SourceNotTarget"
        }
      ],
      "glossary_paths": ["/path/to/glossary.xlsx"],
      "locale_config": {
        "decimal_separator": ".",
        "thousands_separator": ",",
        "percent_space": false
      }
    }
    ```
    
  **Per-Check Settings Schema** (canonical reference):
  
  | Check | Setting Key | Type | Default | Description |
  |-------|-------------|------|---------|-------------|
  | **tags** | `strict_order` | bool | false | Require same tag order in source/target |
  | **tags** | `check_paired` | bool | true | Verify bx/ex, bpt/ept pairs match |
  | **numbers** | `check_order` | bool | false | Require same number order |
  | **punctuation** | `check_end` | bool | true | Check ending punctuation matches |
  | **punctuation** | `check_brackets` | bool | true | Verify bracket pairing |
  | **punctuation** | `check_quotes` | bool | true | Verify quote pairing |
  | **punctuation** | `check_double_space` | bool | true | Flag double spaces |
  | **empty** | `check_identical` | bool | true | Flag source==target |
  | **empty** | `partial_threshold` | f32 | 0.3 | Target/source length ratio to flag |
  | **empty** | `skip_locked` | bool | true | Don't flag locked segments |
  | **forbidden** | `case_sensitive` | bool | false | Case-sensitive matching |
  | **forbidden** | `whole_words` | bool | true | Match whole words only |
  | **forbidden** | `ignore_if_in_source` | bool | false | Skip if word in source too |
  | **consistency** | `ignore_case` | bool | true | Ignore case when comparing |
  | **consistency** | `ignore_punctuation` | bool | true | Ignore punctuation |
  | **consistency** | `ignore_numbers` | bool | false | Ignore numbers |
  | **spelling** | `dictionaries` | string[] | ["en_US"] | Dictionary IDs to use |
  | **spelling** | `skip_tags` | bool | true | Don't spell-check tag content |
  | **terminology** | `case_sensitive` | bool | false | Case-sensitive term matching |
  | **terminology** | `whole_words` | bool | true | Match whole words |
  | **terminology** | `check_reverse` | bool | false | Also check target→source |
  - Save profiles to app data directory
  - Load profiles at startup
  - Export/import profiles (for sharing between machines)
  - Default profile with sensible settings

  **Must NOT do**:
  - Cloud sync
  - Profile sharing via network

  **Parallelizable**: NO (needs QA checks defined)

  **References**:
  - Tauri 2 storage API: See "Tauri 2 Storage API (Corrected)" section above
  - Profile schema defined in "What to do" section above

  **Acceptance Criteria**:
  - [ ] Profiles save to app data directory
  - [ ] Profiles load on app start
  - [ ] Export profile to JSON file
  - [ ] Import profile from JSON file
  - [ ] Default profile created on first run
  - [ ] Profile selection persists between sessions

  **Commit**: YES
  - Message: `feat(profile): implement QA profile save/load/export/import`
  - Files: `src-tauri/src/services/profile_manager.rs`

---

### Phase 5: Spell & Terminology

- [ ] 17. Integrate Hunspell Spell Checker

  **What to do** (ALIGNS WITH OPTION B: User-Provided Korean Dictionary):
  
  **English dictionaries (BUNDLED)**:
  - Integrate Hunspell via `hunspell-rs` crate (CHOSEN, see "Implementation Decisions")
  - Bundle in `src-tauri/dictionaries/`:
    - `en_US.dic`, `en_US.aff` (from LibreOffice dictionaries, MPL 2.0)
    - `en_GB.dic`, `en_GB.aff` (from LibreOffice dictionaries, MPL 2.0)
  - Configure Tauri to bundle:
    ```json
    // tauri.conf.json
    "resources": ["dictionaries/*"]
    ```
  
  **Korean dictionary (USER-PROVIDED, NOT BUNDLED)**:
  - On first Korean spell check attempt, check `<app_data>/dictionaries/ko_KR.dic`
  - If not found, show dialog:
    ```
    Korean Spell Check Setup
    
    Korean spell check requires dictionary files that are not bundled
    due to licensing (GPL-3.0).
    
    To enable Korean:
    1. Download from: https://github.com/spellcheck-ko/hunspell-dict-ko/releases
    2. Extract ko_KR.dic and ko_KR.aff
    3. Click "Select Dictionary Files" below
    
    [Select Dictionary Files] [Skip Korean]
    ```
  - When user selects: Copy to `<app_data>/dictionaries/`
  - Test load with Hunspell and verify `hs.check("안녕하세요")` returns true
  - If Hunspell version < 1.7.0, warn: "Korean may not work correctly - Hunspell 1.7.0+ recommended"
  - Persist dictionary availability in app state
  
  **Common functionality**:
  - Custom dictionary support (add/remove words) at `<app_data>/dictionaries/custom.dic`
  - Skip content inside inline tags (use `SegmentContent.text_only()`)
  - Handle mixed language segments: spell check target only

  **Must NOT do**:
  - Bundle `ko_KR.dic` (GPL-3.0 license, user must provide)
  - Grammar checking
  - Web API integration
  - Auto-correct

  **Parallelizable**: YES (with 18)

  **References**:
  - hunspell-rs crate: https://docs.rs/hunspell-rs/latest/hunspell_rs/
  - LibreOffice dictionaries: https://github.com/LibreOffice/dictionaries
  - hunspell-dict-ko: https://github.com/spellcheck-ko/hunspell-dict-ko

  **Acceptance Criteria**:
  
  **English (out-of-box)**:
  - [ ] `en_US.dic` bundled in app resources
  - [ ] "hello" = correct, "helo" = misspelled with suggestion "hello"
  - [ ] Test words verified: "computer", "keyboard"
  
  **Korean (user-provided flow)**:
  - [ ] On fresh install with no Korean dict: "Korean spell check" option shows "Setup Required"
  - [ ] Click "Setup Required" → dialog appears with download instructions
  - [ ] After user provides ko_KR.dic: dialog closes, Korean spell check becomes available
  - [ ] "안녕하세요" = correct, "안녕하세욯" = misspelled
  - [ ] Dictionary persists: Restart app → Korean still available without re-setup
  
  **Common**:
  - [ ] Custom words: Add "MyProduct" → no longer flagged
  - [ ] Custom dictionary persists across restarts
  - [ ] Content inside `<g id="1">text</g>` tags: Only "text" checked, not tag markup
  - [ ] Error reports include: word, segment ID, character position in target

  **Commit**: YES
  - Message: `feat(spell): integrate Hunspell with English and Korean dictionaries`
  - Files: `src-tauri/src/qa/spell_checker.rs`

---

- [ ] 18. Implement Glossary Parser

  **What to do**:
  - Parse glossary formats:
    - Excel (XLSX) - using `calamine` crate
    - TBX (TermBase eXchange) - XML parsing
    - CSV/TSV - standard parsing
  - Map columns to: source term, target term, forbidden terms
  - Support multiple target columns (for variants)
  - Handle language codes in headers
  - Load multiple glossaries simultaneously

  **Must NOT do**:
  - SDLTB (user will export to TBX/Excel)
  - Glossary editing (just loading)

  **Parallelizable**: YES (with 17)

  **References**:
  - TBX spec: https://www.tbxinfo.net/
  - calamine crate: https://docs.rs/calamine/latest/calamine/
  - Fixture files: `fixtures/glossary/*.{xlsx,tbx,csv}`

  **Acceptance Criteria (Fixture-Based)**:
  
  **Excel (`fixtures/glossary/minimal.xlsx`)**:
  - [ ] Column detection: `en` col=0, `ko` col=1, `forbidden` col=2, `notes` col=3
  - [ ] Term count: 5 terms extracted
  - [ ] First term: source="computer", target="컴퓨터", forbidden=["콤퓨터", "컴퓨타"]
  - [ ] Third term: source="file", target="파일", forbidden=["화일"]
  
  **TBX (`fixtures/glossary/minimal.tbx`)**:
  - [ ] Term count: 2 terms extracted (based on fixture content)
  - [ ] First term: source="computer", target="컴퓨터"
  - [ ] Handles `xml:lang` attributes correctly
  
  **CSV (`fixtures/glossary/minimal.csv`)**:
  - [ ] Parses comma-separated values
  - [ ] Handles quoted values with embedded commas in forbidden column
  - [ ] Term count: 5 terms extracted
  - [ ] Forbidden parsing: "콤퓨터,컴퓨타" split into ["콤퓨터", "컴퓨타"]
  
  **In-Memory Glossary Structure** (used by Task 19):
  ```rust
  pub struct Glossary {
      pub terms: Vec<GlossaryTerm>,
  }
  
  pub struct GlossaryTerm {
      pub source: String,           // e.g., "computer"
      pub target: String,           // e.g., "컴퓨터"
      pub forbidden: Vec<String>,   // e.g., ["콤퓨터", "컴퓨타"]
      pub notes: Option<String>,    // e.g., "Standard translation"
  }
  ```
  
  **Common**:
  - [ ] Multiple glossaries: Load 2+ glossaries, merge into single term list
  - [ ] Duplicate handling: Same source term in multiple files → keep all entries
  - [ ] Clear error on parse failure: "Failed to parse glossary.xlsx: Invalid column format"
  - [ ] Unit test: `cargo test services::glossary_parser::test_all_formats`

  **Commit**: YES
  - Message: `feat(glossary): implement parser for Excel, TBX, and CSV formats`
  - Files: `src-tauri/src/services/glossary_parser.rs`

---

- [ ] 19. Implement Terminology Checker

  **What to do**:
  - Check if source term exists → target translation should exist
  - Check for forbidden target terms
  - Support whole-word and case-sensitive options
  - Reverse check: target term without source term
  - Handle term variants (word forms)
  - Report: source term, expected target, actual target

  **Must NOT do**:
  - Fuzzy matching (exact or word forms only)
  - Auto-fix terminology

  **Parallelizable**: NO (depends on 18)

  **References**:
  - Algorithm: For each segment, check if any glossary source term appears in source text;
    if yes, verify corresponding target term appears in target text

  **Acceptance Criteria**:
  - [ ] Detects missing term translation
  - [ ] Detects forbidden term usage
  - [ ] Reverse check works
  - [ ] Case-sensitive/insensitive modes work
  - [ ] Whole-word mode works
  - [ ] Reports expected vs actual clearly

  **Commit**: YES
  - Message: `feat(qa): implement terminology checker with glossary integration`
  - Files: `src-tauri/src/qa/terminology_checker.rs`

---

### Phase 6: UI Shell

- [ ] 20. Implement Main Layout and Navigation

  **What to do**:
  - Create main layout:
    - Header with app title, profile selector
    - Sidebar with file list (tabs)
    - Main content area (segments)
    - Bottom panel (QA results)
  - Implement keyboard navigation
  - Support system dark/light mode
  - Responsive layout (resizable panels)

  **Must NOT do**:
  - Implement actual functionality (just layout)
  - Custom theming (use system)

  **Parallelizable**: YES (with 21)

  **References**:
  - TailwindCSS docs: https://tailwindcss.com/docs/flex (layout)
  - TailwindCSS dark mode: https://tailwindcss.com/docs/dark-mode
  - Panel resizing: Use CSS `resize` or custom drag implementation (no library needed)
  - Zustand for persisting panel sizes: https://docs.pmnd.rs/zustand/integrations/persisting-store-data

  **Acceptance Criteria**:
  - [ ] Layout renders: All 4 regions visible (header, sidebar, main, bottom) with no overlapping elements
  - [ ] Panels resizable: Drag divider between main/bottom changes heights; persists across page refresh
  - [ ] Dark mode: Toggle system appearance (macOS: System Preferences → Appearance); app background color changes within 1 second
  - [ ] Keyboard shortcuts: Press `Ctrl+O` (Windows) / `Cmd+O` (macOS) → file dialog opens; press `Escape` → dialog closes

  **Commit**: YES
  - Message: `feat(ui): implement main layout with resizable panels`
  - Files: `src/components/Layout/`

---

- [ ] 21. Implement Tab-Based File Management

  **What to do**:
  - Tab bar for open files
  - Open file dialog (filter for .sdlxliff, .mxliff, .xliff, .xlf)
  - Close tab (with unsaved changes warning)
  - Tab reordering
  - Show modified indicator (*)
  - Recent files list

  **Must NOT do**:
  - Drag-drop file open (later)
  - Multiple windows

  **Parallelizable**: YES (with 20)

  **References**:
  - Tauri file dialog plugin: https://v2.tauri.app/plugin/dialog/
  - Tab pattern: See "UI Reference Map > Tab Component Pattern" in this plan
  - Recent files: Store in Zustand with `persist` middleware

  **Acceptance Criteria**:
  - [ ] Open file via dialog
  - [ ] Multiple files in tabs
  - [ ] Close tab with unsaved warning
  - [ ] Modified indicator shows
  - [ ] Recent files persist

  **Commit**: YES
  - Message: `feat(ui): implement tab-based file management with recent files`
  - Files: `src/components/Tabs/`

---

- [ ] 22. Implement Segment List View

  **What to do**:
  - Virtual scrolling for large segment lists (5K+ segments)
  - Segment row shows: ID, source, target, status icon, error count
  - Click to select segment
  - Filter by: has errors, empty, locked, status
  - Search within segments
  - Keyboard navigation (up/down, enter to edit)

  **Must NOT do**:
  - Inline editing (separate view)
  - Multi-select

  **Parallelizable**: NO (depends on 20)

  **References**:
  - @tanstack/react-virtual (CHOSEN): https://tanstack.com/virtual/latest/docs/framework/react/react-virtual

  **Acceptance Criteria**:
  - [ ] Renders 5K segments: Load `fixtures/xliff/perf_5000.xliff`, scroll top-to-bottom in <2s, no frame drops visible
  - [ ] Performance measurement: Open React DevTools Profiler → record scroll → verify no render >16ms
  - [ ] Scroll position: Select segment #2500 → switch to another tab → switch back → segment #2500 still visible
  - [ ] Filter by error: Run QA → click "Show errors only" → segment list shows only segments with errors (count matches QA error count)
  - [ ] Search: Type "hello" in search box → only segments containing "hello" in source OR target shown
  - [ ] Keyboard nav: Click segment list → press Arrow Down 3 times → selection moves down 3 rows; press Enter → segment editor opens

  **Commit**: YES
  - Message: `feat(ui): implement segment list with virtual scrolling and filtering`
  - Files: `src/components/SegmentList/`

---

- [ ] 23. Implement Segment Editor

  **What to do**:
  - Edit target text (not source)
  - Show inline tags visually (colored badges)
  - Tags are not editable (read-only visual)
  - Undo/redo (Ctrl+Z, Ctrl+Shift+Z)
  - Save changes (Ctrl+S saves file)
  - Navigate to next/previous segment (Ctrl+Arrow)
  - Show QA errors for current segment

  **Must NOT do**:
  - Edit source text
  - Rich text editing (just plain text + tag display)
  - Tag manipulation

  **Parallelizable**: NO (depends on 22)

  **References**:
  - **CHOSEN**: textarea (NOT contenteditable) - see "UI Reference Map > Segment Editor Pattern"
  - Rationale: ContentEditable has IME issues with Korean input and unpredictable undo behavior
  - Undo/redo: Custom history stack in component state (see pattern in UI Reference Map)

  **Acceptance Criteria**:
  - [ ] Edit target text
  - [ ] Tags display but can't be edited
  - [ ] Undo/redo works (10+ levels)
  - [ ] Save hotkey works
  - [ ] Navigate next/prev segment
  - [ ] QA errors show for selected segment

  **Commit**: YES
  - Message: `feat(ui): implement segment editor with undo/redo and tag display`
  - Files: `src/components/SegmentEditor/`

---

### Phase 7: Integration

- [ ] 24. Connect QA Engine to Frontend

  **What to do**:
  - Wire up `run_qa` command to UI
  - Show progress during QA (via Channel)
  - Display results in bottom panel:
    - Error list grouped by type
    - Click error to jump to segment
    - Show error count per type
  - Persist QA results while file is open
  - Clear results on file reload

  **Must NOT do**:
  - Auto-fix from results panel
  - Export results

  **Parallelizable**: NO (depends on all QA)

  **References**:
  - Tauri Channel for progress
  - React state management

  **Acceptance Criteria**:
  - [ ] QA runs and shows progress
  - [ ] Results display grouped by type
  - [ ] Click error navigates to segment
  - [ ] Results persist during session
  - [ ] Counts shown correctly

  **Commit**: YES
  - Message: `feat(integration): connect QA engine to frontend with progress streaming`
  - Files: `src/components/QAResults/`, `src/hooks/useQA.ts`

---

- [ ] 25. Implement Custom Script UI

  **What to do**:
  - Script editor panel:
    - Name field
    - Source pattern field
    - Target pattern field
    - Flags checkboxes (C, T, W, R, P, B)
    - Search mode dropdown
  - Test script against current file (preview results)
  - Add/edit/delete scripts in profile
  - Regex syntax highlighting (optional)

  **Must NOT do**:
  - Script sharing
  - Script import from Verifika format

  **Parallelizable**: NO (depends on 24)

  **References**:
  - Script structure defined in Profile schema (Task 16)
  - UI provides form fields for each CTWRP flag + search mode dropdown

  **Acceptance Criteria**:
  - [ ] Create new script
  - [ ] Edit existing script
  - [ ] Delete script
  - [ ] Test script shows preview results
  - [ ] Scripts save to profile
  - [ ] All flags work in UI

  **Commit**: YES
  - Message: `feat(ui): implement custom script editor with test preview`
  - Files: `src/components/ScriptEditor/`

---

- [ ] 26. Implement Profile Management UI

  **What to do**:
  - Profile dropdown in header
  - Create new profile
  - Duplicate profile
  - Delete profile (except last one)
  - Rename profile
  - Settings panel for profile options:
    - Enable/disable checks
    - Check-specific settings
    - Forbidden words list editor
    - Glossary file paths
  - Export/import buttons

  **Must NOT do**:
  - Profile sharing via cloud

  **Parallelizable**: NO (depends on 24, 25)

  **References**:
  - Tauri file save dialog for export

  **Acceptance Criteria**:
  - [ ] Create/duplicate/delete/rename profile
  - [ ] Settings UI for all check options
  - [ ] Forbidden words editable
  - [ ] Glossary paths configurable
  - [ ] Export profile to file
  - [ ] Import profile from file

  **Commit**: YES
  - Message: `feat(ui): implement profile management with settings panel`
  - Files: `src/components/ProfileManager/`

---

### Phase 8: Polish

- [ ] 27. Implement Error Handling and Feedback

  **What to do**:
  - User-friendly error messages (not stack traces)
  - Toast notifications for actions (saved, error, etc.)
  - Loading states during operations
  - File parsing error recovery (show what we could parse)
  - Confirm dialog before destructive actions

  **Must NOT do**:
  - Error reporting to server

  **Parallelizable**: YES (with 28)

  **References**:
  - **CHOSEN**: Sonner toast library - https://sonner.emilkowal.ski/
  - See "UI Reference Map > Toast Pattern" for usage examples
  - Dialog for confirmations: @radix-ui/react-dialog - https://www.radix-ui.com/primitives/docs/components/dialog

  **Acceptance Criteria**:
  - [ ] User-friendly errors: Open a corrupted/invalid XML file → error message says "File parsing failed: [specific issue]" (not raw stack trace)
  - [ ] Toast for save: Save file → green toast "File saved successfully" appears for 3 seconds; Save with permission error → red toast with error message
  - [ ] Loading spinner: Run QA on 5K segment file → spinner visible during QA; spinner disappears when QA complete
  - [ ] Partial recovery: Open XLIFF with 10 segments where segment #7 has invalid XML → segments 1-6 load; error banner says "Partial load: 6 of 10 segments (error at segment 7)"
  - [ ] Unsaved close: Edit segment → click X to close tab → dialog "You have unsaved changes. Save before closing?" with Save/Discard/Cancel buttons

  **Commit**: YES
  - Message: `feat(ui): implement error handling with toasts and confirmations`
  - Files: `src/components/common/`

---

- [ ] 28. Keyboard Shortcuts and Accessibility

  **What to do**:
  - Define keyboard shortcuts (platform-aware):
    
    | Action | Windows/Linux | macOS |
    |--------|---------------|-------|
    | Open file | Ctrl+O | Cmd+O |
    | Save file | Ctrl+S | Cmd+S |
    | Close tab | Ctrl+W | Cmd+W |
    | Run QA | F5 | F5 |
    | Go to segment | Ctrl+G | Cmd+G |
    | Find in segments | Ctrl+F | Cmd+F |
    | Undo | Ctrl+Z | Cmd+Z |
    | Redo | Ctrl+Shift+Z | Cmd+Shift+Z |
    | Close dialog | Escape | Escape |
    
  - **Platform detection**: Use `navigator.platform` or Tauri's `os` module to determine modifier key
  - Show shortcuts in menus (with platform-appropriate modifier)
  - Keyboard-navigable UI (Tab, Arrow keys)
  - Screen reader basics (labels, roles)

  **Must NOT do**:
  - Customizable shortcuts (later)

  **Parallelizable**: YES (with 27)

  **References**:
  - Tauri menus: https://v2.tauri.app/learn/window-customization/#menus
  - Keyboard shortcut hook: See "UI Reference Map > Keyboard Shortcuts Pattern"
  - Platform detection: `navigator.platform.toUpperCase().indexOf('MAC') >= 0`
  - ARIA guidance: https://www.w3.org/WAI/ARIA/apg/patterns/

  **Acceptance Criteria**:
  - [ ] All shortcuts work
  - [ ] Shortcuts shown in menus
  - [ ] Tab navigation works
  - [ ] Dialogs trap focus
  - [ ] ARIA labels on interactive elements

  **Commit**: YES
  - Message: `feat(ui): implement keyboard shortcuts and accessibility`
  - Files: `src/hooks/useKeyboardShortcuts.ts`

---

- [ ] 29. Build and Package for macOS + Windows

  **What to do**:
  - Configure Tauri for production build
  - macOS: .dmg installer, code signing (if certificate available)
  - Windows: .msi installer
  - Bundle Hunspell dictionaries
  - App icons
  - Test on both platforms

  **Must NOT do**:
  - Auto-update (later)
  - Microsoft Store / Mac App Store

  **Parallelizable**: NO (final)

  **References**:
  - Tauri bundler config: https://v2.tauri.app/reference/config/
  - macOS signing: https://v2.tauri.app/distribute/sign-macos/
  - Windows MSI: https://v2.tauri.app/distribute/windows-installer/
  - Resources bundling: https://v2.tauri.app/develop/resources/
  - Hunspell packaging: See "Hunspell Cross-Platform Packaging" section in this plan

  **Acceptance Criteria** (aligns with "Option B: User-Provided Korean Dictionary" decision):
  
  **macOS build**:
  - [ ] `npm run tauri build` on macOS produces `src-tauri/target/release/bundle/macos/TranslationQA.app`
  - [ ] Run `scripts/bundle-hunspell-macos.sh` successfully
  - [ ] `.app/Contents/Frameworks/libhunspell-1.7.dylib` exists
  - [ ] `.app/Contents/Resources/dictionaries/en_US.dic` and `en_US.aff` exist
  - [ ] `.app/Contents/Resources/dictionaries/ko_KR.dic` does NOT exist (user-provided)
  - [ ] Create DMG: `hdiutil create -volname TranslationQA -srcfolder TranslationQA.app TranslationQA.dmg`
  - [ ] DMG installs to /Applications and app launches
  
  **Windows build**:
  - [ ] `npm run tauri build` on Windows produces MSI/EXE installer
  - [ ] Run `scripts/bundle-hunspell-windows.ps1` successfully
  - [ ] `hunspell.dll` bundled in install directory
  - [ ] `dictionaries/en_US.dic` and `en_US.aff` bundled
  - [ ] `dictionaries/ko_KR.dic` does NOT exist in bundle (user-provided)
  - [ ] Installer runs on fresh Windows 10/11 system
  
  **Licensing**:
  - [ ] `LICENSE-THIRD-PARTY.txt` includes: 
    - LibreOffice English dictionaries (MPL 2.0)
    - Hunspell library license
    - TailwindCSS, Zustand, and other npm dependencies
  - [ ] `LICENSE-THIRD-PARTY.txt` does NOT include GPL-licensed Korean dictionary (not bundled)
  
  **Common**:
  - [ ] App icon displays correctly in dock/taskbar
  - [ ] First launch: Korean spell check shows "dictionary needed" dialog (not crash)

  **Commit**: YES
  - Message: `chore(build): configure production builds for macOS and Windows`
  - Files: `src-tauri/tauri.conf.json`, icons/

---

- [ ] 30. End-to-End Testing and Documentation

  **What to do**:
  - End-to-end test flow:
    1. Open SDLXLIFF file
    2. Run QA with all checks
    3. Navigate to error
    4. Edit segment
    5. Undo edit
    6. Save file
    7. Verify file opens in Trados
  - Same for MXLIFF
  - Write user documentation:
    - Getting started
    - Feature overview
    - Custom script guide
    - Keyboard shortcuts
  - Fix any bugs found

  **Must NOT do**:
  - Automated E2E tests (manual for now)
  - Video tutorials

  **Parallelizable**: NO (final)

  **References**:
  - Fixture files in `fixtures/` directory
  - Manual CAT tool verification documented in `docs/TESTING_CHECKLIST.md`

  **Acceptance Criteria**:
  
  **E2E SDLXLIFF flow** (manual test with real Trados file):
  - [ ] Open: User-provided SDLXLIFF from Trados → loads without error, segment count matches Trados
  - [ ] QA: Run all QA checks → results appear in bottom panel within 30s for 1000 segments
  - [ ] Navigate: Click error → segment scrolls into view and highlights
  - [ ] Edit: Modify target text → segment shows (*) modified indicator
  - [ ] Undo: Press Ctrl+Z → edit reverts to original text
  - [ ] Save: Press Ctrl+S → file saves, (*) indicator disappears
  - [ ] Verify: Open saved file in Trados 2024 → no warnings, segment content matches edits
  
  **E2E MXLIFF flow** (manual test with real Phrase file):
  - [ ] Open: User-provided MXLIFF → loads without error
  - [ ] Save+Verify: After edit, open in Phrase → imports successfully with edits preserved
  
  **E2E standard XLIFF flow**:
  - [ ] Open `fixtures/xliff/minimal_12.xliff` → loads without error
  - [ ] Round-trip: Edit → Save → `diff` shows only target changes
  
  **Documentation**:
  - [ ] `docs/GETTING_STARTED.md` exists with: installation steps, first-time setup, opening first file
  - [ ] `docs/CUSTOM_SCRIPTS.md` exists with: CTWRP flags explained, B-flag example, common patterns
  - [ ] `docs/KEYBOARD_SHORTCUTS.md` exists listing all shortcuts
  
  **Bug status**:
  - [ ] All bugs logged during E2E testing are fixed OR documented as "known issues" with workarounds

  **Commit**: YES
  - Message: `docs: add user documentation and complete E2E testing`
  - Files: `docs/`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | feat(init): initialize Tauri 2.x project | all | `npm run tauri dev` works |
| 4 | feat(parser): XLIFF 1.2 parser | parser/ | unit tests pass |
| 7 | feat(parser): write-back | parser/ | round-trip test |
| 12 | feat(qa): all core checkers | qa/ | unit tests pass |
| 16 | feat(profile): profiles | services/ | save/load test |
| 19 | feat(qa): terminology | qa/ | glossary test |
| 23 | feat(ui): editor | components/ | manual test |
| 26 | feat(integration): complete | all | QA runs E2E |
| 30 | docs: documentation | docs/ | manual review |

---

## Success Criteria

### Verification Commands
```bash
# Build check
npm run tauri build

# Rust tests
cd src-tauri && cargo test

# Frontend tests
npm test
```

### Final Checklist
- [ ] Opens SDLXLIFF from Trados 2019-2024
- [ ] Opens Phrase MXLIFF
- [ ] Opens standard XLIFF 1.2/2.0
- [ ] All 8 QA check types work
- [ ] Custom scripts with CTWRP + B-flag work
- [ ] Spell check works (English + Korean)
- [ ] Terminology check works with Excel glossary
- [ ] Profiles save/load/export/import
- [ ] Multi-file tabs work
- [ ] Undo/redo works
- [ ] Round-trip save preserves all XML
- [ ] macOS build works
- [ ] Windows build works
- [ ] No TM/MT features (guardrail)
- [ ] No cloud features (guardrail)
- [ ] No pretty-printed XML (guardrail)
