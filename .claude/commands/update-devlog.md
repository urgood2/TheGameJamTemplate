# Update Devlog

Automatically update the devlog with entries from unrecorded git commits.

## Instructions

1. **Read the devlog file** at `docs/project-management/todos/TODO_devlog.md`

2. **Parse the last recorded date** by scanning for date patterns like:
   - `MM/DD/YYYY` (e.g., `12/10/2025`)
   - `- MM/DD/YYYY`
   - `MM/DD - MM/DD/YYYY` (date ranges)

   Extract the most recent date found.

3. **Fetch commits since that date** using:
   ```bash
   git log --since="YYYY-MM-DD" --format="%H|%ad|%s" --date=short --no-merges
   ```

4. **For each commit**, get the diff summary:
   ```bash
   git show <hash> --stat
   ```
   For commits with vague messages (like "f", "fix", "wip"), also read the full diff to understand changes.

5. **Group commits by date** and for each date:
   - Analyze the commit messages and diffs
   - Write 2-5 narrative bullet points summarizing the work
   - Match the existing devlog style:
     - Past tense ("Added", "Fixed", "Implemented")
     - Concise single-line bullets
     - Technical but readable
     - Group related changes into single bullets

6. **Append new entries** to the devlog file in chronological order:
   ```
   MM/DD/YYYY
     - First bullet point describing work done
     - Second bullet point
   ```

7. **Auto-commit the changes**:
   ```bash
   git add docs/project-management/todos/TODO_devlog.md
   git commit -m "docs: update devlog through MM/DD/YYYY"
   ```

## Edge Cases

- **No new commits**: Report "Devlog is up to date" and exit without changes
- **Empty devlog**: Start from 30 days ago
- **Merge commits**: Already filtered out via `--no-merges`
- **Vague commit messages**: Rely on diff analysis to understand changes

## Output

Report what dates were added and how many bullet points were generated.
