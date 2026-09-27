---
description: Runs the gates, inspects the staged changes, and drafts a conventional commit message for the user to commit. Stages files by name; never commits.
---

<!-- Command: /commit -->
<!-- Source: _workflow-source/commit.md -->

# /commit — Quality Gate & Commit Message Generator

This workflow ensures all quality gates pass, inspects the staged changes, and generates a conventional commit message.

1. **Quality Gate**: run the gates in CLAUDE.md § Quality Gates first.
   - **Command**: `bash scripts/check/gates.sh --fix <your files>`, then `bash scripts/check/gates.sh`.
   - **Goal**: every gate exits 0. The pre-commit hook runs the same list on the staged files.
   - **Timeout**: the full run includes the hook probes, about nine minutes. Give that Bash call the full 600000 ms timeout; the default stops it at two minutes.
   - **Action**: if one fails, fix the cause before proceeding. Do not proceed if the state is broken.

2. **Inspect Staged Changes**: `git diff --staged` and `git status`, read whole (with RTK installed,
   `rtk proxy git diff --staged` and `rtk proxy git status`: its rewrite condenses both)
   - **Goal**: understand what is being committed — no accidental files (a real env file, hand-edited generated pages, etc.).
   - **Never commit**: `.env*` files other than the `.example` templates, and a generated page edited by hand.
   - **`.claude/settings.json`**: only as its own reviewed commit, together with the hooks it wires.

3. **Stage Files**: add the files this change touched by name — `git add -A` and `git add .` belong to `/ship` alone, which runs the guards that make them safe.
   - Example: `git add content/product/getting-started.mdx components/Mermaid.tsx`

4. **Draft Commit Message** following the project convention:

   ```text
   type(scope): subject — max 50 characters

   [Optional body explaining context/rationale if needed]
   ```

   - **Types**: `feat` · `fix` · `refactor` · `chore` · `docs` · `style` · `perf`
   - **Scope**: affected area, e.g. `product`, `technical`, `nav`, `layout`, `mermaid`, `scripts`
   - **Subject**: imperative mood, lowercase, no trailing period
   - **Body (Optional)**: separated by a blank line. Use it to explain the "why" and "what" of the change, wrapping lines at 72 characters where possible.
   - Example:

     ```text
     docs(product): add onboarding walkthrough page

     Document the new user onboarding flow with step-by-step
     screenshots and links to the related API reference pages.
     ```

Output: The drafted conventional commit message for the user to commit. Do not execute the commit command itself. When the user commits a content page or other code, the pre-commit hook runs the same full list, hook probes included.
