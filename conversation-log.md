# 会话记录：从项目分析到 AI 友好型框架

> 日期：2026-04-22
> 参与者：利普 + Claude Code (Opus)
> 项目：ggs-product-center → ai-friendly-codebase

---

## 对话脉络

### 第一阶段：GGS Product Center 项目探索

**利普的需求**：理解 ggs-product-center 的批量搬品能力，设计本地 agent 调用方案。

**核心发现**：

1. Excel 批量搬品是一个 7 步异步流程（MetaQ + SchedulerX），只有 2 个用户确认点
2. 处理器体系有 20+ 个处理器，通过 AbilityExpand 开关控制，7 个强制处理器无法关闭
3. 类目预测有 LLM 和 QP 两条路径，category 名称只是拼到 description 里，对结果影响很弱

**关键对话**：

> **利普**：之前的测试中发现这个类目预测不太准确，会把我本地预测好的类目改成错误的类目。
>
> **分析结果**：确认了根因 — LLM 预测主要依赖 title+image 重新预测，category 名称只是补充信息。解决方案是 `predictCategory=false` + batch-update 注入 categoryId。

**最终方案**：4 步 API 调用序列
1. `start-migration`（关闭类目预测 + 选择能力）
2. `batch-update`（注入本地 agent 的 categoryId）
3. `category_confirmed`（触发优化）
4. `post_confirmed`（发品）

### 第二阶段：AI 友好型代码库思考

**触发点**：利普在探索过程中观察到 AI 在企业级项目中的痛点。

> **利普**：什么是 AI 友好型的代码和工程？这个改造究竟在改造什么？

**核心输出**：

1. 定义了 AI 的 4 个结构性盲区：无边界感知、无运行时视角、无业务视角、无网络感知
2. 7 个反模式（从 ggs-product-center 实际案例提炼）
3. 改造路线图（500 字 ARCHITECTURE.md 就能省 30 分钟探索）
4. 度量方法："AI 回答 X 问题需要几轮探索"

### 第三阶段：从原则到实践

> **利普**：能否把这些中心思想沉淀到全局配置中？

**行动**：更新了 `~/.claude/CLAUDE.md`，添加了"AI 友好型开发原则"：
- 进入新项目时的 5 个必问问题
- 开发过程中何时更新架构文档
- 项目架构文档模板
- 度量标准

### 第四阶段：开源框架构想

> **利普**：如果我要把这个思想做成一个开源项目，服务各个企业，我应该如何入手？

**产出**：AI Context Standard 开源项目策略
- 产品定位：OpenAPI 之于 REST API → AI Context 之于代码库
- 4 个核心组件：Spec + Scanner + Generator + Validator
- 7 层上下文模型（YAML Schema）
- 4 阶段路线图

---

## 关键技术发现

### 关于 ggs-product-center

| 发现 | 影响 |
|------|------|
| AbilityExpand 定义在外部 JAR 中 | AI 无法直接读取字段定义，只能从调用点反推 |
| 类目预测不使用 category 名称作为主要信号 | 用户的类目会被覆盖，必须关闭预测 |
| CategoryController 只有 ID→名称查询 | 本地 agent 需要自维护 name→ID 映射 |
| 图片补足能力已就绪 | 1 张图→3 张图，使用 DashScope qwen-image-max |
| 7 个强制处理器无法关闭 | 设计方案需要考虑这些处理器的影响 |

### 关于 AI 友好型改造

| 洞察 | 来源 |
|------|------|
| 最高 ROI 是加文档，不是改代码 | 500 字 ARCHITECTURE.md vs 重构 10 个类 |
| AI 友好 ≈ 新人第一天友好 | 区别：新人能问同事，AI 只能读代码 |
| 企业的真正挑战是知识在人脑中 | 20+ 年项目，关键知识从未文档化 |
| 配置不需要物理集中，需要索引 | 一张表："改 X 行为去哪里" |

---

## 产出文件索引

| 文件 | 内容 |
|------|------|
| `ai-friendly-codebase.md` | AI 友好型代码库完整指南（反模式、特征、改造路线图） |
| `ggs-product-center-analysis.md` | GGS 项目技术分析（流程、处理器、类目预测、API 调用方案） |
| `ai-context-open-source-strategy.md` | AI Context Standard 开源项目策略（Spec 设计、产品路线图） |
| `conversation-log.md` | 本文件 — 会话脉络和关键发现 |
