# GGS Product Center 技术分析

> 基于 AI Agent（Claude Code）对 ggs-product-center 项目的实际探索记录。
> 日期：2026-04-22

---

## 一、项目概览

**技术栈**：Java 21 + Spring Boot 2.7 + Pandora Boot，多模块 Maven 项目

**核心能力**：ICBU 国际站商品管理，包含 Excel 批量搬品、AI 优化（标题/CPV/关键词/图片）、类目预测等

**模块结构**：
- `ggs-product-center-web` — Controller 层，HTTP/HSF 入口
- `ggs-product-center-service` — 核心业务逻辑
- `ggs-product-center-client` — 对外接口定义
- `ggs-product-center-logs` — 日志工具
- `ggs-product-center-start` — 启动模块

---

## 二、Excel 批量搬品完整流程

### 状态机

**主任务状态机**（ExcelSmartPostingMainTaskStateManager）：
```
NEW → UNDER_REVIEW → PRE_DATA → PRE_DATA_SUCCESS → AGGREGATE_DATA 
  → CATEGORY_CONFIRM → OPTIMISE_DATA → POST_CONFIRM → SUCCESS/FINISHED
```

**单品状态机**（ExcelSmartPostingProductStateManager）：
```
INIT → MIGRATION_SUCCESS → OPTIMIZATION_INIT → OPTIMIZATION_SUCCESS 
  → READY_POST → POSTING_SUCCESS
```

### 异步流程串联

```
1. POST /smart-posting/start-migration.json
   → 创建任务，发 MetaQ(FETCH_TAG)

2. FetchTaskListener
   → 解析 Excel，图片上传到 PhotoBank
   → 发 MetaQ(AGGREGATE_TAG)

3. AggregateTaskListener
   → 数据聚合
   → 发 MetaQ(CATEGORY_PROCESSOR_TAG)

4. CategoryProcessorTaskListener
   → 预处理（图片重上传/翻译/类目预测）
   → 停在 CATEGORY_CONFIRM 等待用户确认

5. POST /migration/smart-posting/category_confirmed.json
   → 用户确认类目，产品状态改为 OPTIMIZATION_INIT

6. MigrationOptimizedTaskProcessor（SchedulerX 轮询）
   → 执行优化 Pipeline（CPV/关键词/标题/图片等）
   → 停在 POST_CONFIRM 等待用户确认

7. POST /migration/smart-posting/post_confirmed.json
   → 用户确认发品，异步提交到 ICBU
```

### 用户确认节点

整个流程只有 **2 个** 用户确认点：
1. **CATEGORY_CONFIRM** — 类目预测结果确认
2. **POST_CONFIRM** — 最终发品确认

其余步骤（解析、聚合、优化）全部静默执行。

---

## 三、处理器体系

### SmartPostingProcessorType 枚举（优先级排序）

| 优先级 | 处理器 | 说明 | terminateOnFailure |
|--------|--------|------|--------------------|
| 0 | IMAGE_UPLOAD | 图片上传 | true |
| 1 | TRANSLATION | 翻译 | false |
| 2 | CATEGORY_PREDICT | 类目预测 | false |
| 4 | CPV_ID_SET | CPV ID 设置 | true |
| 10 | TITLE | 标题优化 | false |
| 20 | ATTRIBUTE_EXPAND | CPV 属性扩展 | false |
| 30 | WHITE_BACKGROUND_IMAGE | 白底图生成 | false |
| 31 | SCENE_IMAGE | 场景图生成 | false |
| 40 | IMAGE_CHOOSE | 图片选择 | false |
| 60 | DESCRIPTION | 描述优化 | false |
| 70 | KEYWORD_GENERATE | 关键词生成 | true |
| ... | PRICE_TRANSFORM | 价格转换 | true |
| ... | LOGISTIC | 物流 | true |
| ... | SALE_ATTRIBUTES | 销售属性 | true |
| ... | SKU_IMAGE | SKU 图片 | true |
| ... | QUALITY_CHECK_POST | 质量检查 | true |

### 强制处理器（无论 abilityList 如何配置都会执行）

定义在 `SmartPostingTaskItemInitService.ensureMandatoryProcessorTypes()`:
- KEYWORD_GENERATE
- PRICE_TRANSFORM
- LOGISTIC
- SALE_ATTRIBUTES
- SKU_IMAGE
- QUALITY_CHECK_POST
- CPV_ID_SET

### 能力开关映射

`SmartPostingAbilityConverter.convertToProcessorTypes()` 将 AbilityExpand 的 boolean 开关映射为处理器类型：
- `categoryExpand.predictCategory` → CATEGORY_PREDICT
- `cpvExpand.openCpvOptimized` → ATTRIBUTE_EXPAND
- `titleExpand.openTitleOptimized` → TITLE
- `whiteBackgroundImageExpand.openOptimized` → WHITE_BACKGROUND_IMAGE
- `sceneImageExpand.openOptimized` → SCENE_IMAGE
- 注意：IMAGE_UPLOAD 不在此映射中

---

## 四、类目预测机制

### 两条路径

1. **LLM 路径**（LlmCategoryPredictServiceImpl）
   - 输入：title + description + image + categoryList（可选）
   - 模型：千问（Qianwen）
   - 关键发现：category 名称只是被**拼接到 description** 里作为补充信息
   ```java
   param.setDesc(StringUtils.join(
       ArrayUtils.toArray(generalProductDTO.getCategory(), param.getDesc()), " | "));
   ```

2. **QP 路径**（CategoryPredictionService.predictIcbuCategory）
   - 输入：仅 title 文本
   - 走算法服务 HTTP 调用

### 跳过机制

在 `CategoryPredictProcessor` 中（第 57-59 行）：
```java
if (abilityExpand != null && abilityExpand.getCategoryExpand() != null
        && Boolean.FALSE.equals(abilityExpand.getCategoryExpand().getPredictCategory())) {
    return true; // 跳过
}
```

### 根因分析：为什么类目预测会覆盖用户的正确类目

**现象**：用户本地 agent 预测好的类目，被系统改成错误的类目。

**根因**：
- Excel 中的 category 只是文本名称，不是 categoryId
- LLM 预测将 category 名称拼到 description 中，但主要依赖 title+image 重新预测
- category 名称对最终结果的影响很弱
- QP 路径完全不使用 category 名称，只用 title

**解决方案**：通过 `predictCategory=false` 跳过系统预测，再通过 batch-update 接口注入本地 agent 的 categoryId。

---

## 五、图片处理链路

### 上传链路
```
外部图片 URL → 下载到本地 → 上传到 OSS 临时存储 
  → 图片处理 → FileBroker(sc01.alicdn.com) → PhotoBank(sc04.alicdn.com)
```

关键服务：`ProductImageServiceImpl.uploadOriginImgToPhotoBank(aliMbrId, url)`

### 图片补足能力

`ProductImageGenerationService`：
- 1 张图 → 生成白底图 + 场景图 = 共 3 张
- 2 张图 → 只生成场景图 = 共 3 张
- >= 3 张 → 不生成
- 常量：MIN_IMAGE_COUNT=3, MAX_IMAGE_COUNT=6
- AI 模型：DashScope qwen-image-max

---

## 六、本地 Agent 调用方案

### 目标

用户本地 agent 完成初步优化（本地 LLM），然后调用 ggs-product-center 的原子能力完成发品。

### 4 步 API 调用序列

**第 1 步：启动搬品任务**
```
POST /smart-posting/start-migration.json
Body: {
  excelUrl: "...",
  abilityList: [
    { type: "CPV", enabled: true },
    { type: "KEYWORD", enabled: true },
    { type: "WHITE_BG_IMAGE", enabled: true },
    { type: "SCENE_IMAGE", enabled: true }
  ],
  // 关键：关闭类目预测
  categoryExpand: { predictCategory: false }
}
```
等待状态流转到 CATEGORY_CONFIRM。

**第 2 步：注入本地 agent 的 categoryId**
```
PUT /migration/smart-posting/batch-update.json
Body: {
  mainTaskId: <taskId>,
  editField: "CATEGORY",
  editValue: "<categoryId>",
  productIds: [<id1>, <id2>, ...]
}
```

**第 3 步：确认类目，触发优化**
```
POST /migration/smart-posting/category_confirmed.json
Body: { mainTaskId: <taskId> }
```
等待优化完成，状态流转到 POST_CONFIRM。

**第 4 步：确认发品**
```
POST /migration/smart-posting/post_confirmed.json
Body: { mainTaskId: <taskId> }
```

### 关键注意事项

- 类目预测必须关闭（`predictCategory=false`），否则系统会用自己的预测覆盖你的 categoryId
- 当前项目**不支持**按类目名称查 categoryId（CategoryController 只有反向查询：ID→名称）
- 本地 agent 需要自行维护 category name → categoryId 的映射
- 强制处理器（KEYWORD_GENERATE 等）始终会执行，无法关闭
