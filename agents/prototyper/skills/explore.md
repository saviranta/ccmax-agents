# Skill: Explore

**Trigger:** "I have a vague idea, help me figure out what I want"

The user has a fuzzy concept. Your job is to sharpen it into something buildable through structured conversation and research — not to jump to solutions.

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

### Step 1: Understand the problem space

Ask open-ended questions. Do NOT propose solutions yet. Cover:

1. **The problem** — What frustration or need sparked this idea? What happens today without this thing?
2. **The people** — Who experiences this problem? How often? In what context (work, personal, on-the-go, desktop)?
3. **The stakes** — What happens if this problem stays unsolved? Is it annoying or blocking?
4. **Existing attempts** — Has the user tried anything? Spreadsheets, other tools, manual processes?

Ask 3-5 questions maximum per round. Wait for answers before continuing.

### Step 2: Research the landscape

Once you understand the problem:

1. Use **WebSearch** to find 3-5 existing products or approaches that solve adjacent problems
2. Use **WebFetch** (or Jina Reader via `WebFetch "https://r.jina.ai/URL"` for JS-rendered pages) to read relevant pages
3. Summarize what exists, what works, what's missing
4. Present findings to the user: "Here's what's out there. What resonates? What's wrong with these?"

### Step 3: Define the audience

Narrow down who this is for. Get explicit answers on:

- **Actor type** — Who is the primary user? Secondary users?
- **Frequency** — Daily tool? Weekly? One-time?
- **Environment** — Mobile, desktop, both? Office, field, home?
- **Technical comfort** — Power user or needs hand-holding?
- **Scale** — Solo use, team, public?

### Step 4: Identify key features

Based on Steps 1-3, propose 5-8 potential features ranked by importance. For each:

- One-sentence description
- Which user problem it addresses
- Whether it's core (must-have) or nice-to-have

Ask the user to sort: "Which 3 of these are essential for v1?"

### Step 5: Rough wireframes

For the top 3 features the user selected:

1. Delegate to **wireframer** to produce rough HTML wireframes — low-fidelity, grayscale, focused on layout and information hierarchy
2. Delegate to **flow-mapper** to map the happy path connecting these features
3. Present wireframes and flow to the user for reaction

### Step 6: Produce outputs

Write the following artifacts:

1. **`vision.md`** — Problem statement, target audience, key features (v1 scope), what's explicitly out of scope, open questions remaining
2. **Initial user stories** — One story per key feature. Each story must include:
   - Tradeoff decisions with rationale
   - Happy path narrative
   - Documented unhappy paths (what can go wrong)
   - User's explicit decisions as constraints
   - Usage context (frequency, environment, actor type)
3. **Rough wireframes** — The HTML files produced by wireframer

Save all artifacts to `.max-agents/artifacts/prototyper/`.

---

## Principles

- Stay in question mode longer than feels comfortable. Premature solutions are the biggest risk at this stage.
- Surface tradeoffs explicitly: "You could go simple or flexible here — simple means X limitation, flexible means Y complexity."
- Record every explicit user decision as a constraint for downstream agents.
- If the user says "I don't know," that's valuable information. Note it as an open question, don't fill it in.
