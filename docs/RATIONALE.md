# Rationale

Why the odd-looking parts of this configuration are shaped the way they are.

Every entry below guards against a failure that is slow to diagnose. Several look like clutter and
are load bearing. This file exists so you can tell which is which before you tidy anything.

**One rule while reading: if a pattern here looks needlessly complicated, do not simplify it.**
Each one is followed by what breaks when you do.

| § | Decision | Section |
| --: | :-- | :-- |
| 1 | A rule scopes itself with `paths:` | [Rules](#1-a-rule-scopes-itself-with-paths-and-any-other-key-loads-it-everywhere) |
| 2 | Only a `PreToolUse` exit 2 blocks | [Hooks](#2-pretooluse-blocks-everything-else-only-complains) |
| 3 | The mirror check has a `--check` mode | [Commands](#3---check-mode-and-why-write-mode-cannot-replace-it) |
| 4 | Installer-owned files are exempt from the drift check | [Commands](#4-third-party-installers-leave-legitimate-orphans) |
| 5 | The review bot never checks out the pull request | [CI](#5-the-review-bot-runs-on-pull_request-and-never-checks-out-the-pull-request) |
| 6 | The strip uses one list, checks both branches, merges back | [CI](#6-the-strip-pipeline-one-list-both-directions-merge-not-rebase) |
| 7 | No skip-CI marker on a commit that reaches `dev` | [CI](#7-the-skip-ci-marker-that-disarms-gates-silently) |
| 8 | Gates differ by repository role on purpose | [CI](#8-ci-script-divergence-between-repos-is-usually-correct) |
| 9 | Gitignored files are invisible to symbol search | [Tooling](#9-gitignored-files-are-invisible-to-symbol-search) |
| 10 | Escape hostile MDX at render time | [Content](#10-text-that-is-hostile-to-the-mdx-build) |
| 11 | The changelog has its own concurrency group | [CI](#11-the-changelog-workflow-its-own-concurrency-group-and-a-marker-that-must-not-spread) |
| 12 | State intentional absences | [Docs](#12-state-intentional-absences-explicitly) |
| 13 | Count file-presence claims | [Docs](#13-count-file-presence-claims-do-not-infer-them) |
| 14 | The always-loaded context has a byte budget | [Rules](#14-the-always-loaded-context-has-a-byte-budget) |
| 15 | The safety hook parses commands, and probes prove it | [Hooks](#15-the-safety-hook-parses-a-command-and-the-probes-prove-every-rule) |
| 16 | SkillSpector scans the files an agent obeys | [Gate](#16-skillspector-scans-the-files-an-agent-obeys) |
| 17 | Merge commits, never squash | [Git](#17-merge-commits-never-squash) |
| 18 | The deploy target lives in one workflow | [Deploy](#18-the-deploy-target-lives-in-one-workflow) |
| 19 | CI starts only from pull-request events | [CI](#19-ci-starts-only-from-pull-request-events) |
| 20 | Secrets and production writes open only for the user | [Unlock](#20-secrets-and-production-writes-open-only-for-the-user-and-only-for-minutes) |
| 21 | MCP permissions live in `settings.json` | [Tooling](#21-mcp-tools-are-allowed-in-settingsjson-and-alwaysallow-is-read-by-nothing) |

---

## 1. A rule scopes itself with `paths:`, and any other key loads it everywhere

A rule under `.claude/rules/` that matters only for some files opens with a `paths:` list, and loads
only once Claude reads a file that matches:

```yaml
---
paths:
  - 'content/**'
  - 'scripts/generate/**'
---
```

`paths` is the only frontmatter field Claude Code reads from a rule. It takes a YAML list or one
comma-separated string. Every other key is ignored without an error, and so is frontmatter that does
not parse. Either way the rule has no `paths`, so it loads in **every** session. A rule written with
another tool's `globs:` key looks scoped, works, and quietly spends its full size on every prompt.

Quote each pattern. A bare leading `*` starts a YAML alias, the frontmatter stops parsing, and the
rule is loaded everywhere again.

Only `.claude/rules/common/working-agreements.md` loads unscoped on purpose. A mis-keyed rule shows
up in one place only: the always-loaded byte count that §14 holds to a budget. This is the
archetype for the whole file: the failure is silent, and silence reads as success.

---

## 2. `PreToolUse` blocks; everything else only complains

The single most important thing to understand about hooks. What an exit code 2 does depends on the
event:

| Event | Exit 2 | Here |
| --- | --- | --- |
| `PreToolUse` | **The tool call does not happen**, and stderr is the reason Claude reads | the four guards |
| `PostToolUse` | Nothing is stopped: the tool already ran. Claude sees stderr | `post-edit.sh`, `post-commit.sh` |
| `UserPromptSubmit` | The prompt is blocked **and erased** | `prompt-intent.sh`, which ends in `\|\| true` so it never does |
| `Stop` | Claude keeps working instead of stopping | none ships |

Every other exit code, `1` included, lets a `PreToolUse` call through, and so do a crash and a
timeout. So a rule that must not be violated belongs in `PreToolUse`, and it must exit 2. Put it in
`PostToolUse`, or exit 1, and you get a guard that appears installed, logs complaints, and prevents
nothing. Each guard here says whether it refuses or lets through when python3 or jq is missing or
broken (`.claude/hooks/README.md` § Fail modes).

A hook reads the tool call as JSON on stdin. No `CLAUDE_TOOL_INPUT_*` variable exists, so a hook
that reads one sees an empty string on every call, matches nothing, and passes everything.
`scripts/check/ai-config.sh` fails on any hook that reads one.

**Corollary: test a guard by triggering it.** A guard whose path pattern does not match your
directory layout never fires and never complains. Reading the script tells you what it intends;
only triggering it tells you what it matches. `bash scripts/check/hook-probes.sh` triggers every
hook here, both ways, the way Claude Code calls it (§15).

**Hooks on one event run in parallel.** Two `PostToolUse` hooks that both touch the file just
written, one formatting it and one linting it, race: the linter can read the file before the
formatter has finished with it, and report what the formatter was about to fix. So formatting and
linting share one script, `post-edit.sh`, which runs them in order. Split them and the race comes
back without a sound.

---

## 3. `--check` mode, and why write mode cannot replace it

Mirror scripts run in two modes. Only one detects drift:

```bash
bash scripts/sync/workflows.sh           # write
bash scripts/sync/workflows.sh --check   # verify — this is the CI mode
```

A write-mode run **overwrites staleness before it can observe it**. Run it in CI and the mirrors
are always in sync, because the check just fixed them, and an unlisted command can stay unlisted
indefinitely.

`--check` writes nothing and fails on each of these, and a checker that skips any one of them misses
real drift:

1. A mirror file that is missing, or no longer matches its source.
2. An **orphan**: a mirror file with no source. This is the direction naive checkers forget. An
   `INDEX.md` in `.agent/workflows/` counts as one, because nothing maintains it there.
3. `INDEX.md` drift, verified **both ways**: every command has a row, and every row names a real
   command.
4. A missing `INDEX.md`.

Files a third-party installer owns are exempt from 2 and 3; see §4.

---

## 4. Third-party installers leave legitimate orphans

A design or framework skill installed by its own tooling writes into `.claude/skills/` or
`.agents/skills/`, and can drop a command shim into `.claude/commands/`, with **no counterpart** in
your source directory, by design. The installer owns their versioning.

A naive drift checker flags these as orphans and advises deleting them or moving them into the
source directory. Both suggestions break the next upgrade.

Hence the `VENDORED` list in `scripts/sync/workflows.sh`: paths, relative to a mirror, that the
orphan and `INDEX.md` checks skip. It ships empty, because this repository installs nothing that
way. Add a path when an installer drops one, not after the check files its first false report.

---

## 5. The review bot runs on `pull_request`, and never checks out the pull request

The AI review workflow used to run under `pull_request_target`, so it could comment on fork pull
requests. That trigger runs the workflow from the base branch with every repository secret in
scope, and it is the pattern behind most leaked Actions secrets: one `actions/checkout` of the
pull request's code later, anyone who opens a pull request runs code next to your tokens. GitHub's
default Actions event policy turns the trigger off in public repositories: it is in evaluate mode
now, and GitHub enforces it from 2 November 2026.

It runs on `pull_request` instead. Pull requests in the normal flow come from branches of this
repository, so the secret is there, and whoever can push such a branch already has write access.
A fork's pull request gets no secret, and the job skips it rather than failing. A second trigger,
`issue_comment`, re-runs the review on a `/ask-deepseek` comment from someone with write access.
That path does run with the secret, on any pull request, which is why the rule outlives the
trigger change: **the workflow never checks out the pull request's code.** It reads the diff
through the API.

Two smaller decisions in the same workflow, both deliberate:

- **No `synchronize` in the trigger types.** The action posts no sticky comment, so every push
  would add another review.
- **Base branch only, not the promotion branch.** A `dev → prod` diff re-adds the entire AI config
  that the strip pipeline removed, and the provider rejects a diff that size.

---

## 6. The strip pipeline: one list, both directions, merge not rebase

Three rules, each against a failure the strip is prone to.

**One list, sourced — never copied.** `STRIP_PATHS` lives in `strip-paths.sh`; the other three
scripts source it. Duplicated, one updated copy beside a stale one makes the strip half-land:
production keeps part of the config, and nothing reports an error.

**Verify both directions.** Asserting that `prod` lost the files misses the failure where `dev`
lost them too. Only the second assertion catches that, and it is the one people leave out.

**Merge, never rebase, on the back-merge.** Rebasing rewrites the strip commit, and the branches
diverge permanently.

One more: `git rm --cached` leaves the files present but untracked, which blocks a subsequent
rebase for reasons that look unrelated to the strip.

---

## 7. The skip-CI marker that disarms gates silently

GitHub's skip-CI marker matches anywhere in a commit message, and on the head commit of a pull
request it stops every workflow that pull request would start. A workflow that stamps the marker on
a commit it pushes to the development branch therefore prevents nothing there, and disarms the
quality gate on **every** promotion opened from that commit.

Nothing here runs on a push any more (§19), so nothing writes the marker, on either side: not the
workflows, not the strip scripts, and not `/promote-deploy`, the fallback for when CI cannot run,
whose pushes start no run to skip. On the head commit of a pull request it would still silence
every workflow for that pull request, the merged-PR ones included: the strip, the changelog and the
deploy.

**A pull request with no checks at all is not a slow queue.** Three causes, all of which report as
"pending" rather than as a failure, so they survive indefinitely:

1. A skip-CI marker on the head commit.
2. A conflicting pull request — the provider builds a merge commit to run `pull_request`
   workflows; a conflict means no merge commit, so nothing starts.
3. A gate whose trigger omits the review branch. `branches: [prod]` alone lets everything reach the
   development branch ungated.

Check `mergeable` and the head commit's message before concluding CI is slow.

The marker does not need to be placed on purpose to do this. Text that merely describes it, in a
commit body that a squash merge folds into `dev`'s head commit, silences the next promotion pull
request (§17): `.claude/anti-patterns/commit-message-skip-ci-substring.md`.

---

## 8. CI script divergence between repos is usually correct

If you run this layer in more than one repository, their quality gates will differ, and the tempting
conclusion is that they have drifted and should be unified.

Check what the variance tracks first. If the gates cluster by **repository role** — applications,
services, documentation sites, each with a consistent shape — that is not drift.
Documentation repositories do not need the same checks as applications; a backend does not need
translation-key parity.

Unifying that deletes legitimate checks. Divergence by role is the correct design; the useful thing
to hunt for is divergence **within** a role.

---

## 9. Gitignored files are invisible to symbol search

`changelog.yaml` checks the application repository out into `app-source/` for `docs:generate` to
read, and `.gitignore` lists that folder. Check it out there locally too and Serena, which respects
`.gitignore`, never sees it: a search for a function the generator documents returns nothing, even
though the code is on disk.

This is the one case where an empty result does not mean "absent from the scope you searched" — the
files are filtered out before the search rather than rejected by it.

Search the application repository in a session opened there, or read the generated page. Turning off
the gitignore filter is not the fix: it also exposes every `.env` file to symbol search and file
reads.

---

## 10. Text that is hostile to the MDX build

The defining hazard of a generated documentation site.

If you generate pages from source comments, two classes of **perfectly correct source text** will
break the build. Neither is a bug in the source, which is what makes them surprising.

**Multi-line destructured parameters inside a table cell.** The newline ends the inline-code span,
leaving an unbalanced `{` that the parser reads as a JSX expression:

```ts
/** @param {{ id, name,
              email }} user */
```

Collapse whitespace and escape `|`, `<`, and `>` before the value reaches a cell.

**Element names in prose.** A comment describing `<Foo>` parses as an unclosed JSX tag. Escape `<`
before tag-shaped text.

**Solve both at render time, not write time.** The obvious alternative — a brace-balance heuristic
that rejects hostile source before it is committed — gives false positives on multi-line balanced
expressions. A detector that cries wolf gets disabled, which is strictly worse than not having one.

---

## 11. The changelog workflow: its own concurrency group, and a marker that must not spread

Two decisions in `changelog.yaml`, both of which look like cruft and are not.

**Its concurrency group is not the strip pipeline's.** Both workflows push to the production
branch, so one shared group looks like the way to keep them from racing. It drops runs instead.
A concurrency group holds one running and one pending run, and a newly queued run cancels the one
already pending, whatever `cancel-in-progress` says. With both workflows in one group, a strip run
waiting behind a changelog run is cancelled as soon as another run queues, and nothing reports it.

So `changelog.yaml` uses `prod-deploy` and `strip-ai-on-pr.yml` uses `prod-strip-ai`, and the race
is handled where it happens: each push rebases onto the production branch and retries. Neither
group sets `cancel-in-progress`, because a cancelled run loses a content revision or a strip for
good.

**No skip-CI marker on either commit.** The workflow starts on a merged pull request into
production or on a dispatch from the application repository, never on a push, so its own commits
cannot retrigger it and a marker would prevent nothing. On the development-side commit it would
silently disarm the quality gate on **every** promotion opened from that commit, and skip the
strip and the deploy when that promotion merges.

That second one is the more dangerous, because of how it presents. See §7.

---

## 12. State intentional absences explicitly

If an architectural layer does not exist yet, the contract document should say so in as many words:

```markdown
The service hook layer does not exist yet. All data fetching currently goes through the client.
This is deliberate and planned, not drift.
```

Without that sentence, the next audit reports it as a finding, and someone spends an afternoon
re-deriving that it was intentional.

**Every deliberate absence is worth one sentence in the contract.** This is the cheapest rule in
the file and the one most often skipped.

This repository is itself the largest example. It has no `AGENTS.md` and no `SSOT.md`, and
`CLAUDE.md` says so in its second paragraph rather than leaving it to be noticed. Without that
sentence, the first person to compare this layer against the frontend one files it as a gap and
starts writing an empty rulebook — which agents then cite.

---

## 13. Count file-presence claims; do not infer them

A claim of the form "file X does not exist in repo Y" must be **counted**, not assumed.

A presence claim is cheap to make and easy to get wrong: the directory you expect may exist after
all, and one that differs may have been written by a skill installer rather than by any
architectural decision. Only a count tells them apart.

Auditing file presence is far cheaper than auditing intent, and it is the kind of claim that gets
repeated once written down. Run the `ls`. The file and component counts in the template's README
come from `git ls-files`, for the same reason.

---

## 14. The always-loaded context has a byte budget

Everything Claude reads at the start of every session costs context on every prompt, before any
work starts: `CLAUDE.md`, every file it imports, and every rule without `paths:` (§1). Nothing
reports that cost. A rulebook grows a line at a time, each line looks cheap, and the agent ends up
reading instructions for code it is not touching while the ones that matter get diluted.

So `scripts/check/ai-config.sh` holds that set to **15,000 bytes** and fails the gate above it. Here
it is 11,565 bytes: `CLAUDE.md` and `working-agreements.md`. Two consequences shape the files:

- **No `@` imports in `CLAUDE.md`.** An import loads the whole file at launch, so it moves bytes into
  every session while looking like a pointer. The check refuses one anywhere in the file, comments
  included, rather than guess where Claude Code expands them. `CLAUDE.md` ends in an **On-demand
  References** table instead: a file per row, read only when its row matches the task.
- **Knowledge that loads rarely lives in files that load rarely.** The review checklist is read by
  `/review`, the anti-patterns by their trigger keywords, the rarely used MCP servers by
  `claude --mcp-config` (§18). The four `.claude/*.example.md` references load only when a task
  names them.

Raising the budget is a legitimate change. Doing it to fit a rule that could have been scoped is not.

---

## 15. The safety hook parses a command, and the probes prove every rule

A guard that matches substrings fails both ways. It refuses harmless commands that merely mention a
dangerous word, and it misses the dangerous ones written differently: `git -C . push`,
`cd sub && git push`, a push inside `bash -c`, a branch name in a variable, a command piped into
`sh`. An agent that meets a false refusal learns to rephrase, and rephrasing is exactly what walks
past a substring match.

So `lib.sh` reads a command the way a shell does: quotes, heredocs, `$( )`, backticks, `bash -c`,
`eval`, aliases, loop variables, exported variables and text piped into a shell, then judges each
command it finds. It peels wrappers (`env`, `sudo`, `timeout`, `nohup`, `xargs`, ...) and package
runners (`npx`, `bunx`, `npm`/`pnpm`/`yarn`/`bun` `exec` and `dlx`) the same way, so a rule holds
whatever runs the command. The permission rules in `.claude/settings.json` overlap with it on
purpose: a permission rule matches a command's prefix, the hook reads the whole command line, and
neither alone covers the other.

What it refuses falls into a few categories, each listed rule by rule in `.claude/hooks/README.md`:
recursive deletes of protected paths; commands that wipe uncommitted work; skipping the pre-commit
gate; a push to, or the deletion of, a protected branch; any shell read or write of a real `.env*`
file; the unlock, from the agent, and changes to `scripts/env/` or the unlock script; a shell
change to the other guards (the hooks, the probes, the settings that turn them on); and git
settings that change what git runs, which config it loads, where it connects or where it works (an
alias, an include, a command, a credential helper, a proxy, `url.*.insteadOf`, ...), whatever their
value and however they are set.

A parser is also more code that can fail, so each failure is decided in advance. A guard refuses
when its payload is not JSON, when python3 crashes, and when the analyzer runs past its time limit.
Only a machine with no python3 at all falls back to a few plain-text rules, and everything those
rules miss then runs unchecked: install python3.

**What the analyzer cannot resolve, it refuses.** A text check can be walked past by a command that
builds its real target at run time, so those shapes are refused whether or not a `.env*` name or
the unlock appears in plain text: `eval` and sourced or decoded text; code a shell or interpreter
reads from stdin out of output the hook cannot read (`curl … | bash`); a command git or a pager
runs from a setting or variable (`-c core.pager=`, `GIT_PAGER`, `EDITOR`); `$( )` or `<( )` as the
command name or as the file a reader or writer opens; a path built through `IFS`, `dotglob`, an
array or `printf`; a package runner whose command or shell text is built from `$( )` or an unknown
variable, or a recipe `make`, `just` or `task` reads from stdin; inline code that opens or builds a
path; a copy, link or archive landing on `.claude/state/` or a `.env*` file; and `xargs` feeding a
file reader. Each refusal names the reason and says to run the command yourself with `!` if it is
intended; `!` runs it as you, with your own access, outside the hooks and (in an ordinary session)
outside the sandbox. One narrow case stays open because everyday work needs it:
`cat $(git ls-files '*.md')`, a literal `git ls-files` or `git diff --name-only` whose pathspecs
cannot match `.env*`. Over-refusal is the trade: a refused harmless command costs one `!`, a guessed
one can cost a secret.

None of that is worth anything unproven. `bash scripts/check/hook-probes.sh` feeds every hook the
JSON Claude Code sends, in throwaway fixtures, and checks both what it must refuse and what it must
let through. It covers every row of the rule table, a linked git worktree, every cell of the
fail-mode table, and each hook's configuration keys: 2,365 probes here, under macOS `/bin/bash` 3.2
in about nine minutes. The gate list runs it whenever a hook, `settings.json`, the probes, the
unlock script or `scripts/env/` change, and CI runs it on every pull request. Add a rule with one
probe it must stop and one it must allow, then disable the rule and watch the probe fail, so the
probe is known to be load-bearing.

It is still a text check. A script the agent writes and then runs is executed, not read; a program
the hooks do not know that runs commands of its own (`watch`, `script`, `flock`, `parallel`) is
judged by name only; and an application that loads `.env` itself sees the values, as it must.
`docs/unlock.md` § What the lock does not stop lists those limits. Below the hooks,
`.claude/settings.json` turns on Claude Code's Bash sandbox by default. At the operating-system
level it stops every sandboxed command and its children from reading `.env*` files or the `.env`
backups and from writing under `.claude/state/unlock/` or `.claude/hooks/` or to
`scripts/ops/unlock.sh`, so it holds where a text check cannot. It
runs on macOS, and on Linux or WSL2 with `bubblewrap` and `socat`; not on WSL1 or native Windows.
Where it cannot start, Claude Code warns and runs commands without it (unless
`sandbox.failIfUnavailable` is `true`), and the hooks still apply. A command that fails inside it
can be retried outside through Claude Code's permission prompt, which
`sandbox.allowUnsandboxedCommands: false` forbids. Turn it off with `"sandbox": {"enabled": false}`
in `.claude/settings.json` or `.claude/settings.local.json`; the hooks keep running.

---

## 16. SkillSpector scans the files an agent obeys

A slash command, a subagent, a skill and a hook are instructions that run with your permissions.
Text hidden in one of them (an instruction in an HTML comment, a command that sends a file
somewhere, a line that tells the agent to skip a check) acts with every tool the agent has, and a
diff review reads past it because the file looks like documentation.

`scripts/check/skills.sh` runs NVIDIA's SkillSpector over `_workflow-source/`, `.claude/agents/`,
`.claude/hooks/` and any skills folder: on the staged ones before each commit, on the changed ones in
CI. It is pinned to one release, and it runs in static mode unless you ask for more, because the LLM
mode sends the full text of every scanned file to a provider. A finding of medium severity or above
fails the gate until someone triages it in `.skillspector-baseline.yaml`, one entry per finding with
a reason. A file the scanner could inspect only in part fails too, unless the baseline names that
exact file and the reason code.

Prefer rewording to suppressing. This template's hooks and commands pass with no suppression rule
at all, because each finding the scanner raised was fixed in the text. One consequence is visible
in every command: it carries its three header comments and no other HTML comment, since a comment
that contains words such as "ignore" or "system" reads as a hidden instruction.

---

## 17. Merge commits, never squash

Every pull request here merges with `--merge`, and the repository settings turn squash merging off
(**Settings → General → Pull Requests**). Rebase merging goes with it, because it rewrites every
commit the same way.

- **A merge commit keeps every commit and its own date.** A squash folds the branch into one commit
  dated the merge day, so `git log` and `git blame` stop saying when a change was made.
- **A squashed branch never looks merged.** Its commits are not ancestors of `dev`, so it stays
  "ahead" forever and `/branch-cleanup` can never prove it is safe to delete.
- **A squash concatenates commit bodies.** Text that describes the skip-CI marker in one commit body
  becomes part of `dev`'s head commit, and the next promotion pull request runs nothing (§7).

---

## 18. The deploy target lives in one workflow

A docs site built with `output: 'export'` is a folder of static files, so `ci-cd.yaml` uploads it to
an assets-only Cloudflare Worker: no server, no container, no image registry. It is the one workflow
that deploys, and `changelog.yaml` only calls it.

The commands are written against a neutral deploy. `/promote` and `/promote-deploy` describe the
steps (the gate, the push, the verification by timestamp) and leave the host to you. The MCP servers
for a deploy platform and a VPS provider ship as placeholders in `.claude/mcp/`, next to a Cloudflare
example, and each loads for one session with `claude --mcp-config` rather than spending context in
every session. An agent told
about a platform the project does not use follows instructions for tools that are not there, and a
rule that names a vendor is wrong the day the project moves.

So deploying elsewhere means replacing `ci-cd.yaml` and deleting what only a Worker needs:
`wrangler.example.jsonc`, the two Cloudflare secrets, `.claude/mcp/cloudflare.example.json`, and
the Worker checks in `.claude/rules/docs-site/content.md`, the review checklist and
`agents-security-guard`.
The gate, the hooks and the commands do not change.

---

## 19. CI starts only from pull-request events

No workflow here starts on a push, on a timer or by hand, and no bot opens update pull requests. The
allowed triggers are `pull_request` (including the closed-and-merged one, with a job condition that
checks `merged`), `issue_comment`, `repository_dispatch` and `workflow_call`.

- **A push trigger repeats work.** Every change reaches `dev` and `prod` through a pull request, and
  the gate already ran on it. The merged pull request into `prod` fires at the same moment the push
  did, so the strip, the changelog and the deploy follow it instead.
- **A timer runs where nobody is looking.** A scheduled scan or an update bot spends runner minutes
  and opens pull requests on its own clock. Here updates happen when a person decides:
  `pinact run -u --min-age 7` for the actions (the minimum age is a cooldown against a freshly
  compromised release) and the package manager's update command, each in a normal pull request.
- **What covers the gap** runs on the pull request: `dependency-review.yml` fails a new or bumped
  dependency with a known high or critical vulnerability, `codeql.yml` scans the code, and
  `workflows-lint.yml` lints any change under `.github/`.
- **Hardened by default.** Every `uses:` is pinned to a full commit SHA with its release in a
  comment, and Bun and Wrangler to exact releases. Every workflow starts with
  `permissions: contents: read`, no checkout keeps its token (the two jobs that push hand git one
  through a credential helper in the steps that fetch and push, never in `.git/config`), secrets
  are passed by name, and no `${{ }}` of event data appears inside a `run:` block.

This departs from common supply-chain guidance on purpose. OpenSSF Scorecard's
`Dependency-Update-Tool` check scores zero without an update bot, and no CodeQL analysis runs on the
default branch itself, so GitHub has no baseline for which alerts a pull request introduced.

---

## 20. Secrets and production writes open only for the user, and only for minutes

The obvious way to let an agent touch `.env` is a phrase: the user writes "I allow it" and the hook
lets the next command through. That phrase can come from anywhere the agent reads: a web page, an
issue, a file in the repository, the agent's own summary of an earlier turn. So **no hook reads the
prompt for permission.**

The lock is a file instead. `scripts/ops/unlock.sh env` writes `.claude/state/unlock/env` holding
the time the unlock ends: 20 minutes by default for `.env*` changes, 15 for production SQL writes,
240 at most. The user runs it with `!`, which runs the command as the user, outside the hooks and
the sandbox. From inside a session the hooks refuse every route to that file they can read: running
the script or its package alias, writing, linking, copying or deleting anything under
`.claude/state/unlock/`; the sandbox refuses any write there too. Every reader checks the file the
same strict way (owned by the user, private, not a link, not tracked, not expired), and the probes
check that they agree.

While `env` is locked the agent still works. `scripts/env/show.sh` lists every key with secrets
masked to four characters and a length, and reports keys missing against the `.env.<target>.example`
template. `scripts/env/set.sh` changes one key from stdin while `env` is open, backs the file up and
logs only the key name. Reads of the production database always pass; `db-guard.sh` holds anything
else until `db` is open, and the production server starts read-only so the lock has a layer below it.

The expiry is the point. An unlock that closes itself cannot be forgotten open. The limits are the
same as §15: the hooks are a guardrail, the Bash sandbox in `settings.json` is the operating-system
layer below them, and `docs/unlock.md` says what neither stops.

---

## 21. MCP tools are allowed in `settings.json`, and `alwaysAllow` is read by nothing

An `alwaysAllow` list in `.mcp.json` looks like approval for a server's tools. It belongs to other
MCP clients: Claude Code never reads it, so the tools it names still prompt, and a reader of the
file believes something is approved that is not. Claude Code takes MCP permissions from
`.claude/settings.json`, the same `allow`, `ask` and `deny` lists as every other tool, so that is
where a server's read tools go when their prompts get in the way.

The editing tools stay on the prompt, and for `.env*` files the prompt is the whole guard. The
`Read(.env*)` and `Edit(.env*)` deny rules apply to Claude Code's own file tools. The hooks read
shell commands and the paths of the built-in edits; the one `PreToolUse` hook on Serena's write
tools, `generated-guard.sh`, looks only for generated pages. A Serena edit of `.env.production` or
of a file in `.claude/state/` therefore reaches the user as a permission prompt and nothing else.
Answer no, and never add those tools to `allow`.
