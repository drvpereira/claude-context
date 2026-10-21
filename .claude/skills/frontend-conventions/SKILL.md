---
name: frontend-conventions
description: Shared rules for React (web) and React Native (mobile) — state management, OpenAPI contract, pagination, UI states, forms, i18n, error handling, observability, performance. Has web and mobile profile sections where rules diverge. Use when implementing or reviewing any frontend feature.
---

# Frontend Conventions

Canonical frontend rules shared between Senior React Engineer (web) and Senior React Native Engineer (mobile). Sections labelled **[Web]** or **[Mobile]** apply to one platform only; all other rules are universal.

## When to Use
- Implementing any new React (web) or React Native (mobile) feature
- Reviewing frontend code for state management, OpenAPI typing, pagination, forms, error handling
- Designing the data layer for a new screen or component
- Onboarding a new engineer to the frontend conventions

---

## Project Structure & State Management

```
src/features/payment/
├── api/         ← React Query hooks
├── components/
├── screens/     ← [Mobile only]
└── store/       ← Zustand slice (only if needed)
```

- Server state: React Query only — never raw fetch in components
- Shared UI state: Zustand — only when used across >1 component (**[Mobile]**: >1 screen/component)
- Local state: useState/useReducer
- Never prop-drill >1 level — if passing through without using, it belongs in Zustand/React Query
- All async logic in custom hooks — nothing async in components (**[Mobile]**: nothing async in screen/component bodies)

## OpenAPI Contract

- Generate typed client from backend spec — infer tooling, default to `openapi-typescript` + `openapi-fetch`
- Never raw fetch with manually typed responses
- Regenerate on backend spec change — never patch manually
- Broken generated types → flag contract violation to Architect, do not use `any`
- v2 API behind flag: toggle the flag, keep v1/v2 calls separate
- Existing HTTP client for existing features untouched — typed client for new features

## Pagination

Every list view: pagination from first implementation. Always pass `page` + `size`. Scroll to top on page change.

- **[Web]**: Page navigation or infinite scroll per UX spec.
- **[Mobile]**: `FlatList` with `onEndReached` for infinite scroll or explicit page controls per UX spec.

## UI States

Every component (**[Mobile]**: screen and component) that touches async data must handle all four states:

- **Loading**: skeleton loaders (match existing patterns)
- **Empty**: explicit empty state — never show a blank page/screen or a loading spinner that never resolves
- **Error**:
  - **[Web]**: boundaries for crashes, inline for validation/recoverable — choose per user impact
  - **[Mobile]**: inline for recoverable errors, full-screen for fatal failures — choose per user impact
- **Success**: the happy path — must not be the only state that is implemented

## Forms

- Infer form library from project — default to React Hook Form
- Validate on submit first; after the first submit attempt, re-validate on blur so errors clear as the user corrects them
- Never reset form state until the server confirms success

**[Web]**:
- Controlled inputs for dynamic fields; uncontrolled only for fully static forms with no validation

**[Mobile]**:
- `KeyboardAvoidingView` required on all forms — behaviour differs between iOS and Android, test both
- Wrap in `ScrollView` to ensure all fields remain reachable when the keyboard is open
- Set `returnKeyType` and `onSubmitEditing` to allow keyboard-based navigation between fields
- `secureTextEntry` on all password and sensitive input fields

## i18n

- All user-facing text internationalised — infer library, default `react-i18next`
- Keys use backend enum values: `status.PENDING_REVIEW`
- Update all language files before done — infer location from project (e.g. `src/i18n/locales/en.json`)
- **[Web]** rich text: `Trans` wrapper — never `dangerouslySetInnerHTML`

## Error Handling

- All validation errors at once — never one at a time
- Field-level errors inline next to field — never only in toast/banner
- API errors mapped back to fields when backend provides field names
- Never clear errors until user corrective action

## Observability

- User-facing errors logged with context — never swallowed
- Distinguish three categories in UI feedback and logs: 4xx (client error), 5xx (server error), network/timeout (no response)
- **[Mobile]**: Crash reporting integration verified on all new flows

## Coding Standards

- Match existing code style before writing
- Thin components (**[Mobile]**: thin screens): no business logic inline in JSX — extract to custom hooks
- Feature-based packaging: minimal cross-feature imports
- Document non-obvious logic only — self-documenting names are preferred over comments
- No magic strings — typed constants. TypeScript strict mode. **[Mobile]**: no `any` without justification + comment.

## Quality Gates

- **[Web]**: Storybook story per new component (default, loading, empty, error states)
- **[Web]**: `data-testid` on every interactive/testable element — missing = Blocker, don't wait for QA
- **[Mobile]**: `testID` on every interactive/testable element — missing = Blocker, don't wait for QA
- **[Mobile]**: Detox or Jest + RNTL tests per QA's test plan

## Performance

**[Web]**:
- `React.memo` only when profiling confirms unnecessary re-renders — not by default
- `useMemo` / `useCallback` only for referentially stable values passed to memoised children or used as effect dependencies — not for minor computations
- Code-split at route level with `React.lazy` + `Suspense` — infer existing pattern from project
- Never import an entire library when a single function is needed — check tree-shaking impact
- Flag any new dependency that adds >10 kB gzipped to the bundle — raise to Architect before adding

**[Mobile]**:
- `FlatList` or `SectionList` for all lists of unknown length — never `ScrollView` over a mapped array
- `keyExtractor` must return a stable, unique string — unstable keys cause full list re-renders
- `getItemLayout` for fixed-height list items — eliminates expensive item measurement
- Images: use `expo-image` or `react-native-fast-image` for caching — never bare `<Image>` for remote URLs
- `useMemo` / `useCallback` only for referentially stable values passed to memoised children or used as effect dependencies — not for minor computations
- `InteractionManager.runAfterInteractions` for non-urgent work triggered by navigation transitions
- Flag any new dependency that adds measurable JS bundle size — raise to Architect before adding

## Mutations & Server State

- React Query mutations: use `useMutation` with explicit `onSuccess` / `onError` handlers; invalidate related queries on success — never leave the cache stale after a mutation
- Optimistic updates only when the UX spec explicitly requires them; default to pessimistic (wait for server confirmation)
- Never bypass React Query for data that should be server-authoritative — do not hold server state in `useState`
- Loading and error states must be wired for every async operation before marking a task done

## Test Execution

Unit + integration in parallel. E2E only when both pass.

---

## Related Skills

- `accessibility` — web and mobile accessibility rules paired with these conventions
- `mermaid-diagrams` — diagrams for frontend specs (navigation flows, component graphs)
- `http-semantics` — status codes and error formats the frontend handles
