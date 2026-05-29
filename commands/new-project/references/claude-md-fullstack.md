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
make dev      # starts backend on :8000 (runs docker, migrations, seed)
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
├── infra/       ← circuit_breaker.py, rate_limiter.py, cost_tracker.py
├── schemas/     ← Pydantic output models (AI apps)
├── db/          ← schema, fact_store
└── jobs/        ← scheduled work
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

