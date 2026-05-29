---
name: doc-audit
description: Grade a repository's existing documentation against the bar an external reader would actually apply (buyer / CTO / investor / technical reviewer). Use this whenever the user mentions auditing, reviewing, refreshing, or grading their docs — even if they don't say "audit". Also use when they ask "is our README current", "would a customer trust these docs", "do our docs match what we actually built". Pure REVIEW skill — does not generate missing docs; for that, invoke /doc-create.
---

# `/doc-audit` — grade existing docs against an external-reader bar

This is a **review** skill. It reads the docs that already exist, grades them, lists the gaps, and (optionally with `--fix`) opens a PR that edits the existing ones. **It does NOT create new docs** — when a category is missing, it points at `/doc-create`.

---

## Arguments

| Flag | Values | Default | Effect |
|---|---|---|---|
| `--audience` | `buyer`, `cto`, `investor`, `technical-reviewer`, `all` | `all` | Per-audience overlay (see Phase 2) |
| `--depth` | `tier1`, `tier1-2`, `full` | `tier1-2` | What's in scope (see Phase 0) |
| `--fix` | (flag) | off | After diagnosis, open a doc-refresh PR |
| `--verbose` | (flag) | off | Show per-criterion justifications, not just scores |

Argument parsing is fuzzy — `/doc-audit buyer tier1 --fix` is fine.

---

## Phase 0 — Scope detection

Find every doc in scope per the depth flag. Honor `.gitignore`. Skip `node_modules`, `venv`, `.next`, `.pytest_cache`, `dist`, `build`.

### Depth-mode targets

```
tier1     README.md
          docs/product/**/*.md
          docs/PRODUCT_OVERVIEW.md or similar front-door docs

tier1-2   tier1 +
          docs/dev/PRODUCTION_READINESS_PLAN.md (and similar roadmaps)
          docs/dev/PERFORMANCE_AND_QUALITY_METRICS.md
          docs/dev/HOW_IT_WORKS.md
          docs/dev/PLATFORM_DECISIONS.md
          docs/dev/PRODUCTION_CHECKLIST.md
          BACKLOG.md / docs/**/BACKLOG.md
          CONTRIBUTING.md
          SECURITY.md
          docs/dev/migrations.md

full      All .md files in the repo EXCEPT:
          .claude/**             — internal session state
          *_review.md            — historical review snapshots
          PLATFORM_REVIEW*.md    — point-in-time evals
          SESSION_PLAN.md, HANDOFF.md, daily_build_log.md
          *.pytest_cache/**
```

Treat the depth-mode targets as patterns, not literal filenames. Match what's actually present.

If nothing is in scope, tell the user and stop — no docs means no audit.

---

## Phase 1 — Grade each in-scope doc on 5 criteria

For each file, return a score `1–5` per criterion (5 = excellent) and a one-line justification. Read each doc fully before grading.

### The 5 criteria

| # | Criterion | What it tests | Red flags |
|---|---|---|---|
| **1** | **Currency** | Does it match `git log` reality on master? Dates recent? Recently-shipped phases / features reflected? | Status table says "Phase X planned" when commit log shows Phase X merged; "Last updated" date older than 3 commits ago on touched files |
| **2** | **Honesty** | Does it distinguish shipped from planned? Are metrics evidenced? Does it overclaim? | "100% accuracy" without a test cited; vague "production-ready"; promises that contradict the BACKLOG |
| **3** | **Jargon discipline** | Would an outsider know what this means? | Internal terms like "PR-A", "skill 02", short commit hashes, "Q09 above threshold"; no expansion on first use |
| **4** | **Evidence backing** | When a property is claimed, is there a link to a test / commit / smoke run / benchmark a reader can verify? | Headline claims with no anchor; "tested" without naming the test file |
| **5** | **Tone & cohesion** | Does the repo's doc set read like ONE product organisation, or like N sessions stapled together? | Inconsistent product name (Meridian vs Agentic Platform); mixed terminology (Phase X / PR-Y / Skill Z used interchangeably) |

A doc scoring `≤2` on any criterion is a HIGH-severity gap.

Use the per-doc table format described in Phase 4.

---

## Phase 2 — Per-audience overlay

For each `--audience` selected (default = all 4), additionally surface concerns ONLY that audience would raise. The four audiences and their unique sensitivities:

### `buyer` — procurement / RFP-evaluator
- *Will this work for my workflow?* — concrete deployment story missing?
- *Who's accountable?* — no company info, no SLA, no support contact?
- *Is my data safe?* — no data-residency, retention, or auth model?
- *What does it cost?* — no pricing or licensing story?

### `cto` — technical due diligence
- *Can it scale?* — no concurrency / throughput / latency numbers?
- *Security posture?* — no auth scheme, no secrets management, no incident-response story?
- *Team & support?* — no team-size signal, no on-call story?
- *Operational maturity?* — no runbook, no monitoring story?

### `investor` — VC / acquirer
- *Where's the moat?* — no competitive analysis, no defensibility story?
- *What's the roadmap?* — no dated milestones?
- *Risk profile?* — no honest "what could go wrong" section?
- *Traction signal?* — no customer / usage / revenue indicators (even hypothetical for early-stage)?

### `technical-reviewer` — peer engineer / external auditor
- *Are claims backed by code?* — doc says "BM25 sparse" but the source uses MD5 hashing?
- *Architecture diagrams match the tree?* — claimed modules / agents / services actually present?
- *Test coverage matches docs?* — doc says "100% determinism" but the test count is 3?
- *Are versions / dependencies current?* — doc pins libraries that have moved 2 majors?

For each finding, cite the specific doc + line, and (where possible) the contradicting code path.

---

## Phase 3 — Cross-doc cohesion checks

These are repo-wide checks that no single doc-grade catches.

1. **Date monotonicity.** Is the most recent doc the one that claims the newest version? Are stale "Last updated" dates on docs that were edited last week?
2. **Terminology consistency.** Does "Meridian" appear in some docs and "Agentic RAG Platform" in others? Is "Phase X" always used the same way (release phase vs sprint vs methodology stage)?
3. **Status agreement.** Do Phase-X status claims agree across files? (PRODUCTION_READINESS_PLAN says "Phase 3 ✅"; HOW_IT_WORKS says "Phase 3 planned" → contradiction.)
4. **Orphan references.** PR numbers / commit hashes / file paths that no longer exist?
5. **Empty links.** `[See X](X.md)` where `X.md` doesn't exist?

Report each cohesion issue with the conflicting files / lines.

---

## Phase 4 — Aggregate report

Output a single structured report. **Default mode = terse** (just the table + gap list + recommendation). **`--verbose` mode** adds per-criterion justifications.

### Terse output template

```
═════════════════════════════════════════════════════════════════
  /doc-audit — depth=tier1-2, audience=all, 14 docs in scope
═════════════════════════════════════════════════════════════════

  Per-doc grades (currency / honesty / jargon / evidence / tone)

  ✓ README.md                                  5 / 5 / 4 / 4 / 5
  ⚠ docs/product/INDEX.md                      3 / 4 / 5 / 2 / 4
  ❌ docs/dev/HOW_IT_WORKS.md                   1 / 3 / 2 / 1 / 3
  ✓ docs/dev/PRODUCTION_READINESS_PLAN.md      5 / 5 / 3 / 5 / 5
  ⚠ docs/dev/PERFORMANCE_AND_QUALITY_METRICS    4 / 4 / 4 / 3 / 4
  ...

  Gap list (ranked by severity)

  ❌ HIGH  docs/dev/HOW_IT_WORKS.md is months stale — still
          describes the pre-Phase-5 single-upload flow; no
          mention of background ingestion or autonomy modes.
  ❌ HIGH  README install steps reference `app/core/` which was
          renamed to `app/providers/` two phases ago.
  ⚠ MED   PRODUCTION_READINESS_PLAN uses unexplained "PR-A",
          "skill 02" — opaque to outside reader.
  ⚠ MED   No SECURITY.md anywhere — `cto` and `buyer` will both
          ask for it.
  💡 LOW  Product name inconsistent: "Meridian" in 8 docs,
          "Agentic Platform" in 3, "RFP evaluator" in 2.

  Per-audience flags

  [buyer]              ⚠ no SLA / support / pricing story anywhere
  [cto]                ⚠ no auth-model doc; PERFORMANCE doc
                       claims '~3-4 min for 15 vendors' without a
                       benchmark file
  [investor]           ⚠ BACKLOG is feature list, not roadmap;
                       no milestones, no risk register
  [technical-reviewer] ❌ PERFORMANCE doc claims "BM25 sparse" but
                       app/retrieval/pipeline.py:33 uses MD5
                       hashing (BACKLOG P1.12 acknowledges this
                       but the metrics doc still overclaims)

  Cohesion issues

  ❌ Phase 3 status disagrees:
         PRODUCTION_READINESS_PLAN says "✅ COMPLETE"
         HOW_IT_WORKS says "Planned"
  ⚠ Two stale dates: HOW_IT_WORKS (2026-04-12), PLATFORM_DECISIONS
    (2026-04-18) — touched in 2026-05-29 commits

  Missing doc categories

  💡 MISSING — invoke /doc-create --doc-type security --audience cto
  💡 MISSING — invoke /doc-create --doc-type runbook --audience cto
  💡 MISSING — invoke /doc-create --doc-type roadmap --audience investor

═════════════════════════════════════════════════════════════════
  RECOMMENDATION
═════════════════════════════════════════════════════════════════
  REFRESH — 5 docs need edits; no full rewrites required.
  Most urgent: HOW_IT_WORKS (stale), PERFORMANCE (overclaim).

  Next: invoke /doc-audit --fix to open the refresh PR, OR
        /doc-create for the 3 missing categories above.
```

Use `✓` / `⚠` / `❌` / `💡` consistently with `/phase-done`.

### Final recommendation line

End with ONE of:
- `READY` — all green; no edits needed
- `REFRESH` — edits sufficient; no rewrites needed
- `REGENERATE` — multiple docs need substantial rewrites; consider doing a few at a time

---

## Phase 5 — Optional `--fix` mode

Only runs if `--fix` flag was passed AND the recommendation is `REFRESH` or better.

1. Create a branch `chore/doc-audit-refresh-YYYYMMDD`
2. Apply the HIGH-severity edits in order. For each:
   - Read the current file
   - Apply the minimum edit that addresses the gap
   - **Do not rewrite from scratch** — preserve the doc's voice and structure
3. Apply the MED-severity edits the same way
4. Skip LOW edits (stylistic — usually not worth a PR on their own)
5. Commit with message `docs: refresh after /doc-audit (N HIGH, M MED gaps fixed)`
6. Push and open a PR. PR body MUST include:
   - The original audit report (table + gap list)
   - One bullet per gap addressed, with before/after snippet
   - List of LOW gaps deferred + why
   - "Missing doc categories" section pointing at `/doc-create`
7. Do NOT generate any missing-category docs in `--fix` mode. That's `/doc-create`'s job. Surface it as a follow-up suggestion.

---

## Composition with `/doc-create`

When this skill finds a MISSING category, it emits a single composition hint:

```
MISSING — invoke /doc-create --doc-type <type> --audience <audience>
```

so the user sees the natural next step. Two small skills, single responsibility each.

---

## What NOT to do in this skill

- Don't generate net-new docs (delegate to `/doc-create`)
- Don't rewrite a doc from scratch — preserve the original voice
- Don't audit `.claude/*` internal session state
- Don't grade docs you haven't read in full
- Don't fabricate evidence (if a claim isn't anchored, mark it gap-flagged; don't invent a citation)
- Don't lower the severity bar to make the report look better — better to recommend `REFRESH` honestly than to claim `READY` falsely

---

## When in doubt — defer to the user

If you're uncertain whether a doc category should be in scope, **err toward including it** for the audit phase but flagging the inclusion. The user can tell you it's out of scope; they can't tell you to look at something you skipped.

If the recommendation is borderline (a few MED gaps), tell the user the call is theirs.

---

## Footnote for me — keep this in sync

This skill is `~/.claude/commands/doc-audit.md` — user-global so it applies to every project. To share with team-mates or other projects:

1. Copy to `~/product-toolkit/doc-audit.md`
2. Push to `https://github.com/kish21/product-toolkit`
3. Other devs `cp product-toolkit/doc-audit.md ~/.claude/commands/`
4. For project-specific layered checks, create `.claude/commands/doc-audit-<project>.md` that invokes `/doc-audit` first then adds custom checks (e.g., RFP-evaluator-specific terminology rules)

Date created: 2026-05-29.
