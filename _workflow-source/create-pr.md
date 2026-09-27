---
description: Detects the branch and its commits, drafts a PR title and description, and opens the PR into dev on GitHub once the user confirms the draft.
---

<!-- Command: /create-pr -->
<!-- Source: _workflow-source/create-pr.md -->
<!-- Run when ready to open a new PR -->

# /create-pr — Create Pull Request

## Step 0: Auto-Detect Context

Run the following to gather context automatically:

```bash
git fetch origin dev
git branch --show-current
git log origin/dev..HEAD --oneline
git diff origin/dev...HEAD --stat
```

With RTK installed, run the `git log` and `git diff` lines as `rtk proxy git …`: its rewrite drops
merge commits from `--oneline` and reshapes `--stat`, and the PR body lists both.

The base is `dev` (CLAUDE.md § Branching). On `dev`, `prod` or the default branch, stop: a PR
starts from an `internal/{scope}` branch, and a promotion PR into `prod` is `/promote`'s job. Run
the gates before drafting (`bash scripts/check/gates.sh`); never open a PR from a red gate.

- **Branch name**: infer scope from branch name (e.g., `internal/getting-started` → scope: `getting-started`)
- **Commits**: summarize what was done from the log
- **Diff stat**: understand which files changed

---

## Step 1: Collect Missing Input

Based on what was auto-detected, ask the user for anything still needed (all in one prompt):

- **Ticket ID** (optional) — e.g., `ABC-42`
- **Feature Description** — one sentence describing what this change does (if not clear from commits)
- **Context** (optional) — restructured navigation, new content section, broken-link fixes

---

## Step 2: Generate Draft

Produce a **PR Title** and **PR Description** using the formats below.

**Title Format:**

```text
docs(scope): [TICKET-ID] Integrate {Feature Description In Title Case}
```

- Keep under 70 characters
- Use Title Case for all words after the colon
- Omit `[TICKET-ID]` if none provided

**Description Format (use bold headings with emoji, no ## markdown):**

```text
**📝 Description**
[What content or docs-site problem does this solve?]

**🛠️ Technical Implementation**
[Which content sections, components, or scripts changed. Any nav/structure changes.]

**✅ Testing**
[Steps to verify: build succeeded, links checked, pages render correctly.]

**📋 Checklist**
- [ ] Content review passed (`/review`)
- [ ] Gates pass (`bash scripts/check/gates.sh`); CI re-runs them on this PR
- [ ] Production build succeeds (`bun run build`)
- [ ] No broken internal links
- [ ] `bun run docs:generate` run after any exported component/hook/type change
- [ ] [Any env var or follow-up noted]
```

---

## Step 3: Preview & Confirm

Show the generated title and description in a fenced code block.

Ask: **"Does the title and description look correct? (Yes / No)"**

- **No** → Ask what to change, regenerate, return to Step 3
- **Yes** → Proceed to Step 4

---

## Step 4: Create PR

Run:

```bash
gh pr create --title "<generated title>" --body "<generated description>" --base dev
```

Output the PR URL when done.

Ask: **"PR created successfully. Anything you'd like to change or add?"**
