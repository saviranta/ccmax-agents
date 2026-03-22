# Skill: Tech Stack Decision

This skill defines how to write a technical evaluation report for choosing between technology options. Load this file when the report type is `tech-stack-decision`.

---

## Purpose

Help technical leads and architects choose between competing technologies with confidence. The report must be evidence-based — every claim about a technology should cite a source, benchmark, or direct observation. Opinion is permitted in the Recommendation section and must be labeled as such.

---

## Audience

- Engineering leads, architects, CTOs
- Technical contributors who will work with the chosen technology
- May be reviewed by non-technical stakeholders; the Executive Summary must be accessible to them

---

## Structure

### 1. Executive Summary
- State the decision to be made, the recommended choice, and the one or two strongest reasons for it
- 1–2 paragraphs; accessible to non-technical readers
- Include a one-line risk statement if a significant tradeoff exists

### 2. Requirements
- List what the chosen technology must do, organized as:
  - **Must-have**: hard requirements; a candidate that fails any of these is eliminated
  - **Should-have**: important but negotiable
  - **Nice-to-have**: would improve the decision but are not decision criteria on their own
- Non-functional requirements belong here: performance targets, licensing constraints, team expertise, support requirements, budget ceiling
- Be precise: "handles 10,000 concurrent connections" is a requirement; "performant" is not

### 3. Candidates
- List each technology evaluated
- For each candidate: one paragraph covering what it is, who makes it, what problem it was designed to solve, and its current adoption level
- State why it was included (meets must-haves, widely recommended, specifically requested)
- State any candidates that were considered and excluded early, with the reason

### 4. Evaluation Matrix
- A table with candidates as columns and evaluation criteria as rows
- Each criterion must have a weight (e.g., 1–5 or percentage of total)
- Score each candidate per criterion (e.g., 1–5)
- Show weighted score per cell and total weighted score per candidate
- Criteria should map directly to the requirements in section 2
- Include the matrix even if the winner is obvious — it makes the reasoning auditable

Example column headers: Criterion | Weight | Candidate A | Candidate B | Candidate C

### 5. Deep Dive per Candidate
- One subsection per candidate
- Each subsection covers:
  - **Strengths**: what it does well relative to the requirements
  - **Weaknesses**: limitations, missing features, known issues
  - **Risks**: things that could go wrong in adoption or operation (vendor lock-in, breaking changes, deprecation risk, sparse documentation)
  - **Ecosystem health** (required — pull current data where possible):
    - GitHub stars and star growth trend
    - npm/PyPI/package manager weekly downloads (as applicable)
    - Last release date and release cadence
    - Number of contributors
    - Open issues and average time to close
    - Commercial support availability
  - **Team fit**: how well it matches current team skills and hiring market

### 6. Recommendation
- State the choice directly
- Summarize why it wins on the criteria that matter most
- Address the strongest argument for the runner-up and explain why it was not chosen
- State any conditions that would change the recommendation (e.g., "If the team's Python expertise grows significantly, reconsider Candidate B")

### 7. Migration and Adoption Plan
- How to move from the current state to using the recommended technology
- Cover: proof of concept scope, phased rollout if applicable, training needs, integration points to address, rollback plan
- Flag dependencies that need to be resolved before adoption can begin
- Rough effort estimate by phase (days or weeks, not hours)

---

## Tone and Style

- Technical but not obscure — explain acronyms and niche terms on first use
- Evidence-based: cite benchmarks, documentation, GitHub data, community surveys (e.g., Stack Overflow Developer Survey)
- When stating a weakness or risk, distinguish between observed evidence and inference
- Avoid vendor marketing language; use neutral descriptors

---

## Required Elements

The following must appear in every tech stack decision report:

1. **Comparison table** (the Evaluation Matrix in section 4)
2. **Ecosystem health metrics** for each candidate (GitHub stars, downloads, last release date, contributor count) — note the date these were retrieved
3. **Risk assessment** — at minimum a sentence per candidate on adoption risk; a table is preferred if risks differ significantly across candidates

---

## Length Guidance

- Main body: 3–6 pages
- The Deep Dive section typically dominates length; keep individual candidate subsections focused
- Cut ecosystem data that is not meaningfully different between candidates; summarize in a table instead

---

## Format Requirements

- Use `##` for main sections, `###` for candidate subsections within the Deep Dive
- The Evaluation Matrix must be a markdown table
- Ecosystem health data should be presented as a table for easy comparison
- Cite all data sources; include retrieval date for metrics that change over time
- Code snippets are appropriate in Deep Dive sections if they illustrate a meaningful API or configuration difference
