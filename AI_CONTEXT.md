# AI Context: VibeGame

## 🛠 技術堆疊 (Tech Stack)
- **平台**: Roblox
- **語言**: Luau (Strict Typing enabled `--!strict`)
- **工具**: Rojo 7.7.0 (檔案同步)
- **風格**: Object-Oriented Programming (OOP) for Systems

## 📂 專案結構與關鍵檔案

### 1. Client (客戶端)
- **路徑**: `src/client/`
- **核心**: `WordGame.client.luau` (入口), `GameSession.luau` (核心邏輯類別)
- **架構**: 
  - 每個玩家擁有獨立的 `LocalClassroom` (本地地圖)，避免多人干擾。
  - 使用 `GameSession` 管理遊戲狀態 (Lobby -> Playing -> Ended)。

### 2. Server (伺服器端)
- **路徑**: `src/server/`
- **核心**: `MultiplayerManager.server.luau`
- **職責**: 
  - 管理多人大廳 (`LobbyPlayers`)。
  - 處理全域遊戲循環 (倒數 -> 傳送 -> 出題 -> 判斷勝負)。
  - 生成與控制老師 NPC。

### 3. Shared (共用)
- **路徑**: `src/ReplicatedStorage/`
- **資料**: `QuestionData.luau` (題庫模組)
- **通訊**: 使用 RemoteEvents 進行 Client-Server 同步。

## 📏 開發規範 (Coding Conventions)
1. **Type Checking**: 所有新腳本必須包含 `--!strict` 並定義 Type。
2. **Services**: 使用 `game:GetService("ServiceName")` 獲取服務。
3. **Cleanup**: 建立的 Instance (如地圖、特效) 必須在遊戲結束時透過 `Destroy()` 或 `Debris` 清理。
4. **UI**: 使用 SurfaceGui 呈現遊戲內資訊，保持沉浸感。

## 🤖 NPC 邏輯 (Teacher)
- 老師目前是一個 R15/R6 Rig。
- 行為：
  - **Idle**: 在講台附近徘徊。
  - **Active**: 遊戲開始後，會追逐答錯的玩家或進行巡視。
  - **Reaction**: 根據玩家答題結果播放動畫。

## ⚠️ 注意事項
- 修改 `MultiplayerManager` 時要注意 Singleton 檢查，避免重複執行。
- 確保 Client 端的 `LocalClassroom` 生成位置有足夠的偏移量，避免與其他玩家重疊。