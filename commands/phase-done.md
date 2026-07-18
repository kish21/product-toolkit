---
description: End-of-phase quality gate — 11-category audit (code review, deprecated patterns, hygiene, docs, CI parity, branch freshness, PR safety) that blocks bad pushes
---

# `/phase-done` — generic end-of-phase quality gate

You are running an 11-category end-of-phase audit on the user's current branch.
Use this **after every phase commit**, before push. The user invokes this as
the LAST step of a phase; your job is to surface anything that warrants action.

**Reusable across projects** — this skill is project-agnostic. For
project-specific extras, look for a co-resident `phase-done-<project>.md` in
the repo's `.claude/commands/` and run that AFTER this generic one finishes.

---

## Phase 0 — Detect scope

Run these read-only commands and note the results:

```bash
git log --oneline @{upstream}..HEAD          # commits since last push
git diff --stat @{upstream}...HEAD           # file-level diff stat
git status --short                           # uncommitted changes
git diff --name-only @{upstream}...HEAD      # file list (for content scans)
```

If no upstream, fall back to `git diff origin/master...HEAD` or `git diff HEAD~5...HEAD`.

Note:
- Branch name + commit count since upstream
- Set of changed file *categories* (auth, db, frontend, agents, infra, tests, docs)
- Whether the working tree is clean

If the tree is empty (no commits to review), stop and tell the user there's
nothing to audit.

---

## Phase 1 — Run the 11 audit categories

For each category, surface findings with severity (high / medium / low) and a
concrete action. Don't fix anything automatically — the user decides.

### Category 1 — Code quality

- **Always**: run `/code-review` against the diff. Wait for findings.
- **If** `app/auth/`, `app/api/`, schema, or anything access-control was touched:
  also recommend the user run `/security-review` (you cannot invoke it yourself
  — only the user can run user-level slash commands).
- If `/code-review` surfaces auto-fixable cleanups, recommend `/simplify` (if installed).

### Category 2 — Architecture currency

Scan the diff for **deprecated patterns**. Common ones (extend per ecosystem):

- **Python 3.12+**: `datetime.utcnow()` → `datetime.now(timezone.utc)`
- **Pydantic 2.x**: `@validator` → `@field_validator`; `from pydantic import BaseSettings` → `from pydantic_settings import BaseSettings`
- **SQLAlchemy 2.x**: bare string SQL → `sa.text(...)`; sync `engine.connect()` inside async code
- **asyncio**: blocking `time.sleep` → `asyncio.sleep`; fire-and-forget `asyncio.create_task(coro)` without holding a reference
- **FastAPI 0.110+**: `@app.on_event("startup"/"shutdown")` → `lifespan` context manager
- **LangGraph 1.x**: missing `Annotated[dict, reducer]` on state fields with parallel writes; old `langgraph.prebuilt` imports
- **OpenAI 2.x / Anthropic ≥ 0.35**: check provider SDK kwargs match current signatures (seed, response_format, etc.)
- **React 19**: `useEffect(() => fetch(...), [])` without cleanup; bare `dangerouslySetInnerHTML` (XSS)
- **Next.js 16**: `pages/` directory in an App-Router project; client components forgetting `"use client"`

For each finding, report `file:line — pattern detected — modern alternative`.

Also cross-check against `requirements.txt` / `package.json` versions — if the
codebase is pinned to a major version where a pattern is deprecated, flag it.

### Category 3 — Industry-standard hygiene

For each file the diff added or substantially changed:

- **Type hints**: every public function has return type annotation
- **Docstrings**: every public function (no leading `_`) has at least a one-line docstring
- **Tests**: ratio of new test lines / new code lines ≥ 0.3 (rough heuristic; tune per project culture)
- **Logging**: new error paths have a log call
- **Security smells**:
  - Raw f-string SQL: `f"SELECT * FROM users WHERE id={user_id}"` (parameterise instead)
  - `eval` / `exec` / `pickle.loads` on any untrusted input
  - Hardcoded passwords / API keys / tokens
  - Missing `org_id` filter on any DB query in a multi-tenant codebase
  - Missing auth dependency on a new API endpoint
  - `except ValueError` mapped to a user-facing "your input is invalid" response in an
    API handler: pydantic `ValidationError` **subclasses ValueError**, so server-side
    model/config failures leak internal error text to the client, mislabelled as the
    user's mistake and never logged as an outage. Fix: define a dedicated typed error
    class for the user-actionable case(s) and catch ONLY it; let everything else fall
    through to the logged generic 5xx path. (Same trap: `binascii.Error` from base64,
    `int()` on config values — all ValueError.)
- **Configuration**: hardcoded URLs / thresholds / timeouts (should live in config)
- **DEAD CONFIG (the inverse smell, and the sneakier one)**: a knob **declared** in
  config/yaml and **read by nobody** — the behaviour it names is hardcoded somewhere
  else. It reads as configurable, does nothing when flipped, and the owner reasonably
  concludes the setting is honoured. Grep every new config key for a consumer; if the
  consumer is a frontend with no config access, the **server must serve the value**
  (e.g. in a response `meta`) rather than the page re-hardcoding it. Pin with a test
  that asserts the value actually reaches the behaviour.
- **Correctness smells (each of these ships a bug that still LOOKS correct):**
  - **An auto-fix that isn't re-validated against the checks it fixes.** "Fix it for
    me" / auto-remediation that emits output the validator then rejects → it reports
    *"Fixed!"* and the user re-checks into the same failure. Assert end-to-end: apply
    the fix → re-run the checks → zero findings. Where no fix is possible it must
    **refuse honestly**, not half-fix.
  - **A cache key built by INCLUSION (a hand-picked field allowlist).** The next field
    someone adds to the model is silently unhashed → a stale result is served on
    changed input. Build the key by **exclusion**: hash the whole object minus known-
    volatile fields (signed URLs, timestamps), and include the **thresholds** and the
    **validator/check version** so a config change or a new check invalidates it.
  - **A validator/gate that fails OPEN.** A check that throws and falls through, or a
    checker that silently no-ops when its endpoint/flag is unconfigured. Fail-soft is
    correct on a generation path and **catastrophic** on a gate — it waves everything
    through while still looking like a gate.
  - **A fabricated metric.** A score/percentage/grade shown in the UI that nothing
    actually measured (a text model "rating" images it never saw; a hardcoded demo
    number left in a real page). Emit **no number** and say why. Grep new UI for
    literal scores.

Report each finding with file:line + the smell + the standard fix.

### Category 4 — Documentation

Check whether documentation kept pace with code:

- Is there a project plan / roadmap doc? If yes, was it updated to reflect this phase?
- Is there a CHANGELOG, README "what's new", or release-notes section? Updated?
- For public API changes, are docstrings updated AND any external docs (Sphinx/MkDocs/Storybook) regenerated?
- For schema changes, is there a migration file or schema-doc update?

Don't be pedantic — flag genuine gaps only.

### Category 5 — Memory writes

Prompt the user (text-only, don't auto-write):

> "Did this phase reveal any non-obvious patterns, gotchas, or bugs that
> future-Claude should know about? Examples: SDK quirks, library
> versioning footguns, surprising-but-correct behaviour. Save them as
> `feedback_*.md` in your project memory directory so future sessions
> don't rediscover them."

If the user names something, save it for them as a `feedback_*.md` file in
`~/.claude/projects/<project-slug>/memory/` and update `MEMORY.md` with a
one-line pointer.

### Category 6 — Claude Code feature suggestions (file-type aware)

Inspect the file *categories* changed and recommend underused features:

| If the phase touched... | Recommend |
|---|---|
| `app/db/`, `db/`, any `.sql`, or DB-touching code | Install **Postgres / SQLite MCP server** for next phase (replaces inline `psycopg2` / `sqlalchemy.text` scripts) |
| `app/api/`, GitHub workflow, repeated `gh` CLI calls | Install **GitHub MCP server** |
| `frontend/`, `*.tsx`, `*.jsx`, `*.vue`, `*.svelte` | Use `/frontend-design` → `/new-component`, then Anthropic's `anti-ai-ui` skill if installed |
| `app/auth/`, RBAC, multi-tenant code | Run `/security-review` explicitly on this branch |
| Multiple independent feature areas changed in one phase | Next time consider `Agent(isolation: "worktree")` to do them in parallel |
| New background job / cron / scheduled task | Use `/schedule` for cron-style remote agents |
| Subtle correctness logic (state machines, schedulers, concurrency) | Run `/code-review ultra` (billed cloud multi-agent) on the PR |
| LLM prompt changes (any `*.yaml` / `*.txt` under prompts dir) | Audit prompt caching via the `claude-api` skill |
| Same kind of permission prompt fired ≥3 times this session | Run `/fewer-permission-prompts` to consolidate (if installed) |
| Recurring task pattern emerging (e.g. you typed similar commands 4+ times) | Use Anthropic's `skill-creator` skill to author a reusable skill |

For each recommendation, link to the relevant doc or skill name. Don't
recommend something the project already uses — check first.

### Category 7 — Pre-push hygiene

Block list (any hit = warn the user before pushing):

- Uncommitted files in working tree (other than gitignored)
- `.env`, `*.key`, `*.pem`, `id_rsa`, `id_ed25519`, `aws-creds*`, `.npmrc` with auth tokens
- Settings.local.json staged (should be gitignored)
- Plain-text secrets / API-key-shaped strings in diff (`sk-`, `xoxb-`, `ghp_`, `AKIA`)
- Large binary files (>5MB) without LFS markers
- Build artifacts (`dist/`, `build/`, `__pycache__/`, `node_modules/`) accidentally staged
- `requirements.txt` / `package.json` / `pyproject.toml` parse-fails (run `pip check` / `npm install --dry-run` / equivalent)
- All new tests pass; the project's full test suite is green
- **Diff scope matches the change** (see below)

Report each as a blocker (do-not-push), warning (review-before-push), or pass.

#### Diff-scope check — did a formatter/codemod touch files you never meant to?

```bash
git diff --stat HEAD | tail -1          # or: git diff --stat main...HEAD
```

Compare the file count to the number you *intended* to change. If the diff is
much wider than the work, something ran repo-wide. The usual culprits:
`ruff format .`, `black .`, `prettier --write .`, `eslint --fix`, `gofmt -w .`,
an IDE "format on save" sweep, or a codemod.

**Why this is a blocker, not a nit.** A 15-file change that arrives as a
120-file diff is unreviewable — the reviewer cannot separate your logic from
whitespace, `git blame` is polluted across the codebase, and every concurrent
branch gets conflicts. Reviewers respond by skimming, which is exactly when
real bugs ship.

**Do not assume the repo is formatter-clean.** Many mature repos deliberately
keep hand-tuned formatting (aligned comment columns, compact multi-arg calls)
that a formatter will "fix". Running the formatter repo-wide *creates* the
drift you then have to back out.

Fix, in order of preference:
1. Scope the tool to your files: `ruff format path/to/file.py`, not `ruff format .`
2. Already ran it wide? Revert everything you did not intend to touch:
   ```bash
   for f in $(git diff --name-only); do
     grep -qx "$f" intended-files.txt || git checkout -- "$f"
   done
   ```
   Then re-apply your edits to any of *your* files that got reformatted, keeping
   the file's existing style.
3. If the repo genuinely should be formatted repo-wide, that is **its own PR**
   with no logic in it — never a passenger on a feature change.

### Category 8 — Deferred work tracking

Grep for `TODO`, `FIXME`, `XXX`, `HACK`, `BUG` comments added by the diff.
For each, ask whether it should become a GitHub issue / Linear ticket / backlog
entry so it's not lost.

Check whether the project plan / `BACKLOG.md` was updated with anything that
got punted from this phase.

If commit messages contain "deferred to Phase N.M" or "TODO: ...", verify the
deferral target actually exists in the plan.

### Category 9 — Branch freshness (catches "merge conflicts at PR-merge time")

Long-lived feature branches drift from master and accumulate conflicts that
are easier to resolve early than late. Run:

```bash
git fetch origin master
behind=$(git rev-list --count HEAD..origin/master 2>/dev/null || echo 0)
ahead=$(git rev-list --count origin/master..HEAD 2>/dev/null || echo 0)
echo "Branch: ${ahead} ahead, ${behind} behind"
```

Severity ladder:
- `behind == 0` → ✓ pass
- `behind 1–5` → ⚠ warn: "Rebase recommended before opening PR. `git rebase origin/master`."
- `behind > 5` → ❌ block: "Significant divergence — rebase first or the PR will hit conflicts."

Also surface ALL files that origin/master changed but our branch hasn't seen:

```bash
git diff --name-only HEAD..origin/master | head -20
```

so the user can predict which files are most likely to conflict.

### Category 10 — Pre-push CI parity (catches "works locally, fails in CI")

Most CI failures are environment mismatches between local dev and CI. Three
concrete checks to run BEFORE proposing the user push:

**10a. Dependency drift between dev and CI**

If `requirements-dev.txt` (or equivalent dev-tooling file) exists, verify the
CI workflow installs it. This catches the most common regression where pytest
or test-only deps live in dev requirements but CI only installs prod:

```bash
# Find dev-deps files
ls requirements-dev.txt package.json 2>/dev/null
# Verify CI installs them
grep -l "requirements-dev.txt\|npm ci.*--include=dev" .github/workflows/*.yml || \
  echo "⚠ requirements-dev.txt exists but no CI workflow installs it"
```

**10b. Run pytest locally with the SAME command CI uses**

Read the pytest invocation from the CI workflow and run it locally:

```bash
# Extract the command from the workflow
grep -A1 "Run pytest\|Run tests" .github/workflows/*.yml | grep "pytest" | head -1
# Then run it locally and check the exit code
```

If it fails locally, fix BEFORE pushing — CI will surface the same failure
slower.

**10c. Service-dependency scan in test files**

Detect tests that need external services (Postgres, Qdrant, Redis, LLM
endpoints) so the user knows which will fail in a service-less CI:

```bash
grep -rln "get_engine\|psycopg2\|sa.text\|qdrant\|requests.post.*localhost" \
    tests/ 2>/dev/null | grep -v "conftest\|_helper\|__pycache__"
```

For each file surfaced: report whether the CI workflow has the corresponding
service block. If not, either add the service OR mark those tests with a
pytest marker and exclude them in CI. Don't silently push and let CI surface
the failure.

### Category 11 — PR pre-creation audit (catches "silent overwrite of PR metadata")

Before invoking `/github-pr-flow` or `gh pr create`, check whether a PR
already exists for the current branch. PR title + body are collaborative
state — reviewers, the team, future-you may be reading them; overwriting
silently destroys context.

```bash
branch=$(git branch --show-current)
gh pr list --head "$branch" --json number,title,state,updatedAt
```

If a PR exists:
- Report current title + the FIRST 5 LINES of the existing body
- Ask the user: keep / replace title only / replace body only / append my
  generated summary / leave entirely as-is
- Only after explicit choice, proceed with `gh pr edit`

If no PR exists, proceed to `/github-pr-flow` normally.

---

## Phase 2 — Aggregate and report

Output a single structured report. Example shape:

```
═════════════════════════════════════════════════════════════════
  /phase-done audit — branch fix/X, 7 commits since upstream
═════════════════════════════════════════════════════════════════

[1] CODE QUALITY
    ✓ /code-review: 8 findings (3 high, 5 low) — see above
    ⚠ /security-review recommended: auth changes detected in app/auth/rbac.py
    💡 /simplify can auto-fix 2 findings

[2] ARCHITECTURE CURRENCY
    ⚠ 3 deprecated patterns:
      - app/infra/logger.py:127  datetime.utcnow() → use datetime.now(timezone.utc)
      - app/api/v1.py:42         @app.on_event → use lifespan context manager
      - app/db/models.py:89      @validator → use @field_validator (Pydantic 2)

[3] INDUSTRY STANDARDS
    ✓ Type hints: 100%
    ✓ Docstrings: 92%
    ✓ Test ratio: 0.4 (new_test_lines / new_code_lines)
    ⚠ Security: 1 raw f-string SQL at app/db/queries.py:55

[4] DOCUMENTATION
    ✓ Plan file updated for this phase
    ⚠ CHANGELOG not updated

[5] MEMORY
    ❓ Did this phase reveal anything worth saving to memory?
       (suggested topic based on diff: ...)

[6] FEATURE SUGGESTIONS
    💡 Phase touched app/db/ extensively → install Postgres MCP server
    💡 Phase touched LLM prompts → audit caching via /claude-api

[7] PRE-PUSH HYGIENE
    ✓ Tree clean, no secrets, requirements valid, all tests green

[8] DEFERRED WORK
    ⚠ 2 new TODO comments without tracked issues:
       - app/agents/planner.py:67  "TODO: handle multi-agency RFPs"
       - app/jobs/cleanup.py:34   "FIXME: race condition under load"

[9] BRANCH FRESHNESS
    ⚠ Branch is 3 commits behind origin/master
       Files master changed that we'll likely conflict on:
       - BACKLOG.md
       - app/agents/retrieval.py
       Suggested: git fetch && git rebase origin/master  (before push, not at merge time)

[10] PRE-PUSH CI PARITY
    ❌ pytest fails locally with: pytest: command not found
       requirements-dev.txt exists but CI workflow doesn't install it.
       Fix: add `-r requirements-dev.txt` to .github/workflows/ci.yml line 49.
    ⚠ 14 tests in tests/test_visibility_matrix.py touch PostgreSQL
       CI workflow has no PG service — these will error in CI.
       Either add a `services: postgres:` block OR mark with
       @pytest.mark.requires_db and exclude in CI.

[11] PR PRE-CREATION AUDIT
    ⚠ PR #150 already exists for this branch
       Current title: "fix: agent review — all 9 agents hardened..."
       Updated 5 days ago by your previous session.
       Options before /github-pr-flow runs:
         a) keep title + body as-is (push commits only)
         b) replace title + body with my new summary
         c) append my new summary to existing body
       (User must choose; I do NOT silently overwrite.)

═════════════════════════════════════════════════════════════════
  RECOMMENDATION
═════════════════════════════════════════════════════════════════
  [BLOCK]  fix high-severity /code-review findings before push
  [BLOCK]  fix CI parity issue (pytest missing) before push
  [WARN]   review architecture-currency + security smell
  [WARN]   3 commits behind master — rebase before /github-pr-flow
  [INFO]   consider Postgres MCP for next phase
  [INFO]   answer PR #150 metadata question before invoking /github-pr-flow
```

Use `✓` / `⚠` / `❌` / `💡` / `❓` consistently so the user can scan it.

---

## Phase 3 — Hand off

End with a clear single-line recommendation:
- `READY TO PUSH` (all green)
- `FIX FIRST` (any high-severity finding from /code-review or hygiene blockers)
- `REVIEW WARNINGS` (only warnings, user judgement call)

Then ask: **"Would you like me to act on any of these now?"** — don't proceed
unprompted; let the user pick what to address.

---

## Footnote for me (the user) — keep this in sync

This skill is `~/.claude/commands/phase-done.md` — user-global so it applies
to every project. To share with team-mates or other projects:

1. Push a copy to your `kish21/product-toolkit` repo
2. Other devs `cp product-toolkit/phase-done.md ~/.claude/commands/`
3. For project-specific extras, layer a `.claude/commands/phase-done-<project>.md`
   in the project repo that invokes `/phase-done` first then adds custom checks.

Date: 2026-05-28. Iterate as new patterns emerge.
