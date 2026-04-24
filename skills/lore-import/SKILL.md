---
name: lore-import
description: Import structured knowledge from documents, specs, or manual input
category: ai-context
---

# /import — 重型知识导入

对话知识密度有限。Lore 支持从文档、规范、手动输入导入高密度知识。

## 使用场景

| 场景 | 示例 |
|------|------|
| 架构设计文档 | 导入系统架构图、模块说明 |
| API 规范 | 导入接口文档、字段说明 |
| 业务规范 | 导入业务规则、流程说明 |
| 外部依赖说明 | 导入第三方系统对接文档 |
| 历史知识迁移 | 从旧文档系统迁移知识 |

## 使用方式

### 方式 1：文件导入

```
/import path/to/architecture.md
```

Agent 会：
1. 读取文档内容
2. 提取知识（DECISION/CONSTRAINT/ARCHITECTURE/EXTERNAL）
3. 生成 increment 文件
4. 标记来源为 `[trigger: document]`

### 方式 2：目录扫描

```
/import docs/
```

扫描目录下所有 `.md` 文件，批量导入知识。

### 方式 3：手动输入

```
/import

请输入知识内容（输入 END 结束）：
[DECISION] 订单服务使用 TDDL 分库分表
原因: 单表数据量超过 1 亿，需要水平扩展
分片键: order_id
分库数: 16

[CONSTRAINT] 订单表不能加唯一索引
原因: 并发写入场景会导致死锁

END
```

Agent 会解析并写入 increment。

### 方式 4：URL 导入

```
/import https://wiki.company.com/architecture
```

从 URL 获取内容并提取知识。

## 知识格式

导入的知识会标记不同的来源：

```markdown
# 2026-04-24 import-architecture-doc

## Meta
- author: 文档作者 / 导入者
- timestamp: YYYY-MM-DD HH:MM:SS
- trigger: document / manual / url
- source: 文件路径 / URL
- confidence: high（文档通常经过审核）

## Decisions
...

## Constraints
...

## Architecture
...

## External Dependencies
...
```

## 文档解析规则

### 架构文档

识别以下模式：
- "系统架构" / "模块说明" → ARCHITECTURE
- "设计原因" / "为什么" → DECISION
- "不能" / "禁止" / "必须" → CONSTRAINT
- "依赖" / "调用" / "接口" → EXTERNAL

### API 文档

识别以下模式：
- 接口定义 → ARCHITECTURE
- 字段说明 → EXTERNAL
- 限制条件 → CONSTRAINT

### 业务文档

识别以下模式：
- 业务规则 → CONSTRAINT
- 流程说明 → ARCHITECTURE
- 术语定义 → EXTERNAL

## 与对话知识的区别

| 维度 | 对话知识 | 文档知识 |
|------|---------|---------|
| **密度** | 低 | 高 |
| **结构** | 碎片化 | 完整 |
| **时效** | 实时 | 可能过期 |
| **验证** | 待验证 | 通常已审核 |
| **更新** | 自动 | 需重新导入 |

## 知识合并

文档导入的知识会与对话知识合并到同一个 snapshot：

```
snapshot.md
├── 对话知识（trigger: dialogue）
├── 文档知识（trigger: document）
└── 手动知识（trigger: manual）
```

冲突时：
- 文档知识优先级 > 对话知识（文档通常更权威）
- 标记 `[CONFLICT]` 等待人工裁决

## 示例

### 导入架构文档

```
用户: /import docs/architecture.md

Agent: 
正在解析 docs/architecture.md...

提取到以下知识：
- [ARCHITECTURE] 系统采用微服务架构，包含 5 个核心服务
- [DECISION] 选型 Spring Cloud 作为微服务框架
- [CONSTRAINT] 服务间调用必须走网关，禁止直连
- [EXTERNAL] 配置中心使用 Nacos

已写入 increment: 2026-04-24_import-architecture.md
```

### 导入 API 文档

```
用户: /import docs/api/order-service.md

Agent:
正在解析 docs/api/order-service.md...

提取到以下知识：
- [ARCHITECTURE] 订单服务提供 12 个 API 接口
- [EXTERNAL] OrderCreateRequest: 包含 8 个必填字段
- [CONSTRAINT] 订单金额必须大于 0

已写入 increment: 2026-04-24_import-order-api.md
```

## 定期同步

对于会更新的文档，可以配置定期重新导入：

```yaml
# .ai-context/config.yaml
import:
  watch_paths:
    - docs/architecture.md
    - docs/api/
  sync_interval: 7d  # 每 7 天检查一次
```

## 注意事项

1. **文档可能过期** — 导入后需要 `/health` 校验
2. **重复导入** — 相同文档重复导入会去重
3. **格式要求** — 文档需要有一定的结构，纯文本效果较差
4. **人工审核** — 高价值知识建议导入后人工确认
