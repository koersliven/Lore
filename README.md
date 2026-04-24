# Lore

> 管理代码中的 WHY。

## 一句话说明

**Lore 让开发者的隐性知识（WHY、约束、架构）随代码一起版本化、传播、积累。**

## 问题

Git 记录了 who + what + when，但 **WHY 在开发者脑子里**。

- 为什么选这个方案？
- 这个配置为什么不能改？
- 这个流程是怎么走的？

**人走了，WHY 就死了。** 新人接手项目，从零开始理解。AI agent 每次都是"第一天上班"。

## 解决方案

Lore 是一套**自动知识积累机制**：

```
开发对话 → 知识自动流出 → 结构化沉淀 → 随代码传播
```

**核心特点**：
- **零负担** — 正常开发对话，知识自动积累
- **自动触发** — 条目数、时间、commit 多重触发
- **git 传播** — 知识随代码一起 push/pull
- **三层架构** — L1 结构层、L2 约束层、L3 过程层

## 快速开始

### 1. 克隆 Lore

```bash
git clone https://github.com/koersliven/Lore.git
```

### 2. 在你的项目中安装

#### Claude Code

```bash
cd your-project
bash /path/to/Lore/hooks/install.sh
```

这会：
- 创建 `.lore-hooks/` 目录，复制所有 hook 脚本
- 修改 `.claude/settings.json`，注入 hooks
- 配置自动触发机制

#### Cursor

```bash
# 1. 安装 hooks（同上）
cd your-project
bash /path/to/Lore/hooks/install.sh

# 2. 手动配置 Cursor 读取知识
# 在项目根目录创建 .cursorrules，添加：
```

```markdown
# Lore 知识库

读取 .ai-context/snapshot.md 获得项目理解。
读取 .ai-context/increments/ 获得知识增量。
```

#### Codex / 其他工具

```bash
# 1. 安装 hooks
bash /path/to/Lore/hooks/install.sh

# 2. 在工具的配置文件中添加：
# - 读取 .ai-context/snapshot.md 作为项目上下文
# - 配置 git commit 后执行 .lore-hooks/post-commit-digest.sh
```

### 3. 初始化知识库

```
/init-context
```

Agent 会问你 5 类问题：外部依赖、配置、数据层、业务背景、隐式契约。

### 4. 正常开发

什么都不用做。你在对话中说的 WHY、约束、架构，会自动被记录。

### 5. 验证安装

```bash
# 检查 hooks 是否安装成功
ls .lore-hooks/

# 应该看到：
# install.sh
# post-commit-digest.sh
# pre-edit-guard.sh
# session-end-flush.sh
# session-start.sh
# snapshot-guard.sh
# stop-flush.sh
```

## 目录结构

```
.ai-context/
├── snapshot.md      ← 项目全景（agent 入场时读取）
├── buffer.md        ← 对话缓冲区（实时写入）
├── increments/      ← 知识增量文件
│   ├── 2026-04-24_payment-timeout.md
│   └── archive/     ← 已编译的旧增量
└── config.yaml      ← 框架配置
```

## 三层架构

Lore 将知识分为三层，各有不同的来源和管理方式：

| 层级 | 名称 | 来源 | 内容 | 更新方式 |
|------|------|------|------|---------|
| **L1** | 结构层 | 代码扫描 | 模块、入口、依赖 | `/sync` 自动扫描 |
| **L2** | 约束层 | 对话沉淀 | 不可违背的规则 | 需人工确认提升 |
| **L3** | 过程层 | 对话流出 | WHY、决策、流程 | 自动积累 |

**L3 → L2 提升**：过程知识经过多次验证后，自动提升为约束层。

## 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                     开发对话 + AI Agent                           │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      知识自动流出                                 │
│  • DECISION — 设计选择及原因                                     │
│  • CONSTRAINT — 不可违背的规则                                   │
│  • ARCHITECTURE — 系统关系和流程                                 │
│  • EXTERNAL — 外部依赖信息                                       │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    .ai-context/buffer.md                         │
│                      (临时缓冲区)                                 │
└───────────────────────┬─────────────────────────────────────────┘
                        │ 触发条件: 条目>=5 / 时间>=20min / commit
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    /digest → increments/                         │
│                      (知识增量文件)                               │
└───────────────────────┬─────────────────────────────────────────┘
                        │ 触发条件: increments>=3
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    /evolve → snapshot.md                         │
│                      (项目全景快照)                               │
└───────────────────────┬─────────────────────────────────────────┘
                        │ git push
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                   全团队成员继承知识                              │
│              任何 AI 工具 clone 即获得项目理解                     │
└─────────────────────────────────────────────────────────────────┘
```

**完整架构图**：[architecture.md](architecture.md)
**数据流图**：[dataflow.md](dataflow.md)

## 自动触发机制

Lore 有多重自动触发，确保知识不丢失：

| 触发条件 | 动作 | 说明 |
|---------|------|------|
| Buffer 条目 >= 5 | `/digest` | 建议刷新 |
| Buffer 条目 >= 8 | `/compact` + `/digest` | 压缩后刷新 |
| Buffer 条目 >= 15 | 强制执行 | 防止丢失 |
| **时间 >= 20分钟** | `/digest` | 长对话保护 |
| git commit | 提取知识 | 随代码提交 |
| 未归档 increments >= 3 | `/evolve` | 编译快照 |

**优先级**：evolve > compact > digest

## Skills（7 个技能）

| Skill | 作用 | 触发方式 |
|-------|------|---------|
| `/init-context` | 0→1 引导式问答 | 手动 |
| `/digest` | buffer → increment | 自动/手动 |
| `/compact` | 知识压缩合并 | 自动/手动 |
| `/evolve` | 编译 snapshot | 自动/手动 |
| `/health` | 知识健康校验 | 自动（SessionStart） |
| `/sync` | L1 结构扫描 | 手动 |
| `/constraint` | L2 约束管理 | 手动 |

## Hooks（7 个触发器）

| Hook | 事件 | 作用 |
|------|------|------|
| `stop-flush.sh` | Agent 停止 | 检测 buffer/时间/increments |
| `post-commit-digest.sh` | git commit | 提取知识写入 increment |
| `session-start.sh` | 会话开始 | 加载 snapshot + 检查 evolve |
| `session-end-flush.sh` | 会话结束 | 紧急 flush |
| `snapshot-guard.sh` | 编辑 snapshot | 拦截直接编辑 |
| `pre-edit-guard.sh` | 编辑文件 | 提示相关知识历史 |
| `install.sh` | 安装 | 注入 hooks 到项目 |

## 知识类型

只记录**代码无法表达**的信息：

| 类型 | 含义 | 示例 |
|------|------|------|
| **DECISION** | 设计选择及原因 | "选 MetaQ 因为要分布式" |
| **CONSTRAINT** | 不可违背的规则 | "这里不能改，上次出事故" |
| **ARCHITECTURE** | 系统关系和流程 | "订单创建后发两条 MQ" |
| **EXTERNAL** | 外部依赖信息 | "这个类的字段含义是..." |

**不记录**：变量重命名、格式调整、纯 bug fix —— 代码 diff 已经表达了。

## 知识识别规则

Lore 会主动识别对话中的架构相关信息，不需要你刻意说"因为..."：

### 外部依赖

| 提到 | 自动记录为 |
|------|-----------|
| Diamond / Nacos / Apollo | [EXTERNAL] 配置中心，控制 X 行为 |
| Tair / Redis | [ARCHITECTURE] 缓存层，存储 X 数据 |
| HSF / Dubbo | [ARCHITECTURE] RPC 调用，依赖 X 服务 |
| MetaQ / Kafka | [ARCHITECTURE] 消息队列，X 流程解耦 |
| TDDL / ShardingSphere | [ARCHITECTURE] 分库分表，规则是 X |

### 配置来源

| 提到 | 自动记录为 |
|------|-----------|
| "这个配置在..." | [EXTERNAL] 配置位置和含义 |
| "改了这个会..." | [CONSTRAINT] 配置变更影响 |

### 数据流向

| 提到 | 自动记录为 |
|------|-----------|
| "数据在...里" | [ARCHITECTURE] 数据存储位置 |
| "这个表..." | [ARCHITECTURE] 表结构/分片规则 |

### 架构边界

| 提到 | 自动记录为 |
|------|-----------|
| "这个服务调用..." | [ARCHITECTURE] 服务依赖关系 |
| "不能直接调用..." | [CONSTRAINT] 架构约束 |

### 示例

```
你说: "这部分依赖 diamond 配置"
Agent 识别: [EXTERNAL] Diamond 配置中心，控制超时/开关等行为

你说: "订单数据在 tddl 分库分表"
Agent 识别: [ARCHITECTURE] 订单存储: TDDL 分库分表，分片键 order_id

你说: "订单不能直接调库存，要走 MQ"
Agent 识别: [CONSTRAINT] 订单-库存解耦，必须通过 MQ
```

## 工作流程示例

```
1. 你说："上游 SLA 从 3s 升到 5s，支付超时要改"
   → Agent 自动写入 buffer: [DECISION] 支付超时改为 5s

2. 你说："不能超过 6s，否则会触发回退"
   → Agent 自动写入 buffer: [CONSTRAINT] 超时上限 6s

3. 你说："帮我提交一下"
   → git commit 触发 hook
   → hook 提取 buffer 知识 → increment 文件
   → 知识随代码一起提交

4. 团队成员 pull 代码
   → SessionStart 加载 snapshot
   → 立刻理解"支付超时为什么是 5s"
```

## 和现有方案的区别

| | CLAUDE.md | .cursorrules | **Lore** |
|--|-----------|-------------|----------|
| 知识持续增长 | ❌ 一次性 | ❌ 一次性 | ✅ 自动积累 |
| 自动提取 | ❌ 手写 | ❌ 手写 | ✅ 对话提取 |
| 团队共享 | 手动 | 手动 | ✅ git 原生 |
| 版本化 | ✅ | ✅ | ✅ |
| 记录 WHY | ❌ | ❌ | ✅ |
| 知识校验 | ❌ | ❌ | ✅ /health |

## 项目状态

**当前版本**：Alpha

**已实现**：
- ✅ 7 个 Skills + 7 个 Hooks
- ✅ 自动知识提取（对话 + commit）
- ✅ 多重触发机制（条目数 + 时间 + evolve）
- ✅ 三层架构（L1/L2/L3）
- ✅ 知识健康校验（/health）
- ✅ 来源追溯（author/timestamp/confidence）
- ✅ 冲突检测（不自动覆盖）
- ✅ 编辑前防护（提示历史知识）

**规划中**：
- 🔲 非 Claude Code 工具支持
- 🔲 CI/CD 集成
- 🔲 多语言 Scanner

## 参与贡献

欢迎 Issue、PR、讨论。

如果你对"什么是 AI 友好的"有自己的思考，欢迎一起探索。

## License

Apache 2.0
