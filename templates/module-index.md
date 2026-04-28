# Module Index

> Auto-managed by /lore-evolve and /lore-sync. Last updated: {{YYYY-MM-DD}}.
> This file serves as the registry for all modules in the project.

## Modules

| Module | Code Path | Purpose | Status |
|--------|-----------|---------|--------|
| {{module-name}} | `{{code-path-pattern}}` | {{one-line purpose}} | {{active / dormant}}

## Cross-Module Dependencies

| Source | Target | Dependency Type | Description |
|--------|--------|----------------|-------------|

## Auto-Discovery Config

> /lore-sync uses these patterns to discover modules from code structure.

### Discovery Patterns

- **Java**: Directories containing `*Controller.java`, `*Service.java`, or `@HSFService` annotations
- **Node.js/TypeScript**: Directories containing `*Controller.ts`, `*Handler.ts`, `router.ts`, or route definitions
- **Go**: Directories containing `handler.go`, `controller.go`, or `*Service` files
- **Python**: Directories containing `*views.py`, `*api.py`, `*handler.py`
- **General**: Top-level directories under `src/` or `app/` that have entry-point files

### Exclusions

- `test/`, `__tests__/`, `spec/`, `fixtures/` — test directories are not modules
- `shared/`, `common/`, `util/` — shared utilities are not modules
- Single-file directories with no entry points are not modules
