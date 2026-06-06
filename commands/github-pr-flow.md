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
| PR created but has uncommitted local changes | Forgot to stage/commit | `git add . && git commit -m "..."` then `git push` |
| Issue still OPEN after its PR merged | PR body lacked `Closes #N` (title ref doesn't count) | `gh issue close <N> --comment "Shipped in #<PR> (<sha>)"`; add the keyword next time |
| Project-board card stuck in Todo/In-Progress after merge | No auto-Done workflow on the board, or issue never closed | Close the issue (auto-Done fires) or move the card manually via `gh project item-edit` |

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
- One PR per logical change — do not bundle unrelated fixes
- Always note temporarily disabled code (e.g. auth guards, feature flags) in the PR test plan
