---
description: 將目前 session 標記為公司任務，並委派耗 token 的工作給 Claude Code
---

這是公司任務。需要網路搜尋、調查、規劃、文件查詢或原始程式碼查詢時，可以用 OpenCode 呼叫 `claude -p`，把耗 token 的工作委派給 Claude Code。

請盡量把大範圍蒐集脈絡、查資料、比對文件、探索原始程式碼、整理方案等工作交給 Claude Code；目前 session 只負責回收結果、驗證重點、做最後決策與實作。

委派時可使用可用的最強 Opus 模型，並依任務需要調整思考深度。不要送出 secrets、憑證、private keys，或不必要的公司內部資料；也不要讓 Claude Code 執行釋出、推送、刪除、修改 production 等有外部副作用的動作。

額外指示：

$ARGUMENTS
