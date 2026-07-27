# References - root CLAUDE.md for full-stack projects

Loaded ONLY when the user picks **Full stack**. Single root CLAUDE.md template.
Frontend-only modes emit their own CLAUDE.md inside their respective reference file.

---

### `CLAUDE.md`
Generate a CLAUDE.md using this template, filling in the app name:

```markdown
# CLAUDE.md — [APP NAME]

## THIS PROJECT
**Product:** [APP NAME]
**Stack:** Next.js + FastAPI + PostgreSQL + Redis
**LLM:** Configurable via LLM_PROVIDER in .env (openai | anthropic | openrouter | ollama | azure | modal)

## SESSION START — MANDATORY
```bash
make check    # confirm imports ok + unit tests passing
docker-compose ps  # confirm services running
```

## DEV
```bash
make dev      # starts backend on :8000 (docker services + alembic migrations + seed)
make migration m="add x"  # autogenerate migration from app/db/models.py changes
make frontend # starts Next.js on :3000
make test     # unit + integration tests
make lint     # ruff + eslint
```

## PACKAGE STRUCTURE — NEVER FLATTEN INTO core/
```
app/
├── api/         ← routes only. Import from auth/, providers/, infra/
├── auth/        ← jwt.py, rbac.py, dependencies.py
├── providers/   ← llm.py, embedding.py  — swap via .env, never hardcode
├── infra/       ← circuit_breaker.py, rate_limiter.py, cost_tracker.py, pagination.py
├── validators/  ← centralised input validation — never ad-hoc checks in routes
├── schemas/     ← Pydantic output models (AI apps)
├── prompts/     ← LangSmith YAML prompts + registry.py (AI apps)
├── db/          ← models.py (SQLAlchemy — single source of truth), base.py (engine + get_db)
└── jobs/        ← scheduled work + background tasks
(migrations/ at repo root — Alembic, autogenerates from models.py)
```

## IMPORT RULES
- Routes import from `app.auth.*`, `app.providers.*`, `app.infra.*`
- Agents call `call_llm()` from `app.providers.llm` — never import openai/anthropic directly
- Never create `app/core/` — it becomes a dumping ground

## TYPESCRIPT TYPE RULES — SINGLE SOURCE OF TRUTH
1. Any interface used by 2+ files → lives in `types.ts`, never duplicated
2. Feature modules with 2+ sub-components get a `_components/` folder containing:
   - `types.ts`   — all shared interfaces and union types
   - `styles.ts`  — style objects and style helper functions
   - `helpers.ts` — pure utility functions (no JSX)
3. Union types / type aliases → `types.ts` only, never inside `styles.ts` or `helpers.ts`
4. No workaround types (duck types, partial re-definitions) — fix the import graph instead

## COMPONENT CONTRACTS
1. CORS locked to ALLOWED_ORIGINS env var — never "*"
2. Rate limiting is per-org — never a global singleton
3. All secrets from env vars — no hardcoded values in any file
4. SQL queries parameterized — never f-string SQL
5. Frontend: CSS vars only — never raw hex colours
6. Agent outputs are Pydantic models — never raw text between agents
7. Any React component used in 2+ files → extract to shared file before copy-pasting
8. Small shared UI helpers (ErrorBanner, Spinner, LoadingState) → `components/ui/`, never inlined

## SCOPE RULES
**Allowed:** Build features, fix bugs, write tests
**Ask first:** Installing new packages, changing DB schema, modifying auth

## WORKING RULES
**Standard workflow (every non-trivial task):** 1) architect first (how it *should* be built), 2) verify against real code/running system + the project's own design docs, 3) plan with NO hardcoding — values in config or `.env`, 4) benchmark to the current year ("is this at par with how product companies build it now?") + prefer the best open-source tool, then act, 5) DEEP self-review (code-review, exit criteria, perf, unit+integration tests; security-review on auth/data) before "done".
**Per-feature contract (define BEFORE coding):** exit criteria (testable definition of done) · module-interaction map (typed contracts in/out + dependencies) · independent test plan (unit + integration + other). Can't test it independently → fix the seams first.
**Architecture bar:** modular/single-responsibility · layered & decoupled (deps point inward; typed contracts at boundaries, never raw dict/text) · provider/adapter for ALL externals (config-selected, no vendor SDK in business logic) · intention-revealing naming · testable-by-construction · change-safely (migrations, backward-compat, structured logging).
**Production safeguards:** no secrets in source (gitleaks) + authz/tenant checks on every data path + input validation + security-review on auth/data · structured logging + trace external/LLM steps + audit state changes · graceful fallbacks, fail-CLOSED on security, never swallow errors · perf + cost budgets in the exit criteria where relevant.
**Documentation-driven dev:** before a big task create a design doc in `docs/` (plan + per-feature contract + decisions); on completion reconcile code ↔ doc (record intentional drift + reason); **a big task is NOT pushed/merged until its doc matches reality** (big-task level, not every subtask) — so `docs/` always shows what was built / pending / why.
**Review & vision (top priority):** reviews are DEEP not overviews (read real code paths, end with confidence + evidence); no assumptions or silent drift; honesty always; continually ask "does this serve THIS project's vision/direction?" (read it from this CLAUDE.md) and surface misalignment.
**Confidence score:** when a subtask/feature is done, report a Confidence Score (0–100%) vs the exit criteria — solid / risky-untested / to-raise.
**Session boundaries:** one subtask per session. When a subtask is done, BEFORE suggesting a new session: (1) open a GitHub PR, (2) update this CLAUDE.md's build-state + NEXT SESSION PLAN for a clean handoff, then explicitly tell the user to start a new session. Don't finish a whole feature in one session.
**Session economy (token cost):** agent-session cost grows ~quadratically with session length — every API call re-reads the full conversation history, so the boundary rule above is a COST rule, not just a focus rule. At a natural checkpoint prefer handoff + fresh session over pushing on; run `/compact` after a closed debugging detour whose detail is no longer needed; keep bulky tool output (test logs, scrapes, JSON dumps) in files, not chat; delegate broad code searches to subagents that return conclusions; use a cheaper model tier for purely mechanical sessions (docs, changelog, config edits). *(Measured on a real project, 2026-07: 97% of a ~$2,900-API-equivalent month was cache re-reads from 600–900-call sessions — generated code was only a few percent.)*
**Secret files:** `.env` and secret/credential files are the USER's to edit — hand them the exact lines, never hand-edit `.env`. Back up before any risky write.

## KNOWN FIXES — DO NOT REVERT
(Record discovered bugs and fixed patterns here so they are never accidentally reverted.
Format: what was wrong → what the fix is → which files it applies to.)
```
- localStorage draft for forms with file inputs: File objects cannot be serialized.
  Wrong: saving the entire form state including File refs → silently stores undefined.
  Fix: save only string/number/select fields; on restore show "files not saved" notice
  with a Clear button; call clearDraft() on successful submit.
  Applies to: any multi-field upload form.

- Debounced auto-save with useRef timer: calling localStorage.setItem inside a useEffect
  on every keystroke hammers storage and causes stale-closure bugs.
  Fix: use useRef<ReturnType<typeof setTimeout>|null>(null); clear previous timer in
  effect body, set new timer (800ms), return cleanup that clears it.
  Applies to: any form with auto-save behaviour.
```

---

