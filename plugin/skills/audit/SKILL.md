---
description: Full software audit with a virtual development team. Spins up parallel subagents to audit a codebase from multiple expert perspectives, then produces a unified bullet-point report with findings and fixes.
argument-hint: <repo-path-or-name> [goal]
---

# Software Audit

Audit a codebase by deploying a virtual development team. Each team member is a subagent that independently explores the actual code, then findings are merged into one clean report.

## Usage

```
/audit library agentic
/audit enterprise production-ready
/audit ~/Desktop/taxclaw security
/audit klauscode
```

- `<repo>` — Path or project name (resolved via ~/Desktop/<name>/)
- `[goal]` — Optional lens: "agentic", "production-ready", "performance", "security", etc.

## Execution

### Step 1: Discovery

Launch **one Sonnet agent** to map the codebase.

**Tools:** Read, Glob, Grep, Bash

The agent must return a structured codebase profile covering: language, framework, project type, size, directory structure (3 levels), key files, core abstractions, public API surface, dependencies, test infrastructure, documentation state, and git health. Keep it factual and concise.

### Step 2: Assemble the Team

Pick **8 reviewers** based on the codebase profile and goal.

**Core team (always present):**

1. **Principal Architect** — system design, modularity, abstractions, boundaries
2. **Security Engineer** — vulnerabilities, auth, secrets, attack surface, supply chain
3. **Staff Engineer** — code quality, naming, dead code, tech debt, consistency, patterns
4. **SRE** — error handling, failure modes, observability, logging, operational readiness
5. **QA Lead** — test coverage, test quality, edge cases, CI, untested critical paths
6. **DX Lead** — API design, documentation, developer experience, onboarding

**Dynamic team (2 more, chosen based on codebase + goal):**

Select 2 specialists that cover what the core team doesn't. Examples:
- Goal "agentic" → Agentic Systems Architect, Tool Integration Engineer
- Goal "production-ready" → Platform Engineer, Compliance Reviewer
- Goal "performance" → Performance Engineer, Database Specialist
- Goal "security" → Penetration Tester, Cryptography Reviewer
- No goal → pick based on what the codebase most needs

Don't add roles that don't apply (no Frontend Lead for a CLI tool, etc.).

### Step 3: Parallel Audit

Launch **8 Sonnet agents in parallel** — one per reviewer.

**Each agent gets these tools:** Read, Glob, Grep, WebSearch, WebFetch

**Each agent receives:**
1. The codebase profile from Step 1
2. Their role and focus area
3. The audit goal (if any)
4. The repo path so they can explore the actual code

**Agent instructions (customize the role/focus per reviewer):**

> You are a [Role] auditing [repo name].
>
> Focus: [focus area]
> Goal: [goal or "general health"]
>
> Codebase Profile:
> [paste profile]
>
> Your job:
> 1. Explore the actual code — read files, grep for patterns, trace data flows. Don't just read the profile.
> 2. Use WebSearch to research best practices for this tech stack and your focus area.
> 3. Find real issues. Every finding must reference a specific file or pattern in the code.
> 4. For each finding, suggest a direction for fixing it — not a full implementation, just enough that another Claude session could pick it up and run with it.
> 5. If there's a goal, evaluate how the codebase measures up.
>
> Return your findings as a numbered list. Each finding MUST have three fields — Problem, Files, and Fix — each on its own line with a blank line between findings:
>
> 1. [severity: critical or standard]
>
>    Problem: [what's wrong — be specific about the pattern or behavior]
>
>    Files: [2-5 key file paths where this issue lives, comma-separated]
>
>    Fix: [concrete direction — name the function/module to change, the pattern to apply, or the approach to take. Enough that another Claude session can start coding without re-investigating]
>
> The Fix line is the most important. Don't say "add error handling" — say "wrap the spawn calls in web.rs:handle_upload() with a timeout and map the error to a 413 response." The more specific the fix direction, the more useful this audit is.
>
> Also return:
> - 2-3 bullet points on what's done well
> - A score out of 10 for your dimension
> - If goal specified: 1-2 sentences on how the codebase relates to the goal from your perspective

### Step 4: Report

After all agents return, merge everything into one unified report. Do NOT break it down by reviewer.

**Output format:**

```
## Audit Report — <repo name>
Goal: <goal or "General Health">
Team: <list the 8 roles on one line>
Overall Score: X/10

### What's Strong
- [merged positive findings from all reviewers, deduplicated]

### Findings

1. [CRITICAL]

   Problem: [what's wrong]

   Files: [key files where this issue lives]

   Fix: [specific direction — name the function, pattern, or approach]

2. [CRITICAL]

   Problem: [what's wrong]

   Files: [key files]

   Fix: [specific direction]

3. [STANDARD]

   Problem: [what's wrong]

   Files: [key files]

   Fix: [specific direction]

[... all findings numbered sequentially, critical first then standard, deduplicated across reviewers]

### Goal: <goal> (if specified)
Progress: X/10
- [what exists toward the goal]
- [what's missing]
- [top 3 actions to get there]
```

## Rules

- Do not enter plan mode.
- Deduplicate across reviewers — if two reviewers flag the same thing, list it once.
- Critical findings first, then standard.
- Every finding MUST include a Files line listing 2-5 relevant file paths.
- Fix directions must be specific enough that another Claude session can start coding without re-investigating. Name the function, module, or pattern to change.
- Overall score = average of all reviewer scores, weighted: Architecture and Security count 1.5x.
- Keep the whole report scannable. No walls of text.
- If the repo path doesn't resolve, stop and ask.
