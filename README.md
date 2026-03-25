# Auditor

A Claude Code plugin that audits any codebase from 8 expert perspectives in parallel. One command deploys a virtual development team — Principal Architect, Security Engineer, Staff Engineer, SRE, QA Lead, DX Lead, plus 2 dynamic specialists — each independently exploring the actual code. Findings are merged into a single prioritized report with actionable fix directions.

No configuration. No external dependencies. No API keys.

**Version:** 1.0.0 | **License:** MIT

---

## Table of Contents

- [Why Auditor?](#why-auditor)
- [Installation](#installation)
- [How to Use It](#how-to-use-it)
- [What You Get](#what-you-get)
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

- **Goal-directed auditing** — optional goal parameter focuses the audit. "security" gets a Penetration Tester and Cryptography Reviewer. "agentic" gets an Agentic Systems Architect and Tool Integration Engineer. No goal runs a general health check.

- **Unified report** — findings are merged across all reviewers, deduplicated, and sorted by severity. Critical issues first, then standard. Each finding includes a fix direction specific enough for another Claude session to act on.

- **Weighted scoring** — Architecture and Security count 1.5x in the overall score, because they're the hardest to fix later.

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

### Common mistakes

| Problem | Fix |
|---------|-----|
| Wrong clone location | Must be `~/.claude/plugins/marketplaces/auditor` |
| `/audit` doesn't appear | Add `"auditor@auditor": true` under `enabledPlugins` |
| Plugin not detected | Add `extraKnownMarketplaces` entry pointing to the plugin directory |
| Stale behavior after update | Restart Claude Code to reload SKILL.md |

---

## How to Use It

### When to run `/audit`

`/audit` works anywhere in Claude Code — no plan mode required.

```
/audit <repo> [goal]
```

- `<repo>` — path or project name (e.g., `~/Desktop/myproject`, `enterprise`, `klauscode`)
- `[goal]` — optional focus lens: `security`, `performance`, `agentic`, `production-ready`, etc.

### Examples

```
/audit enterprise production-ready
/audit ~/Desktop/taxclaw security
/audit klauscode
/audit library agentic
```

### What happens when you type `/audit`

1. **Discovery** — one agent maps the codebase (language, structure, dependencies, abstractions)
2. **Team assembly** — 6 core reviewers + 2 dynamic specialists chosen for your codebase and goal
3. **Parallel audit** — 8 agents launched simultaneously, each exploring the actual code independently
4. **Unified report** — findings merged, deduplicated, severity-sorted, with fix directions

---

## What You Get

Here's a sample of what `/audit` produces (abbreviated — real audits are longer):

```
## Audit Report — myproject
Goal: Production-Ready
Team: Principal Architect, Security Engineer, Staff Engineer, SRE, QA Lead, DX Lead, Platform Engineer, Database Specialist
Overall Score: 5.8/10

### What's Strong
- Clean module boundaries with well-defined public API surface
- Comprehensive error types with context propagation
- Good use of connection pooling for database access

### Findings

1. [CRITICAL]

   Problem: SQL queries constructed via string interpolation in 3 endpoints

   Files: src/api/users.rs, src/api/search.rs, src/api/admin.rs

   Fix: Replace format!() query construction with parameterized queries using the existing QueryBuilder::bind() pattern from src/db/mod.rs

2. [CRITICAL]

   Problem: No rate limiting on any public endpoint

   Files: src/api/mod.rs, src/middleware/

   Fix: Add tower::RateLimit middleware in the router setup at api/mod.rs, start with 60 req/min on auth endpoints

3. [CRITICAL]

   Problem: Secrets loaded from environment with no validation at startup

   Files: src/config.rs, src/main.rs

   Fix: Add a Config::validate() call in main() before server start — check all required env vars exist, fail with a clear error listing what's missing

4. [STANDARD]

   Problem: 40% of error paths return generic 500 with no context

   Files: src/api/error.rs, src/api/users.rs, src/api/search.rs

   Fix: Implement From<DomainError> for ApiError in error.rs, map each variant to appropriate HTTP status codes

5. [STANDARD]

   Problem: No integration tests — only unit tests mocking the database

   Files: tests/, src/db/mod.rs

   Fix: Add tests/integration/ with a real SQLite test database, focus on user CRUD and search endpoints first

[... all findings numbered sequentially]

### Goal: Production-Ready
Progress: 4/10
- Exists: solid domain model, clean API design, basic auth
- Missing: rate limiting, input validation, integration tests, observability, graceful shutdown
- Top 3: (1) fix SQL injection, (2) add rate limiting + input validation, (3) integration test critical paths
```

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

### Severity System

| Marker | Meaning |
|--------|---------|
| `[CRITICAL]` | Must fix — significant risk or broken functionality |
| `[STANDARD]` | Real issue — fix at your discretion |

Critical findings are listed first in the report.

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

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `/audit` says "repo not found" | Bad path | Use full path or project name that resolves via `~/Desktop/<name>/` |
| `/audit` not appearing as a command | Plugin not enabled | Check `enabledPlugins` in `~/.claude/settings.json` |
| Plugin not detected at all | Missing marketplace entry | Check `extraKnownMarketplaces` in `~/.claude/settings.json` |
| Stale behavior after update | Skills cached at session start | Restart Claude Code |
| Audit feels shallow | Codebase too large for context | Focus with a goal parameter |

---

## Contributing

1. Fork the repository
2. Edit `plugin/skills/audit/SKILL.md` — that's the whole plugin
3. Submit a pull request

The plugin is intentionally a single file. Keep it that way.

---

## License

MIT — see [LICENSE](LICENSE).
