# References - backend (FastAPI / Python) scaffold

Loaded by the orchestrator when the user picks **Full stack** or **Backend only**.

All file templates below are emitted verbatim (with `<app-name>` substituted).

---

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
│   ├── prompts/          ← LangSmith prompt YAML files + registry.py (AI + SaaS only)
│   └── main.py
├── deploy/               ← Modal, Dockerfile variants (AI + SaaS only)
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── tools/                ← build quality: checkpoint_runner, drift_detector, smoke_test (never ops)
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

**Interface:** `messages: list[dict]` — standard OpenAI/Anthropic format. Pass system prompt as
`{"role": "system", "content": "..."}` and user turn as `{"role": "user", "content": "..."}`.
This handles multi-turn, caching, and all providers uniformly — never use `(system_prompt, user_message)` positional params.

Providers: `openai | anthropic | openrouter | ollama | azure | modal`
```python
import time
from typing import Optional
from app.config import settings


def _http_client():
    """Return an httpx.AsyncClient with SSL disabled when SSL_VERIFY=false (Windows corp proxies)."""
    if not getattr(settings, "ssl_verify", True):
        import httpx
        return httpx.AsyncClient(verify=False)
    return None


def get_llm_client():
    provider = settings.llm_provider.lower()
    http_client = _http_client()

    if provider == "openai":
        from openai import AsyncOpenAI
        kwargs = {"api_key": settings.openai_api_key}
        if http_client:
            kwargs["http_client"] = http_client
        return AsyncOpenAI(**kwargs)

    elif provider == "anthropic":
        from anthropic import AsyncAnthropic
        kwargs = {"api_key": settings.anthropic_api_key}
        if http_client:
            kwargs["http_client"] = http_client
        return AsyncAnthropic(**kwargs)

    elif provider == "openrouter":
        from openai import AsyncOpenAI
        kwargs = {"api_key": settings.openrouter_api_key, "base_url": "https://openrouter.ai/api/v1"}
        if http_client:
            kwargs["http_client"] = http_client
        return AsyncOpenAI(**kwargs)

    elif provider == "ollama":
        from openai import AsyncOpenAI
        return AsyncOpenAI(api_key="ollama", base_url=f"{settings.ollama_base_url}/v1")

    elif provider == "azure":
        from openai import AsyncAzureOpenAI
        kwargs = {
            "api_key": settings.azure_openai_api_key,
            "azure_endpoint": settings.azure_openai_endpoint,
            "api_version": "2024-02-01",
        }
        if http_client:
            kwargs["http_client"] = http_client
        return AsyncAzureOpenAI(**kwargs)

    elif provider == "modal":
        from openai import AsyncOpenAI
        import httpx
        modal_http = httpx.AsyncClient(timeout=600, verify=getattr(settings, "ssl_verify", True), follow_redirects=True)
        return AsyncOpenAI(api_key="modal", base_url=f"{settings.modal_llm_url.rstrip('/')}/v1", http_client=modal_http)

    else:
        raise ValueError(f"Unknown LLM_PROVIDER: '{provider}'. Valid: openai, anthropic, openrouter, ollama, azure, modal")


def get_model_name() -> str:
    mapping = {
        "openai":     getattr(settings, "openai_model", "gpt-4o"),
        "anthropic":  getattr(settings, "anthropic_model", "claude-sonnet-4-6"),
        "openrouter": getattr(settings, "openrouter_model", "openai/gpt-4o"),
        "ollama":     getattr(settings, "ollama_model", "qwen2.5:72b"),
        "azure":      settings.azure_openai_deployment,
        "modal":      getattr(settings, "modal_llm_model", "served-model"),
    }
    return mapping.get(settings.llm_provider.lower(), "gpt-4o")


async def call_llm(
    messages: list[dict],
    temperature: float = 0.1,
    max_tokens: int = 4096,
    response_format: Optional[dict] = None,
) -> str:
    """
    Unified LLM call across all providers.
    Agents call this — never the provider SDK directly.

    Usage:
        result = await call_llm([
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ])
    """
    provider = settings.llm_provider.lower()
    client = get_llm_client()
    model = get_model_name()

    if provider == "anthropic":
        system_msg = next((m["content"] for m in messages if m["role"] == "system"), None)
        user_msgs = [m for m in messages if m["role"] != "system"]
        resp = await client.messages.create(
            model=model, max_tokens=max_tokens,
            system=system_msg or "You are a helpful assistant.",
            messages=user_msgs,
        )
        return resp.content[0].text
    else:
        kwargs = {"model": model, "max_tokens": max_tokens, "temperature": temperature, "messages": messages}
        if response_format and provider in ("openai", "openrouter", "azure"):
            kwargs["response_format"] = response_format
        resp = await client.chat.completions.create(**kwargs)
        return resp.choices[0].message.content
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

### `.gitignore`
```
# Python
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
dist/
build/
.pytest_cache/
.ruff_cache/

# Env
.env
.env.local
.env*.local

# Secrets / local state — never commit
*.smoke_test_state.json
SESSION_PLAN.md

# Test data (large PDFs, sample documents — store in shared drive instead)
data/documents/

# Node
node_modules/
.next/
out/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
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

