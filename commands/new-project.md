---
name: new-project
description: >
  Scaffold a complete production-ready project foundation from scratch. Use this skill
  at the very start of any new project — before writing any business logic. Run when the
  user says /new-project, "start a new project", "scaffold a new app", "set up a new
  project", or "create a new app". Asks 3 questions then creates ~25 files covering LLM
  abstraction, auth, security, CI/CD, frontend components, MCP servers, and CLAUDE.md.
  Works for SaaS, AI apps, internal tools, and APIs. Never run on an existing project
  with code already in it.
---

# New Project Scaffold

You are scaffolding a brand new production-ready project. Follow these steps in order.

---

## STEP 1 — ASK 3 QUESTIONS

Ask the user these questions before creating anything:

```
Before I scaffold, I need 3 answers:

1. App type?
   a) SaaS (multi-tenant web app with users and orgs)
   b) AI + SaaS (same but with LLM agents and vector search)
   c) Internal tool (single-tenant, no billing)
   d) API only (headless backend, no frontend)

2. What is the app name? (used for CLAUDE.md and docker-compose)

3. Billing from day one?
   a) Yes — include Stripe webhook + subscription check scaffold
   b) No — skip for now
```

Wait for answers before proceeding.

---

## STEP 2 — SCAFFOLD FILES

Create all files in parallel. Use the app name provided. Adapt based on app type:
- Skip frontend files if "API only"
- Add Qdrant + AI files if "AI + SaaS"
- Add billing file if billing = yes

### `app/__init__.py`
Empty file.

### `app/config.py`
```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # App
    app_name: str = "MyApp"
    app_version: str = "0.1.0"
    debug: bool = False

    # Security — startup fails if these are empty in production
    secret_key: str
    allowed_origins: str = "http://localhost:3000"

    # Database
    database_url: str

    # LLM
    llm_provider: str = "openai"
    openai_api_key: str = ""
    anthropic_api_key: str = ""
    openrouter_api_key: str = ""
    azure_openai_api_key: str = ""
    azure_openai_endpoint: str = ""
    azure_openai_deployment: str = ""
    ollama_base_url: str = "http://localhost:11434"
    modal_llm_url: str = ""

    # Embeddings
    embedding_provider: str = "openai"
    openai_embedding_model: str = "text-embedding-3-large"
    embedding_model_local: str = "BAAI/bge-large-en-v1.5"

    # Optional
    langfuse_public_key: str = ""
    langfuse_secret_key: str = ""
    langfuse_host: str = "https://cloud.langfuse.com"
    qdrant_url: str = "http://localhost:6333"
    redis_url: str = "redis://localhost:6379"
    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"

    def validate_production(self):
        if not self.debug:
            assert self.secret_key != "change-me", "SECRET_KEY must be set in production"
            assert self.database_url, "DATABASE_URL must be set"

@lru_cache
def get_settings() -> Settings:
    return Settings()

settings = get_settings()
```

### `app/main.py`
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.api.routes import router

app = FastAPI(title=settings.app_name, version=settings.app_version)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

@app.get("/health")
async def health():
    return {"status": "ok", "version": settings.app_version}
```

### `app/api/__init__.py`
Empty file.

### `app/api/routes.py`
```python
from fastapi import APIRouter
from app.api.auth import router as auth_router

router = APIRouter()
router.include_router(auth_router, prefix="/auth", tags=["auth"])
```

### `app/api/auth.py`
```python
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from datetime import datetime, timedelta
import jwt
from app.config import settings

router = APIRouter()
security = HTTPBearer()

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

def create_token(payload: dict, expires_minutes: int = 60) -> str:
    payload["exp"] = datetime.utcnow() + timedelta(minutes=expires_minutes)
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    try:
        return jwt.decode(credentials.credentials, settings.secret_key, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    # TODO: verify against database
    token = create_token({"sub": request.email, "role": "user", "org_id": "default"})
    return TokenResponse(access_token=token)

@router.get("/me")
async def me(payload: dict = Depends(verify_token)):
    return payload
```

### `app/core/__init__.py`
Empty file.

### `app/core/llm_provider.py`
```python
"""
LLM abstraction — swap providers via LLM_PROVIDER in .env.
Agents call call_llm() — never import provider SDKs directly in agent files.

Providers: openai | anthropic | openrouter | ollama | azure | modal
"""
import time
from app.config import settings

async def call_llm(
    system_prompt: str,
    user_message: str,
    model: str | None = None,
    max_tokens: int = 4096,
    temperature: float = 0.1,
    stream: bool = False,
) -> str:
    provider = settings.llm_provider.lower()
    if provider == "openai":
        return await _call_openai(system_prompt, user_message, model or "gpt-4o", max_tokens, temperature)
    elif provider == "anthropic":
        return await _call_anthropic(system_prompt, user_message, model or "claude-sonnet-4-6", max_tokens, temperature)
    elif provider == "openrouter":
        return await _call_openrouter(system_prompt, user_message, model or "openai/gpt-4o", max_tokens, temperature)
    elif provider == "ollama":
        return await _call_ollama(system_prompt, user_message, model or "qwen2.5:72b", max_tokens)
    elif provider == "azure":
        return await _call_azure(system_prompt, user_message, max_tokens, temperature)
    elif provider == "modal":
        return await _call_modal(system_prompt, user_message, max_tokens)
    else:
        raise ValueError(f"Unknown LLM_PROVIDER: '{provider}'")

async def _call_openai(system_prompt, user_message, model, max_tokens, temperature) -> str:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key=settings.openai_api_key)
    response = await client.chat.completions.create(
        model=model, max_tokens=max_tokens, temperature=temperature,
        messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": user_message}],
    )
    return response.choices[0].message.content

async def _call_anthropic(system_prompt, user_message, model, max_tokens, temperature) -> str:
    import anthropic
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
    # Prompt caching — cache long system prompts to save 60-90% cost
    response = await client.beta.prompt_caching.messages.create(
        model=model, max_tokens=max_tokens,
        system=[{"type": "text", "text": system_prompt, "cache_control": {"type": "ephemeral"}}],
        messages=[{"role": "user", "content": user_message}],
    )
    return response.content[0].text

async def _call_openrouter(system_prompt, user_message, model, max_tokens, temperature) -> str:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key=settings.openrouter_api_key, base_url="https://openrouter.ai/api/v1")
    response = await client.chat.completions.create(
        model=model, max_tokens=max_tokens, temperature=temperature,
        messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": user_message}],
    )
    return response.choices[0].message.content

async def _call_ollama(system_prompt, user_message, model, max_tokens) -> str:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key="ollama", base_url=f"{settings.ollama_base_url}/v1")
    response = await client.chat.completions.create(
        model=model, max_tokens=max_tokens,
        messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": user_message}],
    )
    return response.choices[0].message.content

async def _call_azure(system_prompt, user_message, max_tokens, temperature) -> str:
    from openai import AsyncAzureOpenAI
    client = AsyncAzureOpenAI(
        api_key=settings.azure_openai_api_key,
        azure_endpoint=settings.azure_openai_endpoint,
        api_version="2024-02-01",
    )
    response = await client.chat.completions.create(
        model=settings.azure_openai_deployment, max_tokens=max_tokens, temperature=temperature,
        messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": user_message}],
    )
    return response.choices[0].message.content

async def _call_modal(system_prompt, user_message, max_tokens) -> str:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key="modal", base_url=settings.modal_llm_url)
    response = await client.chat.completions.create(
        model="served-model", max_tokens=max_tokens,
        messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": user_message}],
    )
    return response.choices[0].message.content
```

### `app/core/circuit_breaker.py`
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
                    raise RuntimeError("Circuit breaker OPEN — service unavailable")
        try:
            result = func(*args, **kwargs)
            with self._lock:
                self.failure_count = 0
                self.state = State.CLOSED
            return result
        except Exception:
            with self._lock:
                self.failure_count += 1
                self.last_failure_time = time.time()
                if self.failure_count >= self.failure_threshold:
                    self.state = State.OPEN
            raise
```

### `app/core/rate_limiter.py`
```python
"""Per-org rate limiting — each org gets its own token bucket."""
import time
from collections import defaultdict
from threading import Lock
from app.config import settings

class OrgRateLimiter:
    def __init__(self, requests_per_minute: int = 60):
        self.rpm = requests_per_minute
        self._buckets: dict[str, dict] = defaultdict(lambda: {"tokens": requests_per_minute, "last_refill": time.time()})
        self._lock = Lock()

    def allow(self, org_id: str) -> bool:
        with self._lock:
            bucket = self._buckets[org_id]
            now = time.time()
            elapsed = now - bucket["last_refill"]
            bucket["tokens"] = min(self.rpm, bucket["tokens"] + elapsed * (self.rpm / 60))
            bucket["last_refill"] = now
            if bucket["tokens"] >= 1:
                bucket["tokens"] -= 1
                return True
            return False

rate_limiter = OrgRateLimiter()
```

### `app/core/cost_tracker.py`
```python
"""Track LLM cost and latency per agent per run."""
from dataclasses import dataclass, field
from datetime import datetime

@dataclass
class AgentCost:
    agent_name: str
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    latency_ms: int = 0

@dataclass
class RunCost:
    run_id: str
    org_id: str
    started_at: datetime = field(default_factory=datetime.utcnow)
    agents: list[AgentCost] = field(default_factory=list)

    @property
    def total_cost_usd(self) -> float:
        return sum(a.cost_usd for a in self.agents)

    @property
    def total_latency_ms(self) -> int:
        return sum(a.latency_ms for a in self.agents)

    def add_agent(self, name: str, input_tokens: int, output_tokens: int, cost_usd: float, latency_ms: int):
        self.agents.append(AgentCost(name, input_tokens, output_tokens, cost_usd, latency_ms))

_runs: dict[str, RunCost] = {}

def start_run(run_id: str, org_id: str) -> RunCost:
    run = RunCost(run_id=run_id, org_id=org_id)
    _runs[run_id] = run
    return run

def get_run(run_id: str) -> RunCost | None:
    return _runs.get(run_id)
```

### `app/core/embedding_provider.py`
```python
"""Embedding abstraction — swap via EMBEDDING_PROVIDER in .env."""
from app.config import settings

def embed_text(text: str) -> list[float]:
    return embed_batch([text])[0]

def embed_batch(texts: list[str]) -> list[list[float]]:
    provider = settings.embedding_provider.lower()
    if provider in ("openai", "azure"):
        return _embed_openai(texts)
    elif provider == "local":
        return _embed_local(texts)
    elif provider == "modal":
        return _embed_modal(texts)
    else:
        raise ValueError(f"Unknown EMBEDDING_PROVIDER: '{provider}'")

def get_embedding_dimensions() -> int:
    provider = settings.embedding_provider.lower()
    return 3072 if provider in ("openai", "azure") else 1024

def _embed_openai(texts: list[str]) -> list[list[float]]:
    from openai import OpenAI
    client = OpenAI(api_key=settings.openai_api_key)
    response = client.embeddings.create(model=settings.openai_embedding_model, input=texts)
    return [d.embedding for d in response.data]

def _embed_local(texts: list[str]) -> list[list[float]]:
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer(settings.embedding_model_local)
    return model.encode(texts).tolist()

def _embed_modal(texts: list[str]) -> list[list[float]]:
    import httpx
    response = httpx.post(f"{settings.modal_llm_url}/embed", json={"texts": texts}, timeout=60)
    return response.json()["embeddings"]
```

### `app/db/__init__.py`
Empty file.

### `app/db/schema.sql`
```sql
-- Core tables for multi-tenant SaaS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE orgs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    slug        TEXT UNIQUE NOT NULL,
    plan        TEXT NOT NULL DEFAULT 'free',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id      UUID NOT NULL REFERENCES orgs(id) ON DELETE CASCADE,
    email       TEXT UNIQUE NOT NULL,
    role        TEXT NOT NULL DEFAULT 'member',  -- member | admin | owner
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id      UUID NOT NULL REFERENCES orgs(id),
    user_id     UUID REFERENCES users(id),
    action      TEXT NOT NULL,
    resource    TEXT,
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_org ON users(org_id);
CREATE INDEX idx_audit_org ON audit_logs(org_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
```

### `app/jobs/__init__.py`
Empty file.

### `app/jobs/cleanup.py`
```python
"""Scheduled data retention cleanup — run daily via cron or Modal."""
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

RETENTION_DAYS = 90

def cleanup_old_records():
    cutoff = datetime.utcnow() - timedelta(days=RETENTION_DAYS)
    logger.info(f"Cleanup: removing records older than {cutoff.date()}")
    # TODO: connect to DB and delete old audit_logs, expired sessions, etc.

if __name__ == "__main__":
    cleanup_old_records()
```

### `Dockerfile`
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

### `docker-compose.yml`
```yaml
version: "3.9"
services:
  app:
    build: .
    ports:
      - "8000:8000"
    env_file: .env
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: apppassword
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./app/db/schema.sql:/docker-entrypoint-initdb.d/schema.sql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  # Uncomment for AI apps:
  # qdrant:
  #   image: qdrant/qdrant:latest
  #   ports:
  #     - "6333:6333"
  #   volumes:
  #     - qdrant_data:/qdrant/storage

volumes:
  postgres_data:
  # qdrant_data:
```

### `.github/workflows/ci.yml`
```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:

jobs:
  backend:
    name: Backend — pytest
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -r requirements.txt
      - name: Create test .env
        run: |
          cat > .env << 'EOF'
          SECRET_KEY=ci-test-secret
          DATABASE_URL=postgresql://user:pass@localhost/db
          LLM_PROVIDER=openai
          OPENAI_API_KEY=sk-fake
          EMBEDDING_PROVIDER=local
          EOF
      - run: pytest tests/ -v --tb=short

  frontend:
    name: Frontend — build + lint
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - run: npm ci
      - run: npm run build
      - run: npm run lint
```

### `.env.example`
```bash
# App
APP_NAME=MyApp
DEBUG=false
SECRET_KEY=change-me-in-production-use-openssl-rand-hex-32

# CORS — comma-separated list of allowed origins
ALLOWED_ORIGINS=http://localhost:3000,https://app.yourdomain.com

# Database
DATABASE_URL=postgresql://appuser:apppassword@localhost:5432/appdb

# Redis
REDIS_URL=redis://localhost:6379

# LLM Provider — openai | anthropic | openrouter | ollama | azure | modal
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
OPENROUTER_API_KEY=sk-or-...
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_DEPLOYMENT=
OLLAMA_BASE_URL=http://localhost:11434
MODAL_LLM_URL=

# Embeddings — openai | azure | local | modal
EMBEDDING_PROVIDER=openai
OPENAI_EMBEDDING_MODEL=text-embedding-3-large
EMBEDDING_MODEL_LOCAL=BAAI/bge-large-en-v1.5

# Observability (optional)
LANGFUSE_PUBLIC_KEY=
LANGFUSE_SECRET_KEY=
LANGFUSE_HOST=https://cloud.langfuse.com

# Vector store (AI apps only)
QDRANT_URL=http://localhost:6333

# Stripe (if billing enabled)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

### `requirements.txt`
```
fastapi==0.136.1
uvicorn[standard]==0.34.3
pydantic==2.13.3
pydantic-settings==2.9.1
python-jose[cryptography]==3.3.0
pyjwt==2.10.1
httpx==0.28.1
sqlalchemy==2.0.40
psycopg2-binary==2.9.10
redis==5.2.1
openai==2.33.0
anthropic==0.49.0
sentence-transformers==4.1.0
pytest==8.3.5
pytest-asyncio==0.25.0
```

### `frontend/components/ErrorBoundary.tsx`
```tsx
"use client";
import React from "react";

interface Props { children: React.ReactNode; fallback?: React.ReactNode; }
interface State { hasError: boolean; }

export class ErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) { super(props); this.state = { hasError: false }; }
  static getDerivedStateFromError(): State { return { hasError: true }; }
  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div style={{ padding: "2rem", color: "var(--color-error)", fontFamily: "var(--font-sans)" }}>
          <p>Something went wrong. Please refresh the page.</p>
        </div>
      );
    }
    return this.props.children;
  }
}
```

### `frontend/components/EmptyState.tsx`
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
      color: "var(--color-text-muted)", textAlign: "center",
    }}>
      {icon && <div style={{ opacity: 0.4, marginBottom: "0.5rem" }}>{icon}</div>}
      <p style={{ fontWeight: 700, fontSize: "1.125rem", letterSpacing: "-0.02em",
        color: "var(--color-text)", margin: 0, fontFamily: "var(--font-display)" }}>
        {title}
      </p>
      {description && (
        <p style={{ fontWeight: 400, fontSize: "0.875rem", lineHeight: 1.6,
          maxWidth: "24rem", margin: 0, fontFamily: "var(--font-sans)" }}>
          {description}
        </p>
      )}
      {action && <div style={{ marginTop: "0.5rem" }}>{action}</div>}
    </div>
  );
}
```

### `frontend/components/SkeletonLoader.tsx`
```tsx
interface SkeletonProps { width?: string; height?: string; borderRadius?: string; }

export function Skeleton({ width = "100%", height = "1rem", borderRadius = "var(--radius)" }: SkeletonProps) {
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

### `frontend/components/AuthGuard.tsx`
```tsx
"use client";
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  useEffect(() => {
    const token = localStorage.getItem("access_token");
    if (!token) router.push("/login");
  }, [router]);
  return <>{children}</>;
}
```

### `.mcp/database-server.py`
```python
"""
MCP server — lets Claude Code query the app database directly in conversation.
Run: python .mcp/database-server.py
"""
import os
import psycopg2
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("database")

def get_conn():
    return psycopg2.connect(os.environ["DATABASE_URL"])

@mcp.tool()
def query_db(sql: str) -> str:
    """Run a read-only SQL query against the app database."""
    if any(kw in sql.upper() for kw in ["INSERT", "UPDATE", "DELETE", "DROP", "TRUNCATE"]):
        return "Error: only SELECT queries allowed"
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()
            cols = [d[0] for d in cur.description]
            return str([dict(zip(cols, row)) for row in rows[:50]])

@mcp.tool()
def list_tables() -> str:
    """List all tables in the database."""
    return query_db("SELECT tablename FROM pg_tables WHERE schemaname = 'public'")

if __name__ == "__main__":
    mcp.run()
```

### `.mcp/api-server.py`
```python
"""
MCP server — lets Claude Code call app API endpoints directly.
Run: python .mcp/api-server.py
"""
import os
import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("api")
BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")

@mcp.tool()
def health_check() -> str:
    """Check if the app is running."""
    r = httpx.get(f"{BASE_URL}/health")
    return r.json()

@mcp.tool()
def get_endpoint(path: str) -> str:
    """Call a GET endpoint on the app. path should start with /"""
    r = httpx.get(f"{BASE_URL}{path}", timeout=10)
    return r.text

if __name__ == "__main__":
    mcp.run()
```

### `CLAUDE.md`
Generate a CLAUDE.md using this template, filling in the app name:

```markdown
# CLAUDE.md — [APP NAME]

## THIS PROJECT
**Product:** [APP NAME]
**Stack:** Next.js + FastAPI + PostgreSQL + Redis
**LLM:** Configurable via LLM_PROVIDER in .env

## SESSION START — MANDATORY
```bash
docker-compose ps           # confirm services running
python -m pytest tests/ -q  # confirm tests passing
```

## SCOPE RULES
**Allowed:** Build features, fix bugs, write tests
**Ask first:** Installing new packages, changing DB schema, modifying auth

## COMPONENT CONTRACTS
1. CORS is locked to ALLOWED_ORIGINS env var — never set to "*"
2. Rate limiting is per-org — never a global singleton
3. All secrets from env vars — no hardcoded values
4. SQL queries parameterized — never f-string SQL
5. Frontend: CSS vars only — never raw hex colours

## STACK DETAILS
- Backend: `uvicorn app.main:app --reload` → http://localhost:8000
- Frontend: `cd frontend && npm run dev` → http://localhost:3000
- DB: PostgreSQL via SQLAlchemy — migrations via Alembic
- Auth: JWT tokens, verify with `app/api/auth.py:verify_token`
```

---

### ALSO CREATE IF BILLING=YES

### `app/api/billing.py`
```python
from fastapi import APIRouter, Request, HTTPException
from app.config import settings
import stripe

router = APIRouter()
stripe.api_key = settings.stripe_secret_key

@router.post("/webhook")
async def stripe_webhook(request: Request):
    payload = await request.body()
    sig = request.headers.get("stripe-signature")
    try:
        event = stripe.Webhook.construct_event(payload, sig, settings.stripe_webhook_secret)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")

    if event["type"] == "customer.subscription.created":
        pass  # TODO: update org plan in DB
    elif event["type"] == "customer.subscription.deleted":
        pass  # TODO: downgrade org to free tier

    return {"status": "ok"}
```

---

## STEP 3 — PRINT SUMMARY

After all files are created:

```
════════════════════════════════════════════
  PROJECT SCAFFOLDED — [app name]
════════════════════════════════════════════

Files created: [N]
Stack: Next.js + FastAPI + PostgreSQL

── To start ────────────────────────────────
  cp .env.example .env          # fill in your values
  docker-compose up -d          # start DB + Redis
  pip install -r requirements.txt
  uvicorn app.main:app --reload  # start backend → :8000

  cd frontend && npm install
  npm run dev                    # start frontend → :3000

── MCP servers ─────────────────────────────
  Set DATABASE_URL in .env, then:
  python .mcp/database-server.py  # Claude Code can query your DB
  python .mcp/api-server.py       # Claude Code can call your API

── What's ready ────────────────────────────
  ✅ LLM abstraction (6 providers + streaming + prompt caching)
  ✅ JWT auth with RBAC
  ✅ Per-org rate limiting
  ✅ Circuit breaker
  ✅ Cost + latency tracking
  ✅ CORS locked to env var
  ✅ Dockerfile + docker-compose
  ✅ GitHub Actions CI
  ✅ Frontend: ErrorBoundary, EmptyState, SkeletonLoader, AuthGuard
  ✅ MCP servers for DB + API
  ✅ CLAUDE.md with project rules

── Next steps ──────────────────────────────
  1. Fill in .env values
  2. Run /enterprise-ai-audit to verify nothing was missed
  3. Start building your first feature

════════════════════════════════════════════
```
