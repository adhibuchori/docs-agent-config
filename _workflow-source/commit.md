---
description: Run quality gates, inspect staged changes, and generate a conventional commit message.
---

<!-- Command: /commit -->
<!-- Source: _workflow-source/commit.md -->

# /commit — Quality Gate & Commit Message Generator

This workflow ensures all quality gates pass, inspects the staged changes, and generates a conventional commit message.

1. **Quality Gate**: Run format, lint, and type-check first.
   - **Goal**: Both `bun type-check` and `bun fl` must pass (exit code 0).
   - **Action**: If either fails, fix all issues before proceeding. Do not proceed if the state is broken.

2. **Inspect Staged Changes**: `git diff --staged` and `git status`
   - **Goal**: Understand what is being committed — no accidental files (`.env`, generated docs output, etc.).
   - **Protected files** (never commit): `.env*`, `.claude/settings.json`.

3. **Stage Files**: Add relevant files explicitly by name — never use `git add -A` or `git add .`.
   - Example: `git add content/product/getting-started.mdx components/Mermaid.tsx`

4. **Draft Commit Message** following the project convention:

   ```
   type(scope): subject — max 50 characters

   [Optional body explaining context/rationale if needed]
   ```

   - **Types**: `feat` · `fix` · `refactor` · `chore` · `docs` · `style` · `perf`
   - **Scope**: affected area, e.g. `product`, `technical`, `nav`, `layout`, `mermaid`, `scripts`
   - **Subject**: imperative mood, lowercase, no trailing period
   - **Body (Optional)**: separated by a blank line. Use it to explain the "why" and "what" of the change, wrapping lines at 72 characters where possible.
   - Example:

     ```
     docs(product): add onboarding walkthrough page

     Document the new user onboarding flow with step-by-step
     screenshots and links to the related API reference pages.
     ```

Output: The drafted conventional commit message for the user to commit. Do not execute the commit command itself.
