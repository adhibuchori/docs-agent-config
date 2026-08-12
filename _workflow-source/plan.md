---
description: Detailed content/feature planning workflow including scoping, task breakdown, and risk assessment.
---

<!-- Command: /plan [feature] -->
<!-- Source: _workflow-source/plan.md -->
<!-- Run before starting any new content section or site feature -->

# /plan — Content & Feature Planning

## Input

Feature: $ARGUMENTS

---

## Output Format

Prefix output with: `## 📋 PLAN`

Tone: exploratory — flag unknowns, surface assumptions. Do NOT proceed to code. Wait for user confirmation.

---

## Steps

### 1. SCOPE

Map out exactly what needs to change, layer by layer:

- **Content** (`content/product/`, `content/technical/`): MDX pages to create or restructure — path + reason
- **Navigation** (`content/**/_meta.js` or equivalent Nextra meta files): new entries, reordering, renamed sections
- **Components** (`components/`): new or modified `.tsx` files used inside MDX (keep this list short — this repo has almost no custom components)
- **App shell** (`app/`): layout, root MDX catch-all route, or global styling changes
- **Generation scripts** (`scripts/generate-docs/`, `scripts/generate-changelog/`): changes needed if source code/comments that feed generated docs changed
- **Config** (`next.config.mjs`, `mdx-components.tsx`): only if the change requires it

### 2. UNKNOWNS

List anything that must be investigated before writing can start. Examples:

- "Does this content already exist under a different section?"
- "Does `docs:generate` need to run first to pull in new source comments?"

If none → state: "No unknowns."

### 3. TASKS

Format: `[ ] [TAG] [verb] [target] — est. Xmin`

- Each task: **5–30 min**. If larger, split it.
- Ordered by dependency.
- Tags: `[CONTENT]` `[NAV]` `[UI]` `[CONFIG]` `[SCRIPT]`

### 4. RISKS

Format: `[HIGH/MED/LOW] [risk] → [mitigation]`

Only flag risks that would block or significantly change execution (e.g., broken links, nav structure conflicts, generated-docs drift).

### 5. CONFIRMATION

Generate 1–3 questions specific to this feature that need user answers before proceeding.

If no open questions → state: "No blockers — ready to execute."

---

## Hard Rules

- Do not start writing/coding until user responds to CONFIRMATION
- Output sections in order: SCOPE → UNKNOWNS → TASKS → RISKS → CONFIRMATION
- If plan exceeds 50 tasks, split into phases — output Phase 1 first, ask user before continuing
