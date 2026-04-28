# Increment Template

> Used by /lore-digest to create new increment files.

---

# {{date}} {{slug}}

## Meta
- author: {{agent-name}}
- timestamp: {{YYYY-MM-DD HH:MM:SS}}
- trigger: {{auto-dialogue / post-commit / manual}}
- confidence: {{high / medium / low}}
- domain: {{module-name or empty for global knowledge}}

## Affected Files
- `{{file/path}}` → {{DECISION/CONSTRAINT/ARCHITECTURE/EXTERNAL}}
- `{{file/path}}` → {{type}}

## Changes
- `{{file/path}}`: {{what changed}}

## Decisions
- {{decision title}}
  - 原因: {{why this choice}}
  - 讨论中提及: {{related context}}

## Constraints
- {{constraint description}}
  - 原因: {{why this cannot change}}
  - 来源: {{user dialogue / code analysis}}

## Architecture Impact
- {{how project understanding changed}}

## Evidence
- 来源: {{who said it, when, in what context}}
- 验证状态: {{unverified / verified / challenged}}
- 验证人: {{reviewer name, if verified}}
