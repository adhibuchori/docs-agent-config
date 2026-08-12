<!-- Source of Truth: _workflow-source/ -->
<!-- Sync: bun run workflow:sync (copies these into .claude/commands/ and .agent/workflows/) -->

| Category | Command             | When to Use                         | Example                            |
| -------- | ------------------- | ----------------------------------- | ---------------------------------- |
| Planning | /plan               | Before every content/feature change | /plan add SDK reference section    |
| Quality  | /review             | Before every commit                 | /review                            |
| Safety   | /checkpoint         | Before risky changes                | /checkpoint before nav restructure |
| Session  | /checkpoint-summary | Every 90min / 10 tasks              | /checkpoint-summary docs-sprint    |
| Release  | /create-pr          | Generate + create PR                | /create-pr                         |
| Release  | /resolve-pr-review  | Triage & apply PR review            | /resolve-pr-review 42              |
| Release  | /merge-pr           | Check readiness & merge PR          | /merge-pr 42                       |
| Workflow | /commit             | After work done                     | /commit                            |
| Release  | /promote-dokploy    | Promote with CI down (no PR)        | /promote-dokploy                   |
| Release  | /branch-cleanup     | After a promotion lands             | /branch-cleanup                    |
| Session  | /learn-session      | Capture durable learnings           | /learn-session                     |
| Release  | /promote            | Promote internal → dev → prod       | /promote                           |
