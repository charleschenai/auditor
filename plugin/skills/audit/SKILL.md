---
description: Full software audit with a virtual development team. Spins up parallel subagents to audit a codebase from multiple expert perspectives, then produces a unified report with actionable findings. Supports diff-aware mode, baseline tracking, and fix-by-number.
argument-hint: <repo-path-or-name> [goal] [--diff <base-branch>]
---

# Software Audit

Audit a codebase by deploying a virtual development team. Each team member is a subagent that independently explores the actual code, then findings are merged into one clean report saved to disk. The chat gets a summary; the full report lives in a file any Claude session can pick up.

## Usage

```
/audit library agentic
/audit enterprise production-ready
/audit ~/Desktop/taxclaw security
/audit klauscode
/audit enterprise --diff main
/audit library security --diff main
```

- `<repo>` — Path or project name (resolved via ~/Desktop/<name>/)
- `[goal]` — Optional lens: "agentic", "production-ready", "performance", "security", etc.
- `--diff <base>` — Only audit files changed since diverging from `<base>` branch. Much faster, great as a pre-merge gate.

## Execution

### Step 0: Resolve Arguments

1. **Resolve repo path.** If the argument is a name (not a path), try `~/Desktop/<name>/`. If it doesn't exist, stop and ask.
2. **Parse flags.** Check for `--diff <base>` in the arguments. If present, this is a diff-aware audit.
3. **Check for prior audits.** Look for `.audit/` directory in the repo root. If a previous `audit-report.md` exists, this is a re-audit — you will produce a delta in Step 5.

### Step 1: Discovery

Launch **one Sonnet agent** to map the codebase.

**Tools:** Read, Glob, Grep, Bash

**If `--diff` mode:**
The agent should run `git diff <base>...HEAD --name-only` to get the list of changed files, then focus the codebase profile on those files and their immediate dependencies. Still include the overall project structure for context, but mark which files are changed.

**If normal mode:**
The agent must return a structured codebase profile covering: language, framework, project type, size, directory structure (3 levels), key files, core abstractions, public API surface, dependencies, test infrastructure, documentation state, and git health. Keep it factual and concise.

**Codemap enrichment (if available):**
If `codemap` is on PATH (check with `which codemap`), the discovery agent must also run these AST-level analyses and include the results in the profile under a **"Codemap Signal"** section:

```bash
codemap --dir <repo> dead-functions           # unused exports
codemap --dir <repo> orphan-files             # disconnected files
codemap --dir <repo> complexity . | head -30  # complexity hotspots
codemap --dir <repo> hotspots                 # most-connected code
codemap --dir <repo> unreachable              # dead code paths
```

Include the top 10-20 items from each output in the profile — this is structural ground truth that every reviewer will use. The Staff Engineer, Principal Architect, and SRE reviewers should be told explicitly to cross-reference the Codemap Signal against their own exploration rather than greping from scratch. If `--diff` mode is active, also run `codemap --dir <repo> blast-radius <changed-files>` to scope the ripple of changes. If codemap isn't available, skip this section entirely and reviewers fall back to Glob/Grep heuristics.

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

**In `--diff` mode:** Tell reviewers to focus on changed files but they may also examine unchanged files that interact with the changes.

### Step 3: Parallel Audit

Launch **8 Sonnet agents in parallel** — one per reviewer.

**Each agent gets these tools:** Read, Glob, Grep, WebSearch, WebFetch

**Each agent receives:**
1. The codebase profile from Step 1
2. Their role and focus area
3. The audit goal (if any)
4. The repo path so they can explore the actual code
5. If `--diff` mode: the list of changed files and instruction to focus on them

**Agent instructions (customize the role/focus per reviewer):**

> You are a [Role] auditing [repo name].
>
> Focus: [focus area]
> Goal: [goal or "general health"]
> [If diff mode: "Scope: Focus on these changed files: [list]. You may also examine unchanged files that interact with the changes."]
>
> Codebase Profile:
> [paste profile]
>
> Your job:
> 1. Explore the actual code — read files, grep for patterns, trace data flows. Don't just read the profile.
> 2. Use WebSearch to research best practices for this tech stack and your focus area.
> 3. Find real issues. Every finding must reference a specific file or pattern in the code.
> 4. For each finding, suggest a direction for fixing it — specific enough that another Claude session can start coding without re-investigating.
> 5. If there's a goal, evaluate how the codebase measures up.
>
> Return your findings as a numbered list. Each finding MUST have five fields — Problem, Files, Fix, Effort, and Tags — each on its own line with a blank line between findings:
>
> 1. [severity: critical or standard]
>
>    Problem: [what's wrong — be specific about the pattern or behavior]
>
>    Files: [2-5 key file paths where this issue lives, comma-separated]
>
>    Fix: [concrete direction — name the function/module to change, the pattern to apply, or the approach to take. Enough that another Claude session can start coding without re-investigating]
>
>    Effort: [small / medium / large — rough estimate of fix complexity]
>
>    Tags: [1-3 category tags, comma-separated, drawn from this fixed vocabulary: security, correctness, performance, quality, operational, testing, documentation, architecture]
>
> The Fix line is the most important. Don't say "add error handling" — say "wrap the spawn calls in web.rs:handle_upload() with a timeout and map the error to a 413 response." The more specific the fix direction, the more useful this audit is.
>
> Tag guidance: security (auth, secrets, injection, supply chain), correctness (bugs, wrong output, race conditions), performance (slow paths, unnecessary work), quality (naming, dead code, tech debt), operational (error handling, observability, logging), testing (coverage, test quality), documentation (docs, DX, onboarding), architecture (design, boundaries, modularity). Pick the 1-3 that best fit — don't tag everything as "quality."
>
> Also return:
> - 2-3 bullet points on what's done well
> - A score out of 10 for your dimension
> - If goal specified: 1-2 sentences on how the codebase relates to the goal from your perspective

### Step 4: Write Report to File

After all agents return, merge everything into one unified report. Do NOT break it down by reviewer.

1. **Create `.audit/` directory** in the repo root if it doesn't exist.
2. **Write the full report** to `.audit/audit-report.md`.
3. **If a previous report exists**, rename it to `.audit/audit-report-<YYYY-MM-DD>.md` before writing the new one.

**Full report format (written to `.audit/audit-report.md`):**

```markdown
# Audit Report — <repo name>

**Date:** <YYYY-MM-DD>
**Goal:** <goal or "General Health">
**Mode:** <"Full" or "Diff vs <base>">
**Team:** <list the 8 roles on one line>
**Overall Score:** X/10

## What's Strong

- [merged positive findings from all reviewers, deduplicated]

## Findings

### 1. [CRITICAL]

**Problem:** [what's wrong]

**Files:** [key files where this issue lives]

**Fix:** [specific direction — name the function, pattern, or approach]

**Effort:** [small / medium / large]

**Tags:** [1-3 from: security, correctness, performance, quality, operational, testing, documentation, architecture]

---

### 2. [CRITICAL]

**Problem:** [what's wrong]

**Files:** [key files]

**Fix:** [specific direction]

**Effort:** [small / medium / large]

**Tags:** [category tags]

---

### 3. [STANDARD]

**Problem:** [what's wrong]

**Files:** [key files]

**Fix:** [specific direction]

**Effort:** [small / medium / large]

**Tags:** [category tags]

---

[... all findings numbered sequentially, critical first then standard, deduplicated across reviewers]

## Findings by Category

- **security:** #1, #4, #9 (3)
- **correctness:** #2, #7 (2)
- **testing:** #5, #12, #14 (3)
- **[other tags with counts and finding numbers, omit tags with zero findings]**

## Goal: <goal> (if specified)

**Progress:** X/10

- [what exists toward the goal]
- [what's missing]
- [top 3 actions to get there]
```

### Step 5: Baseline Delta (if re-audit)

If a previous audit report was found in Step 0, compare the two reports:

1. Read the previous report.
2. Identify:
   - **Resolved** — findings from the previous report that no longer appear
   - **New** — findings in the current report that weren't in the previous one
   - **Persistent** — findings that appear in both
   - **Score change** — previous score vs current score
3. Append a `## Delta` section to the end of `.audit/audit-report.md`:

```markdown
## Delta (vs <previous date>)

**Score:** X/10 → Y/10 (<+/-Z>)
**Resolved:** N findings
**New:** N findings
**Persistent:** N findings

### Resolved
- [#prev-N] [security] [brief description of what was fixed]

### New
- [#N] [testing] [brief description of new finding]

### By Category
- **security:** -2 resolved, +1 new (net -1)
- **testing:** +2 new (net +2)
- [only list categories with changes]
```

### Step 6: Chat Summary

After writing the report file, show a **concise summary** in chat. Do NOT dump the full report into chat.

**Chat output format:**

```
## Audit — <repo name> (<goal or "General Health">)

Score: X/10 [if re-audit: "(was Y/10)"]
Critical: N | Standard: N [if re-audit: "| Resolved: N | New: N"]
Report: .audit/audit-report.md

### Top Findings

1. [CRITICAL] [security] <one-line problem summary> — <effort>
2. [CRITICAL] [correctness] <one-line problem summary> — <effort>
3. [CRITICAL] [architecture] <one-line problem summary> — <effort>
4. [STANDARD] [testing] <one-line problem summary> — <effort>
5. [STANDARD] [operational] <one-line problem summary> — <effort>

[if more findings: "... and N more in the full report"]

By category: security (3) · correctness (2) · testing (4) · [other tags with counts]

[if re-audit, show delta summary:
"### Delta (vs <date>)"
"Resolved: [list resolved findings, one line each]"
"New: [list new findings, one line each]"]

To fix a finding: "fix #3", "fix all critical", or "fix all security"
Full report: .audit/audit-report.md
```

### Step 7: Fix Mode

After an audit, the user can request fixes by referencing finding numbers, severity, effort, or category tags:

- `fix #3` — fix finding #3
- `fix #1 #4 #7` — fix multiple specific findings
- `fix all critical` — fix all critical findings (both tags and standard combined)
- `fix all small` — fix all findings marked as small effort (both severities combined)
- `fix all security` — fix all findings tagged `security` (works for any tag from the vocabulary)
- `fix all critical security` — intersect filters: critical severity AND security tag

When the user requests a fix:

1. **Read `.audit/audit-report.md`** to get the finding details (Problem, Files, Fix, Effort, Tags).
2. **For each finding to fix**, launch a Sonnet agent with these tools: Read, Glob, Grep, Edit, Write, Bash.
3. **Agent prompt:**

> You are fixing audit finding #N in [repo name].
>
> **Problem:** [from report]
>
> **Files:** [from report]
>
> **Fix direction:** [from report]
>
> **Effort:** [from report]
>
> **Tags:** [from report]
>
> Your job:
> 1. Read the files listed above and understand the current code.
> 2. Implement the fix described in the fix direction.
> 3. Keep changes minimal — fix exactly this issue, don't refactor surrounding code.
> 4. If the fix requires changes to files not listed, that's fine — but stay focused on this finding.
> 5. Return a summary of what you changed.

4. **If fixing multiple findings**, launch fix agents in parallel where the findings don't overlap on the same files. If two findings touch the same files, fix them sequentially.
5. **After all fixes complete**, report what was fixed in chat.
6. **Do NOT automatically re-audit.** The user can run `/audit` again if they want to see the new score.

## Rules

- Do not enter plan mode.
- Deduplicate across reviewers — if two reviewers flag the same thing, list it once.
- Critical findings first, then standard.
- Every finding MUST include a Files line listing 2-5 relevant file paths.
- Every finding MUST include an Effort estimate (small / medium / large).
- Every finding MUST include 1-3 Tags from the fixed vocabulary: security, correctness, performance, quality, operational, testing, documentation, architecture. Don't invent new tags. Don't tag every finding as "quality" — pick the tags that best describe the domain of the issue.
- Fix directions must be specific enough that another Claude session can start coding without re-investigating. Name the function, module, or pattern to change.
- Overall score = average of all reviewer scores, weighted: Architecture and Security count 1.5x.
- The full report goes to `.audit/audit-report.md`. The chat gets a summary only.
- Keep the chat summary scannable — max 5 top findings shown, rest referenced by count.
- If the repo path doesn't resolve, stop and ask.
- Add `.audit/` to `.gitignore` if it isn't already there — audit reports are local artifacts, not committed code.
