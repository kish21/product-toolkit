# product-toolkit

Personal Claude Code skills library — reusable slash commands for building production-grade products.

## What this is

A collection of `/skills` that work globally across every project. Run any of these in any Claude Code session by typing the command name.

## Setup (new machine)

```bash
git clone https://github.com/kish21/product-toolkit
cp product-toolkit/commands/*.md ~/.claude/commands/
```

That's it. All skills are immediately available in every project.

---

## Skills

### `/enterprise-ai-audit`
Audits any AI project for production readiness gaps across 8 categories (LLM abstraction, security, testing, deployment, observability, frontend, cost controls). Prints a score card and auto-fixes missing patterns. Also shows Claude-specific bonus features (prompt caching, extended thinking) in a separate section.

**Run when:** Starting a new AI project health check, or before shipping to first customer.

---

### `/new-component`
Creates a React component following the design system rules — CSS variables only, loading states, hover/focus/active states, accessibility labels.

**Run when:** Building any UI component.

---

### `/frontend-design`
Builds production-grade frontend interfaces avoiding generic AI aesthetics. Enforces typography rules, depth/shadow system, and anti-generic design guardrails.

**Run when:** Building any page, dashboard, or UI section from scratch.

---

### `/anti-ai-ui`
Audits finished UI against 12 "AI tell" checks — flat shadows, same font weights, generic blue colors, missing interactive states, etc. Flags and fixes anything that looks template-generated.

**Run when:** Before delivering any UI work.

---

### `/github-pr-flow`
Handles the full GitHub workflow — branch naming, PR creation, CI failure handling, merge conflict resolution, branch protection.

**Run when:** Pushing code to a protected main/master branch.

---

### `/mcp-builder`
Guides building MCP servers that connect Claude Code to external services (databases, APIs, tools). Covers both Python (FastMCP) and TypeScript (MCP SDK).

**Run when:** Building an MCP server to give Claude Code direct access to a tool or API.

---

### `/theme-factory`
Applies visual themes (colors, fonts, spacing) to any artifact — slides, HTML pages, reports, UI components.

**Run when:** Styling any visual output.

---

### `/web-artifacts-builder`
Builds complex multi-component HTML artifacts using React, Tailwind CSS, and shadcn/ui — with state management, routing, and component libraries.

**Run when:** Building a complex interactive artifact that needs multiple components.

---

### `/skill-creator`
Creates new skills, improves existing ones, runs evaluations to test quality, benchmarks performance, and optimizes trigger descriptions.

**Run when:** Building a new skill or improving an existing one.

---

## Adding a new skill

1. Create `commands/your-skill-name.md`
2. Copy to `~/.claude/commands/your-skill-name.md`
3. Commit and push

```bash
cp commands/your-skill-name.md ~/.claude/commands/
git add commands/your-skill-name.md
git commit -m "feat: add your-skill-name skill"
git push
```

---

## Sync after pulling updates

```bash
git pull
cp commands/*.md ~/.claude/commands/
```
