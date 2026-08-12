<div align="center">

# docs-agent-config

**A complete, runnable AI agent configuration layer for a documentation-site repository.**

Rules, hooks, two scoped subagents, slash commands, a 13-step CI quality gate, a changelog
pipeline, and a pipeline that strips the entire layer out of production branches.

Not advice about writing rules. The rules themselves, in the form that executes.

[Setup](SETUP.md) · [Rationale](docs/RATIONALE.md) · [Frontend](https://github.com/adhibuchori/fe-agent-config) · [Backend](https://github.com/adhibuchori/be-agent-config)

</div>

---

## Table of contents

- [The problem this solves](#the-problem-this-solves)
- [Why a docs site needs less](#why-a-docs-site-needs-less)
- [What ships](#what-ships)
- [Repository structure](#repository-structure)
- [Quick start](#quick-start)
- [What is deliberately excluded](#what-is-deliberately-excluded)
- [Requirements](#requirements)
- [Adapting it to your stack](#adapting-it-to-your-stack)
- [The failure mode unique to docs sites](#the-failure-mode-unique-to-docs-sites)
- [Design decisions worth knowing before you edit](#design-decisions-worth-knowing-before-you-edit)
- [FAQ](#faq)
- [License](#license)

---

## The problem this solves

Most AI agent configuration is prose. You write `AGENTS.md`, list your conventions, and hope the
agent reads it. Some days it does.

Prose has no failure mode. When a rule is ignored, nothing reports it — the change just lands. So
the rule quietly becomes a suggestion, and the document becomes something people stop maintaining
because it stopped mattering.

A docs site has a second version of the same problem, and it is the one that bites: **most of the
content is generated.** An agent that hand-edits a generated page produces work that looks correct,
passes review, and vanishes on the next regeneration. Nothing reports that either.

This layer attaches every convention to something that exits non-zero, and marks generated output
as off-limits at the point where an agent would edit it.

---

## Why a docs site needs less

Three structural facts, each of which removes something. **The absences are the design.**

**No product to describe, so no `SSOT.md`.** That file states what a codebase *is* — layers, API
contract, data flow. A docs site renders content owned by another repository. There is no
architecture to contract about.

**No domain logic, so no `AGENTS.md`.** Separation-of-concerns rules, data-fetching rules, and
state-management rules have nothing to bind to. A single 117-line `CLAUDE.md` carries the entire
rule layer.

**No application state, so half the guards would be inert.** Nothing to memoise, no generated API
client, no translation catalogue. Those hooks are absent rather than present-and-passing — a hook
that always passes trains everyone to ignore hook output.

What it gains instead is a **content pipeline**, and the class of failure that comes with rendering
arbitrary source text as MDX.

| | Frontend | Docs site |
| :-- | :-- | :-- |
| `AGENTS.md` | 335 lines | **absent by design** |
| `SSOT.md` | 309 lines | **absent by design** |
| `CLAUDE.md` | 283 lines | **117 lines — the whole rule layer** |
| Rule tiers | 4 — common, typescript, react, web | **2 — common, web** |
| Subagents | 4 | **2** |
| Hooks | 9 | **5, plus lib.sh** |
| Gate steps | 14 | **13, one of them unique** |
| Deploy | Docker → registry → webhook | **Cloudflare Workers via Wrangler** |
| Extra workflow | — | **`changelog.yaml`** |

This shape was not designed in the abstract. It is what five separate documentation repositories
converged on independently, with no deviation between them.

---

## What ships

### Rules — 13 files across 2 tiers

```
.claude/rules/
├── common/    8 files   language-agnostic — transfers as is
└── web/       5 files   coding style, design quality, performance, security, hooks
```

No `typescript/` or `react/` tier. A docs site has a handful of custom components at most; rules
written for an application codebase would be dead text.

### Subagents — 2

| Agent | Scope |
| :-- | :-- |
| `sc-security-guard` | Content-Security-Policy integrity, secret hygiene, XSS prevention |
| `sc-seo-validator` | Metadata completeness, structured data, Open Graph |

Both matter more here than in an application, because a docs site is public by definition and is
usually the most-indexed thing a team publishes. The reviewer and translation-parity agents are
absent — there is no domain to review and no locale catalogue to compare.

### Hooks — 5, plus a shared library

`auto-format` · `auto-lint` · `notify` · `safety-check` · `stop-check`

The `PreToolUse` / `PostToolUse` distinction still governs everything: a non-zero exit in
`PreToolUse` **stops the tool call**, while `PostToolUse` and `Stop` are advisory. Anything that
must not happen belongs in `PreToolUse`.

### Quality gate — 13 steps, one of which exists nowhere else

**`Check Generated Doc TODOs`** greps changed generated pages for placeholder markers and warns
before they reach a published page. It is a warning rather than a failure, deliberately — a
half-filled page is often a legitimate intermediate state, and a hard failure would teach people to
skip the step.

The rest: install · format · lint · type check · comment style · comment block length · workflow
mirror drift · security audit · `.env` not committed · secret scan · AI config rule drift ·
production build · source-map leak.

> `AI Config Rule Drift Check` self-guards with `if [ ! -f AGENTS.md ] … skipping`, so it is inert
> here rather than broken. Left in place so the gate stays identical across all three repository
> types — a gate that diverges per repo is a gate nobody can reason about.

Dropped relative to the frontend gate: tests with coverage, and documentation-block presence. This
repository *consumes* documentation blocks; it does not author them.

### Changelog pipeline

`.github/workflows/changelog.yaml` reads the application repository's commits and tags on release
and opens a content revision. Two traps in it are already fixed in the shipped copy — see
[Design decisions](#design-decisions-worth-knowing-before-you-edit).

### Anti-patterns — 3 documented failures

A pinned Nextra/Zod version interaction, Node 25 WebStorage under server rendering, and
`bun build` versus `bun run build`. Real incidents, each with the trigger keyword that should
surface it before it recurs.

---

## Repository structure

```
docs-agent-config/
├── CLAUDE.md                    117 lines — the entire rule layer
├── README.md · SETUP.md · LICENSE
├── .mcp.json                    MCP servers, neutral env-var names
├── oxlint.json · .oxlintignore
│
├── .claude/
│   ├── settings.json            Hook wiring, permission allow/deny lists
│   ├── rules/
│   │   ├── common/              8 files
│   │   └── web/                 5 files
│   ├── agents/                  sc-security-guard · sc-seo-validator + INDEX.md
│   ├── anti-patterns/           3 documented failures + INDEX.md
│   ├── hooks/                   5 scripts + lib.sh
│   ├── commands/                12 slash commands (generated)
│   └── *.example.md             3 optional shared docs — most sites delete all three
│
├── .agent/workflows/            Command mirror for a second tool (generated)
├── _workflow-source/            12 command sources + INDEX.md — edit here
│
├── scripts/
│   ├── sync-workflows.sh        Mirror commands, with --check drift mode
│   ├── env.ts                   Environment-variable validation
│   ├── audit-check.ts           Dependency audit wrapper
│   └── run-next.mjs             Build wrapper
│
├── .github/
│   ├── workflows/               quality-gate · ci-cd (Cloudflare Workers) · changelog
│   │                            strip-ai-on-pr · deepseek-review · react-doctor
│   ├── scripts/                 quality-gate.sh · strip-paths.sh · strip-ai.sh
│   │                            verify-strip.sh · back-merge-prod.sh
│   │                            check-comment-blocks.sh · check-comment-style.ts
│   ├── PULL_REQUEST_TEMPLATE/ · CODEOWNERS · dependabot.yml
│
└── docs/RATIONALE.md            Why the odd-looking parts are shaped that way
```

**97 files. No `AGENTS.md`, no `SSOT.md`, no application source code.**

---

## Quick start

```bash
git clone https://github.com/adhibuchori/docs-agent-config.git
cd your-docs-project

CFG=../docs-agent-config
cp -R "$CFG"/{.claude,.agent,_workflow-source,.github,scripts} .
cp "$CFG"/{CLAUDE.md,.mcp.json,oxlint.json,.oxlintignore} .

# Placeholders are named, never blank — this is your complete to-do list
grep -rn '<[a-zA-Z][a-zA-Z -]*>' CLAUDE.md .mcp.json .claude/ .github/

chmod +x .claude/hooks/*.sh
```

Then follow **[SETUP.md](SETUP.md)** — about forty minutes, less than the other two repositories
because there is less to fill in. The step that can delete files comes last on purpose.

---

## What is deliberately excluded

**No content pipeline code.** `scripts/generate-docs/` and `scripts/generate-changelog/` are
application code — extractors, renderers, a preservation writer. `SETUP.md` §5 describes the shape
they should take and the two escaping traps waiting in them, but the implementation is yours.

**No site source.** No `content/`, no `app/`, no `components/`, no `next.config.mjs`, no
`package.json`, no lockfile. This is configuration, not a starter template.

**No `AGENTS.md`, no `SSOT.md`.** See [Why a docs site needs less](#why-a-docs-site-needs-less).

**No secrets, and none required.** Every credential is an environment-variable reference.

---

## Requirements

Nothing is mandatory. Every piece degrades to "delete this file" rather than breaking the rest.

| For | You need |
| :-- | :-- |
| Hooks, commands, subagents | An agent runtime that reads `.claude/` |
| The quality gate | GitHub Actions, plus the package scripts named in `SETUP.md` §4 |
| `ci-cd.yaml` as shipped | A Cloudflare Workers account and `wrangler.jsonc`. Replace the workflow outright if you deploy elsewhere |
| `changelog.yaml` | A separate application repository and a token that can read it |
| Shared docs | Most docs sites need none of the three `.example.md` files. Delete them |

---

## Adapting it to your stack

The rules are written against a concrete stack — Nextra on Next.js — deliberately. A rule
genericised into `{{DOCS_FRAMEWORK}}` is unusable until filled in, and most people never fill it in.

- `.claude/rules/common/` transfers unchanged to any language or framework.
- `.claude/rules/web/` is broadly applicable to any static site.
- `CLAUDE.md` § Orientation names Nextra-specific files; rewrite that list for Docusaurus, VitePress,
  Astro Starlight, or whatever you use. **Everything else in the file is framework-neutral.**
- Replace `ci-cd.yaml` wholesale if you do not deploy to Cloudflare Workers. Editing around it is
  more work than replacing it.

The `sc-` prefix on subagents is only a namespace, so project agents sort together and never collide
with built-ins. Rename it to your own initials.

---

## The failure mode unique to docs sites

If you generate pages from source comments, two classes of **perfectly correct source text** will
break the MDX build. Both are worth knowing before you write the generator, because both are much
cheaper to prevent than to debug.

**Multi-line destructured parameters inside a table cell.** The newline ends the inline-code span,
leaving an unbalanced `{` that the parser reads as a JSX expression. Collapse whitespace and escape
the delimiters before the value reaches a cell.

**Element names in prose.** A comment describing `<Foo>` parses as an unclosed JSX tag. Escape `<`
before tag-shaped text.

Solve both at **render time, not write time.** A brace-balance heuristic is the obvious detector
and gives false positives on multi-line balanced expressions — and a detector that cries wolf gets
disabled, which is worse than not having one.

---

## Design decisions worth knowing before you edit

Full detail in **[docs/RATIONALE.md](docs/RATIONALE.md)**. The four that catch people most often:

**The changelog workflow shares a concurrency group with the strip pipeline, on purpose.** Both push
to the production branch and would otherwise race. It must never use `cancel-in-progress` — a
dropped run loses a content revision permanently.

**Never put a skip-CI marker on the development-side commit.** The production-side commit needs it
to stop the workflow retriggering itself. Copied to the other side it prevents nothing — the
workflow does not trigger on that branch anyway — and silently disarms the quality gate on **every**
promotion opened from that commit. It reports as "no checks", which reads as a slow queue rather
than a failure, so it survives indefinitely.

**`--check` mode exists because write mode cannot replace it.** A write-mode sync run overwrites
staleness before it can observe it. Wire `--check` into CI; wire the write mode into nothing.

**Comma-separated globs stay in one string.** A YAML list looks tidier and stops the rule matching
any file — with no error, no warning, and nothing in the logs.

---

## FAQ

**Will cloning this run any GitHub Actions?**
No. Every workflow triggers on `dev` or `prod`, and this repo has only `main`. Nothing runs on push
and no secrets are needed. They activate when you create those branches in your own repo — the
right order, since a gate has nothing to guard until then.

**Why is there no `AGENTS.md`? Did you forget it?**
No — its absence is the defining trait of this variant, and `CLAUDE.md` says so at the top. See
[Why a docs site needs less](#why-a-docs-site-needs-less). Add one when your content pipeline grows
conventions of its own, and not before.

**Should I use this or `fe-agent-config`?**
This one, if the repository's job is rendering documentation. `fe-agent-config` if it is an
application that happens to have docs pages. The test: does the repo own domain logic? If yes, you
need `AGENTS.md`, which means you want the frontend layer.

**I do not deploy to Cloudflare Workers.**
Replace `.github/workflows/ci-cd.yaml` entirely. Nothing else in the layer depends on the deploy
target.

**Is this specific to one agent runtime?**
The rules, gate, and scripts are portable. The hook wiring in `.claude/settings.json` and the
`.mcp.json` format target Claude Code. The `.agent/` mirror exists for a second tool that reads
from that path — delete it if you use only one tool.

---

## License

MIT License. See [LICENSE](LICENSE).
