# Skill: Design Feature

**Trigger:** "I want to add a feature to an existing app"

The user has an existing application and wants to design a new feature that fits within it. The key challenge is producing multiple distinct approaches so the user can make an informed tradeoff decision.

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

### Step 1: Gather existing project context

Check for existing documentation in these locations:

1. `.max-agents/artifacts/` — Previous prototyper outputs, vision docs, design systems
2. `.max-agents/artifacts/prototyper/` — Design system drafts, wireframes, flows
3. Project root — `PRD.md`, `DESIGN_SYSTEM.md`, `ADR.md`, user research docs
4. `agent-workspace/` — Any previous agent outputs

**If found:** Read and summarize the constraints. Confirm with the user: "I found [X]. I'll follow these constraints. Anything changed?"

**If not found:** Ask the user:
- What's the app? Show me (screenshots, URL, or description).
- What's the existing visual language? (Colors, fonts, component style)
- Who are the current users?
- What's the tech stack? (Affects what's feasible)

### Step 2: Understand the feature

Get clear on:

1. **What** — What should this feature do? What problem does it solve?
2. **Where** — Where does it live in the app? New screen, addition to existing screen, modal, sidebar?
3. **Who** — Same users as the core app, or a subset?
4. **When** — How often will this be used? Is it a daily action or occasional?
5. **Constraints** — Any technical limitations, deadlines, or non-negotiables?

### Step 3: Map the feature flow

Delegate to **flow-mapper**:

- Map the feature's entry points (how does the user get to it?)
- Map the happy path through the feature
- Map unhappy paths: errors, cancellations, edge cases, empty states
- Map how the feature connects back to the rest of the app

### Step 4: Produce 5+ approach options

This is the core of this skill. Produce at least 5 distinct approaches, each representing a clear UX tradeoff. Not just visual variations — structurally different approaches.

**Tradeoff dimensions to explore:**
- **Simple vs. powerful** — Fewer options vs. more control
- **Inline vs. dedicated** — Embedded in existing flow vs. separate screen
- **Progressive vs. upfront** — Reveal complexity gradually vs. show everything
- **Guided vs. freeform** — Wizard/stepper vs. open canvas
- **Minimal vs. comprehensive** — Solve the core case vs. handle every edge case

For each option:

1. **Name** — A descriptive label (e.g., "Inline Quick-Add" or "Full-Page Wizard")
2. **Tradeoff** — One sentence: what you gain and what you sacrifice
3. **Best for** — Which user type or use case this serves best
4. **Visual mockup** — Delegate to **wireframer** to produce a scrollable HTML file that uses the existing app's visual language (colors, fonts, spacing from the design system or screenshots)
5. **Effort estimate** — Low / Medium / High relative complexity

Delegate to **ux-writer** for microcopy on each option's key interactions.

### Step 5: Present tradeoff comparison

Create a comparison summary:

| Option | Tradeoff | Best for | Effort | Risk |
|--------|----------|----------|--------|------|
| ... | ... | ... | ... | ... |

Present all options with their mockups. Ask the user: "Which direction? Or combine elements from multiple?"

### Step 6: Refine chosen option

Once the user picks (or combines):

1. Produce a refined mockup with all states (empty, loading, populated, error, disabled)
2. Delegate to **flow-mapper** for the final flow including edge cases
3. Delegate to **ux-writer** for complete microcopy (all labels, messages, tooltips)

### Step 7: Produce outputs

Write the following artifacts to `.max-agents/artifacts/prototyper/`:

1. **`feature-brief.md`** — Feature description, user problem, constraints, chosen approach with rationale, rejected approaches with reasons

2. **5+ option mockups** — A single scrollable HTML file at `wireframes/feature-{slug}-options.html` containing all options, each in a clearly labeled section. All options visible by scrolling a single page.

3. **Tradeoff comparison** — Included in feature-brief.md as a comparison table

4. **User stories for chosen option** — Each must include:
   - Tradeoff decisions with rationale
   - Happy path narrative
   - Documented unhappy paths
   - User's explicit decisions as constraints
   - Usage context (frequency, environment, actor type)

5. **Refined mockup** — Final HTML mockup of the chosen approach with all states

---

## Principles

- 5 options is the minimum. If you can only think of 3, you haven't explored the tradeoff space enough. Push harder on the dimensions.
- Each option must be visually distinct when scrolled in a browser — not just text descriptions.
- Use the existing app's visual language. A feature mockup that looks nothing like the existing app is useless.
- The user's choice is the most important output. Structure everything to make that choice clear and informed.
- Never present a "recommended" option. Present tradeoffs and let the user decide.
