# product-toolkit

> Personal Claude Code skills library — reusable slash commands for shipping production-grade products fast.

**13 skills**, installable in any project, refined from real shipping work on the [agenticRag-rfp](https://github.com/kish21/agenticRag-rfp) project.

---

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/kish21/product-toolkit/master/install.sh | bash
```

That copies every `.md` from `commands/` into `~/.claude/commands/`. Every skill becomes available globally as a slash command in any Claude Code session — **no per-project setup**.

### Or install manually

```bash
git clone https://github.com/kish21/product-toolkit ~/product-toolkit
cp ~/product-toolkit/commands/*.md ~/.claude/commands/
```

### Sync after the toolkit updates

```bash
cd ~/product-toolkit && git pull && cp commands/*.md ~/.claude/commands/
```

---

## Skill catalogue

| Skill | When to invoke | What it outputs | Lives in |
|---|---|---|---|
| **`/new-project`** | Starting a fresh project; user says "scaffold a new app" | Complete project scaffold — LLM abstraction, auth, security, CI/CD, frontend skeleton, CLAUDE.md. Asks 4 questions first. **Supports:** SaaS / AI+SaaS / Internal tool / API-only × Full stack / Backend only / Frontend only (Next.js OR React+Vite) + optional Stripe billing. | `commands/new-project/` (directory: slim SKILL.md + 5 references — see below) |
| **`/enterprise-ai-audit`** | "Are we production ready?", "what are we missing?" — pre-launch health check on any AI project | 8-category score card (LLM abstraction, security, testing, deployment, observability, frontend, cost, Claude bonus features) + auto-creates missing boilerplate | `commands/enterprise-ai-audit.md` |
| **`/phase-done`** | After every phase commit, **before push** — end-of-phase quality gate | 11-category report (code quality, architecture, hygiene, docs, memory writes, feature suggestions, pre-push hygiene, deferred work, branch freshness, CI parity, PR pre-creation audit) + `READY TO PUSH` / `FIX FIRST` / `REVIEW WARNINGS` | `commands/phase-done.md` |
| **`/doc-audit`** | "Are our docs current?", "would a CTO trust this README?" | Per-doc grade table (currency / honesty / jargon / evidence / tone) × 4 audiences (buyer / CTO / investor / technical reviewer) + gap list + `READY` / `REFRESH` / `REGENERATE` recommendation. `--fix` opens refresh PR. | `commands/doc-audit.md` |
| **`/doc-create`** | When `/doc-audit` flags a MISSING category, or "we should write a SECURITY.md" | ONE new doc grounded in actual code state (not generic templates). Catalogue: architecture, security, runbook, roadmap, competitive, personas, business-case, sla, performance, decisions, migrations, contributing, changelog, readme | `commands/doc-create.md` |
| **`/frontend-design`** | Building any page, dashboard, or UI section from scratch | Design proposal + production-grade frontend code that avoids generic AI aesthetics (typography, depth/shadow, anti-template guardrails) | `commands/frontend-design.md` |
| **`/new-component`** | Building any single React component (button, card, form, modal, table) | Component file enforcing CSS variables only, full interactive states (hover/focus/active), accessibility, design system constraints | `commands/new-component.md` |
| **`/anti-ai-ui`** | Before delivering ANY frontend work — final UI check | 12-tell audit (flat shadows, uniform font weights, generic blue palette, missing states, etc.) + flag/fix anything template-generated | `commands/anti-ai-ui.md` |
| **`/theme-factory`** | Styling any visual artifact (slides, HTML pages, reports) | Themed output via pre-set themes or generated custom themes | `commands/theme-factory.md` |
| **`/web-artifacts-builder`** | Complex multi-component HTML artifact (state management, routing, component library) | React + Tailwind + shadcn/ui artifact with the right structure | `commands/web-artifacts-builder.md` |
| **`/github-pr-flow`** | Pushing to a protected main/master branch | Branch creation, PR with proper title/body, CI failure handling, merge conflict resolution | `commands/github-pr-flow.md` |
| **`/mcp-builder`** | Connecting Claude Code to an external service via MCP | High-quality MCP server (Python FastMCP or TypeScript MCP SDK) with proper tool design | `commands/mcp-builder.md` |
| **`/skill-creator`** | Building a new skill, improving an existing skill, or running skill evaluations | New / improved skill file in `~/.claude/commands/` + eval workspace + benchmark | `commands/skill-creator.md` |

### `/new-project` — what it actually scaffolds (read this if you're new to web apps)

`/new-project` asks **4 short questions** and routes you down one of these paths. Each option has a "pick this if…" rationale so you can choose with confidence.

#### Question 1 — what ARE you building?

| Choice | Pick this if… | Adds to the scaffold |
|---|---|---|
| **SaaS** | Multiple companies/teams sign up, each with their own users and data (Slack, Linear, Stripe Dashboard) | org/users tables, RBAC roles, multi-tenant scoping everywhere |
| **AI + SaaS** | Same as SaaS but with an AI feature — chatbot grounded in user docs, document evaluator, writing assistant | Above + Qdrant vector DB + agent scaffolding + LangSmith prompt registry + Modal deploy config |
| **Internal tool** | One company only — your team, ops, or admin dashboard. No paying customers | Drops billing + multi-tenant complexity |
| **API only** | A backend that someone else's frontend will call (mobile, public API, integration service) | No frontend scaffolded at all |

#### Question 3 — payments from day one?

| Choice | Pick this if… | Adds |
|---|---|---|
| **Yes** | You'll have paying customers from launch | Stripe webhook + subscription check on protected endpoints |
| **No** | Pre-revenue or internal-only | Skipped (easy to add later) |

#### Question 4 — what needs scaffolding?

| Choice | Pick this if… | What gets created |
|---|---|---|
| **Full stack** | Building a complete product end-to-end | Backend (FastAPI) + Frontend (Next.js) + CI/CD for both |
| **Backend only** | No web UI in this codebase | Just FastAPI — no frontend files |
| **Frontend only → Next.js** | You already have a backend (Supabase, Firebase, existing API) AND SEO matters | Next.js standalone project |
| **Frontend only → React + Vite** | Same as above but SEO doesn't matter (admin dashboard, internal tool) | React + Vite SPA |

#### Why the skill is split into 5 reference files

`/new-project` used to be one 2,926-line file — every invocation paid the cost of loading Python templates even when you picked "Frontend only". Now the slim orchestrator (~345 lines) loads ONLY the references your answers need:

| Your choice | References loaded |
|---|---|
| Full stack | `backend-fastapi.md` + `frontend-nextjs.md` + `claude-md-fullstack.md` |
| Backend only | `backend-fastapi.md` only |
| Frontend only → Next.js | `frontend-nextjs.md` only |
| Frontend only → React + Vite | `frontend-react-vite.md` only |
| + Billing or AI+SaaS (any) | + `optional-features.md` |

Smaller context = faster + cheaper invocations + clearer maintenance.

### How they compose

```
NEW PROJECT FLOW
    /new-project   ➜  scaffold full project
        ➜  /enterprise-ai-audit  ➜  verify all 8 categories covered

DOC QUALITY LOOP
    /doc-audit          ➜  diagnose existing docs
    /doc-audit --fix    ➜  refresh existing docs
    /doc-create         ➜  scaffold missing docs (one per call)

UI WORKFLOW
    /frontend-design    ➜  layout + design proposal
    /new-component      ➜  individual components
    /anti-ai-ui         ➜  final audit before delivery

SHIPPING FLOW
    /phase-done         ➜  pre-push quality gate
    /github-pr-flow     ➜  branch → PR → CI → merge

EXTENDING
    /skill-creator      ➜  build new skills or improve existing
    /mcp-builder        ➜  add tool integrations
    /theme-factory      ➜  style any visual artifact
```

---

## Distribution & plugin status

Claude Code's plugin marketplace is still evolving. **As of 2026-05-29, the canonical install path is to drop `.md` files into `~/.claude/commands/`** — which is what `install.sh` does for you.

The repo is **structurally plugin-ready**:

- Each skill is a self-contained file with YAML frontmatter (`name`, `description`)
- `install.sh` provides a one-line bootstrap
- `manifest.json` declares the toolkit contents in a forward-compatible format so when Anthropic ships an official plugin manifest standard, the upgrade is mechanical

**Want to ship this as a plugin to your team?** Fork the repo; everyone runs the one-line installer. That's the distribution model that works today.

---

## Adding a new skill

```bash
# 1. Create the skill
vim commands/your-skill-name.md

# 2. Install locally + add to git
cp commands/your-skill-name.md ~/.claude/commands/
git add commands/your-skill-name.md README.md manifest.json
git commit -m "feat: add /your-skill-name skill"
git push
```

Update this README's catalogue table AND `manifest.json`'s `commands` list when you add a skill.

---

## Provenance

Each skill in this toolkit was hardened on a real project before landing here. The provenance is preserved in the skill file's footnote section. Notable origins:

- `/phase-done` — distilled from the agenticRag-rfp project after PR #150 surfaced 3 systemic bug classes (branch drift, CI parity gaps, PR metadata overwrites)
- `/doc-audit` + `/doc-create` — created on agenticRag-rfp on 2026-05-29 after a reviewer-feedback round revealed several docs had drifted from master
- `/new-project` — refined through 5 patches from agenticRag-rfp build learnings

---

**License:** MIT (do whatever you want with these skills) · **Author:** [@kish21](https://github.com/kish21)
