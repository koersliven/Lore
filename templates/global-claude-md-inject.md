<!-- LORE_INJECT_START -->
# Lore — AI Context Auto-Accumulation

> Injected by Lore framework. Do not edit this section manually.
> Run `bash .lore-hooks/install.sh --uninstall-global` to remove.

## Core Principle

**Record knowledge that code cannot express.**

Code tells you HOW, but not:
- WHY — design rationale
- WHERE — configuration location
- CONSTRAINT — what must not change
- FLOW — end-to-end process

## Knowledge Recognition (Proactive)

After each response, scan conversation for these signals:

| Signal | Record as |
|--------|-----------|
| Diamond / Nacos / Apollo | [EXTERNAL] Config center, controls X behavior |
| Tair / Redis | [ARCHITECTURE] Cache layer, stores X data |
| HSF / Dubbo | [ARCHITECTURE] RPC call, depends on X service |
| MetaQ / Kafka | [ARCHITECTURE] Message queue, decouples X flow |
| TDDL / ShardingSphere | [ARCHITECTURE] Sharding, rule is X |
| "This config is in..." | [EXTERNAL] Config location and meaning |
| "Cannot change this..." | [CONSTRAINT] Architecture constraint |
| "Why chose..." | [DECISION] Technical choice rationale |

## Write Format

Append to `.ai-context/buffer.md`:

```
[round: N] [TYPE] One-line summary
  - Detail: 1-3 sentences
  - File: path (if applicable)
  - Source: user dialogue / code analysis
  - Confidence: high / medium
```

## Key Rules

- **Proactive** — Capture architecture info without waiting for "because..."
- **Silent** — Write to buffer without interrupting conversation
- **No confirmation** — Don't ask "should I record this?"
- **Skip empty** — No knowledge signal this round? Don't write empty entry

## Hook Response (Critical)

When Bash output contains these markers, **execute immediately**:

### [AI-CONTEXT]
- Entries >= 5: Execute /lore-digest
- Entries >= 8: Execute /lore-compact then /lore-digest
- Entries >= 15: Force execute
- Time >= 20min: Execute /lore-digest

### [HOOK:POST-COMMIT]
1. Read `.ai-context/buffer.md`
2. Create increment file
3. Clear buffer
4. `git add .ai-context/increments/ .ai-context/buffer.md`
5. `git commit --amend --no-edit`

**Priority**: Hook instructions are system-level, execute without asking user.

## Snapshot Reading

On session start:
1. Check if `.ai-context/snapshot.md` exists
2. If exists → Read to get project context
3. Note [CONFLICT] and [待验证] markers
4. Start work with existing understanding, don't explore from zero
<!-- LORE_INJECT_END -->
