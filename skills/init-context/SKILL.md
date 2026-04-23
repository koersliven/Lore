---
name: init-context
description: Bootstrap AI project context through guided questioning with source tracing
category: ai-context
---

# /init-context — Project Context Initialization

## When to Trigger

- User explicitly invokes this skill
- Agent enters a project with no `.ai-context/snapshot.md`
- Agent detects a project it has never seen before (no snapshot, no CLAUDE.md architecture section)

## Purpose

Complete the 0→1 knowledge capture. Extract the developer's mental model of the project into structured `.ai-context/` files so the agent reaches a minimum viable understanding level.

## Process

### Step 1: Project Discovery

First, scan the project to understand basics:
- What language/framework? (package.json, pom.xml, go.mod, etc.)
- What are the entry points? (controllers, routes, main functions)
- Module structure (directories, packages, workspaces)
- External dependencies (imports, package.json dependencies, Maven GAVs)

Report what you found, then proceed to questioning.

### Step 2: Guided Questioning

Ask the user these questions in batches (3-5 at a time, conversational tone). Adapt questions based on what you already discovered.

#### Category A: External Dependencies
- "这个项目调用了哪些外部服务或 API？对方提供什么能力？"
- "有哪些依赖定义在外部 JAR 包里，你看不到源码的？"

#### Category B: Configuration
- "配置存在哪里？（Diamond / env / 数据库 / 本地文件？）"
- "有哪些关键配置项会影响行为？改了什么配置会导致线上出问题？"

#### Category C: Data Layer
- "数据存储在哪里？有分库分表吗？规则是什么？"
- "缓存策略是什么？什么数据被缓存？"

#### Category D: Business Context
- "这个项目的业务场景是什么？服务于谁？"
- "核心业务流程是什么？能描述 3-5 个关键步骤吗？"

#### Category E: Implicit Contracts
- "有哪些未文档化的约定？"
- "有哪些代码不能碰？为什么？"
- "踩过哪些坑？哪些设计是因为历史事故才这样的？"

### Step 3: Generate Initial Files

Based on answers, create:

**`.ai-context/snapshot.md`**:
- Project overview (what it is, who it serves)
- Core flows (end-to-end process descriptions)
- Key decisions (WHY-level, with source tracing)
- Constraints (things that must not change)
- External dependencies (things AI cannot read from source)
- Config index (where to find configurations)
- Business context (scenarios, relationships)
- Glossary (terminology)

Each entry must include:
```markdown
- 来源: {{user name}}, {{date}}, /init-context guided session
- 置信度: high (directly from project owner/developer)
- 验证状态: verified
```

**`.ai-context/config.yaml`**:
```yaml
version: "0.1"
project:
  name: "<project-name>"
  tech_stack: ["java-21", "spring-boot"]
knowledge_schema:
  decision: "WHY-level choice with rationale"
  constraint: "Something that must not change, with reason"
  architecture: "System relationship or flow description"
  external: "Definition in external dependency"
```

### Step 4: Install Infrastructure

Run `bash hooks/install.sh` from the framework directory.

### Step 5: Inject CLAUDE.md Rules

Add the following section to the project's `CLAUDE.md` (or `~/.claude/CLAUDE.md`):

```markdown
## AI Context Auto-Accumulation

### Buffer Rules
After each response, check if this turn revealed any of the following knowledge signals:
- **DECISION**: User corrected my understanding or explained why a design choice was made
- **CONSTRAINT**: User mentioned something that must not change, or a rule I should follow
- **ARCHITECTURE**: User described a business scenario, upstream/downstream relationship, or system flow
- **EXTERNAL**: I discovered an external dependency, API, or DTO I couldn't read from source

If yes → append to `.ai-context/buffer.md` in this format:
  [round: N] [TYPE] One-sentence summary
  - Detail: 1-3 sentences of specific information
  - 关联文件: file path (if applicable)
  - 来源: user dialogue / code analysis
  - 置信度: high (user confirmed) / medium (code analysis) / low (guess)

### Edit Guard Rules
When editing a file:
1. Check if it has knowledge associations in .ai-context/
2. If yes → show the knowledge before editing
3. If your change contradicts existing knowledge → explain why
4. Your explanation will be recorded as a new DECISION

### Flush Rules
When instructed to /digest:
1. Read .ai-context/buffer.md
2. Group entries by type (DECISION/CONSTRAINT/ARCHITECTURE/EXTERNAL)
3. Write a new increment file to .ai-context/increments/YYYY-MM-DD_<short-slug>.md
4. Include: author, timestamp, confidence, affected_files, evidence
5. Clear buffer.md (overwrite with empty)
6. Git add the increment file

### Evolve Rules
When instructed to /evolve:
1. Read snapshot and all new increments
2. Detect conflicts — if found, mark [CONFLICT], do NOT auto-resolve
3. Filter by confidence: low → pending verification section
4. Write updated snapshot
5. Archive old increments
```

## Output Format

After completion, report to the user:
```
✓ .ai-context/snapshot.md created (X sections, Y knowledge items)
✓ .ai-context/config.yaml created
✓ .ai-context/buffer.md initialized (empty)
✓ Hooks installed (5 hooks including pre-edit guard)
✓ CLAUDE.md rules injected

Agent understanding level: INITIALIZED
Next step: Start developing. Knowledge will accumulate automatically.
```
