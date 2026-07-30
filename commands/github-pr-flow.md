---
name: github-pr-flow
description: Standard GitHub branch → PR → CI → merge workflow. Use whenever you need to push code to a protected main/master branch. Covers branch naming, PR creation with gh CLI, handling CI failures, merge conflict resolution, and branch protection setup.
---

# GitHub PR Flow

This skill enforces the standard branch-protection workflow used across all projects. Direct pushes to `main`/`master` are blocked — all changes go through a PR with CI checks.

---

## Step 1 — Check current state before doing anything

```bash
git status                          # confirm working tree is clean or staged
git log --oneline -5               # see recent commits
git branch                         # confirm current branch
```

If there are uncommitted changes, commit or stash them first before creating a branch.

---

## Step 2 — Create a feature branch

Branch naming convention:
| Work type | Prefix | Example |
|---|---|---|
| New feature | `feat/` | `feat/shell-redesign` |
| Bug fix | `fix/` | `fix/auth-redirect` |
| Chore / tooling | `chore/` | `chore/update-deps` |
| Documentation | `docs/` | `docs/api-reference` |
| Hotfix (urgent) | `hotfix/` | `hotfix/login-broken` |

```bash
git checkout -b feat/<short-description>
```

---

## Step 3 — Push and open PR

**Before pushing, check the diff SCOPE — not just the content:**

```bash
git diff --stat main...HEAD | tail -1
```

If the file count is far larger than the work you actually did, a formatter or
codemod ran repo-wide (`ruff format .`, `prettier --write .`, `eslint --fix`,
an IDE format-on-save sweep). Back the unrelated files out before pushing — a
15-file change that lands as a 120-file diff is unreviewable, pollutes
`git blame`, and conflicts with every open branch. Repo-wide formatting is its
own logic-free PR, never a passenger on a feature change. Full procedure:
`phase-done` Category 7.

```bash
git push -u origin feat/<short-description>
```

Then create the PR using the `gh` CLI. Always include a Summary + Test plan:

```bash
gh pr create --title "<type>: <what it does> (<issue ref>)" --body "$(cat <<'EOF'
## Summary
- Bullet point 1 — what changed and why
- Bullet point 2

## Test plan
- [ ] Manual step to verify feature works
- [ ] Edge case checked
- [ ] Any temporarily disabled code noted (e.g. auth guard commented out)
- [ ] CI passes (all 3 checks green)

## Linked issue
Closes #<issue-number>
EOF
)"
```

**PR title format:** `feat: add vendor upload form (#48)` — type prefix, what it does, issue number in brackets.

> **The `Closes #N` in the BODY is what auto-closes the issue on merge — the `(#48)` in the
> title does not.** If this subtask maps to a tracked issue, always include the body keyword
> (find the number first: `gh issue list --search "<title/keyword>"`; beware stale duplicate
> issues — pick the one the live roadmap references). Verified in Step 7.
>
> **⚠️ A closing keyword cannot be QUALIFIED — GitHub ignores your caveat and closes the issue.**
> Shipping one piece of a multi-part issue and writing
> `Closes #12 **piece 1 only** — the issue stays OPEN for pieces 2 and 3`
> closes #12 on merge anyway: the parser reads `Closes #12` and stops. The trailing words are for
> humans only, and the next session inherits a closed issue whose work is half-done — easy to miss,
> because the PR body *says* it stays open. **For partial work, never use a closing keyword: write
> `Part of #12` / `Refs #12` and close the issue by hand when the last piece lands.** Same for
> `Fixes`/`Resolves`. Cheap to verify: after merging, `gh issue view <N> --json state` — reopen with
> a comment saying why if it closed by mistake.
>
> **Verify the number against the LIVE tracker (`gh issue view <N>`) before writing `Refs #N` /
> `Closes #N` into a COMMIT message** — never trust an issue number carried by an old doc, a
> memory note, or a subagent report (they drift; issues get closed/repurposed). A wrong ref in a
> PR body is a one-command fix (`gh pr edit`), but a wrong ref in a *pushed commit* is effectively
> permanent and cross-links noise onto an unrelated issue. When it happens, correct the record in
> the PR body ("commit says #6 — stale ref, tracker is #156") rather than force-pushing history.

---

## Step 4 — Handle CI failures

If CI fails after the PR is opened:

1. Click the failing check in the PR → read the exact error
2. Fix the issue locally on the same branch
3. Commit the fix: `git add <files> && git commit -m "fix: <what broke>"`
4. Push: `git push` — CI re-triggers automatically

If CI does NOT re-trigger after a push (rare GitHub quirk):
```bash
git commit --allow-empty -m "ci: trigger re-run"
git push
```

**If the failure is UNRELATED to your diff — a dependency-audit gate tripped by a NEW upstream
advisory** (`npm audit` / `pip-audit` fails on a CVE published after your last merge, so EVERY
PR is red):
1. **Verify honestly whether the advisory applies** to how the project uses the package (the
   vulnerable code path may never be exercised) — but prefer the upgrade over an audit exception
   either way; record the applicability note in the fix PR body.
2. **Fix it as its OWN dependency PR off the default branch, merged FIRST** — never fold an
   unrelated dependency upgrade into the feature PR (it muddies review and revert). Watch for
   package renames/consolidations: the patched release may live under a different package name
   than the one you have installed, making the audit unfixable in place.
3. **Then update the feature branch from the default branch** and let CI re-run; re-verify the
   feature branch locally after the merge (typecheck + tests) before merging it.

---

## Step 5 — Resolve merge conflicts

If another PR merged to master while yours was open:

```bash
git fetch origin
git rebase origin/master
```

Conflicts will be listed. For each conflicting file:
- Open the file and resolve `<<<<<<< HEAD` / `>>>>>>> origin/master` markers
- Stage the resolved file: `git add <file>`
- Continue: `git rebase --continue`

After rebase:
```bash
git push --force-with-lease   # safe force push — fails if someone else pushed
```

> **Never** use `git push --force` on a shared branch. Always use `--force-with-lease`.

---

## Step 6 — Merge

Once all CI checks are green and the PR is approved:

```bash
gh pr merge <PR-number> --squash --delete-branch
```

Or merge via GitHub UI. After merge, sync local master:

```bash
git checkout master
git pull origin master
```

**⚠️ Stacked PRs (PR B based on PR A's branch): retarget the child BEFORE merging the parent.**
`gh pr merge A --squash --delete-branch` deletes A's branch, and GitHub then **auto-CLOSES PR B**
— a closed PR with a deleted base can be neither retargeted nor reopened. Correct order:

```bash
gh pr edit B --base master        # retarget the child FIRST
gh pr merge A --squash --delete-branch
gh pr merge B --squash --delete-branch
```

Recovery if B already got auto-closed: replay ONLY B's own commits onto the new master and
open a fresh PR. A plain `git rebase master` usually CONFLICTS (it replays A's pre-review-fix
commits against A's squashed final state) — use `--onto` from A's old tip instead:

```bash
git rebase --onto origin/master <A-branch-tip-sha> <B-branch>
git push --force-with-lease origin <B-branch>
gh pr create --base master ...    # fresh PR replaces the dead one
```

---

## Step 7 — Verify the issue closed AND the project board moved (don't skip)

Merging a PR **does NOT close the linked issue** unless the PR *body* contained a closing
keyword (`Closes #N` / `Fixes #N` — the title alone does nothing). And even when the issue
closes, a **GitHub Projects board** card only moves if the project's built-in
"auto-archive / set-Done-on-close" workflow is enabled. Both are silent when missing — the
work looks shipped while the tracker still says open. So after every merge:

```bash
# 1. The linked issue should now be CLOSED
gh issue view <N> --json state -q .state          # expect: CLOSED
# If still OPEN (PR forgot the keyword), close it manually with a trace to the merge:
gh issue close <N> --comment "Shipped in #<PR> (squash-merged as <sha>). <one line of what landed>."

# 2. If the repo uses a project board, the card should be in Done
gh project list --owner <owner>                    # find the board number
gh project item-list <num> --owner <owner> --format json \
  | python -c "import sys,json;[print(i['content'].get('number'),i.get('status')) for i in json.load(sys.stdin)['items'] if i['content'].get('number')==<N>]"
# If the card didn't move, set it (find the Status field/option ids via `gh project field-list`):
# gh project item-edit --id <item-id> --field-id <status-field> --project-id <pid> --single-select-option-id <done-id>
```

**Reconciliation sweep (cheap, catches drift):** list the board and flag any card whose
column disagrees with its issue's open/closed state — a closed issue still in *Todo/In-Progress*,
or an open issue parked in *Done*. Do this whenever you "finish" a ticket, not just at merge.

> A build-state / handoff note that says "✅ shipped" is **not** evidence the issue is
> closed or the card moved — verify the tracker itself. (This exact gap left two shipped
> features' issues open until a reconciliation pass caught them.)

---

## Handling Dependabot PRs (triage, don't bulk-merge)

Dependabot opens one PR per dependency (or per group). **Never** bulk-merge them blind, and
**never** force a red one through — a failing dep PR is telling you the bump is incompatible.
Triage first:

```bash
gh pr list --state open                         # find the dependabot PRs
for pr in <nums>; do
  echo "=== #$pr ==="; gh pr checks $pr | head; echo
done
```

Split into two piles:

- **Green (all checks pass)** → low-risk, merge directly: `gh pr merge <pr> --squash --delete-branch`.
- **Red (any check fails)** → read the *actual* failing log before deciding — the failure mode dictates the fix:

```bash
gh pr checks <pr>                               # find the failing job's run/job id
gh run view --job <job-id> --log-failed | grep -iE "error|conflict|cannot|Traceback|exit code" | head -40
```

Common red patterns and the fix:

| Failure in the log | What it means | Fix |
|---|---|---|
| `ResolutionImpossible` / `X depends on Y<Z` | The bump conflicts with another pin (e.g. langchain caps langgraph) | Bump **both together** in one coordinated PR; let `pip`/`npm` re-resolve, run `pip check` |
| `AttributeError` / `no attribute` / removed API after install | A *different* dep can't handle the new version (e.g. passlib reads bcrypt's removed `__about__`) | The blocker is the consumer, not the bump — upgrade/replace it (passlib→native bcrypt). Often the dead dep should be dropped, not pinned-back |
| Grouped bump where one member breaks (e.g. eslint 9→10 with a config bump) | One sub-bump is hostile (removed API), the rest are fine | Take only the safe member, pin the hostile one back; verify locally |

**Supersede pattern** — when a dependabot PR can't merge as-is, do the real fix on **your own
branch** and close theirs in favour of it (a dependabot branch isn't yours to hand-edit, and
`Closes #N` doesn't auto-close *PRs*, only issues):

```bash
git checkout master && git checkout -b deps/<coordinated-fix>
# edit manifests, regenerate lockfile, run the suite + (for engine/pipeline bumps) the benchmark
gh pr create --title "chore(deps): <coordinated bump> (fixes #<dependabot-pr>)" \
  --body "Supersedes #<dependabot-pr>. <root cause + what verified>"
# after your PR merges:
gh pr close <dependabot-pr> --delete-branch --comment "Superseded by #<your-pr>: <one-line why>"
```

Always record the *why* in the manifest comment (e.g. `# pinned at ^9 — eslint 10 removed
context.getFilename(), breaks eslint-plugin-react`) so the next dependabot bump doesn't silently
reopen the same break.

---

## Branch protection setup (one-time per repo)

Set up via GitHub UI: **Settings → Branches → Add ruleset**

Required settings:
- Target branch: `master` (or `main`)
- ✅ Require a pull request before merging
- ✅ Require status checks to pass
  - Add checks only AFTER CI has run once on master (names appear in dropdown)
  - Typical checks to add: `test`, `lint`, `build` (whatever your CI jobs are named)
- ✅ Block force pushes

> **Note:** Status check names only appear in the "Add checks" dropdown after the GitHub Actions workflow has completed at least one run on master. If the dropdown is empty, merge one PR first, then come back and add the checks.

---

## Common problems and fixes

| Problem | Cause | Fix |
|---|---|---|
| `push declined due to repository rule violations` | Tried to push directly to master | Create a branch, open a PR |
| CI check not showing in ruleset dropdown | CI hasn't run on master yet | Merge any passing PR first, then add checks |
| CI not re-triggering after push | GitHub timing issue | Empty commit: `git commit --allow-empty -m "ci: trigger re-run"` |
| `error: failed to push some refs` after rebase | Diverged history | `git push --force-with-lease` |
| Merge conflict on same file from two PRs | Concurrent PRs | Merge in order: rebase later PR on top of merged one |
| PR created but has uncommitted local changes | Forgot to stage/commit | `git add <paths> && git commit -m "..."` then `git push` — stage EXPLICIT paths, never `git add .`, or you sweep in whatever else is in the tree (see the row below) |
| Dependabot PR red with `ResolutionImpossible` | Bump conflicts with another pin | Bump both deps together in one superseding PR (see Dependabot section) |
| Dependabot PR red with `AttributeError`/removed-API after install | A *consumer* dep can't handle the new version | Upgrade/replace the consumer (often drop a dead dep), don't pin the bump back |
| Issue still OPEN after its PR merged | PR body lacked `Closes #N` (title ref doesn't count) | `gh issue close <N> --comment "Shipped in #<PR> (<sha>)"`; add the keyword next time |
| Project-board card stuck in Todo/In-Progress after merge | No auto-Done workflow on the board, or issue never closed | Close the issue (auto-Done fires) or move the card manually via `gh project item-edit` |
| `gh pr checks --watch` exits non-zero but every required check passed | A path-filtered/skipped job reports an empty conclusion, which `--watch` treats as failure | Never trust the exit code alone — confirm with `gh pr view <N> --json statusCheckRollup` and read each check's `conclusion` (SUCCESS/empty=skipped) before declaring CI red |
| Feature commit accidentally includes unrelated untracked files | `git add -A` / `git add .` sweeps in whatever else is sitting in the working tree (someone else's docs, scratch files) | Stage explicit paths for feature commits; if already committed, `git rm --cached <files> && git commit` removes them from the branch while keeping them on disk |

---

## Quick reference — full flow in one block

```bash
# 1. Create branch
git checkout -b feat/my-feature

# 2. Make changes, commit
git add <files>
git commit -m "feat: describe what changed"

# 3. Push and open PR
git push -u origin feat/my-feature
gh pr create --title "feat: my feature (#42)" --body "## Summary\n- What changed\n\n## Test plan\n- [ ] Verify X works"

# 4. If CI fails — fix, commit, push
git add <fixed-files>
git commit -m "fix: resolve CI failure"
git push

# 5. After CI passes — merge
gh pr merge 42 --squash --delete-branch

# 6. Sync local master
git checkout master && git pull origin master
```

---

## Notes for this workflow

- **No Co-Authored-By trailers** in commit messages — causes confusion in git history
- Commit messages follow conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`
- **ANY multiline text argument to a native exe on Windows PowerShell 5.1 goes through a FILE, never an
  inline here-string.** Embedded double quotes inside a `@'…'@` here-string get stripped/split when passed
  to a native exe, so the text arrives chopped into bogus extra arguments. Seen in the field on **both**
  `git commit -m` (→ `error: pathspec '…' did not match`) **and** `gh pr create --body` (→ `unknown
  arguments […]; please quote all values that have spaces`). The fix is the same family of flags:
  `git commit -F <msgfile>` · `gh pr create --body-file <file>` · `gh pr comment --body-file` ·
  `gh issue create --body-file` · `gh release create --notes-file`. Write the text to a temp file,
  pass the file flag, delete the file after.
- **Never round-trip a UTF-8 source file through PowerShell 5.1 `Get-Content`/`Set-Content`**
  (e.g. for a bulk regex replace before committing). PS5.1 reads with the ANSI codepage by default,
  so em-dashes and other multibyte chars come back as mojibake (`â€”`) and the mangled file gets
  committed. Seen in the field: a test file corrupted by a one-liner replace; the fix was
  `git checkout -- <file>` and redoing the change with a real editor/Edit tool. If PowerShell must
  write a file, pass `-Encoding utf8` on BOTH read and write — but prefer proper edit tooling.
- **`npm run <script> -- --flag value` argument passthrough is unreliable on Windows PowerShell 5.1**
  — flags can arrive as bare positionals (seen in the field: `npm run dev -- --port 5173` started
  Vite with root dir "5173" → every route 404). When a background dev server must get flags, invoke
  the underlying binary directly: `npx vite --port 5173 --strictPort`.
- One PR per logical change — do not bundle unrelated fixes
- Always note temporarily disabled code (e.g. auth guards, feature flags) in the PR test plan
