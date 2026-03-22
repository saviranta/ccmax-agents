# Skill: Refine Detail

**Trigger:** "I need to nail this specific interaction/element"

The user knows what they want at a high level. They need to get one specific interaction, component, or element exactly right — every state, every pixel, every edge case.

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

Check for existing documentation:

1. `.max-agents/artifacts/prototyper/` — Previous design outputs, design system drafts
2. Project root — `PRD.md`, `DESIGN_SYSTEM.md`
3. `.max-agents/artifacts/` — Any other relevant artifacts

**If found:** Read the design system and relevant specs. Use them as constraints.

**If not found:** Ask the user:
- What's the app's visual language? (Screenshots, colors, fonts)
- What component library or framework is in use?
- Is there a design system to follow?

### Step 2: Identify the element

Get precise about what needs refinement:

1. **What element?** — Button, form, modal, dropdown, table, card, navigation, animation, transition?
2. **Current state** — Does a version already exist? Show me (screenshot or URL).
3. **What's wrong?** — What specifically needs to be better? Feels clunky? Missing states? Unclear feedback?
4. **Context** — Where does this element appear? What happens before and after interaction?

### Step 3: Produce initial draft

Delegate to **wireframer** to produce a single focused HTML mockup of the element. This first draft should:

- Match the existing design system (if available)
- Show the element in its default/resting state
- Be viewable and interactive in a browser where possible (hover states via CSS, etc.)

Present to the user: "Here's my starting point. What needs to change?"

### Step 4: Iterate on feedback

This is a tight feedback loop. Each iteration:

1. Listen to the user's feedback
2. Make targeted adjustments — do not redesign from scratch unless asked
3. Get more precise with each round (layout → spacing → colors → micro-interactions)
4. After each iteration, ask one specific question to drive the next improvement

Typical iteration sequence:
- Round 1: Layout and structure
- Round 2: Spacing, sizing, proportions
- Round 3: Colors, typography, visual weight
- Round 4: States and transitions
- Round 5: Edge cases and final polish

### Step 5: Document all states

Once the design direction is stable, produce the full state inventory. Every interactive element needs:

| State | Description | Visual treatment |
|-------|-------------|-----------------|
| **Default** | Resting state, no interaction | — |
| **Hover** | Mouse over (desktop) | — |
| **Active/Pressed** | During click/tap | — |
| **Focus** | Keyboard navigation | — |
| **Loading** | Waiting for response | — |
| **Disabled** | Not available | — |
| **Error** | Something went wrong | — |
| **Success** | Action completed | — |
| **Empty** | No data/content | — |
| **Overflow** | Too much content | — |

Not every state applies to every element. Include only those that are relevant, but actively consider each one.

Delegate to **ux-writer** for:
- Labels and text for each state
- Error messages (specific, actionable)
- Loading text (if applicable)
- Empty state copy
- Tooltips or help text

Delegate to **wireframer** to produce the final mockup HTML with all states visible (either as separate sections on the page or as interactive states).

### Step 6: Produce outputs

Write the following artifacts to `.max-agents/artifacts/prototyper/`:

1. **`detail-spec.md`** — Complete specification including:
   - Element name and purpose
   - Context (where it appears, what triggers it)
   - All states with visual descriptions
   - Interaction behavior (what happens on click, hover, keyboard)
   - Accessibility notes (ARIA roles, keyboard navigation, screen reader text)
   - Edge cases (long text, missing data, rapid clicks, slow network)
   - Exact values: colors (hex), spacing (px/rem), font sizes, border radius, shadows
   - Animation/transition timing (if applicable)

2. **Final mockup** — HTML file showing all states, viewable in browser

---

## Principles

- This skill is about precision, not exploration. One element, done thoroughly.
- Each iteration should be visibly better than the last. If you're going sideways, stop and ask a clarifying question.
- States are not optional. An element without documented states is incomplete.
- Accessibility is not a separate concern — it's part of every state (focus ring, ARIA labels, contrast ratios).
- The detail-spec.md must be specific enough that a developer can implement it without asking questions.
