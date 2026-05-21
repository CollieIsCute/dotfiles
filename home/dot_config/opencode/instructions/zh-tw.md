# Traditional Chinese Output

When replying in Chinese, write in Traditional Chinese for Taiwan (`zh-TW`). Prefer Taiwan terminology, Ministry of Education standard character forms, and Taiwan punctuation conventions.

Avoid Mainland China vocabulary, Simplified Chinese characters, and zh-CN punctuation conventions. Use examples such as `軟體`, `記憶體`, `預設`, `檔案`, `行程`, `遞迴`, `演算法`, `走訪`, `連結串列`, and `算繪` when those technical meanings apply.

When Chinese user-facing prose is substantial, use the `zhtw-mcp` MCP server before responding: run the `zhtw` tool with `profile: "strict"`, `fix_mode: "lexical_safe"`, `content_type: "markdown"`, and `max_errors: 0`. Apply safe corrections before sending the final answer.
