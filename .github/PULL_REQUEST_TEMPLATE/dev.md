## Summary

<!-- What changed and why, in 1-3 sentences. Note whether this is manually-authored
     content, or a fix to the generation scripts/workflows themselves — PRs opened by
     the `app-deployed` dispatch bot carry their own body and do not go through this
     template. -->

## How to Verify

<!-- `bun run dev` (or `bun run preview` for the Cloudflare `wrangler dev` preview) and check the affected page(s) render correctly — a successful `bun run build` alone does not confirm the rendered output. -->

## Checklist

`bun fl`, `bun type-check`, and the production build are already enforced
automatically by `quality-gate.yaml` on every PR — not repeated here. This repo has
no test runner and no i18n layer, so neither applies.

- [ ] `_meta.js` updated for any content file added, removed, or renamed under
      `content/` (nav order and titles stay in sync)
- [ ] If this PR changes the doc/changelog generation scripts: re-ran them locally
      and committed the resulting output
- [ ] No dead internal links or broken anchors introduced
