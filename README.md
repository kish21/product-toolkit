# product-toolkit

> 8 original, interlocking Claude Code skills for the **build-and-ship** lifecycle:
> **scaffold → audit → quality-gate → ship.**

Not a grab-bag — a workflow. Every skill was hardened on a real shipping project
([agenticRag-rfp](https://github.com/kish21/agenticRag-rfp)), and the flagship scaffold has been
**runtime-tested end to end**: the generated backend boots, both frontends build, and CI passes
on the first commit.

> **Want the *whole product* arc, not just build→ship?** See its sibling
> **[product-playbook](https://github.com/kish21/product-playbook)** — a guided, step-by-step journey
> (vision → scope → … → eval → ship → learn) that *composes* engineering skills like these.
> *Rule of thumb:* reach for a **product-toolkit** skill when you know what you need; run
> **product-playbook** when you want to be walked through the full arc.

```
LIFECYCLE
  /new-project          ➜  scaffold a production-grade foundation
  /enterprise-ai-audit  ➜  score it across 8 readiness categories, auto-fix gaps
  /phase-done           ➜  11-category quality gate before every push
  /github-pr-flow       ➜  branch → PR → CI → merge

DOCS LOOP                          UI WORKFLOW
  /doc-audit   ➜ diagnose            /frontend-design  ➜ design direction + rules
  /doc-audit --fix ➜ refresh         /new-component    ➜ individual components
  /doc-create  ➜ fill gaps
```

---

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/kish21/product-toolkit/master/install.sh | bash
```

That copies everything in `commands/` into `~/.claude/commands/` — each skill becomes a global
slash command in any Claude Code session. No per-project setup. Re-running the installer is safe
(it syncs updates).

```bash
# Manual install / sync
git clone https://github.com/kish21/product-toolkit ~/product-toolkit
cd ~/product-toolkit && ./install.sh
```

---

## The flagship: `/new-project`

Asks 4 short questions (each option has a "pick this if…" rationale), then scaffolds a complete
foundation. Supports **SaaS / AI+SaaS / Internal tool / API-only** × **Full stack (FastAPI +
Next.js) / Backend only / Frontend only (Next.js or React+Vite)**, with optional **Stripe
billing** (webhook + subscription gating).

What makes it different from create-next-app or a cookiecutter:

- **Built for building with Claude.** Generates a CLAUDE.md contract (import rules, working
  rules, per-feature contracts) that keeps the agent disciplined *after* scaffolding, plus two
  MCP servers so Claude can query your dev database and call your API while you build.
- **CI that enforces its own rules.** A drift-detector job fails the build on raw hex colours,
  raw `fetch()` in UI primitives, or raw font strings — the scaffold's conventions are checked,
  not just suggested.
- **AI infrastructure from day one.** Swap LLM providers via one `.env` line (openai / anthropic /
  openrouter / ollama / azure / modal), per-agent cost + latency tracking, prompt registry with
  LangSmith + local YAML fallback.
- **Real data layer.** SQLAlchemy 2.0 typed models as single source of truth + Alembic
  migrations (initial migration included; `make migration m="..."` autogenerates from model
  changes). Multi-tenant orgs/users/audit-log schema with RBAC.
- **Runtime-tested.** The maximal scaffold (76+ files) was extracted and executed: server boots,
  `/health` + `/metrics` + JWT login verified, both frontends build, lint and tests green on
  first commit.
- Plus the hygiene you'd expect: JWT auth, per-org rate limiting, validators, pagination,
  Docker + compose, Prometheus metrics, pre-commit with secret scanning, structured test dirs,
  Makefile single entrypoint.

It's split into a slim orchestrator + 5 reference files, so each invocation loads only the
templates your answers require (a "Frontend only" run never pays for Python templates).

---

## Skill catalogue

| Skill | When to invoke | What it outputs |
|---|---|---|
| **`/new-project`** | Starting a fresh project | Complete tested scaffold — see above |
| **`/enterprise-ai-audit`** | "Are we production ready?" on any AI project | 8-category score card (LLM abstraction, data layer incl. migrations, security, testing, deployment, observability, frontend, cost controls) + Claude-specific bonuses + auto-created boilerplate for gaps |
| **`/phase-done`** | After every phase commit, before push | 11-category report: code quality, deprecated patterns, hygiene, docs, memory, feature suggestions, pre-push secrets scan, deferred-work tracking, branch freshness, CI parity, PR-overwrite safety → `READY TO PUSH` / `FIX FIRST` / `REVIEW WARNINGS` |
| **`/doc-audit`** | "Are our docs current? Would a CTO trust this README?" | Per-doc grades (currency / honesty / jargon / evidence / tone) × 4 audiences (buyer / CTO / investor / technical reviewer) + gap list; `--fix` opens a refresh PR |
| **`/doc-create`** | A doc is missing (often flagged by `/doc-audit`) | ONE new doc grounded in actual code state — never generic templates, every claim cited or marked TODO |
| **`/frontend-design`** | Building any page, dashboard, or UI section | Design direction + production-grade code avoiding generic AI aesthetics |
| **`/new-component`** | Building any single React component | Component enforcing CSS-variable tokens, full interactive states, accessibility |
| **`/github-pr-flow`** | Pushing to a protected main/master | Branch naming, PR with summary + test plan, CI failure handling, safe conflict resolution |

### Pairs well with (Anthropic-published skills — not bundled here)

This toolkit deliberately ships only original skills. For these adjacent needs, use Anthropic's
own published skills: **skill-creator** (author new skills), **anti-ai-ui** (final UI audit —
the natural third step after `/frontend-design` → `/new-component`), **mcp-builder**,
**theme-factory**, **web-artifacts-builder**. Several ship with the Claude apps / Anthropic
skills plugin.

---

## Distribution

The one-line installer is the simplest path today. The repo is also structured for Claude Code's
plugin format (self-contained skill files with frontmatter, `manifest.json`, directory-form
skills with progressive disclosure) — packaging it as an installable plugin for a team
marketplace is mechanical.

---

## Adding a new skill

```bash
vim commands/your-skill-name.md          # 1. create (YAML frontmatter: name, description)
cp commands/your-skill-name.md ~/.claude/commands/   # 2. install locally
# 3. update README catalogue + manifest.json, then commit & push
```

---

## Provenance

Every skill here was distilled from real shipping work, and the lineage is preserved in each
file's footnote. Notable: `/phase-done` came out of PR #150 on agenticRag-rfp surfacing three
systemic bug classes (branch drift, CI parity, PR metadata overwrites); `/new-project` has been
through 7+ patch rounds including a full consistency review and runtime test (2026-06-04) — the
changelog lives in its SKILL.md footnote.

---

**License:** MIT · **Author:** [@kish21](https://github.com/kish21)
