# Auditor

A Claude Code plugin that audits any codebase from 8 expert perspectives in parallel. One command deploys a virtual development team — Principal Architect, Security Engineer, Staff Engineer, SRE, QA Lead, DX Lead, plus 2 dynamic specialists — each independently exploring the actual code. Findings are saved to a detailed report file; the chat gets a concise summary. Then say `fix #3` and Claude implements the fix.

No configuration. No external dependencies. No API keys.

**Version:** 2.1.0 | **License:** MIT

---

## Table of Contents

- [Why Auditor?](#why-auditor)
- [Installation](#installation)
- [How to Use It](#how-to-use-it)
- [What You Get](#what-you-get)
- [Features](#features)
- [Under the Hood](#under-the-hood)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Why Auditor?

Asking Claude to "review this codebase" produces surface-level observations. It scans a few files, notes some patterns, and gives generic advice — "consider adding tests", "error handling could be improved."

Auditor fixes this by forcing Claude into 8 distinct expert roles, each with a specific mandate and blind spots the others cover. Every reviewer independently explores the actual code — reading files, grepping for patterns, tracing data flows — then produces findings that reference specific files and patterns.

**What makes it work:**

- **8 parallel perspectives** — architecture, security, code quality, operations, testing, developer experience, plus 2 specialists chosen for your codebase and goal. No single reviewer can see everything; 8 reviewers with different lenses catch what each other misses.

- **Real code exploration** — each subagent has full read access to your codebase. Findings reference actual files and patterns, not hypothetical concerns.

- **Report to file, summary to chat** — the full report with all findings, files, and fix directions is saved to `.audit/audit-report.md`. The chat shows only a concise summary with top findings. No context wasted.

- **Fix by number** — after an audit, say `fix #3` and Claude reads the finding from the report file and implements the fix. No copy-pasting, no re-explaining.

- **Baseline tracking** — re-run the audit and get a delta: score change, resolved findings, new findings. Track progress over time.

- **Category tags** — every finding is tagged with one or more categories (security, correctness, performance, quality, operational, testing, documentation, architecture). Filter and sweep with `fix all security`, `fix all testing`, or combine with severity: `fix all critical security`.

- **Diff-aware mode** — `--diff main` audits only changed files. Fast, focused, great as a pre-merge check.

---

## Installation

### One-line install

```bash
git clone https://github.com/charleschenai/auditor.git \
  ~/.claude/plugins/marketplaces/auditor \
  && bash ~/.claude/plugins/marketplaces/auditor/install.sh
```

The installer clones the repo, verifies the file structure, and adds the required entries to `~/.claude/settings.json`. If settings.json already exists, it merges non-destructively (requires python3).

### Manual install

1. **Clone into Claude Code's plugin directory:**

```bash
git clone https://github.com/charleschenai/auditor.git \
  ~/.claude/plugins/marketplaces/auditor
```

2. **Add to `~/.claude/settings.json`:**

```json
{
  "enabledPlugins": {
    "auditor@auditor": true
  },
  "extraKnownMarketplaces": {
    "auditor": {
      "source": {
        "source": "directory",
        "path": "/home/YOUR_USER/.claude/plugins/marketplaces/auditor"
      }
    }
  }
}
```

Replace `/home/YOUR_USER` with your actual home directory path.

3. **Restart Claude Code.** Skills are cached at session start.

### Updating

```bash
cd ~/.claude/plugins/marketplaces/auditor && git pull
```

Then restart Claude Code.

---

## How to Use It

### Basic audit

```
/audit enterprise production-ready
/audit ~/Desktop/taxclaw security
/audit klauscode
/audit library agentic
```

- `<repo>` — path or project name (resolved via `~/Desktop/<name>/`)
- `[goal]` — optional focus: `security`, `performance`, `agentic`, `production-ready`, etc.

### Diff-aware audit

```
/audit enterprise --diff main
/audit library security --diff main
```

Only audits files changed since diverging from the base branch. Much faster, much more focused.

### Fixing findings

After an audit, the report is saved to `.audit/audit-report.md`. Fix findings by number:

```
fix #3
fix #1 #4 #7
fix all critical
fix all small
fix all security
fix all critical security
```

Claude reads the finding from the report (Problem, Files, Fix direction, Effort, Tags), then implements the fix. Multiple findings that don't overlap on files are fixed in parallel. Tag filters and severity filters can be combined — `fix all critical security` sweeps every critical finding tagged `security`.

### Re-auditing

Run `/audit` again on the same repo and you get a delta:

```
Score: 7.1/10 (was 5.2/10)
Resolved: 4 findings
New: 2 findings
Persistent: 8 findings
```

Previous reports are archived as `.audit/audit-report-<date>.md`.

---

## What You Get

### In chat (summary)

```
## Audit — enterprise (Production-Ready)

Score: 5.8/10
Critical: 3 | Standard: 12
Report: .audit/audit-report.md

### Top Findings

1. [CRITICAL] [security] SQL injection via string interpolation in 3 endpoints — small
2. [CRITICAL] [security] No rate limiting on public endpoints — medium
3. [CRITICAL] [operational] Secrets loaded without startup validation — small
4. [STANDARD] [operational] 40% of error paths return generic 500 — medium
5. [STANDARD] [testing] No integration tests, only mocked unit tests — large

... and 10 more in the full report

By category: security (4) · operational (5) · testing (3) · architecture (2) · quality (1)

To fix a finding: "fix #3", "fix all critical", or "fix all security"
Full report: .audit/audit-report.md
```

### In file (full report at `.audit/audit-report.md`)

```markdown
# Audit Report — enterprise

**Date:** 2026-03-24
**Goal:** Production-Ready
**Mode:** Full
**Team:** Principal Architect, Security Engineer, Staff Engineer, SRE, QA Lead, DX Lead, Platform Engineer, Database Specialist
**Overall Score:** 5.8/10

## What's Strong

- Clean module boundaries with well-defined public API surface
- Comprehensive error types with context propagation
- Good use of connection pooling for database access

## Findings

### 1. [CRITICAL]

**Problem:** SQL queries constructed via string interpolation in 3 endpoints — format!() used directly with user input in query strings

**Files:** src/api/users.rs, src/api/search.rs, src/api/admin.rs

**Fix:** Replace format!() query construction with parameterized queries using the existing QueryBuilder::bind() pattern from src/db/mod.rs. The bind pattern is already used in 4 other query functions in the same module — follow that pattern.

**Effort:** small

**Tags:** security, correctness

---

### 2. [CRITICAL]

**Problem:** No rate limiting on any public endpoint — brute force auth attacks trivial

**Files:** src/api/mod.rs, src/middleware/

**Fix:** Add tower::RateLimit middleware in the router setup at api/mod.rs. Start with 60 req/min on /auth/* endpoints, 200 req/min globally. The middleware stack at line 47 of api/mod.rs is where other middleware is composed — add it there.

**Effort:** medium

**Tags:** security

---

### 3. [CRITICAL]

**Problem:** Secrets loaded from environment with no validation at startup — server starts with missing config and fails on first request

**Files:** src/config.rs, src/main.rs

**Fix:** Add Config::validate() that checks all required env vars (DATABASE_URL, JWT_SECRET, API_KEY) and returns a Result. Call it in main() before server start. Pattern: check existence, check non-empty, fail with a message listing all missing vars at once.

**Effort:** small

**Tags:** operational, security

---

[... all findings with full detail]

## Findings by Category

- **security:** #1, #2, #3, #7 (4)
- **operational:** #3, #4, #9 (3)
- **testing:** #5, #11, #14 (3)
- **architecture:** #6, #8 (2)
- **quality:** #12 (1)

## Goal: Production-Ready

**Progress:** 4/10

- Exists: solid domain model, clean API design, basic auth
- Missing: rate limiting, input validation, integration tests, observability, graceful shutdown
- Top 3: (1) fix SQL injection, (2) add rate limiting + input validation, (3) integration test critical paths
```

### On re-audit (delta section appended)

```markdown
## Delta (vs 2026-03-20)

**Score:** 5.8/10 → 7.1/10 (+1.3)
**Resolved:** 4 findings
**New:** 2 findings
**Persistent:** 9 findings

### Resolved
- [#1] [security] SQL injection via string interpolation — fixed with parameterized queries
- [#2] [security] No rate limiting — tower middleware added
- [#5] [operational] Missing startup config validation — Config::validate() added
- [#8] [quality] Unused imports in 12 files — cleaned up

### New
- [#3] [security] New endpoint /admin/bulk-delete has no authorization check
- [#11] [correctness] Migration 005 adds column without default, breaks rollback

### By Category
- **security:** -2 resolved, +1 new (net -1)
- **operational:** -1 resolved (net -1)
- **quality:** -1 resolved (net -1)
- **correctness:** +1 new (net +1)
```

---

## Features

### Report to File

The full detailed report is written to `.audit/audit-report.md` in the repo root. The chat gets a compact summary. This means:

- No context window wasted on findings you aren't actively fixing
- The report persists across sessions — any future Claude session can read it
- The report file is what `fix #N` reads from

The `.audit/` directory is added to `.gitignore` — audit reports are local artifacts.

### Fix by Number

Each finding in the report is numbered. After an audit:

- `fix #3` — Claude reads finding #3 from the report, understands the problem, files, and fix direction, then implements it
- `fix #1 #4 #7` — fixes multiple findings, parallelized when they don't touch the same files
- `fix all critical` — fixes every critical finding
- `fix all small` — fixes every finding marked as small effort (low-hanging fruit sweep)
- `fix all security` — fixes every finding tagged `security` (or any other category tag)
- `fix all critical security` — intersect: every critical finding that is also tagged `security`

No copy-pasting findings, no re-explaining what's wrong. The report file is the contract between the audit and the fix.

### Category Tags

Every finding is tagged with 1-3 categories drawn from a fixed vocabulary so filtering and sweeps stay consistent across audits:

| Tag | Covers |
|-----|--------|
| `security` | Auth, secrets, injection, attack surface, supply chain |
| `correctness` | Bugs, race conditions, wrong output, broken invariants |
| `performance` | Slow paths, unnecessary work, resource contention |
| `quality` | Naming, dead code, tech debt, consistency |
| `operational` | Error handling, observability, logging, graceful shutdown |
| `testing` | Coverage gaps, weak assertions, missing integration tests |
| `documentation` | Missing or misleading docs, DX, onboarding friction |
| `architecture` | Module boundaries, abstractions, system design |

The report includes a **Findings by Category** section listing counts per tag. The delta section groups resolved/new by category so you can see at a glance whether security debt is shrinking or growing.

### Baseline Tracking

Re-run `/audit` on the same repo and the new report includes a delta section:

- Score change (e.g., 5.8 → 7.1)
- Which findings were resolved
- Which findings are new
- Which findings persist

Previous reports are archived with their date. This turns the audit from a one-shot report into a progress tracker.

### Diff-Aware Mode

`/audit enterprise --diff main` only audits files changed since diverging from `main`:

- Reviewers focus on the diff but can examine unchanged files that interact with changes
- Much faster — no need to audit the entire codebase for a feature branch
- Great as a pre-merge quality gate

---

## Under the Hood

### The Review Team

Every audit gets 6 core reviewers plus 2 dynamic specialists:

**Core team (always present):**

| Role | Focus |
|------|-------|
| Principal Architect | System design, modularity, abstractions, boundaries |
| Security Engineer | Vulnerabilities, auth, secrets, attack surface, supply chain |
| Staff Engineer | Code quality, naming, dead code, tech debt, consistency |
| SRE | Error handling, failure modes, observability, logging, operational readiness |
| QA Lead | Test coverage, test quality, edge cases, CI, untested critical paths |
| DX Lead | API design, documentation, developer experience, onboarding |

**Dynamic specialists (2, chosen per audit):**

| Goal | Example Specialists |
|------|-------------------|
| agentic | Agentic Systems Architect, Tool Integration Engineer |
| production-ready | Platform Engineer, Compliance Reviewer |
| performance | Performance Engineer, Database Specialist |
| security | Penetration Tester, Cryptography Reviewer |
| no goal | Based on what the codebase most needs |

### Severity & Effort

| Marker | Meaning |
|--------|---------|
| `[CRITICAL]` | Must fix — significant risk or broken functionality |
| `[STANDARD]` | Real issue — fix at your discretion |

| Effort | Meaning |
|--------|---------|
| small | A focused fix, likely < 50 lines changed |
| medium | Requires understanding multiple components, 50-200 lines |
| large | Architectural change or significant new code, 200+ lines |

### Scoring

Each reviewer scores their dimension 0-10. The overall score is a weighted average:
- Architecture and Security: **1.5x weight** (hardest to fix later)
- All other dimensions: **1x weight**

---

## Architecture

The entire plugin is a single `SKILL.md` file — a prompt that tells Claude how to conduct the audit. No servers, no Python, no external dependencies.

```
auditor/
├── README.md
├── LICENSE
├── install.sh                         # Installer script
├── .claude-plugin/
│   └── marketplace.json               # Marketplace metadata
└── plugin/
    ├── .claude-plugin/
    │   └── plugin.json                # Plugin version
    └── skills/
        └── audit/
            └── SKILL.md               # The entire plugin
```

**Generated at runtime (in the audited repo):**

```
<audited-repo>/
└── .audit/
    ├── audit-report.md                # Latest full report
    └── audit-report-2026-03-20.md     # Archived previous report
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `/audit` says "repo not found" | Bad path | Use full path or project name that resolves via `~/Desktop/<name>/` |
| `/audit` not appearing as a command | Plugin not enabled | Check `enabledPlugins` in `~/.claude/settings.json` |
| Plugin not detected at all | Missing marketplace entry | Check `extraKnownMarketplaces` in `~/.claude/settings.json` |
| Stale behavior after update | Skills cached at session start | Restart Claude Code |
| `fix #N` says "no report found" | No prior audit | Run `/audit` first |
| Audit feels shallow | Codebase too large for context | Focus with a goal or use `--diff` |

---

## Contributing

1. Fork the repository
2. Edit `plugin/skills/audit/SKILL.md` — that's the whole plugin
3. Submit a pull request

The plugin is intentionally a single file. Keep it that way.

---

## License

MIT — see [LICENSE](LICENSE).
