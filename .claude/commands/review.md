---
description: Content-quality, broken-link, build-success, accessibility, and doc-structure review of the staged changes for a static Nextra documentation site; ends by offering to apply the fixes.
---

<!-- Command: /review -->
<!-- Source: _workflow-source/review.md -->
<!-- Run before every commit -->

# /review — Docs Review Workflow

Review covering content quality, link integrity, production build success, accessibility, and documentation structure. This repo is a static Nextra/MDX docs site with no backend, no auth, and no test suite — the review scope is intentionally narrower than an application repo.

---

## Step 1: Automated Quality Gates

```bash
bash scripts/check/gates.sh
```

**If a gate fails:**

- Report errors immediately.
- The review **CANNOT** pass until every gate is clean.
- **NEVER** use `// oxlint-disable` — fix the underlying issue.

---

## Step 2: Extract Staged Changes and Read the Checklist

```bash
git diff --cached
```

Read the diff whole: with RTK installed, run it as `rtk proxy git diff --cached`, since its rewrite
condenses a diff.

Then read `.claude/docs/code-review-checklist.md`. Its base sections apply where the change can
reach them, and its **Stack checks** section holds the docs-site checks; report a miss there
under the severity it carries.

---

## Step 3: Content-Quality Audit

Scope: any `.mdx` file under `content/`.

- 🔴 High — Heading hierarchy is linear (no h1 → h3 jumps) and a single top-level heading per page
- 🔴 High — Frontmatter/`_meta.js` entry exists for every new page — no orphaned MDX files
- 🟡 Medium — Code blocks specify a language for syntax highlighting
- 🔴 High — No placeholder text left behind (`TODO`, `Lorem ipsum`, `TBD`)
- 🟡 Medium — Terminology consistent with existing pages (check `content/technical/` for established terms)
- 🔴 High — Screenshots/diagrams referenced actually exist under `public/`
- 🔴 High — Mermaid diagrams (via `components/Mermaid.tsx` / `MermaidDynamic.tsx`) render valid syntax
- 🔴 Critical — Generated pages (from `bun run docs:generate` / `bun run changelog:generate`) are not hand-edited — edit the source instead

---

## Step 4: Broken-Link Audit

```bash
git diff --cached --name-only -- '*.mdx'
```

With RTK installed, run it as `rtk proxy git diff …`: every file on the list is audited.

For each changed or added MDX file:

- 🔴 Critical — Internal links (`[text](/path)`) resolve to an existing route under `content/`
- 🔴 High — Cross-references between `content/product/` and `content/technical/` use root-relative paths, not hardcoded domains
- 🟡 Medium — External links use `https://` and are not dead (spot-check any newly added ones)
- 🔴 High — Anchor links (`#heading-slug`) match the actual generated heading slug
- 🔴 Critical — No links pointing at `.next/` or other build output

If `pagefind` search index generation is part of the build, confirm no MDX changes broke the searchable content structure.

---

## Step 5: Build-Success Verification

```bash
bun run build
```

- A failed build blocks the review: a Nextra compile error, an MDX parse error, or a `pagefind` indexing failure.
- If the change touches the `nextra` or `nextra-theme-docs` version, read `.claude/anti-patterns/nextra-zod-v4-bug.md` first and report the version pair: the two packages move together.
- Confirm `next.config.mjs` still sets `output: 'export'` and `images.unoptimized`: the site is a static export served as assets.

---

## Step 6: Accessibility Audit

Scope: `app/layout.tsx`, `mdx-components.tsx`, and any `.tsx` file under `components/`. Skip if the diff contains no `.tsx` changes.

- 🔴 Critical — All images (`next/image` or `<img>`) have meaningful `alt` text (or `alt=""` if purely decorative)
- 🔴 Critical — Interactive elements (nav links, search, theme toggle) have accessible names
- 🔴 Critical — Focus visible on all interactive elements — no `outline: none` without a replacement
- 🔴 Critical — `<html lang>` set correctly in `app/layout.tsx`
- 🔴 High — Heading hierarchy is linear across the rendered page (see Step 3)
- 🔴 High — Color contrast ≥ 4.5:1 body text, ≥ 3:1 large text — check both light and dark theme
- 🟡 Medium — Mermaid diagrams have a text alternative or accessible summary for screen readers where feasible

---

## Step 7: Documentation Structure Check

Scope: `content/_meta.js`, `content/product/_meta.js`, `content/technical/_meta.js`.

- 🔴 Critical — Every `.mdx` file has a corresponding entry in its directory's `_meta.js`
- 🟡 Medium — `_meta.js` ordering matches the intended navigation order
- 🔴 Critical — No duplicate route slugs across `content/product/` and `content/technical/`
- 🟡 Medium — New top-level sections are deliberate — prefer nesting under `product/` or `technical/` over adding a third top-level section
- 🔴 High — `scripts/generate/docs/` output (if regenerated) matches the source it was generated from — no stale content

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

- `bash scripts/check/gates.sh`: ✅ / ❌
- `bun run build`: ✅ / ❌

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

1. **Apply all blocking fixes** — resolve the Critical and High issues, then re-run Step 1
2. **Walk through issue-by-issue** — show each one, decide together
3. **Skip — I'll handle it manually** — exit, user fixes on their own

Default recommendation: **option 1** when all issues are unambiguous; **option 2** when navigation structure or content placement decisions are involved. Apply nothing until the user picks one.
