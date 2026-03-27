# VibeEnglishGame — Claude 工作規範

## 📌 Token 節省原則（重要）

**每次完成一個任務或功能後，立即更新 `TODO.md`：**
- 把完成的 Task 標記為 `✅`，並加上完成日期
- 在「🔥 下次對話立即執行」區塊更新下一步待辦
- 說明已完成的變更（哪些檔案、放在哪裡、做了什麼）

這樣下次開啟對話只需讀 TODO.md 就能掌握進度，不需重新探索整個 codebase。

---

## 🛠️ 開發環境

- **不使用 Rojo**：所有腳本透過 `mcp__Roblox_Studio__run_code` 直接寫入 Studio
- **MCP 工具**：`Roblox_Studio: rbx-studio-mcp.exe --stdio`（需確認已 Connected）
- **Studio 模式**：寫入腳本前先用 `get_studio_mode` 確認為 stop 模式

## 📁 檔案對應 Studio 位置

| src 路徑 | Studio 位置 |
|----------|-------------|
| `src/shared/*.luau` | ReplicatedStorage > Shared |
| `src/server/*.server.luau` | ServerScriptService（Script） |
| `src/server/*.luau` | ServerScriptService（ModuleScript） |
| `src/client/*.client.luau` | StarterPlayerScripts > Client（LocalScript） |
| `src/client/*.luau` | StarterPlayerScripts > Client（ModuleScript） |

## 🔑 重要架構

- `DevTest.server.luau`：`DEV_MODE = "OFF" / "PLAYER" / "MCP"`（字串 flag）
- `MultiplayerManager`：啟動時建立 `DevTriggerGame` BindableFunction 在 ServerScriptService
- `QuestionData`（Shared）：從 `https://vocab.kubahuang.synology.me` API 拉題目，有後備題庫

## 📋 每次對話開始時

1. 讀 `TODO.md`（尤其是「🔥 下次對話立即執行」區塊）
2. 讀 `AI_CONTEXT.md` 了解架構細節
3. 確認 MCP 已連線（工具列表中有 `mcp__Roblox_Studio__*`）
