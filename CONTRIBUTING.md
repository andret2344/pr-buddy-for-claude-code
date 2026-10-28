# Contributing

Issues and pull requests are welcome.

## Layout

- `.claude-plugin/marketplace.json`: the `andret2344` marketplace, with one entry per plugin; pr-buddy's source is `./plugins/pr-buddy`.
- `plugins/pr-buddy/`: the plugin, and the only folder its users receive. Anything for developers stays outside it.
  - `.claude-plugin/plugin.json`: the manifest, next to the icon its `icon` field names.
  - `skills/<name>/SKILL.md`: one file per command, holding the steps.
  - `reference/`: material the skills point at: platform APIs, the sending gate, voice, history, guideline mining.
  - `scripts/`: read-only Bash helpers a skill runs to gather local facts in one call. They run git and read files only; every `gh` and `glab` call stays in the platform references.
  - `README.md`: the full user documentation, also shown as the directory listing. The `README.md` at the repository root is a short landing page that links to it.
- `LICENSE` and `NOTICE` exist twice, at the repository root for GitHub and in `plugins/pr-buddy/` for every copy of the plugin. CI fails when the two copies differ.

## Ground rules

- **Nothing user-specific.** Voice profiles, guidelines and comment samples live in each user's `~/.claude/pr-buddy/`, never in this repository. The plugin ships no review rules of its own.
- **Posting stays behind the gate** in `plugins/pr-buddy/reference/sending.md`: the full payload shown, an explicit send word, one batch.
- **Repository state belongs to the user.** Skills run read-only git and hand every state-changing command to the user. Besides the edits the user agrees to in `respond`, the only files a skill creates in a clone are ones git already ignores, such as the `check` files in `.review/`, and it deletes them only once the user confirms; ignore rules (`.gitignore`, `.git/info/exclude`, git config) stay the user's to change.
- **`${user_config.*}` is substituted only in skill files**, never in `plugins/pr-buddy/reference/`, so any line that needs a config value belongs in a `SKILL.md`.

## Testing

1. Run `claude plugin validate .` (the marketplace) and `claude plugin validate ./plugins/pr-buddy` (the plugin) after every change to the manifests or skills. CI runs both on every push and pull request, together with a check of the relative Markdown links between skills and references.
2. Load your working copy: `claude plugin marketplace add <path to your clone>`, then `claude plugin install pr-buddy@andret2344`. A directory marketplace loads the files in place, so `/reload-plugins` picks up edits.
3. Try anything that posts against private state first: a pending GitHub review and GitLab draft notes are visible only to you until submitted. Delete them afterwards.

## Releasing

Users receive a new copy only when `version` in `plugins/pr-buddy/.claude-plugin/plugin.json` changes; commits pushed without a bump never reach them. Every change meant for users ships with a version bump, following semver. Keep `version` in `plugin.json` only, never in the marketplace entry.

## License

By contributing, you agree that your contributions are licensed under [Apache-2.0](plugins/pr-buddy/LICENSE).
