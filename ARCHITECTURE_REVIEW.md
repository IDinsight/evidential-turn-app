# Evidential Turn App — Architecture Review & Platform Gaps

This document captures the findings from a review of the `additonal-tweaks-for-exp-and-arm-id-config` branch (PR #3). The goal is to identify where the developer's approach diverged from what the Turn platform supports, why it diverged, and what documentation or platform gaps led to the choices made.

## Context

The Evidential app integrates Turn.io with an external A/B testing platform. Its core job is:

1. Accept experiment configuration (experiment ID, arm-to-journey mappings)
2. When a contact enters the experiment, call the Evidential API to get their arm assignment
3. Route the contact to the correct arm journey
4. Post outcomes back to Evidential after the arm journey completes

The developer's approach on this branch was to **generate journey notebooks dynamically** from string templates on every `config_changed` event, stitching together markdown fragments with `gsub` substitutions to produce a journey with the right number of branch cards and `run_stack()` calls.

## Why the developer chose code generation

The fundamental problem: the journey needs experiment-specific values (experiment ID, arm IDs, journey UUIDs) that come from runtime configuration, but the developer didn't have a clear path to get those values into the journey without baking them into the notebook source.

This led to a cascade of complexity:

| Decision | Why it was made | What it led to |
|----------|----------------|----------------|
| Can't read config from within a journey natively | No `turn.data` write API exists for Lua apps | Experiment ID must be hardcoded in notebook |
| Need dynamic arm-to-journey routing | Number of arms varies per experiment | Built a branching card generator |
| Branch cards need arm IDs as literals | Journey expressions can't read app config directly | String-templated arm IDs via `gsub` |
| Each `run_stack()` needs a literal UUID | Assumed `run_stack()` requires static UUIDs | Generated one `run_stack()` card per arm |
| Journey must change when config changes | All values are baked into the notebook | Regenerate entire journey on `config_changed` |
| New journey created each time | No tracking of previously created journey UUID | Orphaned journeys accumulate |

Each decision is locally reasonable given the perceived constraints, but the chain produces a fragile system.

## Platform capabilities the developer missed or couldn't use

### 1. Journey data tables (global and local) — no Lua write API

**What exists:** Turn has global data (`@global.<namespace>.<key>`, scoped to a number) and local data (`@<namespace>.<key>`, scoped to a journey). Both are fully functional — journeys can read them via expressions, the UI exposes them for editing, and the Elixir backend has complete CRUD. They are exposed via GraphQL.

**What's missing:** No Lua app API to write to these stores. Apps cannot call `turn.data.set_global()` or `turn.data.set_local()` because these functions don't exist yet.

**Impact on this developer:** If the app could write experiment config to local data on the journey, the journey could read `@evidential.experiment_id` natively. No string templating needed.

**Documentation gap:** The app developer docs don't mention global/local data tables as a concept at all. A developer reading only the app docs would not know these stores exist or that journeys can read from them. The journey docs mention `@global` access but don't explain how data gets written there (only via UI or GraphQL — not from apps).

**Spec written:** A spec for `turn.data.set_global()` / `turn.data.set_local()` / etc. has been drafted at `/Users/sdehaan/Repositories/engage/specs/turn-global-data-lua-api.md`.

### 2. Dynamic expression indexing in journeys

**What exists:** Journey expressions support dynamic map key access. If local data contains `arms = {"arm_abc": "journey-uuid-1"}`, the expression `@evidential.arms[@contact.assignment_arm_id]` resolves correctly at runtime.

**Documentation gap:** This capability is not explicitly documented. The journey expression docs show static key access (`@global.namespace.key`) but don't demonstrate or explain dynamic indexing with variables as keys. A developer wouldn't know this is possible without experimenting or asking.

**Impact on this developer:** Had they known, combined with a data write API, the entire branching card generation would be unnecessary — the journey could look up the target journey UUID dynamically from a data table.

### 3. `run_stack()` accepts variables at runtime

**What exists:** `run_stack()` can accept a variable or expression as its argument, not just a hardcoded UUID string. At runtime, the expression is evaluated and the resolved UUID is used.

**Caveat:** The canvas UI validates journey UUIDs and will show errors if `run_stack()` references a variable (since it can't verify the UUID exists at design time). This doesn't affect runtime behavior but makes the journey appear broken in the UI.

**Documentation gap:** The journey docs show `run_stack("hardcoded-uuid")` exclusively. There's no mention of using variables or expressions as the argument. The UI validation behavior (flagging variables as errors) reinforces the impression that only literals are allowed.

**Impact on this developer:** They assumed `run_stack()` required a literal UUID, which meant generating one `run_stack()` card per arm at build time.

### 4. `turn.journeys.start()` as a routing mechanism

**What exists:** `turn.journeys.start(chat_uuid, journey_uuid, {override = true})` can start any journey for a chat from within a Lua app, releasing any existing lease first. The `data.chat_uuid` is available in `journey_event` handlers.

**What this enables:** Instead of the journey doing the routing (branching + `run_stack`), the app can route the contact directly by calling `turn.journeys.start()` with the resolved journey UUID. No branching in the journey at all.

**Documentation gap:** The docs show `turn.journeys.start()` in webhook/HTTP handler examples but don't demonstrate calling it from within a `journey_event` handler. The pattern of "journey calls app, app starts a different journey for the same chat" is not documented. It's also not clear whether calling `turn.journeys.start()` with `override` from inside a `journey_event` (while the calling journey's lease is active) works correctly — this needs verification.

**Impact on this developer:** The developer didn't consider this as an option for routing, likely because the docs position `turn.journeys.start()` as an external trigger mechanism rather than an internal routing tool.

### 5. `turn.contacts.update_contact_details()` from within journey events

**What exists:** The app can update contact fields directly from a `journey_event` handler, rather than returning data to the journey and having the journey do `update_contact()`.

**Impact:** The generated journey includes an `UpdateProfile` card that writes `assignment_arm_id` and `experiment_id` to the contact. If the app handles routing directly (Option 1 below), it can also update the contact, eliminating the need for the `UpdateProfile` card.

**Documentation gap:** Using `turn.contacts` from within `journey_event` handlers is technically documented in the API reference but no examples demonstrate this pattern in combination with routing.

### 6. Journey mapping for tracking installed journey UUIDs

**What exists:** `turn.app.set_journey_mapping()` / `turn.app.get_journey_mapping()` allow apps to track the UUIDs of journeys they've created, keyed by a name. `turn.manifest.install()` automatically populates these mappings for manifest-declared journeys.

**Impact on this developer:** The `config_changed` handler creates a new journey every time but never stores or checks the UUID. Using journey mapping, the app could create the journey once and retrieve its UUID on subsequent config changes.

**Documentation gap:** Journey mapping is documented but not positioned as a best practice for apps that create journeys programmatically. There's no guidance on the pattern of "create once, update later" vs "create every time".

## The three architectural options considered

### Option 1: App-driven routing via `turn.journeys.start()` (recommended)

The app handles all routing. The journey is minimal (trigger → consent → app call). The app gets the assignment, resolves arm → journey UUID from its own config, updates the contact, and starts the arm journey directly.

**Pros:**
- No branching in the journey at all
- No journey generation, no string templating
- Adding/removing arms requires only a config change
- Journey never needs modification
- Clean separation: app routes, arm journeys deliver content

**Cons:**
- No parent/child return — the original journey is terminated when the arm journey starts
- Outcome collection must happen in the arm journeys (they call `post_outcome_for_contact` themselves)
- Needs verification that `turn.journeys.start()` with `override` works correctly from within a `journey_event` handler
- Arm journey authors need to know to call the outcome posting function

**What this eliminates:** `JourneyGenerator` module, all fragment templates, all string templating, all branching logic, journey duplication on config change.

### Option 2: Static template with hardcoded branches

Ship a static journey template. The operator manually edits it after installation to add their arm IDs and journey UUIDs in the branch conditions and `run_stack()` calls.

**Pros:**
- Simplest implementation — no code generation, no clever routing
- Parent/child model works — outcome collection stays in the routing journey
- Journey is fully editable in the canvas UI

**Cons:**
- Operator must manually edit the journey per experiment
- Adding/removing arms means editing the journey
- Doesn't scale to many experiments or frequent changes
- Error-prone (typos in arm IDs, wrong UUIDs)

### Option 3: App routing with `turn.data` (future, when API exists)

The app writes experiment config to local data on the journey via `turn.data.set_local()`. The journey reads config natively via `@evidential.*` expressions. Routing uses either dynamic `run_stack(@evidential.arms[@contact.assignment_arm_id])` or a single `run_stack()` with the journey UUID returned by the app.

**Pros:**
- Parent/child model preserved (if using `run_stack`)
- Journey reads its own config — self-documenting
- Clean separation between app (writes config) and journey (reads config, routes)

**Cons:**
- Requires `turn.data` API to be built first
- `run_stack()` with a variable triggers UI validation errors
- More moving parts than Option 1

## Bugs found in current code

| Bug | Location | Severity |
|-----|----------|----------|
| Contact field name mismatch: generator uses `arm_assignment_id` but manifest defines `assignment_arm_id` | `journey_generator.lua:19` vs `manifest.json` | **High** — branch conditions never match |
| Hardcoded card UUIDs in fragment templates reused across generated journeys | `journey_fragments/*.md` | **High** — UUID collisions between generated journeys |
| Global variable `i` (missing `local`) in generator loop | `journey_generator.lua:16` | **Low** — potential for subtle bugs |
| Stale static template with hardcoded arm IDs still installed via manifest | `manifest.json` journeys section + `evidential_template_journey.md` | **Medium** — broken journey installed alongside generated one |
| No JSON parse error handling for `experiment_config` | `evidential.lua:65` | **Low** — crashes on malformed JSON |
| Fallback string still says "test_app" | `evidential.lua:139` | **Low** — cosmetic |
| Journey orphaning — new journey created on every config change, old ones never cleaned up | `evidential.lua:82` | **High** — unbounded journey accumulation |

## Documentation recommendations

Based on the gaps identified, the following additions to the Turn developer documentation would help prevent similar architectural missteps:

### App developer docs

1. **"Passing configuration to journeys" guide** — Explain the available mechanisms: global data tables, local data tables, contact fields, app function return values. When to use each. Currently, a developer reading only the app docs has no visibility into global/local data tables.

2. **"Routing contacts between journeys" pattern** — Show the `turn.journeys.start()` pattern for programmatic routing from within `journey_event` handlers. Contrast with `run_stack()` in the journey DSL. Explain the lease implications of each approach.

3. **"Managing app-created journeys" best practice** — Document the create-once-update-later pattern using `turn.app.set_journey_mapping()`. Warn against creating journeys in `config_changed` without tracking UUIDs.

4. **`turn.journeys.start()` from `journey_event` handlers** — Add an explicit example. Document whether `override` works correctly when called from within the journey whose lease will be released. If it doesn't work, document that clearly.

### Journey developer docs

5. **Dynamic expression indexing** — Add examples showing variable-based map key access: `@data.map_name[@contact.field]`. This is a powerful capability that's currently undocumented.

6. **`run_stack()` with expressions** — Document that `run_stack()` accepts variables/expressions at runtime. Document the UI validation caveat (canvas shows errors for non-literal UUIDs). Explain when this is acceptable (app-installed journeys that won't be canvas-edited).

7. **Global vs local data tables** — Explain the difference (number-scoped vs journey-scoped), how data gets into them (UI, GraphQL, and eventually Lua API), and how journeys access them (`@global.ns.key` vs `@ns.key`).

### Cross-cutting

8. **"App + Journey integration patterns" guide** — A single document showing the common patterns:
   - Journey reads config from data tables (when `turn.data` ships)
   - Journey calls app for API operations, app returns results
   - App routes contacts to journeys via `turn.journeys.start()`
   - App updates contact fields directly vs returning data for journey to update
   - Sync vs async (`continue` vs `wait`) patterns with concrete use cases
