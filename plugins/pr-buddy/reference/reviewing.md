# Reviewing

The review pass shared by `review` and `check`. The skill names the code under review and adds its own rules on top.

Every tool call sends the whole conversation again, so gather in a few large calls rather than many small ones: one command reads all the changed files, one greps all the callers, one searches all the tests.

- Read every changed file in full, beyond the hunks. In a file over 500 lines, read the changed functions and classes whole instead.
- For every changed or removed signature that code outside its file can call (public, exported, package-level), grep its callers across the repository. Callers of the others sit in the file already read.
- Judge a library or framework by its documentation and by how the repository already uses it. Open its source (a sources jar, `node_modules`, `site-packages`) only when a blocking finding turns on it.
- Apply every guideline from [setup](setup.md) to every changed file.
- When the intent is known (the PR/MR description, a linked issue), check the change against it.
- Match every changed behavior to the tests that exercise it, searching the whole repository, not only the changed test files. Name each path no test reaches: error handling, boundaries, the other branch of a condition. Such a path is blocking when a documented testing or coverage rule of the repository requires it, and non-blocking otherwise. A feature with no test at all is a blocking finding. Let it go when the code cannot be tested, or when a test would take far more scaffolding than it is worth, such as mocking half a framework to check one log line. Tell the user every feature let go, with the reason, apart from the findings: it is a note, not a finding, and the user may still argue it into one. When the repository has no tests at all, none of this applies per feature: `check` raises one non-blocking finding suggesting it add some instead, and `review` says nothing about it, since the missing tests are not the author's doing.
- Build or run tests only with the user's permission. When the repository configures a coverage tool (JaCoCo, Vitest or Jest coverage, coverage.py, a coverage step in CI), ask once, before the pass, whether to run the tests with coverage; when someone else wrote the code under review, the question says the run executes their code, build scripts included, on this machine. Run it only when its output lands where git ignores it (`git check-ignore`); otherwise say so and do not run it. With a run, report the coverage of the changed lines and hold it against the repository's rules; without one, say the test findings rest on reading the code alone. Beyond that, ask when a build or test result would change a finding.

Done when every hunk is read, every guideline applied, the callers of every changed signature reachable from other files checked, and every changed behavior matched to its tests.
