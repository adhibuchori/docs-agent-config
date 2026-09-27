<!-- Source of Truth: _workflow-source/ -->
<!-- Sync: bash scripts/sync/workflows.sh (copies these into .claude/commands/ and .agent/workflows/) -->

In the order work flows: plan, build, review, commit, pull request, release.

| Stage        | Command             | When to Use                                    | Example                            |
| ------------ | ------------------- | ---------------------------------------------- | ---------------------------------- |
| Plan         | /plan               | Before every content or feature change         | /plan add SDK reference section    |
| Build        | /rca                | A bug: reproduce it, then fix it               | /rca broken anchor on SDK page     |
| Build        | /checkpoint         | Before a risky change                          | /checkpoint before nav restructure |
| Build        | /check-fix          | A gate is red: fix at the cause and re-run     | /check-fix                         |
| Review       | /review             | Before every commit                            | /review                            |
| Commit       | /commit             | After the work is done; you commit             | /commit                            |
| Commit       | /ship               | Review, fix, commit and push the work branch   | /ship                              |
| Pull request | /create-pr          | Draft and open the pull request into dev       | /create-pr                         |
| Pull request | /resolve-pr-review  | Triage and apply review comments               | /resolve-pr-review 42              |
| Pull request | /merge-pr           | Check readiness, then merge                    | /merge-pr 42                       |
| Release      | /promote            | Promote internal → dev → prod through PRs      | /promote                           |
| Release      | /promote-deploy     | Promote with CI down, without PRs              | /promote-deploy                    |
| Release      | /branch-cleanup     | After a promotion lands                        | /branch-cleanup                    |
| Session      | /checkpoint-summary | A handover, every 90 minutes or 10 tasks       | /checkpoint-summary docs-sprint    |
| Session      | /learn-session      | Capture durable learnings                      | /learn-session                     |
