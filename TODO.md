# VibeGame Development Tasks (AI Optimized)

> **Note for AI Agent**: Always refer to `AI_CONTEXT.md` for architecture, tech stack, and coding conventions before implementing features.

---

## 🔥 下次對話立即執行（重開後先看這裡）

**背景：** MCP 遷移 + 驗證已於 2026-03-27 全部完成。所有 src/ 腳本已用 `mcp__Roblox_Studio__run_code` 寫入 Studio（不再使用 rojo serve）。DevTest 驗證通過，DEV_MODE = "OFF"。

**下一步：** 見 Task C 下方的待辦清單（UI、Audio、Leaderboards）。

### ✅ Task A：MCP 遷移（已完成 2026-03-27）

| Studio 位置 | 腳本 |
|-------------|------|
| ReplicatedStorage > Shared | GameLogger, Hello, Logger, QuestionData, WordList |
| ServerScriptService | Main, MapSetup, MultiplayerManager, WordGameServer, DevTest, LeaderboardBoard, WordService |
| StarterPlayerScripts > Client | Client, GoldDisplay, LobbyMusic, WordGame, GameSession, CountdownUI, LevelSelectionUI |

### ✅ Task B：DevTest DEV_MODE（已完成 2026-03-27）

`DEV_MODE` 字串 flag（在 ServerScriptService > DevTest）：
- `"OFF"` = 停用（預設）
- `"PLAYER"` = Studio 手動玩家測試
- `"MCP"` = MCP 自動測試（自動觸發關卡 + 答題）

MultiplayerManager 啟動時會自動建立 `DevTriggerGame` BindableFunction 供 DevTest 呼叫。

### ✅ Task C：驗證（已完成 2026-03-27）

1. ✅ PLAYER 模式：5 個等級區域全部找到，QuestionData 載入，Client 連線正常，無錯誤
2. ✅ MCP 模式：3 場自動測試全部正常結束（教室建立→答題→清理），DevTriggerGame BindableEvent 正常運作
3. ✅ DEV_MODE 已重設為 `"OFF"`（Studio + `src/server/DevTest.server.luau`）

**關鍵修復（本次對話）：**
- `DevTriggerGame`：BindableFunction → **BindableEvent**（解決 `Invoke` 阻塞 DevTest 問題）
- `devTrigger:Invoke()` → `devTrigger:Fire()`（在 DevTest）
- classroom 等待逾時：`waited < 15` → `waited < 50`（避免遊戲還在跑就超時）
- 以上修復已同步至 `src/server/DevTest.server.luau` 和 `src/server/MultiplayerManager.server.luau`

### 🔥 下次對話立即執行

**所有 Task A/B/C 均已完成！** 下一步建議：

- [ ] **Backlog UI**：改善黑板的 SurfaceGui 視覺效果（`src/client/LevelSelectionUI.luau`）
- [ ] **Audio**：加入 Lo-fi 背景音樂（`src/client/LobbyMusic.client.luau`）
- [ ] **Leaderboards**：全球排行榜（`src/server/LeaderboardBoard.server.luau` 已佔位）

---

## 🎯 Project Goal
Create a Roblox "Vibe" style social word trivia game. Players answer questions from a Teacher NPC by moving to YES/NO zones in independent or multiplayer classrooms.

## 🚀 Current Sprint (High Priority)

### 1. Question System Integration (題庫系統整合)
*Context*: `src/ReplicatedStorage/QuestionData.luau` exists. Needs integration into the game loop.
- [x] **Integrate QuestionData**:
    - Modified `src/server/MultiplayerManager.server.luau` to require `QuestionData`.
    - Updated the question selection logic to pick from `QuestionData`.
    - Questions are now replicated to clients via RemoteEvents.
- [x] **Implement Difficulty Logic**:
    - Added logic to categorize or filter questions by difficulty (Easy/Medium/Hard) in `QuestionData`.
    - Allow `GameSession` (Client) or `MultiplayerManager` (Server) to request specific difficulties.
- [x] **Word Level Challenge (1000-5000 Levels)**:
    - **Data Expansion**: Added datasets for 2000, 3000, 4000, and 5000 most common English words.
    - **Zone-based Selection**: Created different trigger zones in the game world for each level (LevelZone_1000, LevelZone_2000, etc.).
    - **Data Structure**: Tagged questions in `QuestionData` with levels.
    - **Room Isolation**: Each level has its own zone in the lobby, players choose their level by entering the corresponding zone.

### 2. Teacher NPC Behavior (老師 NPC 行為)
*Context*: Teacher is an R15/R6 Rig managed by Server.
- [x] **Emotion Animations**:
    - Imported animations for "Angry" (Wrong Answer) and "Happy" (Correct Answer).
    - Play these animations on the NPC Humanoid in `MultiplayerManager` during the result phase.
- [x] **Idle Behavior**:
    - Implemented a loop in `MultiplayerManager` for the Teacher to wander near the podium when not chasing players.

## ✅ Completed
- [x] **Infrastructure**: Rojo setup, `GameSession` (Client) OOP, Independent Local Classrooms.
- [x] **Core Loop**: Question display (Blackboards), YES/NO zone detection, Punishment (Ragdoll), Game Loop (Start -> Question -> Result -> Reset).
- [x] **QuestionData Structure**: Full module with 50+ questions across 5 levels (1000-5000).
- [x] **Basic NPC**: Chasing and attack logic.
- [x] **Level Selection**: Zone-based level selection (players choose level by entering different zones).
- [x] **Teacher Emotions**: Happy (correct), Angry (wrong), Idle, Walk animations.
- [x] **Teacher Idle**: Wanders near podium when not chasing players.

## 📝 Backlog (Future Tasks)

### UI/UX
- [x] **Countdown UI**: Implemented basic start countdown.
- [ ] **Question UI**: Improve SurfaceGui visuals on blackboards.
- [ ] **Audio**: Add Lo-fi background music and sound effects manager.

### Social & Economy
- [ ] **Spectating**: Allow players in Lobby to watch active games.
- [ ] **Leaderboards**: Global wins/points.
- [ ] **Shop System**: Use currency for Dances, Room Decor, Revives.

### Visuals & Vibe
- [ ] **Custom Rooms**: Player-customizable spaces.
- [ ] **Lighting**: Upgrade to Future Lighting.
- [ ] **Vibe Aesthetics**: Default outfits and accessories.

### Economy
- [ ] **Currency**: Implement Gold/Points system.
- [ ] **Shop Items**: Dances, Poses, Furniture, Revives.

## 🐛 Known Issues / Optimization
- [ ] **NPC Pathfinding**: Current movement is rigid. Implement `PathfindingService` for smoother navigation around desks.
- [ ] **Mobile Controls**: Test and adjust UI touch targets.
