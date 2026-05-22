---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

The process:
- Decide what the skill should do and roughly how
- Write a draft
- Create test prompts and run claude-with-access-to-the-skill on them
- Help the user evaluate results qualitatively and quantitatively
- Rewrite based on feedback
- Repeat until satisfied
- Expand the test set at larger scale

Figure out where the user is in this process and jump in. If they say "I want to make a skill for X" — help narrow it down, write a draft, write test cases, run them, iterate. If they already have a draft — go straight to eval/iterate. If they say "just vibe with me" — do that.

---

## Communicating with the User

Pay attention to technical literacy cues. Default to plain language:
- "evaluation" and "benchmark" — borderline OK
- "JSON" and "assertion" — explain unless the user clearly knows them

---

## Creating a Skill

### Capture Intent

Extract from the conversation first — tools used, steps taken, corrections made. Fill gaps with the user, then confirm before proceeding.

1. What should this skill enable Claude to do?
2. When should this skill trigger? (what phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases? Skills with objectively verifiable outputs benefit from them; subjective skills (writing style, art) often don't.

### Interview and Research

Ask about edge cases, input/output formats, example files, success criteria, and dependencies. Check available MCPs if useful for research. Don't write test prompts until this is sorted.

### Write the SKILL.md

Fill in:
- **name**: Skill identifier
- **description**: When to trigger + what it does. Include specific contexts. Make it slightly "pushy" — Claude tends to undertrigger. E.g., instead of "Build a dashboard", write "Build a dashboard. Use this whenever the user mentions dashboards, data visualization, or wants to display any kind of data, even if they don't explicitly say 'dashboard'."
- **the rest of the skill**

### Skill Anatomy

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code for repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Templates, icons, fonts
```

**Progressive Disclosure** — three loading levels:
1. Metadata (name + description) — always in context
2. SKILL.md body — in context when skill triggers (keep under 500 lines)
3. Bundled resources — loaded as needed

If approaching 500 lines, add hierarchy with clear pointers to where to look next.

**Domain organization** — for multi-domain skills:
```
cloud-deploy/
├── SKILL.md
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

### Writing Style

Use imperative form. Explain **why** things matter rather than heavy-handed MUSTs. Theory of mind beats rigid structure. After drafting, read with fresh eyes and improve.

**Output format pattern:**
```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern:**
```markdown
## Commit message format
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Test Cases

Come up with 2–3 realistic test prompts. Share with the user for sign-off. Save to `evals/evals.json` (no assertions yet):

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

---

## Running and Evaluating Test Cases

One continuous sequence — don't stop partway through.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory. Organize by `iteration-1/`, `iteration-2/`, etc., then `eval-0/`, `eval-1/` within each.

### Step 1: Spawn all runs in the same turn

For each test case, spawn two subagents simultaneously — one with the skill, one without (baseline). Don't run with-skill first and come back for baselines.

**With-skill run:**
```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what the user cares about>
```

**Baseline run:** Same prompt, no skill. Save to `without_skill/outputs/`.  
*(For improving an existing skill: snapshot the old version and point baseline at it.)*

Write `eval_metadata.json` for each test case:
```json
{
  "eval_id": 0,
  "eval_name": "descriptive-name-here",
  "prompt": "The user's task prompt",
  "assertions": []
}
```

### Step 2: Draft assertions while runs are in progress

Don't wait. Draft quantitative assertions and explain them to the user. Good assertions are objectively verifiable with descriptive names. Update `eval_metadata.json` and `evals/evals.json`.

### Step 3: Capture timing data

When each subagent completes, save the notification data immediately to `timing.json`:
```json
{
  "total_tokens": 84852,
  "duration_ms": 23332,
  "total_duration_seconds": 23.3
}
```

This data isn't persisted elsewhere — capture it as it arrives.

### Step 4: Grade, aggregate, and launch the viewer

1. **Grade** — spawn a grader subagent reading `agents/grader.md`. Save `grading.json` with fields `text`, `passed`, `evidence` (exact field names — viewer depends on them).

2. **Aggregate:**
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```

3. **Analyst pass** — read `agents/analyzer.md` ("Analyzing Benchmark Results") for patterns: non-discriminating assertions, high-variance evals, time/token tradeoffs.

4. **Launch viewer:**
   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```
   For iteration 2+, add `--previous-workspace <workspace>/iteration-<N-1>`.  
   In headless environments: use `--static <output_path>` for a standalone HTML file.

5. **Tell the user:** "I've opened the results in your browser. 'Outputs' tab lets you review test cases and leave feedback, 'Benchmark' shows the quantitative comparison. Come back when done."

### Step 5: Read the feedback

When the user is done, read `feedback.json`. Empty feedback = they thought it was fine. Focus improvements on entries with specific complaints.

Kill the viewer when done:
```bash
kill $VIEWER_PID 2>/dev/null
```

---

## Improving the Skill

### How to think about improvements

1. **Generalise from feedback.** You're creating something for a million future uses, not just these examples. Avoid overfitting with fiddly overspecific MUSTs — try different metaphors or working patterns instead.

2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Read transcripts, not just outputs — if the skill wastes time on unproductive steps, cut the instructions causing that.

3. **Explain the why.** Today's LLMs are smart. Explain the reasoning behind instructions rather than writing ALWAYS/NEVER in all caps. Understanding why is more powerful and humane than rigid rules.

4. **Look for repeated work.** If all 3 test runs independently wrote the same helper script, bundle it in `scripts/` and tell the skill to use it.

### The iteration loop

1. Apply improvements to the skill
2. Rerun all test cases into `iteration-<N+1>/` with baseline runs
3. Launch reviewer with `--previous-workspace` pointing at previous iteration
4. Wait for user review
5. Read feedback, improve, repeat

Stop when: user is happy, feedback is all empty, or no meaningful progress is being made.

---

## Description Optimization

After creating or improving a skill, offer to optimize the description for better triggering.

### Step 1: Generate 20 trigger eval queries

Mix of should-trigger (8–10) and should-not-trigger (8–10). Queries must be realistic and specific — not abstract.

Bad: `"Format this data"`, `"Create a chart"`  
Good: `"ok so my boss just sent me this xlsx file (Q4 sales final FINAL v2.xlsx) and she wants me to add a profit margin column"`

Should-not-trigger queries must be genuine near-misses — adjacent domains or ambiguous phrasing — not obviously irrelevant.

Save as JSON:
```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

### Step 2: Review with user

Read `assets/eval_review.html`, replace placeholders, write to `/tmp/eval_review_<skill-name>.html`, open it. User edits queries, toggles should-trigger, clicks "Export Eval Set". Check Downloads for `eval_set.json`.

### Step 3: Run the optimization loop

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

The script runs in background, splits eval set 60/40 train/test, runs each query 3 times, proposes description improvements, and returns `best_description` selected by test score (not train score, to avoid overfitting).

### Step 4: Apply

Update SKILL.md frontmatter with `best_description`. Show before/after and report scores.

---

## Environment-Specific Notes

### Claude Code (this environment)
Full workflow available. Subagents work. Browser viewer works.

### Claude.ai
No subagents — run test cases sequentially, using the skill yourself. Skip baseline runs. Skip browser viewer — present results inline in conversation. Skip description optimization (`run_loop.py` requires `claude -p` CLI). Packaging works.

### Cowork
Subagents available. No browser — use `--static <output_path>` for the viewer. Feedback downloads as `feedback.json`. **GENERATE THE EVAL VIEWER BEFORE evaluating inputs yourself.** Get it in front of the human first.

### Updating an existing skill
- Preserve the original directory name and `name` frontmatter field exactly
- Copy to a writable location before editing (installed paths may be read-only)
- Copy to `/tmp/skill-name/`, edit there, package from the copy

---

## Reference Files

- `agents/grader.md` — How to evaluate assertions against outputs
- `agents/comparator.md` — Blind A/B comparison between two outputs
- `agents/analyzer.md` — Why one version beat another
- `references/schemas.md` — JSON structures for evals.json, grading.json, etc.

---

## Core Loop (summary)

1. Understand what the skill is about
2. Draft or edit the skill
3. Run test prompts with the skill
4. Evaluate outputs with the user (viewer + quantitative evals)
5. Repeat until satisfied
6. Package and return to user
