## Promotion: dev → prod

<!-- Filled in from `git log origin/prod..origin/dev` — do not hand-edit the commit
     list without re-checking it against that range. -->

### Commits Being Promoted

<!-- List each commit: short SHA — subject line. -->

`quality-gate.yaml` re-runs the full gate on this PR. That gate is the list; nothing it decides
is repeated here.

### Local Merge Verification

- [ ] Ran `git merge --no-commit --no-ff origin/dev` locally against `prod` before
      opening this PR
- Result: <!-- clean / conflicts found and how resolved / not run -->

## Expected Diff Noise

This PR's diff will look far larger than the commit list above — `strip-ai-on-pr.yml`
removes `.claude/`, `.agent/`, `AGENTS.md`, `CLAUDE.md`, `SSOT.md`, and related AI
config from `prod` on every merge, so those files reappear as "new" on every single
promotion. This is expected noise, not a sign of scope creep — do not treat a large
file count as a red flag on its own.

## Post-Merge Checks

<!-- Delete the lines below that do not apply to this promotion before submitting. -->

- [ ] `strip-ai-on-pr.yml` and `changelog.yaml` both ran for this merge. A head commit carrying
      the skip-CI marker starts neither, and nothing reports their absence
- [ ] Production deployment succeeded — the Worker's newest deployment is dated after the merge
- [ ] The live site reflects the new content, checked on the pages that changed
- [ ] If this promotion carries a changelog revision: the generated page is live as well
