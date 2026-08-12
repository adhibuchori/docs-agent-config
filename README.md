<div align="center">

# docs-agent-config

**A complete, runnable AI agent configuration layer for a documentation-site repository.**

Rules, hooks, two scoped subagents, slash commands, a 13-step CI quality gate, a changelog
pipeline, and a pipeline that strips the entire layer out of production branches.

Not advice about writing rules. The rules themselves, in the form that executes.

[Setup](SETUP.md) · [Rationale](docs/RATIONALE.md) · [Frontend](https://github.com/adhibuchori/fe-agent-config) · [Backend](https://github.com/adhibuchori/be-agent-config) · [AI/Python](https://github.com/adhibuchori/ai-agent-config)

</div>

---

## Table of contents

- [The problem this solves](#the-problem-this-solves)
- [Why a docs site needs less](#why-a-docs-site-needs-less)
- [What ships](#what-ships)
- [Repository structure](#repository-structure)
- [Quick start](#quick-start)
- [What is deliberately excluded](#what-is-deliberately-excluded)
- [GitHub repository configuration](#github-repository-configuration)
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
| `agents-security-guard` | Content-Security-Policy integrity, secret hygiene, XSS prevention |
| `agents-seo-validator` | Metadata completeness, structured data, Open Graph |

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
│   ├── agents/                  agents-security-guard · agents-seo-validator + INDEX.md
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
application code — extractors, renderers, a preservation writer. `SETUP.md` §6 describes the shape
they should take and the two escaping traps waiting in them, but the implementation is yours.

**No site source.** No `content/`, no `app/`, no `components/`, no `next.config.mjs`, no
`package.json`, no lockfile. This is configuration, not a starter template.

**No `AGENTS.md`, no `SSOT.md`.** See [Why a docs site needs less](#why-a-docs-site-needs-less).

**No secrets, and none required.** Every credential is an environment-variable reference.

---

## GitHub repository configuration

Everything the workflows need, in the order you should set it up. **Nothing here is required to
clone and read the layer** — this is for when you wire the gate into a real repository.

A docs site has one wrinkle the other two do not: **it talks to a second repository.** The changelog
pipeline reads the application repo's commits, which means a cross-repository token, and that token
is the one worth being careful with. Skip to [the checklist](#checklist) if you just want the list.

### What costs money, and what does not

**Everything required to make this layer work is free.** Only the enforcement layer on top of it is
tier-dependent, and it is tier-dependent in one specific way: **private repositories.**

| Feature | Public repo | Private repo on the free plan |
| :-- | :-- | :-- |
| Actions minutes | Free, unmetered | Monthly allowance, then billed |
| Workflows, secrets, variables | Free | Free |
| Container registry (`ghcr.io`) | Free | Storage allowance, then billed |
| Dependabot alerts + security updates | Free | **Free** |
| Secret scanning + push protection | Free | Paid add-on |
| Code scanning | Free | Paid add-on |
| `CODEOWNERS` auto-review-request | Free | Paid — Pro, Team, or Enterprise |
| **Branch protection / rulesets** | **Free** | **Paid — Pro, Team, or Enterprise** |

So the honest summary:

- **Public repository:** every step below is available to you at no cost.
- **Private repository, free plan:** everything through the container registry works. Branch
  protection does not — see [Nice to have — branch protection](#nice-to-have--branch-protection) below.

> Plans and limits change. Check GitHub's current pricing page before concluding a feature is out
> of reach — this table reflects the tiers at the time of writing, not a promise.

### Step 0 — Create the branches (this is what turns the workflows on)

```bash
git checkout -b dev  && git push -u origin dev
git checkout -b prod && git push -u origin prod
```

Until these exist, **no workflow can trigger** — every one of them is scoped to `dev` or `prod`.
That is why cloning this repo costs zero Actions minutes.

Then set `dev` as the default branch: **Settings → General → Default branch**.

### Step 1 — Repository secrets

**Settings → Secrets and variables → Actions → New repository secret**

| Secret | Required for | How to get it |
| :-- | :-- | :-- |
| `GITHUB_TOKEN` | everything | **Do not create this.** GitHub injects it automatically per run. It appears in the workflows but never in your settings |
| `CLOUDFLARE_API_TOKEN` | `ci-cd.yaml` deploy | See [Step 3](#step-3--cloudflare-deploy) |
| `CLOUDFLARE_ACCOUNT_ID` | `ci-cd.yaml` deploy | Cloudflare dashboard → **Workers & Pages** → right sidebar. Not secret, but the action expects it here |
| `APP_REPO_TOKEN` | `changelog.yaml` | See [Step 4](#step-4--cross-repository-token) |
| `DEEPSEEK_CODE_REVIEW_TOKEN` | `deepseek-review.yml` | See [Step 5](#step-5--ai-review-token-optional) |

Delete the workflow rather than inventing a value for a secret you do not need. A workflow failing
on a missing secret every single run trains people to ignore red marks.

### Step 2 — Repository variables (not secrets)

**Settings → Secrets and variables → Actions → Variables tab**

| Variable | Purpose |
| :-- | :-- |
| `CI_RUNNER` | Runner label. Every job reads `${{ vars.CI_RUNNER \|\| 'ubuntu-latest' }}`, so **leaving it unset is valid** and gives you GitHub's hosted runners. Set it only to point at a self-hosted or third-party runner |

Variables are visible in logs; secrets are masked. A runner label is not sensitive, which is why it
is a variable.

### Step 3 — Cloudflare deploy

`ci-cd.yaml` deploys the built static site to a Cloudflare Worker via
[`cloudflare/wrangler-action`](https://github.com/cloudflare/wrangler-action).

1. Cloudflare dashboard → **My Profile → API Tokens → Create Token**.
2. Use the **Edit Cloudflare Workers** template, or build a custom token with:
   - `Account · Workers Scripts · Edit`
   - `Account · Account Settings · Read`
3. Scope it to the **one account** that hosts this site, not "All accounts".
4. Add it as `CLOUDFLARE_API_TOKEN`, and the account ID as `CLOUDFLARE_ACCOUNT_ID`.

You also need a `wrangler.jsonc` in the repository root — it is not shipped here, since it names
your Worker and its routes.

> The shipped workflow pins `wranglerVersion: '3'` deliberately. Wrangler 4 requires Node 22+ and
> the runner ships Node 20; pinning was preferred over adding a `setup-node` step for a single CLI
> invocation. If you bump it, add the Node step in the same change.

**Deploying elsewhere?** Replace `ci-cd.yaml` outright rather than editing around it, and skip both
Cloudflare secrets. Nothing else in the layer depends on the deploy target.

### Step 4 — Cross-repository token

This is the one to get right. `changelog.yaml` reads the **application repository's** commits and
tags to build the changelog, and resolves its production SHA through the REST API.

1. Create a **fine-grained personal access token**: your avatar → **Settings → Developer settings →
   Personal access tokens → Fine-grained tokens**.
2. **Resource owner:** the org or account owning the application repo. **Repository access:** only
   that repo — not "All repositories".
3. **Permissions:** `Contents: Read-only`. Reading commits and tags needs nothing more.
4. Set an expiry you will actually notice. When it lapses, the changelog job fails with an
   authentication error rather than silently producing an empty changelog.
5. Add it as `APP_REPO_TOKEN`, then fill in `<github-org>/<app-repo>` inside `changelog.yaml`.

> **Read-only is enough, and matters.** A classic token scoped to `repo` can write to every
> repository you can reach. This job only reads history from one. If your application repo also
> dispatches *into* this one — the `repository_dispatch` in the frontend layer's `ci-cd.yaml` — that
> is a **separate** token living in the application repo, and it is the one that needs
> `Contents: Read and write`. Do not merge the two into one broadly-scoped token.

### Step 5 — AI review token (optional)

`deepseek-review.yml` posts an AI review comment on pull requests into `dev`.

1. Create an API key at your provider's console (the shipped workflow uses
   [`hustcer/deepseek-review`](https://github.com/hustcer/deepseek-review), which accepts any
   OpenAI-compatible endpoint).
2. Add it as `DEEPSEEK_CODE_REVIEW_TOKEN`.
3. Confirm **Settings → Actions → General → Workflow permissions** allows pull-request writes.

> **Read this before enabling it.** The workflow uses `pull_request_target`, which runs with your
> repository secrets in scope so it can comment on fork pull requests. **It therefore must never
> check out the pull request's code.** The shipped workflow reads the diff through the API. If you
> modify it, keep that property — adding an `actions/checkout` of the PR ref hands your secrets to
> anyone who opens a pull request. On a docs repo that now includes a token that reads your
> application repository.

Not wiring this up? Delete the workflow file.

### Step 6 — Workflow permissions

**Settings → Actions → General → Workflow permissions** → **Read and write permissions**.

Required because `changelog.yaml` commits generated content back to the repository, and
`strip-ai-on-pr.yml` rewrites the production branch. Both declare `contents: write` at job level;
the repository setting is a ceiling those declarations cannot exceed.

### Step 7 — Dependabot

`.github/dependabot.yml` ships configured. It needs no secret, but it does need
**Settings → Code security → Dependabot alerts** and **security updates** enabled to be useful.

### Nice to have — branch protection

**This step is optional, and on a private repository it is a paid feature** (GitHub Pro, Team, or
Enterprise). On a public repository it is free.

Everything above works without it. What it adds is the difference between the gate **reporting** a
failure and the gate **preventing** a merge.

If you have it, **Settings → Rules → Rulesets → New branch ruleset**, applied to `dev` and `prod`:

| Setting | Value | Why |
| :-- | :-- | :-- |
| Require a pull request before merging | on | The gate triggers on `pull_request`. Direct pushes bypass it entirely |
| Require status checks to pass | on, select **Quality Gate** | Without this the gate reports and merges anyway |
| Require branches to be up to date | on | Otherwise the gate passes against a stale base |
| Block force pushes | on | The strip pipeline's history is not recoverable from a force push |

Two things must **not** be required checks:

- **`react-doctor`** is advisory and never fails a build. Marking it required makes it a blocking
  gate it was not designed to be.
- **`Check Generated Doc TODOs`** emits a warning, not a failure, on purpose — a half-filled
  generated page is often a legitimate intermediate state.

> **Do not add a rule that blocks the bot.** `changelog.yaml` commits to the repository. If your
> ruleset requires pull requests with no bypass, the changelog job fails on push. Add the
> `github-actions` app to the ruleset's **bypass list**, or scope the pull-request requirement so
> the bot's branch is exempt.

#### If you do not have it

The gate still runs on every pull request and still shows red or green. What is missing is only the
block. Three things close most of that gap for free:

**1. Run the gate before you push.** It is the same script CI runs, so there are no surprises:

```bash
bash .github/scripts/quality-gate.sh origin/dev
```

**2. Make it automatic with a pre-push hook.** This genuinely enforces — the push does not happen:

```bash
# .husky/pre-push
bash .github/scripts/quality-gate.sh origin/dev
```

Local hooks can be skipped with `--no-verify`, so this is discipline rather than a wall. But it
catches the ordinary case, which is someone forgetting, not someone deliberately bypassing.

**3. `CODEOWNERS` still requests reviewers.** The shipped file says as much in its own comment:
without branch protection it is a prompt, not a gate. A prompt is still worth having.

If the repository can be public, making it public is the cheapest way to get real enforcement —
branch protection, secret scanning, and push protection all become free at once.

### Checklist

```
□ Branches dev and prod created and pushed          ← nothing runs until this
□ Default branch set to dev
□ Secrets: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID  (or replace ci-cd.yaml)
□ Secret:  APP_REPO_TOKEN — fine-grained, Contents: Read-only, one repo
□ Secret:  DEEPSEEK_CODE_REVIEW_TOKEN   (or delete deepseek-review.yml)
□ Variable: CI_RUNNER                   (or leave unset — defaults to ubuntu-latest)
□ wrangler.jsonc present in the repo root
□ <github-org>/<app-repo> filled in inside changelog.yaml
□ Workflow permissions → Read and write
□ Dependabot alerts enabled

Nice to have — free on public repos, paid on private:
□ Branch ruleset on dev and prod, with github-actions on the bypass list
□ react-doctor and Generated Doc TODOs NOT required checks
□ CODEOWNERS updated from @your-github-handle (the file is free to add;
  auto-requesting reviewers from it needs a paid plan on a private repo)
```

### Verifying it without burning minutes

Open one throwaway pull request into `dev` with a whitespace change. That exercises
`quality-gate.yaml`, `deepseek-review.yml`, and `react-doctor.yml` in a single run.

Test `changelog.yaml` separately with **Actions → Changelog → Run workflow** if you have added a
`workflow_dispatch` trigger, or by pushing to `prod` once you are ready for a real content
revision. It commits, so it is not a free dry run.

---

## Requirements

Nothing is mandatory. Every piece degrades to "delete this file" rather than breaking the rest.

| For | You need |
| :-- | :-- |
| Hooks, commands, subagents | An agent runtime that reads `.claude/` |
| The quality gate | GitHub Actions, plus the package scripts named in `SETUP.md` §5 |
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

The `agents-` prefix is only a namespace, so project subagents sort together in the picker and never
collide with a built-in name. Rename it to anything you like — just rename the `name:` field in the
frontmatter and the row in `.claude/agents/INDEX.md` together, since the gate's index-coverage check
verifies both directions.

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
