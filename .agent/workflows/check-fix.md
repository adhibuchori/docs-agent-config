---
description: Write the format, run every gate in scripts/check/gates.list and the build, and fix what fails until all pass.
---

<!-- Command: /check-fix -->
<!-- Source: _workflow-source/check-fix.md -->

# /check-fix — Quality Check & Fix

1. **Format + Lint**: `bun run fl`
   - Writes oxfmt's format, then runs oxlint. Fix each lint finding at its cause: never
     `// oxlint-disable` to make a finding go away.

2. **Every gate**: `bash scripts/check/gates.sh`
   - The list `.husky/pre-commit` runs (`scripts/check/gates.list`): the staged secret scan, type
     check, double assertions, folder shape, dead code, comment style, the AI config and the
     mirrors. It prints each gate's exit code and the tail of every failure. Fix, re-run, repeat
     until every gate passes; `--only <text>` re-runs just the gates whose command contains it.

3. **Build**: `bun run build`
   - Catches what the type check does not: an MDX page that fails to compile, a broken `_meta`
     entry, a route the static export cannot produce.

A changed exported component, hook or type means `bun run docs:generate` before the gates.

Fix at the cause, never by silencing: no skipped gate, no loosened config, no deleted test or page to
make a failure go away. When a fix needs a decision (a rule that is wrong, a gate that should not
apply here), stop and ask instead of choosing.

Output: PASS/FAIL per gate, with what was fixed and what remains.
