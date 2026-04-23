# Knowledge Schema — 知识提取标准与规范

## 核心原则

不是所有代码变更都值得记录。只记录代码无法表达的信息：

- **WHY** — 为什么这么设计
- **WHERE** — 配置在哪里
- **WHICH** — 多条路径用哪条
- **FLOW** — 端到端流程
- **CONSTRAINT** — 不能碰的东西

## 知识分类

### 1. DECISION（决策）

**定义**: 一个设计选择及其原因。

**判断标准**:
- 用户在对话中解释了"为什么选 A 不选 B"
- 纠正了 agent 的错误建议
- 描述了一个技术方案背后的权衡

**示例**:
- "用 MetaQ 不用定时任务是因为要支持分布式"
- "这里加了冗余字段是为了避免跨服务查询"

**不记录**: 变量重命名、格式调整、纯粹 bug fix

### 2. CONSTRAINT（约束）

**定义**: 一条不可违背的规则及其原因。

**判断标准**:
- "这里不能改，因为..."
- "上次有人改了导致..."
- "必须满足 X 否则会 Y"

### 3. ARCHITECTURE（架构）

**定义**: 系统之间的关系、流程的描述。

**判断标准**:
- 用户描述了 A 服务调用 B 服务的原因和方式
- 用户解释了一个端到端流程

### 4. EXTERNAL（外部）

**定义**: 定义在外部依赖中的关键信息，AI 无法从源码读取。

**判断标准**:
- 用户告诉 agent 某个外部 JAR 的类的字段含义
- 用户说明了一个外部 API 的契约

## 增量文件格式

每条增量文件 **必须** 包含以下元数据：

```markdown
# YYYY-MM-DD <slug>

## Meta
- author: <用户名>
- timestamp: <YYYY-MM-DD HH:MM:SS>
- trigger: <对话自动提取 / commit 提取 / 手动输入>
- confidence: <high / medium / low>

## Affected Files
- `文件路径` → [DECISION/CONSTRAINT/ARCHITECTURE/EXTERNAL]
- `文件路径` → [类型]

## Changes
- `文件路径`: <改了什么>

## Decisions
- <决策标题>
  - 原因: <为什么这么选>
  - 讨论中提及: <相关背景>
  - 来源: <用户对话中谁说的>

## Constraints
- <约束描述>
  - 原因: <为什么不能改>
  - 来源: <用户明确告知 / 历史事故 / 代码分析>

## Architecture Impact
- <对项目的理解产生了哪些更新>

## Evidence
- 来源: <利普，2026-04-23，开发对话>
- 验证状态: <unverified / verified / challenged>
- 验证人: <review 确认的人>
```

### 置信度判定

| 级别 | 条件 | 处理 |
|------|------|------|
| **high** | 模块 owner 说的、有明确证据（线上事故、代码注释） | 直接进入快照 |
| **medium** | 团队成员说的、逻辑上合理但未被验证 | 进入快照，标注待验证 |
| **low** | 新人说的、第一次碰这个模块、信息不完整 | 进入 increments，不进入快照，需验证 |

### 验证状态流转

```
unverified → verified (有人 review 确认)
unverified → challenged (有人提出异议)
challenged → resolved (冲突解决，标记原因)
```

## 冲突标记规范

当 `/evolve` 编译快照时，发现新知识与已有快照矛盾：

```markdown
### [CONFLICT] <主题>
- 已有快照说: <旧内容> (记录于 YYYY-MM-DD, author: XXX)
- 新增增量说: <新内容> (记录于 YYYY-MM-DD, author: YYY)
- 状态: pending_resolution
- 处理: 需要人工裁决。在确认前，快照保留双方记录。
```

冲突条目 **不自动覆盖**，保留双方直到有人确认哪个是对的。

## 编辑前防护（Pre-edit Guard）

当开发者编辑一个在 `.ai-context/` 中有知识沉淀关联的文件时：

1. PreToolUse hook 拦截编辑
2. 提取该文件在 snapshot/increments 中的所有相关知识
3. 注入提示给 agent：
   ```
   ⚠️ 此文件有相关知识沉淀：
   [DECISION] buffer flush 阈值基于知识条目数
     原因: 按轮数不准确（利普, 2026-04-23）
   如果你要修改这个值，请说明原因。你的修改将被记录为新的 DECISION。
   ```
4. agent 确认后继续，修改原因自动写入 buffer → 知识更新

## 知识生命周期

```
产生 → 写入 buffer → /digest 整理为 increment (含 author + timestamp)
  → git commit + push → 团队 review
    → review 通过 → verified
    → 有人 challenge → challenged → 人工裁决
  → /evolve 编译 → 高置信度 → 进入 snapshot
                → 低置信度 → 标记待验证
                → 有冲突 → 标记 CONFLICT，保留双方
```
