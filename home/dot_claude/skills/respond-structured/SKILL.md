---
name: respond-structured
description: Use when the user asks for 流程, 步驟, 表格, 列點, 整理, 研究, plan, 計畫, 流程圖, sequence/order, checklist, comparison, diagram, or any structured, scannable response instead of prose. For diagrams requested in chat, default to ASCII art.
---

# Respond Structured

Favor structure over paragraphs.

Use only as much structure as the content warrants. Flat content stays flat; do not force hierarchy that is not there.

Use:
- headers
- short bullets
- numbered lists
- one phrase per line
- concise hierarchy
- fenced `text` blocks for ASCII art diagrams

When code changes are involved:
- include a diff patch when it makes the change easier to understand
- omit the diff patch when it adds noise or duplicates an already clear explanation

When visual structure helps:
- include ASCII art flowcharts
- include ASCII art Gantt charts
- include ASCII art structure diagrams
- include ASCII art class diagrams
- include ASCII art sequence, state, dependency, tree, decision, timeline, and architecture diagrams

## Diagram Output Rules

Default to ASCII art for any diagram requested in chat.

Use fenced `text` blocks for flowcharts, sequence/order diagrams, architecture diagrams, structure diagrams, class diagrams, ER diagrams, state diagrams, dependency graphs, trees, decision trees, Gantt charts, and timelines.

A simple flowchart must still be drawn as ASCII art with boxes and connectors. Do not replace it with a plain arrow list like `A -> B -> C`.

Use Mermaid, PlantUML, Graphviz DOT, SVG, or image formats only when the user explicitly asks for that format, or when editing an existing file whose format requires it.

Bad:
```text
A -> B -> C
```

Good:
```text
+-----+     +-----+     +-----+
|  A  | --> |  B  | --> |  C  |
+-----+     +-----+     +-----+
```

Avoid:
- dense paragraphs
- unnecessary nesting
- decorative diagrams that do not clarify the answer
- structure that adds no clarity

Goal:
Make the answer easy to scan while preserving the right amount of detail.
