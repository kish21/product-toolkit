---
name: new-project
description: >
  Scaffold a complete production-ready project foundation from scratch. Use this skill at
  the very start of any new project — before writing any business logic. Run when the user
  says /new-project, "start a new project", "scaffold a new app", "set up a new project",
  or "create a new app". Asks 3–5 short questions then routes to the right scaffolding
  reference and creates files. Supports: full-stack (Next.js + FastAPI), backend only
  (FastAPI), frontend only (Next.js App Router OR React + Vite). Adds optional Stripe
  billing + optional AI scaffolding (Qdrant, prompts, Modal). Uses industry-standard
  sub-package structure from day one. Never run on an existing project with code already in it.
---

# `/new-project` — production scaffold in one session

You are scaffolding a brand new production-ready project. The skill is split into a slim
orchestrator (this file) plus reference files that hold the actual file templates. Load
references only when the user's answers say you need them — that keeps context lean.

---

## STEP 1 — Pick your project shape

> **New to web apps?** Each option below has a "pick this if…" line so you can choose
> with confidence. Read the rationale; don't pick at random.

Print these questions to the user, one block at a time. Wait for ALL answers before
loading any references or writing files.

```
Before I scaffold, I need 4 short answers. Each option has a "pick this if…" line.

────────────────────────────────────────────────────────────────────────────
QUESTION 1 — What are you building?

  a) SaaS
     pick this if: you're building a product where multiple companies / teams
     sign up, each with their own users and data isolated from one another.
     Examples: Slack, Linear, Stripe Dashboard. Adds: org/users tables,
     RBAC roles, multi-tenant scoping everywhere.

  b) AI + SaaS
     pick this if: same as (a) but with an AI feature — chatbot grounded in
     customer docs, document evaluator, writing assistant.
     Adds (on top of SaaS): Qdrant vector DB, agent scaffolding,
     LangSmith prompt registry, Modal deploy config for heavier AI compute.

  c) Internal tool
     pick this if: it's for ONE company — your own team, ops, or admin
     dashboard. No paying customers, no multi-tenant isolation needed.
     Drops: billing, the multi-tenant complexity.

  d) API only
     pick this if: you're building a backend that someone else's frontend
     will call. Mobile app backend, public API for developers, integration
     service. No frontend will be scaffolded.

────────────────────────────────────────────────────────────────────────────
QUESTION 2 — What is the app name?
     Used for docker-compose service name, CLAUDE.md heading, folder name.
     Example: "meridian", "rfp-evaluator". Lowercase, hyphens or underscores
     ok, no spaces.

────────────────────────────────────────────────────────────────────────────
QUESTION 3 — Take payments from day one?

  a) Yes — scaffold Stripe webhook + subscription check now
     pick this if: you'll have paying customers from launch.
     Adds: app/api/billing_routes.py with webhook signature verification
     + subscription-active check on protected endpoints.

  b) No — skip Stripe for now
     pick this if: you're pre-revenue, internal-only, or will wire payments
     later. Easy to add via /new-project in a later session.

────────────────────────────────────────────────────────────────────────────
QUESTION 4 — What needs scaffolding?

  a) Full stack — backend (FastAPI/Python) + frontend (Next.js/React)
     pick this if: you're building a complete product end-to-end. You get
     both halves wired together with auth, theming, and CI/CD that tests
     both sides.

  b) Backend only — FastAPI/Python only, no frontend files
     pick this if: there's NO web UI to build. Pure API service. Commonly
     paired with "API only" in Question 1, but valid for any app type
     when you don't need a UI in this codebase.

  c) Frontend only — no backend at all
     pick this if: you ALREADY have a backend (Supabase, Firebase, existing
     internal API) or only need the UI half (marketing site, landing page,
     dashboard against an external API).

  → If you picked (c), one more question:

  4b. Which frontend framework?

      a) Next.js — App Router, Server Components, SSR
         pick this if: SEO matters (marketing site, public dashboard), or
         you want server-rendered pages. Heavier but more capable.

      b) React + Vite — Single-page application
         pick this if: SEO doesn't matter (admin dashboard, internal tool).
         Lighter, faster dev experience, pure client-side React.
```

Wait for all answers before proceeding to STEP 2.

---

## STEP 2 — Load references and scaffold

Based on the answers, load **only** the reference files you need. **Never load all five**
— that defeats the purpose of the split. Load on demand.

### Routing table

| User chose | Load references in this order |
|---|---|
| Full stack | `references/backend-fastapi.md` + `references/frontend-nextjs.md` + `references/claude-md-fullstack.md` |
| Full stack + Billing=Yes | + `references/optional-features.md` (billing section only) |
| Full stack + App type=AI+SaaS | + `references/optional-features.md` (AI/SaaS section: schemas, prompts, Modal) |
| Backend only | `references/backend-fastapi.md` only |
| Backend only + Billing=Yes | + `references/optional-features.md` (billing section only) |
| Backend only + App type=AI+SaaS | + `references/optional-features.md` (AI/SaaS section) |
| Frontend only → Next.js | `references/frontend-nextjs.md` only (use the standalone scaffold inside that file) |
| Frontend only → React+Vite | `references/frontend-react-vite.md` only |

Inside `references/frontend-nextjs.md` two scaffolds coexist:
- **Shared frontend components** (ErrorBoundary, EmptyState, SkeletonLoader, AuthGuard, ErrorBanner) — emit these for **Full stack** mode.
- **Standalone Next.js project scaffold** under the `FRONTEND ONLY — NEXT.JS` header — emit this whole section ONLY for **Frontend only → Next.js**, instead of the full-stack components.

### Adapting based on App type (within whichever references are loaded)

- **App type = API only** → skip every frontend file. Equivalent to `Backend only` for emission purposes.
- **App type = SaaS** → standard behaviour: emit multi-tenant tables, RBAC.
- **App type = AI + SaaS** → also emit the AI section from `optional-features.md`.
- **App type = Internal tool** → drop billing-related files even if Q3 was Yes (warn the user; ask to confirm). Drop multi-tenant org_id from the schema; single-tenant.

### Creation rules

- Substitute `<app-name>` everywhere with the user's answer to Q2.
- Create files in parallel where order doesn't matter.
- Don't ask follow-up questions during emission. If a template has a placeholder, fill it with a sensible default and surface a TODO at the end.

---

## STEP 3 — PRINT SUMMARY

After all files are created:

```
════════════════════════════════════════════
  PROJECT SCAFFOLDED — [app name]
════════════════════════════════════════════

Files created: [N]
Stack: Next.js + FastAPI + PostgreSQL + Redis

── Start in one command ────────────────────
  cp .env.example .env   # fill in your values
  make dev               # docker + migrations + seed + backend :8000
  make frontend          # Next.js :3000 (separate terminal)

── Package structure ───────────────────────
  app/auth/       JWT, RBAC, FastAPI Depends()
  app/providers/  LLM + embeddings (swap via .env)
  app/infra/      circuit breaker, rate limiter, cost tracker
  app/schemas/    Pydantic output models      [AI apps only]
  app/prompts/    LangSmith YAML prompts + registry.py  [AI apps only]
  deploy/         Modal GPU deployment        [AI apps only]
  tests/unit/     fast, no I/O
  tests/integration/  needs DB + services
  tools/          build quality: smoke_test, checkpoint_runner, push_prompts
  scripts/        ops only (seed, reset) — never test code here

── MCP servers ─────────────────────────────
  Set DATABASE_URL in .env, then:
  python .mcp/database-server.py  # Claude Code can query your DB
  python .mcp/api-server.py       # Claude Code can call your API

── What's ready ────────────────────────────
  ✅ LLM abstraction (6 providers, prompt caching on Anthropic)
  ✅ JWT auth — create_token, decode_token, require_role
  ✅ RBAC — owner/admin/member/viewer permission matrix
  ✅ Per-org rate limiting (token bucket)
  ✅ Circuit breaker
  ✅ Cost + latency tracking per agent
  ✅ CORS locked to ALLOWED_ORIGINS env var
  ✅ Dockerfile + docker-compose (Postgres + Redis + Prometheus + Grafana + Loki)
  ✅ Prometheus /metrics endpoint + fastapi_app_info metric
  ✅ Grafana at :3001, Prometheus at :9090, Loki at :3100
  ✅ Request ID middleware — every request traceable in logs
  ✅ Global error handler — consistent error shape for frontend
  ✅ PaginatedResponse — standard pagination for all list endpoints
  ✅ /api/v1/ versioning — safe to change endpoints without breaking clients
  ✅ app/validators/ — centralised input validation
  ✅ Background task pattern — no raw threading hacks
  ✅ Theme system (lib/theme.ts) — dark/light + runtime switchable
  ✅ Frontend drift detector in CI — enforces no raw hex, no fetch() in ui/
  ✅ GitHub Actions CI (ruff lint + pytest + frontend build + drift check)
  ✅ Makefile — make dev / test / lint / seed
  ✅ pyproject.toml — ruff + pytest config
  ✅ .pre-commit-config.yaml — ruff + secret scanner
  ✅ tests/unit/, tests/integration/, tests/fixtures/ — structured from day one
  ✅ tools/push_prompts.py — LangSmith prompt push with Windows SSL workaround [AI apps only]
  ✅ app/prompts/registry.py — load from LangSmith Hub with local YAML fallback [AI apps only]
  ✅ Frontend: ErrorBoundary, EmptyState, SkeletonLoader, AuthGuard
  ✅ MCP servers for DB + API
  ✅ CLAUDE.md with import rules + package structure

── ONBOARDING — do these steps in order ────

  STEP 1 — Environment (5 min)
    cp .env.example .env
    Open .env and set:
      SECRET_KEY    → run: openssl rand -hex 32
      DATABASE_URL  → postgresql://appuser:apppassword@localhost:5432/appdb
      LLM_PROVIDER  → openai  (or anthropic / ollama to start free)
      OPENAI_API_KEY → from platform.openai.com

  STEP 2 — Start services (2 min)
    docker-compose up -d
    → PostgreSQL  localhost:5432
    → Redis       localhost:6379
    → Prometheus  localhost:9090
    → Grafana     localhost:3001  (login: admin/admin — change immediately)
    → Loki        localhost:3100

  STEP 3 — Run migrations (1 min)
    alembic upgrade head

  STEP 4 — Verify foundation (1 min)
    make check
    curl http://localhost:8000/health   → must return {"status":"ok"}
    curl http://localhost:8000/metrics  → must return Prometheus text

  STEP 5 — Start frontend (separate terminal)
    cd frontend && npm install && npm run dev
    → http://localhost:3000

  STEP 6 — Audit before writing features
    Run /enterprise-ai-audit — fix any ❌ before adding business logic

── RULES — never break these ───────────────

  Backend:
  ✋ Routes in app/api/ only — no business logic in route files
  ✋ Agents call call_llm() — never import openai/anthropic directly
  ✋ SQL always parameterized — never f"SELECT {var}"
  ✋ Secrets from .env only — never hardcoded anywhere
  ✋ List endpoints use PaginatedResponse — never invent own pagination
  ✋ Input validation via app/validators/ — never ad-hoc len() in routes
  ✋ Background tasks via app/jobs/background.py — never raw threading
  ✋ Never create app/core/ — it becomes a dumping ground

  Frontend:
  ✋ CSS vars only — never a raw hex colour in any component
  ✋ Fonts via FONT/DISPLAY/MONO from lib/theme.ts — never raw strings
  ✋ All API calls via lib/api.ts — never raw fetch() in components
  ✋ components/ui/ are pure primitives — no API calls, no auth, no router
  ✋ Every input must have a label with htmlFor

════════════════════════════════════════════
```

### If "Frontend only" was chosen, print this summary instead:

```
════════════════════════════════════════════
  PROJECT SCAFFOLDED — [app name]
  Mode: Frontend only ([Next.js / React + Vite])
════════════════════════════════════════════

Files created: [N]
Stack: [Next.js 15 + Tailwind CSS v4 / React 19 + Vite 6 + Tailwind CSS v4]

── Start ───────────────────────────────────
  cp .env.example .env
  npm install
  npm run dev    # http://localhost:[3000 / 5173]

── Component structure ─────────────────────
  components/ui/       primitives (Button, Input)       [Next.js]
  src/components/ui/   primitives (Button, Input)       [Vite]
  */layout/            app chrome (Header)
  */features/          page-specific — fill this in
  lib/api.ts           fetch wrapper — always use this, never raw fetch
  src/store/auth.ts    Zustand auth store                [Vite only]

── What's ready ────────────────────────────
  ✅ Industry-standard folder structure
  ✅ TypeScript strict mode
  ✅ Tailwind CSS v4 with CSS custom properties
  ✅ Auth flow (login page + route guard)
  ✅ API fetch wrapper with Bearer token auth
  ✅ CSS custom properties — theme-ready, never raw hex
  ✅ GitHub Actions CI (type-check + build + lint)
  ✅ CLAUDE.md with structure rules

── Next steps ──────────────────────────────
  1. Fill in .env (set API URL if connecting to a backend)
  2. Build your first feature in components/features/
  3. Run /enterprise-ai-audit to check for gaps

════════════════════════════════════════════
```

### If "Backend only" was chosen, print the standard summary but replace the stack line:

```
Stack: FastAPI + PostgreSQL + Redis (no frontend)
```


---

## What NOT to do

- Don't load all references up-front. Load what the user's answers require, nothing more.
- Don't run on an existing repo. If you see existing code, stop and ask the user to confirm (e.g., empty directory check; presence of an `app/` or `frontend/` with files).
- Don't re-implement a file template inside this SKILL.md. Templates live in `references/*.md`. This file is routing logic + questions + summary only.
- Don't add billing files if the user picked "Internal tool" — these conflict. Ask before doing so.
- Don't claim a feature was scaffolded that wasn't actually written.

---

## Footnote for me — keep this in sync

This skill is `~/.claude/commands/new-project/SKILL.md` — user-global so it applies to every project.

To share with team-mates:
1. Copy the entire `new-project/` directory to `~/product-toolkit/commands/new-project/`
2. Push to https://github.com/kish21/product-toolkit
3. Other devs run the one-line installer: `curl -fsSL https://raw.githubusercontent.com/kish21/product-toolkit/master/install.sh | bash`

When you patch this skill after fixing a structural pattern on a project, update the appropriate file:
- **SKILL.md** — routing logic, question wording, summary template
- **references/backend-fastapi.md** — Python/FastAPI scaffold templates
- **references/frontend-nextjs.md** — Next.js scaffold templates
- **references/frontend-react-vite.md** — React + Vite scaffold templates
- **references/claude-md-fullstack.md** — root CLAUDE.md template
- **references/optional-features.md** — billing, AI/SaaS schemas/prompts/Modal

Date last refactored: 2026-05-29 (split from monolithic 2926-line file).
