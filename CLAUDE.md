# CLAUDE.md — `<Project Name>` Docs

Static Nextra documentation site (Next.js, App Router, MDX). No backend, no database, no auth, no
test suite. Content lives under `content/` (`.mdx` pages plus `_meta.js` nav files), a thin `app/`
shell renders it through Nextra's catch-all route, and `components/` holds the handful of custom
`.tsx` files the theme cannot express. `scripts/generate-docs/` and `scripts/generate-changelog/`
generate MDX from source comments and git history — **never hand-edit their output.**

> **There is deliberately no `AGENTS.md` and no `SSOT.md` here.**
>
> `SSOT.md` exists to state what a codebase *is* — layers, API contract, data flow. A docs site
> renders content owned by another repository; there is no architecture to contract about.
> `AGENTS.md` exists to guard domain logic, and there is none.
>
> So this single file carries the whole rule layer. That is the shape of a docs repo, not an
> omission. If your content pipeline later grows conventions of its own — extractor rules, an
> escaping policy with enough cases to need numbering — that is the signal to add `AGENTS.md`, and
> not before.

## Orientation

Before making non-trivial changes, skim:

- `content/_meta.js` and each section's `_meta.js` — the actual navigation structure
- `app/layout.tsx` — theme, navbar, footer, metadata
- `next.config.mjs` — Nextra wrapper configuration
- `.claude/anti-patterns/` — known gotchas. Check this **before** touching `nextra` /
  `nextra-theme-docs` versions or the dev/build scripts, not after the build breaks

## Command Wrapper

If you route terminal commands through a wrapper — a token-reducing proxy, a sandbox, a recorder —
declare it here as a hard rule and prefix every command in this file with it. A wrapper mentioned
only in passing gets dropped the moment a task gets busy. If you have no wrapper, the commands
below are already correct.

## Quality Gates

Run before every commit — these are the same gates CI (`quality-gate.yaml`) enforces on PRs into `prod`:

```bash
bun fl            # oxfmt --write + oxlint
bun type-check     # tsc --noEmit
bun run build      # next build + pagefind index (NOT `bun build` — see anti-patterns)
```

There is no test script in this repo (`package.json` defines no `test`) — do not invent `bun test` commands. `bun run docs:generate` / `bun run changelog:generate` regenerate content from source; re-run them if the underlying source or git history changed, then re-review the generated MDX.

## Commit Format

```
type(scope): subject — max 50 characters

[optional body, wrapped at ~72 chars]
```

Types: `feat` · `fix` · `refactor` · `chore` · `docs` · `style` · `perf` — these label commit messages, not branch names; branch prefixes are `internal/…` (see § Branching). Scope is the affected area (e.g. `product`, `technical`, `nav`, `mermaid`, `scripts`). Stage files explicitly by name — never `git add -A` / `git add .`.

## Branching

Three branch levels, each a promotion stage:

| Branch             | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| `internal/{scope}` | Experiments, proof of concept, early work on a scope |
| `dev`              | Active development — all scopes merge here first     |
| `prod`             | Stable, deployed code                                |

Naming: `internal/{scope}` for a single task; `internal/{scope}/{context}` when parallel
tasks share a scope — e.g. `internal/auth`, `internal/auth/login`, `internal/auth/register`.
Work directly on `internal/{scope}` unless the scope splits into parallel tasks, in which
case `internal/{scope}` becomes the integration point for the `internal/{scope}/{context}`
branches and is not committed to directly.

Merge order: `internal/{scope}/{context}` → `internal/{scope}` → `dev` → `prod`. Never push
directly to `dev` or `prod`; nothing enforces this in CI yet, so it is a convention to keep.

## Protected Files

Never write to or commit:

- `.env*` (except `.env.<target>.example`, which documents the schema and has no real values)
- `.claude/settings.json`

## Workflow Commands

Slash commands live in `.claude/commands/`, synced from `_workflow-source/` by
`scripts/sync-workflows.sh` — **edit the source, never the synced copy.** See
`.claude/commands/INDEX.md` for the full list.

Use `sync-workflows.sh --check` in CI rather than the write mode. A write-mode run overwrites
staleness before it can observe it, so it reports success no matter what.

Project-specific rules live in `.claude/rules/common/` and `.claude/rules/web/`. Known environment/tooling gotchas live in `.claude/anti-patterns/` — check `INDEX.md` there before debugging a build/dev issue that feels like it shouldn't be happening.

---

## Optional Shared Docs

Three templates ship in `.claude/` as `*.example.md`. Each covers a capability this config can use
but does not require. **Fill one in, rename it to drop `.example`, then uncomment its import line
below.** Delete the ones you do not need — an unfilled template is worse than an absent one,
because an agent will try to use it.

| Template                      | Covers                                                       | Delete it if                       |
| ----------------------------- | ------------------------------------------------------------ | ---------------------------------- |
| `DATABASE.example.md`         | Database access over MCP — topology, tunnel, production rules | You give agents no database access |
| `OPENPANEL.example.md`        | Analytics read API — base URL, auth headers, worked example  | You have no analytics backend      |
| `SERENA-WORKSPACE.example.md` | Multi-repo symbol-search scoping                             | You work in a single repo          |

```
<!-- @.claude/DATABASE.md -->
<!-- @.claude/ANALYTICS.md -->
<!-- @.claude/SERENA-WORKSPACE.md -->
```

Most docs sites need none of the three. Deleting all three is a perfectly normal outcome.
