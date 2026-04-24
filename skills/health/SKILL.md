---
name: health
description: Validate knowledge health by cross-checking against code and detecting stale/contradicted entries
category: ai-context
---

# /health — Knowledge Health Check

自动校验 snapshot 中的知识是否仍然有效。不依赖人工确认，通过交叉验证自动判断。

## When to Trigger

- SessionStart hook（agent 入场时）
- Before /evolve compilation
- User explicitly invokes this skill

## Purpose

知识不是静态的。代码会变、业务会变、组织会变。`/health` 确保 Lore 的知识库不会积累过期或错误的信息。

**核心原则**：
- CODE 类知识：代码是权威来源
- BUSINESS 类知识：业务是权威来源，代码里没有不代表过期
- 只有"有矛盾"才标记问题，"找不到"不等于"过期"

## Knowledge Validation Types

每条知识带一个 `validation_type` 字段：

| 类型 | 验证方式 | 不健康信号 | 处理 |
|------|---------|-----------|------|
| **CODE** | 扫描代码匹配 | 代码不存在且相关文件最近有变更 | 标记 stale |
| **BUSINESS** | 代码是否违反规则 | 代码行为与规则矛盾 | 标记 contradicted |
| **DECISION** | 检查 affected files | 新值覆盖旧值 | 标记 superseded |
| **ORG** | 无自动检测 | 人工推翻 | 等待更新 |

## Process

### Step 1: Read Snapshot

读取 `.ai-context/snapshot.md` 中的所有知识条目。

### Step 2: Validate Each Entry

对每条知识，根据其 `validation_type` 执行验证：

#### CODE 类验证

```
知识: "订单服务在 OrderService.create() 中"
验证:
  1. grep/扫描代码找 OrderService.create()
  2. 找到 → healthy
  3. 没找到 → 检查 OrderService.java 最近是否有 commit
     - 有 commit → 很可能被改了 → stale
     - 无 commit → 可能是描述不准 → inaccurate（不是 stale）
```

#### BUSINESS 类验证

```
知识: "业务只做东南亚，不做欧洲"
验证:
  1. 扫描代码中 region/country 相关配置
  2. 发现 EUR region 支持 → contradicted
  3. 无相关代码变更 → healthy（业务知识不依赖代码存在）
```

```
知识: "图片最少 3 张"
验证:
  1. 扫描校验逻辑中 image_count 相关代码
  2. 代码允许 0 张图片 → contradicted
  3. 代码要求 3 张 → healthy
```

#### DECISION 类验证

```
知识: "支付超时改为 5s" (affected: PaymentService.java, 2026-04-23)
验证:
  1. 检查 PaymentService.java 最近 commit
  2. 有 commit 且改了超时值 → 检查新值
     - 新值不同 → superseded（新决策覆盖）
     - 新值相同 → healthy
  3. 无 commit → healthy
```

#### ORG 类验证

```
知识: "这个模块归财务团队管"
验证: 无自动检测
策略: 等待对话中"推翻信号"——"这个模块转到库存团队了"
```

### Step 3: Classify Health Status

| 状态 | 含义 | 动作 |
|------|------|------|
| **healthy** | 知识仍然有效 | 保持现状 |
| **stale** | CODE 类且代码已不存在 | 移至 snapshot 末尾 "Stale Knowledge" 章节 |
| **contradicted** | 代码直接违反知识 | 标记 `[CONTRADICTION]`，保留双方 |
| **superseded** | 新决策覆盖旧决策 | 标记旧决策为 "Superseded by [新决策]" |
| **inaccurate** | 描述不准但知识本身可能仍对 | 标记 `[待修正]` |

### Step 4: Auto-fix When Possible

如果能确定新值，自动更新：

```
旧知识: "超时阈值 3s"
代码中找到: timeout = 5000
动作: 自动更新为 "超时阈值 5s (原 3s, 2026-04-24 代码变更)"
```

如果不能确定，只标记不修改。

### Step 5: Update Snapshot

将验证结果写入 snapshot：

```markdown
## Health Check Result (2026-04-24)

### Healthy
- 12 entries verified

### Stale
- [CODE] "OrderService.create() 在订单模块" — 代码已删除
- [CODE] "超时配置在 config.timeout" — 配置项已迁移

### Contradicted
- [BUSINESS] "图片最少 3 张" — 代码允许 0 张

### Superseded
- [DECISION] "支付超时 3s" → 被 "支付超时 5s" (2026-04-24) 覆盖
```

### Step 6: Report

静默执行。完成后简要报告：

```
+ Health check complete:
  - 15 entries checked
  - 12 healthy, 2 stale, 1 contradicted
  - 1 auto-fixed
  - Snapshot updated
```

## Integration Points

### SessionStart Hook

`session-start.sh` 触发后，agent 自动执行 `/health`，带着"最新理解"入场。

### /evolve Pre-compilation

编译前清理不健康的知识，保证快照质量。

## Difference from Manual Review

| | 人工 Review | /health |
|--|-------------|---------|
| **触发** | PR 时 | 每次入场 + 编译前 |
| **覆盖** | 只看变更 | 全量校验 |
| **成本** | 高 | 零（自动） |
| **准确性** | 依赖人 | 依赖交叉验证 |

**关键**：不依赖人确认。agent 自己跑完，自己标记，自己修复（如果能确定）。
