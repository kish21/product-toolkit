---
name: enterprise-ai-audit
description: >
  Audit and auto-fix an enterprise AI project for production readiness gaps. Use this skill
  whenever the user asks to audit their AI project, check what's missing, start a new AI
  project and wants to validate completeness, says "are we production ready", "what are we
  missing", "audit my project", or runs /enterprise-ai-audit. Scans the codebase across 8
  categories, prints a score card, auto-creates missing boilerplate files, and shows
  Claude-specific bonus features in a separate section. Works for any AI project regardless
  of which LLM provider is used.
---

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
- Is there a relational DB for structured facts? (glob for `models.py` or `schema.sql` or `alembic.ini`)
- Are schema changes versioned? (glob for `migrations/versions/*.py` or `alembic.ini` — raw DDL with no migration history is a gap)
- Do agent output models extend Pydantic BaseModel? (grep for `class.*Output.*BaseModel` or `class.*Result.*BaseModel`)
- Is org_id filtering applied on queries? (grep for `org_id` in query files)
- Is there a GDPR right-to-deletion / data-subject path? (grep for `erase`/`delete_org`/`anonymize`/`gdpr`). Two DISTINCT modes — don't conflate: (a) **tenant erasure** (customer offboards → wipe the whole tenant across every store: relational rows, vectors, on-disk files, caches) and (b) **subject anonymization** (one person asks → scrub their PII but KEEP business/audit records under the legal-retention exemption). If a FK-ordered purge list exists, is there a **schema-drift guard test** asserting every table with an `org_id` column is covered (so a new table can't silently survive a "complete" wipe)? Is a retained, anonymized **erasure receipt** written as proof (it must survive the delete — i.e. no FK to the parent tenant row)?

### Category 3: Security
- Is there input length validation on text fields? (grep for `max_length` or `len(` in route files)
- Is rate limiting per-org? (grep for `org_id` in rate_limiter files — global singleton is a gap)
- Are there hardcoded secrets? (grep for `password =` or `secret =` or `api_key =` as string literals in Python files — exclude .env and test files)
- Is CORS locked? (grep for `allow_origins` — `["*"]` is a gap)
- Are SQL queries parameterized? (grep for `f"SELECT` or `f"INSERT` — f-string SQL is a gap)
- **For AI products ingesting untrusted documents/user content: is there a prompt-injection scan before content reaches the LLM?** (grep `app/validators/` or the critic/guardrail layer for injection-pattern scanning; check the ingestion path scans untrusted chunks but exempts trusted first-party inputs) — absence is a gap (**OWASP LLM01**, the #1 AI-specific risk). The scan must be config-driven (patterns in config, not hardcoded) and fail-CLOSED (a match blocks the pipeline, never silently drops).

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
- Is `prometheus-fastapi-instrumentator` in requirements.txt? (grep for `prometheus-fastapi-instrumentator`)
- Is the `/metrics` endpoint exposed? (grep for `Instrumentator` in main.py)
- Are Prometheus + Grafana in docker-compose? (grep `docker-compose.yml` for `prom/prometheus`)

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

2. DATA LAYER
   ...

3. SECURITY
   ...  [flag "⚠️ REVIEW REQUIRED — human decision needed" for CORS and secrets]

4. TESTING
   ...

5. DEPLOYMENT
   ...

6. OBSERVABILITY
   ...

7. FRONTEND
   ...  [skip with note if no frontend/ directory]

8. COST CONTROLS
   ...

──────────────────────────────────────
SCORE: X/Y checks passed

SECTION B — CLAUDE-ONLY BONUSES
──────────────────────────────────────
(These only apply if LLM_PROVIDER=anthropic is set or planned)

❌ Prompt caching — long system prompts re-sent on every call (60–90% cost saving available)
❌ Extended thinking — reasoning-heavy agents (Decision, Comparator) would benefit
❌ Native Citations API — you built custom grounding; Claude can do this natively
❌ Batch API — bulk/non-real-time operations run at standard latency and cost
❌ Token counting pre-flight — no cost estimate before sending expensive calls

──────────────────────────────────────
FIXING: [N] items now. SKIPPING: [M] items (need your decision — listed below).
════════════════════════════════════════════════
```

After printing the report, immediately proceed to Phase 3 without waiting.

---

## PHASE 3 — FIX

For each ❌ item (except those marked REVIEW REQUIRED), create the minimal boilerplate. Do all file creations in parallel.

**Consistency rule:** if the project was scaffolded by `/new-project`, follow its conventions —
infrastructure code goes in `app/infra/` (NEVER `app/core/` — that violates the scaffold's
CLAUDE.md rules), frontend components in `frontend/components/`, colours via `var(--color-*)`
tokens. When in doubt, match the structure already present in the repo.

### circuit_breaker.py (if missing)
Create `app/infra/circuit_breaker.py` (fall back to the project's infra/utils package if the
layout differs — never create `app/core/`):
```python
import time
from enum import Enum
from threading import Lock

class State(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: int = 60):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.last_failure_time = None
        self.state = State.CLOSED
        self._lock = Lock()

    def call(self, func, *args, **kwargs):
        with self._lock:
            if self.state == State.OPEN:
                if time.time() - self.last_failure_time > self.recovery_timeout:
                    self.state = State.HALF_OPEN
                else:
                    raise RuntimeError("Circuit breaker is OPEN — service unavailable")
        try:
            result = func(*args, **kwargs)
            with self._lock:
                self.failure_count = 0
                self.state = State.CLOSED
            return result
        except Exception as e:
            with self._lock:
                self.failure_count += 1
                self.last_failure_time = time.time()
                if self.failure_count >= self.failure_threshold:
                    self.state = State.OPEN
            raise
```

### Dockerfile (if missing)
Create `Dockerfile` at project root:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Health check endpoint (if missing)
Add to the main FastAPI app file:
```python
@app.get("/health")
async def health_check():
    return {"status": "ok", "version": settings.app_version}
```

### GitHub Actions CI (if missing or backend tests not in CI)
Create `.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -r requirements.txt
      - run: pytest tests/ -v --tb=short

  frontend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      # use npm ci ONLY if package-lock.json is committed; otherwise npm install
      - run: npm ci || npm install
      - run: npm run build
      - run: npm run lint
```

### ErrorBoundary (if frontend exists and missing)
Create `frontend/components/ErrorBoundary.tsx`:
```tsx
"use client";
import React from "react";

interface Props {
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div style={{ padding: "2rem", color: "var(--color-error)" }}>
          <p>Something went wrong. Please refresh the page.</p>
        </div>
      );
    }
    return this.props.children;
  }
}
```

### EmptyState (if frontend exists and missing)
Create `frontend/components/EmptyState.tsx` — uses CSS variables directly so it works on ANY
project (no `@/lib/theme` import, which only exists in /new-project scaffolds):
```tsx
interface Props {
  title: string;
  description?: string;
  action?: React.ReactNode;
  icon?: React.ReactNode;
}

export function EmptyState({ title, description, action, icon }: Props) {
  return (
    <div style={{
      display: "flex", flexDirection: "column", alignItems: "center",
      justifyContent: "center", padding: "4rem 2rem", gap: "1rem",
      color: "var(--color-text-muted)", textAlign: "center"
    }}>
      {icon && <div style={{ opacity: 0.4, marginBottom: "0.5rem" }}>{icon}</div>}
      <p style={{ fontFamily: "var(--font-display)", fontWeight: 700, fontSize: "1.125rem",
        letterSpacing: "-0.02em", color: "var(--color-text)", margin: 0 }}>
        {title}
      </p>
      {description && (
        <p style={{ fontFamily: "var(--font-sans)", fontWeight: 400, fontSize: "0.875rem",
          lineHeight: 1.6, maxWidth: "24rem", margin: 0 }}>
          {description}
        </p>
      )}
      {action && <div style={{ marginTop: "0.5rem" }}>{action}</div>}
    </div>
  );
}
```

### SkeletonLoader (if frontend exists and missing)
Create `frontend/components/SkeletonLoader.tsx`:
```tsx
interface Props {
  width?: string;
  height?: string;
  borderRadius?: string;
  count?: number;
}

export function Skeleton({ width = "100%", height = "1rem", borderRadius = "var(--radius)" }: Props) {
  return (
    <div style={{
      width, height, borderRadius,
      background: "var(--color-surface)",
      backgroundImage: "linear-gradient(90deg, var(--color-surface) 0%, var(--color-surface-hover) 50%, var(--color-surface) 100%)",
      backgroundSize: "200% 100%",
      animation: "skeleton-shimmer 1.5s infinite",
    }} />
  );
}

export function SkeletonText({ lines = 3 }: { lines?: number }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
      {Array.from({ length: lines }).map((_, i) => (
        <Skeleton key={i} width={i === lines - 1 ? "60%" : "100%"} />
      ))}
    </div>
  );
}
```
Also add to `frontend/app/globals.css` (or equivalent):
```css
@keyframes skeleton-shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
```

### Prompt caching (if LLM_PROVIDER=anthropic and missing)
In the Anthropic branch of the LLM wrapper (`app/providers/llm.py` in /new-project scaffolds),
pass the system prompt as a system block with `cache_control` — this is the standard Messages
API (the old `client.beta.prompt_caching.*` namespace is obsolete; never use it):
```python
response = await client.messages.create(
    model=model,
    max_tokens=max_tokens,
    system=[
        {
            "type": "text",
            "text": system_prompt,
            "cache_control": {"type": "ephemeral"},  # cache long system prompts (60-90% savings)
        }
    ],
    messages=[{"role": "user", "content": user_message}],
)
```
This is only valid when the Anthropic provider is selected — no changes needed for other providers.

---

## ITEMS THAT NEED YOUR DECISION (never auto-fix)

After creating files, list these separately as "REVIEW REQUIRED":

- **CORS** — `allow_origins=["*"]` found. Replace with explicit list of your domains.
- **Hardcoded secrets** — default values like `"change-me-in-production"` found. Enforce non-empty via startup validation.
- **Per-org rate limiting** — current rate limiter is a global singleton. Requires architectural decision on per-org quota storage.
- **Error alerting** — no Slack/PagerDuty integration. Requires deciding your alerting destination.
- **Cost caps per org** — requires a `org_settings` table or config field. Requires schema decision.

---

## AFTER FIXING

Print a summary:
```
FIXED [N] items automatically.
[N] items need your decision (listed above).
Section B Claude bonuses: [N] available if you set LLM_PROVIDER=anthropic.

New files created:
  - app/infra/circuit_breaker.py
  - Dockerfile
  - frontend/components/ErrorBoundary.tsx
  - ...
```
