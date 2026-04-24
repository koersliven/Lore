---
name: compact
description: Compress knowledge window by merging, deduping, and summarizing buffer entries
category: ai-context
---

# /compact — Knowledge Window Compression

类比 Claude Code 的上下文 compaction，在知识窗口过大时自动压缩，保持 snapshot 精炼。

## When to Trigger

- Stop hook detects buffer has reached compact threshold (8+ entries)
- User explicitly invokes this skill
- Before /digest when buffer has 5+ entries (optional optimization)

## Purpose

将 buffer 中的多条原始知识压缩为精炼的摘要，减少 snapshot 膨胀，同时保留完整追溯。

**核心思想**：不是简单 flush，而是先"消化"——合并同类、去除冗余、提取本质。

## Process

### Step 1: Read Buffer

读取 `.ai-context/buffer.md` 中的所有原始知识条目。

### Step 2: Group by Theme

按主题分组。判断标准：
- 涉及同一文件 → 同组
- 涉及同一概念（如"超时"、"缓存"） → 同组
- 同一类型的知识（多个 DECISION 关于同一设计） → 同组

### Step 3: Merge and Dedupe

对每组执行：

**合并规则**：
- 多条关于同一文件的 DECISION → 合并为一条，保留最新原因
- 多条关于同一约束的重复描述 → 保留最完整的一条
- 互相矛盾的条目 → 标记 `[CONFLICT]`，保留双方

**去重规则**：
- 完全相同的条目 → 只保留一条
- 后一条是前一条的子集 → 只保留前一条

### Step 4: Summarize

将合并后的条目压缩为精炼形式：

**原始**：
```
[round: 3] [DECISION] 支付超时改为 5s
  - Detail: 上游 SLA 从 3s 升级为 5s
[round: 5] [DECISION] 支付超时不能超过 8s
  - Detail: 超过会触发回退
```

**压缩后**：
```
[DECISION] 支付超时设为 5s（上游 SLA 升级），上限 8s（防止回退）
  - 来源: round 3, 5
  - 关联: PaymentService.java
```

### Step 5: Write Outputs

**写入 increment（详细版）**：
- 包含所有原始条目的完整记录
- 用于追溯

**写入 snapshot 更新（精炼版）**：
- 只写入压缩后的摘要
- 更新 snapshot 中受影响的章节

### Step 6: Clear Buffer

清空 `.ai-context/buffer.md`。

### Step 7: Git Add

```bash
git add .ai-context/increments/
git add .ai-context/snapshot.md
git add .ai-context/buffer.md
```

## Output

静默执行。完成后简要报告：

```
+ Compact complete:
  - 12 raw entries → 4 summarized entries
  - 2 groups merged, 1 conflict flagged
  - Increment: 2026-04-24_compact-session.md
  - Snapshot updated: Key Decisions, Constraints
```

## Difference from /digest

| | /digest | /compact |
|--|---------|----------|
| **触发时机** | soft 阈值 (5) | compact 阈值 (8) |
| **动作** | 直接写入 increment | 先合并压缩，再写入 |
| **snapshot 更新** | 否（等 /evolve） | 是（轻量更新） |
| **目的** | 防止丢失 | 防止膨胀 |

**典型流程**：
```
buffer 积累 → 达到 5 条 → /digest → increments
buffer 继续积累 → 达到 8 条 → /compact → snapshot 轻量更新 + increments
buffer 继续积累 → 达到 15 条 → 强制 /compact + /digest
```
