# Setup

Ordered by dependency, not by importance. Each step is verifiable before the next one starts, and
the step that can delete files comes last on purpose.

Budget about forty minutes. Steps 1–5 are the useful minimum; 6–9 are opt-in.

| Step | What you get | Required |
| :-- | :-- | :-- |
| [1. Copy the layer in](#1-copy-the-layer-in) | The files, and the tools they need | yes |
| [2. Fill in every placeholder](#2-fill-in-every-placeholder) | No `<placeholder>` left for an agent to act on | yes |
| [3. Agent tooling](#3-agent-tooling--mcp-servers-wrappers-plugins) | The MCP servers you keep, and the ones you load on demand | yes |
| [4. The hooks](#4-the-hooks) | Guards that refuse, proven by the probes | yes |
| [5. Make the gate runnable](#5-make-the-gate-runnable) | The gate list before each commit, the unlock alias | yes |
| [6. The content pipeline](#6-the-content-pipeline--yours-to-write) | The generators' shape and the changelog workflow | when you generate pages |
| [7. Slash commands and their mirror](#7-slash-commands-and-their-mirror--optional) | One source for every command | optional |
| [8. GitHub repository settings](#8-github-repository-settings) | Secrets, merge settings, the pull-request CI | for CI |
| [9. The AI-config strip pipeline](#9-the-ai-config-strip-pipeline--last-and-only-if-you-want-it) | A production branch with no agent config | last, optional |

> **The workflows arrive disarmed.** Nothing in `.github/workflows/` runs on a push, on a schedule or
> by hand. The deploy, changelog, strip, review and gate workflows wait for pull requests into `dev`
> or `prod`, and this repo ships with just `main`, so they activate when you create those two
> branches (§8). Three read-only checks (dependency review, CodeQL, workflows lint) run on a pull
> request into any branch; on a private repository the first two skip themselves until the
> `CODE_SECURITY` variable is set. None of them needs a secret.

---

## 1. Copy the layer in

From the root of your docs repository, copy the layer, not this repository's own documents
(`README.md`, `README.id.md`, this file, `docs/assets/`, `LICENSE`, `.markdownlint-cli2.jsonc`):

```bash
CFG=/path/to/docs-agent-config
cp -R "$CFG"/{.claude,.agent,_workflow-source,.github,.husky,scripts} .
cp "$CFG"/{CLAUDE.md,.mcp.json,oxlint.json,.oxlintignore,.oxfmtrc.json,knip.ts,doctor.config.json} .
cp "$CFG"/{.gitleaks.toml,.skillspector-baseline.yaml,wrangler.example.jsonc} .
mkdir -p docs && cp "$CFG"/docs/{unlock.md,RATIONALE.md} docs/
```

`docs/unlock.md` is where the hooks' refusals send you, and `docs/RATIONALE.md` is the "why" that
`CLAUDE.md`, the rules and the workflows cite; both stay in your repository. The one copied file
that still points at this guide, `scripts/check/gates.list`, names it as docs-agent-config's.

Copy `.env.development.example` and `.env.production.example` too if your repository has no env
templates yet; if it has them, merge the keys into yours instead of overwriting them (§5 explains
what reads them).

Then **merge `.gitignore` into yours.** `.claude/settings.local.json`, `.claude/state/` and every
real `.env*` file must be ignored before your first commit, not after. `.claude/state/` holds the
unlock files and the `.env` backups of §4, and `scripts/env/set.sh` refuses to run until it is
ignored.

> **There is no `AGENTS.md` or `SSOT.md` to copy.** That is not an omission — see `CLAUDE.md` at
> the top, which explains why a docs site carries its whole rule layer in one file. Do not create
> them "for consistency" with your other repositories; an empty rulebook is worse than none,
> because agents cite it.

### Tools

| Tool | Needed by | Without it |
| :-- | :-- | :-- |
| bash 3.2 or newer, git | every hook and script | nothing runs |
| python3 3.8 or newer | the command analyzer in the safety hook, `db-guard.sh`, the unlock and `.env` helpers, `ai-config.sh`, `pr-ready.sh`, the hook probes | the safety hook falls back to a few plain-text rules and says so; `db-guard.sh` refuses every call; the checks fail rather than pass unread |
| jq | optional: faster hook input | nothing is lost |
| macOS, or Linux or WSL2 with `bubblewrap` and `socat` | Claude Code's Bash sandbox, which `.claude/settings.json` turns on by default (§4) | on WSL1, native Windows or a machine missing a package, Claude Code warns and runs commands without it (unless `sandbox.failIfUnavailable` is `true`); the hooks still apply |
| Bun, and Node 20 or newer | the package scripts, the build, `folder-shape.mjs` | the gate cannot run |
| uv (`uvx`) | the `serena` and database MCP servers, installing SkillSpector | those servers do not start |
| SkillSpector 2.11.2 | `scripts/check/skills.sh` | the gate fails and prints the pinned install command |
| gh, signed in | `scripts/ops/pr-ready.sh`, `/merge-pr`, `/promote` | those commands stop at the readiness check |
| gitleaks | the secret scan in `.github/scripts/quality-gate.sh` on your machine (CI fetches a pinned build) | the local run reports the scan as skipped |

On macOS, `/bin/bash` is 3.2; everything here is written for it.

---

## 2. Fill in every placeholder

Placeholders are named, never blank. This grep finds every one, together with usage syntax that
stays as written, such as `<file>` or `<paths>` in an example command:

```bash
grep -rn '<[a-zA-Z][a-zA-Z -]*>' CLAUDE.md .mcp.json .claude/ .github/ _workflow-source/
```

The ones to fill are in these files:

| File | What to replace |
| :-- | :-- |
| `CLAUDE.md` heading | Project name |
| `CLAUDE.md` § Orientation | The file list is Nextra-specific — rewrite for your framework |
| `CLAUDE.md` § Quality Gates | Your actual commands, if they differ |
| `.claude/rules/docs-site/content.md` | Which pages are generated and from what, the repository the site documents, and the claims about it that must never drift. Point its `paths:` list at your folders |
| `.claude/docs/code-review-checklist.md` | Nothing; its last section holds the docs-site review checks. Add your own there |
| `.mcp.json` | Nothing: every token is a `${VARIABLE}` read from your shell. Delete the servers you do not use (§3) |
| `.claude/mcp/*.example.json` | Only for an on-demand server you use: copy, fill and pin it (§3). Otherwise delete them |
| `.github/CODEOWNERS` | `@your-github-handle`, and drop rows for files you do not have |
| `.github/workflows/changelog.yaml` | `<github-org>/<app-repo>`, once, in its `env:` block (§6) |
| `.github/workflows/deepseek-review.yml` | Its `sys-prompt` describes a Nextra site with no backend: correct the stack, the places your app code lives and the project rules it lists, or the reviewer reports findings against files you do not have |
| `_workflow-source/promote.md` · `promote-deploy.md` | § This repo's deploy target: the platform, the Worker's name, the live URL, and the adapter's `read-env`, `latest`, `trigger` and `backup` commands. Then run `bash scripts/sync/workflows.sh` to update the mirrors (§7) |
| `wrangler.example.jsonc` | Copy to `wrangler.jsonc`; the Worker name, the creation date and the hostname (§8, Cloudflare deploy) |
| `.env.development.example` · `.env.production.example` | Nothing, unless your site or generators read more keys: add each one with a placeholder value, never a real one (§5) |

Four on-demand references ship as `.claude/*.example.md`. `CLAUDE.md` § On-demand References
lists each one, so an agent reads it only when the task matches; nothing imports them. Copy the ones
you use to the name without `.example` and fill every placeholder; delete the rest together with
their table rows. An unfilled template is worse than an absent one, because an agent will try to
use it.

| Template | Covers | Most docs sites |
| :-- | :-- | :-- |
| `OPERATIONS.example.md` | The hook contract, GitHub and CI, reviews, MCP pins, deploy verification, skill scanning | **Keep it.** Its hook, CI and review sections apply as shipped; delete the deploy, container and database parts you do not use |
| `CI-RUNNERS.example.md` | Two runner pools behind `CI_RUNNER` / `CI_RUNNER_FAST` | Delete it unless you run CI on more than GitHub's hosted runners |
| `DATABASE.example.md` | Database access over MCP: topology, tunnel, the agent's role, production rules | Delete it, with `db-dev` and `db-prod` in `.mcp.json` |
| `ANALYTICS.example.md` | An analytics read API: base URL, auth headers, a verified example | Delete it if you have no analytics backend |

---

## 3. Agent tooling — MCP servers, wrappers, plugins

This is what the agent actually reaches for on every task. Hooks stop bad edits; **this decides how
well it works in the first place**, so it is worth ten minutes even though nothing breaks if you
skip it.

### Every tool by name, and where it is covered

| Tool | What it is | Ships here? | Covered in |
| :-- | :-- | :-- | :-- |
| **Serena** | Semantic code search and edit over a language server | `.mcp.json` | [below](#serena--install-it-or-delete-the-line-that-assumes-it) |
| **Context7** | Live library documentation lookup | `.mcp.json` | server table below |
| **GitHub MCP** | Pull requests, issues, and reviews inside a session | `.mcp.json` | server table below |
| **Postgres MCP** | Database schema, health, and query plans (`db-dev`, `db-prod`), read-only as shipped | `.mcp.json` | server table below · `DATABASE.example.md` |
| **Cloudflare** | DNS, Workers, and account resources | **On demand** — `.claude/mcp/cloudflare.example.json` | [On-demand servers](#on-demand-servers) |
| **Deploy platform · VPS provider** | Deployments, logs, DNS, and VPS control | **On demand** — `.claude/mcp/*.example.json` | [On-demand servers](#on-demand-servers) — neutral placeholders |
| **Command wrapper** | Output filter, sandbox, or recorder in front of your shell | **No** — machine-local | [Command wrappers](#command-wrappers) |
| **Plugins** | Session add-ons | **No** — machine-local | [Plugins](#plugins) |
| **DeepSeek Code Review** | AI review comment on pull requests | `.github/workflows/` | [below](#ai-code-review-on-pull-requests--deepseek) · §8 |
| **react-doctor** | Framework health checks — **advisory, never fails a build** | `.github/workflows/react-doctor.yml` | Runs on pull requests only. Do not make it a required check (§8) |
| **react-doctor skill** | Lets the agent run and triage React Doctor locally | **No** — own installer | `npx react-doctor@<version> install`, pinned to the version you checked. Installed by reference, never copied in: it is the vendor's to update |
| **impeccable** | Interface design and polish skill | **No** — own installer | `npx impeccable@<version> install`, pinned the same way, if your theme needs design work |

### The servers in `.mcp.json`

Five ship. **Most projects should delete most of them.** Every connected server spends context on
its tool definitions before you have asked anything, so an unused server is a permanent tax.

| Server | What it gives the agent | Needs | Keep it if |
| :-- | :-- | :-- | :-- |
| `serena` | Semantic code search and edit over a language server — find a symbol, its references, its implementations, rename it safely | `uvx` ([Astral uv](https://github.com/astral-sh/uv)). No token | **Almost always.** See below |
| `context7` | Current library documentation, fetched live | `npx`. No token | You use libraries that moved recently |
| `github` | Pull requests, issues, reviews, and branches from inside a session | `GITHUB_PERSONAL_ACCESS_TOKEN` in your shell. GitHub hosts the server; nothing installs | You want the agent to open and read pull requests |
| `db-dev` · `db-prod` | Query and inspect a database — schema, health, index advice, query plans. Both start **read-only** (`--access-mode=restricted`) | `uvx`, and `DB_DEV_URI` / `DB_PROD_URI` in your shell, plus a tunnel if the port is not public | Rarely — a docs site has no database. Usually **delete both** |

Every package is pinned to an exact version, because a package runner left on the latest release
runs whatever was published last. `scripts/check/ai-config.sh` fails the gate on an unpinned one.
Move a pin deliberately, after reading the release.

Deleting a server is removing its object from `.mcp.json`. `.claude/settings.json` names three of
them — `serena` (its write tools, in the edit hooks' matchers), `github` (`mcp-guard.sh`) and
`db-prod` (an `ask` rule and `db-guard.sh`) — and those entries simply match nothing once the
server is gone.

**The production database starts read-only.** `db-prod` runs with `--access-mode=restricted`, so
the server itself refuses every write, and a permission prompt (`ask`) still guards
`execute_sql`. If you want the agent able to fix production data during an incident, drop that
flag and give its role write grants; from then on `db-guard.sh` holds every write until you run
`unlock db` yourself ([`docs/unlock.md`](docs/unlock.md)).

### On-demand servers

A server you reach for once a month should not spend context in every session. Three examples ship
in `.claude/mcp/`: `deploy-platform.example.json` (deployments, logs, backups) and
`vps-provider.example.json` (VPS, domain and DNS management) as neutral placeholders rather than
recommendations, and `cloudflare.example.json` (DNS, Workers and account resources) for the Worker
`ci-cd.yaml` deploys to. To use a placeholder:

1. Copy it to `<name>.json` in the same folder.
2. Put your provider's MCP package in place of the placeholder, pinned to the exact version you
   checked. A copy that still says `<pinned-version>` fails `ai-config.sh`.
3. Rename the `env` keys to the ones that package reads, keeping the `${VARIABLE}` values that
   point at your shell.
4. Load it for one session:

   ```bash
   claude --mcp-config .claude/mcp/deploy-platform.json
   ```

The Cloudflare example is a hosted server with no package to pin: copy it to `cloudflare.json` as it
is, keep `CLOUDFLARE_API_TOKEN` in your shell, and load it the same way when a session has Worker,
DNS or account work to do. The deploy itself never needs it; `ci-cd.yaml` uses its own secrets.

If the deploy platform's server can redact environment values from its output, turn that on: a
tool result is part of the transcript. Delete the examples you will never use.

### Serena — install it, or delete the line that assumes it

`CLAUDE.md` § Agent Tooling tells the agent to call Serena's `initial_instructions` before its first
symbol search and to use Serena's symbol tools for `.ts`/`.tsx` files. A docs site has few of those,
so Serena earns less here than in an application repository.

**If Serena is not installed, that line sends the agent to a server that is not there.** It falls
back to the built-in tools and says so, so nothing deadlocks, but you pay for the detour. Pick one,
deliberately:

- Install [uv](https://docs.astral.sh/uv/getting-started/installation/), which provides `uvx`. The
  server itself needs no separate install: the `.mcp.json` entry fetches its pinned release on first
  run.
- **Or** delete the Serena line from `CLAUDE.md` § Agent Tooling and the `serena` entry from
  `.mcp.json`, together. Deleting one without the other is the failure case.

**`ENABLE_TOOL_SEARCH: "true"`** defers Serena's tool definitions until they are needed. It cuts the
per-session cost substantially. The trade-off: Serena's own instructions are deferred too, so the
session must call `initial_instructions` once before its first symbol search, which is what
`CLAUDE.md` § Agent Tooling asks for.

**No `alwaysAllow` list.** That key belongs to other MCP clients; Claude Code never reads it, so
it only looked like approval. Permissions for MCP tools live in `.claude/settings.json`: to stop
the prompts for Serena's read tools, add them to `permissions.allow` there (for example
`mcp__serena__find_symbol`), and leave its editing tools on the normal prompt. That prompt is the
only thing between Serena and a `.env*` file: the `Read(.env*)` and `Edit(.env*)` deny rules cover
Claude Code's own file tools, and no hook reads the path a Serena edit names. Never approve one
aimed at a `.env*` file or at `.claude/state/` (`docs/RATIONALE.md` §21).

### Command wrappers

If you route shell commands through a wrapper — an output filter, a sandbox, an audit
recorder — declare it in `CLAUDE.md` § Agent Tooling **as a hard rule**, prefix every command in
that file with it, and list it under `commandWrappers` in `.claude/agent-config.json` so the safety
hook judges the command it runs rather than the wrapper.

None ships here, on purpose: a wrapper is machine-local tooling that a fresh clone will not have,
and a rule pointing at a missing binary fails every command. The **shape** is left in place so you
can slot yours in. It has to be a hard rule because a wrapper mentioned in passing gets dropped the
moment a task gets busy, and then half your commands are wrapped and half are not.

### Plugins

`.claude/settings.json` ships with **no plugins enabled**. A session add-on is usually configured
through `enabledPlugins`, sometimes with a few environment variables. None is declared here, for the
same reason as the command wrapper: a plugin declared but not installed is a startup error for
everyone who clones this. If you use plugins, they go in the same file:

```jsonc
{
  "enabledPlugins": { "<plugin>@<source>": true },
  "env": { "<PLUGIN_SETTING>": "<value>" }
}
```

Keep them out of `.claude/settings.local.json` if the whole team should get them, and in it if the
choice is yours alone. The `.gitignore` here already excludes the local file.

### AI code review on pull requests — DeepSeek

`.github/workflows/deepseek-review.yml` posts an AI review comment on pull requests into `dev`,
using [`hustcer/deepseek-review`](https://github.com/hustcer/deepseek-review) — which accepts any
OpenAI-compatible endpoint, so the provider is your choice despite the name. Setup is one secret
(§8). It runs on `pull_request`, for a pull request opened from a branch of this repository, and on
an `issue_comment` of `/ask-deepseek` from someone with write access, re-reviewing on demand:

| Event | Workflow file from | The review secret | This workflow |
| :-- | :-- | :-- | :-- |
| `pull_request`, head branch in this repository | the pull request's merge commit | available | reviews |
| `pull_request` from a fork | the pull request's merge commit | withheld | skipped by the job's `if:` |
| `issue_comment` on a pull request | the default branch | available | reviews, only for `/ask-deepseek` from an owner, member or collaborator |

The comment path runs with the secret even on a fork's pull request, so the workflow **must never
check out the pull request's code**: the action reads the diff through the API. Nothing here needs
`pull_request_target`, which GitHub's default policy turns off in public repositories from
2 November 2026 (`docs/RATIONALE.md` §5).

---

## 4. The hooks

`.claude/settings.json` already wires every script in `.claude/hooks/`, each run as
`bash "$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.sh"` with a timeout. `.claude/hooks/README.md`
says what each one refuses, why, how it fails when python3 or jq is missing, and how to turn it
off.

### The contract

- Claude Code sends the tool call as **JSON on stdin**. No `CLAUDE_TOOL_INPUT_*` variable exists,
  so a hook that reads one does nothing (`ai-config.sh` fails on it).
- **Only a `PreToolUse` hook can stop a tool call, and only by exiting 2**, with the reason on
  stderr. Exit 1, a crash or a timeout lets the call through. `PostToolUse` hooks run after the
  write has landed and can only report. Anything that must not happen belongs in a `PreToolUse`
  hook that exits 2; anywhere else you get a guard that looks installed and enforces nothing.
- A hook speaks to Claude through stderr (a refusal) or `hookSpecificOutput.additionalContext` on
  stdout. Stdout carries that JSON or nothing.
- Hooks on one event run in parallel, which is why formatting and linting share one script.
- The `SessionStart` and `UserPromptSubmit` hooks end in `|| true`: an exit 2 on a prompt erases it.
- No hook opens a network connection or installs anything.

### Prove them

**Test a guard by triggering it, never by reading it.** A guard whose path pattern does not match
your layout never fires and never complains. `bash scripts/check/hook-probes.sh` feeds every hook
the JSON Claude Code sends and checks both what it blocks and what it lets through, in temporary
fixtures that never touch your repo. It takes about nine minutes; on macOS, run it with
`/bin/bash` to prove bash 3.2. Run it after any change to a hook, `settings.json` or
`scripts/check/hook-probes.tsv`; the gate list does too.

One check by hand, from the repository root:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}' |
  bash .claude/hooks/safety-check.sh; echo "exit $?"    # the reason on stderr, then: exit 2
```

### Point the generated-content guard at your output

An agent that hand-edits a generated page produces work that looks correct, passes review, and
disappears on the next regeneration. `generated-guard.sh` refuses those edits, but only you know
your output paths: its defaults name an application's generated API client, which a docs site does
not have, so until you set your own it guards nothing.

Copy `.claude/agent-config.example.json` to `.claude/agent-config.json`, keep only the key you
change, and list the folders and pages your generators rewrite:

```json
{ "generatedPaths": ["content/technical", "content/changelog.mdx"] }
```

Keep the list in step with the table in `.claude/rules/docs-site/content.md` and the pattern in
`/ship`. Leave out a page whose hand-written section the generator preserves, or edits to that
section are refused too. Then test it by asking an agent to edit one of those pages: the edit must
be refused.

### Secrets and production writes stay locked

The hooks refuse the shell commands that read or write a real `.env*` file, and the sandbox refuses
the reads underneath them. The agent lists one with `bash scripts/env/show.sh <file>`, which masks
the secrets, and changes a value only through `scripts/env/set.sh`, which works while you have
unlocked `env`. Writes to the production database wait for `db` the same way. Only you unlock, for a
few minutes, by running `! bun unlock env` (or `db`) yourself; the alias is in §5, and
[`docs/unlock.md`](docs/unlock.md) covers the rest, including what the lock does not stop.

### What the safety hook refuses

`safety-check.sh` refuses these categories, and `.claude/hooks/README.md` lists each rule with its
fix:

- a recursive delete of a protected path, the repo, a parent or the home folder, and a `find` that
  deletes outside a temp folder;
- commands that wipe uncommitted work: a hard reset, a forced `clean`, `checkout .`, `restore .`, a
  `stash` without a pathspec;
- skipping the pre-commit gate: `--no-verify`, `commit -n`, `HUSKY=0`, `SKIP=`, a moved
  `core.hooksPath`;
- a push to, or the deletion of, a protected branch, and `gh pr merge --delete-branch`;
- any shell read or write of a real `.env*` file or of `set.sh`'s backups;
- the unlock, from the agent, by any route it can read, and changing `scripts/env/` or the unlock
  script from the shell;
- changing the other guards from the shell: the hooks, `scripts/check/hook-probes.*` and the
  settings that turn the guards on (a change goes through the Edit tool, which asks you first, or
  your own `!`);
- git settings that change what git runs, which config it loads, where it connects or where it
  works (an alias, an include, `core.sshCommand`, `core.fsmonitor`, an editor or pager command, a
  credential helper, `protocol.*.allow`, a proxy, `url.*.insteadOf`, `safe.directory`, ...),
  whatever their value, set with `-c`, `--config-env` or `GIT_CONFIG_*`, or written with
  `git config`. Plain settings such as `user.*` and `color.*`, and config reads, stay open.

It peels wrappers (`env`, `sudo`, `timeout`, `nohup`, `xargs`, ...) and package runners (`npx`,
`bunx`, `pnpx`, `npm`/`pnpm`/`yarn`/`bun` `exec`, `dlx` and `x`) and judges the command they run. A
runner's `-c` string, and the script `bun exec` and `yarn exec` build by joining their words, are
judged like `bash -c`. List a wrapper of your own under `commandWrappers`.

### When the safety hook cannot tell, it refuses

The safety hook reads a command the way a shell does, and it fails closed. A payload that is not
JSON is refused, and so is every command when python3 crashes or the analyzer runs past 8 s. When it
cannot resolve what a command touches, it refuses (exit 2) with the reason and the hint to run the
command yourself with `!` if it is intended, whether or not a `.env*` name appears in plain text.
The shapes it refuses: `eval` and sourced or decoded text; code a shell or interpreter reads from
stdin out of output the hook cannot read (`curl … | bash`); a command git or a pager runs from a
setting or variable (`GIT_PAGER`, `EDITOR`); `$( )` or `<( )` as the command name or as a file
operand; a path built through `IFS`, `dotglob`, an array or `printf`; a package runner whose command
or shell text is built from `$( )` or an unknown variable, or a recipe `make`, `just` or `task`
reads from stdin; inline code that opens or builds a path to a file; a copy, link or archive landing
on `.claude/state/` or a `.env*` file; and `xargs` feeding a file reader. The one allowance is a
literal `git ls-files` or `git diff --name-only` whose pathspecs cannot match `.env*`, so
`cat $(git ls-files '*.md')` still runs. A false refusal costs you one `!`; that is the trade. `!`
runs the command as you, with your own access, outside the hooks and (in an ordinary session)
outside the sandbox.

Without python3 the hook falls back to plain-text rules: pushes to protected branches, recursive
deletes of protected paths, a hard reset, a forced `clean`, `--no-verify` and `HUSKY=0`, any real
`.env*` name, the unlock, and any mention of `scripts/env/`, of a file that turns the guards on or
of a guard script. Everything else runs unchecked on such a machine, so install python3.

### The sandbox under the hooks

`.claude/settings.json` also turns on [Claude Code's Bash
sandbox](https://code.claude.com/docs/en/sandboxing), on by default
(`"sandbox": {"enabled": true}`). The operating system then stops every sandboxed command, and
anything it starts, from reading `.env*` files (`.envrc` included, at any depth) or the backups in
`.claude/state/env-backups/`, and from writing under `.claude/state/unlock/` or `.claude/hooks/` or
to `scripts/ops/unlock.sh`; the `*.example` templates stay readable. Only `scripts/env/show.sh` and
`scripts/env/set.sh` are excluded from it.

- **Platforms.** macOS needs nothing; Linux and WSL2 need `bubblewrap` and `socat`. WSL1 and native
  Windows are not supported. Where the sandbox cannot start, Claude Code warns and runs commands
  without it (unless `sandbox.failIfUnavailable` is `true`); the hooks still apply.
- **The retry outside it.** A command that must read `.env` itself, such as the dev server or a
  generator, fails inside the sandbox; Claude Code can retry it outside, through its normal
  permission prompt. Set `sandbox.allowUnsandboxedCommands` to `false` to forbid that retry.
- **Your `!` commands** run outside the sandbox, so `! bun unlock env` can write its file. In a
  background session with `allowUnsandboxedCommands: false`, and on Linux with
  `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` set, `!` commands are sandboxed too (and, before Claude Code
  2.1.260, in any session with `allowUnsandboxedCommands: false`), so the unlock is refused: run it
  in your own terminal there.
- **Turning it off.** Set `"sandbox": {"enabled": false}` in `.claude/settings.json`, or in your own
  `.claude/settings.local.json`. The hooks keep running.

---

## 5. Make the gate runnable

Two layers run one set of checks. **`scripts/check/gates.list` is the local gate**:
`.husky/pre-commit` runs it on every commit through `scripts/check/gates.sh`, choosing the gates
by what is staged, and `bash scripts/check/gates.sh` runs all of it by hand.
**`.github/scripts/quality-gate.sh` is the CI gate**: it runs everything on that list, plus the
checks that need the whole branch — dependency audit, secret scan over the history, SkillSpector
over changed commands, the production build and the source-map leak check. Both call package
scripts, so those must exist. `dev` and `build` go through the environment preflight and the
Next.js wrapper that ship in `scripts/`:

```jsonc
{
  "scripts": {
    "dev": "bun run scripts/next/env.ts check development --soft && node scripts/next/run.mjs dev",
    "build": "bun run scripts/next/env.ts check production --soft && node scripts/next/run.mjs build && pagefind --site .next/server/app --output-path out/_pagefind",
    "preview": "wrangler dev",
    "env:init": "bun run scripts/next/env.ts init",
    "docs:generate": "bun run scripts/next/env.ts check development --soft && bun run scripts/generate/docs/index.ts",
    "changelog:generate": "bun run scripts/next/env.ts check development --soft && bun run scripts/generate/changelog/index.ts",
    "format": "oxfmt --write",
    "fl": "oxfmt --write && oxlint -c oxlint.json --ignore-path=.oxlintignore",
    "fl:ci": "oxfmt --check && oxlint -c oxlint.json --ignore-path=.oxlintignore",
    "type-check": "tsc --noEmit",
    "check:dead-code": "knip",
    "sync:workflows": "bash scripts/sync/workflows.sh",
    "unlock": "bash scripts/ops/unlock.sh",
    "prepare": "husky"
  }
}
```

Add the tools the gates, the build and the preview call as dev dependencies, pinned —
`bun add -d husky knip oxfmt oxlint @types/bun pagefind`, then
`bun add -d -E typescript@6.0.3 wrangler@3.114.17`. TypeScript stays on 6: twoslash, which Nextra
uses to highlight code, supports TypeScript 5.5 to 6 (its peer range), and `bun run build` fails on
7 with `Cannot read properties of undefined (reading 'readFile')`. Wrangler 3.114.17 is the release
`ci-cd.yaml` deploys with (§8, Step 4). Knip reports a binary a script runs that no dependency
provides. `pagefind` builds Nextra's search
index into the export; a site that searches some other way replaces that step of `build`.
`prepare` installs the pre-commit hook on the next `bun install`. The scripts in `scripts/` run on
Bun and use its globals, so `tsconfig.json` needs `"types": ["bun"]` under `compilerOptions`:
current TypeScript loads no `@types` package its config does not name, and `type-check` then
fails on them. TypeScript 6 also checks side-effect imports, so the theme's
`import 'nextra-theme-docs/style.css'` fails `type-check` until a `.d.ts` file in the project
declares `declare module '*.css';` (or `compilerOptions` sets `"noUncheckedSideEffectImports":
false`).

### The env templates

`scripts/next/env.ts` treats `.env.development.example` and `.env.production.example` as the
schema — a key with a non-empty example value is required — so keep both committed, with
placeholder values only, before the first `env:init`. The development one lists the generators'
keys; the production one is empty on purpose, because a static export reads no environment, and
`/promote` audits the live Worker's variables against it. `scripts/env/show.sh` also lists the keys
a real `.env` file is missing compared with its template.

### The unlock alias

`unlock` is only an alias, so the unlock command of §4 reads the same in every package manager:

| Package manager | Open `.env*` changes (20 min) | Open production SQL writes (15 min) |
| :-- | :-- | :-- |
| bun | `! bun unlock env` | `! bun unlock db` |
| npm | `! npm run unlock env` | `! npm run unlock db` |
| pnpm | `! pnpm unlock env` | `! pnpm unlock db` |
| yarn | `! yarn unlock env` | `! yarn unlock db` |
| none | `! ./scripts/ops/unlock.sh env` | `! ./scripts/ops/unlock.sh db` |

`status` shows what is open and until when, `off` locks everything now, and a number of minutes
(1 to 240) after the target changes how long it stays open. `db` matters only when your production
database server accepts writes; [`docs/unlock.md`](docs/unlock.md) explains when that is.

### Layout, and the merge check

`scripts/` holds one folder per job and nothing loose at its root: `check/` for the gate list, its
runner, the checks and the hook probes; `env/` for the masked `.env` helpers and nothing else;
`next/` for the build wrapper and the environment preflight it runs after; `sync/` for the command
mirror; `ops/` for the unlock command and `pr-ready.sh`; and `generate/` for the content pipeline
in §6.

Keep your own scripts out of `scripts/env/`. The safety hook trusts the helpers there (`show.sh`,
`set.sh` and `envfile.py`) with `.env*` files, so the agent's shell may read and run what is in that
folder (`set.sh` only while `env` is open) but never change, replace, move or delete a file in it;
and the gate counts every file there as a hook file, so a commit that touches one runs the
nine-minute probes.

`/merge-pr` and `/promote` run `bash scripts/ops/pr-ready.sh <pr>` before a merge. On its own it
only checks that a pull request into the default branch does not come from that branch. To hold it
to the branch flow in `CLAUDE.md` § Branching, export this in the shell the agent runs from:

```bash
export PR_READY_FLOW="prod=dev dev=internal/*"   # prod takes only dev; dev only internal/ branches
```

Only a passing check counts. A skipped or neutral check is listed by name and blocks until you
confirm it skips by design; the command then re-runs `pr-ready.sh` with `--allow-skipped`. On a
private repository without `CODE_SECURITY` (§8, Step 3), CodeQL and dependency review skip
themselves, so every pull request asks you once.

### Run both gates once

Commit the layer first, or at least stage it: the comment-style check reads `git ls-files`, and
finds nothing to check in files git does not know. Run `bun run format` once too, so your own files
(`package.json`, `tsconfig.json`) match the formatter before `@format` checks them.

```bash
bash scripts/check/gates.sh                        # the local gate, every line
bash .github/scripts/quality-gate.sh origin/dev    # the CI gate, against your base branch
```

Five things worth knowing about them:

**`@format` is built into `gates.sh`.** It reads the formatter's scope from the `format` script
(which must start with `oxfmt`) and the linter's flags from `fl:ci`; on a commit it checks only
the staged files. Markdown is outside the formatter's scope (`.oxfmtrc.json` ignores `*.md`):
oxfmt adds trailing commas inside a Markdown JSON code block, which breaks a snippet like the one
above once pasted into `package.json`, and the shared agent-layer files stay as shipped.

**A commit runs only the gates its staged files need.** A content page (`content/**/*.md` or `.mdx`)
counts as docs, so it runs only the `all` lines, format and lint and the AI config check; other code
runs every line except the hook probes. The probes are the slow one, about nine minutes with bash
3.2, and run only when a commit stages a hook, `.claude/settings.json`, the probes themselves,
`scripts/ops/unlock.sh` or a file under `scripts/env/`. The agent's Bash tool stops a command after
two minutes unless told otherwise, so `CLAUDE.md` § Quality Gates asks for a longer timeout on
`gates.sh` and on such a commit.

**SkillSpector is installed by you, once.** `bash scripts/check/skills.sh` prints the pinned
install command when it is missing. Pre-commit scans the commands, subagents and hooks you stage;
CI installs the same pinned commit itself and scans what the pull request changed. Triage a finding
in `.skillspector-baseline.yaml`, one entry per finding, with a reason (`docs/RATIONALE.md` §16).

**`Check Generated Doc TODOs`** greps changed generated pages for placeholder markers. It **warns
rather than fails**, deliberately — a half-filled page is often a legitimate intermediate state,
and a hard failure teaches people to skip the step. Point its path glob at your generated
directories.

**`AI Config Check`** (`scripts/check/ai-config.sh`) holds `CLAUDE.md` plus every rule without
`paths:` to 15,000 bytes, keeps `@` imports out of `CLAUDE.md`, and checks that every hook
`settings.json` runs exists and every MCP server is pinned. Its rule-citation check skips itself
here, because there is no `AGENTS.md`.

---

## 6. The content pipeline — yours to write

Two generators this layer does not ship, because they are application code:

- `scripts/generate/docs/` reads your application repository and emits MDX — one extractor per
  symbol kind and a renderer.
- `scripts/generate/changelog/` reads commits and tags and emits a changelog page.

Code both use — the writer that preserves hand-edited sections, for one — goes in
`scripts/generate/shared/`. `changelog.yaml` keys its generation cache on `scripts/generate/docs/**`
and `scripts/generate/shared/**`: keep the generator under those paths, or move the `hashFiles`
keys with it, or a generator change hits a stale marker and never publishes.

### The two escaping traps

Both come from source text being *correct*, which is what makes them surprising:

**Multi-line destructured parameters inside a table cell.** The newline ends the inline-code span,
leaving an unbalanced `{` that the parser reads as a JSX expression. Collapse whitespace and escape
`|`, `<`, and `>` before the value reaches a cell.

**Element names in prose.** A comment describing `<Foo>` parses as an unclosed JSX tag. Escape `<`
before tag-shaped text.

Solve both at **render time, not write time.** A brace-balance heuristic is the obvious detector and
gives false positives on multi-line balanced expressions — and a detector that cries wolf gets
disabled, which is worse than not having one.

### `changelog.yaml`

This one **does** ship. Fill in `<github-org>/<app-repo>` (once, in its `env:` block) and add an
`APP_REPO_TOKEN` secret that can read the application repository (§8). It runs when a pull request
into `prod` is merged, and when the application repository sends an `app-deployed` dispatch after
its own release; GitHub runs a dispatch from the workflow file on the default branch. It commits
the generated pages to `prod`, copies them to `dev`, then calls `ci-cd.yaml` with the two Cloudflare
secrets only. To run it by hand, send the dispatch yourself (it commits and deploys):

```bash
gh api repos/<github-org>/<docs-repo>/dispatches -f event_type=app-deployed
```

Two things in it are deliberate and must not be "cleaned up":

**Its concurrency group is its own, not `strip-ai-on-pr.yml`'s.** Both push to the production
branch, but a shared group keeps only one pending run and cancels the older one, so it silently
dropped strip runs. Each push rebases and retries instead. It must never use `cancel-in-progress` —
a dropped run loses a content revision permanently. `docs/RATIONALE.md` §11 has the detail.

**Neither commit carries a skip-CI marker.** Nothing here runs on a push, so the bot's commits
cannot retrigger the workflow and a marker prevents nothing. On the development side it does harm:
GitHub skips every workflow for a pull request whose head commit carries one, so a promotion
opened from that commit runs no gate, and its merge runs no strip, no changelog and no deploy. It
reports as "no checks", which reads as a slow queue rather than a failure, so it survives
indefinitely.

---

## 7. Slash commands and their mirror — optional

Commands are maintained **once** in `_workflow-source/` and mirrored into `.claude/commands/` and
`.agent/workflows/`.

```bash
bash scripts/sync/workflows.sh           # write the mirrors
bash scripts/sync/workflows.sh --check   # verify without writing — this is the CI mode
```

`--check` is the mode that catches drift, and the reason is worth internalising: a write-mode run
**overwrites staleness before it can observe it**. Wire `--check` into your gate; wire the write
mode into nothing.

`.agent/workflows/` exists for a second tool that reads commands from that path. **If no such tool
is in use, delete it** — it is fourteen files kept in sync for a reader who does not exist. It
carries no `INDEX.md`: the index lives in `_workflow-source/` and `.claude/commands/`, and `--check`
reports a copy in `.agent/workflows/` as an orphan.

---

## 8. GitHub repository settings

Everything the workflows need, in the order to set it up. **Nothing here is needed to clone and read
the layer**; it is for wiring the gate into a real repository. Skip to
[the checklist](#checklist) for the short version.

A docs site has one wrinkle an application does not: **it talks to a second repository.** The
changelog pipeline reads the application repository's commits, which means a cross-repository token,
and that token is the one worth being careful with.

### What costs money, and what does not

**Everything required to make this layer work is free.** Only the enforcement on top of it depends
on the plan, and only for **private** repositories.

| Feature | Public repo | Private repo on the free plan |
| :-- | :-- | :-- |
| Actions minutes | Free, unmetered | Monthly allowance, then billed |
| Workflows, secrets, variables | Free | Free |
| Dependency review + code scanning (CodeQL) | Free | Paid add-on (GitHub Code Security) |
| Secret scanning + push protection | Free | Paid add-on |
| `CODEOWNERS` auto-review-request | Free | Paid — Pro, Team, or Enterprise |
| **Branch protection / rulesets** | **Free** | **Paid — Pro, Team, or Enterprise** |

On a private repository on the free plan the workflows, secrets and variables work; dependency
review and CodeQL skip themselves until you have Code Security and set `CODE_SECURITY`, and branch
protection is unavailable. Plans and limits change: check GitHub's current pricing before
concluding a feature is out of reach.

### Step 0 — Create the branches (this is what turns the workflows on)

```bash
git checkout -b dev  && git push -u origin dev
git checkout -b prod && git push -u origin prod
```

Until these exist, the deploy, changelog, strip, review and gate workflows **cannot trigger** —
each is scoped to pull requests into `dev` or `prod`. Then set `dev` as the default branch:
**Settings → General → Default branch**.

### Step 1 — Merge commits only

**Settings → General → Pull Requests**: keep **Allow merge commits** on, and turn **Allow squash
merging** and **Allow rebase merging** off. Every command here merges with `--merge`. A squash
re-dates the work to the merge day, leaves the merged branch looking unmerged to `/branch-cleanup`,
and folds every commit body into one message, where a described skip-CI marker silences the next
promotion (`docs/RATIONALE.md` §17).

### Step 2 — Repository secrets

In **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Required for | How to get it |
| :-- | :-- | :-- |
| `GITHUB_TOKEN` | everything | **Do not create this.** GitHub injects it per run. It appears in the workflows but never in your settings |
| `CLOUDFLARE_API_TOKEN` | the deploy in `ci-cd.yaml` | See [Step 4](#step-4--cloudflare-deploy) |
| `CLOUDFLARE_ACCOUNT_ID` | the deploy in `ci-cd.yaml` | Cloudflare dashboard → **Workers & Pages** → right sidebar. Not secret, but the action expects it here |
| `APP_REPO_TOKEN` | `changelog.yaml` | See [Step 5](#step-5--cross-repository-token) |
| `DEEPSEEK_CODE_REVIEW_TOKEN` | `deepseek-review.yml` | See [Step 6](#step-6--ai-review-token-optional) |

Delete the workflow rather than inventing a value for a secret you do not need. A workflow failing
on a missing secret every single run trains people to ignore red marks.

### Step 3 — Repository variables (not secrets)

In **Settings → Secrets and variables → Actions → Variables**:

| Variable | Purpose |
| :-- | :-- |
| `CI_RUNNER` | Runner label. Every job reads `${{ vars.CI_RUNNER \|\| 'ubuntu-latest' }}`, so **leaving it unset is valid** and gives you GitHub's hosted runners. Set it only to point at a self-hosted or third-party runner |
| `CI_RUNNER_FAST` | Optional faster pool, tried first by the two long jobs: the quality gate and the build-and-deploy job. Unset, they fall back to `CI_RUNNER`, then `ubuntu-latest`. `.claude/CI-RUNNERS.example.md` covers running two pools |
| `CODE_SECURITY` | `true` once a **private** repository has GitHub Code Security. Until then dependency review and CodeQL skip themselves, because both would fail on every pull request without it. A public repository needs nothing |

Variables are visible in logs; secrets are masked. A runner label is not sensitive, which is why it
is a variable.

### Step 4 — Cloudflare deploy

`ci-cd.yaml` deploys the built static site to a Cloudflare Worker via
[`cloudflare/wrangler-action`](https://github.com/cloudflare/wrangler-action).

1. Cloudflare dashboard → **My Profile → API Tokens → Create Token**.
2. Use the **Edit Cloudflare Workers** template, or build a custom token with
   `Account · Workers Scripts · Edit` and `Account · Account Settings · Read`.
3. Scope it to the **one account** that hosts this site, not "All accounts".
4. Add it as `CLOUDFLARE_API_TOKEN`, and the account ID as `CLOUDFLARE_ACCOUNT_ID`.

You also need a `wrangler.jsonc` in the repository root: copy `wrangler.example.jsonc` and fill in
the Worker name, the compatibility date and the hostname. Four things in it are deliberate:

- **No `main`.** An assets-only Worker runs no script per request, so serving the site costs no
  Worker requests. `output: 'export'` in `next.config.mjs` is what makes that possible; there is no
  `start` command under a static export.
- **`workers_dev: false` and `preview_urls: false`, both.** Anything bound to your hostname
  (Cloudflare Access, a WAF rule) does not cover the Worker's other addresses. Turning off
  `workers_dev` does not turn off preview URLs, and a flag you leave out keeps whatever the deployed
  Worker already has.
- **A hostname one level under your zone** (`docs.example.com`, not `docs.team.example.com`): the
  free Universal SSL certificate covers only the first level.
- **The compatibility date is the day you create the Worker.** Move it deliberately.

> The shipped workflow pins `wranglerVersion: '3.114.17'`, the last 3.x release, and the dev
> dependency in §5 pins the same one, so the action finds it installed and uses it. Current
> Wrangler 4 releases require Node 22 or newer, and the deploy job installs no Node of its own;
> 3.114.17 runs on older Node and already supports `preview_urls`. If you move to 4, change both
> pins and add a pinned `actions/setup-node` step for Node 22 in the same change.

**Deploying elsewhere?** Replace `ci-cd.yaml` outright rather than editing around it, and skip both
Cloudflare secrets (`docs/RATIONALE.md` §18 lists the rest).

### Step 5 — Cross-repository token

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
> dispatches *into* this one — the `app-deployed` dispatch the frontend layer's `ci-cd` sends after
> its deploy — that is a **separate** token living in the application repo, and it is the one that
> needs `Contents: Read and write` on this repository. Do not merge the two into one
> broadly-scoped token.

### Step 6 — AI review token (optional)

1. Create an API key at your provider's console (the shipped workflow uses
   [`hustcer/deepseek-review`](https://github.com/hustcer/deepseek-review), which accepts any
   OpenAI-compatible endpoint).
2. Add it as `DEEPSEEK_CODE_REVIEW_TOKEN`.
3. Confirm **Settings → Actions → General → Workflow permissions** allows pull-request writes.

§3 describes when it runs. Not wiring this up? Delete the workflow file.

### Step 7 — Workflow permissions

**Settings → Actions → General → Workflow permissions** → **Read and write permissions**.

Required because `changelog.yaml` commits generated content back to the repository, and
`strip-ai-on-pr.yml` rewrites the production branch. Every workflow starts from
`contents: read`; only those two jobs raise it, to `contents: write`, and the repository setting is
a ceiling those declarations cannot exceed.

### Step 8 — Pull-request CI, and why nothing runs on a timer

No workflow here starts on a push, on a schedule or by hand, and no bot opens update pull requests.
Every workflow starts from a pull-request event:

| Workflow | Starts on | Does |
| :-- | :-- | :-- |
| `quality-gate.yaml` | a pull request into `dev` or `prod` | the 22-step CI gate |
| `react-doctor.yml` | a pull request into `dev` or `prod` | framework health report, advisory |
| `deepseek-review.yml` | a pull request into `dev` opened or reopened; a `/ask-deepseek` comment | an AI review comment |
| `dependency-review.yml` | every pull request | fails a new or bumped dependency with a known high or critical vulnerability |
| `codeql.yml` | every pull request | code scanning, languages detected per pull request |
| `workflows-lint.yml` | a pull request that changes `.github/` | actionlint, zizmor and pinact |
| `strip-ai-on-pr.yml` | a pull request into `prod`, merged | strips the agent layer from `prod` (§9) |
| `changelog.yaml` | a pull request into `prod`, merged; the `app-deployed` dispatch | commits the generated pages, then deploys |
| `ci-cd.yaml` | only when `changelog.yaml` calls it | builds the site and deploys the Worker |

Work that used to follow a push to `prod` follows the merged pull request into `prod`, which is the
same moment in the normal flow. A push trigger would repeat checks the pull request already ran, and
a scheduler or update bot spends minutes and opens pull requests on a clock nobody watches. Updates
happen when a person decides: `pinact run -u --min-age 7` for the actions (the minimum age is a
cooldown against a freshly compromised release) and `bun update` for packages, each in a normal
pull request that `dependency-review.yml` then checks. Bun itself is pinned too, as `bun-version`
in `quality-gate.yaml`, `changelog.yaml` and `ci-cd.yaml`: move all three together, to the release
you run locally. `docs/RATIONALE.md` §19 has the trade-offs.

On a public repository dependency review and CodeQL work as shipped. On a private one they need
GitHub Code Security; set `CODE_SECURITY` (Step 3) once you have it. The dependency graph must
recognise your lockfile: check **Insights → Dependency graph**.

### Nice to have — branch protection

**Optional, and on a private repository a paid feature** (GitHub Pro, Team, or Enterprise). On a
public repository it is free. Everything above works without it; what it adds is the difference
between the gate **reporting** a failure and the gate **preventing** a merge.

**Settings → Rules → Rulesets → New branch ruleset**, applied to `dev` and `prod`:

| Setting | Value | Why |
| :-- | :-- | :-- |
| Require a pull request before merging | on | The gate triggers on `pull_request`. Direct pushes bypass it entirely |
| Require status checks to pass | on, select **Quality Gate**; add **Dependency Review** and the **Analyze** checks where they run (public, or `CODE_SECURITY=true`) | Without this the gate reports and merges anyway |
| Require branches to be up to date | on | Otherwise the gate passes against a stale base |
| Block force pushes | on | The strip pipeline's history is not recoverable from a force push |

Two checks must **not** be required:

- **`react-doctor`** is advisory and never fails a build.
- **`Workflows Lint`** runs only when a pull request touches `.github/`. A required check that
  never reports blocks every other merge.

`Check Generated Doc TODOs` needs no decision: it is a warning inside the quality gate, not a check
of its own.

> **Do not add a rule that blocks the bot.** `changelog.yaml` and the strip commit to the
> repository. If your ruleset requires pull requests with no bypass, those jobs fail when they push.
> Add the `github-actions` app to the ruleset's **bypass list**, or scope the pull-request
> requirement so the bot's pushes are exempt.

Without branch protection the gate still runs on every pull request and still shows red or green;
only the block is missing. Three things close most of that gap for free: `.husky/pre-commit` runs
the gate list on every commit (the agent's safety hook refuses `--no-verify`); run
`bash .github/scripts/quality-gate.sh origin/dev` before you push, which is the script CI runs; and
`CODEOWNERS` still requests reviewers. If the repository can be public, that is the cheapest way to
real enforcement: branch protection, secret scanning and push protection all become free at once.

### Nice to have — secret scanning and push protection

Turn on secret scanning and push protection in the repository's security settings. Push protection
refuses a push that contains a recognised token, before it reaches GitHub; it is the server-side
twin of the gitleaks step in the quality gate. Free on a public repository, a paid add-on on a
private one.

### Checklist

```text
□ Branches dev and prod created and pushed          ← nothing runs until this
□ Default branch set to dev
□ Merge commits on; squash and rebase merging off
□ Secrets: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID  (or replace ci-cd.yaml)
□ Secret:  APP_REPO_TOKEN — fine-grained, Contents: Read-only, one repo
□ Secret:  DEEPSEEK_CODE_REVIEW_TOKEN   (or delete deepseek-review.yml)
□ Variable: CI_RUNNER                   (or leave unset — defaults to ubuntu-latest)
□ Variable: CI_RUNNER_FAST              (optional faster pool for the two long jobs)
□ Variable: CODE_SECURITY=true          (private repo with Code Security; public needs nothing)
□ wrangler.jsonc copied from wrangler.example.jsonc and filled in
□ <github-org>/<app-repo> filled in inside changelog.yaml
□ Workflow permissions → Read and write

Nice to have — free on public repos, paid on private:
□ Branch ruleset on dev and prod, with github-actions on the bypass list
□ react-doctor and Workflows Lint NOT required checks
□ Secret scanning and push protection on
□ CODEOWNERS updated from @your-github-handle
```

### Verifying it without burning minutes

Open one throwaway pull request into `dev` with a whitespace change. That exercises
`quality-gate.yaml`, `deepseek-review.yml`, `react-doctor.yml`, `dependency-review.yml` and
`codeql.yml` in a single run, plus `workflows-lint.yml` when it touches `.github/`. Test
`changelog.yaml` separately with the dispatch in §6; it commits and deploys, so it is not a free
dry run.

---

## 9. The AI-config strip pipeline — last, and only if you want it

**This is the only part that deletes files. Everything else should be working before you touch it.**

The idea: your production branch carries no agent configuration at all. When a pull request into
`prod` merges, `strip-ai-on-pr.yml` removes the agent layer from `prod`, merges `prod` back into
`dev`, and checks both branches.

| Script | Role |
| :-- | :-- |
| `strip-paths.sh` | **The single source of truth** for what gets removed. The other three source it |
| `strip-ai.sh` | Removes those paths on the production branch |
| `verify-strip.sh` | Asserts they are gone from `prod` **and still present on `dev`** |
| `back-merge-prod.sh` | Merges `prod` back into `dev` so the branches do not diverge |

The list removes `.claude/`, `.agent/`, `_workflow-source/`, `CLAUDE.md`, `.mcp.json`,
`.skillspector-baseline.yaml` and the other agent files named in `strip-paths.sh`. Everything under
`scripts/` stays: the build calls `scripts/next/env.ts`, and `gates.list` and `quality-gate.sh` name
the checks on every branch. With `.claude/` gone, the hook probes, the AI config check and the
mirror check skip themselves, and the unlock command has no hooks left to open.

Three things that are not obvious, each of which has already cost someone a debugging session:

**One list, sourced — never copied.** When `STRIP_PATHS` was duplicated across scripts, updating one
and not the others made the strip half-land: production kept part of the config and nothing reported
an error.

**Verify both directions.** Checking only that `prod` lost the files misses the failure where `dev`
lost them too. Only the second assertion catches that.

**Merge, never rebase, on the way back.** Rebasing rewrites the strip commit and the branches
diverge permanently.

> **Extra care here.** This pipeline and `changelog.yaml` both push to the production branch. Keep
> their concurrency groups separate (`prod-strip-ai` and `prod-deploy`): one shared group cancels
> a pending strip run without a word. Both pushes rebase and retry, which is what handles the race.

Adopt it in this order:

1. Run `strip-ai.sh` on a throwaway branch and inspect what disappeared.
2. Run `verify-strip.sh` and confirm it fails when you deliberately skip a path.
3. Only then let `strip-ai-on-pr.yml` run on a real merge.

---

## Verify the whole thing

```bash
# The key placeholders (§2): prints nothing once they are filled
grep -n -e '<Project Name>' -e '<generated page>' -e '<app-repo>' -e '<deploy platform>' \
  CLAUDE.md .claude/rules/docs-site/content.md .github/workflows/changelog.yaml \
  _workflow-source/promote.md _workflow-source/promote-deploy.md
/bin/bash scripts/check/hook-probes.sh              # every hook, both ways, under bash 3.2
bash scripts/check/gates.sh                         # the local gate: every line of gates.list
bash .github/scripts/quality-gate.sh origin/dev     # the CI gate
```

Then the test no script performs: open a session and ask the agent to edit a generated page. If it
does, `generatedPaths` (§4) does not name that page — and that is the general remedy whenever a
rule is not holding: move it from prose into a `PreToolUse` hook or a gate step.
