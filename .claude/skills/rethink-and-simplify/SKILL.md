---
name: rethink-and-simplify
description: Critical architectural audit of the current branch's diff. Asks "is this the simplest, most elegant approach?" — finds over-engineering, atomization, premature abstraction, schema duplication, dead branches, defensive checks for impossible cases. APPLIES every Strong + Medium finding without asking, verifies once, and loops internally until nothing material is left. Use after implementation feels done but before opening / re-pushing a PR.
---

# Rethink and Simplify

> One question, applied recursively to the diff you just wrote: **is this the simplest, most elegant approach?** If not, fix it. Loop until yes.
>
> Not style — `/enforce-coding-guideline` handles that. This skill is shape: dead code, over-engineering, frameworks funding too few callers, parallel-maintained schemas, helpers duplicating project utilities.
>
> The skill loops internally. It does NOT emit a verdict line for an outer orchestrator. It returns only when the diff is genuinely as simple as it can be.

## When to invoke

- After implementation looks "merge-ready" but **before** the human reviewer sees it.
- After a major refactor or restructure — the new layout has its own bloat and its own over-engineering.
- After every review-iteration push during an open PR.

## Procedure

Each pass is one cycle of: read diff → find what isn't simplest → apply Strong + Medium → verify if applied → decide whether to loop.

### 1. Read the diff — line-by-line, with one verdict per hunk in chat

```bash
git diff origin/main..HEAD     # committed changes
git diff                       # working tree
git status --short
```

**Skimming the diff is the canonical failure mode of this skill.** You will look at a hunk, think "looks reasonable," and miss the bug that the skim couldn't see — an accidentally-swapped token, an off-by-one in math that was correct before a constant became a function, a partial refactor where only some consumers got updated. This step is the gate that catches those. Skipping it makes the rest of the skill worthless.

For every changed file, open it with the Read tool (not just the `git diff` excerpt — surrounding context is where the bug usually shows up). For every hunk, emit ONE chat line with this exact structure before you move to step 2:

```
<file>:<line> — <one-line description of the change> — checked: <A>/<B>/<C>
  A intent: <every changed token/literal/classname/keyword in this hunk listed and confirmed intentional. If you changed `bg-surface-1` to `bg-surface-2`, name it and say WHY. If a class string was retyped, every token in the retyped string is "changed" until you've confirmed each one matches the original.>
  B math:   <if a hard-coded constant became a function/hook, walk every caller — does the caller's `K - 1` / `K + 1` / `K + extras` already get baked into the function's return value? Off-by-ones in grid-template / nth-child / Array-length math are silent at default settings and break in non-default modes (timeline on, all-extras visible, zero-visible, etc.).>
  C consistency: <if you made ONE case "special" before (the last cell, the default branch, the error path) and now compute "specialness" dynamically, EVERY consumer that referenced the old special case must be updated — not just the one you happened to think of. Grep for the old special-case name (`end_date`, `META_COL_COUNT`, etc.) and confirm.>
```

ANY hunk that fails A, B, or C → fix it as part of pass 1 (it is a Strong finding by definition).

This is non-negotiable. **If your chat output for pass 1 does not contain one verdict line per hunk, the audit didn't happen and you cannot self-terminate.** The smell-catalog pass (step 2) is what catches the residual; line-by-line is what catches the bugs.

Worked example of bugs ONLY the line-by-line read catches:

- **Accidental token swap.** A re-typed JSX line shipped `bg-surface-2` where the original had `bg-surface-1`. The smell catalog doesn't include "what was the value before." A's "every changed token confirmed intentional" does.
- **Constant→function off-by-one.** Old code: `META_COL_COUNT - 1` where `META_COL_COUNT = 6` (timeline-on path). Refactored to `useMetaColCount()` that already returns 5 (post-collapse). The consumer still does `metaColCount - 1` → renders 4. Subgrid breaks silently the moment timeline turns on. B catches it.
- **Partial last-element handling.** Old code: one cell (`end_date`) had no `border-r` because it was always rightmost. New code: rightmost is dynamic. But only the `end_date` case got the dynamic check; the `PlainHead` for `related_people` / `counterparts` still unconditionally renders `border-r`. C catches it.

### 2. Ultra-think against the smell catalog

Group findings as **Strong** / **Medium** / **Minor**. Inside each rank, order by impact.

**Strong — always flag:**

DELETE — code that shouldn't exist:
- **Dead branches.** Paths no caller can reach. `if (x === undefined)` where the type guarantees `x` is defined. `default:` cases for exhaustive unions. Fallback values for required parameters.
- **Defensive checks for impossible cases.** Internal code re-validating what a typed caller already proved. Trust internal code; only validate at system boundaries.
- **One-shot helpers.** A `formatX()` used in exactly one place — inline it. Three similar lines beats a premature abstraction with a name.
- **Comments that restate the code.** `// increment counter` above `counter++`. Delete.
- **Half-finished scaffolding.** Empty `else` clauses, `TODO: implement` blocks shipped alongside a "complete" feature, commented-out alternatives.
- **Backwards-compat shims for code you control.** Renamed `_oldName` re-exports, `// removed in vX` comments, fallback branches for an API version no caller uses.

RESHAPE — architecture that's wrong:
- **Framework funding 1–2 use cases.** `BlockDef<TType, TFields, TInput, TApprovedExtras>` generic over 4 type params for 2 instances is paying upfront for speculative variants. If the speculated variants would have a different shape than the framework supports, the framework is paying for nothing.
- **Atomization without payoff.** Splitting one 200-line file into six 50-line files when the methods share constants and patterns. Grep-ability doesn't replace side-by-side comparison.
- **Schemas / types maintained in parallel.** `fields` + hand-maintained `input` (= partial of fields). `params` + `fields` + `input` — three flavors of the same shape, drift bait. Derive (`fields.partial().optional()`).
- **Duplicate state declarations.** Every block has the same N-way kind union → shared type alias, declared once, used N times.
- **N-case switch / if-chain where cases differ only in data.** Eight `case` branches that each wrap an identical `<div className=…>` around a different cell component, varying only in 2–3 props → pull the wrapper out and look up the inner via `Record<Id, (ctx) => Node>`. A `switch` reads as code, but if the only thing changing per branch is a config tuple, it IS data — express it as a table indexed by the union, render via one helper. Repeating CSS variants keyed on a finite attribute (`[data-count="1"]…[data-count="8"]`) is the same smell — collapse via `:not(:last-child)` / `:has()` / a CSS variable when the predicate has a single algebraic form.
- **Helpers duplicating project utilities.** A new date formatter when `lib/date.ts` already has one. A new fetch wrapper when there's a typed client. Always grep for the utility *before* writing a new one.
- **In-place edits to immutable artifacts.** Editing migrations already applied. Editing released contracts. Schema drift between dev and prod.
- **Inconsistent gating / scope mismatch.** PR titled "user-verified actions" but only half the actions are verified. Either gate all (matches title), or scope title down (matches scope).
- **Sibling instances of the anti-pattern you're fixing.** When the bug IS a systemic shape (unbounded fetch, N+1 query, O(N²) on user data, missing pagination, full-table load), the fix is incomplete until you grep for sibling occurrences in the same surface and fix or list them. "Fixed the one the user pointed at" leaves the page slow when the user opens a sibling. Run the grep BEFORE declaring the diff done, not after the user yells.
- **External-shell sidesteps to project abstractions.** `docker exec psql` to seed test state when the project has typed repos. Raw curl in an e2e scenario when there's a typed harness.
- **Generic-pinning tricks with unused parameters.** HOCs whose only purpose is `_type: T` to pin a generic.

**Medium — flag if clearly worth it:**

- **Redundant state.** Two variables that always move together (`isLoading` + `status === "loading"`). One source of truth.
- **Validation duplicated across layers.** Same zod check at controller and at repo. Validate at the boundary.
- **Custom UI components re-implementing primitives.** `TextField` with raw `<input>` styling when `@/components/ui/input` exists.
- **Wide-cast dispatchers with clustered eslint-disables.** Sometimes the right answer IS a wide cast; but if `as Record<string, unknown>` appears 4 places, a `switch` may give type safety.
- **Mixing backend identity with editable fields.** `userSkillId` / `threadId` in the same schema the user can submit edits to → split into `meta` (immutable) + `fields` (editable).
- **Half-extracted abstractions.** A `chatAndWait` that returns `messages` but not `sessionId` because the original use case didn't need it.

**Minor — note, don't insist:**

- `Result<T, E>` used as if `.success` is the value (it's the boolean).
- Inherited prompts that don't apply (cosmetic).
- Premature splits (`lib/seeds.ts` vs `lib/harness.ts` when there's only one seeder).
- Single-line comments above obvious code.

### 3. Apply Strong + Medium — without asking

Use Edit. **Do not write "Want me to apply?"** — the user invoked this to GET fixes, not approve them one by one.

Order: DELETE fixes first (they shrink the diff and may invalidate later RESHAPE findings), then RESHAPE fixes. Inside each, apply by descending impact.

If a fix expands scope beyond the PR's intent, note it as a follow-up and **don't apply**.

Minor findings: skip by default. Apply only if trivial.

### 4. Verify — only if fixes applied

If any Strong / Medium fixes were applied, run the project's lint + typecheck commands ONCE at the end. Look for `package.json` scripts (`"lint"`, `"typecheck"`, `"check"`, `"build"`) or common configs (`tsconfig.json`, `biome.json`).

If verification fails, fix forward in this same pass.

If no fixes were applied, **skip verify entirely.**

### 5. Decide whether to loop

After applying + verifying, ask: **would another pass on the current state find something material?**

- DELETE/RESHAPE just changed the shape of the diff → very likely another pass surfaces atomization that wasn't visible before, or new dead code created by deletion. **Loop.**
- This pass found only Minor / nothing → **stop.**

Loop = go back to step 1 with the post-fix state. No outer orchestrator decides this — the skill self-terminates.

Hard ceiling: 3 internal passes. After pass 3, stop regardless. (In practice, pass 3 finds nothing.)

### 6. Final report

Single concise report. Format:

```
Pass 1 — applied:
- [delete] <file>: <fix>
- [reshape] <file>: <fix>
...
Pass 2 — applied:
- ...
Pass 3 — nothing material.

Verify: lint clean, types clean.   (or "skipped — no fixes applied")
```

No VERDICT line. The skill has already self-terminated by the time you write this.

## Hard rules

- **No diplomacy.** "This is over-engineered." "This is duplication." "This is dead code." Soft critiques are invisible critiques.
- **No vague findings.** Every finding cites file:line and the concrete fix. "Consider simplifying X" is not a finding. "Drop the 138-line framework in `blocks/define.ts` — per-block module = ~50 lines total" is.
- **Bias toward removal.** The simpler version (fewer files, abstractions, types, parameters, lines) is usually right. Adding back a deleted abstraction is cheap; carrying a wrong one compounds.
- **Don't expand the PR.** Out-of-scope findings → mark as follow-up, don't apply.
- **Don't second-guess the user.** If they said "the framework stays" in an earlier turn, the framework stays.
- **Stop in finite time.** Cap is 3 passes. Pass 3 finding only `Record<string, unknown>` quibbles means you've over-looped — stop at the end of pass 2.

## Anti-patterns

- **Don't ask "should I apply?"** The user invoked the skill to get fixes. Just apply.
- **Don't verify per-fix.** One verify at the end of a pass, not after every change.
- **Don't re-find what you already fixed.** Each pass is on the current state.
- **Don't recommend everything.** Some findings are real but out-of-scope. Mark as follow-up, don't apply.
- **Don't loop on cosmetics.** If pass N surfaces only `Record<string, unknown>` nits, stop.

## Worked example

**Pass 1** on a feature branch (~500 LoC):

DELETE:
- `userController.ts:42-58` — defensive `if (!user)` after auth middleware already throws
- `messageHandler.ts:91` — empty `else {}`

RESHAPE:
- `blocks/define.ts` — 138-line framework for 2 blocks. Per-block module = ~50 lines total. **Strong.**
- `params/fields/input` — three schemas, same shape. Derive `input = fields.partial().optional()`. **Strong.**

Applied. Verify clean. → Loop (the reshape changed enough that another sweep might find atomization).

**Pass 2:**

- `chatAndWait` missing `sessionId` in return — Medium
- Over-atomized 6 per-block files → consolidate to 2 — Strong

Applied. Verify clean. → Loop.

**Pass 3:** nothing material. Stop.

Done in 2 effective passes.
