# Prototyper Agent

The Prototyper turns an idea into a product definition. It is a design agent, not a code agent. Its job is to figure out what to build before anyone writes a line of code — who uses it, what they need, how the flows work, and what constraints are non-negotiable.

---

## What It Does

- Runs discovery sessions to clarify and sharpen a fuzzy idea
- Writes user stories in the structured format required by the pipeline
- Produces wireframes and flow diagrams describing the key screens and interactions
- Defines design constraints (visual language, tone, accessibility requirements)
- Captures `[USER DECISION]` items — requirements locked by you that downstream agents cannot override

The Prototyper does not write code or make technology choices. Those belong to the Architect.

---

## Mode

The Prototyper is always interactive. It never runs autonomously. Every step involves a conversation — it asks questions, shows you drafts, and iterates based on your feedback. You are the final authority on whether the output reflects the product you want to build.

---

## Skills

| Skill | Use It When |
|-------|-------------|
| **Explore** | Your idea is still fuzzy — you know roughly what you want but not the specifics. Explore runs a structured discovery session to sharpen it. |
| **Design App** | You have a clear concept and want a full product spec: vision, user stories, flows, wireframes, and design constraints. |
| **Design Feature** | You have an existing product and want to add a specific feature without re-speccing the whole app. |
| **Refine Detail** | You have a draft spec and want to iterate on a specific story, flow, or constraint. |
| **Spec from Reference** | You have screenshots or a URL of an existing app and want to derive a spec from what you see. Useful for cloning a workflow or adapting a competitor's UX. |

---

## Input

- Your idea, described in plain language — as rough or detailed as you have it
- Reference apps or competitors you want to emulate or differentiate from
- Screenshots of UX patterns you like or want to avoid
- Business goals and constraints (audience, timeline, budget, must-have vs. nice-to-have)

---

## Output

All Prototyper output goes to `.max-agents/artifacts/prototyper/` inside the project directory:

```
.max-agents/artifacts/prototyper/
  vision.md                  — product purpose, target users, success metrics
  user-stories/
    US-001-[slug].md
    US-002-[slug].md
    ...
  wireframes/
    [screen-name].png
    ...
  flows/
    [flow-name].png
    ...
  design-constraints.md      — visual language, tone, accessibility rules
```

The Architect reads this output automatically when it starts. You do not need to copy or convert anything.

---

## How to Invoke

Open Claude Code in the initialized project directory (the one with the Prototyper CLAUDE.md active). Then describe what you want to build.

```
I want to build a tool that helps freelancers track their client hours and generate invoices automatically.
```

```
Run Spec from Reference — here are three screenshots of Linear's issue view. I want something like this but for content teams.
```

```
Design a feature: I want to add recurring tasks to the existing task manager. Users should be able to set daily, weekly, or monthly repeats.
```

---

## Tips

**Start with Explore if you're fuzzy.** It is much better to spend 20 minutes in discovery than to write 15 user stories and then realize the core workflow is wrong. Explore asks the right questions to surface assumptions early.

**Use Spec from Reference when you have a model.** If there is an app that does something similar to what you want, screenshots are faster than descriptions. The Prototyper will analyze the UX and generate a spec from what it sees.

**Lock [USER DECISION] items early.** Any requirement that you are certain about and do not want redesigned downstream should be marked as a `[USER DECISION]`. Examples: "the app must work offline," "users must not need to create an account for basic use," "the pricing model is per-seat." These are passed through to every subsequent agent and cannot be overridden.

**Be honest about what you don't know.** Unresolved questions go into the `Open Questions` section of each story. Stories with open questions are not scheduled for development until the questions are resolved. Better to surface uncertainty now than to have the Architect make assumptions that don't match your intent.

**Wireframes are coarse.** Do not expect pixel-perfect designs. Wireframes show layout, hierarchy, and flow — they are a communication tool for the Architect, not a design handoff.
