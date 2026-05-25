---
name: new-project
description: >
  Scaffold a complete production-ready project foundation from scratch. Use this skill
  at the very start of any new project — before writing any business logic. Run when the
  user says /new-project, "start a new project", "scaffold a new app", "set up a new
  project", or "create a new app". Asks 3–5 questions then creates files covering LLM
  abstraction, auth, security, CI/CD, frontend components, MCP servers, and CLAUDE.md.
  Supports: full-stack (Next.js + FastAPI), backend only (FastAPI), frontend only
  (Next.js App Router or React + Vite). Uses industry-standard sub-package structure
  from day one. Never run on an existing project with code already in it.
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

After receiving answers to questions 1–3, ask:

```
4. What do you want to scaffold?
   a) Full stack — Next.js frontend + FastAPI backend (default)
   b) Backend only — FastAPI + Python, no frontend files
   c) Frontend only — no backend at all

   → If answer is (c), ask one more question:

   4b. Which frontend framework?
       a) Next.js — App Router, React 19, TypeScript, Tailwind CSS
       b) React + Vite — SPA, TypeScript, Tailwind CSS, React Router v6
```

Wait for all answers before proceeding.

---

## STEP 2 — SCAFFOLD FILES

Create all files in parallel. Use the app name provided. Adapt based on app type:
- Skip frontend files if "API only"
- Add Qdrant + AI files and `app/schemas/` if "AI + SaaS"
- Add billing file if billing = yes
- Add `deploy/modal.py` if "AI + SaaS"
- If "Backend only": skip all frontend files (ErrorBoundary, EmptyState, SkeletonLoader, AuthGuard, Makefile `frontend` target, CI `frontend` job)
- If "Frontend only → Next.js": skip ALL backend files — follow the FRONTEND ONLY — NEXT.JS section below instead
- If "Frontend only → React + Vite": skip ALL backend files — follow the FRONTEND ONLY — REACT + VITE section below instead
- If "Full stack": existing behaviour — create everything as documented above

### DIRECTORY STRUCTURE TO CREATE

```
<app-name>/
├── app/
│   ├── api/              ← routes only, no business logic
│   ├── auth/             ← JWT, RBAC, FastAPI dependencies
│   ├── providers/        ← LLM, embedding (pluggable backends)
│   ├── infra/            ← circuit breaker, rate limiter, cost tracker, pagination
│   ├── validators/       ← input validation — text length, file size, org_id
│   ├── db/               ← schema, migrations
│   ├── jobs/             ← scheduled work + background tasks
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
├── prometheus.yml
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
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Info
from app.config import settings
from app.api.routes import router
import uuid
import logging

logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"[startup] {settings.app_name} v{settings.app_version} starting")
    yield
    logger.info("[shutdown] clean shutdown")

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
)

@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    request_id = getattr(request.state, "request_id", "unknown")
    logger.error(f"[{request_id}] Unhandled error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "request_id": request_id},
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins.split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")

Info("fastapi_app", "FastAPI application info").info({"app_name": settings.app_name})
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

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
# All routes are mounted at /api/v1 via main.py — never hardcode version here
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

### `app/infra/pagination.py`
Standard pagination — all list endpoints use this, never invent their own.
```python
from pydantic import BaseModel
from typing import TypeVar, Generic, Sequence

T = TypeVar("T")

class PaginatedResponse(BaseModel, Generic[T]):
    items: Sequence[T]
    total: int
    page: int
    size: int
    pages: int

    @classmethod
    def create(cls, items: Sequence[T], total: int, page: int, size: int) -> "PaginatedResponse[T]":
        return cls(items=items, total=total, page=page, size=size, pages=-(-total // size))

class PaginationParams(BaseModel):
    page: int = 1
    size: int = 20

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.size
```

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

### `app/validators/__init__.py`
Empty file.

### `app/validators/common.py`
Centralised input validation — import these in routes, never write ad-hoc len() checks.
```python
from pydantic import BaseModel, Field, field_validator
from fastapi import HTTPException

MAX_TEXT_LENGTH = 50_000
MAX_FILE_SIZE_MB = 50

class TextInput(BaseModel):
    text: str = Field(..., min_length=1, max_length=MAX_TEXT_LENGTH)

    @field_validator("text")
    @classmethod
    def no_null_bytes(cls, v: str) -> str:
        if "\x00" in v:
            raise ValueError("Text contains null bytes")
        return v.strip()

class OrgScopedInput(BaseModel):
    org_id: str = Field(..., min_length=1, max_length=64, pattern=r"^[a-zA-Z0-9_-]+$")

def validate_file_size(size_bytes: int) -> None:
    if size_bytes > MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE_MB}MB"
        )
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

### `app/jobs/background.py`
Standard background task pattern — use this instead of raw threading or asyncio.create_task().
```python
"""
Background task helpers — keeps route handlers fast.
Usage in a route:
    from fastapi import BackgroundTasks
    from app.jobs.background import run_in_background

    @router.post("/evaluate")
    async def start_eval(background_tasks: BackgroundTasks):
        background_tasks.add_task(run_in_background, my_task, arg1, arg2)
        return {"status": "started"}
"""
import logging
from typing import Callable, Any

logger = logging.getLogger(__name__)

async def run_in_background(func: Callable, *args: Any, **kwargs: Any) -> None:
    try:
        if hasattr(func, "__await__"):
            await func(*args, **kwargs)
        else:
            func(*args, **kwargs)
    except Exception as exc:
        logger.error(f"Background task {func.__name__} failed: {exc}", exc_info=True)
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

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
      GF_USERS_ALLOW_SIGN_UP: 'false'
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: unless-stopped

  loki:
    image: grafana/loki:latest
    container_name: loki
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped

  # Uncomment for AI apps:
  # qdrant:
  #   image: qdrant/qdrant:latest
  #   ports:
  #     - "6333:6333"
  #   volumes:
  #     - qdrant_data:/qdrant/storage

volumes:
  postgres_data:
  prometheus_data:
  grafana_data:
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

  frontend-drift:
    name: Frontend — structure drift check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check no raw fetch() in ui/ components
        run: |
          if grep -r "fetch(" frontend/components/ui/; then
            echo "❌ Raw fetch() found in components/ui/ — use lib/api.ts instead"
            exit 1
          fi
      - name: Check no hex colours in components
        run: |
          if grep -rE "#[0-9a-fA-F]{3,6}" frontend/components/; then
            echo "❌ Raw hex colour found in components — use var(--color-*) instead"
            exit 1
          fi
      - name: Check no raw font strings in components
        run: |
          if grep -rE "font-family\s*:\s*['\"]" frontend/components/; then
            echo "❌ Raw font string found — use FONT, DISPLAY, or MONO from lib/theme.ts"
            exit 1
          fi
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
prometheus-fastapi-instrumentator==7.1.0
```

---

### `frontend/lib/theme.ts`
Full theme system — 51 themes selectable at runtime via CSS custom properties.
```typescript
export const FONT = "var(--font-sans)";
export const DISPLAY = "var(--font-display)";
export const MONO = "var(--font-mono)";

export interface Theme {
  name: string;
  vars: Record<string, string>;
}

export const THEMES: Theme[] = [
  {
    name: "default",
    vars: {
      "--color-background": "#0f1117",
      "--color-surface": "#1a1d27",
      "--color-surface-hover": "#22263a",
      "--color-border": "#2a2d3e",
      "--color-border-strong": "#3d4158",
      "--color-text": "#e8eaf6",
      "--color-text-muted": "#8b8fa8",
      "--color-accent": "#6366f1",
      "--color-accent-hover": "#4f46e5",
      "--color-success": "#22c55e",
      "--color-warning": "#f59e0b",
      "--color-error": "#ef4444",
      "--color-info": "#3b82f6",
      "--shadow-sm": "0 1px 2px rgba(0,0,0,0.4)",
      "--shadow-md": "0 4px 12px rgba(0,0,0,0.5)",
      "--shadow-lg": "0 8px 32px rgba(0,0,0,0.6)",
      "--radius": "8px",
      "--transition": "150ms ease",
      "--bg-gradient": "linear-gradient(135deg, #0f1117 0%, #1a1d27 100%)",
    },
  },
  {
    name: "light",
    vars: {
      "--color-background": "#ffffff",
      "--color-surface": "#f8fafc",
      "--color-surface-hover": "#f1f5f9",
      "--color-border": "#e2e8f0",
      "--color-border-strong": "#cbd5e1",
      "--color-text": "#0f172a",
      "--color-text-muted": "#64748b",
      "--color-accent": "#6366f1",
      "--color-accent-hover": "#4f46e5",
      "--color-success": "#16a34a",
      "--color-warning": "#d97706",
      "--color-error": "#dc2626",
      "--color-info": "#2563eb",
      "--shadow-sm": "0 1px 2px rgba(0,0,0,0.05)",
      "--shadow-md": "0 4px 12px rgba(0,0,0,0.08)",
      "--shadow-lg": "0 8px 32px rgba(0,0,0,0.12)",
      "--radius": "8px",
      "--transition": "150ms ease",
      "--bg-gradient": "linear-gradient(135deg, #ffffff 0%, #f8fafc 100%)",
    },
  },
];

export function applyThemeVars(theme: Theme): void {
  const root = document.documentElement;
  Object.entries(theme.vars).forEach(([key, value]) => {
    root.style.setProperty(key, value);
  });
}

export function getTheme(name: string): Theme {
  return THEMES.find((t) => t.name === name) ?? THEMES[0];
}
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

### `frontend/components/ui/ErrorBanner.tsx`
```tsx
import { FONT } from "@/lib/theme";

export function ErrorBanner({ message }: { message: string }) {
  return (
    <div
      role="alert"
      style={{
        marginBottom: 20,
        padding: "10px 14px",
        backgroundColor: "color-mix(in srgb, var(--color-error) 10%, transparent)",
        borderTop: "none",
        borderBottom: "none",
        borderRight: "none",
        borderLeft: "2px solid var(--color-error)",
        borderRadius: "0 4px 4px 0",
        fontFamily: FONT,
        fontWeight: 500,
        fontSize: 13,
        color: "var(--color-error)",
        lineHeight: 1.5,
      }}
    >
      {message}
    </div>
  );
}
```

---

### `prometheus.yml`
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: fastapi
    static_configs:
      - targets: ['host.docker.internal:8000']
        labels:
          app_name: appname
    metrics_path: /metrics
```
Replace `appname` with your actual app name.

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

### FRONTEND ONLY — NEXT.JS

Only create these files when user chose "Frontend only → Next.js". Skip all Python/backend files entirely.

#### Directory structure

```
<app-name>/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── globals.css
│   ├── (auth)/
│   │   ├── login/page.tsx
│   │   └── signup/page.tsx
│   └── dashboard/page.tsx
├── components/
│   ├── ui/
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   └── index.ts
│   ├── layout/
│   │   └── Header.tsx
│   └── features/          ← empty, fill with page-specific components
├── lib/
│   ├── api.ts
│   ├── hooks.ts
│   └── utils.ts
├── types/
│   └── index.ts
├── public/
├── next.config.ts
├── tsconfig.json
├── tailwind.config.ts
├── postcss.config.mjs
├── package.json
├── .env.example
├── .gitignore
├── .github/workflows/ci.yml
└── CLAUDE.md
```

#### `package.json`
```json
{
  "name": "<app-name>",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "typescript": "^5",
    "tailwindcss": "^4",
    "@tailwindcss/postcss": "^4",
    "eslint": "^9",
    "eslint-config-next": "^15"
  }
}
```

#### `next.config.ts`
```ts
import type { NextConfig } from "next";
const nextConfig: NextConfig = { reactStrictMode: true };
export default nextConfig;
```

#### `tsconfig.json`
```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

#### `tailwind.config.ts`
```ts
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./pages/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./app/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
};
export default config;
```

#### `postcss.config.mjs`
```js
const config = { plugins: { "@tailwindcss/postcss": {} } };
export default config;
```

#### `app/layout.tsx`
```tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "<APP NAME>",
  description: "<APP NAME> — built with Next.js",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

#### `app/page.tsx`
```tsx
export default function HomePage() {
  return (
    <main>
      <h1>Welcome to &lt;APP NAME&gt;</h1>
    </main>
  );
}
```

#### `app/globals.css`
```css
@import "tailwindcss";

:root {
  --color-background: #ffffff;
  --color-surface: #f9fafb;
  --color-text-primary: #111827;
  --color-text-secondary: #6b7280;
  --color-accent: #2563eb;
  --color-border: #e5e7eb;
  --radius: 6px;
}
```

#### `app/(auth)/login/page.tsx`
```tsx
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await api.post<{ access_token: string }>("/auth/login", { email, password });
      localStorage.setItem("access_token", res.access_token);
      router.push("/dashboard");
    } catch {
      setError("Invalid email or password. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh", background: "var(--color-background)" }}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 16, width: 340, padding: "2rem", background: "var(--color-surface)", borderRadius: "var(--radius)", boxShadow: "var(--shadow-lg)" }}>
        <h1 style={{ fontWeight: 800, fontSize: 24, letterSpacing: "-0.03em", color: "var(--color-text)", margin: 0 }}>Sign in</h1>
        <p style={{ color: "var(--color-text-muted)", fontSize: 14, margin: 0 }}>Welcome back. Enter your credentials to continue.</p>
        {error && (
          <div role="alert" style={{ padding: "10px 12px", background: "color-mix(in srgb, var(--color-error) 15%, transparent)", border: "1px solid var(--color-error)", borderRadius: "var(--radius)", color: "var(--color-error)", fontSize: 13 }}>
            {error}
          </div>
        )}
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <label htmlFor="email" style={{ fontSize: 13, fontWeight: 500, color: "var(--color-text)" }}>Email</label>
          <input id="email" type="email" value={email} onChange={e => setEmail(e.target.value)} required autoComplete="email"
            style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", background: "var(--color-background)", color: "var(--color-text)", fontSize: 14 }} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          <label htmlFor="password" style={{ fontSize: 13, fontWeight: 500, color: "var(--color-text)" }}>Password</label>
          <input id="password" type="password" value={password} onChange={e => setPassword(e.target.value)} required autoComplete="current-password"
            style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", background: "var(--color-background)", color: "var(--color-text)", fontSize: 14 }} />
        </div>
        <button type="submit" disabled={loading}
          style={{ padding: "10px", backgroundColor: loading ? "var(--color-border)" : "var(--color-accent)", color: "#fff", border: "none", borderRadius: "var(--radius)", fontWeight: 600, cursor: loading ? "not-allowed" : "pointer", transition: "var(--transition)" }}>
          {loading ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}
```

#### `app/dashboard/page.tsx`
```tsx
export default function DashboardPage() {
  return (
    <main style={{ padding: "2rem" }}>
      <h1>Dashboard</h1>
      <p>Your content goes here.</p>
    </main>
  );
}
```

#### `components/ui/Button.tsx`
```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
}
export function Button({ variant = "primary", size = "md", children, ...props }: ButtonProps) {
  const pad = { sm: "8px 12px", md: "10px 18px", lg: "12px 24px" }[size];
  return (
    <button {...props} style={{
      padding: pad,
      backgroundColor: variant === "primary" ? "var(--color-accent)" : "transparent",
      color: variant === "primary" ? "#fff" : "var(--color-text-primary)",
      border: variant === "secondary" ? "1px solid var(--color-border)" : "none",
      borderRadius: "var(--radius)", cursor: "pointer", fontWeight: 500, ...props.style,
    }}>{children}</button>
  );
}
```

#### `components/ui/Input.tsx`
```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> { label?: string; }
export function Input({ label, id, ...props }: InputProps) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
      {label && <label htmlFor={id} style={{ fontSize: 13, fontWeight: 500 }}>{label}</label>}
      <input id={id} {...props} style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", fontSize: 14, ...props.style }} />
    </div>
  );
}
```

#### `components/ui/index.ts`
```ts
export { Button } from "./Button";
export { Input } from "./Input";
```

#### `components/layout/Header.tsx`
```tsx
import Link from "next/link";
export function Header() {
  return (
    <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 24px", height: 56, borderBottom: "1px solid var(--color-border)" }}>
      <Link href="/" style={{ fontWeight: 700, textDecoration: "none", color: "var(--color-text-primary)" }}>&lt;APP NAME&gt;</Link>
      <nav style={{ display: "flex", gap: 16 }}>
        <Link href="/dashboard" style={{ fontSize: 14, color: "var(--color-text-secondary)", textDecoration: "none" }}>Dashboard</Link>
      </nav>
    </header>
  );
}
```

#### `lib/api.ts`
```ts
const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("access_token");
}

interface FetchOptions extends RequestInit { on401?: () => void; }

async function request<T>(path: string, options: FetchOptions = {}): Promise<T> {
  const token = getToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers },
  });
  if (res.status === 401) { options.on401?.(); throw new Error("Unauthorized"); }
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const api = {
  get: <T>(path: string, opts?: FetchOptions) => request<T>(path, { method: "GET", ...opts }),
  post: <T>(path: string, body?: unknown, opts?: FetchOptions) =>
    request<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined, ...opts }),
  delete: <T>(path: string, opts?: FetchOptions) => request<T>(path, { method: "DELETE", ...opts }),
};
```

#### `lib/hooks.ts`
```ts
"use client";
import { useEffect, useState } from "react";

export function useAuth() {
  const [token, setToken] = useState<string | null>(null);
  useEffect(() => { setToken(localStorage.getItem("access_token")); }, []);
  return { token, isLoggedIn: !!token, signOut: () => { localStorage.removeItem("access_token"); setToken(null); } };
}

type Breakpoint = "mobile" | "tablet" | "desktop";
export function useBreakpoint(): Breakpoint {
  const [bp, setBp] = useState<Breakpoint>("desktop");
  useEffect(() => {
    const update = () => setBp(window.innerWidth < 640 ? "mobile" : window.innerWidth < 1024 ? "tablet" : "desktop");
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, []);
  return bp;
}
```

#### `lib/utils.ts`
```ts
export const cn = (...c: (string | undefined | false | null)[]): string => c.filter(Boolean).join(" ");
export const formatDate = (iso: string): string =>
  new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
```

#### `types/index.ts`
```ts
export interface User { id: string; email: string; role: string; org_id: string; }
export interface ApiError { detail: string; status: number; }
```

#### `.env.example`
```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
```

#### `.gitignore`
```
node_modules/
.next/
out/
.env.local
.env*.local
```

#### `.github/workflows/ci.yml`
```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
jobs:
  frontend:
    name: Frontend — type-check + build + lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run type-check
      - run: npm run build
      - run: npm run lint
```

#### `CLAUDE.md` (Next.js variant)
```markdown
# CLAUDE.md — <APP NAME>

## THIS PROJECT
**Stack:** Next.js 15, React 19, TypeScript, Tailwind CSS v4
**API:** NEXT_PUBLIC_API_URL in .env

## DEV
```bash
npm install && npm run dev   # http://localhost:3000
npm run type-check           # TypeScript without building
```

## COMPONENT STRUCTURE
```
components/ui/       ← primitives — Button, Input, no business logic
components/layout/   ← Header, Footer, Sidebar — app shell
components/features/ ← page-specific business components
lib/api.ts           ← all fetch calls go through api.get / api.post
lib/hooks.ts         ← useAuth, useBreakpoint
lib/utils.ts         ← cn(), formatDate()
```

## RULES
- CSS custom properties only — never raw hex in components
- All API calls use lib/api.ts — never raw fetch() in components
- components/ui/ are pure primitives — no API calls, no router, no auth
- Every input must have a label with htmlFor

## TYPESCRIPT TYPE RULES — SINGLE SOURCE OF TRUTH
1. Any interface used by 2+ files → lives in `types.ts`, never duplicated
2. Feature modules with 2+ sub-components get a `_components/` folder containing:
   - `types.ts`   — all shared interfaces and union types
   - `styles.ts`  — style objects and style helper functions
   - `helpers.ts` — pure utility functions (no JSX)
3. Union types / type aliases → `types.ts` only, never inside `styles.ts` or `helpers.ts`
4. No workaround types (duck types, partial re-definitions) — fix the import graph instead

## DRY RULES
- Any React component used in 2+ files → extract to shared file before copy-pasting
- Small shared UI helpers (ErrorBanner, Spinner, LoadingState) → `components/ui/`, never inlined

## KNOWN FIXES — DO NOT REVERT
(Record discovered bugs and fixed patterns here so they are never accidentally reverted.
Format: what was wrong → what the fix is → which files it applies to.)
```
```

---

### FRONTEND ONLY — REACT + VITE

Only create these files when user chose "Frontend only → React + Vite". Skip all Python/backend files entirely.

#### Directory structure

```
<app-name>/
├── src/
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Button.tsx
│   │   │   ├── Input.tsx
│   │   │   └── index.ts
│   │   ├── layout/
│   │   │   └── Header.tsx
│   │   └── features/      ← empty, fill with page-specific components
│   ├── pages/
│   │   ├── HomePage.tsx
│   │   ├── LoginPage.tsx
│   │   ├── DashboardPage.tsx
│   │   └── NotFoundPage.tsx
│   ├── hooks/
│   │   └── useAuth.ts
│   ├── lib/
│   │   ├── api.ts
│   │   └── utils.ts
│   ├── store/
│   │   └── auth.ts
│   ├── types/
│   │   └── index.ts
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css
├── public/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── tsconfig.node.json
├── package.json
├── .env.example
├── .gitignore
├── .github/workflows/ci.yml
└── CLAUDE.md
```

#### `package.json`
```json
{
  "name": "<app-name>",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext ts,tsx",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^6.28.0",
    "zustand": "^5.0.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.6.2",
    "vite": "^6.0.0",
    "tailwindcss": "^4.0.0",
    "@tailwindcss/vite": "^4.0.0",
    "eslint": "^9.13.0",
    "eslint-plugin-react-hooks": "^5.0.0",
    "eslint-plugin-react-refresh": "^0.4.14"
  }
}
```

#### `vite.config.ts`
```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": path.resolve(__dirname, "./src") } },
});
```

#### `tsconfig.json`
```json
{
  "files": [],
  "references": [{ "path": "./tsconfig.app.json" }, { "path": "./tsconfig.node.json" }]
}
```

#### `tsconfig.node.json`
```json
{
  "compilerOptions": {
    "target": "ES2022", "lib": ["ES2023"], "module": "ESNext",
    "moduleResolution": "bundler", "allowImportingTsExtensions": true,
    "isolatedModules": true, "moduleDetection": "force",
    "noEmit": true, "strict": true, "skipLibCheck": true
  },
  "include": ["vite.config.ts"]
}
```

#### `index.html`
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><APP NAME></title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

#### `src/main.tsx`
```tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./App";
createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>);
```

#### `src/App.tsx`
```tsx
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { DashboardPage } from "./pages/DashboardPage";
import { NotFoundPage } from "./pages/NotFoundPage";
import { useAuthStore } from "./store/auth";

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const token = useAuthStore(s => s.token);
  return token ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/dashboard" element={<PrivateRoute><DashboardPage /></PrivateRoute>} />
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </BrowserRouter>
  );
}
```

#### `src/index.css`
```css
@import "tailwindcss";

:root {
  --color-background: #ffffff;
  --color-surface: #f9fafb;
  --color-text-primary: #111827;
  --color-text-secondary: #6b7280;
  --color-accent: #2563eb;
  --color-border: #e5e7eb;
  --radius: 6px;
}

*, *::before, *::after { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, sans-serif; background: var(--color-background); color: var(--color-text-primary); }
```

#### `src/store/auth.ts`
```ts
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface AuthState {
  token: string | null;
  email: string | null;
  setToken: (token: string, email: string) => void;
  signOut: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    set => ({
      token: null, email: null,
      setToken: (token, email) => set({ token, email }),
      signOut: () => set({ token: null, email: null }),
    }),
    { name: "auth-storage" }
  )
);
```

#### `src/lib/api.ts`
```ts
const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8000";

function getToken(): string | null {
  try { return JSON.parse(localStorage.getItem("auth-storage") ?? "{}").state?.token ?? null; }
  catch { return null; }
}

interface FetchOptions extends RequestInit { on401?: () => void; }

async function request<T>(path: string, options: FetchOptions = {}): Promise<T> {
  const token = getToken();
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers },
  });
  if (res.status === 401) { options.on401?.(); throw new Error("Unauthorized"); }
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const api = {
  get: <T>(path: string, opts?: FetchOptions) => request<T>(path, { method: "GET", ...opts }),
  post: <T>(path: string, body?: unknown, opts?: FetchOptions) =>
    request<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined, ...opts }),
  delete: <T>(path: string, opts?: FetchOptions) => request<T>(path, { method: "DELETE", ...opts }),
};
```

#### `src/lib/utils.ts`
```ts
export const cn = (...c: (string | undefined | false | null)[]): string => c.filter(Boolean).join(" ");
export const formatDate = (iso: string): string =>
  new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
```

#### `src/hooks/useAuth.ts`
```ts
import { useNavigate } from "react-router-dom";
import { useAuthStore } from "@/store/auth";

export function useAuth() {
  const { token, email, setToken, signOut: storeSignOut } = useAuthStore();
  const navigate = useNavigate();
  return { token, email, isLoggedIn: !!token, setToken, signOut: () => { storeSignOut(); navigate("/login"); } };
}
```

#### `src/pages/HomePage.tsx`
```tsx
import { Link } from "react-router-dom";
export function HomePage() {
  return (
    <main style={{ padding: "4rem 2rem", maxWidth: 640, margin: "0 auto" }}>
      <h1 style={{ fontWeight: 800, fontSize: 48, letterSpacing: "-0.03em", marginBottom: 16 }}>&lt;APP NAME&gt;</h1>
      <p style={{ color: "var(--color-text-secondary)", fontSize: 16, marginBottom: 32 }}>Your app description here.</p>
      <Link to="/login" style={{ padding: "10px 20px", backgroundColor: "var(--color-accent)", color: "#fff", borderRadius: "var(--radius)", textDecoration: "none", fontWeight: 600 }}>
        Get started →
      </Link>
    </main>
  );
}
```

#### `src/pages/LoginPage.tsx`
```tsx
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
import { api } from "@/lib/api";

export function LoginPage() {
  const navigate = useNavigate();
  const { setToken } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      const res = await api.post<{ access_token: string }>("/auth/login", { email, password });
      setToken(res.access_token, email);
      navigate("/dashboard");
    } catch { setError("Invalid email or password."); }
  }

  return (
    <main style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh" }}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 12, width: 320 }}>
        <h1 style={{ fontWeight: 700, fontSize: 24, letterSpacing: "-0.02em" }}>Sign in</h1>
        {error && <p role="alert" style={{ color: "var(--color-error, #dc2626)", fontSize: 13 }}>{error}</p>}
        <label htmlFor="email" style={{ fontSize: 13, fontWeight: 500 }}>Email</label>
        <input id="email" type="email" value={email} onChange={e => setEmail(e.target.value)} required
          style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)" }} />
        <label htmlFor="password" style={{ fontSize: 13, fontWeight: 500 }}>Password</label>
        <input id="password" type="password" value={password} onChange={e => setPassword(e.target.value)} required
          style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)" }} />
        <button type="submit" style={{ padding: "10px", backgroundColor: "var(--color-accent)", color: "#fff", border: "none", borderRadius: "var(--radius)", fontWeight: 600, cursor: "pointer" }}>
          Sign in
        </button>
      </form>
    </main>
  );
}
```

#### `src/pages/DashboardPage.tsx`
```tsx
import { useAuth } from "@/hooks/useAuth";
export function DashboardPage() {
  const { email, signOut } = useAuth();
  return (
    <main style={{ padding: "2rem" }}>
      <h1>Dashboard</h1>
      <p>Signed in as {email}</p>
      <button onClick={signOut} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--color-text-secondary)" }}>Sign out</button>
    </main>
  );
}
```

#### `src/pages/NotFoundPage.tsx`
```tsx
import { Link } from "react-router-dom";
export function NotFoundPage() {
  return (
    <main style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "100vh", gap: 16 }}>
      <p style={{ fontWeight: 800, fontSize: 64, letterSpacing: "-0.04em", color: "var(--color-text-secondary)" }}>404</p>
      <p>This page does not exist.</p>
      <Link to="/">Go home</Link>
    </main>
  );
}
```

#### `src/components/ui/Button.tsx`
```tsx
interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
}
export function Button({ variant = "primary", size = "md", children, ...props }: ButtonProps) {
  const pad = { sm: "8px 12px", md: "10px 18px", lg: "12px 24px" }[size];
  return (
    <button {...props} style={{
      padding: pad, cursor: "pointer", fontWeight: 500, borderRadius: "var(--radius)",
      backgroundColor: variant === "primary" ? "var(--color-accent)" : "transparent",
      color: variant === "primary" ? "#fff" : "var(--color-text-primary)",
      border: variant === "secondary" ? "1px solid var(--color-border)" : "none",
      ...props.style,
    }}>{children}</button>
  );
}
```

#### `src/components/ui/Input.tsx`
```tsx
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> { label?: string; }
export function Input({ label, id, ...props }: InputProps) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
      {label && <label htmlFor={id} style={{ fontSize: 13, fontWeight: 500 }}>{label}</label>}
      <input id={id} {...props} style={{ padding: "9px 12px", border: "1px solid var(--color-border)", borderRadius: "var(--radius)", fontSize: 14, ...props.style }} />
    </div>
  );
}
```

#### `src/components/ui/index.ts`
```ts
export { Button } from "./Button";
export { Input } from "./Input";
```

#### `src/components/layout/Header.tsx`
```tsx
import { Link } from "react-router-dom";
import { useAuth } from "@/hooks/useAuth";
export function Header() {
  const { isLoggedIn, signOut } = useAuth();
  return (
    <header style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 24px", height: 56, borderBottom: "1px solid var(--color-border)" }}>
      <Link to="/" style={{ fontWeight: 700, textDecoration: "none", color: "var(--color-text-primary)" }}>&lt;APP NAME&gt;</Link>
      <nav>
        {isLoggedIn
          ? <button onClick={signOut} style={{ background: "none", border: "none", cursor: "pointer" }}>Sign out</button>
          : <Link to="/login" style={{ textDecoration: "none", color: "var(--color-text-secondary)" }}>Sign in</Link>}
      </nav>
    </header>
  );
}
```

#### `src/types/index.ts`
```ts
export interface User { id: string; email: string; role: string; org_id: string; }
export interface ApiError { detail: string; status: number; }
```

#### `.env.example`
```bash
VITE_API_URL=http://localhost:8000
```

#### `.gitignore`
```
node_modules/
dist/
.env.local
.env*.local
```

#### `.github/workflows/ci.yml`
```yaml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
jobs:
  frontend:
    name: Frontend — type-check + build + lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: "npm"
      - run: npm ci
      - run: npm run type-check
      - run: npm run build
      - run: npm run lint
```

#### `CLAUDE.md` (React + Vite variant)
```markdown
# CLAUDE.md — <APP NAME>

## THIS PROJECT
**Stack:** React 19, Vite 6, TypeScript, Tailwind CSS v4, React Router v6, Zustand
**API:** VITE_API_URL in .env

## DEV
```bash
npm install && npm run dev   # http://localhost:5173
npm run type-check           # TypeScript without building
```

## STRUCTURE
```
src/components/ui/       ← primitives — Button, Input, no business logic
src/components/layout/   ← Header, Sidebar — app chrome
src/components/features/ ← page-specific components
src/pages/               ← one file per route, imported in App.tsx
src/hooks/useAuth.ts     ← auth hook wrapping Zustand store
src/lib/api.ts           ← all API calls go here, never raw fetch()
src/store/auth.ts        ← Zustand + localStorage persistence
src/types/               ← shared TypeScript interfaces
```

## RULES
- All API calls use src/lib/api.ts — never raw fetch() in components
- Auth state lives in Zustand store — never useState for auth
- src/components/ui/ are pure primitives — no router imports, no API calls
- CSS custom properties only — never raw hex in components
- Every input must have a label with htmlFor

## TYPESCRIPT TYPE RULES — SINGLE SOURCE OF TRUTH
1. Any interface used by 2+ files → lives in `types.ts`, never duplicated
2. Feature modules with 2+ sub-components get a `_components/` folder containing:
   - `types.ts`   — all shared interfaces and union types
   - `styles.ts`  — style objects and style helper functions
   - `helpers.ts` — pure utility functions (no JSX)
3. Union types / type aliases → `types.ts` only, never inside `styles.ts` or `helpers.ts`
4. No workaround types (duck types, partial re-definitions) — fix the import graph instead

## DRY RULES
- Any React component used in 2+ files → extract to shared file before copy-pasting
- Small shared UI helpers (ErrorBanner, Spinner, LoadingState) → `src/components/ui/`, never inlined

## KNOWN FIXES — DO NOT REVERT
(Record discovered bugs and fixed patterns here so they are never accidentally reverted.
Format: what was wrong → what the fix is → which files it applies to.)
```
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
And omit the `make frontend` and frontend CI lines from the "What's ready" list.
