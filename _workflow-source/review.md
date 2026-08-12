---
description: Content-quality, broken-link, build-success, accessibility, and doc-structure review for a static Nextra documentation site.
---

<!-- Command: /review -->
<!-- Source: _workflow-source/review.md -->
<!-- Run before every commit -->

# /review — Docs Review Workflow

Review covering content quality, link integrity, production build success, accessibility, and documentation structure. This repo is a static Nextra/MDX docs site with no backend, no auth, and no test suite — the review scope is intentionally narrower than an application repo.

---

## Step 1: Automated Quality Gates

```bash
bun fl && bun type-check
```

**If these fail:**

- Report errors immediately.
- The review **CANNOT** pass until both are clean.
- **NEVER** use `// oxlint-disable` — fix the underlying issue.

---

## Step 2: Extract Staged Changes

```bash
git diff --cached
```

---

## Step 3: Content-Quality Audit

Scope: any `.mdx` file under `content/`.

| Check                                                                                                               | Severity    |
| :------------------------------------------------------------------------------------------------------------------ | :---------- |
| Heading hierarchy is linear (no h1 → h3 jumps) and a single top-level heading per page                              | 🔴 High     |
| Frontmatter/`_meta.js` entry exists for every new page — no orphaned MDX files                                      | 🔴 High     |
| Code blocks specify a language for syntax highlighting                                                              | 🟡 Medium   |
| No placeholder text left behind (`TODO`, `Lorem ipsum`, `TBD`)                                                      | 🔴 High     |
| Terminology consistent with existing pages (check `content/technical/` for established terms)                       | 🟡 Medium   |
| Screenshots/diagrams referenced actually exist under `public/`                                                      | 🔴 High     |
| Mermaid diagrams (via `components/Mermaid.tsx` / `MermaidDynamic.tsx`) render valid syntax                          | 🔴 High     |
| Generated pages (from `bun docs:generate` / `bun changelog:generate`) are not hand-edited — edit the source instead | 🔴 Critical |

---

## Step 4: Broken-Link Audit

```bash
git diff --cached --name-only -- '*.mdx'
```

For each changed or added MDX file:

| Check                                                                                                               | Severity    |
| :------------------------------------------------------------------------------------------------------------------ | :---------- |
| Internal links (`[text](/path)`) resolve to an existing route under `content/`                                      | 🔴 Critical |
| Cross-references between `content/product/` and `content/technical/` use root-relative paths, not hardcoded domains | 🔴 High     |
| External links use `https://` and are not dead (spot-check any newly added ones)                                    | 🟡 Medium   |
| Anchor links (`#heading-slug`) match the actual generated heading slug                                              | 🔴 High     |
| No links pointing at `.next/` or other build output                                                                 | 🔴 Critical |

If `pagefind` search index generation is part of the build, confirm no MDX changes broke the searchable content structure.

---

## Step 5: Build-Success Verification

```bash
bun run build
```

- **Block** if the build fails for any reason (Nextra compile error, MDX parse error, `pagefind` indexing failure).
- Watch specifically for the Nextra 4.6.x Zod `LayoutPropsSchema` bug (see `.claude/anti-patterns/nextra-zod-v4-bug.md`) if `nextra`/`nextra-theme-docs` versions were touched — this repo is pinned to `4.5.1`, do not bump without checking that anti-pattern file first.
- Confirm `next.config.mjs` still sets `output: 'standalone'` unless intentionally changed.

---

## Step 6: Accessibility Audit

Scope: `app/layout.tsx`, `mdx-components.tsx`, and any `.tsx` file under `components/`. Skip if the diff contains no `.tsx` changes.

| Check                                                                                              | Severity    |
| :------------------------------------------------------------------------------------------------- | :---------- |
| All images (`next/image` or `<img>`) have meaningful `alt` text (or `alt=""` if purely decorative) | 🔴 Critical |
| Interactive elements (nav links, search, theme toggle) have accessible names                       | 🔴 Critical |
| Focus visible on all interactive elements — no `outline: none` without a replacement               | 🔴 Critical |
| `<html lang>` set correctly in `app/layout.tsx`                                                    | 🔴 Critical |
| Heading hierarchy is linear across the rendered page (see Step 3)                                  | 🔴 High     |
| Color contrast ≥ 4.5:1 body text, ≥ 3:1 large text — check both light and dark theme               | 🔴 High     |
| Mermaid diagrams have a text alternative or accessible summary for screen readers where feasible   | 🟡 Medium   |

---

## Step 7: Documentation Structure Check

Scope: `content/_meta.js`, `content/product/_meta.js`, `content/technical/_meta.js`.

| Check                                                                                                                         | Severity    |
| :---------------------------------------------------------------------------------------------------------------------------- | :---------- |
| Every `.mdx` file has a corresponding entry in its directory's `_meta.js`                                                     | 🔴 Critical |
| `_meta.js` ordering matches the intended navigation order                                                                     | 🟡 Medium   |
| No duplicate route slugs across `content/product/` and `content/technical/`                                                   | 🔴 Critical |
| New top-level sections are deliberate — prefer nesting under `product/` or `technical/` over adding a third top-level section | 🟡 Medium   |
| `scripts/generate-docs/` output (if regenerated) matches the source it was generated from — no stale content                  | 🔴 High     |

---

## Step 8: Generate Review Report

### 8.1 Severity definitions

- **🔴 Critical** = broken build, broken link, or missing nav entry. **Blocks merge.**
- **🟠 High** = content-quality or accessibility issue that degrades the reader experience. **Blocks merge.**
- **🟡 Medium** = non-blocking improvement.

### 8.2 Required output structure

Always output in this exact order:

```markdown
# /review Report — {feature or branch name}

## Status: {✅ LGTM | ⚠️ Requires Changes | ❌ Blocked}

**Severity Summary**

- 🔴 Critical: {N}
- 🟠 High: {N}
- 🟡 Medium: {N}

**Quality Gates**

| Gate                 | Status  |
| :------------------- | :------ |
| `bun fl`         | ✅ / ❌ |
| `bun type-check` | ✅ / ❌ |
| `bun run build`  | ✅ / ❌ |

---

## Blocking Issues

> [!CAUTION]
> **{Title}** — `{file:line}`
> {Description}
> **Fix:** {Concrete fix instruction}

---

## Suggestions

> [!TIP]
> **{Title}** — `{file:line}`
> {Description}

---

## Files Reviewed

{N} files, +{additions} / -{deletions} lines
```

---

## Step 9: User Approval & Action

Present three options to the user:

1. **Apply all blocking fixes** — automatically resolve Critical + High issues
2. **Walk through issue-by-issue** — show each one, decide together
3. **Skip — I'll handle it manually** — exit, user fixes on their own

Default recommendation: **option 1** when all issues are unambiguous; **option 2** when navigation structure or content placement decisions are involved.
