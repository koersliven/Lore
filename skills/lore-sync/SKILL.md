---
name: lore-sync
description: Auto-scan project structure and sync L1 knowledge layer with codebase
category: ai-context
---

# /sync — Code Structure Auto-Scan

自动扫描项目结构，生成 L1 层知识（代码可表达的结构信息），与 snapshot 比对并更新。

## When to Trigger

- User explicitly invokes this skill
- After major refactoring or module changes
- Periodically (e.g., weekly) as maintenance

## Purpose

Lore 的 L3 层（过程知识）依赖对话沉淀，但 L1 层（结构知识）可以从代码直接提取。`/sync` 补补"开发者不说话时 Lore 什么都不知道"的盲区。

**L1 层知识范围**：
- 模块结构（目录、包、workspace）
- 入口点（Controller、Router、main 函数）
- 外部依赖（imports、package.json、pom.xml）
- 接口定义（公开 API、HSF 接口）

## Process

### Step 1: Detect Project Type

识别项目技术栈：

```
检查文件:
- package.json → Node.js/TypeScript
- pom.xml / build.gradle → Java
- go.mod → Go
- Cargo.toml → Rust
- pyproject.toml / requirements.txt → Python
```

### Step 2: Scan Structure

根据项目类型执行扫描：

#### Node.js/TypeScript

```
扫描:
- package.json → dependencies, scripts, workspaces
- src/ 目录 → 入口文件 (index.ts, main.ts, app.ts)
- Controller 文件 → HTTP 入口
- Router 文件 → 路由定义
```

#### Java

```
扫描:
- pom.xml → dependencies, modules
- src/main/java/ → 包结构
- *Controller.java → HTTP 入口
- *Service.java → 服务接口
- @HSFService 注解 → HSF 接口
```

#### Go

```
扫描:
- go.mod → dependencies
- main.go → 入口
- internal/ → 内部模块
- api/ → API 定义
```

### Step 3: Extract L1 Knowledge

将扫描结果转为 L1 知识格式：

```yaml
## L1 Structure Layer

### Modules
- web: HTTP/HSF 入口层
- service: 核心业务逻辑
- dal: 数据访问层

### Entry Points
- POST /api/orders → OrderController.create()
- GET /api/products/:id → ProductController.get()
- HSF OrderService.createOrder() → 订单创建

### Dependencies
- spring-boot-starter-web: HTTP 框架
- mybatis-plus: ORM
- hsf-sdk: RPC 框架

### External Types (待补充)
- AbilityExpand (nurture-product-tenant-common.jar)
```

### Step 4: Compare with Snapshot

读取 snapshot 中现有的 L1 内容，比对差异：

```
扫描结果:
- 模块: web, service, dal, scheduler (新)

Snapshot 现有:
- 模块: web, service, dal

差异:
+ 新增模块: scheduler
- 入口点一致
~ 依赖版本变更: spring-boot 2.7 → 3.0
```

### Step 5: Generate Update

根据差异生成更新：

**新增的结构** → 直接追加到 snapshot

**删除的结构** → 标记 `[REMOVED]`，移至 archive

**变更的结构** → 标记 `[CHANGED]`，保留新旧对比

### Step 6: Write Increment

将同步结果写入 increment：

```markdown
# 2026-04-24 sync-structure

## Meta
- trigger: /sync auto-scan
- confidence: high (直接从代码提取)

## L1 Structure Changes

### Added
- 模块: scheduler (定时任务模块)
- 入口: POST /api/jobs → JobController.trigger()

### Changed
- 依赖: spring-boot 2.7.18 → 3.0.0
- 入口: OrderController.create() 签名变更

### Removed
- 模块: legacy-api (已删除)
```

### Step 7: Update Snapshot

轻量更新 snapshot 的 L1 章节（不跑完整 /evolve）。

### Step 8: Report

```
+ Sync complete:
  - Scanned: 47 files, 3 modules
  - Added: 1 module, 2 entry points
  - Changed: 1 dependency version
  - Removed: 1 module
  - Snapshot L1 section updated
```

## L1 vs L3 Distinction

| | L1 (Structure) | L3 (Process) |
|--|----------------|--------------|
| **来源** | 代码扫描 | 对话沉淀 |
| **内容** | 模块、入口、依赖 | WHY、决策、约束 |
| **更新** | /sync 自动 | /digest + /evolve |
| **验证** | 代码是权威 | 交叉验证 |

**关键**：L1 是"代码说了算"，L3 是"人说了算"。`/sync` 只管 L1，不碰 L3。

## Implementation Notes

### Lightweight Requirement

不依赖外部工具（JavaParser、ts-morph 等）。用 agent 的文件扫描能力实现：

```
扫描方式:
- Bash: find, grep, awk
- Read: package.json, pom.xml
- Agent: 模式识别、结构提取
```

### Incremental Scan

不是每次全量扫描。只扫描：

```
- 最近 7 天有 commit 的文件
- 新增的模块/目录
- 配置文件变更
```

全量扫描只在用户明确要求时执行。
