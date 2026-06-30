---
name: project-task
description: "Manage GitHub Project board issues and full lifecycle task execution. ALWAYS use this skill when the user mentions /project-task, says 'consider this a project task', describes a feature or bug to create as an issue, asks to create/list/move issues, pick an issue, start working on an issue, manage project board items, or provides a GitHub Project issue URL. Even if the user's message is long or contains other context, if /project-task appears anywhere in it, invoke this skill first."
---

# Modes

`/project-task` takes an optional first arg picking the mode: `manual` or `auto`.

- `/project-task manual` (or just `/project-task` — manual is the default) — gates on:
  - **Design approval** (Step 3) — but only for substantive work; trivial / mechanical / cleanup changes per the Step 3 carve-out skip the gate.
  - **Result check** (Step 7) — always ask.
  - **Land confirmation** (Step 10) — `AskUserQuestion("Land now or hold?")` before `cli.ts land-pr`.
- `/project-task auto` — no human gates between start and merge:
  - **Design** (Step 3) — trivial → skip doc + no gate (same carve-out as `manual`). Substantive → write the doc as a record but **proceed without asking**. The user can interrupt if they disagree.
  - **Result check** (Step 7) — skipped. E2E green → proceed straight to Polish.
  - **Land** (Step 10) — `cli.ts land-pr` fires immediately after Open PR. CI is the only gate.

Parse the mode from the args string passed to the Skill invocation. If the user typed `/project-task` alone (no arg, or any arg other than `auto`) → default to `manual`. If the user typed `/project-task auto` → run in auto mode for the entire lifecycle.

Both modes use the same Polish pipeline (Step 8), the same E2E loop (Step 6), and the same Open PR step (Step 9). The only difference is which gates block.

# Lifecycle

```
 0. Sync main + plan      — `git checkout main && git pull`, then TaskCreate every step upfront
 1. Create issue          — (skip if user gave an issue/URL)
 2. Pick up issue         — Move to "In progress", branch from main
 3. Design                — substantive → write doc; manual mode also gates on approval; auto mode proceeds
 4. Read guidelines       — ls + Read the coding-guidelines files for the areas the design touches
 5. Implement             — write code, type-check, build, commit
 6. E2E loop              — verify end-to-end → fix on fail → loop until passes
 7. Result check          — manual mode asks AskUserQuestion(works/tweak); auto mode skips
 8. Polish                — inline /rethink-and-simplify, then inline /enforce-coding-guideline
 9. Open PR               — demo screenshots in body, no review wait
10. Land                  — manual mode asks "land now?"; auto mode fires immediately. `land-pr` waits for CI, merges, syncs main, moves issue to Done.
11. Post-land DB push     — if the diff added a migration, run `npm run -w backend db:push` to apply it to production. CI does NOT do this. **Always pair with a disruption plan.**
12. Cleanup               — stop ./scripts/e2e.ts; stop ./scripts/dev.ts if this session started it
13. Retro                 — invoke /retro INLINE via Skill tool; updates a skill / CLAUDE.md if this session's misses revealed a doc-gap
```

**Key insight:** the expensive Polish (step 8) runs AFTER the verification phase (step 6/7) — never on code that's about to be rewritten.

# Anti-getting-lost rules

1. **TaskCreate every lifecycle step before touching code — EVERYTHING is a task.** Tasks survive `/compact`; they are your memory. Missing tasks = skipped steps. Every numbered line in the canonical list (Step 0) is its own task, including **two separate Polish tasks** — one for `/rethink-and-simplify`, one for `/enforce-coding-guideline`. If you catch yourself about to act without a matching task, create the task first.
2. **State machine, not chat.** At every decision point (approve design, accept result, scope a pivot, pick a fallback), use **`AskUserQuestion` with options** — not open-ended prose that buries the decision in a paragraph.
3. **Never mark all tasks complete until Step 12 cleanup has actually run.** Always keep at least one task open. Completing all tasks makes the list vanish and you lose context. And **cleanup only runs AFTER `land-pr` returns successfully** — never as a way to exit a hold (see rule #8).
4. **Don't ask "should I continue?" between steps.** Invoking `/project-task` IS authorization to run the whole lifecycle. The only blocking gates exist in `manual` mode (Step 3 if substantive, Step 7, Step 10 land confirm). In `auto` mode there are no human gates between start and merge. Everything else just proceeds.
5. **Mid-PR pivots route through `AskUserQuestion`** (see "Mid-flow pivots" below) — never silently re-enter Step 0 or skip Polish.
6. **The Polish (step 8) is non-negotiable before opening a PR** — runs **inline in the current session via the Skill tool**: `/rethink-and-simplify` first (architectural shape), then `/enforce-coding-guideline` second (style). Do NOT dispatch these as Agent subagents — subagents re-read the whole diff cold and waste time; inline keeps the context you already have.
7. **Every background task you start, you own.** If you launch a Bash command with `run_in_background: true`, the cleanup task to `KillBash` it MUST exist in your task list before you launch it. Orphaned `tsx`/`node` pollers from prior sessions are visible in `ps` for days — don't be the source.
8. **A "hold" is a pause, not an exit. Do not run cleanup on hold.** If the user says "do it autonomously until you open PR" / "stop after PR" / "don't land yet" — OR the manual-mode Step 10 gate returns "hold" — you stop at the named step with the task list intact and dev/e2e STILL RUNNING. The user is going to come back to this same checkout to land later; tearing down dev forces them to restart it. Cleanup (Step 12) runs ONLY after `cli.ts land-pr` has successfully returned. If you find yourself about to run `./scripts/dev.ts stop` or `./scripts/e2e.ts stop` without a completed land-pr above it in this session, STOP — you're misreading "hold" as "done."
9. **`./documents/` FIRST — never open with an Explore/general-purpose agent.** This codebase documents every feature in `./documents/features/`. Before ANY code search and before spawning ANY exploration subagent, `ls ./documents/features/` + `grep -ril <keywords> ./documents/` and READ the matching design docs. They almost always hand you the architecture, the file list, and the "how to extend" path directly — which is faster and cheaper than an agent re-deriving it from the code. **Dispatching an `Explore`/`general-purpose` agent as the first investigative step is a DEFECT** — it wastes the user's time and tokens re-discovering what a doc already states. Only after the docs are exhausted may you read the specific code files they point to; only if the docs genuinely don't cover the area may you fan out with an Explore agent, and say why the docs were insufficient when you do.

# CLI

All GitHub ops go through this script. Output is JSON. Never use `gh` directly for PR/project operations.

```
~/.claude/skills/project-task/scripts/cli.ts <command> [options]
```

Has shebang `#!/usr/bin/env tsx` — call the path directly, never prefix with `tsx`.

Project settings (project ID, column IDs, repo, labels) live in `github-project.json` at repo root.

Commands you'll use: `create-issue`, `view-issue`, `update-issue`, `list-items`, `move-item`, `create-pr`, `link-pr`, `land-pr`. (`wait-for-review` and `comment-pr` exist but the lifecycle no longer invokes them — `wait-for-review` was the deprecated review-poll loop, `comment-pr` is for manual one-off comment replies.)

---

# Steps

## Step 0: Sync main, then plan tasks

**FIRST actions — no exceptions, in order:**

1. **Sync local main.** Run `git checkout main && git pull` before anything else — before reading code, before TaskCreate, before exploration. Every branch this lifecycle creates branches from `main`, every guideline file you read needs to reflect current state, and a stale main silently produces stale diffs and stale design docs. If `git checkout main` fails because of uncommitted changes on the current branch, STOP and ask the user how to handle them — don't stash/discard on your own.
2. **TaskCreate every remaining lifecycle step** before reading code, exploring, or running commands. If implementation tasks aren't known yet, create one "Read `./documents/` to plan implementation tasks" task (docs first — NOT a code-Explore task; see Anti-getting-lost rule #9), complete it, then add the rest.

**EVERYTHING is a task. There is no step that runs outside the task list.** Each numbered line below becomes exactly one `TaskCreate` call — including each Polish sub-skill, which gets its OWN task (never bundle `/rethink-and-simplify` and `/enforce-coding-guideline` into one "Polish" task). If you're about to do something and there's no task for it, STOP and create the task first. An agent reading the task list must be able to tell, at a glance, every action that remains.

Canonical task list (adapt #4–6 to actual work; gate tasks differ per mode):

```
#0  Sync main: `git checkout main && git pull` (DONE before this list is even written)
#1  Pick up issue: move to "In progress", branch, npm install
#2  Design: substantive → write doc; trivial → skip both doc and gate.
#3  (manual mode + substantive only) Design approval gate: AskUserQuestion(approve/reject) → fix → loop until approved
#4  Read coding-guidelines files that apply to the areas the design touches
#5  Implement: <file> — <what to change>
#6  Implement: <file> — <what to change>
#7  Implement: <file> — <what to change>
#8  E2E loop: verify end-to-end → fix on fail → loop until passes
#9  (manual mode only) Result check gate: show result → AskUserQuestion(works/tweak) → fix → re-verify → loop
#10 Polish 1/2: invoke /rethink-and-simplify INLINE via Skill tool — apply every Strong+Medium fix, loop until clean
#11 Polish 2/2: invoke /enforce-coding-guideline INLINE via Skill tool — apply every Strong+Medium violation, loop until clean
#12 Build + type-check + lint, commit
#13 Open PR with demo screenshots
#14 (manual mode only) Land gate: AskUserQuestion("Land now or hold?") — wait for "land" before #15
#15 Land PR (`cli.ts land-pr`): waits for PR CI, merges, waits for main CI, syncs local main, moves linked issue to Done
#16 Post-land DB push (ONLY if the diff added a migration): run `npm run -w backend db:push`. See Step 11 — required and non-trivial. If skipped, prod schema diverges from the new code shipped by CI and reads/writes will 500 the moment they touch the new column. CI does NOT run this.
#17 Cleanup: KillBash any background tasks this session started (rare without wait-for-review, but check)
#18 Cleanup: stop ./scripts/e2e.ts
#19 Cleanup: stop ./scripts/dev.ts (only if THIS session started it)
#20 Retro: invoke /retro INLINE via Skill tool — classify each miss as doc-gap / already-documented / tooling-gap; apply at most one bullet of edits per real doc-gap
```

In `auto` mode, **cancel tasks #3, #9, and #14** (the human gates) right after creating the list — don't leave them dangling. Everything else is identical and every other task still runs. **#16 (db:push) is NOT a human-gate — it runs in both modes whenever the diff added a migration.**

Rules:
- **One task per line above. The two Polish skills are two separate tasks (#10 and #11) — always.** Never collapse them.
- Each task = concrete unit of work, not a phase name.
- Include file paths in descriptions.
- Mark `in_progress` when starting, `completed` when done. Cancel n/a tasks immediately.

## Step 1: Create issue

(Skip if user gave an issue number/URL.)

```bash
cli.ts create-issue --title <title> --body-file <path> [--column Ready] [--label <label>]
```

- Default `--column Ready`.
- Body must let another agent pick up cold: context, requirements, key files, hints.
- Write bodies to `.tmp/<random>.md` (gitignored) and pass `--body-file`. Never inline multi-line markdown.

## Step 2: Pick up issue

1. `cli.ts view-issue --issue <n>` → grab `projectItemId` and `projectStatus`.
2. **Search `./documents/` FIRST — this is mandatory and comes before any code search or Explore agent (see Anti-getting-lost rule #9).** `ls ./documents/features/` and `grep -ril <keywords> ./documents/`, then READ the matching docs. Existing design docs/specs usually answer most questions — architecture, key files, the "add one X" extension path — in 10 seconds. Do NOT open the investigation by spawning an `Explore`/`general-purpose` agent; that is a defect. Read the docs, then read the specific code files they cite. Reach for an Explore agent only if the docs genuinely don't cover the area, and state why.
3. Set up branch:

```bash
cli.ts move-item --item <projectItemId> --column "In progress"
git fetch origin && git checkout main && git rebase origin/main
npm install
git checkout -b <slug-from-issue-title>
```

## Step 3: Design

First decision: **trivial or substantive?**

**Trivial — skip the doc AND skip the gate (both modes).** Post a 1-line "implementing: <one-sentence summary>" note in chat so the user sees what's coming, then go straight to Step 4. The user can interrupt if they disagree. Carve-outs:

- **Mechanical refactors.** Renames, import rewrites, extract-this-block, replace-N-instantiations-with-an-import, codemod-shaped changes. There is no design to decide; the diff IS the design. File count is irrelevant — a 26-file mechanical refactor needs a doc just as much as a 2-line one (i.e. not at all).
- **Trivial fixes** (≤5 lines, single file, obvious root cause).
- **Pure cleanup** — dead-code removal, comment fixes, formatting, dependency bumps with no behavior change.
- **Anything the issue body already explains.** If the issue already lays out the problem, approach, and key files, the design doc is just a copy. Skip it.

**When in doubt, treat as trivial.** A doc that restates the obvious wastes the reviewer's time and creates a future-rot artifact in `./documents/features/`. The bar is "does the next person reading this PR cold need this written down?" — not "did the task touch more than N files?"

**Substantive — write the doc.** A new feature, an architectural change, a bug whose root cause is non-obvious, anything where the next agent (or reviewer) genuinely needs the "why" written down. Use `/write-document` into `./documents/features/`. Include: problem, approach, key files, risks. Cite any `./documents/` files used.

**If the change includes a DB migration, the doc MUST include a "Deploy plan" section.** Migrations don't go out with CI — production is updated by a manual `npm run -w backend db:push` AFTER `cli.ts land-pr` merges. That means there's a window where the new backend code is live but the new schema isn't (CI deploys backend in ~3 min; you run `db:push` after). Anything the new code reads/writes against the new column will 500 during that window.

The deploy plan answers, in three short paragraphs:
1. **What the window looks like.** Which routes / writes will break between merge and `db:push`. Be specific — "POST /api/objectives with project_ids will 500; GET /api/objectives will not."
2. **How big is the window in practice.** Run `db:push` immediately after `land-pr` returns and the window is ~3 minutes (CI deploy time). Acceptable for low-traffic surfaces, NOT for hot paths.
3. **The disruption strategy.** Pick one and justify:
   - **Migration-first, code-second (two PRs).** PR1: migration only with the column nullable / defaulted so existing code keeps working. Land + `db:push`. PR2: the code that reads/writes the column. Land. Zero downtime, no code-vs-schema window. The default for anything user-visible.
   - **Same-PR with backward-compatible code.** Migration + code in one PR, but the new code tolerates the old schema for the window (feature-flagged, or reads/writes guarded by a "column exists?" check, or the column is added with a safe default and the code path is dormant until traffic naturally arrives). Cheaper than two PRs but the code path needs explicit defensive shape.
   - **Same-PR, accept the window.** Only for: admin-only surfaces, surfaces with no live traffic, or strictly-additive reads that gracefully degrade. Document WHY the window is OK.

If you can't articulate which of the three you're picking and why, the design isn't done. Treat that as a Step 3 gate failure in `manual` mode and fix the doc before asking for approval.

After writing a doc for substantive work, the **gate depends on mode**:

- **`manual` mode** — loop on approval:
  ```
  loop:
    AskUserQuestion({
      question: "Design at <path> ready. Approve?",
      header: "Design",
      options: [
        "Approve — start implementation",
        "Needs changes — I'll describe in next message"
      ]
    })
    if approve: break
    else: read user's reason, revise doc, loop
  ```
  Do NOT start coding until approve.

- **`auto` mode** — post a 1-line "design doc at <path>, implementing" note, then proceed to Step 4 immediately. The doc exists as a record; the user can read it and interrupt if they disagree.

## Step 4: Read the coding guidelines that apply to this change

**MANDATORY between Step 3 and writing code** — regardless of whether Step 3 wrote a doc, gated on approval, or skipped both. **You write no code, you create no file, you do not even sketch a function signature, until this step has completed in full.** If you catch yourself reaching for Edit/Write before Step 4 is done — stop, back out, finish Step 4 first. Guidelines live one-per-folder under `documents/coding-guidelines/<group>/<slug>/rule.md`. Groups: `frontend`, `backend`, `e2e`, `sharing-code`.

### What "shortcut" looks like (all of these are violations)

Every one of these has happened, and every one has produced a rule violation in the resulting PR. If you find yourself thinking any of them, you are about to fuck up:

- "I've seen this pattern in a neighbour file, that's good enough." → No. Neighbour files are not the source of truth; the rule files are. A neighbour can be wrong, a neighbour can be the very file the rule was written to fix, and you have no way to tell from reading the neighbour.
- "I'll read the rules whose slugs sound related to my task." → No. Most rules don't have slugs that map to your task's vocabulary. `don-t-name-a-type-you-use-once` doesn't sound like "saved views". `draft-state-matches-the-persisted-type` doesn't sound like "modal form". You will miss them by recall.
- "I'll grep keywords against the rule directory." → No. `search.ts` is a supplemental shortcut for **adding** rules to a list you already walked. It is NOT a substitute for the walk.
- "Polish (Step 8) will catch anything I miss." → No. Polish reviews the diff against the rules YOU say apply. If you didn't read a rule in Step 4, you won't list it in Step 8 either. Skipped here = skipped forever.
- "This rule clearly doesn't apply, I don't need to read it." → Maybe. But state the decision out loud BEFORE skipping (see step 2 below). The act of writing "skip: <slug> — <reason>" is what forces you to actually consider it instead of glancing past.

### Procedure (do every step, in order)

1. **List ALL rule names** for every group your diff touches (and `e2e` if you'll write/extend a scenario in Step 6):
   ```bash
   find documents/coding-guidelines -name rule.md | sort
   ```
   The slug path (`<group>/<slug>/`) is the rule's name — that alone tells you what each rule is about.
2. **Walk the full list and decide, rule-by-rule, whether it applies to your diff.** Print the verdict in chat for EVERY rule — not just the ones that apply. Format:
   ```
   apply: backend/all-db-access-goes-through-a-per-feature — new repository for tasks_views
   apply: frontend/don-t-name-a-type-you-use-once — modal has a Props interface
   skip:  frontend/never-input-type-date-time-datetime-local-use — no date inputs
   skip:  backend/cross-table-sql-objects-belong-in-the-target — no SQL functions
   ...
   ```
   The verdict line must mention the slug. "I read the relevant rules" is not a verdict. **If your chat output doesn't contain one verdict line per slug in the listing, you have not done step 2.**
3. **Read the `rule.md` of every rule you marked `apply`, front to back.** Skim is not read. After reading, also run `check.sh` where one exists (sibling of `rule.md`).
4. Carry the relevant rules into Step 5. Polish (Step 8) audits the diff against these same rules later — every rule you break in Step 5 becomes a Polish finding that forces a rewrite. **Every Polish finding that fires on a rule you marked `skip` in Step 2 is a Step 4 failure to admit out loud.**

### Self-check before leaving Step 4

Before you mark Step 4 complete and touch any file, ask yourself: "If the user opens the chat log right now, do they see one verdict line per slug in the rule listing?" If the answer is no, you are not done with Step 4. Go back and finish.

The `check-guidelines` skill can drive this whole procedure; you may invoke it instead of doing the walk by hand. Either way, the verdict lines must end up in the chat — that's the gate, not which tool produced them.

## Step 5: Implement

Write code per the design. For each subtask: mark `in_progress`, edit, mark `completed`.

Build + type-check + lint as you go (`npm run build:types -w <pkg>`, `npm run lint -w <pkg>`, `npm test -w <pkg>` if tests exist). Don't run `/rethink-and-simplify` or `/enforce-coding-guideline` yet — those are step 8 after the user has confirmed behavior.

Commit when work is in a coherent state.

## Step 6: E2E loop

**Verify end-to-end** — type-checks and unit tests are not verification.

**Before the loop, open the local dev URL for the user.** Once the dev server is ready (or after starting it), run `open "<dev-url>"` using the URL reported by `./scripts/dev.ts status` / `./scripts/dev.ts start` (for example, `open "http://astra-4.localhost:4310"`). Do this even in `auto` mode so the user can watch or spot-check without hunting for the URL. If the change's observable surface is a specific route, open that route directly (for example, `/tasks`).

**Preferred path: write a scenario, run it, debug from the screenshots.**

If the repo has an `e2e/` directory with `npm run e2e` (TSS-stack-template shape):

1. Write `e2e/<scenario>.ts` default-exporting a `Scenario` (or `harness()`-wrapped body for multi-step verification).
2. Capture **`page.screenshot({ name, fullPage })`** at every meaningful checkpoint: after `goto`, after each user action, right before a flaky assertion. Names get a numeric prefix so they sort by execution order — `0_initial_load`, `1_after_login`, `2_modal_open`. Files auto-save to `e2e/fixtures/<scenario>/<name>.png` (wiped + recreated per run, checked into git).
3. Run with `npm run e2e <scenario>` (auto-starts headless Chrome; dev server must already be up via `./scripts/dev.ts start`).
4. **On fail, READ THE SCREENSHOTS FIRST.** `e2e/fixtures/<scenario>/*.png` is the primary debugging surface — last image tells you the state right before the failure. Do not re-run with random changes hoping it works; do not add `console.log`s blindly. The Read tool renders PNGs natively.
5. Loop: fix → rerun → break on pass.

**Existing harnesses:** if an `e2e/<domain>.ts` already exists for the surface you touched, extend it instead of creating a parallel scenario.

**Per-category fallback (no e2e/ shape):**
- **Frontend UI** — dev server + browser, click through the user flow. Screenshot whatever you'd attach to the PR.
- **Backend HTTP** — curl the edge proxy URL with auth headers if needed; verify status + body.
- **Agent skill / prompt** — `POST /api/chat`, poll `GET /api/chat/:id` until `current_run_id == null`, confirm the LLM actually uses the new tool/behavior. The proof is the next turn changing, not a `.d.ts` diff.
- **DB migration** — reset, regen types, exercise the new column/index/constraint with realistic data.
- **Script/CLI** — run it the way a user would, verify exit code + side effect.
- **Library/util** — exercise the nearest real consumer, not the util in isolation.

If the change has **no observable runtime surface** (pure docs, type-only declarations no consumer reads), say so explicitly in the verify task — don't silently skip.

## Step 7: Result check

**`manual` mode** — show the user what you verified (screenshot, demo, curl output, agent transcript — whatever's appropriate) and ask:

```
loop:
  AskUserQuestion({
    question: "Verified <feature> end-to-end. Result matches what you wanted?",
    header: "Result check",
    options: [
      "Yes — proceed to code review + PR",
      "Needs tweaks — I'll describe in next message"
    ]
  })
  if yes: break
  else: read user's reason, fix → back into Step 6 → return here
```

Only proceed to Step 8 after explicit "yes."

**`auto` mode** — skip the gate. Post a 1-line summary of what was verified (e.g. "E2E green: <scenario>. Proceeding to Polish."), then go straight to Step 8.

## Step 8: Polish — rethink, then enforce guidelines

**Run both skills inline in THIS session via the Skill tool.** Do NOT dispatch them as Agent subagents — a subagent re-reads the entire diff cold, re-discovers the guideline files, and burns turns rebuilding context you already hold. Inline is strictly faster here.

Order is non-negotiable: `/rethink-and-simplify` first (architectural shape, may delete/restructure whole files), then `/enforce-coding-guideline` second (style, against the now-stable shape). Running style first means the style work gets discarded by the reshape; running rethink first means style fixes apply to the final shape.

Each skill **loops internally** until clean — no outer pass-cap, no VERDICT line to parse.

**Carve-outs (skip Polish entirely):**
- Pure CSS value changes (≤10 numeric/color/spacing tweaks, no new selectors).
- Docs-only changes (`.md` files, no code paths affected).
- Test/fixture-only changes that don't touch production code.

For everything else — **these are TWO separate tasks (#10 and #11), run one after the other:**

**Task #10 — `/rethink-and-simplify`:** mark the task `in_progress`, **invoke `/rethink-and-simplify` via the Skill tool**, let it run its internal loop (read the diff, apply every Strong + Medium DELETE/RESHAPE finding, verify, loop until nothing material), commit any fixes it applied, then mark the task `completed`.

**Task #11 — `/enforce-coding-guideline`:** mark the task `in_progress`, **invoke `/enforce-coding-guideline` via the Skill tool**, let it walk every applicable guideline heading-by-heading against the now-stable diff (apply every Strong + Medium violation, verify, loop until clean), commit any fixes it applied, then mark the task `completed`.

**Never bundle these two into one task.** Each is a distinct, separately-tracked unit so the task list always shows which half of Polish has run.

**Why this order, run sequentially:** rethink may delete or restructure whole files; doing it first means the style pass audits the final shape instead of code that's about to change. Run them one after the other (not interleaved) so each works against a settled tree.

**If a skill reports it found nothing:** that's the expected steady state, not an error. Move on.

## Step 9: Open PR

**Browser tabs the user is going to look at — open them, don't make the user hunt for URLs:**

- **BEFORE creating the PR**, open the local dev URL so the user can spot-check the feature in the running app. Use the URL reported by `./scripts/dev.ts status` / `./scripts/dev.ts start` — for example, `open "http://astra-4.localhost:4310"` (or the specific route the change affects). This is mandatory in both modes. If you already opened it in Step 6, opening again is fine — `open` reuses the tab.
- **AFTER `cli.ts create-pr` returns**, immediately `open "<pr-url>"` with the URL from its JSON output. Mandatory in both modes. The user needs the PR tab whether they're reviewing, landing, or holding.

Then:

1. **Verification artifacts** (frontend / UI-observable changes): your Step 6 screenshots are already committed at `e2e/fixtures/<scenario>/*.png` — GitHub renders them inline in the PR diff. Just reference them in the PR body so the reviewer doesn't have to hunt:

   ```markdown
   ## Verification

   `e2e/<scenario>.ts` run end-to-end. Screenshots checked in at `e2e/fixtures/<scenario>/`:
   - `0_initial_load.png` — clean page state
   - `1_after_action.png` — feature working
   ```
2. Create PR (`--issue` required, `--body-file` required — write to `.tmp/<random>.md`):

   ```bash
   cli.ts create-pr --title "<title>" --body-file <path> --issue <n> --reviewer breath103
   ```

3. `cli.ts move-item --item <id> --column "In review"`
4. Proceed straight to Step 10 (Land). No review-wait loop.

## Step 10: Land

The review-wait loop is gone. PR opens → land. CI is the gate, not human review.

Before any land decision or auto-land, open the PR URL for the user with bash: `open "<pr-url>"`. This is mandatory in both modes so the user doesn't have to copy/check the URL manually.

**`manual` mode** — ask before landing:

```
AskUserQuestion({
  question: "PR opened at <url>. Land now or hold?",
  header: "Land",
  options: [
    "Land now — `cli.ts land-pr` runs immediately (waits for CI, merges)",
    "Hold — exit lifecycle here; user lands manually later"
  ]
})
```

If "hold" → skip directly to Step 12 (Cleanup) and tell the user how to land later (`cli.ts land-pr` from this repo root). If "land now" → continue below.

**`auto` mode** — no gate. Go straight to `cli.ts land-pr`.

Then:

```bash
cli.ts land-pr
```

Run bare. **Don't pipe through `tail` or merge stderr with `2>&1`** — the command ends with single-line JSON `{landed, pr, linkedIssues}` on stdout; tail/redirect breaks it. The noisy middle is `gh pr checks --watch` streaming live CI; ignore it.

`land-pr` waits for PR CI, merges (merge commit), waits for main CI, syncs local `main`. After it returns, confirm `git status --short --branch` shows local `main`, not detached HEAD.

Then if there's a linked issue: `cli.ts move-item --item <id> --column Done`. If no linked issue/project item exists, say so and skip — don't go fishing.

## Step 11: Post-land DB push (migrations only)

**Skip this step if the diff did NOT add a migration.** Check with:

```bash
git diff origin/main..HEAD~ --name-only -- 'packages/backend/supabase/migrations/**' | head
```

If nothing prints, skip to Step 12.

If a migration is in the diff, **understand the constraint up front:**

> CI deploys backend code automatically. CI does NOT apply migrations. Production schema only moves when someone runs `npm run -w backend db:push` from a local checkout linked to the remote project. That someone is you. Right now.

The window between `cli.ts land-pr` returning and you running `db:push` is exactly the production-disruption window the design's "Deploy plan" (Step 3) was supposed to cover. Re-read the plan you wrote. Then act:

1. **Confirm local main is up to date.** `git status --short --branch` should read `## main...origin/main`. If it doesn't, `git checkout main && git pull` first — `db:push` reads migration files from the working tree.
2. **Run the push:**
   ```bash
   npm run -w backend db:push
   ```
   Forward-only. NEVER pass `--reset` or any flag that touches remote state. If you don't know what a flag does, don't pass it.
3. **Verify.** `db:push` prints the migrations it applied. Confirm the expected file is in that list. If it says "Remote database is up to date" but you expected your migration, the linked project is wrong — STOP and tell the user.
4. **If the migration fails on remote** (constraint violation on existing rows, missing dependency, anything): the production schema is now partially-mutated and the new backend code is live. Tell the user immediately with the exact error. Do NOT try a destructive rollback (`supabase db reset` against remote is never the answer). Most often the fix is a follow-up migration that resolves the bad state forward.

In `manual` mode, ask before running:

```
AskUserQuestion({
  question: "Land done. Migration <file> needs `db:push` to reach prod (CI doesn't run it). Push now?",
  header: "DB push",
  options: [
    "Push now — apply migration to production",
    "Hold — I'll push manually; back out the deploy plan if needed"
  ]
})
```

In `auto` mode, push immediately — but log the disruption-plan choice from Step 3 in the post-push summary so it's visible to anyone reviewing the session.

## Step 12: Cleanup

**Run before the final summary message.** Landing the PR does NOT stop spawned services — leaked tsx/node processes are visible in `ps` for days otherwise.

1. **Kill any background Bash task this session started.** Without the review-wait loop, the lifecycle rarely starts background tasks anymore — but if you did (e.g. ad-hoc `gh run watch`, `gh pr checks --watch`), walk your own background-task IDs and `KillBash` each one. Verify with:
   ```bash
   ps -ef | grep -E "gh (run watch|pr checks --watch)" | grep -v grep
   ```
   Kill anything related to **this** session's PR number.

2. **Stop e2e Chrome always** (no-op if nothing running):
   ```bash
   ./scripts/e2e.ts stop
   ```

3. **Stop dev server only if THIS session started it.** Check `./scripts/dev.ts status` first:
   - Was it already `ready` when this session arrived? → leave it; cancel the cleanup task with "dev was already running on arrival."
   - Did this session call `./scripts/dev.ts start`? → `./scripts/dev.ts stop`.

4. Mark cleanup tasks `completed` only after the stop commands actually returned. Cancel (don't complete) tasks for services that were never started this session.

## Step 13: Retro

**Run AFTER cleanup, BEFORE the final summary.** Invoke `/retro` via the Skill tool, INLINE in this session — never as an Agent subagent. The skill self-aborts if it can't enumerate ≥2 concrete misses, so invoking it on a smooth session is cheap: it walks back, finds nothing, and returns. On a session where the user had to push back, it produces (at most) one bullet of edits to the right SKILL.md or `CLAUDE.md`.

Carve-outs (skip Retro entirely):

- The lifecycle never reached Step 9 (Open PR) — there's no completed work to retro on.
- The user explicitly said "skip retro" / "don't retro" at any point in the lifecycle.

Everything else: invoke. Do NOT pre-judge "this session went fine, no retro needed" — the skill is the gate, not you. Confirmation bias is exactly why the skill exists: every session the assistant thinks went fine, the user has at least one push-back to point at.

Mark the retro task `completed` only after the Skill returns. If the Skill applied a doc edit, the edit is uncommitted — leave it for the user to review and commit separately (do NOT bundle into the PR that's already landed). If the Skill found only discipline gaps (no edits), the report itself is the deliverable.

This is the LAST step. After Step 13, the final summary message can go out.

---

# Mid-flow pivots

When the user asks for a different change mid-session ("also fix X", "tweak Y", "rename Z"), use `AskUserQuestion` to scope it — never silently re-enter Step 0 or skip Polish.

```
AskUserQuestion({
  question: "You're asking for <X>. How should I handle it?",
  header: "Pivot scope",
  options: [
    "Add to current PR — re-enter Step 5 (implement) → Step 6 (e2e) → [Step 7 if manual] → Step 8 (Polish) → push",
    "Land current PR first, then new lifecycle for <X>",
    "Drop current, fully switch to <X>"
  ]
})
```

Regardless of choice: **TaskCreate the procedural tasks (Polish, e2e, push) before editing any code for the new work.** The already-completed Polish tasks for the previous diff don't carry over.

If the pivot touches a new area of the codebase (e.g. backend after a frontend-only branch), **re-run Step 4** for the newly-touched area before writing code — read whichever coding-guidelines file you didn't already read this session.

Visual nits ARE code changes ("make column X narrower", "shrink padding"). The size of the change does not determine whether Polish fires; pushing additional commits to an open PR does. (Pure value tweaks — colors, spacing — qualify for the CSS-value carve-out in Step 8.)

**The "Land current PR first" path is mode-aware** — in `auto` mode the current PR may have already landed by the time the pivot arrives, in which case the pivot starts a fresh lifecycle from Step 0.

---

# Case rules

## Already-implemented issues
If you investigate and discover the feature/fix is already in the codebase:
- `cli.ts move-item --item <id> --column Done`
- Do NOT close via `gh issue close` — the project column is source of truth.

## No-code-change issues
If resolvable without code (config note, doc clarification, confirming existing behavior):
- Move to Done directly.
- Don't create a branch or PR.

---

# URL parsing

GitHub Project issue URLs look like:
`https://github.com/users/<user>/projects/1/views/1?pane=issue&itemId=<itemId>&issue=<owner>%7C<repo>%7C<issue_number>`

The `issue` query param URL-decodes to `owner|repo|issue_number`. The issue number is the last `|`-separated segment.
