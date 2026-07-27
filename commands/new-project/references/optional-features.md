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

### `app/validators/injection.py`  [AI apps that ingest UNTRUSTED documents/user content]
Prompt-injection defence (**OWASP LLM01**). Untrusted vendor/user content can embed
instructions to manipulate the LLM ("ignore previous instructions and ..."). Scan chunk
text at the single ingestion choke point — BEFORE any LLM consumes it — and turn a match
into a guardrail/critic **block**. Fail-CLOSED.
- Patterns + threshold live in CONFIG (platform.yaml / settings), **never hardcoded**.
- Scan UNTRUSTED inputs only; exempt trusted first-party docs (pass `trusted_source=True`).
- Findings are a typed model (e.g. `InjectionFinding`) on the ingestion output — never raw text.
```python
import re

def scan_text(text: str, patterns) -> list[tuple[str, str]]:
    """Return (pattern_name, matched_snippet) for each config pattern that fires.
    `patterns` come from config (each has .name and .regex) — nothing hardcoded here."""
    hits = []
    for pat in patterns:
        m = re.compile(pat.regex).search(text or "")
        if m:
            hits.append((pat.name, m.group(0)[:160].strip()))
    return hits
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

# SSL workaround for Windows corporate proxies with TLS inspection
if os.getenv("SSL_VERIFY", "true").lower() == "false":
    import ssl
    import urllib.request
    ssl._create_default_https_context = ssl._create_unverified_context
    os.environ["CURL_CA_BUNDLE"] = ""
    os.environ["REQUESTS_CA_BUNDLE"] = ""

def push_prompts():
    api_key = os.getenv("LANGSMITH_API_KEY")
    if not api_key:
        print("ERROR: LANGSMITH_API_KEY not set in .env")
        sys.exit(1)

    from langsmith import Client
    client = Client()

    yaml_files = list(PROMPTS_DIR.rglob("*.yaml"))
    if not yaml_files:
        print("No YAML prompt files found in app/prompts/")
        return

    for path in yaml_files:
        with open(path, encoding="utf-8") as f:
            data = yaml.safe_load(f)

        name = data.get("name") or path.stem.replace("_", "-")
        template = data.get("template", "")

        try:
            from langchain_core.prompts import PromptTemplate
            prompt = PromptTemplate.from_template(template)
            client.push_prompt(name, object=prompt)
            print(f"  ✅ pushed: {name}")
        except Exception as e:
            print(f"  ❌ failed: {name} — {e}")

if __name__ == "__main__":
    push_prompts()
```

### `deploy/modal.py`
```python
"""
Modal deployment — GPU inference, batch embeddings, scheduled jobs.
Deploy: modal deploy deploy/modal.py
"""
import modal

app = modal.App("app-name")
image = (
    modal.Image.debian_slim()
    .pip_install_from_requirements("requirements.txt")
    # Modal >=1.0 does NOT auto-mount local source — bundle it explicitly or containers
    # die with ModuleNotFoundError at runtime (deploy itself succeeds!). add_local_dir
    # (not add_local_python_source) when the package carries non-.py data (yaml configs).
    .add_local_dir("app", remote_path="/root/app", ignore=["**/__pycache__"])
)

@app.function(image=image, schedule=modal.Cron("0 2 * * *"))
def daily_cleanup():
    from app.jobs.cleanup import cleanup_old_records
    cleanup_old_records()
```

**Modal deploy gotchas (learned the hard way on a shipped GPU project):**
- `@modal.fastapi_endpoint` no longer auto-injects FastAPI — put `fastapi[standard]` in
  requirements.txt or every web endpoint 404s after a "successful" deploy.
- If the app mixes CPU web endpoints + a GPU function in one module: define the GPU function
  BEFORE any fastapi import. Modal imports the whole module in EVERY container; if the
  fastapi import fails in the slim GPU image, the GPU function is silently never registered
  ("module has no attribute X").
- **Windows CLI:** Modal's gRPC needs the OS cert store — run via a shim that calls
  `truststore.inject_into_ssl()` first; and set `PYTHONUTF8=1` or build logs crash the CLI
  with a 'charmap' codec error. Invoke as `python -m modal ...` (PS5.1 can't exec `.venv\Scripts\modal`).
- **Scripts passed to `modal run`/inline apps re-import ON the container** — guard local-only
  imports (truststore, dev tooling) in try/except ImportError.
- **HF-gated models** (FLUX, Llama, …): the license must be accepted on the SAME account as
  the token in your Modal secret (check with whoami — 401 = no token sent, 403 = wrong
  account/not accepted). Pass `token=` to `from_pretrained`.
- **FLUX-class 12B models on 24GB GPUs (A10G/4090):** bf16 OOMs even with
  `enable_model_cpu_offload()` (the transformer alone ≈22GB must fit on-GPU). Use
  bitsandbytes NF4 on transformer + text_encoder_2 (prebuilt kernels, no CUDA toolkit
  needed) — fits ~14GB at full speed. optimum-quanto qfloat8 needs a nvidia/cuda-devel base
  image (JIT-compiles). Cache weights in a `modal.Volume` mounted at `HF_HOME`.
- Cost guardrails: explicit `timeout=` on EVERY function (GPU ones sized for cold start +
  one unit of work); never `keep_warm`/`min_containers` without a cost review.

---

