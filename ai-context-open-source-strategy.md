# AI Context Standard — 开源项目策略

> 让企业代码库对 AI 可读、可理解、可操作的标准化框架。

---

## 一、核心洞察

### AI 的 4 个结构性盲区

企业级代码库（尤其是 20+ 年积累的大型项目）对 AI 有 4 个结构性盲区：

1. **无边界感知** — AI 不知道"这个项目不能碰什么"。没有人告诉它哪些是稳定接口、哪些是实验代码、哪些数据库表有触发器。
2. **无运行时视角** — AI 只看到静态代码，看不到 Diamond 配置、数据库内容、MQ 消息流、定时任务调度。
3. **无业务视角** — AI 不知道"为什么这么做"。代码只有 HOW，没有 WHY。
4. **无网络感知** — AI 不知道这个服务被谁调用、调用谁、在什么链路上是关键节点。

### 关键认知

AI 友好型改造的本质不是重构代码，而是：**把"问同事才能知道"的知识，沉淀为机器可读的结构化描述。**

最高 ROI 的改造是加文档，不是改代码。

---

## 二、产品定义

### 名称：AI Context Standard（ai-context）

### 定位

一套描述代码库 AI 上下文的开放标准，类比：
- OpenAPI 之于 REST API → AI Context 之于代码库
- tsconfig.json 之于 TypeScript → ai-context.yaml 之于 AI Agent

### 核心组件

| 组件 | 形态 | 用途 |
|------|------|------|
| **Spec** | YAML Schema | 定义描述格式 |
| **Scanner** | CLI 工具 | 自动扫描代码库，生成初始 manifest |
| **Generator** | CLI 工具 | 将 manifest 转换为不同 AI 工具的格式（CLAUDE.md, .cursorrules, Copilot instructions） |
| **Validator** | CI 插件 | 检查 manifest 是否与代码同步 |

---

## 三、Spec 设计（v0.1）

### 7 层模型

```yaml
# ai-context.yaml
version: "0.1"
project:
  name: "ggs-product-center"
  description: "ICBU 国际站商品管理中心"
  tech_stack: ["java-21", "spring-boot-2.7", "pandora-boot"]

# Layer 1: 代码可读性（AI Scanner 可自动生成）
code:
  entry_points:
    - path: "ggs-product-center-web/src/.../ExcelSmartPostingController.java"
      description: "Excel 批量搬品主入口"
      key_endpoints:
        - "POST /smart-posting/start-migration.json"
        - "POST /migration/smart-posting/category_confirmed.json"
  modules:
    - name: "web"
      path: "ggs-product-center-web"
      role: "HTTP/HSF 入口层"
    - name: "service"
      path: "ggs-product-center-service"
      role: "核心业务逻辑"

# Layer 2: 架构可见性
architecture:
  flows:
    - name: "Excel 批量搬品"
      steps:
        - "startMigration() → MetaQ(FETCH_TAG)"
        - "FetchTaskListener → Excel解析+图片上传 → MetaQ(AGGREGATE_TAG)"
        - "AggregateTaskListener → 数据聚合 → MetaQ(CATEGORY_PROCESSOR_TAG)"
        - "CategoryProcessorTaskListener → 预处理 → CATEGORY_CONFIRM[等待用户]"
        - "categoryConfirmed() → OPTIMIZATION_INIT"
        - "SchedulerX轮询 → 优化Pipeline → POST_CONFIRM[等待用户]"
        - "postConfirmed() → 异步发品"
  state_machines:
    - name: "主任务状态"
      states: "NEW → UNDER_REVIEW → PRE_DATA → AGGREGATE_DATA → CATEGORY_CONFIRM → OPTIMISE_DATA → POST_CONFIRM → SUCCESS"

# Layer 3: 边界感知
boundaries:
  stable_interfaces:
    - "OpenApiCategoryPredictService（HSF 对外接口，不可随意修改）"
  experimental:
    - "ggs-product-center-service/.../llm/（AI 相关能力，快速迭代中）"
  danger_zones:
    - "SmartPostingTaskItemInitService.ensureMandatoryProcessorTypes() — 修改会影响所有搬品任务"

# Layer 4: 运行时上下文
runtime:
  config_sources:
    - type: "diamond"
      key: "ggs_excel_smart_posting_config"
      description: "SmartPosting 灰度配置"
    - type: "code"
      class: "MigrationDataSwitcher"
      description: "静态开关集合"
  async_mechanisms:
    - type: "metaq"
      topics: ["FETCH_TAG", "AGGREGATE_TAG", "CATEGORY_PROCESSOR_TAG"]
    - type: "schedulerx"
      jobs: ["MigrationOptimizedTaskProcessor"]
  caches:
    - type: "tair"
      usage: "类目预测结果缓存"

# Layer 5: 业务上下文
business:
  domain: "跨境电商商品管理"
  glossary:
    categoryId: "ICBU 叶子类目数字 ID（Long）"
    CPV: "Category-Property-Value，类目属性值"
    SmartPosting: "智能搬品，Excel 批量发品流程"
  decisions:
    - what: "类目预测使用 LLM + QP 双通道"
      why: "LLM 准确率高但有成本，QP 作为兜底"
    - what: "图片补足限制 MIN=3, MAX=6"
      why: "ICBU 发品最低要求 3 张图"

# Layer 6: 网络上下文
network:
  dependencies:
    - service: "CategoryClient"
      protocol: "HSF"
      description: "全球类目服务"
    - service: "DashScope"
      protocol: "HTTP"
      description: "AI 图片生成（qwen-image-max）"
  consumers:
    - service: "OpenAPI 网关"
      interface: "OpenApiCategoryPredictService"

# Layer 7: 外部不可见定义
external_types:
  - class: "AbilityExpand"
    source: "nurture-product-tenant-common.jar"
    fields:
      - path: "categoryExpand.predictCategory"
        type: "Boolean"
        description: "false=跳过类目预测"
      - path: "cpvExpand.openCpvOptimized"
        type: "Boolean"
        description: "true=启用 AI CPV 扩展"
```

---

## 四、产品路线图

### Phase 1：Spec + 手动示例（4 周）

**目标**：发布 v0.1 spec，附带真实项目示例

**产出**：
- `spec/v0.1/schema.yaml` — 完整 YAML schema
- `examples/ggs-product-center/ai-context.yaml` — 真实项目示例
- `docs/` — why.md, layers.md, getting-started.md
- README.md

**验证**：用示例 manifest 生成 CLAUDE.md，对比手写版本的效果差异

### Phase 2：Scanner CLI（8 周）

**目标**：自动扫描 Java/TypeScript 项目，生成初始 manifest

**能力**：
- 识别入口点（Controller/Router）
- 识别模块结构（Maven module / package.json workspace）
- 识别外部依赖（Maven GAV → external_types 骨架）
- 识别配置源（application.properties, @Value, Diamond annotations）

**技术**：
- Java AST 解析（JavaParser）
- TypeScript AST 解析（ts-morph）
- 支持插件扩展其他语言

### Phase 3：Generator + CI（12 周）

**目标**：从 manifest 生成多种 AI 工具格式，集成到 CI

**产出**：
- `ai-context generate --format claude` → CLAUDE.md
- `ai-context generate --format cursor` → .cursorrules
- `ai-context generate --format copilot` → .github/copilot-instructions.md
- `ai-context validate` → CI 检查 manifest 与代码是否同步

### Phase 4：社区 + 生态（持续）

- 企业案例集（匿名化）
- 各语言 Scanner 插件
- IDE 插件（VS Code / JetBrains）
- AI 工具原生集成（CLAUDE.md 自动读取 ai-context.yaml）

---

## 五、项目骨架

```
ai-context/
├── spec/
│   └── v0.1/
│       ├── schema.yaml          # YAML Schema 定义
│       └── README.md            # Spec 说明
├── examples/
│   └── ggs-product-center/
│       └── ai-context.yaml      # 真实项目示例
├── docs/
│   ├── why.md                   # 为什么需要 AI Context Standard
│   ├── layers.md                # 7 层模型详解
│   └── getting-started.md       # 快速开始
├── packages/
│   ├── scanner/                 # Scanner CLI（Phase 2）
│   └── generator/               # Generator CLI（Phase 3）
├── LICENSE                      # Apache 2.0
└── README.md                    # 项目主页
```

---

## 六、核心卖点

### 对企业

| 痛点 | 解法 |
|------|------|
| AI 工具花 30 分钟才能理解项目 | 一份 manifest 让 AI 10 秒入场 |
| 不同 AI 工具需要不同格式的配置 | 一份 manifest 生成所有格式 |
| 知识在开发者脑子里，AI 看不到 | 结构化描述，机器可读 |
| 不知道从哪里开始改造 | Scanner 自动生成基线，逐步补充 |

### 对开发者

| 痛点 | 解法 |
|------|------|
| 手写 CLAUDE.md 不知道写什么 | Schema 定义了需要哪些信息 |
| 文档容易过时 | CI validate 检查同步 |
| 每个 AI 工具配置一遍 | 写一次 manifest，生成多种格式 |

### 关键 Narrative

> "你不需要重构代码来让 AI 理解它。你只需要告诉 AI 那些它看不到的东西。"

---

## 七、与竞品差异

| 方案 | 覆盖范围 | 结构化 | 多工具 | 自动化 |
|------|---------|--------|--------|--------|
| 手写 CLAUDE.md | 自由格式 | 无 | 否 | 无 |
| .cursorrules | Cursor 专属 | 弱 | 否 | 无 |
| Copilot instructions | GitHub 专属 | 弱 | 否 | 无 |
| **AI Context Standard** | 7 层全覆盖 | YAML Schema | 多格式生成 | Scanner + CI |
