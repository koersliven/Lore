# AI 友好型代码库：特征、反模式与改造指南

> 本文基于 AI Agent（Claude Code）在真实企业级 Java 项目中的实际探索经验总结。
> 不是理论推演，而是"AI 在读你的代码时，到底卡在了哪里"的第一手观察。

---

## 一、什么是 AI 友好型代码库

AI 友好型代码库的核心定义：

**AI 能在最少的探索轮次内，准确理解代码意图，并在此基础上正确地修改它。**

这里的"AI"不限于 Claude Code，也包括 Cursor、Copilot、Windsurf 等任何依赖代码上下文理解的 AI 工具。

"友好"不是一个二元标签，而是一个频谱——从"AI 读一眼就懂"到"AI 花 30 分钟和 $12 才搞清楚一个流程"。

### 与"人类友好"的关系

AI 友好型 ≈ **新人第一天友好型**。

区别在于：
- 新人可以问同事、参加 onboarding、看内部 wiki
- AI 只能读代码、读注释、读文档、搜索符号

所以 AI 友好型改造的本质是：**把"问同事才能知道"的知识，沉淀到代码和文档里。**

---

## 二、AI 理解代码的方式

要理解什么是"AI 友好"，先要理解 AI 是怎么读代码的。

### AI 的认知模型

```
1. 入口识别    → 从 Controller/命令行/测试 找到起点
2. 调用链追踪  → 顺着方法调用一层层往下读
3. 数据流追踪  → 理解输入是什么、经过什么变换、输出是什么
4. 配置发现    → 找到影响行为的开关、阈值、特性标志
5. 心智模型建立 → 在脑中（上下文窗口中）拼出完整图景
```

### AI 的硬约束

| 约束 | 影响 |
|------|------|
| **上下文窗口有限** | 不能同时看 50 个文件，必须选择性读取 |
| **无法运行代码** | 不能通过 debug 验证假设，只能静态分析 |
| **无法问人** | 没有"去问下隔壁同事这个字段什么意思"的选项 |
| **按 token 计费** | 每多探索一轮，都有时间和金钱成本 |
| **无法访问外部系统** | 看不到 Diamond 配置、数据库内容、外部 JAR 源码 |

**AI 不友好的代码，就是让 AI 在这些约束下频繁碰壁的代码。**

---

## 三、AI 不友好的代码特征（反模式）

### 3.1 关键定义不可达

**症状**：核心 DTO、接口定义在外部 JAR 包中，AI 无法读取源码。

```
# AI 看到了调用
abilityExpand.getCategoryExpand().getPredictCategory()

# 但 AbilityExpand 的类定义在 nurture-product-tenant-common.jar 里
# AI 不知道这个类还有哪些字段、哪些方法
# 只能从项目中所有对它的调用反推它的结构
```

**为什么有害**：AI 被迫用"考古法"理解一个类——遍历所有调用点，拼凑出字段列表。这极其低效，而且容易遗漏。

**严重程度**：🔴 高——直接导致 AI 无法完成任务或给出错误建议。

### 3.2 流程靠异步消息串联，无全局视图

**症状**：一个业务流程跨越多种异步机制，没有任何地方描述完整链路。

```
Controller 
  → MetaQ 消息 → FetchTaskListener 
  → MetaQ 消息 → AggregateTaskListener 
  → MetaQ 消息 → CategoryProcessorTaskListener 
  → [等待用户] 
  → SchedulerX 定时轮询 → MigrationOptimizedTaskProcessor 
  → [等待用户] 
  → CompletableFuture.runAsync() → PostStrategy
```

**为什么有害**：AI 在追踪 `controller.startMigration()` 时，发现它发了一条 MQ 消息就返回了。然后需要搜索哪个 Consumer 消费这个 Topic/Tag，找到后发现又发了另一条消息……每跳一步都需要一次搜索 + 读文件。一个 5 步流程需要至少 10 次工具调用。

**严重程度**：🔴 高——直接导致理解成本翻倍。

### 3.3 配置散落多处

**症状**：影响同一个功能的配置分散在 5+ 个地方。

```
要回答"类目预测能不能关掉"，AI 需要检查：
1. AbilityExpand.categoryExpand.predictCategory    → 代码开关
2. MigrationDataSwitcher.categoryPredictDemote     → 静态开关
3. migrationConfigCenter.getLlmPredictCategoryGray  → Diamond 灰度比例
4. application.properties                          → 可能有覆盖
5. 数据库 SiteMigrationRule                        → 规则级配置
```

**为什么有害**：AI 找到一个开关后，无法确定"还有没有其他开关也影响这个行为"。它必须穷举搜索才能给出完整答案。

**严重程度**：🟡 中——不阻断但降低准确度。

### 3.4 同一能力多条路径，无文档说明关系

**症状**：同一个业务能力有 3-4 种调用方式，没有说明它们的区别和适用场景。

```
CPV 优化的 4 种调用路径：
1. AttributeExpandProcessor         → Pipeline 内处理器
2. OpenApiCpvOptimizationService    → HSF 独立服务
3. SmartPostingPipelineExecutor     → SmartPosting 选择性执行
4. ProductOptimizationDomainService → 重优化入口

哪个是"正统"？哪个是历史遗留？哪个是给外部调用的？
```

**为什么有害**：AI 在推荐"你应该调用哪个"时，可能选错路径。历史遗留代码和当前代码并存，AI 无法区分。

**严重程度**：🟡 中——可能导致错误建议。

### 3.5 隐式行为

**症状**：代码中存在不明显的副作用或数据变换，没有注释说明原因。

```java
// 你的类目名称被悄悄拼到了描述里
// 不看代码根本不知道这个行为存在
param.setDesc(StringUtils.join(
    ArrayUtils.toArray(generalProductDTO.getCategory(), param.getDesc()), " | "));
```

```java
// @Order(2) 决定了这个处理器的执行顺序
// 但处理器文件分散在不同目录，要汇总所有 @Order 值才能理解执行序
@Order(2)
public class ImageProcessor extends AbsPreOptimizationProcessor { ... }
```

**为什么有害**：AI 看到 `setDesc()` 时以为只是设置描述，不知道这实际上是在给类目预测注入上下文。这种"代码做了比表面看起来更多的事"的模式，AI 很难识别。

**严重程度**：🟡 中——导致 AI 对行为的理解出现偏差。

### 3.6 命名不一致

**症状**：同一个概念在不同上下文中用不同名字。

```
"类目" 的不同表示：
- category（String，类目名称文本）
- categoryId（Long，类目数字 ID）
- categoryName（String，有时和 category 相同）
- cateId（String，又一个 ID 变体）
- stdCategoryDTO.getCategoryId()（外部 API 返回的 ID）
- leafCategory（叶子类目）
- firstCategoryDesc（一级类目描述）

"图片" 的不同表示：
- images、img、photo、pic、imageUrl、predictImg、imgForDesc
```

**为什么有害**：AI 搜索 `categoryId` 时可能漏掉叫 `cateId` 的地方。同一字段不同名字会让 AI 无法建立正确的数据流关系。

**严重程度**：🟠 中低——增加搜索遗漏风险。

### 3.7 没有接口契约文档

**症状**：REST API 没有 Swagger/OpenAPI 文档，请求/响应结构需要从代码推断。

```java
@PostMapping(value = "/smart-posting/start-migration.json")
public WebResponseDTO<Long> startMigration(@RequestBody MigrationStartRequest req) {
    // AI 需要找到 MigrationStartRequest 的定义
    // 才能知道这个接口需要传什么参数
    // 如果 MigrationStartRequest 又引用了其他 DTO……递归查找
}
```

**为什么有害**：当用户问"我怎么调用这个接口"时，AI 需要层层追踪 DTO 定义，而不是直接给出参数说明。

**严重程度**：🟠 中低——增加探索轮次。

---

## 四、AI 友好型代码的特征

### 4.1 架构自描述

**项目根目录有一份简洁的架构说明**，回答 AI 最先会问的 5 个问题：

```markdown
# ARCHITECTURE.md（或 CLAUDE.md）

## 核心流程
Excel 上传 → 解析(MetaQ) → 聚合(MetaQ) → 类目预测 → [用户确认] → 优化(SchedulerX) → [用户确认] → 发品

## 关键入口
- 批量发品：ExcelSmartPostingController /smart-posting/start-migration.json
- 单品优化：AiBatchOptimizationController /ai/batch/

## 配置位置索引
- 能力开关：AbilityExpand（nurture-product-tenant-common.jar，字段说明见下方）
- 灰度控制：Diamond ggs_excel_smart_posting_config
- 代码开关：MigrationDataSwitcher

## AbilityExpand 字段说明（外部 JAR，AI 无法直接读取）
- categoryExpand.predictCategory: Boolean — 是否启用类目预测
- cpvExpand.openCpvOptimized: Boolean — 是否启用 CPV 扩展
- ...
```

这份文档不需要长——500 字就能省掉 AI 30 分钟的探索时间。

### 4.2 流程可追踪

在流程入口处或文档中，提供**端到端的调用链注释**：

```java
/**
 * Excel 批量发品主流程：
 * 
 * 1. startMigration() → 创建任务，发 MetaQ(FETCH_TAG)
 * 2. FetchTaskListener → 解析 Excel，图片上传到 PhotoBank，发 MetaQ(AGGREGATE_TAG)
 * 3. AggregateTaskListener → 数据聚合，发 MetaQ(CATEGORY_PROCESSOR_TAG)
 * 4. CategoryProcessorTaskListener → 预处理（图片/翻译/类目预测），停在 CATEGORY_CONFIRM
 * 5. categoryConfirmed() → 用户确认类目，产品状态改为 OPTIMIZATION_INIT
 * 6. MigrationOptimizedTaskProcessor（SchedulerX 轮询） → 执行优化 Pipeline，停在 POST_CONFIRM
 * 7. postConfirmed() → 用户确认发品，异步提交到 ICBU
 */
@PostMapping(value = "/smart-posting/start-migration.json")
public WebResponseDTO<Long> startMigration(...) { ... }
```

### 4.3 接口契约显式化

```java
// 方式 1：Swagger 注解
@ApiModel("批量发品请求")
public class MigrationStartRequest {
    @ApiModelProperty(value = "Excel 文件 URL", required = true)
    private String excelUrl;
    
    @ApiModelProperty(value = "能力列表，控制执行哪些优化", required = true)
    private List<MigrationUserAbilityDTO> abilityList;
}

// 方式 2：至少有字段注释
public class MigrationStartRequest {
    /** Excel 文件 URL（OSS 地址）*/
    private String excelUrl;
    
    /** 优化能力列表，可选值见 SmartPostingProcessorType 枚举 */
    private List<MigrationUserAbilityDTO> abilityList;
}
```

### 4.4 外部依赖有本地描述

对于定义在外部 JAR 中的关键类，在项目内维护一份**字段索引**：

```markdown
# docs/external-dto-index.md

## AbilityExpand（来自 nurture-product-tenant-common）
| 字段路径 | 类型 | 默认值 | 说明 |
|---------|------|--------|------|
| categoryExpand.predictCategory | Boolean | true | false=跳过类目预测 |
| cpvExpand.openCpvOptimized | Boolean | false | true=启用 AI CPV 扩展 |
| titleExpand.openTitleOptimized | Boolean | false | true=启用标题优化 |
| whiteBackgroundImageExpand.openOptimized | Boolean | false | true=启用白底图生成 |
| sceneImageExpand.openOptimized | Boolean | false | true=启用场景图生成 |
```

### 4.5 命名一致性

```
# 制定命名规约，在 CLAUDE.md 或 CONTRIBUTING.md 中声明

术语表：
- categoryId: Long — ICBU 叶子类目数字 ID，全局唯一
- categoryName: String — 类目英文名称
- categoryPath: String — 类目完整路径，用 " > " 分隔
- 不要使用 cateId、category（歧义）、leafCategory 等变体
```

### 4.6 配置集中索引

不要求配置物理集中（那不现实），但要有一个**索引**告诉 AI 去哪里找：

```markdown
# docs/config-index.md

## 批量发品配置索引
| 行为 | 配置位置 | 配置项 | 说明 |
|------|---------|--------|------|
| 是否走 SmartPosting 流程 | Diamond | ggs_excel_smart_posting_config | 按 companyId 灰度 |
| 是否跳过类目预测 | AbilityExpand | categoryExpand.predictCategory | API 参数传入 |
| LLM vs QP 类目预测比例 | Diamond/代码 | llmPredictCategoryGray | 0-100 灰度值 |
| 类目预测降级开关 | 代码 | MigrationDataSwitcher.categoryPredictDemote | 静态字段 |
| 强制处理器列表 | 代码 | SmartPostingTaskItemInitService.ensureMandatoryProcessorTypes() | 硬编码 |
```

### 4.7 可独立理解的模块

```java
// 不友好：处理器紧耦合完整的上下文对象
public boolean doOptimize(GeneralProductDTO dto, OriginConfigModel config, TargetSiteEnum site) {
    // 需要理解 GeneralProductDTO 的 50+ 个字段
    // 需要理解 OriginConfigModel 的嵌套结构
    // 才能知道这个处理器实际读写了哪些字段
}

// 友好：处理器声明自己的输入输出
/**
 * 输入：dto.title, dto.categoryId, dto.attribute, dto.images[0]
 * 输出：dto.attribute（合并 AI 预测的新属性）
 * 依赖：CpvExtractionService（HSF）, AccountContextBuilder
 */
public boolean doOptimize(GeneralProductDTO dto, ...) { ... }
```

---

## 五、AI 友好型改造路线图

### 第一优先级：投入产出比最高（1-2 天）

| 改造项 | 做什么 | 效果 |
|--------|--------|------|
| **CLAUDE.md / ARCHITECTURE.md** | 500 字描述核心流程、关键入口、配置位置 | AI 探索时间从 30 分钟降到 5 分钟 |
| **外部 DTO 字段索引** | 列出 AI 看不到的外部 JAR 类的字段 | 消除最大的信息黑洞 |
| **配置索引** | 一张表列出"改 X 行为去哪里" | AI 不再需要穷举搜索配置 |

### 第二优先级：显著提升体验（1 周）

| 改造项 | 做什么 | 效果 |
|--------|--------|------|
| **核心流程入口注释** | 在 Controller 方法上写端到端调用链 | AI 一次读取就能理解流程 |
| **Swagger/OpenAPI** | 关键接口加上参数文档 | AI 能直接给出 API 调用示例 |
| **处理器 I/O 声明** | 每个处理器注释说明读写哪些字段 | AI 能判断处理器之间的依赖关系 |

### 第三优先级：长期收益（持续）

| 改造项 | 做什么 | 效果 |
|--------|--------|------|
| **命名一致性** | 制定术语表，新代码遵循 | 减少搜索遗漏 |
| **减少隐式行为** | 副作用加 WHY 注释 | AI 不会误判行为 |
| **标记历史遗留** | `@Deprecated` + 说明当前替代方案 | AI 不会推荐过时路径 |
| **接口版本标注** | 多条路径标注哪个是当前推荐的 | AI 推荐正确的调用方式 |

---

## 六、改造的度量方式

### 定性度量

让 AI 回答以下问题，看它需要几轮探索：

1. "这个项目的核心业务流程是什么？" — 目标：1 轮（读 ARCHITECTURE.md）
2. "我要关掉 X 功能，在哪里改？" — 目标：1-2 轮（读配置索引 + 确认）
3. "这个接口需要传什么参数？" — 目标：1 轮（读 Swagger 文档）
4. "A 和 B 两个类有什么区别？" — 目标：1 轮（读注释或文档）

### 定量度量

```
改造前：理解一个核心流程 = 3 个 Agent × 5 分钟 = $12, 25 分钟
改造后：理解一个核心流程 = 读 1 个文件 = $0.05, 10 秒
```

成本下降 200 倍，这就是改造的 ROI。

---

## 七、常见误区

### "加更多注释就是 AI 友好"

❌ 错。AI 不需要解释 WHAT 的注释（代码自己说了），需要解释 **WHY** 的注释。

```java
// ❌ 没有价值的注释
// 设置类目 ID
generalProductDTO.setCategoryId(stdCategoryDTO.getCategoryId());

// ✅ 有价值的注释
// category 文本拼到 desc 里是因为 LLM prompt 需要类目信息作为上下文
// 而 prompt 模板只有 desc 和 title 两个变量，没有单独的 category 输入
param.setDesc(StringUtils.join(...));
```

### "代码写得好就不需要文档"

❌ 错。代码只描述 HOW（怎么做），不描述：
- **WHY**（为什么这么做）
- **WHERE**（配置在哪里）
- **WHICH**（多条路径用哪条）
- **FLOW**（端到端流程）

这些信息只存在于团队成员的脑子里，AI 无法访问。

### "Swagger 文档就够了"

❌ 不够。Swagger 只覆盖 HTTP 接口层。AI 还需要：
- 内部服务之间的调用关系
- 异步流程的串联方式
- 配置项的位置和含义
- 外部依赖的接口定义

### "AI 友好型改造 = 大规模重构"

❌ 错。最高 ROI 的改造是**加文档**，不是改代码。一份 500 字的 ARCHITECTURE.md 比重构 10 个类的收益更大。代码层面的改造应该随日常开发渐进进行，而非专门立项。

---

## 八、总结

```
AI 友好型代码库 = 自描述 + 可追踪 + 显式配置 + 一致命名

核心公式：
  AI 探索成本 = f(信息分散度 × 隐式行为数 × 外部依赖不可见度)

改造目标：
  让上述三个因子尽可能小

最小可行改造：
  1. 一份 ARCHITECTURE.md（500 字）
  2. 一份外部 DTO 索引（列出 AI 看不到的字段）
  3. 一份配置索引（列出"改 X 去哪里"）
  
  总投入：半天。收益：AI 效率提升 10-50 倍。
```
