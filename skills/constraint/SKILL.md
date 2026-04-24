---
name: constraint
description: Manage L2 constraint layer - knowledge stabilization, protection, and indexing
category: ai-context
---

# L2 约束层 — 知识沉淀与保护

L2 是介于 L1（结构层）和 L3（过程层）之间的"稳定层"。它存储那些经过验证、长期有效、一旦错了影响大的知识。

## 核心概念

```
L3 过程知识（高频变化）
    ↓ 多次验证 + 长期稳定
L2 约束知识（低频变化，高影响）
    ↓ 组织级约定 / 架构边界
L1 结构知识（代码可表达）
```

**L2 的特点**：
- 变化慢（季度/年级别）
- 一旦错了影响大（线上事故、架构违规）
- 需要更高阈值才能修改

## 约束层内容

### 典型 L2 知识

```yaml
## L2 Constraints

### Architecture Boundaries
- 订单模块不能直接调用库存模块，必须通过 MQ
- 支付回调必须幂等，防止重复扣款

### Data Constraints
- order 表不能加唯一索引（并发写入场景）
- 用户 ID 必须通过 UserService 获取，禁止本地缓存

### Business Rules
- 图片最少 3 张（ICBU 发品要求）
- 类目预测失败时走 QP 兜底

### External Contracts
- HSF 接口 OpenApiCategoryPredictService 是对外接口，不可随意修改签名
```

## Process

### Step 1: Knowledge Promotion Detection

`/evolve` 编译时，自动检测哪些 L3 知识可以提升为 L2：

**提升条件（全部满足）**：
1. 知识存在时间 >= 30 天
2. 被至少 3 个 increment 引用或验证
3. 从未被 challenge 或推翻
4. 类型为 CONSTRAINT 或关键 DECISION

**自动标记**：
```markdown
### [PROMOTION CANDIDATE] 支付回调必须幂等
- 存在时间: 45 天
- 验证次数: 5 次
- 状态: pending_promotion
```

### Step 2: Human Confirmation for Promotion

L2 提升需要人工确认（不能全自动）：

```
[AI-CONTEXT] 检测到 2 条知识可提升为 L2 约束：
1. "支付回调必须幂等" (45 天, 5 次验证)
2. "订单表不能加唯一索引" (60 天, 3 次验证)

是否确认提升？确认后修改需要更高阈值。
```

用户确认后，写入 `.ai-context/constraints.md`。

### Step 3: Constraint Protection

L2 知识变更需要更高阈值：

| 变更类型 | L3 阈值 | L2 阈值 |
|---------|--------|--------|
| 新增 | 对话中说出即可 | 需要 L3 验证 + 人工确认 |
| 修改 | 新 increment 覆盖 | 需要 PR review + 2 人确认 |
| 删除 | 新 increment 推翻 | 需要 PR review + 架构师确认 |

**实现方式**：
- `pre-edit-guard.sh` 检测到 L2 知识关联时，输出更强的警告
- `/evolve` 编译时，L2 变更需要额外的确认步骤

### Step 4: Constraint Index

L2 约束独立存储，不与 snapshot 混在一起：

```
.ai-context/
├── snapshot.md      ← L1 + L3 混合（agent 入场读取）
├── constraints.md   ← L2 独立（优先加载，高保护）
├── buffer.md
└── increments/
```

**constraints.md 格式**：

```markdown
# L2 Constraints

> Last updated: 2026-04-24
> Total: 8 constraints

## Architecture Boundaries

### 订单-库存解耦
- 规则: 订单模块不能直接调用库存模块，必须通过 MQ
- 原因: 防止库存服务故障导致订单不可用
- 来源: 利普, 2026-03-15, 架构评审
- 验证: 5 次, 从未推翻
- 保护级别: high (修改需架构师确认)

## Data Constraints

### order 表无唯一索引
- 规则: order 表不能加唯一索引
- 原因: 并发写入场景，唯一索引会导致死锁
- 来源: 张三, 2026-02-20, 线上事故复盘
- 验证: 3 次, 从未推翻
- 保护级别: critical (修改需 CTO 确认)
```

### Step 5: Session Start Loading

`session-start.sh` 优先加载 constraints：

```
[AI-CONTEXT] Loading L2 constraints (8 rules)...
[AI-CONTEXT] Loading snapshot (L1 + L3)...
[AI-CONTEXT] Execute /health to validate...
```

**优先级**：L2 > L3 > L1。约束知识优先于过程知识。

## Integration with /health

`/health` 校验时，L2 知识有特殊处理：

| L2 状态 | 处理 |
|---------|------|
| contradicted | **强制输出警告**，不自动修复，等待人工裁决 |
| stale | 标记但保留，不删除 |
| healthy | 正常 |

L2 知识不会因为"代码里找不到"就标记 stale——它的权威性来自业务/架构约定，不是代码。

## Commands

### /constraint promote

手动触发知识提升检查：

```
/constraint promote
→ 扫描 L3 知识，列出可提升候选
→ 等待用户确认
→ 写入 constraints.md
```

### /constraint list

列出所有 L2 约束：

```
/constraint list
→ 输出 constraints.md 内容摘要
→ 按保护级别分组
```

### /constraint check <file>

检查文件是否违反 L2 约束：

```
/constraint check OrderService.java
→ 扫描代码
→ 检查是否违反"订单-库存解耦"约束
→ 输出结果
```

## Summary

L2 约束层是 Lore 的"安全带"：
- **沉淀**：L3 验证后自动提升
- **保护**：变更需要更高阈值
- **优先**：入场时优先加载
- **独立**：不与 snapshot 混在一起
