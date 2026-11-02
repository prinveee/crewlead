<!-- Managed by crewlead — edit it in the crewlead repo, not here. -->
Closes #

**Approved:** <!-- link to the /go comment on the issue, or "A3 — no approval needed" -->

## What and why
<!-- One or two sentences. Bug: the root cause. -->

## AC → tests
| AC | Test (file › name) | Result |
|---|---|---|
| AC-1 | | ✅ |

## Bug: failing before, passing after
<!-- Delete for non-bugs. Paste the reproduction test failing on the unfixed code. -->

## Deviations from the plan
<!-- "None", or each change from the plan comment and why. -->

## Verified locally
```
<commands run and their result>
```

## Risk
<!-- Protected paths, business rules or decisions touched, and what a reviewer should look at. "None" is fine.
     If behaviour, a decision or the code map changed: which .ai/steering file was updated. -->

## Definition of Done
- [ ] Every AC has a passing test (or a stated manual check)
- [ ] Bug: the reproduction test failed before the fix
- [ ] CI green (lint, typecheck, tests, build, guard)
- [ ] Docs / ADRs updated where behaviour or a decision changed
