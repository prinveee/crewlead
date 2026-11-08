<!-- crewlead:plan -->
## Implementation plan — #<issue> (v1)

**In short:** <!-- Two or three plain lines: what changes, for whom, and what stays the same. -->
<!-- A re-plan edits this comment in place: (v<k>) in the title, and here one line per version:
     **v<k>:** <what changed> — <why> (planner.md §6). -->

**Lane:** Bug | Feature | Story · **Size:** S | M · **Autonomy:** A2 | A3
**Spec:** this issue | `<path to the spec file (BMAD story or specs.docs)>`

**For you before `/go`:**
<!-- 1–5 one-line bullets: decisions only a person can make, risks, protected
     paths, new dependencies, anything that changes how people work.
     "Nothing special." when there is none. -->

<details><summary>Full plan (for the implementor)</summary>

### Context
<!-- Root cause (bug) or what exists today (feature). Files you read. -->

### AC → test map
| AC | Rules | Test (file › name) | Red shown by | Status today |
|---|---|---|---|---|
| AC-1 | BR-… | `tests/…/x.test.ts` › "…" | `test_local` \| CI, step 2 | new — fails until step 3 |

Callers checked: <!-- tests, fixtures, seeds that use what changes; each one that breaks has a step. -->

### Design
<!-- Feature M and Story only; delete for bugs and size S.
     - Components / files: what is added or changed, and how they connect
     - Data model: tables, columns, constraints, migrations
     - Interfaces: API routes, payloads, function signatures
     - Errors: what can fail and what the user sees
     - Test strategy: which level (unit / integration) proves which AC -->

### UI
<!-- Delete when the change has no UI.
     design: none → what each new screen looks like, and which existing components it reuses.
     With frames → | Frame (link, or "none — designed from <nearest frame>") | State | Built from (component / new) | -->

### Steps
- [ ] 1. Write the failing test(s) for AC-1 in `…` (bug: reproduce it first)
- [ ] 2. In `src/…`, change `functionName` to …
- [ ] 3. …

### Do NOT touch
- `…` (why)

### Steering and business rules
No change. | `.ai/steering/<file>.md` — what changes and why. | `BR-…` — new or changed rule, written into the rules file.

### Protected / immutable paths
None. | `<path>` — why it must change.

### Verify
```bash
<commands.lint>
<commands.typecheck>
<commands.test_local>
<commands.build>
```
CI runs the full suite.

### Stop & ask if
- <the specific risk you foresee for this change>

</details>
