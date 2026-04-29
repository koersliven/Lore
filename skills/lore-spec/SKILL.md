---
name: lore-spec
description: Create and manage L0 prescriptive design specs before writing code
category: ai-context
---

# /spec — L0 Prescriptive Design Spec

在写代码之前，先写下设计意图。L0 是 Lore 的 prescriptive 层——不是记录"代码是什么"，而是记录"代码应该是什么"。

## 与 L3 的区别

| | L3 (Process) | L0 (Spec) |
|--|-------------|-----------|
| **内容** | 已发生的决策和原因 | 尚未实现的设计意图 |
| **来源** | 对话中自动提取 | 人工主动编写 |
| **时机** | 代码之后 | 代码之前 |
| **格式** | 描述性（发生了什么） | 规定性（应该怎么做） |

## When to Trigger

- 开始一个新模块/功能之前
- 用户说"先设计再写代码"
- 用户说"/spec" 显式调用

## Process

### Step 1: Identify Target Module

如果 `modules/` 存在：
1. 读取 `modules/_index.md` 列出已知模块
2. 让用户选择要给哪个模块写 spec
3. 如果模块不存在，先用 `/lore-modularize` 发现模块

如果 `modules/` 不存在：
- Spec 放在项目级 `specs/` 目录（暂不支持模块）

### Step 2: Select Spec Type

```
支持的 Spec 类型：
1. api-design — API 设计（端点、请求、响应、错误码）
2. data-model — 数据模型（实体、字段、关系）
3. flow-design — 流程设计（状态机、业务流程）
4. interface-contract — 接口契约（模块间调用约定）
```

### Step 3: Create Spec File

在 `modules/<module>/specs/` 下创建 `<type>-<name>.md>`：

```markdown
# Spec: {{API Name / Feature Name}}

> Type: {{api-design / data-model / flow-design / interface-contract}}
> Module: {{module-name}}
> Author: {{author}}
> Created: {{YYYY-MM-DD}}
> Status: draft  ← draft | proposed | approved | implemented | superseded

## Design Intent

{{描述设计目标和约束，不是实现细节}}

## Spec Details

{{具体规格，视类型而定}}

### API Design
- Endpoint: POST /api/...
- Request: {{schema}}
- Response: {{schema}}
- Errors: {{error codes}}

### Data Model
- Entity: {{name}}
- Fields: {{field list}}
- Relationships: {{relations}}

### Flow Design
- Entry: {{trigger}}
- States: {{state list}}
- Transitions: {{transitions}}

## Implementation Checklist

- [ ] 基础结构已创建
- [ ] 核心逻辑实现
- [ ] 测试覆盖
- [ ] 文档更新

## Notes

{{额外说明}}
```

### Step 4: Link to Knowledge

当 spec 状态变为 `implemented` 时：
1. 将 spec 的核心设计决策转为 L3 知识
2. 写入 `modules/<module>/increments/` 作为 increment
3. 将 spec 状态改为 `implemented`

```markdown
## Post-Implementation

从本 spec 提炼的知识：
- [DECISION] {{设计决策}}
  - 来源: spec/{{spec-name}}.md
  - confidence: high（经过设计评审）
```

## Commands

### /spec create <module> <type> <name>

创建新 spec：
```
/spec create order api-design order-creation
→ 创建 modules/order/specs/api-design-order-creation.md
```

### /spec list <module>

列出模块的所有 specs：
```
/spec list order
→ 输出所有 order specs 及状态
```

### /spec approve <module>/<spec-name>

将 spec 状态从 `draft` → `proposed` → `approved`：
```
/spec approve order/api-design-order-creation
→ 状态更新为 approved
```

### /spec implement <module>/<spec-name>

标记 spec 为已实现，并提取知识：
```
/spec implement order/api-design-order-creation
→ 状态改为 implemented
→ 生成 increment
```

### /spec drop <module>/<spec-name>

废弃 spec：
```
/spec drop order/api-design-order-creation
→ 状态改为 superseded
```

## Output

创建时：
```
+ Spec created: modules/order/specs/api-design-order-creation.md
  Status: draft
  Next: /spec approve order/api-design-order-creation
```

状态变更时：
```
+ Spec updated: order/api-design-order-creation
  draft → approved
```

实施时：
```
+ Spec implemented: order/api-design-order-creation
  + Increment created: modules/order/increments/YYYY-MM-DD_spec-implemented.md
  + 1 decision extracted
```
