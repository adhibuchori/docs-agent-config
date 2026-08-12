---
description: Fetch PR review comments from a GitHub PR, triage interactively, and resolve accepted suggestions against project conventions.
---

<!-- Command: /resolve-pr-review -->
<!-- Source: _workflow-source/resolve-pr-review.md -->
<!-- Run after a PR has been reviewed to triage and apply fixes -->

# /resolve-pr-review — PR Review Resolver

## Step 1: Collect PR Input

Ask the user for:

- **PR URL or PR Number** — e.g., `https://github.com/owner/repo/pull/42` or just `42`
- **Reviewer** (optional) — filter by a specific reviewer username or bot (e.g., `gemini-code-assist`, `copilot`, or a GitHub username). Leave blank to include all reviewers.

If the user provides only a number, also ask:

- **Repository** — `owner/repo` format

---

## Step 2: Fetch PR Review Comments via `gh` CLI

```bash
# Fetch PR metadata
gh pr view {PR_NUMBER} --repo {OWNER/REPO} \
  --json title,url,headRefName,additions,deletions,changedFiles
```

```bash
# Fetch inline review comments (code suggestions)
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments --paginate \
  --jq '[.[] | {id: .id, user: .user.login, file: .path, line: .line, body: .body, created_at: .created_at}]' \
  > /tmp/pr_inline_comments.json
```

```bash
# Fetch PR-level review comments (summary reviews)
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews --paginate \
  --jq '[.[] | {id: .id, user: .user.login, state: .state, body: .body, submitted_at: .submitted_at}]' \
  > /tmp/pr_reviews.json
```

If **reviewer** was specified, filter both files to only include comments from that username.

Parse each suggestion and extract:

- `file` — file path and line number (inline comments only)
- `reviewer` — who left the comment
- `type` — infer from keywords: `content`, `link`, `structure`, `build`, `accessibility`, `style`, `other`
- `summary` — first 1–2 sentences
- `detail` — full comment body

If **no review comments found**, inform the user and exit.

---

## Step 3: Validate Against Project Rules

Before presenting suggestions to the user, cross-check each suggestion against **CLAUDE.md** and `.claude/rules/`:

- If a suggestion **contradicts** a documented rule, flag it as `⚠ Conflicts with CLAUDE.md` and recommend dismissing it.
- If a suggestion **aligns** with a documented rule, flag it as `✓ Aligns with CLAUDE.md`.
- If unclear, mark as `—`.

---

## Step 4: Triage Table

Show a summary table of all suggestions found:

| ID  | File:Line     | Reviewer   | Type   | Rule Alignment | Summary   |
| :-- | :------------ | :--------- | :----- | :------------- | :-------- |
| 1   | {file}:{line} | {reviewer} | {type} | {✓ / ⚠ / —}    | {summary} |

Ask: **"Which suggestions would you like to apply? (e.g., 'All', '1, 3, 5', or 'None')"**

- **All** → Include all in the plan.
- **Specific IDs** → Include only those selected.
- **None** → Exit.

For selected suggestions, ask if there are any **custom notes** or specific approaches before generating the plan.

---

## Step 5: Prioritize

Group accepted suggestions by priority:

| Priority    | Types                                   |
| :---------- | :-------------------------------------- |
| 🔴 Critical | `broken-link`, `build-breaking`         |
| 🟠 High     | `content accuracy`, `accessibility`     |
| 🟡 Medium   | `structure`, `style`, `maintainability` |
| 🔵 Low      | Minor improvements, `other`             |

---

## Step 6: Generate Fix Plan

Output a structured plan following the `/plan` format:

```markdown
# PR Fix Plan: {PR Title}

**PR**: {PR URL}
**Branch**: {headRefName}
**Date**: {today}
**Changes**: +{additions} / -{deletions} across {changedFiles} files

## SCOPE

- Files to modify: [list unique files from accepted suggestions]

## TASKS

- [ ] [TAG] [verb] [File:Line] — {summary}
      [repeat for all accepted suggestions]

## RISKS

[flag only risks that could block execution]

## CONFIRMATION

[questions that need user answers before starting fixes]
```

---

## Step 7: Execute & Verify

Once the user approves the plan:

1. Apply fixes one by one, ordered by priority (Critical first).
2. After all fixes: run `bun fl && bun type-check` — both must pass.
3. Ask: **"All fixes have been applied. Would you like me to post a summary to the GitHub PR as a comment?"**
   - **Yes** →
     ```bash
     gh pr comment {PR_NUMBER} --repo {OWNER/REPO} \
       --body "{markdown summary: fixes applied, rules referenced, quality gate status}"
     ```
   - **No** → Done.
