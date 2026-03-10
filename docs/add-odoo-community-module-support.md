# Add Odoo Community Module Support

This guide explains how contributors should add support for any new Odoo Community module to Ordo without breaking the current model-agnostic architecture.

## What “module support” means in Ordo

In Ordo, supporting a new module usually means one or more of these:

- exposing one or more new models in browse/home entry points
- rendering their form and list views through the existing schema-driven engine
- supporting any missing generic field, action, or workflow behavior those models need
- documenting the honest support boundary

The default assumption should be:

> Reuse the generic engine first. Add module-specific UI only when the generic path is proven insufficient.

## Ownership map

- `backend/src/shared/` owns transport type contracts used by the backend
- `backend/` owns Odoo normalization, schema parsing, record/chatter/action routes, and module detection
- `ios/` owns browse registration, list/detail UX, and generic editor/renderer behavior
- `docs/` owns the public support boundary and contributor guidance

## Fast decision tree

### No code change needed

Use this path when the target model already works through the shipped generic engine and only needs validation.

Examples:

- list schema loads correctly from Odoo
- form schema already renders correctly
- existing field types cover the model
- existing generic actions/chatter/onchange paths are sufficient

### Small registration change only

Use this path when the generic engine already supports the model and the app only needs to expose it.

Typical files:

- `ios/Ordo/features/browse/model-registry.swift`

This is the common case for a basic CRUD slice.

### Generic engine gap

Use this path when the model depends on a field type or behavior the generic engine does not support yet.

Examples:

- unsupported field/widget behavior
- missing list/filter fallback behavior
- missing workflow/action affordance
- missing x2many/onchange parity needed across more than one module

If the gap is generic, fix it generically. Do not hardcode the new module unless there is strong product evidence that the behavior is truly module-specific.

### Shared contract change

Only widen `backend/src/shared/` when the transport contract must change across layers.

Examples:

- new schema metadata needed by the backend
- new API response/request fields required by the client

Do **not** change `backend/src/shared/` just to avoid a small local refactor.

## Step-by-step workflow

### 1. Inspect the target Odoo model honestly

Before writing code, inspect:

- Odoo technical module name, for example `hr`, `stock`, `project`
- model names, for example `hr.employee`, `stock.picking`, `project.task`
- real form/tree/search XML behavior
- field types used in practice
- whether the model actually uses chatter, actions, statusbar, defaults, or onchange

The contributor goal is not “make it compile.” The goal is “understand the real runtime shape.”

### 2. Decide whether the change is registration or engine work

Use these rules:

- **Registration-only** if schema/list/detail already fit the current engine
- **Engine work** if the target model reveals a reusable generic gap
- **Module-specific UI** only if the Odoo workflow is fundamentally not representable through the generic engine

Examples of likely module-specific UX:

- org chart
- barcode scanning flows
- attendance check-in/out home actions
- heavily wizard-driven business flows

## Registration-only implementation

### Backend: verify discovery already exposes the model honestly

Ordo now auto-discovers the mobile browse catalog through:

- `GET /api/v1/mobile/modules/installed`

That endpoint now returns:

1. installed Odoo application modules
2. `browseMenuTree` discovered from active `ir.ui.menu` entries that resolve to browseable `ir.actions.act_window` records

In other words, the backend no longer needs a hardcoded module whitelist just to surface a new model.

For a registration-only slice, first verify that the target model is already discoverable through real Odoo menus/actions. If it is not, investigate the actual Odoo/menu/action cause before adding app-side code.

Examples of real reasons discovery may not surface a model:

- the module is not installed as an application module
- the model has no active menu entry
- the menu points to a non-window action
- the action only opens modal/wizard targets (`target='new'`)
- the action is not browse-oriented (`tree`, `list`, `kanban`)

Also note the current boundary: discovery is **menu/action-backed but coarse**. The payload preserves app/category/leaf hierarchy plus the discovered `model`, but it does not preserve action-specific `domain` or `context` when multiple menus point at the same model.

### iOS: register browse metadata

Add a `ModelDescriptor` in:

- `ios/Ordo/features/browse/model-registry.swift`

Each descriptor should define:

- `model`
- `title`
- `subtitle`
- `systemImage`
- `listFields` fallback
- row summary fields (`titleFields`, `subtitleFields`, `footnoteFields`)
- `requiredModule`

This metadata now acts as a **curated override/fallback**, not the primary browse gatekeeper.

Known models can get better titles, icons, fallback list fields, and row-summary rules here. Unknown discovered models can still surface without a new descriptor because iOS synthesizes a generic one.

`requiredModule` remains a UI hint for known descriptors, not a security boundary. Contributors should use it sparingly and only when the polished descriptor truly belongs to a specific installed module.

### Important fallback seam

Browse is mostly schema-driven, but descriptor metadata still matters as a fallback when list-schema loading fails.

Contributors should verify:

- row titles still make sense from descriptor summary fields
- fallback list fields are minimal but useful
- the icon/title are product-appropriate

## When you must touch more than two files

### Browse/filter fallback polish

Check:

- `ios/Ordo/features/browse/filter-models.swift`

The shipped browse path prefers dynamic list-schema search metadata, but this file still provides model-aware fallback filter behavior. If your new model has poor fallback UX, you may need to add a narrow preset here.

Do this only to improve fallback behavior, not to replace working schema-driven behavior.

### Generic field or workflow gaps

Potential owning areas:

- `backend/src/shared/` for transport metadata
- `backend/src/odoo/schema/` for schema extraction/parsing
- `backend/src/modules/schema/` and `backend/src/modules/record/` for route behavior
- `ios/Ordo/features/record-detail/` for generic read/edit/render logic

If the same fix would benefit HR, Inventory, Project, and other modules, it belongs in the generic engine.

## Validation matrix

### Registration-only changes

Validate all of these against a real Odoo instance with the module installed:

- model appears in Home/Browse only when expected
- list loads through `GET /schema/:model/list` when available
- list still has sane fallback behavior if list-schema fetch fails
- detail loads through `GET /schema/:model` and `GET /records/:model/:id`
- create/edit/delete work if the business model allows them
- relation search works where relevant
- onchange/defaults/actions behave honestly

### Generic engine changes

Also validate:

- existing supported models still behave correctly (`res.partner`, `crm.lead`, narrow `sale.order`)
- new shared/backend/iOS seams are covered by focused regression tests
- docs describe the new support boundary and any remaining non-goals

## Required docs updates

When adding support for a new module or expanding the generic engine, update the docs that define the live support boundary:

- `docs/system-architecture.md` for architecture-level behavior changes
- `docs/project-changelog.md` for the delivered slice
- `docs/project-roadmap.md` only when phase status or roadmap notes truly changed

If the change affects contributor workflow, update:

- `CONTRIBUTING.md`
- this guide

## Common pitfalls

- Treating one successful model as proof that the whole module is supported
- Adding module-specific UI before confirming the generic engine cannot represent the workflow
- Changing `backend/src/shared/` for convenience instead of necessity
- Assuming a new model needs backend whitelist code when the real issue is missing Odoo menu/action exposure
- Using `requiredModule` as if it were the primary browse gate or a security boundary
- Relying on static descriptor registration when the model could already surface through dynamic discovery
- Claiming parity with unsupported Odoo widgets, wizard flows, or advanced x2many behavior

## Pull request checklist

- [ ] Chosen the smallest valid layer for the change
- [ ] Verified whether backend menu/action discovery already exposes the model honestly
- [ ] Added or updated `ModelDescriptor` metadata when the model should be browsable
- [ ] Kept generic fixes generic
- [ ] Added focused regression coverage for the changed seam
- [ ] Updated architecture/changelog docs when the shipped support boundary changed
- [ ] Described any remaining limitations honestly in the PR

## Rule of thumb

If you can support a new model through existing discovery plus a small `ModelDescriptor` override, do that.

If the model exposes a reusable gap in the engine, fix the engine once.

If the workflow is fundamentally not generic, document the boundary and build a dedicated UI deliberately rather than smuggling module logic into the core.