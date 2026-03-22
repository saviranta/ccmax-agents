# Skill: Spec from Reference

**Trigger:** "Here's exactly what I want, extract the spec"

The user has a reference — screenshot, URL, Figma export, or existing UI — and wants a precise specification extracted from it that downstream agents (especially Architect and Builders) can consume directly.

---

## Sub-agents available

- **screenshot-analyzer** — extract layout, colors, typography, components from reference images
- **ux-writer** — draft microcopy, labels, empty states, error messages
- **wireframer** — produce HTML wireframe files from descriptions
- **flow-mapper** — map user journeys and produce flow diagrams

## Artifact output path

All outputs go to `.max-agents/artifacts/prototyper/`

---

## Workflow

### Step 1: Collect and analyze the reference

Accept whatever the user provides: screenshots, URLs, Figma exports, photos of sketches.

For each reference:

1. **Screenshots/images** — Delegate to **screenshot-analyzer** to extract:
   - Exact colors (hex values) for backgrounds, text, borders, accents
   - Font families, weights, and sizes (estimate from proportions if exact values aren't available)
   - Spacing patterns (margins, padding, gaps)
   - Component hierarchy (what contains what)
   - Layout grid (columns, breakpoints if multiple sizes shown)
   - Icon style (outline, filled, size)
   - Border radius, shadows, opacity values

2. **URLs** — Use **WebFetch** (or Jina Reader via `WebFetch "https://r.jina.ai/URL"` for JS-rendered pages) to get page content. Take Playwright screenshots at key viewport widths (mobile 375px, tablet 768px, desktop 1440px). Then run screenshot-analyzer on the captures.

3. **Multiple references** — If the user provides several, identify what's consistent across them (the system) vs. what varies (individual screens).

### Step 2: Clarify the relationship

Ask the user:

> "Is this the target UI the feature will live in — meaning I should extract the full design system from it? Or is this inspiration — meaning I should note what you like about it but expect the actual UI to differ?"

**If this IS the target UI:**
- Extract the complete design system (Step 3)
- Treat every visual detail as a specification, not a suggestion

**If this is inspiration:**
- Note what the user likes about it
- Extract patterns and principles, not exact values
- Ask what aspects to adopt vs. adapt

### Step 3: User research

Even when extracting from a reference, understanding the users matters for making spec decisions:

1. **Who uses this?** — Primary and secondary users
2. **On what devices?** — Mobile, desktop, both? Which is primary?
3. **How often?** — Daily tool, occasional use, one-time?
4. **What's the core task?** — What action do users perform most?

This informs decisions about responsive behavior, information density, and interaction patterns.

### Step 4: Extract the design system

Produce a complete design system document:

**Colors:**
- Primary, secondary, accent colors (hex)
- Background colors (page, card, modal)
- Text colors (heading, body, muted, link, error, success)
- Border colors
- State colors (hover, active, focus, disabled)

**Typography:**
- Font families (heading, body, mono)
- Type scale (h1 through body-sm, with size, weight, line-height, letter-spacing)
- Text alignment patterns

**Spacing:**
- Base unit
- Spacing scale (xs through 3xl)
- Common padding/margin patterns observed

**Layout:**
- Grid system (columns, gutters, max-width)
- Breakpoints (if responsive behavior is visible)
- Common layout patterns (sidebar + content, stack, grid)

**Components:**
Inventory every distinct component visible in the reference:
- Buttons (variants: primary, secondary, ghost, destructive; sizes; states)
- Inputs (text, select, checkbox, radio, toggle; states)
- Cards (variants, content structure)
- Navigation (header, sidebar, tabs, breadcrumbs)
- Modals/dialogs
- Tables/lists
- Badges, tags, tooltips
- Icons (style, common sizes)

For each component: dimensions, padding, border-radius, shadow, font specs.

**Interaction patterns:**
- Hover effects
- Transitions/animations (describe timing and easing)
- Loading patterns
- Feedback patterns (success, error)

### Step 5: Map flows and stories

Delegate to **flow-mapper** to produce:
- User flows visible in the reference (screen-to-screen navigation)
- Entry and exit points
- Inferred flows (what screens likely exist but aren't shown)

Produce user stories for each visible feature:
- Tradeoff decisions with rationale
- Happy path narrative
- Documented unhappy paths
- User's explicit decisions as constraints
- Usage context (frequency, environment, actor type)

Delegate to **ux-writer** to catalog all visible copy and produce copy for states not shown (empty, error, loading).

### Step 6: Produce outputs

Write the following artifacts to `.max-agents/artifacts/prototyper/`:

1. **`design-system-draft.md`** — Complete design system extracted in Step 4. Formatted so the Design Guardian and Builders can consume it directly. Use exact values, not descriptions. Structure it to match the project's `DESIGN_SYSTEM.md` template if one exists.

2. **Component inventory** — `component-inventory.md` listing every component with its variants, states, and specifications.

3. **User stories** — One per identified feature, with full context as specified above.

4. **Flow maps** — All flows produced by flow-mapper.

5. **Reference analysis** — `reference-analysis.md` documenting what was extracted from each reference, confidence levels (exact value vs. estimate), and any ambiguities that need user clarification.

---

## Principles

- Precision is the entire point. "Blue" is not a spec. "#2563EB" is a spec.
- When you can't determine an exact value, say so explicitly and provide your best estimate with a confidence note.
- The design system must be complete enough that someone could rebuild the reference UI from the spec alone.
- Ask about the target UI question (Step 2) early — it changes the entire approach.
- Component inventory should be exhaustive. Miss a component and a Builder will have to improvise.
- Separate what's observed from what's inferred. Downstream agents need to know the difference.
