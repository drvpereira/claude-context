---
name: accessibility
description: Web and mobile accessibility rules. Use when building or reviewing any UI feature — covers semantic HTML, ARIA, keyboard navigation, focus management (web) and accessibilityLabel, accessibilityRole, touch targets, screen reader support (mobile). Has web and mobile profile sections.
---

# Accessibility

Universal accessibility canon for frontend work. Sections labelled **[Web]** or **[Mobile]** apply to one platform only.

## When to Use
- Building any new UI feature — web or mobile
- Reviewing UI changes for keyboard navigation, contrast, focus management, screen-reader behaviour
- Pairing with UX/UI Designer on flow-level accessibility before sign-off
- Pre-release accessibility audit

---

## [Web] — Web Accessibility

- Use semantic HTML — `<button>` not `<div onClick>`, `<nav>`, `<main>`, `<section>` with labels
- Every interactive element must be keyboard-reachable and operable without a mouse
- All images need `alt` text; decorative images use `alt=""`
- Form inputs must have associated `<label>` — never rely on `placeholder` alone
- `aria-label` or `aria-describedby` on elements whose visible text is insufficient
- Focus management: trap focus in modals, return focus to trigger on close
- Never suppress focus outline globally — style it, do not remove it
- WCAG AA: 4.5:1 text contrast, 3:1 UI contrast, focus states, alt text/aria-label, keyboard navigation, form labels

## [Mobile] — Mobile Accessibility

- `accessibilityLabel` on every touchable element whose visible text is absent or insufficient
- `accessibilityRole` on interactive elements (`button`, `link`, `header`, `image`, etc.)
- `accessibilityHint` for non-obvious actions
- `accessibilityState` for interactive state (`disabled`, `selected`, `checked`, `busy`)
- Screen reader ordering: use `accessibilityViewIsModal` on modals; test VoiceOver (iOS) and TalkBack (Android)
- Minimum touch target 44×44pt on all interactive elements — smaller = Blocker

## Universal

- Accessibility is part of the Definition of Done — not a post-ship task
- Flow-level accessibility (focus order, screen-reader narrative, keyboard reachability) is reviewed end-to-end before sign-off, not field by field
- Coordinate with UX/UI Designer on focus order, primary actions, and any non-obvious interaction patterns

---

## Related Skills

- `frontend-conventions` — paired implementation rules for React (web) and React Native (mobile)
