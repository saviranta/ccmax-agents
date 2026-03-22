> **Note:** This is a draft design system produced during prototyping. The Architect's designer will produce the full, production-ready design system. These constraints establish direction and intent, not final specifications.

# Design Constraints: [Project Name]

**Version:** 0.1
**Status:** Draft
**Created:** YYYY-MM-DD

---

## Color Palette

| Role | Name | Hex | Usage |
|------|------|-----|-------|
| Primary | [Name] | `#000000` | [Main actions, brand elements] |
| Primary Dark | [Name] | `#000000` | [Hover states, emphasis] |
| Secondary | [Name] | `#000000` | [Supporting elements] |
| Accent | [Name] | `#000000` | [Highlights, calls to action] |
| Neutral 100 | [Name] | `#000000` | [Lightest — backgrounds] |
| Neutral 300 | [Name] | `#000000` | [Borders, dividers] |
| Neutral 600 | [Name] | `#000000` | [Secondary text] |
| Neutral 900 | [Name] | `#000000` | [Primary text] |
| Error | [Name] | `#000000` | [Error states, destructive actions] |
| Success | [Name] | `#000000` | [Confirmations, positive states] |
| Warning | [Name] | `#000000` | [Warnings, caution states] |
| Info | [Name] | `#000000` | [Informational messages] |

---

## Typography

**Primary font family:** [Font name — e.g., Inter, system-ui]
**Secondary / display font family:** [Font name or "none"]
**Monospace font family:** [Font name — e.g., JetBrains Mono, or "none"]

| Role | Family | Weight | Size | Line Height |
|------|--------|--------|------|-------------|
| Heading 1 | [Family] | [700] | [2rem] | [1.2] |
| Heading 2 | [Family] | [600] | [1.5rem] | [1.3] |
| Heading 3 | [Family] | [600] | [1.25rem] | [1.4] |
| Body | [Family] | [400] | [1rem] | [1.5] |
| Body Small | [Family] | [400] | [0.875rem] | [1.5] |
| Label | [Family] | [500] | [0.875rem] | [1.4] |
| Caption | [Family] | [400] | [0.75rem] | [1.4] |
| Code | [Mono] | [400] | [0.875rem] | [1.6] |

---

## Spacing

**Base unit:** [e.g., 4px or 8px]

**Scale:**

| Token | Value | Usage |
|-------|-------|-------|
| xs | [4px] | [Tight internal padding] |
| sm | [8px] | [Component internal spacing] |
| md | [16px] | [Default gap between elements] |
| lg | [24px] | [Section padding, card padding] |
| xl | [32px] | [Large gaps, page sections] |
| 2xl | [48px] | [Major section separators] |
| 3xl | [64px] | [Page-level vertical rhythm] |

---

## Layout

**Grid system:** [e.g., 12-column, 8-column, or custom]
**Gutter:** [e.g., 24px]
**Max content width:** [e.g., 1280px]
**Page horizontal padding:** [e.g., 16px mobile / 32px desktop]

**Breakpoints:**

| Name | Min Width | Notes |
|------|-----------|-------|
| sm | [640px] | [Small tablets and large phones] |
| md | [768px] | [Tablets] |
| lg | [1024px] | [Small desktops] |
| xl | [1280px] | [Standard desktops] |
| 2xl | [1536px] | [Large screens] |

---

## Component Patterns

Brief description of visual style intent for key components.

**Buttons:** [e.g., Rounded corners (4px), filled primary with white label, outlined secondary, ghost for low-emphasis actions]

**Inputs:** [e.g., Full-width, 1px border in neutral-300, focus ring in primary, error state in red with helper text below]

**Cards:** [e.g., White background, subtle shadow (0 1px 4px rgba(0,0,0,0.08)), 8px radius, 24px padding]

**Navigation:** [e.g., Top bar on desktop, bottom tab bar on mobile, active state uses primary color underline]

**Modals / dialogs:** [e.g., Centered overlay, max-width 480px, 24px padding, close button top-right]

**Tables:** [e.g., Zebra striping with neutral-100, sticky header, row hover in neutral-50]

---

## UX Tradeoffs

Documented tradeoffs that affect architecture and design decisions.

| Decision | Chosen | Sacrificed | Rationale |
|----------|--------|------------|-----------|
| [Decision area] | [What was chosen] | [What was not] | [Why] |
| [Decision area] | [What was chosen] | [What was not] | [Why] |
| [Decision area] | [What was chosen] | [What was not] | [Why] |

---

## Accessibility

Minimum requirements for this project:

- **Color contrast:** [e.g., WCAG AA — 4.5:1 for body text, 3:1 for large text and UI components]
- **Keyboard navigation:** [e.g., All interactive elements reachable and operable via keyboard]
- **Focus indicators:** [e.g., Visible focus ring on all interactive elements, not removed]
- **Screen reader support:** [e.g., Semantic HTML, aria-labels on icon-only buttons, form labels associated]
- **Motion:** [e.g., Respect prefers-reduced-motion for animations]
- **Target size:** [e.g., Minimum 44x44px touch targets on mobile]

---

## Device Targets

**Approach:** [Mobile-first | Desktop-first]

**Primary target:** [e.g., Mobile (iOS and Android) / Desktop (Chrome, Safari, Firefox)]

**Supported browsers:** [e.g., Last 2 versions of Chrome, Firefox, Safari, Edge]

**Minimum viewport width:** [e.g., 320px]

**Notes:** [Any device-specific constraints — e.g., must work on older Android devices, or tablet layout is not required]
