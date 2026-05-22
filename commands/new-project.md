---
name: new-project
description: >
  Scaffold a complete production-ready project foundation from scratch. Use this skill
  at the very start of any new project — before writing any business logic. Run when the
  user says /new-project, "start a new project", "scaffold a new app", "set up a new
  project", or "create a new app". Asks 3 questions then creates ~35 files covering LLM
  abstraction, auth, security, CI/CD, frontend components, MCP servers, and CLAUDE.md.
  Uses industry-standard sub-package structure (app/providers/, app/auth/, app/infra/)
  from day one — never a flat app/core/ dump. Works for SaaS, AI apps, internal tools,
  and APIs. Never run on an existing project with code already in it.
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
- Add Qdrant + AI files and `app/schemas/` if "AI + SaaS"
- Add billing file if billing = yes
- Add `deploy/modal.py` if "AI + SaaS"

### DIRECTORY STRUCTURE TO CREATE

```
<app-name>/
├── app/
│   ├── api/              ← routes only, no business logic
│   ├── auth/             ← JWT, RBAC, FastAPI dependencies
│   ├── providers/        ← LLM, embedding (pluggable backends)
│   ├── infra/            ← circuit breaker, rate limiter, cost tracker
│   ├── db/               ← schema, migrations
│   ├── jobs/             ← scheduled work
│   ├── schemas/          ← Pydantic output models (AI + SaaS only)
│   └── main.py
├── deploy/               ← Modal, Dockerfile variants (AI + SaaS only)
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── scripts/              ← ops only: seed, reset (never test code)
├── .mcp/                 ← MCP servers for Claude Code
├── .github/workflows/
├── Makefile              ← single dev entrypoint
├── pyproject.toml        ← ruff + pytest config
├── .pre-commit-config.yaml
├── .env.example
├── docker-compose.yml
├── Dockerfile
└── CLAUDE.md
```

---

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
from app.api.auth_routes import router as auth_router

router = APIRouter()
router.include_router(auth_router, prefix="/auth", tags=["auth"])
```

### `app/api/auth_routes.py`
Routes only — all JWT logic lives in `app/auth/jwt.py`.
```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.auth.jwt import create_token, verify_token
from app.auth.dependencies import get_current_user
from fastapi import Depends

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    # TODO: verify against database
    token = create_token({"sub": request.email, "role": "user", "org_id": "default"})
    return TokenResponse(access_token=token)

@router.get("/me")
async def me(payload: dict = Depends(get_current_user)):
    return payload
```

---

### `app/auth/__init__.py`
Empty file.

### `app/auth/jwt.py`
All JWT logic — token creation, verification, role checks.
```python
from datetime import datetime, timedelta
from fastapi import HTTPException
import jwt
from app.config import settings

def create_token(payload: dict, expires_minutes: int = 60) -> str:
    data = payload.copy()
    data["exp"] = datetime.utcnow() + timedelta(minutes=expires_minutes)
    return jwt.encode(data, settings.secret_key, algorithm="HS256")

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.secret_key, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def require_role(*roles: str):
    """FastAPI dependency — raises 403 if user role not in allowed list."""
    def checker(payload: dict) -> dict:
        if payload.get("role") not in roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return payload
    return checker
```

### `app/auth/rbac.py`
Resource-level access checks beyond role.
```python
from fastapi import HTTPException

ROLE_PERMISSIONS: dict[str, list[str]] = {
    "owner":  ["read", "write", "delete", "admin"],
    "admin":  ["read", "write", "delete"],
    "member": ["read", "write"],
    "viewer": ["read"],
}

def has_permission(role: str, action: str) -> bool:
    return action in ROLE_PERMISSIONS.get(role, [])

def require_permission(action: str):
    """FastAPI dependency — raises 403 if role lacks the action."""
    def checker(payload: dict) -> dict:
        role = payload.get("role", "viewer")
        if not has_permission(role, action):
            raise HTTPException(status_code=403, detail=f"Role '{role}' cannot '{action}'")
        return payload
    return checker
```

### `app/auth/dependencies.py`
FastAPI `Depends()` resolvers — imported by all routes.
```python
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.auth.jwt import decode_token

security = HTTPBearer()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    return decode_token(credentials.credentials)

def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(HTTPBearer(auto_error=False)),
) -> dict | None:
    if credentials is None:
        return None
    return decode_token(credentials.credentials)
```

---

### `app/providers/__init__.py`
Empty file.

### `app/providers/llm.py`
LLM abstraction — swap providers via `LLM_PROVIDER` in `.env`.
Agents call `call_llm()` — never import provider SDKs directly in agent files.

Providers: `openai | anthropic | openrouter | ollama | azure | modal`
```python
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

### `app/providers/embedding.py`
Embedding abstraction — swap via `EMBEDDING_PROVIDER` in `.env`.
```python
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
    return 3072 if settings.embedding_provider.lower() in ("openai", "azure") else 1024

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

---

### `app/infra/__init__.py`
Empty file.

### `app/infra/circuit_breaker.py`
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

### `app/infra/rate_limiter.py`
```python
"""Per-org rate limiting — each org gets its own token bucket."""
import time
from collections import defaultdict
from threading import Lock

class OrgRateLimiter:
    def __init__(self, requests_per_minute: int = 60):
        self.rpm = requests_per_minute
        self._buckets: dict[str, dict] = defaultdict(
            lambda: {"tokens": requests_per_minute, "last_refill": time.time()}
        )
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

### `app/infra/cost_tracker.py`
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

---

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

---

### `tests/unit/.gitkeep`
Empty file — keeps the directory tracked by git.

### `tests/integration/.gitkeep`
Empty file.

### `tests/fixtures/.gitkeep`
Empty file.

### `scripts/seed.py`
```python
"""Seed initial data — run once after migrations."""
# TODO: insert default org, admin user, and baseline config
if __name__ == "__main__":
    print("Seeding database...")
```

---

### `Makefile`
Single entrypoint for all dev tasks — `make dev` gets a new engineer running in under 5 minutes.
```makefile
.PHONY: dev test lint seed reset check

dev:
	cp -n .env.example .env 2>/dev/null || true
	docker-compose up -d
	pip install -r requirements.txt
	alembic upgrade head
	python scripts/seed.py
	uvicorn app.main:app --reload --port 8000

frontend:
	cd frontend && npm install && npm run dev

test:
	pytest tests/unit tests/integration -v --tb=short

lint:
	ruff check app/ tests/ --fix
	ruff format app/ tests/
	cd frontend && npx eslint . 2>/dev/null || true

seed:
	python scripts/seed.py

reset:
	python scripts/reset.py

check:
	pytest tests/unit -q
	python -c "from app.main import app; print('imports ok')"
```

### `pyproject.toml`
```toml
[project]
name = "app"
version = "0.1.0"
requires-python = ">=3.11"

[tool.ruff]
line-length = 100
target-version = "py311"
src = ["app"]

[tool.ruff.lint]
select = ["E", "F", "I"]
ignore = ["E501"]

[tool.ruff.lint.isort]
known-first-party = ["app"]

[tool.pytest.ini_options]
testpaths = ["tests"]
asyncio_mode = "auto"
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
```

### `.pre-commit-config.yaml`
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.75.0
    hooks:
      - id: trufflehog
        name: Secret scan
        entry: trufflehog git file://. --since-commit HEAD --only-verified --fail
        language: system
        pass_filenames: false
```

---

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
    name: Backend — lint + test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -r requirements.txt ruff
      - name: Lint
        run: ruff check app/ tests/
      - name: Create test .env
        run: |
          cat > .env << 'EOF'
          SECRET_KEY=ci-test-secret-32-chars-minimum-x
          DATABASE_URL=postgresql://user:pass@localhost/db
          LLM_PROVIDER=openai
          OPENAI_API_KEY=sk-fake
          EMBEDDING_PROVIDER=local
          EOF
      - name: Test
        run: pytest tests/unit -v --tb=short

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
ruff==0.4.4
```

---

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

---

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

---

### ALSO CREATE IF BILLING=YES

### `app/api/billing_routes.py`
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

### ALSO CREATE IF AI + SaaS

### `app/schemas/__init__.py`
Empty file.

### `app/schemas/output_models.py`
Base Pydantic output models — all agent outputs extend these.
```python
from pydantic import BaseModel, Field
from enum import Enum

class ConfidenceLevel(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

class AgentOutput(BaseModel):
    """Base class for all agent outputs. Never pass raw text between agents."""
    agent_name: str
    confidence: ConfidenceLevel = ConfidenceLevel.MEDIUM
    warnings: list[str] = Field(default_factory=list)

class GroundedFact(BaseModel):
    """A fact with a verbatim quote from the source document."""
    value: str
    grounding_quote: str  # must appear verbatim in source — never paraphrased
    source_chunk_id: str | None = None
    confidence: ConfidenceLevel = ConfidenceLevel.MEDIUM
```

### `deploy/modal.py`
```python
"""
Modal deployment — GPU inference, batch embeddings, scheduled jobs.
Deploy: modal deploy deploy/modal.py
"""
import modal

app = modal.App("app-name")
image = modal.Image.debian_slim().pip_install_from_requirements("requirements.txt")

@app.function(image=image, schedule=modal.Cron("0 2 * * *"))
def daily_cleanup():
    from app.jobs.cleanup import cleanup_old_records
    cleanup_old_records()
```

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

## COMPONENT CONTRACTS
1. CORS locked to ALLOWED_ORIGINS env var — never "*"
2. Rate limiting is per-org — never a global singleton
3. All secrets from env vars — no hardcoded values in any file
4. SQL queries parameterized — never f-string SQL
5. Frontend: CSS vars only — never raw hex colours
6. Agent outputs are Pydantic models — never raw text between agents

## SCOPE RULES
**Allowed:** Build features, fix bugs, write tests
**Ask first:** Installing new packages, changing DB schema, modifying auth
```

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
  deploy/         Modal GPU deployment        [AI apps only]
  tests/unit/     fast, no I/O
  tests/integration/  needs DB + services
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
  ✅ Dockerfile + docker-compose (Postgres + Redis)
  ✅ GitHub Actions CI (ruff lint + pytest + frontend build)
  ✅ Makefile — make dev / test / lint / seed
  ✅ pyproject.toml — ruff + pytest config
  ✅ .pre-commit-config.yaml — ruff + secret scanner
  ✅ tests/unit/, tests/integration/, tests/fixtures/ — structured from day one
  ✅ Frontend: ErrorBoundary, EmptyState, SkeletonLoader, AuthGuard
  ✅ MCP servers for DB + API
  ✅ CLAUDE.md with import rules + package structure

── Next steps ──────────────────────────────
  1. Fill in .env values
  2. Run /enterprise-ai-audit to verify nothing was missed
  3. Start building your first feature

════════════════════════════════════════════
```
