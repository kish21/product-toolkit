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
│   ├── db/               ← models.py (SQLAlchemy ORM — single source of truth), base.py (engine + get_db)
│   ├── jobs/             ← scheduled work + background tasks
│   ├── schemas/          ← Pydantic output models (AI + SaaS only)
│   ├── prompts/          ← LangSmith prompt YAML files + registry.py (AI + SaaS only)
│   └── main.py
├── deploy/               ← Modal, Dockerfile variants (AI + SaaS only)
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── tools/                ← build quality: smoke_test.py, push_prompts.py [AI apps] (never ops)
├── scripts/              ← ops only: seed, reset (never test code)
├── .mcp/                 ← MCP servers for Claude Code
├── .github/
│   ├── workflows/        ← ci.yml (lint + test + CVE scan)
│   ├── dependabot.yml    ← weekly dependency-update PRs (pip + npm + actions)
│   └── SECURITY.md       ← responsible-disclosure policy (enables "Report a vulnerability")
├── migrations/           ← Alembic (env.py + versions/ — initial migration included)
├── alembic.ini
├── CHANGELOG.md          ← Keep a Changelog format, starts with [Unreleased]
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

    # Model overrides (read by app/providers/llm.py get_model_name)
    openai_model: str = "gpt-4o"
    anthropic_model: str = "claude-sonnet-4-6"
    openrouter_model: str = "openai/gpt-4o"
    ollama_model: str = "qwen2.5:72b"
    modal_llm_model: str = "served-model"

    # SSL — set false only in dev behind corporate TLS-inspecting proxies
    ssl_verify: bool = True

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
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from app.auth.jwt import create_token
from app.auth.dependencies import get_current_user

router = APIRouter()

class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest):
    # TODO: verify credentials against the users table and load the user's real role + org_id (UUID)
    # Role must be one of: owner | admin | member | viewer — see app/auth/rbac.py
    token = create_token({"sub": request.email, "role": "member", "org_id": "00000000-0000-0000-0000-000000000000"})
    return TokenResponse(access_token=token)

@router.get("/me")
async def me(payload: dict = Depends(get_current_user)):
    return payload
```

---

### API documentation hygiene (OpenAPI / Swagger)

FastAPI auto-generates `/docs`, `/redoc` and `/openapi.json` from the route
decorators — but the default is thin (operation names derived from function
names, empty response schemas, no error docs). For a customer-facing API, treat
the docs as a first-class deliverable from day one. It's all **declarative
metadata** — zero runtime cost.

**1. App-level metadata is config-driven, never hardcoded.** Put the
description / contact / license / per-tag descriptions in your config layer
(yaml/env), defaulted so older config still loads, and read it in `main.py`:

```python
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
    description=settings.api_docs.description,          # from config
    contact={"name": ..., "email": ..., "url": ...},     # from config
    license_info={"name": ..., "url": ...},              # from config
    openapi_tags=[{"name": t.name, "description": t.description}
                  for t in settings.api_docs.tags],      # one line per router tag
)
```

**2. Share error-response specs — don't repeat `responses=` dicts on every
route.** Make one `app/api/openapi_responses.py` documenting your error
envelope once, then compose:

```python
def _err(description, example_detail):
    return {"description": description,
            "content": {"application/json": {"example": {"detail": example_detail}}}}

UNAUTHORIZED = {401: _err("Missing/invalid auth token.", "Not authenticated")}
FORBIDDEN    = {403: _err("Caller lacks the required role.", "Insufficient permissions")}
NOT_FOUND    = {404: _err("Resource not found / not visible to this org.", "Not found")}
CONFLICT     = {409: _err("Conflicts with current state.", "Conflict")}

def responses(*specs):           # responses=responses(UNAUTHORIZED, NOT_FOUND)
    out = {}
    for s in specs: out.update(s)
    return out
```

Annotate each route with a `summary`, a docstring/`description`, and only the
error codes it can ACTUALLY raise (read each `Depends`/`HTTPException` first — a
401 on a public route is a lie in the docs).

**3. The one footgun — `response_model` filters the body.** Adding
`response_model=X` to a route that returns a raw dict makes FastAPI silently
drop any key not on `X` and coerce types — that's a **behaviour change**, not an
annotation. Only set `response_model` where the handler already returns exactly
that model; otherwise document the shape via a `responses` example.

**4. Gate it in CI with a meta-test** so new routes can't regress the docs.
Iterate `app.openapi()` + the route table:

```python
def test_every_operation_has_summary_and_description():
    missing = [f"{m.upper()} {p}" for p, methods in app.openapi()["paths"].items()
               for m, op in methods.items()
               if m in {"get","post","put","patch","delete"}
               and (not op.get("summary") or not op.get("description"))]
    assert not missing, f"Routes missing docs: {missing}"

def test_response_model_set_is_unchanged():
    # Pin the set of routes bound to a response_model (explicit OR via a `-> Model`
    # return annotation). A change here means someone risked filtering a body —
    # prove the body is byte-unchanged with a snapshot, then update the baseline.
    from fastapi.routing import APIRoute
    actual = {(m.lower(), r.path) for r in app.routes if isinstance(r, APIRoute)
              and r.response_model is not None for m in r.methods}
    assert actual == RESPONSE_MODEL_BASELINE
```

Auth-route detection for a "must document 401" gate: walk each route's
`route.dependant` tree for your `get_current_user` callable rather than guessing
from the path. Don't auto-require 403 — most role checks live in the handler
body and aren't detectable from the route table; annotate those by hand.

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
    """FastAPI dependency factory — raises 403 if user role not in allowed list.

    Usage in a route:
        @router.get("/admin", dependencies=[Depends(require_role("owner", "admin"))])
    """
    from fastapi import Depends
    from app.auth.dependencies import get_current_user

    def checker(payload: dict = Depends(get_current_user)) -> dict:
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
    """FastAPI dependency factory — raises 403 if role lacks the action.

    Usage in a route:
        @router.delete("/items/{id}", dependencies=[Depends(require_permission("delete"))])
    """
    from fastapi import Depends
    from app.auth.dependencies import get_current_user

    def checker(payload: dict = Depends(get_current_user)) -> dict:
        role = payload.get("role", "viewer")
        if not has_permission(role, action):
            raise HTTPException(status_code=403, detail=f"Role '{role}' cannot '{action}'")
        return payload
    return checker
```

### `app/auth/dependencies.py`
FastAPI `Depends()` resolvers — imported by all routes.
```python
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

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

### `app/db/base.py`
Engine + session factory + the `get_db` FastAPI dependency. Routes get a session via
`db: Session = Depends(get_db)` — never create engines or sessions ad hoc.
```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db():
    """FastAPI dependency — yields a session, always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### `app/db/models.py`
SQLAlchemy 2.0 typed models — the single source of truth for the schema.
Alembic autogenerates migrations from `Base.metadata`. Never edit tables by hand.
```python
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class Org(Base):
    __tablename__ = "orgs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    slug: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    plan: Mapped[str] = mapped_column(Text, nullable=False, default="free", server_default="free")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class User(Base):
    __tablename__ = "users"
    __table_args__ = (Index("idx_users_org", "org_id"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    org_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("orgs.id", ondelete="CASCADE"), nullable=False
    )
    email: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    # owner | admin | member | viewer — must match app/auth/rbac.py
    role: Mapped[str] = mapped_column(Text, nullable=False, default="member", server_default="member")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class AuditLog(Base):
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("idx_audit_org", "org_id"),
        Index("idx_audit_created", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    org_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orgs.id"), nullable=False)
    user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    action: Mapped[str] = mapped_column(Text, nullable=False)
    resource: Mapped[str | None] = mapped_column(Text, nullable=True)
    # attribute is `meta` because `metadata` is reserved by SQLAlchemy Declarative
    meta: Mapped[dict | None] = mapped_column("metadata", JSONB, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
```

### `alembic.ini`
```ini
[alembic]
script_location = migrations
prepend_sys_path = .
# sqlalchemy.url is set at runtime from DATABASE_URL — see migrations/env.py

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

### `migrations/env.py`
Wired to `Base.metadata` so `alembic revision --autogenerate` diffs the models,
and reads the URL from `.env` via app settings — never hardcoded.
```python
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.config import settings
from app.db.models import Base

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", settings.database_url)
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

### `migrations/script.py.mako`
```mako
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
```

### `migrations/versions/0001_initial_schema.py`
Hand-written initial migration matching `app/db/models.py` exactly — `make dev` runs it
on first boot. All later schema changes: `make migration m="..."` then `make migrate`.
```python
"""initial schema

Revision ID: 0001
Revises:
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "orgs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("slug", sa.Text(), nullable=False, unique=True),
        sa.Column("plan", sa.Text(), nullable=False, server_default="free"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("org_id", UUID(as_uuid=True), sa.ForeignKey("orgs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("email", sa.Text(), nullable=False, unique=True),
        sa.Column("role", sa.Text(), nullable=False, server_default="member"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_table(
        "audit_logs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("org_id", UUID(as_uuid=True), sa.ForeignKey("orgs.id"), nullable=False),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("action", sa.Text(), nullable=False),
        sa.Column("resource", sa.Text(), nullable=True),
        sa.Column("metadata", JSONB(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("idx_users_org", "users", ["org_id"])
    op.create_index("idx_audit_org", "audit_logs", ["org_id"])
    op.create_index("idx_audit_created", "audit_logs", ["created_at"])


def downgrade() -> None:
    op.drop_table("audit_logs")
    op.drop_table("users")
    op.drop_table("orgs")
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

### `tests/unit/test_smoke.py`
Placeholder so `pytest tests/unit` passes from day one (pytest exits with code 5 on an
empty test dir, which would fail `make check` and CI). Replace with real tests.
```python
"""Smoke test — proves the app imports and core config loads. Replace with real tests."""
from app.config import settings


def test_app_imports():
    from app.main import app
    assert app.title == settings.app_name


def test_rbac_matrix_is_consistent():
    from app.auth.rbac import ROLE_PERMISSIONS
    assert set(ROLE_PERMISSIONS) == {"owner", "admin", "member", "viewer"}


def test_models_define_core_tables():
    from app.db.models import Base
    assert {"orgs", "users", "audit_logs"} <= set(Base.metadata.tables)
```

### `tests/integration/.gitkeep`
Empty file — keeps the directory tracked by git.

### `tests/fixtures/.gitkeep`
Empty file.

### `tools/smoke_test.py`
Hit the running app's health + metrics endpoints — quick "is the foundation alive" check.
```python
"""
Smoke test against a RUNNING app — run after `make dev`.
Usage: python tools/smoke_test.py [base_url]
"""
import sys
import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"

def main() -> int:
    failures = 0
    # trust_env=False — never route localhost through a corporate/system proxy
    client = httpx.Client(trust_env=False, timeout=10)
    for path, expect in [("/health", "ok"), ("/metrics", "fastapi")]:
        try:
            r = client.get(f"{BASE}{path}")
            ok = r.status_code == 200 and expect in r.text
            print(f"  {'✅' if ok else '❌'} {path} → {r.status_code}")
            failures += 0 if ok else 1
        except Exception as e:
            print(f"  ❌ {path} → {e}")
            failures += 1
    return failures

if __name__ == "__main__":
    sys.exit(main())
```

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
.PHONY: dev migrate migration test lint seed reset check

dev:
	cp -n .env.example .env 2>/dev/null || true
	docker-compose up -d postgres redis prometheus grafana loki
	pip install -r requirements.txt
	alembic upgrade head
	python scripts/seed.py
	uvicorn app.main:app --reload --port 8000

migrate:
	alembic upgrade head

# Usage: make migration m="add invoices table"  — autogenerates from app/db/models.py
migration:
	alembic revision --autogenerate -m "$(m)"

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

[tool.ruff.lint.per-file-ignores]
# Alembic's conventional import order differs from isort — don't fight it
"migrations/*" = ["I001"]

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
  # NOTE: `make dev` runs the app locally via uvicorn on :8000 and starts only the
  # services below. Uncomment `app` for a prod-like containerised run — but never
  # run both at once (port 8000 conflict).
  # app:
  #   build: .
  #   ports:
  #     - "8000:8000"
  #   env_file: .env
  #   depends_on:
  #     - postgres
  #     - redis
  #   restart: unless-stopped

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

  # Scan pinned Python deps for known CVEs on every push/PR. Added on day one
  # while deps are clean, so it starts (and stays) green — patch CVEs as they
  # appear instead of inheriting a months-deep backlog. Fail-closed on any known
  # vuln; if a transitive vuln has no fix yet, triage it and add its ID to the
  # action's `ignore-vulns:` input below, each with a comment (config in source,
  # never a silent skip). NOTE: use `ignore-vulns:` — passing --ignore-vuln via
  # `extra-args` is NOT honoured by this action.
  dependency-audit:
    name: Dependency CVE scan (pip-audit)
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v4
      - name: pip-audit
        uses: pypa/gh-action-pip-audit@v1.1.0
        with:
          inputs: requirements.txt
          # Example (remove if none): ignore a no-fix, not-reachable CVE with a reason.
          # ignore-vulns: |
          #   PYSEC-XXXX-XXX   # why it's safe to ignore (no fix / not reachable / dev-only)

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
          # 22 = active LTS; match local dev — supabase-js & modern SDKs need native WebSocket (Node 22+)
          node-version: "22"
      # npm install (not ci) — the scaffold has no package-lock.json yet.
      # Switch to `npm ci` after committing the lockfile.
      - run: npm install
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

### `.github/dependabot.yml`
```yaml
# Weekly dependency-update PRs so CVE fixes land automatically — the companion to
# the pip-audit CI gate (the gate detects, the bot fixes). Keeps the backlog at zero.
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels: ["dependencies", "security"]
  - package-ecosystem: "npm"          # drop if backend-only
    directory: "/frontend"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    # Group tightly-coupled packages so they bump together in ONE PR. Bumping them
    # independently drifts their versions apart and breaks the build:
    #   - react / react-dom must share a version (Next refuses a mismatch)
    #   - eslint must move with eslint-config-next (peer-dep compatibility)
    groups:
      react:
        patterns: ["react", "react-dom", "@types/react", "@types/react-dom"]
      eslint:
        patterns: ["eslint", "eslint-config-next", "@eslint/*"]
      next:
        patterns: ["next", "@next/*"]
    labels: ["dependencies", "frontend"]
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels: ["dependencies", "ci"]
```

### `.github/SECURITY.md`
```markdown
# Security Policy

## Supported Versions
Pre-1.0; security fixes ship from the default branch only.

| Version  | Supported |
| -------- | --------- |
| `main`   | ✅        |

## Reporting a Vulnerability
**Do not open a public issue for security vulnerabilities.** Report privately:

- **GitHub** — the **"Report a vulnerability"** button under the repo's **Security** tab.
- **Email** — `security@<your-domain>` with subject `SECURITY:`.

Please include the affected component, steps to reproduce, and the impact.

## What to Expect
| Stage              | Target                 |
| ------------------ | ---------------------- |
| Acknowledgement    | within 3 business days |
| Initial assessment | within 7 business days |

We support coordinated disclosure — please give us a reasonable window to ship a fix.
```

### `CHANGELOG.md`
```markdown
# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial project scaffold.
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

# Model overrides (optional — defaults in app/config.py)
OPENAI_MODEL=gpt-4o
ANTHROPIC_MODEL=claude-sonnet-4-6
OPENROUTER_MODEL=openai/gpt-4o
OLLAMA_MODEL=qwen2.5:72b

# SSL — set false ONLY in dev behind corporate TLS-inspecting proxies
SSL_VERIFY=true

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
pyjwt==2.10.1
httpx==0.28.1
sqlalchemy==2.0.40
alembic==1.16.5
psycopg2-binary==2.9.10
redis==5.2.1
openai==2.33.0
anthropic==0.49.0
mcp==1.9.0
pytest==8.3.5
pytest-asyncio==0.25.0
ruff==0.4.4
prometheus-fastapi-instrumentator==7.1.0
# Add only if EMBEDDING_PROVIDER=local (pulls in torch, ~2GB):
#   sentence-transformers==4.1.0
# AI + SaaS apps also add (see references/optional-features.md):
#   qdrant-client, langsmith, pyyaml, python-dotenv
# Billing adds: stripe
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

