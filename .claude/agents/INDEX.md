<!-- Agents live in .claude/agents/ — authoritative list: ls .claude/agents/ -->

| Category | Agent                   | Validates / Does                                                    |
| -------- | ----------------------- | ------------------------------------------------------------------- |
| Custom   | `agents-security-guard` | CSP/header integrity, secret hygiene, XSS/`dangerouslySetInnerHTML` |
| Custom   | `agents-seo-validator`  | `app/layout.tsx` metadata, per-page MDX headings, public files      |

Invoke explicitly with the Task tool when reviewing security- or metadata-sensitive changes — these agents are not auto-triggered.
