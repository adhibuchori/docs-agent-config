<!-- Agents live in .claude/agents/ — authoritative list: ls .claude/agents/ -->

| Category | Agent                   | Validates / Does                                                                        |
| -------- | ----------------------- | --------------------------------------------------------------------------------------- |
| Custom   | `agents-security-guard` | Headers and CSP, secrets in the static export, raw HTML and XSS, the Worker's addresses |
| Custom   | `agents-seo-validator`  | `app/layout.tsx` metadata, per-page MDX headings, favicon, robots and sitemap files     |

Invoke explicitly, by name, when reviewing security- or metadata-sensitive changes — these agents are
not auto-triggered, and both only report.
