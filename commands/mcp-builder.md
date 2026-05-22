---
name: mcp-builder
description: Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use when building MCP servers to integrate external APIs or services, whether in Python (FastMCP) or Node/TypeScript (MCP SDK).
---

# MCP Server Development Guide

## Overview

Create MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. The quality of an MCP server is measured by how well it enables LLMs to accomplish real-world tasks.

---

## Process

### Phase 1: Deep Research and Planning

#### 1.1 Understand Modern MCP Design

**API Coverage vs. Workflow Tools:**
Balance comprehensive API endpoint coverage with specialized workflow tools. Workflow tools can be more convenient for specific tasks, while comprehensive coverage gives agents flexibility to compose operations. When uncertain, prioritize comprehensive API coverage.

**Tool Naming and Discoverability:**
Use consistent prefixes (e.g., `github_create_issue`, `github_list_repos`) and action-oriented naming.

**Context Management:**
Design tools that return focused, relevant data. Support filtering and pagination.

**Actionable Error Messages:**
Error messages should guide agents toward solutions with specific suggestions and next steps.

#### 1.2 Study MCP Protocol Documentation

Start with the sitemap: `https://modelcontextprotocol.io/sitemap.xml`

Fetch specific pages with `.md` suffix (e.g., `https://modelcontextprotocol.io/specification/draft.md`).

Key areas: specification overview, transport mechanisms, tool/resource/prompt definitions.

#### 1.3 Recommended Stack

- **Language**: TypeScript — broad usage, static typing, strong SDK support, AI models generate it well
- **Transport**: Streamable HTTP (stateless JSON) for remote servers; stdio for local servers

**Load SDK docs:**
- TypeScript SDK: `https://raw.githubusercontent.com/modelcontextprotocol/typescript-sdk/main/README.md`
- Python SDK: `https://raw.githubusercontent.com/modelcontextprotocol/python-sdk/main/README.md`

#### 1.4 Plan Your Implementation

Review the service's API docs. List endpoints to implement, prioritising the most common operations.

---

### Phase 2: Implementation

#### 2.1 Core Infrastructure

Create shared utilities:
- API client with authentication
- Error handling helpers
- Response formatting (JSON/Markdown)
- Pagination support

#### 2.2 Implement Each Tool

**Input Schema:** Use Zod (TypeScript) or Pydantic (Python). Include constraints, clear descriptions, and examples.

**Output Schema:** Define `outputSchema` where possible. Use `structuredContent` in tool responses (TypeScript SDK).

**Tool Description:** Concise summary, parameter descriptions, return type.

**Implementation:** Async/await, proper error handling with actionable messages, pagination support.

**Annotations:**
- `readOnlyHint`: true/false
- `destructiveHint`: true/false
- `idempotentHint`: true/false
- `openWorldHint`: true/false

---

### Phase 3: Review and Test

- No duplicated code (DRY)
- Consistent error handling
- Full type coverage
- Clear tool descriptions

**TypeScript:** `npm run build` → test with `npx @modelcontextprotocol/inspector`
**Python:** `python -m py_compile your_server.py` → test with MCP Inspector

---

### Phase 4: Create Evaluations

Create 10 evaluation questions to test LLM effectiveness using the server.

Each question must be:
- **Independent** — not dependent on other questions
- **Read-only** — only non-destructive operations
- **Complex** — requiring multiple tool calls and exploration
- **Realistic** — based on real use cases
- **Verifiable** — single, clear answer verifiable by string comparison
- **Stable** — answer won't change over time

Output format:
```xml
<evaluation>
  <qa_pair>
    <question>...</question>
    <answer>...</answer>
  </qa_pair>
</evaluation>
```
