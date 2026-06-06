# Enterprise AI Project Audit

You are running a production-readiness audit on the current project. Follow these three phases in order.

---

## PHASE 1 — SCAN

Run these checks using Glob and Grep. Do all checks in parallel for speed.

### Category 1: LLM Abstraction
- Does a `call_llm()` wrapper exist? (grep for `def call_llm` or `async def call_llm`)
- Does it support streaming? (grep for `stream=True` or `async for chunk`)
- Does it have retry/backoff? (grep for `exponential_backoff` or `tenacity` or `max_retries`)
- Does a circuit breaker exist? (glob for `circuit_breaker.py`)
- Is `LLM_PROVIDER` in `.env` or config? (grep for `LLM_PROVIDER`)
- Is `EMBEDDING_PROVIDER` abstracted? (grep for `EMBEDDING_PROVIDER`)
- Are provider SDKs imported directly in agent files? (grep agent files for `import openai` or `import anthropic` — should only appear in the provider wrapper, not agents)

### Category 2: Data Layer
- Is there a vector store client? (glob for `qdrant_client.py` or `chroma` or `pinecone`)
- Is there a relational DB for structured facts? (glob for `schema.sql` or `models.py` or `alembic`)
- Do agent output models extend Pydantic BaseModel? (grep for `class.*Output.*BaseModel` or `class.*Result.*BaseModel`)
- Is org_id filtering applied on queries? (grep for `org_id` in query files)
- Is there a GDPR right-to-deletion / data-subject path? (grep for `erase`/`delete_org`/`anonymize`/`gdpr`). Two DISTINCT modes — don't conflate: (a) **tenant erasure** (customer offboards → wipe the whole tenant across every store: relational rows, vectors, on-disk files, caches) and (b) **subject anonymization** (one person asks → scrub their PII but KEEP business/audit records under the legal-retention exemption). If a FK-ordered purge list exists, is there a **schema-drift guard test** asserting every table with an `org_id` column is covered (so a new table can't silently survive a "complete" wipe)? Is a retained, anonymized **erasure receipt** written as proof (it must survive the delete — i.e. no FK to the parent tenant row)?

### Category 3: Security
- Is there input length validation on text fields? (grep for `max_length` or `len(` in route files)
- Is rate limiting per-org? (grep for `org_id` in rate_limiter files — global singleton is a gap)
- Are there hardcoded secrets? (grep for `password =` or `secret =` or `api_key =` as string literals in Python files — exclude .env and test files)
- Is CORS locked? (grep for `allow_origins` — `["*"]` is a gap)
- Are SQL queries parameterized? (grep for `f"SELECT` or `f"INSERT` — f-string SQL is a gap)

### Category 4: Testing
- Do unit tests exist? (glob for `tests/unit/**/*.py` or `test_*.py`)
- Do integration tests exist? (glob for `tests/integration/**/*.py`)
- Does a regression test exist? (glob for `tests/regression/**/*.py`)
- Is there a CI config? (glob for `.github/workflows/*.yml`)
- Does CI run backend tests? (grep `.github/workflows/*.yml` for `pytest`)

### Category 5: Deployment
- Does a Dockerfile exist? (glob for `Dockerfile`)
- Does Docker Compose include the app service? (grep `docker-compose.yml` for the app service name — not just DB/vector store)
- Is there a health check endpoint? (grep for `/health` in route files)

### Category 6: Observability
- Is there structured logging with context fields? (grep for `request_id` or `org_id` in log statements)
- Is cost tracked per agent per run? (glob for `cost_tracker.py`)
- Is latency tracked per agent? (grep for `latency_ms` or `duration_ms`)
- Is there a cost summary API endpoint? (grep routes for `costs` or `cost_summary`)
- Is there error alerting? (grep for `slack` or `pagerduty` or `alert` in observability files)

### Category 7: Frontend (skip if no `frontend/` directory)
- Does an ErrorBoundary component exist? (glob for `ErrorBoundary.tsx`)
- Does an EmptyState component exist? (glob for `EmptyState.tsx`)
- Does a skeleton loader exist? (glob for `Skeleton*.tsx` or `SkeletonLoader.tsx`)
- Do buttons have loading states? (grep for `loading` prop in Button component)
- Are form inputs labeled? (grep frontend for `htmlFor`)

### Category 8: Cost Controls
- Is there a pre-run cost estimate shown to the user? (grep for `estimate` near evaluation start routes)
- Is there a per-org spend cap? (grep for `max_spend` or `budget` in config/org settings)
- Is cost breakdown visible in UI? (grep frontend for `cost` or `spend`)

---

## PHASE 2 — REPORT

Print the score card using this exact format:

```
════════════════════════════════════════════════
  ENTERPRISE AI AUDIT — [Project Name]
════════════════════════════════════════════════

SECTION A — UNIVERSAL BEST PRACTICES
──────────────────────────────────────

1. LLM ABSTRACTION
   ✅ call_llm() wrapper exists
   ✅ LLM_PROVIDER abstracted
   ❌ Streaming not implemented
   ❌ Circuit breaker missing
   ✅ Retry/backoff present
   ✅ EMBEDDING_PROVIDER abstracted
   ⚠️  Provider SDK imported directly in 2 agent files

2. DATA LAYER   ...
3. SECURITY     ...
4. TESTING      ...
5. DEPLOYMENT   ...
6. OBSERVABILITY ...
7. FRONTEND     ...
8. COST CONTROLS ...

──────────────────────────────────────
SCORE: X/Y checks passed

SECTION B — CLAUDE-ONLY BONUSES
──────────────────────────────────────
(Only relevant when LLM_PROVIDER=anthropic — zero changes needed for other providers)

❌ Prompt caching — system prompts re-sent on every call (60–90% cost saving)
❌ Extended thinking — reasoning-heavy agents would benefit
❌ Native Citations API — build grounding natively instead of custom system
❌ Batch API — bulk operations could run at 50% cost async
❌ Token counting pre-flight — estimate cost before sending

──────────────────────────────────────
FIXING: [N] items now. SKIPPING: [M] items (need your decision).
════════════════════════════════════════════════
```

After printing the report, immediately proceed to Phase 3 without waiting.

---

## PHASE 3 — FIX

For each ❌ item (except REVIEW REQUIRED), create the minimal boilerplate. Do all file creations in parallel.

**circuit_breaker.py** — create `app/core/circuit_breaker.py` with open/half-open/closed state machine using threading.Lock

**Dockerfile** — create at project root with python:3.11-slim, HEALTHCHECK, uvicorn CMD

**Health check** — add `@app.get("/health")` returning `{"status": "ok"}` to main FastAPI file

**GitHub Actions pytest** — add backend-tests job to `.github/workflows/ci.yml` running `pytest tests/ -v --tb=short`

**ErrorBoundary** — create `frontend/components/ErrorBoundary.tsx` as React class component with getDerivedStateFromError, using `var(--color-error)` for fallback UI

**EmptyState** — create `frontend/components/EmptyState.tsx` with title/description/action/icon props, using FONT/DISPLAY from `@/lib/theme` and CSS vars only

**SkeletonLoader** — create `frontend/components/SkeletonLoader.tsx` with Skeleton + SkeletonText exports, gradient shimmer animation via CSS var colors; add `@keyframes skeleton-shimmer` to globals.css

**Prompt caching** — in the Anthropic branch of `llm_provider.py`, add `cache_control: {"type": "ephemeral"}` to system prompt content block and use `client.beta.prompt_caching.messages.create()`

---

## ITEMS THAT NEED YOUR DECISION (never auto-fix)

List these as REVIEW REQUIRED after fixes:
- CORS `allow_origins=["*"]` — lock to explicit domain list
- Hardcoded default secrets — enforce non-empty via startup validation
- Per-org rate limiting — global singleton needs architectural decision
- Error alerting — choose Slack/PagerDuty/email destination
- Cost caps per org — needs org_settings schema decision

---

## AFTER FIXING

```
FIXED [N] items automatically.
[N] items need your decision (listed above).
Section B Claude bonuses: 5 available if LLM_PROVIDER=anthropic.

New files created: [list]
Files patched: [list]
```
