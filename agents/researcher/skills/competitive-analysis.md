# Skill: Competitive Analysis

This skill defines how to write a competitive analysis report. Load this file when the report type is `competitive-analysis`.

---

## Purpose

Give product managers, founders, and strategists a clear picture of the competitive landscape: who the players are, what they offer, where they are strong or weak, and where opportunities exist. The output should drive product decisions and positioning strategy.

---

## Audience

- Product managers and product leaders
- Founders and co-founders
- Business strategists and investors
- May be read by sales and marketing teams for positioning context

Write for people who understand the market domain but may not have researched each competitor directly. Be specific — "better onboarding" is not useful; "4-step onboarding flow versus competitor's 12-step process" is.

---

## Structure

### 1. Executive Summary
- 2–4 paragraphs
- The competitive situation in brief: how crowded is the market, who leads it, what is the central competitive tension
- The 2–3 most actionable insights from the analysis
- Written last, placed first

### 2. Market Landscape
- Define the market: what problem space is this, who are the buyers, what are buyers trying to achieve
- Market size and growth rate if available (cite source and date)
- Market segmentation if relevant (e.g., enterprise vs. SMB, vertical-specific players vs. horizontal)
- Key trends shaping competition right now (e.g., AI integration, pricing model shifts, regulatory changes)
- This section sets context; keep it to 1–2 pages maximum

### 3. Competitor Profiles
- One subsection per competitor
- Cover the following for each:
  - **Overview**: what the product is, who built it, when it launched, how large the company is (employees, funding, revenue if known)
  - **Target audience**: who they are selling to; ideal customer profile
  - **Strengths**: what they do well, why customers choose them
  - **Weaknesses**: known limitations, complaints, areas where they lose deals
  - **Pricing**: pricing model and tiers; specific prices if publicly available; note if pricing is opaque or sales-led
  - **Key differentiators**: the 2–3 things they emphasize most in their own positioning
  - **Recent developments**: product launches, funding rounds, acquisitions, or strategic shifts in the past 12 months
- Use a consistent subsection structure for every competitor so the reader can compare them mentally
- Source claims about weaknesses from public reviews (G2, Capterra, Reddit, App Store), not assumptions

### 4. Feature Comparison Matrix
- A table listing features as rows and competitors (plus the subject product if applicable) as columns
- Use clear indicators: checkmark for present, dash for absent, or a short qualifier (e.g., "limited", "enterprise only", "beta")
- Group features by category (e.g., Core Features, Integrations, Security, Support)
- Include only features that are decision-relevant for buyers; do not pad with trivial features
- Add a brief note below the table calling out the most significant gaps and advantages

### 5. Gap Analysis
- Based on the comparison matrix and competitor weaknesses, identify opportunities
- Frame gaps as: "Competitors do not do X well, and buyers care about X because..."
- Each gap should have an associated strategic option: build, buy, partner, or deprioritize
- Distinguish between gaps that represent immediate opportunities and those that are niche or low-value

### 6. Strategic Recommendations
- 3–6 specific, actionable recommendations
- Each recommendation should reference specific evidence from the analysis
- Frame recommendations in terms of: positioning changes, product investment priorities, go-to-market angles, or areas to avoid competing directly
- Note assumptions each recommendation depends on

---

## Tone and Style

- Analytical and direct — state what the data shows, not what would be flattering to the subject company
- Market-focused: frame everything in terms of what buyers want and what competitors are delivering
- Avoid superlatives ("best-in-class", "industry-leading") unless quoting a specific source
- When a claim about a competitor cannot be verified, say so explicitly rather than omitting it or stating it as fact

---

## Required Elements

1. **Feature comparison table** (section 4) — required in every competitive analysis
2. **Positioning map description** — describe how the competitive set maps across two meaningful axes (e.g., price vs. feature breadth, ease of use vs. enterprise readiness). If a visual chart cannot be rendered, describe the positioning in prose and identify where each competitor sits
3. **Pricing summary** — even if only qualitative ("sales-led, likely $X0K+ ACV based on company size and target segment")

---

## Length Guidance

- Main body: 4–8 pages
- Competitor profiles are typically the longest section; limit each profile to 1 page unless depth is warranted
- More competitors does not mean better analysis — 4–6 well-researched profiles beat 12 shallow ones

---

## Format Requirements

- Use `##` for main sections, `###` for individual competitor names within Competitor Profiles
- Feature comparison matrix must be a markdown table
- Cite review sites and news sources for specific claims about competitors
- Include retrieval dates for pricing and metrics, as these change frequently
- Do not include company logos or branding language from competitors verbatim; describe their positioning neutrally
