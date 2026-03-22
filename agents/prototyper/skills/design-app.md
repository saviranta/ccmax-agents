# Skill: Design App

**Trigger:** "I want to build a full app"

The user wants to go from concept to a complete application design — user research, flows, wireframes, visual exploration, and a draft design system.

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

### Step 1: User research

Gather the full picture before designing anything.

**About the users:**
- Who are the primary and secondary users?
- What devices and contexts will they use this in?
- How frequently will they use it?
- What's their technical comfort level?

**About the problem:**
- What problem does this app solve?
- What do users do today without it?
- What's the most important outcome for users?

**About references:**
- Does the user have screenshots, URLs, or examples of apps they like?
- What specifically do they like about those references?

### Step 2: Analyze all provided references

For every screenshot, URL, or reference the user provides:

1. **Screenshots/images** — Delegate to **screenshot-analyzer** to extract: layout structure, component patterns, visual style, interaction hints
2. **URLs** — Use **WebFetch** (or Jina Reader via `WebFetch "https://r.jina.ai/URL"` for JS-rendered pages) to read the page, then take Playwright screenshots for visual analysis
3. **Competitor research** — Use **WebSearch** to find 2-3 similar apps. Analyze what they do well and where they fall short.

Summarize findings: "From your references, I see these patterns: [list]. Here's what I think you're drawn to: [synthesis]."

### Step 3: Map complete user flows

Delegate to **flow-mapper** to produce flow diagrams covering:

1. **Onboarding flow** — First-time user experience from signup to first value
2. **Core loop** — The primary repeated action (the thing users come back for)
3. **Key secondary flows** — Settings, account management, edge cases
4. **Error and recovery flows** — What happens when things go wrong

Each flow must document:
- Happy path (step by step)
- Unhappy paths (errors, edge cases, cancellations)
- Decision points where the user makes choices

Present flows to the user for validation before proceeding to wireframes.

### Step 4: Clickable wireframe prototype

Delegate to **wireframer** to produce a clickable HTML prototype:

- One HTML file per screen
- Navigation links between screens that actually work (anchor tags or JS)
- Grayscale, low-fidelity — focused on layout, hierarchy, and flow
- Every screen from the flows in Step 3 must be represented
- Include all states: empty, loading, populated, error

Delegate to **ux-writer** to produce microcopy for:
- Navigation labels
- Button text
- Empty states
- Error messages
- Onboarding copy

Present the clickable prototype to the user. Iterate based on feedback before moving to visual design.

### Step 5: Visual exploration

Once wireframes are approved, produce 2-3 visual direction options for key screens:

- **Key screens to design:** Landing/home, the core action screen, one secondary screen
- **Each direction** should represent a distinct aesthetic (e.g., minimal vs. bold, dark vs. light, dense vs. spacious)
- Produce as styled HTML files viewable in a browser

Ask the user: "Which direction resonates? What would you combine from different options?"

### Step 6: Produce outputs

Write the following artifacts to `.max-agents/artifacts/prototyper/`:

1. **`vision.md`** — Problem statement, target users, core value proposition, scope (in/out), key decisions made with rationale

2. **Complete flow maps** — All user flows from Step 3 (produced by flow-mapper)

3. **Clickable wireframe prototype** — All HTML files from Step 4 (produced by wireframer), organized in a `wireframes/` subdirectory

4. **User stories for all features** — One story per feature. Each must include:
   - Tradeoff decisions with rationale
   - Happy path narrative
   - Documented unhappy paths
   - User's explicit decisions as constraints
   - Usage context (frequency, environment, actor type)

5. **Draft design system** — `design-system-draft.md` containing:
   - Color palette (hex values)
   - Typography scale (font families, sizes, weights)
   - Spacing system
   - Component inventory (buttons, inputs, cards, etc.)
   - Interaction patterns (hover, active, focus states)
   - Tone of voice guidelines (from ux-writer output)

---

## Principles

- Do not skip user research. Wireframes without understanding users produce pretty but wrong designs.
- The clickable prototype is the most valuable artifact — it forces you to think through every screen and transition.
- Visual exploration comes AFTER wireframes are validated. Style decisions on broken flows waste time.
- Every design decision must trace back to a user need or an explicit user preference.
- Document what was considered and rejected, not just what was chosen.
