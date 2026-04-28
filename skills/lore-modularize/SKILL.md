---
name: lore-modularize
description: Automatically discover modules and partition knowledge into modular structure
category: ai-context
---

# /modularize — Auto Module Discovery & Knowledge Partition

全自动模块发现与知识分区。不需要用户确认，代码结构即定义。

## When to Trigger

- `/lore-evolve` detects no `modules/` directory but has accumulated knowledge with file references
- User explicitly invokes this skill

## Purpose

扫描代码目录结构，自动识别模块边界，将现有知识按 `affected_files` 路径归类到对应模块。零干预，猜错了后续对话会自动修正。

## Process

### Step 1: Check Prerequisites

- If `.ai-context/modules/` already exists → exit silently (already modular)
- If `snapshot.md` does not exist → exit silently (nothing to partition)

### Step 2: Discover Modules from Code Structure

扫描项目目录结构，识别独立模块。判定标准：

**一个目录包含以下任一即视为模块**：
- Controller/Route/Handler 类文件
- 独立的服务入口或 API 定义
- 独立的数据模型定义

**模块命名规则**：
- 直接使用目录名（`src/order/` → `order`）
- 同一模块可能分散在多个子目录 → 以父目录为准

**排除规则**：
- `test/`, `__tests__/`, `spec/`, `fixtures/` — 测试目录不是模块
- `shared/`, `common/`, `util/`, `helpers/` — 共享工具不是模块
- 只有单文件且无入口点的目录不是模块

### Step 3: Classify Knowledge by Module

读取 `snapshot.md` 和所有 increments，对每条知识：

1. **提取 `affected_files` 和关联文件路径**
2. **路径匹配**：文件路径包含哪个模块目录 → 归到该模块
3. **多模块匹配**：涉及多个模块 → 同时归到各模块，记录交叉引用
4. **零匹配**：路径不匹配任何模块 → 归到全局知识
5. **无法提取路径**：纯业务知识 → 归到全局

### Step 4: Create Module Structure

```
.ai-context/modules/
├── _index.md                  # 模块注册表
├── {{module-name}}/
│   ├── knowledge.md           # 模块知识
│   ├── specs/                 # prescriptive 层（空目录）
│   │   └── index.md           # Spec 目录
│   ├── increments/            # 模块增量
│   ├── progress.md            # 模块进度
│   └── cross-refs.md          # 跨模块依赖
```

### Step 5: Write Module Knowledge Files

对每个模块，使用 `templates/module-knowledge.md` 模板创建 `knowledge.md`：
- 从 snapshot 中提取该模块相关的知识条目
- 保持原有证据溯源（author/timestamp/confidence/source）

### Step 6: Write Module Registry

创建 `modules/_index.md`：
- 列出所有发现的模块
- 代码路径映射
- 模块用途（从知识条目推断）

### Step 7: Write Module Progress

对每个模块创建 `progress.md`：
- 知识条目数量
- 最后更新时间

### Step 8: Mark Legacy Snapshot

在 `snapshot.md` 顶部添加标记：
```
> LEGACY: Superseded by modular knowledge base. See modules/_index.md
> This file is kept for backward compatibility.
```

### Step 9: Git Add

```bash
git add .ai-context/modules/
git add .ai-context/snapshot.md
```

## Output

```
+ Modular knowledge base created:
  - Discovered X modules: {{list}}
  - Partitioned Y knowledge entries
  - Global knowledge: Z entries (unchanged in snapshot.md)
```
