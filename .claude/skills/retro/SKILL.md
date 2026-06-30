# Retro — turn this session's wasted time into a durable rule

> The user just told you a session went badly — they had to push back on the same kind of mistake more than once, or call out something obvious you missed. Reading that message and apologizing is not the response. Updating the skill / doc that would have caught it IS the response — so the next session doesn't repeat.
>
> The output is a small, surgical edit to ONE skill or `CLAUDE.md`. Not a new document. Not a long section. ONE rule, in the right file, terse enough that future-you actually reads it.

## When to invoke

The user explicitly asks: "learn from this", "don't repeat this", "update the skill so this stops", "/retro". Or they invoke `/retro` directly.

**Don't invoke unprompted.** Self-initiated retros are noise; the user has to confirm the session was bad enough to be worth a doc edit.

## Procedure

### 1. Enumerate the actual misses — concrete, in chat

List every distinct thing the user pushed back on this session, in their words. Three to seven items, file:line where applicable. Don't sanitize. Don't generalize.

Examples from a real session:
- "you accidentally flipped `bg-surface-1 → bg-surface-2` in TasksTable.tsx, claimed Polish clean, shipped it"
- "you used `metaColCount - 1` in Dim1RowShell after the function already baked the `- 1` in, broke timeline mode"
- "you wrote 16 CSS selectors `[data-frozen-count="N"]` when `:not(:last-child)` does the same in 1"
- "you claimed `/rethink-and-simplify` ran clean but I found 4 real bugs in the next 30 seconds"

If you can't list ≥2 concrete misses, the session probably didn't need a retro. Stop and say so.

### 2. Classify each miss

For each item, mark exactly one:

- **doc-gap** — the rule that would have caught this isn't written down anywhere. Doc edit will help.
- **already-documented** — the rule IS in a skill, you just didn't follow it. Doc edit will NOT help; the failure was discipline. Say so out loud.
- **tooling-gap** — no doc edit could have prevented it; the harness / tool is the issue.

Most session misses are **already-documented**. That's the uncomfortable answer. Resist the urge to add a paragraph "just in case" — duplicate rules dilute the signal of the originals.

### 3. For doc-gaps only: write the smallest possible edit

One bullet, max ~80 words, in the right file. If you can't decide which file, the rule probably belongs in the most specific skill — not `CLAUDE.md`, not the orchestrator (`/project-task`, etc).

Concrete examples of right-sized edits:

- A new bullet under an existing smell-catalog header in `/rethink-and-simplify`.
- A new line under "Hard rules" in `/enforce-coding-guideline`.
- A new bullet in `CLAUDE.md`'s "Important Rules" — ONLY if the rule is project-wide (deployment, repo conventions, scripts), not skill-specific.

Wrong-sized edits (don't do these):

- A new ## section. If the lesson needs a whole section, it's probably already covered somewhere and you're duplicating.
- A new skill. The threshold for a new skill is "a complete workflow with multiple steps invoked by name", not "a lesson learned."
- Adding the lesson to `CLAUDE.md` when a skill SKILL.md is the natural home. `CLAUDE.md` is effectively in the system prompt — every paragraph there is paid for on every turn forever.
- Re-stating an existing rule with slightly different wording. Re-read the target file before editing; if the rule is already there, the failure was discipline (case 2), not docs.

### 4. Read the target file BEFORE editing

Always. The most common retro failure is adding a rule that's already in the file three paragraphs up. If the rule is already there, mark this miss as **already-documented** and skip the edit — say so to the user explicitly: "this is in `<file>:<line>`. The failure was me not following it, not the doc."

### 5. Report

One short paragraph per miss:

```
- bg-surface-1 → bg-surface-2 accidental flip
  → already-documented (rethink-and-simplify step 1 "A intent: every changed token confirmed intentional"). Discipline gap, no edit.

- N-case switch where cases differ only in data
  → doc-gap. Added one bullet to rethink-and-simplify smell catalog (RESHAPE Strong).

- "Polish complete" without per-hunk verdicts in chat
  → already-documented (rethink-and-simplify step 1 "If your chat output for pass 1 does not contain one verdict line per hunk, the audit didn't happen"). Discipline gap, no edit.
```

Don't write a summary. Don't pad. The user wanted the rule recorded, not a recap.

## Hard rules

- **Be honest about discipline gaps.** If the rule is already documented and you ignored it, name that explicitly. Adding the rule a second time will not make future-you read it; admitting the failure mode might.
- **One bullet per lesson, max.** If you find yourself writing "1. … 2. … 3. …" inside one edit, you're adding a section, not a bullet — go back to step 2 and split or drop.
- **Don't edit `CLAUDE.md` unless the rule is project-wide.** Skill-specific lessons belong in the skill, where they're loaded only when relevant. The system prompt has a tight budget.
- **Don't create a new skill from a retro.** New skills are for new workflows, not for "I really want to remember this."
- **No new files unless explicitly asked.** A retro produces edits to existing files, not new ones.
- **Resist the urge to retroactively document everything.** The point is to capture the lesson that would have saved the session — not the lesson, plus three adjacent lessons, plus a section header, plus an example for each. One bullet. The next miss can add the next bullet.

## Worked example

User: "/retro — you wasted half this session re-doing the same Polish pass."

1. Enumerate:
   - accidental token swap (bg-surface-1 → bg-surface-2) survived two claimed Polish passes
   - off-by-one (`K - 1` left in callers after `K` became a hook)
   - 16 CSS selectors keyed off `data-frozen-count` instead of `:not(:last-child)`
   - N-case switch bloat in TaskRow/Header (8 cases each, wrapping identical divs)

2. Classify:
   - token swap → **already-documented** (rethink step 1 A-intent check)
   - off-by-one → **already-documented** (rethink step 1 B-math worked example calls out exactly this)
   - 16 CSS selectors → **doc-gap** (smell catalog has no entry for "N variants of the same selector with one numeric value differing")
   - N-case switch → **doc-gap** (related to above, same shape — "N branches that differ only in data")

3. Edit (one bullet, in rethink-and-simplify smell catalog under RESHAPE Strong):

   > **N-case switch / if-chain where cases differ only in data.** Eight branches that each wrap an identical `<div className=…>` around a different cell, varying only in 2–3 props → pull the wrapper out and look up the inner via `Record<Id, (ctx) => Node>`. The same smell in CSS: 16 selectors keyed on `[data-count="N"]` → collapse via `:not(:last-child)` / `:has()` / a CSS variable when the predicate has one algebraic form.

4. Report:

   ```
   - token swap: already-documented (rethink step 1 A). Discipline gap.
   - off-by-one: already-documented (rethink step 1 B worked example). Discipline gap.
   - 16-variant CSS / 8-case switch: doc-gap → one bullet added to rethink RESHAPE Strong.
   ```

Two of four lessons are discipline gaps, named as such. One bullet added. No new files. Done.
