---
name: doc-create
description: Scaffold ONE new documentation file grounded in the actual code state, written for a specific audience. Use this whenever the user mentions creating a new doc, "we should write a SECURITY.md", "we don't have an architecture doc", or `/doc-audit` flagged a MISSING category. One doc per invocation — keeps blast radius small. Pair with /doc-audit, which finds the gaps; this skill fills them.
---

# `/doc-create` — scaffold ONE new doc grounded in code reality

This is the **create** half of the doc-toolkit pair. It writes ONE new documentation file at the conventional path, based on what the codebase actually contains — not a generic template. The output is a draft for the user to refine, not a final artifact.

**Pair:** `/doc-audit` finds gaps; `/doc-create` fills them.

---

## Arguments

| Flag | Values | Required? | Effect |
|---|---|---|---|
| `--doc-type` | see catalogue below | yes | What kind of doc to scaffold |
| `--audience` | `buyer`, `cto`, `investor`, `technical-reviewer`, `general` | yes | Framing of the writing |
| `--path` | filesystem path | no | Override the conventional path |
| `--length` | `brief`, `standard`, `detailed` | `standard` | Roughly 200 / 600 / 1200 words |

Argument parsing is fuzzy — `/doc-create security cto brief` is fine.

---

## Doc-type catalogue

When `--doc-type` is one of these, use the conventional path and structure. For anything else, ask the user.

| `--doc-type` | Conventional path | What's in it |
|---|---|---|
| `architecture` | `docs/dev/HOW_IT_WORKS.md` or `docs/product/phase3_architecture/01_architecture.md` | System overview, components, data flow, design decisions |
| `security` | `SECURITY.md` (root) | Threat model, auth, secrets, data residency, incident response, vulnerability reporting |
| `runbook` | `docs/dev/RUNBOOK.md` | Day-2 operations: deployment, monitoring, on-call, common incidents + responses |
| `roadmap` | `ROADMAP.md` (root) or `docs/product/phase6_post_launch/01_roadmap.md` | Time-bounded milestones, "what's next" by quarter, risk register |
| `competitive` | `docs/product/phase1_strategy/05_competitive_analysis.md` | Competitor table, positioning, moat, differentiators |
| `personas` | `docs/product/phase1_strategy/04_user_personas.md` | 3-5 realistic personas with goals, pain, success |
| `business-case` | `docs/product/phase1_strategy/01_business_case.md` | Problem, solution, market sizing, business model |
| `sla` | `docs/product/phase5_deployment/SLA.md` | Uptime targets, response times, incident escalation |
| `performance` | `docs/dev/PERFORMANCE_AND_QUALITY_METRICS.md` | Measured + projected numbers, tests they're backed by, honest limitations |
| `decisions` | `docs/dev/PLATFORM_DECISIONS.md` | ADR-style decision log |
| `migrations` | `docs/dev/migrations.md` | Schema migration history + how-to |
| `contributing` | `CONTRIBUTING.md` (root) | Setup, branch model, PR rules, test expectations |
| `changelog` | `CHANGELOG.md` (root) | Keep-a-changelog format |
| `readme` | `README.md` (root) | Elevator pitch, install, run, key features, links to deeper docs |

If `--doc-type` isn't in the list, ask the user for the intended path and a one-sentence description of what should be in it.

---

## Phase 0 — Don't overwrite

If the target file already exists, **stop and ask**. Three options to offer the user:

1. `replace` — overwrite the existing file (caller confirms)
2. `append` — add a new section to the existing file at the conventional spot
3. `skip` — abort; user wants to keep what's there

Default to asking, even if `--path` was explicit. Surprising a user with a clobber is worse than asking once.

---

## Phase 1 — Read the code reality

Before writing a word, gather grounded evidence from the actual repo:

| If doc-type is… | Read this | Why |
|---|---|---|
| `architecture` | the actual source tree (`app/`, `src/`, top-level packages); `docs/dev/PRODUCTION_READINESS_PLAN.md` if present | match diagrams to reality, not aspiration |
| `security` | auth module(s) — `app/auth/`, `app/middleware/`; `requirements.txt`; `.env.example`; CI workflow; any existing security comments | describe what's actually implemented |
| `runbook` | `docker-compose.yml`, `deploy/`, `app/jobs/`, `.github/workflows/` | extract the real deployment topology |
| `roadmap` | `docs/dev/PRODUCTION_READINESS_PLAN.md`, `BACKLOG.md`, `docs/dev/BACKLOG.md` | use already-tracked plans |
| `performance` | `tests/test_*.py` files matching the claims; `tests/smoke_results/` if present; commit log | every number must point to a test or smoke run |
| `decisions` | git log for "decided", "changed approach", "switched to" commits; existing comments mentioning rationale | recover the why-trail |
| `contributing` | `.github/workflows/`, branch protection settings via `gh`, root scripts | reflect the actual workflow, not a wished-for one |
| any product-strategy doc | `docs/product/*` siblings, README, any pitch deck or business case in the repo | maintain narrative continuity |

**Rule of thumb:** if you can't cite a file or commit for a claim, don't claim it. Leave a placeholder for the user to fill in instead.

---

## Phase 2 — Audience framing

The structure is the same for a `security` doc whether it's for a `cto` or a `buyer`, but the framing differs.

| Audience | Voice | What they want at the top |
|---|---|---|
| `buyer` | plain, operational, accountability-first | concrete promises + who to call |
| `cto` | precise, mechanism-first | the architecture decision + the tradeoff |
| `investor` | crisp, defensible, milestone-anchored | the why-this-matters in 2 lines |
| `technical-reviewer` | honest, test-anchored, limitation-acknowledging | what's measured vs what's claimed |
| `general` | neutral; balance the above | depends on doc-type |

Choose the audience's top-of-doc framing and the section ordering. Don't dilute the doc with all four lenses at once.

---

## Phase 3 — Write the draft

Use the doc-type's conventional structure (catalogue above). Within each section:

- **Lead with the verifiable.** If a section makes a claim, anchor it to a file path, test name, or commit hash within the first 2 sentences.
- **Flag every gap explicitly.** Place `<!-- TODO: confirm with team -->` inline where you couldn't ground a claim. **Don't fabricate to fill space.**
- **Match the repo's existing voice.** Read 2-3 sibling docs first. If the codebase writes "Phase 5 complete (2026-05-29)", don't write "released in May 2026" — mirror the existing convention.
- **Length budget.** `brief` ≈ 200 words. `standard` ≈ 600. `detailed` ≈ 1200. Going over is fine if grounded; going over with fluff is not.

### Sections every doc-type should include (regardless of catalogue specifics)

1. **What this doc IS.** One sentence. (e.g., "This doc describes the authentication model implemented in `app/auth/`.")
2. **Body.** Per the catalogue structure for the doc-type.
3. **Open questions / TODOs.** Items you couldn't ground from the code. Tag with `<!-- TODO -->`.
4. **Last updated + source-of-truth pointer.** Date + the file(s) the reader should `git log` if they suspect drift.

---

## Phase 4 — Verify before writing

Before you write the file:

1. **Echo the plan to the user.** One paragraph: "I'm about to write `path/to/file.md` containing sections X / Y / Z, framed for audience A, length L. Grounding sources: A, B, C. Confirm to proceed."
2. **Wait for confirmation.** Don't write unprompted — the user may want to adjust audience, length, or section structure first.
3. **Use the Write tool** at the conventional path (or `--path` override).
4. **Print a tight summary** after writing: section list, grounded claims, TODOs left for the user, suggested next step (commit / open PR / iterate).

---

## Phase 5 — Hand off

End every invocation with:

```
═════════════════════════════════════════════════════════════════
  /doc-create — wrote <path>, <N> sections, <M> TODOs to fill
═════════════════════════════════════════════════════════════════

  Grounding sources used:
    - file:line
    - file:line
    - commit:short-hash

  TODOs left for you:
    - <one line per TODO>

  Suggested next step:
    - commit on a chore/docs branch and open a PR
    - or run /doc-audit on the broader doc set to see if anything
      else needs a refresh
```

---

## What NOT to do in this skill

- Don't write multiple docs in one invocation. **One doc per call.** Keeps reviews small and intent clear.
- Don't generate generic stub content. If you can't ground a section, mark it `<!-- TODO -->` and move on.
- Don't overwrite without asking (Phase 0).
- Don't merge `/doc-audit` and `/doc-create` workflows. If the audit found 5 gaps, the user runs `/doc-create` 5 times — once per doc.
- Don't write in passive voice or vague consultantese ("solutions are enabled", "best-in-class capabilities").
- Don't claim a metric, certification, or process exists if you didn't see it in the code.

---

## When in doubt — show the user the plan

If you're uncertain about audience, path, scope, or structure, **echo a one-paragraph plan and ask** before invoking Write. The user can correct cheaply at the plan stage; correcting a 1000-word draft is expensive.

---

## Footnote for me — keep this in sync

This skill is `~/.claude/commands/doc-create.md` — user-global so it applies to every project. To share with team-mates:

1. Copy to `~/product-toolkit/doc-create.md`
2. Push to `https://github.com/kish21/product-toolkit`
3. Other devs `cp product-toolkit/doc-create.md ~/.claude/commands/`

Pair: `/doc-audit` (the review half). Together they form a complete doc-quality loop:
diagnose with `/doc-audit` → fix existing with `/doc-audit --fix` → fill missing with `/doc-create`.

Date created: 2026-05-29.
