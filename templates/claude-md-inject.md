# AI Context 自动积累规则

> This section is injected by `ai-context init`. It instructs the agent to
> automatically buffer knowledge during development and flush on trigger.

## 缓冲规则（每次回复结束时自动执行）

在每次回复结束后，检查本次对话中是否包含以下知识信号：

| 信号 | 含义 | 示例 |
|------|------|------|
| **DECISION** | 用户纠正了你的理解或解释了设计原因 | "不对，这个不能这么改，因为..." |
| **CONSTRAINT** | 用户提到了不可违背的规则 | "这里千万别动，上次改了出了线上事故" |
| **ARCHITECTURE** | 用户描述了系统关系或流程 | "这个流程是先...然后...最后..." |
| **EXTERNAL** | 发现了外部依赖的关键信息 | "这个类定义在外部 JAR 里，字段是..." |

**如果包含** → 以追加模式写入 `.ai-context/buffer.md`：

```
[round: N] [TYPE] 一句话摘要
  - 详情: 1-3 句具体信息
  - 关联文件: 文件路径（如果涉及具体代码文件）
  - 来源: 用户对话 / 代码分析
  - 置信度: high（用户明确告知）/ medium（代码分析推断）/ low（agent 猜测）
```

**关键规则**：
- 不要中断对话
- 不要提示用户
- 不要确认
- 只是在 buffer 中追加
- 本轮没有知识信号？静默跳过，不要写空条目
- 必须记录来源（谁说的、在什么场景下说的）

## 编辑防护规则

当你要编辑一个文件时，先检查该文件是否在 `.ai-context/snapshot.md` 或 `.ai-context/increments/` 中有相关知识关联：

1. 如果该文件有知识沉淀 → 在回复中先展示这些知识
2. 如果你的修改与已有知识矛盾 → 解释为什么这么改
3. 你的解释本身会被记录为新的 DECISION

示例：
```
⚠️ 你要修改的 hooks/stop-flush.sh 有以下知识关联：
[DECISION] buffer flush 阈值基于知识条目数 (利普, 2026-04-23)
如果你要修改这个值，请说明原因。
```

## Flush 规则

当收到 `/digest` 指令时（由 Stop hook、PostToolUse hook 或用户手动触发）：
1. 读取 `.ai-context/buffer.md`
2. 执行 `/digest` skill 将 buffer 整理为 increment 文件
3. increment 必须包含 author、timestamp、confidence、affected_files、evidence
4. 清空 buffer

当收到 `/evolve` 指令时：
1. 执行 `/evolve` skill 编译快照
2. 检测冲突 → 有冲突时标记 CONFLICT，不自动覆盖
3. 低置信度知识不进入快照，标记为待验证
4. 归档旧增量

## 快照读取规则

会话开始时：
1. 检查 `.ai-context/snapshot.md` 是否存在
2. 如果存在 → 读取以获得项目全景理解
3. 注意 snapshot 中的 [CONFLICT] 标记和 [待验证] 项
4. 基于快照的理解开始工作，不要从零探索
