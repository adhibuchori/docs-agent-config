<!-- Agents live in .claude/agents/ — authoritative list: ls .claude/agents/ -->

| Category | Agent             | Validates / Does                                                    |
| -------- | ----------------- | ------------------------------------------------------------------- |
| Custom   | sc-security-guard | CSP/header integrity, secret hygiene, XSS/`dangerouslySetInnerHTML` |
| Custom   | sc-seo-validator  | `app/layout.tsx` metadata, per-page MDX headings, public files      |

Invoke explicitly with the Task tool when reviewing security- or metadata-sensitive changes — these agents are not auto-triggered.
