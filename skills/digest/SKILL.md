---
name: digest
description: Flush knowledge buffer into versioned increment files with source tracing
category: ai-context
---

# /digest — Knowledge Buffer Flush

## When to Trigger

- Stop hook detects buffer has reached flush threshold (3+ entries)
- Post-commit hook after git commit
- User explicitly invokes this skill
- Session end with buffered knowledge

## Purpose

Convert raw conversation knowledge (stored in `.ai-context/buffer.md`) into a structured, versioned increment file in `.ai-context/increments/`. Each increment includes **author, timestamp, confidence, affected files, and evidence** for full source tracing.

## Process

### Step 1: Read Buffer

Read `.ai-context/buffer.md`. If empty or contains only lock markers, exit silently — no knowledge to flush.

### Step 2: Analyze and Structure

Parse the buffer entries and reorganize them into a proper increment format with full metadata.

**Buffer format (raw)**:
```
[round: 1] [DECISION] 支付超时改为 5s 因为上游 SLA 从 3s 升级
  - Detail: 上游接口 SLA 从 3s 升级为 5s，支付超时需要同步调整...
```

**Transform to increment format**:
```markdown
# YYYY-MM-DD payment-timeout-adjust

## Meta
- author: {{current agent name}}
- timestamp: YYYY-MM-DD HH:MM:SS
- trigger: auto-dialogue
- confidence: high

## Affected Files
- `PaymentService.java` → DECISION (payment timeout threshold)
- `payment-config.yaml` → CONSTRAINT (timeout rule)

## Changes
- `PaymentService.java`: timeout threshold changed from 3000ms to 5000ms

## Decisions
- Payment timeout adjusted to 5s
  - 原因: upstream SLA changed from 3s to 5s, old timeout would trigger false rollback
  - 讨论中提及: rule of thumb — timeout ≤ upstream SLA × 1.2

## Constraints
- Payment timeout must be ≤ upstream SLA × 1.2
  - 来源: user explicitly stated in dialogue

## Evidence
- 来源: 利普, 2026-04-23, development dialogue
- 验证状态: unverified
- 验证人: —
```

### Step 3: Determine Confidence

Assign confidence level based on source:

| Source | Confidence |
|--------|-----------|
| User corrected agent (direct feedback) | high |
| User explained business context | high |
| Agent inferred from code analysis | medium |
| Agent guessed from usage patterns | low |

### Step 4: Identify Affected Files

For each knowledge entry, identify which files it relates to:
- If the dialogue mentioned specific files → use those
- If the knowledge came from a code change in this session → use the changed files
- Otherwise → mark as `general` (project-level knowledge, not file-specific)

### Step 5: Write Increment File

Write to `.ai-context/increments/YYYY-MM-DD_<short-slug>.md` following the template in `templates/increment.md`.

If an increment for today already exists, append to it (don't overwrite).

### Step 6: Clear Buffer

Overwrite `.ai-context/buffer.md` with an empty file.

### Step 7: Remove Lock Markers

If the buffer had a `[LOCKED:commit]` marker (from post-commit hook), ensure it's cleared.

### Step 8: Git Add

```bash
git add .ai-context/increments/
git add .ai-context/buffer.md
```

If called from post-commit hook context, also:
```bash
git commit --amend --no-edit
```

## Output

Report silently — only confirm if the user asked. If no knowledge was in buffer, exit without any output.

If knowledge was flushed:
```
+ 1 increment written → .ai-context/increments/2026-04-23_payment-timeout-adjust.md
  - 1 decision, 1 constraint
  - confidence: high, status: unverified
  - affected files: PaymentService.java, payment-config.yaml
```
