---
name: check
description: Review the user's own branch or pull/merge request and list the problems in the conversation, posting nothing. Use when the user asks to check, review or critique their own code, branch or PR/MR.
argument-hint: "[PR/MR link or number] [--committed]"
---

# Check

Review the user's own work as a relentless reviewer and hand back the findings as a list in this conversation and as review files in the clone. The platform is only read: every finding stays local, so the voice profile and the sending gate play no part. Shared reference lives in the plugin's `reference/` directory, two levels above this skill's base directory.

Platforms the user enabled for pr-buddy (`true` or `on` means enabled, `false` or `off` disabled, and a placeholder left unfilled means enabled): GitHub `${user_config.github}`, GitLab `${user_config.gitlab}`.

The code under review is the working tree, uncommitted and untracked files included. With `--committed`, it is HEAD.

1. **Setup.** Follow the Local checkout, Shell, Guidelines and Language sections of [setup](../../reference/setup.md). Pick the platform from the link's host, or from `git remote get-url origin`, as its Platform section says.
   - **Online** when the platform is enabled and its CLI logged in. Find the PR/MR: the one given, else the open one from the current branch, per the platform reference's "of a branch" entry. A branch without a remote (`git config branch.<branch>.remote` prints nothing) has none. When more than one matches, ask the user which. From here on, every platform call goes to the repository the PR/MR was found in, which for a fork is its parent, not `origin`. Its author must be the user; when it is someone else (another agent's account included), suggest `/pr-buddy:review` and stop. The base is its target branch. Its head SHA must be an ancestor of HEAD or equal to it (`git merge-base --is-ancestor <head sha> HEAD`); otherwise hand the user `git pull` and wait.
   - **Offline** when there is no PR/MR, the host is unsupported, the platform is disabled, or its CLI is not logged in. Tell the user which, then go on without the platform. The base is the default branch from `git symbolic-ref refs/remotes/origin/HEAD`; when that fails, ask the user for it.

   Then make sure git ignores the report and the waivers file, per the Paths and Ignored first sections of [review files](../../reference/review-files.md), and read both when they exist.

   Done when: online or offline settled, the base known, HEAD confirmed, guidelines loaded, both paths ignored, the existing report and waivers read.

2. **Gather.** Online, first gather metadata and every existing discussion per the platform reference; when the description links an issue (`#12`, `Closes #4`), read it: it states what the change is meant to do. The discussions are context only: applying and answering them is the job of `/pr-buddy:respond`.

   When the run is offline with no PR/MR and the current branch is the default branch itself (`main` against `main`), the code under review is the uncommitted changes only: `git diff HEAD` plus the untracked files, whatever commits are unpushed. With `--committed` there is then nothing to review: say so and stop.

   Otherwise, a found PR/MR included even when its head and target branches share a name, take the diff locally from the merge-base. Online, it is `git merge-base <base sha> HEAD`, with the PR/MR's own base commit from the metadata (`.base.sha` on GitHub, `diff_refs.base_sha` on GitLab): for a fork, `origin/<base>` is the fork's copy and usually lags the parent. When that commit is missing locally (`git cat-file -e <base sha>` fails), hand the user `git fetch` for the remote that holds it and wait. Offline, it is `git merge-base origin/<base> HEAD`. Then `git diff <merge-base>` for the working tree (`git diff <merge-base> HEAD` with `--committed`), plus every file `git ls-files --others --exclude-standard` lists, which the diff leaves out. Mark where each change lives:
   - **uncommitted**: in the working tree only, from `git diff HEAD` and the untracked files;
   - **unpushed**: in local commits the remote lacks, from `git diff <remote head> HEAD`, where the remote head is the PR/MR head SHA online and `@{upstream}` offline; with no upstream, every commit since the merge-base is unpushed;
   - unmarked: already in the PR/MR, or on the remote branch.

   Done when the whole diff is known with the mark of every change, and online, the intent and everything already said.

3. **Review**, relentless, per [reviewing](../../reference/reviewing.md). Hold every finding against the waivers, per the Waivers section of [review files](../../reference/review-files.md). Done when the reviewing pass is done and every waiver on this branch is judged absent, untouched or touched.

4. **Report.** Write the report per the Report section of [review files](../../reference/review-files.md), then give the same report in the conversation: the header (online, the PR/MR number and title; always, branch → base and the HEAD SHA reviewed, adding "plus uncommitted changes" when the working tree under review differs from HEAD), the open findings blocking first under their report numbers, the features let go untested with their reasons, one line naming the numbers that left the report since the last run, one line per waiver removed or hand-written blocking waiver met, online and with unresolved threads on the PR/MR, one line suggesting `/pr-buddy:respond` for them, in that default-branch case from Gather, one line saying only uncommitted changes were reviewed and its report stays until deleted by hand, and one more, said once and left there, that the work would sit better on a branch of its own (`git switch -c <name>` takes the uncommitted changes along), and links to both files. For each finding: `path:line` in the code under review, its severity, its mark, what is wrong and why it matters, then, on the line right under it, `Fix:` with the suggested solution; when the solution is unclear or the user's call, `Fix: needs a decision` naming the options. A blank line separates one finding from the next. In the conversation, `Fix:` is bold (`**Fix:**`); the file keeps it plain. Severity is **blocking** (must be fixed before merging), **non-blocking** (worth fixing, merging may go ahead) or **follow-up** (belongs in a later change). A point a reviewer already raised in a discussion stays on the list, naming who raised it. The user owes no decision on the findings. Then run the Cleanup section of review files.

5. **Argue.** When the user pushes back on a finding, weigh the argument against the code, and record every outcome in the review files at once, setting the report's `Last updated` to now.
   - **The argument holds:** accept it; the finding leaves the report and becomes a waiver with the argument as its reason. When it holds against the severity only, a blocking finding drops to non-blocking in the report with `Lowered from blocking`.
   - **The argument does not hold:** show why with the evidence from the code. A blocking finding stays in the report; say once that the user can waive it by writing its waiver into the waivers file by hand. A non-blocking or follow-up finding the user still wants dropped becomes a waiver with their reason and your objection.
   - **The argument turns a let-go note into a finding:** the feature leaves `## Untested, let go` and becomes a blocking finding with `Next number`, carrying `Argued in: <the user's argument>.` on the line above `Fix`.
   - **The argument targets the rule, not this place** ("this repository uses no `final`"): propose recording the convention in the repository's contributor docs or changing `~/.claude/pr-buddy/guidelines.md`, instead of a waiver. The finding stays as it is until the rule changes. An argument against a finding that names many places counts as one against the rule; when the user drops only some of the places, each becomes a waiver of its own and the finding keeps the rest.
