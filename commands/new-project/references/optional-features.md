# References - optional backend features

Loaded by the orchestrator when the user opted into one of these:
- **Billing = Yes** -> emit the billing section below
- **App type = AI + SaaS** -> emit the AI/SaaS section (schemas, prompts, Modal)

---

### ALSO CREATE IF BILLING=YES

Also do these two things:
1. Append to `requirements.txt`: `stripe==12.0.0`
2. In `app/api/routes.py`, mount the router — the import goes AT THE TOP with the other
   imports (an import after `router = APIRouter()` is an E402 lint failure in CI):
   ```python
   from app.api.billing_routes import router as billing_router  # top of file
   ...
   router.include_router(billing_router, prefix="/billing", tags=["billing"])
   ```

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

### `app/auth/billing.py`
Subscription-active check — the dependency that gates paid endpoints (this is the
"subscription check" promised in the scaffold summary).
```python
"""Gate endpoints on an active subscription.

Usage:
    @router.post("/evaluate", dependencies=[Depends(require_active_subscription)])
"""
from fastapi import Depends, HTTPException
from app.auth.dependencies import get_current_user

PAID_PLANS = {"pro", "team", "enterprise"}


def _org_plan(org_id: str) -> str:
    # TODO: SELECT plan FROM orgs WHERE id = :org_id (cache briefly — this runs per request)
    return "free"


def require_active_subscription(payload: dict = Depends(get_current_user)) -> dict:
    plan = _org_plan(payload.get("org_id", ""))
    if plan not in PAID_PLANS:
        raise HTTPException(status_code=402, detail="Active subscription required")
    return payload
```

---

### ALSO CREATE IF AI + SaaS

Also do these three things:
1. Append to `requirements.txt`:
   `qdrant-client==1.12.0`, `langsmith==0.3.4`, `pyyaml==6.0.2`, `python-dotenv==1.0.1`
   (plus `sentence-transformers==4.1.0` only if EMBEDDING_PROVIDER=local)
2. In `docker-compose.yml`, uncomment the `qdrant` service and the `qdrant_data` volume.
3. Create the `deploy/` directory for `deploy/modal.py` below.

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

### `app/prompts/__init__.py`
Empty file.

### `app/prompts/registry.py`
Prompt registry — load from LangSmith Hub (if key set) with local YAML fallback.
Agents call `get_prompt(name, **vars)` — never hardcode prompt strings in agent files.
```python
"""
Load order:
  1. LangSmith Hub  (if LANGSMITH_API_KEY is set and network is reachable)
  2. Local YAML fallback in app/prompts/

Call get_prompt(name, **vars) — returns the filled prompt string ready for call_llm().
"""
from __future__ import annotations
import os
from functools import lru_cache
from pathlib import Path
import yaml

_PROMPTS_DIR = Path(__file__).parent

# Map short names → (langsmith_identifier, local_yaml_file)
_REGISTRY: dict[str, tuple[str, str]] = {
    # Example entries — add your prompts here:
    # "setup/extract_rfp":    ("setup-extract-rfp",    "setup/extract_rfp.yaml"),
}

_cache: dict[str, str] = {}


@lru_cache(maxsize=1)
def _langsmith_available() -> bool:
    if not os.getenv("LANGSMITH_API_KEY"):
        return False
    try:
        from langsmith import Client
        Client().list_prompts(limit=1)
        return True
    except Exception:
        return False


def _load_from_langsmith(identifier: str) -> str | None:
    try:
        from langsmith import Client
        prompt_obj = Client().pull_prompt(identifier)
        if hasattr(prompt_obj, "template"):
            return prompt_obj.template
        if hasattr(prompt_obj, "messages"):
            for msg in prompt_obj.messages:
                if hasattr(msg, "prompt") and hasattr(msg.prompt, "template"):
                    return msg.prompt.template
        return str(prompt_obj)
    except Exception:
        return None


def _load_from_yaml(yaml_file: str) -> str:
    path = _PROMPTS_DIR / yaml_file
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f)
    return data["template"]


def get_prompt(name: str, **variables: str) -> str:
    """Returns the filled prompt string for the given name."""
    if name not in _REGISTRY:
        raise KeyError(f"Unknown prompt: {name!r}. Available: {list(_REGISTRY)}")

    if name not in _cache:
        langsmith_id, yaml_file = _REGISTRY[name]
        if _langsmith_available():
            template = _load_from_langsmith(langsmith_id)
            if template:
                _cache[name] = template
        if name not in _cache:
            _cache[name] = _load_from_yaml(yaml_file)

    template = _cache[name]
    for key, value in variables.items():
        template = template.replace("{" + key + "}", str(value))
    return template
```

### `tools/push_prompts.py`
Push local YAML prompts to LangSmith Hub. Run after editing any `.yaml` in `app/prompts/`.

**Note on Windows / corporate SSL:** Many corp networks use TLS inspection that causes SSL errors
with LangSmith. Set `SSL_VERIFY=false` in `.env` to skip verification only in dev — never in prod.
```python
"""
Push all YAML prompts in app/prompts/ to LangSmith Hub.

Usage:
    python tools/push_prompts.py

Requires LANGSMITH_API_KEY in .env. Set SSL_VERIFY=false if behind a corporate proxy.
"""
import os
import sys
from pathlib import Path
import yaml

# Load .env early so LANGSMITH_API_KEY is available
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

PROMPTS_DIR = Path(__file__).parent.parent / "app" / "prompts"

# SSL workaround for Windows corporate proxies