# Researcher Agent

The Researcher handles knowledge acquisition. Before the Prototyper designs and before the Architect decides, the Researcher finds out what is worth knowing: what tools exist, what competitors do, what the tradeoffs are, what the community has learned.

---

## What It Does

- Web research on technologies, libraries, and ecosystem options
- Competitive analysis of existing products
- Tech stack evaluation and comparison
- Repo and documentation analysis
- Literature review on approaches and patterns

The Researcher does not produce code or specs. It produces structured knowledge that other agents and the user can act on.

---

## Two Modes

**Interactive mode** — you talk to it directly. Use this when exploring a problem space, evaluating options, or making a technology decision. The Researcher will ask clarifying questions to narrow down what you actually need.

**Autonomous mode** — called by other agents (typically the Architect) when they need specific information to complete a decision. You do not need to do anything in this mode; it runs in the background and deposits results in the research library.

---

## Research Cache

Completed research is saved to:

```
<workspace>/research/
```

Before running new research, the Researcher checks this library. If a relevant report exists and is less than 30 days old, it is reused. This prevents redundant work across projects.

Each report in the library is tagged with topic, date, and a summary. The Researcher indexes these so it can retrieve relevant prior research even when you do not reference it directly.

---

## Skills

| Skill | Use It When |
|-------|-------------|
| **Business Report** | You need a market or domain overview before defining the product |
| **Competitive Analysis** | You want to understand what existing products do, how they position, and where the gaps are |
| **Literature Review** | You need to understand the state of practice on a technical topic (e.g., "how do people handle real-time sync in collaborative editors?") |
| **Quick Brief** | You need a focused answer to a specific question in 5 minutes or less |
| **Tech Stack Decision** | You are choosing between technologies and need a structured comparison with a recommendation |

---

## How to Invoke

From any directory, launch the Researcher agent:

```bash
bash <agents-max>/scripts/run-agent.sh researcher
```

Or directly:

```bash
claude --append-system-prompt "$(cat <agents-max>/agents/researcher/CLAUDE.md)"
```

Then describe what you need in plain language.

Examples:

```
What are the tradeoffs between Supabase and PlanetScale for a Next.js SaaS with a lot of relational data?
```

```
Do a competitive analysis of task management tools that focus on async teams. I want to know what features they compete on and where the market is thin.
```

```
Quick brief: does Vercel support WebSocket connections on the free plan?
```

The Researcher will identify which skill applies and run it. If the question is ambiguous, it will ask one or two clarifying questions before starting.

---

## What It Produces

Every research output includes an **Executive Summary block** at the top:

```
## Executive Summary
- Key finding 1
- Key finding 2
- Key finding 3
- Recommended direction (if applicable)
```

Full reports include sections for methodology, findings, source evaluation, and conclusions. Quick briefs are shorter — just the answer and the sources.

All outputs are saved to the research library with a descriptive filename and date tag so they can be retrieved by future agents and sessions.

---

## Tips

**Be specific about the question.** The Researcher performs much better with a focused question than a broad topic.

- Weak: `compare databases`
- Strong: `What are the tradeoffs of Supabase vs PlanetScale for a Next.js SaaS where most queries are relational joins and the team has no DBA experience?`

**Name your constraints.** If you have a budget limit, a hosting requirement, a language preference, or a timeline pressure, say so upfront. The Researcher will filter recommendations accordingly.

**Ask for a recommendation.** If you want the Researcher to take a position rather than just list options, ask explicitly: "Which would you recommend and why?" Otherwise it will present options neutrally.

**Don't repeat research.** If you have already asked a similar question in a previous session, tell the Researcher — it will check the library first rather than starting from scratch.
