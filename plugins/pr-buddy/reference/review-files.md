# Review files

What `check` keeps in `.review/`: a report per branch, holding the open findings, and one waivers file per clone, holding the findings the user dropped. Both are for the user and for other agents to read and act on, and both are always in English, whatever language the conversation uses.

## Paths

- **Report:** `.review/branch-{branch}.md` in the current worktree, with every `/` in the branch name replaced by `-`, online and offline alike. A PR/MR shows up in the report's header, never in its name, so the report stays the same file when a PR/MR opens for the branch.
- **Waivers:** `.review/waivers.md` in the main worktree, shared by every branch and worktree of the clone. `git rev-parse --path-format=absolute --git-common-dir` prints the main worktree's `.git`; its parent is the main worktree. When that path does not end in `.git` (a bare repository), use the current worktree and tell the user the waivers are not shared.

## Ignored first

Both files may only land where git ignores them: `git -C <worktree> check-ignore -q .review/<file>` succeeds for each. When it fails, offer the user two scopes and wait:

- **every repository on the machine:** `<file>` is what `git config --global core.excludesFile` prints, or `~/.config/git/ignore` when it prints nothing, and `<directory>` is the directory holding it;
- **this clone only:** `<file>` is what `git rev-parse --git-path info/exclude` prints, and its directory already exists.

Give each command in both shells, each on one line, and say which is which. Fill in `<file>` and `<directory>` as absolute paths with `~` already expanded to the home directory: the commands quote them, and a quoted `~` stays a literal `~`.

- **bash** (a Linux or macOS terminal, Git Bash, or the `!` prefix in a Claude Code session): `mkdir -p "<directory>" && echo .review/ >> "<file>"`;
- **PowerShell** (a Windows terminal): `New-Item -ItemType Directory -Force "<directory>" | Out-Null; Add-Content "<file>" ".review/"`.

For this clone only, the directory part drops out: `echo .review/ >> "<file>"` and `Add-Content "<file>" ".review/"`.

`.gitignore`, `.git/info/exclude` and git config are the user's to change.

## Report

```markdown
# Review: <PR owner/repo#22: title | MR group/project!22: title | branch feature/login>

- Branch: feature/login → main
- Head: <full HEAD SHA>[ plus uncommitted changes]
- Last checked: 2026-10-24 14:05
- Last updated: 2026-10-24 14:05
- Next number: 4

## Findings

1. **blocking** · unpushed · `src/Foo.java:42`
   What is wrong and why it matters.
   Fix: the suggested solution.

3. **non-blocking** · `src/Bar.java:10` · raised by jdoe
   What is wrong and why it matters.
   Lowered from blocking: the user's reason.
   Fix: needs a decision: option one, or option two.

## Untested, let go

- PDF export: a test would compare rendered files.
```

`## Untested, let go` holds one line per feature left without a test on purpose, with the reason, per [reviewing](reviewing.md); with none, the section is left out.

The finding line carries the severity, the mark when there is one, `path:line`, and `raised by <login>` when a reviewer already raised the point. The `Fix` line always closes the finding, right under its text, and a blank line separates one finding from the next. With nothing open, `## Findings` holds the line `No findings.`

Take both times from `date '+%Y-%m-%d %H:%M'`. With no report yet, number the findings blocking first, from 1. With a report, read it and keep every number:

- on an incremental run, a finding or let-go note in a file outside the scope stays as it is;
- a finding still present keeps its number, with location, severity, text and fix brought up to date;
- a finding no longer present leaves the report;
- a finding carrying `Argued in` counts as present until a test covers its feature or the feature is gone, even when the pass would let the feature go;
- a new finding takes `Next number`, which then goes up by one; a number is never used twice.

Set `Last checked` to now on every run. Set `Last updated` to now only when the findings section changed.

## Waivers

```markdown
# Waivers

## `src/Order.java` · `Order.submit()` · `if (user.getName().isBlank()) {`

- Finding: `user` may be null here.
- Severity: non-blocking
- Waived: `validate()` three lines up rejects a null user.
- Objection: `validate()` is skipped on the import path.
- Date: 2026-10-24
```

The heading holds the path, the enclosing method or function (or class, or `top level`), and one code line quoted verbatim; together they anchor the waiver however the lines move. `Objection` appears only when the user overruled the reviewer; `Lowered from blocking: <reason>.` only when the severity was lowered first. `check` never writes a waiver with severity blocking: one there is the user's own, written by hand, and every run that meets it names it in the conversation in one sentence.

During the review, a waiver applies on this branch only when its file holds its quoted line or its enclosing method:

- **absent:** neither is there. Skip the waiver and leave it in the file.
- **untouched:** the quoted line is there and the diff leaves it and its surroundings alone. The finding stays waived.
- **touched:** the diff changes the code around the quoted line, or the quoted line is gone while its enclosing method remains. Check the `Waived` reason against the code now; a hand-written blocking waiver without a reason counts as no longer holding. When the reason holds, the finding stays waived. When it does not, remove the waiver and review the place again; a problem still there goes into the report as a new finding.

## Cleanup

On a full run, or when the user asks, after the report is written, look for leftovers, all of them in one command:

- a report whose header names a PR/MR that is merged or closed, per the platform's metadata from the repository the header names (skip this check while offline);
- a report whose name no local branch in `git for-each-ref --format='%(refname:short)' refs/heads` maps to;
- a waiver whose file, on every local branch, holds neither its quoted line nor its enclosing method (`git grep -F` per branch).

Show them all and delete them only once the user confirms, or without asking when the user has said so.

The report of the default branch reviewed with no PR/MR (`main` against `main`, which covers only uncommitted changes) never becomes a leftover: that branch does not go away and has no PR/MR to merge. It stays until the user deletes it.
