# 2026-04-23 buffer-threshold-tuning

## Changes
- `hooks/stop-flush.sh`: flush 阈值从"对话轮数"改为"知识条目数"，soft 阈值设为 3
- `templates/config.yaml`: 默认配置同步更新
- `architecture.md`: 文档中 round → entry 术语统一

## Decisions
- buffer flush 阈值从"对话轮数"改为"知识条目数"
  - 原因: 按轮数不准确——5 轮对话可能只有 2 条知识（短对话被过早打断），也可能有 5 条知识（长对话延迟 flush）
  - 讨论中提及: 按条目数更直接反映知识积累的实质
- soft 阈值设为 3 条知识条目
  - 原因: 保证有足够知识才触发 flush，避免碎片化

## Constraints
- stop-flush.sh 和 config.yaml 中的阈值必须保持一致
  - 来源: 本次修改暴露的配置同步问题
- 阈值变更需要同步更新所有文档引用
  - 来源: architecture.md 中 round → entry 术语需要同步

## Architecture Impact
- 新增 flush 触发语义：knowledge entries count，不再是 dialogue rounds
- 统一了 hook 脚本和配置模板的阈值语义
