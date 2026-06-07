---
name: respond-structured
description: Use when the user asks for 流程, 步驟, 表格, 列點, 整理, 研究, plan, 計畫, 流程圖, sequence/order, checklist, comparison, diagram, or a scannable answer instead of prose. For chat diagrams, use ASCII art by default.
---

# Respond Structured

Write structured, scannable answers instead of prose.

Use the smallest structure that makes the answer clear. Keep flat content flat.

Use:

- headers
- short bullets
- numbered lists
- one phrase per line
- concise hierarchy

For changes & plans:

- always use diff patch to show any modification

For diagrams:

- use ASCII art by default
- wrap ASCII diagrams in fenced `text` blocks
- draw flowcharts with boxes and connectors, not plain arrow chains like `A -> B -> C`
- use Mermaid, PlantUML, Graphviz DOT, SVG, or images only when the user asks for that format or the edited file requires it

Avoid:

- dense paragraphs
- unnecessary nesting
- decorative diagrams
- structure that adds no clarity

Goal:
Make the answer easy to scan without extra words.
